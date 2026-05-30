"""O2 — Self-hosted İzohips (contour) MVT tile server (2026-05-27).

OpenTopoMap raster yerine kendi vektör contour tile'larımızı sunar. Veri,
`scripts/build_contour_mvt.py` ile SRTM DEM → gdal_contour → tippecanoe
pipeline'ından üretilip `backend/data/contours/contour.mbtiles` olarak
saklanır.

  GET /tiles/contour/{z}/{x}/{y}.pbf   — vektör tile (MVT/PBF)
  GET /tiles/contour/meta              — mbtiles metadata + hazır mı?

**MBTiles formatı:** SQLite veritabanı. `tiles` tablosu TMS y-ekseni kullanır
(alttan yukarı), XYZ ise üstten aşağı → y dönüşümü: `tms_y = (2^z - 1) - y`.

mbtiles dosyası yoksa endpoint 404/empty döner; frontend otomatik OpenTopoMap
fallback'ine geçer (feature flag).
"""
from __future__ import annotations

import os
import sqlite3
import threading
from typing import Optional

from fastapi import APIRouter, Path
from fastapi.responses import JSONResponse, Response

from app.core.logger import logger

router = APIRouter()

# data/contours/contour.mbtiles — repo köküne göre
_MBTILES_PATH = os.environ.get(
    "SRRP_CONTOUR_MBTILES",
    os.path.abspath(
        os.path.join(
            os.path.dirname(__file__), "..", "..", "data", "contours",
            "contour.mbtiles",
        )
    ),
)

# Thread-local SQLite bağlantısı — sqlite3 connection thread-safe değil.
_local = threading.local()


def _get_conn() -> Optional[sqlite3.Connection]:
    """Thread-local read-only mbtiles bağlantısı (dosya yoksa None)."""
    if not os.path.isfile(_MBTILES_PATH):
        return None
    conn = getattr(_local, "conn", None)
    if conn is None:
        try:
            # immutable=1 → salt-okunur, lock yok, çok hızlı.
            uri = f"file:{_MBTILES_PATH}?mode=ro&immutable=1"
            conn = sqlite3.connect(uri, uri=True, check_same_thread=False)
            _local.conn = conn
        except Exception as e:
            logger.warning("[contour] mbtiles açılamadı: %s", e)
            return None
    return conn


@router.get("/contour/meta", summary="Contour mbtiles metadata")
def contour_meta():
    """mbtiles hazır mı + metadata (bounds, minzoom, maxzoom)."""
    if not os.path.isfile(_MBTILES_PATH):
        return JSONResponse(
            {
                "ready": False,
                "reason": "mbtiles bulunamadı",
                "path": _MBTILES_PATH,
                "hint": "python scripts/build_contour_mvt.py ile üret",
            }
        )
    conn = _get_conn()
    if conn is None:
        return JSONResponse({"ready": False, "reason": "bağlantı hatası"})
    meta = {}
    try:
        cur = conn.execute("SELECT name, value FROM metadata")
        for name, value in cur.fetchall():
            meta[name] = value
    except Exception as e:
        return JSONResponse({"ready": False, "reason": str(e)})
    return {
        "ready": True,
        "path": _MBTILES_PATH,
        "metadata": meta,
        "tilejson": {
            "tiles": ["/api/v1/tiles/contour/{z}/{x}/{y}.pbf"],
            "minzoom": int(meta.get("minzoom", 8)),
            "maxzoom": int(meta.get("maxzoom", 14)),
            "format": meta.get("format", "pbf"),
            "vector_layers": _safe_vector_layers(meta),
        },
    }


def _safe_vector_layers(meta: dict) -> list:
    """metadata.json içindeki vector_layers'ı parse et (varsa)."""
    import json
    raw = meta.get("json")
    if not raw:
        return [{"id": "contour"}]
    try:
        parsed = json.loads(raw)
        return parsed.get("vector_layers", [{"id": "contour"}])
    except Exception:
        return [{"id": "contour"}]


@router.get(
    "/contour/{z}/{x}/{y}.pbf",
    summary="Contour vektör tile (MVT/PBF)",
)
def contour_tile(
    z: int = Path(..., ge=0, le=22),
    x: int = Path(..., ge=0),
    y: int = Path(..., ge=0),
):
    """Tek bir contour MVT tile döner. mbtiles yoksa 404."""
    conn = _get_conn()
    if conn is None:
        return Response(status_code=404)

    # XYZ → TMS y dönüşümü
    tms_y = (1 << z) - 1 - y
    try:
        cur = conn.execute(
            "SELECT tile_data FROM tiles "
            "WHERE zoom_level=? AND tile_column=? AND tile_row=?",
            (z, x, tms_y),
        )
        row = cur.fetchone()
    except Exception as e:
        logger.warning("[contour] tile sorgu hatası z%s/%s/%s: %s", z, x, y, e)
        return Response(status_code=500)

    if row is None or row[0] is None:
        # Boş tile — 204 (içerik yok ama hata da değil)
        return Response(status_code=204)

    data: bytes = row[0]
    headers = {
        "Content-Type": "application/x-protobuf",
        "Cache-Control": "public, max-age=86400",  # 1 gün
    }
    # tippecanoe çıktısı gzip'li olabilir → mbtiles spec gereği header ekle
    if data[:2] == b"\x1f\x8b":
        headers["Content-Encoding"] = "gzip"
    return Response(content=data, headers=headers)

import asyncio
import time
from typing import Optional

from fastapi import APIRouter, Path
from fastapi.responses import Response
from sqlalchemy import text
from app.core.logger import logger

from ..db.database import SystemSessionLocal
from ..services.redis_cache import REDIS_URL, REDIS_AVAILABLE

try:
    import redis as _redis_lib
    _REDIS_MODULE_AVAILABLE = True
except ImportError:
    _redis_lib = None
    _REDIS_MODULE_AVAILABLE = False

router = APIRouter()

# Binary Redis client — decode_responses=False PBF için zorunlu
binary_redis = None
if REDIS_AVAILABLE and _REDIS_MODULE_AVAILABLE:
    try:
        binary_redis = _redis_lib.from_url(REDIS_URL, decode_responses=False)
    except Exception:
        pass

# ---------------------------------------------------------------------------
# In-memory tile cache (Redis yoksa fallback, Redis varsa ek hız katmanı)
# ---------------------------------------------------------------------------
_TILE_CACHE: dict[str, tuple[bytes, float]] = {}
_TILE_TTL    = 300   # 5 dakika
_TILE_MAX    = 500   # maksimum entry sayısı

def _mem_get(key: str) -> Optional[bytes]:
    entry = _TILE_CACHE.get(key)
    if entry and time.monotonic() < entry[1]:
        return entry[0]
    return None

def _mem_set(key: str, data: bytes) -> None:
    if len(_TILE_CACHE) >= _TILE_MAX:
        now = time.monotonic()
        expired = [k for k, (_, exp) in _TILE_CACHE.items() if now >= exp]
        for k in expired[:max(1, _TILE_MAX // 5)]:
            _TILE_CACHE.pop(k, None)
        if len(_TILE_CACHE) >= _TILE_MAX:
            for k in list(_TILE_CACHE.keys())[:_TILE_MAX // 5]:
                del _TILE_CACHE[k]
    _TILE_CACHE[key] = (data, time.monotonic() + _TILE_TTL)

# ---------------------------------------------------------------------------
# Katman tanımları
#   min_zoom  : Bu zoom seviyesinin altında katman hiç sorgulanmaz.
#   limit     : Tile başına maksimum feature sayısı (büyük tile'ları önler).
# ---------------------------------------------------------------------------
_LAYERS = {
    "hydro": {
        "table":      "hydro_features",
        "properties": "t.feature_type, COALESCE(t.min_zoom, 0) AS min_zoom, t.energy_capacity_mw",
        "min_zoom":   6,    # Su kütleleri düşük zoom'da da görünür
        "limit":      500,
    },
    "restricted": {
        "table":      "restricted_zones",
        "properties": "t.feature_type, COALESCE(t.min_zoom, 0) AS min_zoom, t.description",
        "min_zoom":   7,
        "limit":      300,
    },
    "energy": {
        "table":      "energy_corridors",
        "properties": "t.feature_type, COALESCE(t.min_zoom, 0) AS min_zoom",
        # Tarım/endüstriyel arazi çok büyük — sadece çok yakın zoom'da göster
        "min_zoom":   11,
        "limit":      200,
    },
}

# ---------------------------------------------------------------------------
# Startup — GIST mekansal indeksler (main.py lifespan'dan çağrılır)
# ---------------------------------------------------------------------------
async def ensure_spatial_indexes() -> None:
    """
    Her üç tablo için GIST indeksini yoksa oluşturur.
    ST_Intersects + && operatörünün hızlı çalışması için zorunludur.
    Tablo yoksa sessizce atlar.
    """
    def _create(table: str) -> str:
        db = SystemSessionLocal()
        try:
            db.execute(text(
                f"CREATE INDEX IF NOT EXISTS idx_{table}_geom "
                f"ON {table} USING GIST (geom);"
            ))
            db.commit()
            return f"{table}: OK"
        except Exception as e:
            return f"{table}: {e}"
        finally:
            db.close()

    results = await asyncio.gather(
        asyncio.to_thread(_create, "hydro_features"),
        asyncio.to_thread(_create, "restricted_zones"),
        asyncio.to_thread(_create, "energy_corridors"),
        return_exceptions=True,
    )
    for r in results:
        logger.debug("[GIST] {}", r)

# ---------------------------------------------------------------------------
# Senkron DB işlevi — thread pool içinde çalışır, event loop'u bloke etmez
# ---------------------------------------------------------------------------
def _fetch_combined_tile(z: int, x: int, y: int) -> Optional[bytes]:
    """
    Tüm katmanları tek bir PBF içinde birleştirir.
    Kendi SQLAlchemy session'ını açıp kapatır → thread-safe.

    Optimizasyonlar:
      • &&  operatörü : GIST indeksini kullanır (bbox ön-filtresi)
      • ST_Intersects  : && sonrası sadece aday geometrileri kontrol eder
      • LIMIT          : Tile başına feature sayısını sınırlar
      • min_zoom eşiği : Düşük zoom'da büyük tabloları tamamen atlar
    """
    db = SystemSessionLocal()
    parts: list[bytes] = []
    try:
        for layer_name, cfg in _LAYERS.items():
            # Düşük zoom'da heavy katmanları sorgulama
            if z < cfg["min_zoom"]:
                continue

            query = text(f"""
                WITH bounds AS (
                    SELECT ST_TileEnvelope(:z, :x, :y) AS geom
                ),
                mvtgeom AS (
                    SELECT ST_AsMVTGeom(
                        ST_Transform(t.geom, 3857),
                        bounds.geom,
                        4096, 256, true
                    ) AS geom,
                    {cfg['properties']}
                    FROM {cfg['table']} t, bounds
                    WHERE t.geom && ST_Transform(bounds.geom, 4326)
                      AND ST_Intersects(t.geom, ST_Transform(bounds.geom, 4326))
                      AND COALESCE(t.min_zoom, 0) <= :z
                    LIMIT {cfg['limit']}
                )
                SELECT ST_AsMVT(mvtgeom.*, :layer_name) AS tile
                FROM mvtgeom;
            """)
            result = db.execute(
                query,
                {"z": z, "x": x, "y": y, "layer_name": layer_name}
            ).fetchone()
            if result and result[0]:
                parts.append(bytes(result[0]))
    except Exception:
        pass  # Tablo yok veya PostGIS bağlantı hatası → boş tile dön
    finally:
        db.close()
    return b"".join(parts) if parts else None


# ---------------------------------------------------------------------------
# Endpoint: GET /api/v1/tiles/{z}/{x}/{y}.pbf
# ---------------------------------------------------------------------------
@router.get("/{z}/{x}/{y}.pbf")
async def get_combined_tile(
    z: int = Path(..., description="Zoom level"),
    x: int = Path(..., description="X tile coordinate"),
    y: int = Path(..., description="Y tile coordinate"),
):
    cache_key = f"mvt:all:{z}:{x}:{y}"

    # 1. Redis cache
    if binary_redis:
        try:
            cached = binary_redis.get(cache_key)
            if cached:
                return Response(
                    content=cached,
                    media_type="application/x-protobuf",
                    headers={"X-Cache": "HIT-REDIS", "Access-Control-Allow-Origin": "*"},
                )
        except Exception:
            pass

    # 2. In-memory cache
    cached = _mem_get(cache_key)
    if cached:
        return Response(
            content=cached,
            media_type="application/x-protobuf",
            headers={"X-Cache": "HIT-MEM", "Access-Control-Allow-Origin": "*"},
        )

    # 3. DB — thread pool'da çalıştır, asyncio event loop'unu bloke etmez
    tile = await asyncio.to_thread(_fetch_combined_tile, z, x, y)

    if not tile:
        # 204 yerine geçerli boş PBF döndür — vector_tile_renderer isolate'inin
        # null-parse crash'ini önler (bazı paket sürümleri 204'ü doğru işlemez).
        return Response(
            content=b"",
            status_code=200,
            media_type="application/x-protobuf",
            headers={"Access-Control-Allow-Origin": "*"},
        )

    # Cache'e yaz
    if binary_redis:
        try:
            binary_redis.setex(cache_key, 86400, tile)  # Redis: 24 saat
        except Exception:
            pass
    _mem_set(cache_key, tile)  # Memory: 5 dakika

    return Response(
        content=tile,
        media_type="application/x-protobuf",
        headers={"X-Cache": "MISS", "Access-Control-Allow-Origin": "*"},
    )

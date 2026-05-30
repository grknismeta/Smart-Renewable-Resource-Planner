"""O2 — Self-hosted İzohips MVT pipeline orchestrator (2026-05-27).

Türkiye için SRTM 30m DEM → contour çizgileri → vektör MVT tile pipeline'ı.

Pipeline (5 aşama):
  1. SRTM DEM indir (veya mevcut GeoTIFF kullan)          [opsiyonel]
  2. gdal_contour ile 50m aralıklı contour shapefile üret
  3. ogr2ogr ile GeoJSON'a çevir (tippecanoe girişi)
  4. tippecanoe ile MVT (.mbtiles) üret
  5. Çıktıyı backend/data/contours/contour.mbtiles'a koy

**Bağımlılıklar (sistem araçları — pip değil):**
  - GDAL (gdal_contour, ogr2ogr)  → OSGeo4W (Windows) / apt gdal-bin (Linux)
  - tippecanoe                     → Linux/Mac (Windows: WSL veya derle)

Bu araçlar yüklü değilse script hangi adımda durduğunu net bildirir; veriyi
indirmeden önce ortamı kontrol eder.

**Kullanım:**

    cd backend
    # Tam pipeline (DEM elde var):
    python scripts/build_contour_mvt.py --dem path/to/turkey_dem.tif

    # Sadece ortam kontrolü:
    python scripts/build_contour_mvt.py --check

    # Belirli interval + zoom:
    python scripts/build_contour_mvt.py --dem dem.tif --interval 100 \
        --minzoom 8 --maxzoom 14

**SRTM DEM nereden:**
  - https://srtm.csi.cgiar.org/  (CGIAR 90m, ücretsiz)
  - https://dwtkns.com/srtm30m/  (NASA 30m, login gerekir)
  - Türkiye bbox: 25.5,35.8,44.8,42.1 (W,S,E,N)
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass

# Türkiye bounding box (W, S, E, N)
TR_BBOX = (25.5, 35.8, 44.8, 42.1)

_BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_WORK = os.path.join(_BASE, "data", "contours", "_work")
_OUT = os.path.join(_BASE, "data", "contours", "contour.mbtiles")


def _which(tool: str) -> str | None:
    return shutil.which(tool)


def check_env() -> dict:
    """Gerekli sistem araçlarını kontrol et."""
    tools = {
        "gdal_contour": _which("gdal_contour"),
        "ogr2ogr": _which("ogr2ogr"),
        "tippecanoe": _which("tippecanoe"),
        "gdalwarp": _which("gdalwarp"),
    }
    return tools


def print_env(tools: dict) -> bool:
    print("=" * 60)
    print("  Contour MVT Pipeline — Ortam Kontrolü")
    print("=" * 60)
    all_ok = True
    for name, path in tools.items():
        status = path if path else "BULUNAMADI"
        mark = "OK " if path else "X  "
        # gdalwarp opsiyonel
        if name == "gdalwarp" and not path:
            mark = "~  "
        elif not path:
            all_ok = False
        print(f"  [{mark}] {name:14s} {status}")
    print("-" * 60)
    if not all_ok:
        print("  Eksik araçlar var. Kurulum:")
        print("    Windows : OSGeo4W (GDAL) + WSL/derleme (tippecanoe)")
        print("    Linux   : apt install gdal-bin tippecanoe")
        print("    macOS   : brew install gdal tippecanoe")
    else:
        print("  Tüm araçlar hazır.")
    print("=" * 60)
    return all_ok


def run(cmd: list[str], desc: str) -> None:
    print(f"\n>> {desc}")
    print("   $ " + " ".join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"   X HATA (exit {result.returncode}):")
        print("   " + (result.stderr or result.stdout or "").strip()[:500])
        raise RuntimeError(f"{desc} başarısız")
    print("   OK")


def build(dem: str, interval: int, minzoom: int, maxzoom: int) -> None:
    if not os.path.isfile(dem):
        print(f"X DEM dosyası yok: {dem}")
        sys.exit(1)

    os.makedirs(_WORK, exist_ok=True)
    shp = os.path.join(_WORK, "contour.shp")
    geojson = os.path.join(_WORK, "contour.geojson")

    # ── Aşama 2: gdal_contour ──────────────────────────────────────────────
    # -a elev → yükseklik attribute'ı; -i interval (metre)
    run(
        [
            "gdal_contour",
            "-a", "elev",
            "-i", str(interval),
            dem,
            shp,
        ],
        f"gdal_contour ({interval}m aralık)",
    )

    # ── Aşama 3: ogr2ogr → GeoJSON ─────────────────────────────────────────
    if os.path.isfile(geojson):
        os.remove(geojson)
    run(
        [
            "ogr2ogr",
            "-f", "GeoJSON",
            "-t_srs", "EPSG:4326",
            geojson,
            shp,
        ],
        "ogr2ogr → GeoJSON (EPSG:4326)",
    )

    # ── Aşama 4: tippecanoe → MVT (.mbtiles) ───────────────────────────────
    if os.path.isfile(_OUT):
        os.remove(_OUT)
    run(
        [
            "tippecanoe",
            "-o", _OUT,
            "-l", "contour",            # layer adı (frontend source-layer ile eşleşmeli)
            "-Z", str(minzoom),
            "-z", str(maxzoom),
            "--simplification=4",
            "--drop-densest-as-needed",
            "--no-tile-size-limit",
            "--force",
            geojson,
        ],
        f"tippecanoe → MVT (z{minzoom}-{maxzoom})",
    )

    print("\n" + "=" * 60)
    print(f"  TAMAMLANDI → {_OUT}")
    size_mb = os.path.getsize(_OUT) / (1024 * 1024)
    print(f"  Boyut: {size_mb:.1f} MB")
    print("  Backend yeniden başlatınca /api/v1/tiles/contour/meta hazır olur.")
    print("=" * 60)


def main() -> None:
    p = argparse.ArgumentParser(description="Contour MVT pipeline")
    p.add_argument("--dem", help="SRTM DEM GeoTIFF yolu")
    p.add_argument("--interval", type=int, default=50,
                   help="Contour aralığı metre (default 50)")
    p.add_argument("--minzoom", type=int, default=8)
    p.add_argument("--maxzoom", type=int, default=14)
    p.add_argument("--check", action="store_true",
                   help="Sadece ortam kontrolü yap, çık")
    args = p.parse_args()

    tools = check_env()
    env_ok = print_env(tools)

    if args.check:
        sys.exit(0 if env_ok else 1)

    if not args.dem:
        print("\nX --dem belirtilmedi. SRTM GeoTIFF yolu gerekli.")
        print("  İndirme: https://srtm.csi.cgiar.org/ (Türkiye bbox:"
              f" {TR_BBOX})")
        sys.exit(1)

    # tippecanoe + gdal zorunlu
    if not tools["gdal_contour"] or not tools["ogr2ogr"]:
        print("\nX GDAL araçları eksik — pipeline çalıştırılamaz.")
        sys.exit(1)
    if not tools["tippecanoe"]:
        print("\nX tippecanoe eksik — MVT üretilemez.")
        sys.exit(1)

    build(args.dem, args.interval, args.minzoom, args.maxzoom)


if __name__ == "__main__":
    main()

"""SRRP — Buildings centroid yükleyici (2026-05-27, N3.2).

OSM building polygon shapefile'ından her binanın **centroid POINT**'ini çekip
`buildings_footprint` PostGIS tablosuna yazar. Polygon detayı saklamayız —
RES yoğunluk kontrolü için sadece konum gerekir.

**Amaç:** Büyük şehir merkezlerinde (Taksim, Kızılay, Konak, Antalya merkez)
`populated_areas` tablosu eksik kalıyor çünkü OSM bu merkezleri `place=city`
relation ile işaretliyor, Geofabrik dump'ında polygon yok. Bina yoğunluğu
ölçümü ile dolaylı yoldan şehir merkezlerini yakalarız:

    RES koordinatın 100m yarıçapı içinde ≥10 bina var → "yoğun yaşam alanı".

Kırsal kesimde tek-iki ev RES'i bloklamaz (threshold 10 yeterli).

**Veri:** `backend/data/vector/gis_osm_buildings_a_free_1.shp` (~812 MB,
Geofabrik Turkey dump). Yüklendiğinde ~5M centroid POINT.

**Kullanım:**

    cd backend
    .\\venv\\Scripts\\python.exe scripts\\load_buildings.py
    .\\venv\\Scripts\\python.exe scripts\\load_buildings.py --dry-run

Tahmini süre: 8-15 dakika (shape büyük, chunked write).
İdempotent: tabloyu DROP + CREATE eder, yeniden çalıştırılabilir.
"""
from __future__ import annotations

import argparse
import os
import sys
import time

try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass

import geopandas as gpd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://srrp_admin:srrp_secure_2026@localhost:5432/srrp_db",
)
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "vector")


def create_table(engine) -> None:
    """buildings_footprint — sadece centroid POINT + tipi."""
    sql = text("""
        DROP TABLE IF EXISTS buildings_footprint;
        CREATE TABLE buildings_footprint (
            id SERIAL PRIMARY KEY,
            feature_type TEXT,
            geom GEOMETRY(Point, 4326) NOT NULL
        );
        CREATE INDEX buildings_footprint_geom_idx
            ON buildings_footprint USING GIST (geom);
    """)
    with engine.connect() as conn:
        conn.execute(sql)
        conn.commit()


def load(dry_run: bool) -> None:
    print("=" * 60)
    print(f"  buildings_footprint yükleyici {'(DRY-RUN)' if dry_run else ''}")
    print("=" * 60)

    shp_path = os.path.join(DATA_DIR, "gis_osm_buildings_a_free_1.shp")
    if not os.path.exists(shp_path):
        print(f"❌ Dosya bulunamadı: {shp_path}")
        sys.exit(1)

    print(f"\n🏢 Buildings okunuyor: {shp_path}")
    print("   (~812 MB shape, 3-5 dakika sürebilir...)")
    t0 = time.time()
    gdf = gpd.read_file(shp_path)
    print(f"   Toplam building polygon: {len(gdf):,}  ({time.time() - t0:.1f}s)")

    if gdf.crs and gdf.crs.to_epsg() != 4326:
        gdf = gdf.to_crs(epsg=4326)

    # Centroid → POINT (polygon detayı RES kontrolü için gereksiz, ~10× daha küçük tablo)
    print("\n📍 Centroid hesaplanıyor...")
    t0 = time.time()
    centroids = gdf.geometry.centroid
    print(f"   Centroid: {len(centroids):,} POINT ({time.time() - t0:.1f}s)")

    # feature_type — type sütunu varsa al, yoksa "building"
    if "type" in gdf.columns:
        ftypes = gdf["type"].fillna("building")
    elif "fclass" in gdf.columns:
        ftypes = gdf["fclass"].fillna("building")
    else:
        ftypes = ["building"] * len(gdf)

    gdf_out = gpd.GeoDataFrame({
        "geom": centroids,
        "feature_type": ftypes,
    }, geometry="geom", crs="EPSG:4326")

    # Geçersiz/boş geometrileri temizle
    valid = gdf_out[gdf_out.geometry.is_valid & ~gdf_out.geometry.is_empty]
    print(f"   Geçerli centroid: {len(valid):,}")

    if dry_run:
        # Sample feature_type dağılımı
        if hasattr(ftypes, "value_counts"):
            print("\n📊 feature_type ilk 10 (drop_dup):")
            top = ftypes.value_counts().head(10)
            for k, v in top.items():
                print(f"   {str(k)[:30]:30s}: {v:>8,}")
        print("\n💡 Dry-run: tablo oluşturulmadı.")
        return

    print("\n🔨 buildings_footprint tablosu oluşturuluyor...")
    engine = create_engine(DATABASE_URL)
    create_table(engine)

    print("📤 PostGIS'e yazılıyor (chunked 5000)...")
    t0 = time.time()
    valid.to_postgis(
        "buildings_footprint",
        engine,
        if_exists="append",
        index=False,
        chunksize=5000,
    )
    print(f"\n✅ buildings_footprint: {len(valid):,} centroid yüklendi "
          f"({time.time() - t0:.1f}s)")

    # Test sorgu: 100m radius içinde bina sayısı
    print("\n🧪 Test sorgu — 100m yarıçap bina sayısı:")
    tests = [
        ("Taksim",         41.0369, 28.9850),
        ("Kadiköy merkez", 40.9904, 29.0270),
        ("Ankara Kızılay", 39.9208, 32.8541),
        ("İzmir Konak",    38.4192, 27.1287),
        ("Antalya merkez", 36.8969, 30.7133),
        ("Kayseri merkez", 38.7312, 35.4787),
        ("Konya merkez",   37.8716, 32.4847),
        ("Kırsal — Tuz Gölü", 38.7000, 33.4000),
        ("Kırsal — Toroslar", 37.0500, 32.0000),
    ]
    with engine.connect() as conn:
        for name, lat, lon in tests:
            v = conn.execute(text("""
                SELECT COUNT(*) FROM buildings_footprint
                WHERE ST_DWithin(
                    geom::geography,
                    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                    100
                )
            """), {"lat": lat, "lon": lon}).scalar()
            verdict = "YOĞUN" if v >= 10 else ("orta" if v >= 3 else "kırsal")
            print(f"   {name:22s} ({lat:.4f}, {lon:.4f}) -> {v:>4} bina  [{verdict}]")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dry-run", "-n", action="store_true",
        help="Raporla, tabloya yazma",
    )
    args = parser.parse_args()
    load(dry_run=args.dry_run)

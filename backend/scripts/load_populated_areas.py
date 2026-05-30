"""SRRP — Yaşam alanları yükleyici (2026-05-27, N3).

OSM landuse shapefile'ından `residential` + `commercial` + `retail` polygon'larını
çekip yeni `populated_areas` PostGIS tablosuna yazar. Bu tablo **sadece RES
(rüzgar türbini)** yasak bölgesi kontrolü için kullanılır — GES (güneş paneli)
yaşam alanına kurulabildiği için (çatı, fabrika, devlet binası) `restricted_zones`
yerine ayrı tablo tutuluyor.

Backend `geo_service._analyze_wind` bu tabloyu sorgulayarak şehir/kasaba/köy
içine düşen RES pin'lerini bloklar. Kullanıcı raporu:
> "İstanbul merkezinin çoğu yerine RES kurulamaz ama kurabiliyoruz."

Veri kaynağı: `backend/data/vector/gis_osm_landuse_a_free_1.shp` (Geofabrik
OSM dump'ı, Türkiye için ~150 MB shapefile). Yüklediğimiz feature class'lar:
  • residential  — yerleşim alanı (mahalle, sokak, ev grupları)
  • commercial   — ticari/AVM
  • retail       — perakende
  • school       — okul/üniversite kampüsü

Not: OSM `place=city/town/village/hamlet` *noktasal* veriler ayrı dosyada
(`gis_osm_places_*`) ve polygon karşılığı yok. Residential polygonu pratikte
şehir/kasaba/köy yerleşim alanlarını kapsıyor → yeterli.

**Kullanım:**

    cd backend
    .\\venv\\Scripts\\python.exe scripts\\load_populated_areas.py
    .\\venv\\Scripts\\python.exe scripts\\load_populated_areas.py --dry-run

Tahmini süre: 2-5 dakika (landuse shape büyük, ~150 MB tarama).
İdempotent: tabloyu önce DROP + CREATE eder, yeniden çalıştırılabilir.
"""
from __future__ import annotations

import argparse
import os
import sys

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

# Yaşam alanı için fclass değerleri (Geofabrik landuse şeması)
POPULATED_CLASSES = [
    "residential",  # yerleşim
    "commercial",   # ticari
    "retail",       # perakende
    "school",       # okul/kampüs
    # 'industrial' ve 'military' restricted_zones'da zaten var → buraya koymuyoruz
]


def create_table(engine) -> None:
    """populated_areas tablosunu (sadece RES yasak) oluştur. Yeniden çağrılabilir."""
    sql = text("""
        DROP TABLE IF EXISTS populated_areas;
        CREATE TABLE populated_areas (
            id SERIAL PRIMARY KEY,
            feature_type TEXT NOT NULL,
            name TEXT,
            geom GEOMETRY(Geometry, 4326) NOT NULL
        );
        CREATE INDEX populated_areas_geom_idx
            ON populated_areas USING GIST (geom);
    """)
    with engine.connect() as conn:
        conn.execute(sql)
        conn.commit()


def load(dry_run: bool) -> None:
    print("=" * 60)
    print(f"  populated_areas yükleyici {'(DRY-RUN)' if dry_run else ''}")
    print("=" * 60)

    shp_path = os.path.join(DATA_DIR, "gis_osm_landuse_a_free_1.shp")
    if not os.path.exists(shp_path):
        print(f"❌ Dosya bulunamadı: {shp_path}")
        sys.exit(1)

    engine = create_engine(DATABASE_URL)

    print(f"\n🏙️  Landuse okunuyor: {shp_path}")
    print("   (~150 MB, 2-3 dakika sürebilir...)")
    gdf = gpd.read_file(shp_path)
    print(f"   Toplam landuse polygon: {len(gdf):,}")

    if gdf.crs and gdf.crs.to_epsg() != 4326:
        gdf = gdf.to_crs(epsg=4326)

    if "fclass" not in gdf.columns:
        print("❌ 'fclass' kolonu yok — beklenen Geofabrik şeması değil.")
        sys.exit(1)

    # Yaşam alanlarını filtrele
    mask = gdf["fclass"].isin(POPULATED_CLASSES)
    populated = gdf[mask].copy()
    print(f"   Yaşam alanı (residential/commercial/retail/school): {len(populated):,}")

    # Class bazında özet
    print("\n📊 Class dağılımı:")
    for cls in POPULATED_CLASSES:
        count = (populated["fclass"] == cls).sum()
        print(f"   {cls:15s}: {count:>6,}")

    # Geçersiz/boş geometrileri temizle
    populated = populated[populated.geometry.is_valid & ~populated.geometry.is_empty]
    print(f"\n   Geçerli kayıt: {len(populated):,}")

    if dry_run:
        print("\n💡 Dry-run: tablo oluşturulmadı, kayıt yazılmadı.")
        return

    print("\n🔨 populated_areas tablosu yeniden oluşturuluyor...")
    create_table(engine)

    print("📤 PostGIS'e yazılıyor...")
    gdf_out = gpd.GeoDataFrame({
        "geom": populated.geometry,
        "feature_type": populated["fclass"],
        "name": populated.get("name", "").fillna(""),
    }, geometry="geom", crs="EPSG:4326")

    gdf_out.to_postgis(
        "populated_areas",
        engine,
        if_exists="append",
        index=False,
        chunksize=1000,
    )

    print(f"\n✅ populated_areas: {len(gdf_out):,} kayıt yüklendi.")

    # Test: İstanbul Beşiktaş koordinatından sorgu
    print("\n🧪 Test sorgu (İstanbul Beşiktaş, 41.04, 29.00):")
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT feature_type, COALESCE(name, '') as name
            FROM populated_areas
            WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(29.00, 41.04), 4326))
            LIMIT 3
        """)).fetchall()
        if result:
            for row in result:
                print(f"   ✓ {row[0]:<15s} '{row[1]}'")
            print("   → RES burada YASAKLI olacak ✓")
        else:
            print("   ⚠ Beşiktaş koordinatı yaşam alanı içinde değil — beklenmez!")
            print("   (residential polygon kapsamı dar olabilir, kontrol et)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dry-run", "-n", action="store_true",
        help="Raporla, tabloya yazma",
    )
    args = parser.parse_args()
    load(dry_run=args.dry_run)

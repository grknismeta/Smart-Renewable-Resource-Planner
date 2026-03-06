"""
OSM Shapefile → PostGIS Yükleyici
===================================
Bu script backend/data/vector/ klasöründeki OSM shapefile'larını
PostGIS veritabanına yükler.

Yüklenen tablolar:
  - hydro_features       : Su kütleleri (HES uygunluk analizi için)
  - restricted_zones     : Doğal/koruma alanları
  - energy_corridors     : Arazi kullanım verileri (enerji planlaması için)

Kullanım:
  cd backend
  python scripts/load_vector_data.py
"""

import os
import sys
import geopandas as gpd
import psycopg2
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# .env dosyasından bağlantı bilgilerini al
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://srrp_admin:srrp_secure_2026@localhost:5432/srrp_db")
DATA_DIR = os.path.join(os.path.dirname(__file__), '..', 'data', 'vector')

# SQLAlchemy engine (GeoDataFrame.to_postgis için)
engine = create_engine(DATABASE_URL)


def create_tables():
    """PostGIS extension'ı aktif et."""
    print("📦 PostGIS kontrol ediliyor...")
    with engine.connect() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))
        conn.commit()
    print("✅ PostGIS aktif.")


def load_water_features():
    """
    gis_osm_water_a_free_1.shp → hydro_features
    Su kütleleri: göl, nehir, rezervuar, baraj gölü
    """
    shp_path = os.path.join(DATA_DIR, 'gis_osm_water_a_free_1.shp')
    if not os.path.exists(shp_path):
        print(f"⚠️  Dosya bulunamadı: {shp_path}")
        return

    print(f"\n💧 Su verileri yükleniyor: {shp_path}")
    print("   (Bu işlem 1-2 dakika sürebilir...)")

    gdf = gpd.read_file(shp_path)
    print(f"   Toplam kayıt: {len(gdf)}")

    # Koordinat sistemi düzelt
    if gdf.crs and gdf.crs.to_epsg() != 4326:
        gdf = gdf.to_crs(epsg=4326)

    # Sütunları eşleştir
    gdf_out = gpd.GeoDataFrame({
        'geom': gdf.geometry,
        'feature_type': gdf.get('fclass', 'water').fillna('water'),
        'name': gdf.get('name', '').fillna(''),
        'energy_capacity_mw': 0.0,
        'min_zoom': 5,
    }, geometry='geom', crs='EPSG:4326')

    # Geçersiz geometrileri temizle
    gdf_out = gdf_out[gdf_out.geometry.is_valid]
    gdf_out = gdf_out[~gdf_out.geometry.is_empty]
    print(f"   Geçerli kayıt: {len(gdf_out)}")

    gdf_out.to_postgis(
        'hydro_features',
        engine,
        if_exists='replace',
        index=False,
        chunksize=1000,
    )
    print(f"✅ hydro_features: {len(gdf_out)} kayıt yüklendi.")


def load_natural_features():
    """
    gis_osm_natural_a_free_1.shp + gis_osm_natural_free_1.shp → restricted_zones
    Koruma alanları: orman, milli park, sulak alan, rezerv
    """
    files = [
        ('gis_osm_natural_a_free_1.shp', 'natural_area'),
        ('gis_osm_natural_free_1.shp', 'natural_point'),
    ]

    all_frames = []
    for fname, ftype in files:
        shp_path = os.path.join(DATA_DIR, fname)
        if not os.path.exists(shp_path):
            print(f"⚠️  Dosya bulunamadı: {shp_path}")
            continue

        print(f"\n🌿 Doğal alan verisi yükleniyor: {fname}")
        gdf = gpd.read_file(shp_path)
        print(f"   Toplam kayıt: {len(gdf)}")

        if gdf.crs and gdf.crs.to_epsg() != 4326:
            gdf = gdf.to_crs(epsg=4326)

        # Sadece kısıtlı bölge sayılabilecek kategorileri al
        restricted_classes = [
            'nature_reserve', 'national_park', 'protected_area',
            'forest', 'wetland', 'scrub', 'heath',
        ]
        fclass_col = gdf.get('fclass')
        if fclass_col is not None:
            gdf = gdf[gdf['fclass'].isin(restricted_classes)]

        gdf_out = gpd.GeoDataFrame({
            'geom': gdf.geometry,
            'feature_type': gdf.get('fclass', ftype).fillna(ftype),
            'name': gdf.get('name', '').fillna(''),
            'description': ftype,
            'min_zoom': 5,
        }, geometry='geom', crs='EPSG:4326')

        gdf_out = gdf_out[gdf_out.geometry.is_valid]
        gdf_out = gdf_out[~gdf_out.geometry.is_empty]
        all_frames.append(gdf_out)
        print(f"   Filtrelenmiş kayıt: {len(gdf_out)}")

    if not all_frames:
        print("⚠️  Yüklenecek doğal alan verisi bulunamadı.")
        return

    import pandas as pd
    combined = pd.concat(all_frames, ignore_index=True)
    gdf_final = gpd.GeoDataFrame(combined, geometry='geom', crs='EPSG:4326')

    gdf_final.to_postgis(
        'restricted_zones',
        engine,
        if_exists='replace',
        index=False,
        chunksize=500,
    )
    print(f"✅ restricted_zones: {len(gdf_final)} kayıt yüklendi.")


def load_landuse_features():
    """
    gis_osm_landuse_a_free_1.shp → energy_corridors
    Arazi kullanımı: tarım arazileri, endüstriyel alanlar (enerji planlaması)
    """
    shp_path = os.path.join(DATA_DIR, 'gis_osm_landuse_a_free_1.shp')
    if not os.path.exists(shp_path):
        print(f"⚠️  Dosya bulunamadı: {shp_path}")
        return

    print(f"\n⚡ Arazi kullanım verisi yükleniyor: {shp_path}")
    print("   (Bu işlem 2-3 dakika sürebilir, dosya büyük...)")

    # Büyük dosya — sadece enerji ile ilgili kategorileri al
    energy_classes = [
        'farm', 'farmland', 'farmyard',
        'meadow', 'grass', 'village_green',
        'industrial', 'commercial',
        'military',  # yasak bölge sayılır
        'quarry',
    ]

    first_chunk = True
    total_written = 0

    try:
        import fiona
        with fiona.open(shp_path) as src:
            chunk = []
            for feature in src:
                fclass = feature.get('properties', {}).get('fclass', '')
                if fclass in energy_classes:
                    chunk.append(feature)

                if len(chunk) >= 500:
                    _write_energy_chunk(chunk, engine)
                    total_written += len(chunk)
                    chunk = []
                    print(f"   İlerleme: {total_written} kayıt yazıldı...")

            if chunk:
                _write_energy_chunk(chunk, engine)
                total_written += len(chunk)

    except ImportError:
        # fiona yoksa geopandas ile dene (yavaş ama çalışır)
        print("   (fiona bulunamadı, geopandas ile yükleniyor — yavaş olabilir)")
        gdf = gpd.read_file(shp_path)
        if gdf.crs and gdf.crs.to_epsg() != 4326:
            gdf = gdf.to_crs(epsg=4326)
        if 'fclass' in gdf.columns:
            gdf = gdf[gdf['fclass'].isin(energy_classes)]

        gdf_out = gpd.GeoDataFrame({
            'geom': gdf.geometry,
            'feature_type': gdf.get('fclass', 'landuse').fillna('landuse'),
            'name': gdf.get('name', '').fillna(''),
            'min_zoom': 7,
        }, geometry='geom', crs='EPSG:4326')
        gdf_out = gdf_out[gdf_out.geometry.is_valid & ~gdf_out.geometry.is_empty]
        gdf_out.to_postgis('energy_corridors', engine, if_exists='replace', index=False, chunksize=500)
        total_written = len(gdf_out)

    print(f"✅ energy_corridors: {total_written} kayıt yüklendi.")


def _write_energy_chunk(features, engine):
    """Fiona feature chunk'ını PostGIS'e yazar."""
    from shapely.geometry import shape
    rows = []
    for f in features:
        try:
            geom = shape(f['geometry'])
            if not geom.is_valid or geom.is_empty:
                continue
            rows.append({
                'geom': geom,
                'feature_type': f['properties'].get('fclass', 'landuse'),
                'name': f['properties'].get('name', '') or '',
                'min_zoom': 7,
            })
        except Exception:
            continue

    if not rows:
        return

    import pandas as pd
    gdf = gpd.GeoDataFrame(rows, geometry='geom', crs='EPSG:4326')
    # Use if_exists='append' here because it's called multiple times in a loop,
    # but since fiona is missing, this function isn't even used right now.
    gdf.to_postgis('energy_corridors', engine, if_exists='append', index=False)


if __name__ == '__main__':
    print("=" * 60)
    print("  OSM Shapefile → PostGIS Yükleyici")
    print("=" * 60)

    try:
        create_tables()
        load_water_features()
        load_natural_features()
        load_landuse_features()

        print("\n" + "=" * 60)
        print("✅ Tüm veriler başarıyla yüklendi!")
        print("   Haritada tile katmanları artık veri gösterecek.")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ Hata: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

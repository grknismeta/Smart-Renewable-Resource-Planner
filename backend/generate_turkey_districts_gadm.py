"""
generate_turkey_districts_gadm.py
===================================
Proje icindeki GADM shapefile'larindan Turkiye ilce merkezlerini uretir.
Overpass veya Nominatim API'ye gerek yok — tamamen offline calisir.

GADM Level 2 = Ilce sinir polygonlari (~973 ilce)
Centroid: Gercek polygon merkezi (bbox merkezi degil)

Kullanim:
  cd backend
  pip install geopandas
  python generate_turkey_districts_gadm.py

Gereksinim: geopandas (pyproj, fiona da otomatik gelir)
"""

import sys
import json
from pathlib import Path

# Windows encoding duzeltmesi
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

BASE_DIR   = Path(__file__).parent
VECTOR_DIR = BASE_DIR / "data" / "vector"
SHP_L1     = VECTOR_DIR / "gadm41_TUR_1.shp"   # Iller (province)
SHP_L2     = VECTOR_DIR / "gadm41_TUR_2.shp"   # Ilceler (district)
JSON_OUT   = BASE_DIR / "turkey_districts.json"
CONST_OUT  = BASE_DIR / "app" / "core" / "constants.py"


# ── Turkce karakter normalize etme ────────────────────────────────────────────
CHAR_MAP = {
    "I":  "İ", "i":  "ı",
    "Ğ":  "Ğ", "ğ":  "ğ",
    "Ü":  "Ü", "ü":  "ü",
    "Ş":  "Ş", "ş":  "ş",
    "Ö":  "Ö", "ö":  "ö",
    "Ç":  "Ç", "ç":  "ç",
}

def normalize(name: str) -> str:
    return name.strip().lower()


def fix_name(name: str) -> str:
    """GADM adlarinda bazi duzeltmeler (All caps vs title case)."""
    if name is None:
        return ""
    # GADM bazen ALL CAPS yazabiliyor
    if name == name.upper() and len(name) > 2:
        name = name.title()
    return name.strip()


def load_with_geopandas():
    """
    geopandas ile shapefile oku.
    Centroid hesabi icin once metrik CRS'e (UTM zone 36N) donustur,
    centroid al, sonra WGS84'e geri don.
    Bu sayede geographic CRS uyarisi ve hata payı ortadan kalkar.
    NOT: Bu centroid yine de polygon merkezi, sehir merkezi degil.
         Koordinatlar Nominatim ile duzeltilmesi icin kullanilacak.
    """
    import geopandas as gpd

    print("  geopandas ile yukleniyor...")
    gdf2 = gpd.read_file(SHP_L2)

    # Once WGS84'e donustur
    if gdf2.crs and gdf2.crs.to_epsg() != 4326:
        gdf2 = gdf2.to_crs(epsg=4326)

    # Centroid icin metrik CRS (Turkey icin UTM zone 36N = EPSG:32636)
    gdf_proj = gdf2.to_crs(epsg=32636)
    gdf2["centroid"] = gdf_proj.geometry.centroid.to_crs(epsg=4326)
    gdf2["lat"] = gdf2["centroid"].y
    gdf2["lon"] = gdf2["centroid"].x

    return gdf2


def build_cities(gdf):
    """GeoDataFrame'den standart cities listesi uret."""
    cities = []

    for _, row in gdf.iterrows():
        # GADM alan adlari: NAME_1 (il), NAME_2 (ilce), VARNAME_2 (alternatif)
        province = fix_name(row.get("NAME_1", "") or "")
        district = fix_name(row.get("NAME_2", "") or "")

        if not province or not district:
            continue

        lat = float(row["lat"])
        lon = float(row["lon"])

        # Turkiye sinir kontrolu
        if not (35.5 <= lat <= 42.5 and 25.5 <= lon <= 45.0):
            print(f"  [SINIR DISI] {district} ({province}): lat={lat:.4f}, lon={lon:.4f} — atlanıyor")
            continue

        is_center = normalize(district) == normalize(province)

        cities.append({
            "name": district,
            "province": province,
            "district": None if is_center else district,
            "lat": round(lat, 4),
            "lon": round(lon, 4),
        })

    cities.sort(key=lambda c: (c["province"], c["name"]))
    return cities


def write_json(cities):
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(cities, f, ensure_ascii=False, indent=2)
    print(f"  JSON: {JSON_OUT}")


def write_constants(cities):
    lines = [
        '"""\n',
        'Turkiye il ve ilce merkezleri\n',
        'GADM v4.1 shapefile kaynakli — gercek polygon centroid koordinatlari\n',
        f'Toplam: {len(cities)} konum\n',
        '"""\n\n',
        'TURKEY_CITIES = [\n',
    ]
    current_province = None
    for c in cities:
        if c["province"] != current_province:
            current_province = c["province"]
            lines.append(f'\n    # {current_province.upper()}\n')
        d = f'"{c["district"]}"' if c["district"] else "None"
        lines.append(
            f'    {{"name": "{c["name"]}", "province": "{c["province"]}", '
            f'"district": {d}, "lat": {c["lat"]}, "lon": {c["lon"]}}},\n'
        )
    lines.append(']\n')
    with open(CONST_OUT, "w", encoding="utf-8") as f:
        f.writelines(lines)
    print(f"  constants.py: {CONST_OUT}")


def main():
    print("=" * 65)
    print("Turkiye Ilce Koordinat Ureteci — GADM v4.1 (Offline)")
    print("=" * 65)

    if not SHP_L2.exists():
        print(f"HATA: {SHP_L2} bulunamadi!")
        return

    # ── geopandas yukle ────────────────────────────────────────────
    try:
        gdf = load_with_geopandas()
    except ImportError:
        print("\n  geopandas yuklu degil. Yukleniyor...")
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "geopandas", "-q"])
        gdf = load_with_geopandas()

    print(f"  {len(gdf)} ilce polygon yuklendi.")

    # Mevcut alanları listele (hangi NAME_x var?)
    cols = list(gdf.columns)
    name_cols = [c for c in cols if "NAME" in c.upper() or "VAR" in c.upper()]
    print(f"  Mevcut alan adlari: {name_cols}")

    # Ornek kayit goster
    if len(gdf) > 0:
        row = gdf.iloc[0]
        print(f"  Ornek: {row.get('NAME_2', '?')} / {row.get('NAME_1', '?')} | "
              f"lat={row['lat']:.4f}, lon={row['lon']:.4f}")

    # ── Cities listesi uret ────────────────────────────────────────
    cities = build_cities(gdf)
    print(f"\n  Uretilen konum: {len(cities)}")

    if len(cities) < 500:
        print("  [UYARI] 500'den az konum — shapefile eksik olabilir!")

    # ── Ciktilar ──────────────────────────────────────────────────
    write_json(cities)
    write_constants(cities)

    # Ozet istatistik
    provinces = set(c["province"] for c in cities)
    print(f"\n  Il sayisi    : {len(provinces)}")
    print(f"  Ilce sayisi  : {len(cities)}")
    print(f"\nTamamlandi!")
    print("Sonraki adim: python distribute.py --computers 4")
    print("=" * 65)


if __name__ == "__main__":
    main()

"""
generate_turkey_districts_final.py
=====================================
GADM shapefile'dan il/ilce isimlerini al,
Nominatim'den gercek sehir merkezi koordinatlarini cek.

Neden bu yaklasim:
  - GADM: En dogru idari sinir listesi (81 il, 929 ilce), ama centroid yanlis
  - Nominatim: "Aladağ, Adana, Turkey" → gercek ilce merkezi koordinati

Sonuc: Dogru isimler + dogru koordinatlar.

Kullanim:
  cd backend
  pip install geopandas requests
  python generate_turkey_districts_final.py

Sure: ~929 ilce x 1.2 sn = ~19 dakika
Kesinti durumunda kaldigi yerden devam eder.
"""

import sys
import json
import time
import requests
from pathlib import Path

if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

BASE_DIR      = Path(__file__).parent
VECTOR_DIR    = BASE_DIR / "data" / "vector"
SHP_L2        = VECTOR_DIR / "gadm41_TUR_2.shp"
PROGRESS_FILE = BASE_DIR / "nominatim_progress.json"
JSON_OUT      = BASE_DIR / "turkey_districts.json"
CONST_OUT     = BASE_DIR / "app" / "core" / "constants.py"

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
HEADERS       = {"User-Agent": "SRRP-TurkeyDistricts/3.0"}


# ─────────────────────────────────────────────────────────────────────────────

def load_gadm_names():
    """GADM'dan sadece il/ilce isimlerini al (koordinat almiyoruz)."""
    import geopandas as gpd
    gdf = gpd.read_file(SHP_L2)
    pairs = []
    seen = set()
    for _, row in gdf.iterrows():
        province = (row.get("NAME_1") or "").strip()
        district = (row.get("NAME_2") or "").strip()
        if not province or not district:
            continue
        key = f"{district}|{province}"
        if key not in seen:
            seen.add(key)
            pairs.append((province, district))
    pairs.sort()
    return pairs


def nominatim_query(district, province):
    """Nominatim'den gercek sehir merkezi koordinatini cek."""
    # Oncelikli sorgu: ilce + il + Turkey
    for query in [
        f"{district}, {province}, Turkey",
        f"{district}, Turkey",
    ]:
        try:
            r = requests.get(
                NOMINATIM_URL,
                params={"q": query, "format": "json", "limit": 3,
                        "countrycodes": "tr", "accept-language": "tr"},
                headers=HEADERS,
                timeout=10,
            )
            r.raise_for_status()
            results = r.json()

            # Sonuclar arasinda en uygun olanini sec
            for res in results:
                lat = float(res["lat"])
                lon = float(res["lon"])
                # Turkiye sinir kontrolu
                if 35.5 <= lat <= 42.5 and 25.5 <= lon <= 45.0:
                    return lat, lon
        except Exception:
            pass
        time.sleep(0.5)

    return None, None


def main():
    print("=" * 65)
    print("Turkiye Ilce Koordinat Ureteci — GADM + Nominatim")
    print("GADM: il/ilce isimleri | Nominatim: gercek sehir merkezi")
    print("=" * 65)

    # GADM'dan isimleri yukle
    print("\n[1/2] GADM'dan il/ilce isimleri yukleniyor...")
    try:
        pairs = load_gadm_names()
    except ImportError:
        print("  geopandas yuklu degil, yukleniyor...")
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "geopandas", "-q"])
        pairs = load_gadm_names()

    print(f"  {len(pairs)} ilce bulundu.")

    # Ilerleme dosyasini yukle (kesinti koruması)
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE, "r", encoding="utf-8") as f:
            done = json.load(f)
        print(f"  Onceki ilerleme: {len(done)} ilce hazir, devam ediliyor...")
    else:
        done = {}

    # Nominatim sorguları
    print(f"\n[2/2] Nominatim'den koordinatlar cekiliyor...")
    print(f"  Tahmini sure: ~{len(pairs) * 1.2 / 60:.0f} dakika\n")

    cities = []
    error_count = 0

    for i, (province, district) in enumerate(pairs):
        key = f"{district}|{province}"

        if key in done:
            cities.append(done[key])
            continue

        lat, lon = nominatim_query(district, province)

        if lat is None:
            # Son care: il merkezini kullan
            lat, lon = nominatim_query(province, "Turkey")
            if lat is None:
                print(f"  [ATLA] {district} ({province}): koordinat bulunamadi")
                error_count += 1
                continue
            print(f"  [FALLBACK] {district} ({province}): il merkezi kullanildi")
            error_count += 1

        # GADM Level 2 names province centers "Merkez" (Turkish for "center")
        # → treat as province center: name=province, district=None
        is_center = district.lower().strip() in ("merkez",) or \
                    district.lower().strip() == province.lower().strip()
        entry = {
            "name": province if is_center else district,
            "province": province,
            "district": None if is_center else district,
            "lat": round(lat, 4),
            "lon": round(lon, 4),
        }
        done[key] = entry
        cities.append(entry)

        # Her 20 ilcede bir kaydet
        if (i + 1) % 20 == 0:
            with open(PROGRESS_FILE, "w", encoding="utf-8") as f:
                json.dump(done, f, ensure_ascii=False)
            pct = (i + 1) / len(pairs) * 100
            print(f"  [{i+1:4d}/{len(pairs)}] {pct:5.1f}%  Son: {district} ({province})")

        time.sleep(1.1)  # OSM: max 1 istek/saniye

    # Sirala ve kaydet
    cities.sort(key=lambda c: (c["province"], c["name"]))

    print(f"\n  Toplam: {len(cities)} ilce")
    print(f"  Fallback/Hata: {error_count}")

    # JSON
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(cities, f, ensure_ascii=False, indent=2)
    print(f"  JSON: {JSON_OUT}")

    # constants.py
    _write_constants(cities)
    print(f"  constants.py: {CONST_OUT}")

    # Ilerleme dosyasini temizle
    if PROGRESS_FILE.exists():
        PROGRESS_FILE.unlink()

    print(f"\nTamamlandi! Sonraki adim: python distribute.py --computers 4")
    print("=" * 65)


def _write_constants(cities):
    lines = [
        '"""\n',
        'Turkiye il ve ilce merkezleri\n',
        'Kaynak: GADM v4.1 (isimler) + Nominatim OSM (koordinatlar)\n',
        f'Toplam: {len(cities)} konum\n',
        '"""\n\n',
        'from typing import Optional, Dict, Any\n\n',
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
    lines.append('\n\n')
    lines.append('def get_location_by_name(name: str) -> Optional[Dict[str, Any]]:\n')
    lines.append('    """Isime gore sehir/ilce bul (buyuk/kucuk harf duyarsiz)."""\n')
    lines.append('    if not name:\n')
    lines.append('        return None\n')
    lines.append('    name_lower = name.strip().lower()\n')
    lines.append('    for city in TURKEY_CITIES:\n')
    lines.append('        if city["name"].lower() == name_lower:\n')
    lines.append('            return city\n')
    lines.append('        if city["province"].lower() == name_lower:\n')
    lines.append('            return city\n')
    lines.append('    return None\n')
    with open(CONST_OUT, "w", encoding="utf-8") as f:
        f.writelines(lines)


if __name__ == "__main__":
    main()

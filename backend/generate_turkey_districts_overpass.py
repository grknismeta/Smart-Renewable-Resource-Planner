"""
generate_turkey_districts_overpass.py
======================================
Overpass API kullanarak Turkiye'deki tum ilce merkezlerinin
GERCEK koordinatlarini ceker.

DUZELTME: Artik 'out center' (bounding box merkezi) yerine
OSM'nin elle isaretledigi 'admin_centre' node'unu kullaniyor.
Bu sayede Cankaya, Yenimahalle gibi buyuk ilceler icin
koordinatlar gercek sehir merkezine isaret eder.

Ciktilar:
  1. backend/turkey_districts.json   (standalone backfill icin)
  2. backend/app/core/constants.py   (ana uygulama icin)

Calistirma:
  cd backend
  pip install requests
  python generate_turkey_districts_overpass.py
"""

import requests
import json
import time
import sys
import os
from pathlib import Path

# Windows cp1254 / utf-8 karisikligini onle
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

OVERPASS = "https://overpass-api.de/api/interpreter"

# Sorgu 1: Tum iller (admin_level=4) — bounding box ile (province eslestirmesi icin)
IL_QUERY = """
[out:json][timeout:60];
area["ISO3166-1"="TR"][admin_level=2]->.tr;
relation["boundary"="administrative"]["admin_level"="4"](area.tr);
out bb tags;
"""

# Sorgu 2: Tum ilceler + admin_centre node'lari
# .rels'e kaydet, node(r.rels:"admin_centre") ile merkez node'larini cek,
# union ile birles, tek out ile cik — 400 hatasini onler
ILCE_QUERY = """
[out:json][timeout:300];
area["ISO3166-1"="TR"][admin_level=2]->.tr;
relation["boundary"="administrative"]["admin_level"="6"](area.tr)->.rels;
(
  .rels;
  node(r.rels:"admin_centre");
);
out tags members;
"""

# admin_centre yoksa fallback: ilce place node'u
PLACE_FALLBACK_QUERY = """
[out:json][timeout:120];
area["ISO3166-1"="TR"][admin_level=2]->.tr;
node["place"~"^(city|town|village)$"]["name"](area.tr);
out body;
"""


def overpass_fetch(query, desc):
    print(f"  Overpass sorgusu: {desc}...")
    for attempt in range(3):
        try:
            r = requests.post(OVERPASS, data={"data": query}, timeout=360)
            r.raise_for_status()
            elements = r.json().get("elements", [])
            print(f"    {len(elements)} eleman alindi.")
            return elements
        except Exception as e:
            wait = 30 * (attempt + 1)
            print(f"    [HATA] Deneme {attempt+1}: {e}  --  {wait}s sonra tekrar...")
            time.sleep(wait)
    print("    Overpass erisilemedi, bos liste donuluyor.")
    return []


def get_province_name(tags):
    """Relation tag'lerinden il adini bulmaya calis."""
    return (
        tags.get("is_in:province")
        or tags.get("addr:province")
        or tags.get("is_in:state")
        or None
    )


def find_province_by_bbox(lat, lon, il_elements):
    """
    Koordinatin icinde oldugu ilin adini bounding box ile bul.
    En kucuk alana sahip eslesen il tercih edilir (overlap sorununu azaltir).
    """
    candidates = []
    for el in il_elements:
        bb = el.get("bounds", {})
        if not bb:
            continue
        minlat = bb.get("minlat", 999)
        maxlat = bb.get("maxlat", -999)
        minlon = bb.get("minlon", 999)
        maxlon = bb.get("maxlon", -999)
        if minlat <= lat <= maxlat and minlon <= lon <= maxlon:
            t = el.get("tags", {})
            name = t.get("name:tr") or t.get("name") or ""
            area = (maxlat - minlat) * (maxlon - minlon)
            candidates.append((area, name))

    if not candidates:
        return ""
    # En kucuk bounding box'i olan il daha buyuk ihtimalle dogru il
    candidates.sort(key=lambda x: x[0])
    return candidates[0][1]


def normalize(name):
    return name.lower().strip()


def main():
    print("=" * 65)
    print("Turkiye Il/Ilce Koordinat Ureteci — Overpass API (v2)")
    print("DUZELTME: admin_centre node'lari kullaniliyor")
    print("=" * 65)

    # ── Iller ──────────────────────────────────────────────────────
    print("\n[1/3] Iller cekiliyor (province eslestirmesi icin)...")
    il_elements = overpass_fetch(IL_QUERY, "admin_level=4 (81 il)")
    print(f"  {len(il_elements)} il alindi.")
    time.sleep(3)

    # ── Ilceler + admin_centre node'lari ───────────────────────────
    print("\n[2/3] Ilceler ve admin_centre node'lari cekiliyor...")
    raw_elements = overpass_fetch(ILCE_QUERY, "admin_level=6 + admin_centre nodes")
    time.sleep(3)

    # Elemanlari tipine gore ayir
    relations = [e for e in raw_elements if e.get("type") == "relation"]
    nodes     = {e["id"]: e for e in raw_elements if e.get("type") == "node"}

    print(f"  {len(relations)} ilce relation, {len(nodes)} admin_centre node alindi.")

    # ── Place node'lari (fallback) ─────────────────────────────────
    print("\n[3/3] Place node'lari cekiliyor (fallback icin)...")
    place_elements = overpass_fetch(PLACE_FALLBACK_QUERY, "place=city/town/village")
    # Place node'larini isme gore indeksle
    place_by_name = {}
    for pe in place_elements:
        if pe.get("type") != "node":
            continue
        ptags = pe.get("tags", {})
        pname = ptags.get("name:tr") or ptags.get("name") or ""
        if pname:
            place_by_name[normalize(pname)] = (pe["lat"], pe["lon"])

    print(f"  {len(place_by_name)} place node indekslendi.")

    # ── Her ilce icin koordinat belirle ────────────────────────────
    cities = []
    stats = {"admin_centre": 0, "place_fallback": 0, "bbox_center": 0, "skipped": 0}

    for rel in relations:
        tags = rel.get("tags", {})
        members = rel.get("members", [])

        name = tags.get("name:tr") or tags.get("name") or ""
        if not name:
            stats["skipped"] += 1
            continue

        lat, lon = None, None
        coord_source = None

        # 1. Oncelik: admin_centre uye node'u
        for member in members:
            if member.get("role") == "admin_centre" and member.get("type") == "node":
                node_id = member.get("ref")
                node = nodes.get(node_id)
                if node:
                    lat = node["lat"]
                    lon = node["lon"]
                    coord_source = "admin_centre"
                    break

        # 2. Fallback: ayni isimde place node'u var mi?
        if lat is None:
            place_coords = place_by_name.get(normalize(name))
            if place_coords:
                lat, lon = place_coords
                coord_source = "place_fallback"

        # 3. Son care: relation'in center'i (bbox merkezi — hata paylidir)
        if lat is None:
            center = rel.get("center", {})
            if center:
                lat = center.get("lat")
                lon = center.get("lon")
                coord_source = "bbox_center"

        if lat is None or lon is None:
            stats["skipped"] += 1
            continue

        # Turkey sinir kontrolu
        if not (35.5 <= lat <= 42.5 and 25.5 <= lon <= 45.0):
            stats["skipped"] += 1
            continue

        # Province belirle
        province = get_province_name(tags)
        if not province:
            province = find_province_by_bbox(lat, lon, il_elements)
        if not province:
            province = name

        is_center = normalize(name) == normalize(province)

        cities.append({
            "name": name,
            "province": province,
            "district": None if is_center else name,
            "lat": round(lat, 4),
            "lon": round(lon, 4),
            "_source": coord_source,  # Debug icin, JSON'a yazilacak
        })
        stats[coord_source] += 1

    # Province + ada gore sirala
    cities.sort(key=lambda c: (c["province"], c["name"]))

    print(f"\n  Toplam konum     : {len(cities)}")
    print(f"  admin_centre     : {stats['admin_centre']} (en dogru)")
    print(f"  place fallback   : {stats['place_fallback']}")
    print(f"  bbox_center      : {stats['bbox_center']} (hata paylidir)")
    print(f"  Atlanani         : {stats['skipped']}")

    if stats["bbox_center"] > 50:
        print(f"\n  [UYARI] {stats['bbox_center']} ilce icin admin_centre bulunamadi.")
        print("  Bu ilcelerin koordinatlari yaklasik olabilir.")

    if len(cities) < 500:
        print("\n  [UYARI] 500'den az konum bulundu!")
        print("  Overpass API gecici sorun yasaniyor olabilir.")
        print("  Bir sure sonra tekrar deneyin.")

    # _source alanini temizle (JSON'a gitmesi icin debug bitti)
    cities_clean = [{k: v for k, v in c.items() if k != "_source"} for c in cities]

    # ── JSON kaydet ────────────────────────────────────────────────
    json_out = Path(__file__).parent / "turkey_districts.json"
    with open(json_out, "w", encoding="utf-8") as f:
        json.dump(cities_clean, f, ensure_ascii=False, indent=2)
    print(f"\n  JSON: {json_out}")

    # ── constants.py guncelle ──────────────────────────────────────
    py_out = Path(__file__).parent / "app" / "core" / "constants.py"
    _write_constants(py_out, cities_clean)
    print(f"  constants.py: {py_out}")

    print(f"\nTamamlandi! {len(cities)} konum hazir.")
    print(f"  - {stats['admin_centre']} ilcenin koordinati gercek sehir merkezine isaret ediyor.")
    print("Sonraki adim: python distribute.py --computers 4")
    print("=" * 65)


def _write_constants(path, cities):
    lines = [
        '"""\n',
        'Turkiye il ve ilce merkezleri\n',
        'Overpass API ile uretildi (admin_centre node kullaniliyor)\n',
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
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)


if __name__ == "__main__":
    main()

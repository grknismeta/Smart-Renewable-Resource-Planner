#!/usr/bin/env python3
"""
download_osm_borders.py
========================
Türkiye il ve ilçe sınırlarını OpenStreetMap Overpass API'den indir.

Basemap (OpenFreeMap Liberty) OSM verisiyle besleniyor. Bu script aynı
kaynaktan sınır poligonlarını çekerek GADM kaynaklı geometri kaymasını
tamamen ortadan kaldırır.

Çalıştırma:
    cd backend
    python scripts/download_osm_borders.py

Çıktı:
    data/vector/turkey_provinces_osm.geojson   (81 il)
    data/vector/turkey_districts_osm.geojson   (~960 ilçe)

Gereksinimler:
    pip install requests geopandas shapely
    (geopandas zaten requirements.txt içinde)
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import requests
from shapely.geometry import LineString, mapping
from shapely.ops import polygonize, unary_union
import geopandas as gpd

# Windows konsol encoding
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

OVERPASS_PRIMARY = "https://overpass-api.de/api/interpreter"
OVERPASS_MIRROR  = "https://overpass.kumi.systems/api/interpreter"

OUT_DIR = Path(__file__).parent.parent / "data" / "vector"

# ─── Overpass sorguları ────────────────────────────────────────────────────────

# İller: admin_level=4 — full polygon geometry dahil
PROVINCE_QUERY = """
[out:json][timeout:300];
area["ISO3166-1"="TR"][admin_level=2]->.tr;
(
  relation["boundary"="administrative"]["admin_level"="4"](area.tr);
);
out body geom;
"""

# İlçeler: admin_level=6 — full polygon geometry dahil
# NOT: Bu sorgu büyük veri döndürür (~50-150 MB), birkaç dakika sürebilir.
DISTRICT_QUERY = """
[out:json][timeout:600];
area["ISO3166-1"="TR"][admin_level=2]->.tr;
(
  relation["boundary"="administrative"]["admin_level"="6"](area.tr);
);
out body geom;
"""

# ─── Yardımcı fonksiyonlar ─────────────────────────────────────────────────────

def _overpass_fetch(query: str, desc: str, timeout_http: int = 360) -> list[dict]:
    """Overpass API'ye sorgu gönder; birincil sunucu başarısız olursa mirror'ı dene."""
    for url in (OVERPASS_PRIMARY, OVERPASS_MIRROR):
        for attempt in range(2):
            try:
                print(f"  [{attempt+1}/2] {url}")
                r = requests.post(url, data={"data": query}, timeout=timeout_http)
                r.raise_for_status()
                elements = r.json().get("elements", [])
                print(f"  → {len(elements)} element alındı")
                return elements
            except Exception as exc:
                wait = 20 * (attempt + 1)
                print(f"  ✗ {exc} — {wait}s bekleniyor…")
                time.sleep(wait)
        print(f"  Sunucu {url} yanıt vermedi, mirror deneniyor…")

    raise RuntimeError("Her iki Overpass sunucusu da yanıt vermedi.")


def _relation_to_shapely(el: dict):
    """
    Overpass 'out body geom;' çıktısındaki relation elementini Shapely
    Polygon/MultiPolygon'a dönüştür.

    members[].geometry alanı inline way koordinatlarını içerir.
    Outer ring'ler polygonize ile birleştirilir; inner ring'ler (delikler) çıkarılır.
    """
    outer_lines: list[LineString] = []
    inner_lines: list[LineString] = []

    for member in el.get("members", []):
        if member.get("type") != "way":
            continue
        raw = member.get("geometry", [])
        if len(raw) < 2:
            continue
        coords = [(pt["lon"], pt["lat"]) for pt in raw]
        line = LineString(coords)
        role = member.get("role", "")
        if role == "outer":
            outer_lines.append(line)
        elif role == "inner":
            inner_lines.append(line)

    if not outer_lines:
        return None

    # Outer ring'leri birleştir (bölünmüş way'ler için polygonize kullan)
    outer_polys = list(polygonize(outer_lines))
    if not outer_polys:
        return None

    geom = unary_union(outer_polys)

    # Inner ring'leri (delikler) çıkar
    if inner_lines:
        holes = list(polygonize(inner_lines))
        if holes:
            geom = geom.difference(unary_union(holes))

    return geom


def _clean_name(tags: dict) -> str:
    """OSM etiketlerinden temiz Türkçe il/ilçe adı çıkar."""
    name = (
        tags.get("name:tr")
        or tags.get("name")
        or tags.get("official_name:tr")
        or ""
    )
    # Gereksiz ekleri kaldır
    for suffix in (" İli", " ili", " İlçesi", " ilçesi", " Province", " District", " il", " ilce"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return name.strip()


def _elements_to_gdf(elements: list[dict], name_col: str = "NAME_1") -> gpd.GeoDataFrame:
    """Overpass element listesinden GeoDataFrame oluştur."""
    rows = []
    skipped = 0
    for el in elements:
        if el.get("type") != "relation":
            continue
        geom = _relation_to_shapely(el)
        if geom is None or geom.is_empty:
            skipped += 1
            continue
        tags = el.get("tags", {})
        rows.append({
            name_col: _clean_name(tags),
            "osm_id": el["id"],
            "geometry": geom,
        })
    if skipped:
        print(f"  ⚠ {skipped} relation geometrisi oluşturulamadı (atlandı)")
    return gpd.GeoDataFrame(rows, crs="EPSG:4326")


# ─── Ana indirme fonksiyonları ─────────────────────────────────────────────────

def download_provinces() -> gpd.GeoDataFrame:
    print("\n━━━ İller (admin_level=4) ━━━")
    elements = _overpass_fetch(PROVINCE_QUERY, "iller", timeout_http=360)
    gdf = _elements_to_gdf(elements, name_col="NAME_1")
    print(f"  → {len(gdf)} il poligonu oluşturuldu")
    return gdf


def download_districts(provinces_gdf: gpd.GeoDataFrame) -> gpd.GeoDataFrame:
    print("\n━━━ İlçeler (admin_level=6) ━━━")
    print("  Bu sorgu büyük veri döndürür, 3-8 dakika sürebilir…")
    elements = _overpass_fetch(DISTRICT_QUERY, "ilçeler", timeout_http=720)
    gdf = _elements_to_gdf(elements, name_col="NAME_2")
    print(f"  → {len(gdf)} ilçe poligonu oluşturuldu")

    # Spatial join: her ilçeye parent ili ata (NAME_1 sütunu ekle)
    print("  Spatial join: ilçe → il eşlemesi yapılıyor…")
    provinces_slim = provinces_gdf[["NAME_1", "geometry"]].copy()

    # Centroid hesabı için önce metrik CRS'e çevir (UTM Zone 36N — Türkiye)
    # Coğrafi CRS (EPSG:4326) üzerinde centroid hesabı hatalı sonuç verir.
    gdf_proj = gdf.to_crs(epsg=32636)
    gdf_centroids = gdf[["NAME_2", "osm_id"]].copy()
    gdf_centroids["geometry"] = gdf_proj.geometry.centroid.to_crs(epsg=4326)
    gdf_centroids = gpd.GeoDataFrame(gdf_centroids, crs="EPSG:4326")

    joined = gpd.sjoin(
        gdf_centroids[["NAME_2", "osm_id", "geometry"]],
        provinces_slim,
        how="left",
        predicate="within",
    )
    # sjoin ile bir ilçe birden fazla ile eşleşebilir; indeks başına ilk eşleşmeyi al
    joined = joined[~joined.index.duplicated(keep="first")]
    gdf["NAME_1"] = joined["NAME_1"]

    # Hâlâ eşleşmeyenler için tam geometri ile dene (sınır üzerindeki ilçeler)
    missing_mask = gdf["NAME_1"].isna()
    if missing_mask.any():
        fallback = gpd.sjoin(
            gdf[missing_mask][["NAME_2", "osm_id", "geometry"]],
            provinces_slim,
            how="left",
            predicate="intersects",
        )
        # "intersects" birden fazla eşleşme üretebilir; indeks başına ilk eşleşmeyi al
        fallback = fallback[~fallback.index.duplicated(keep="first")]
        # .values yerine indeks bazlı atama — satır sayısı uyumsuzluğunu önler
        gdf.loc[fallback.index, "NAME_1"] = fallback["NAME_1"]
        still_missing = gdf["NAME_1"].isna().sum()
        if still_missing:
            print(f"  ⚠ {still_missing} ilçe için parent il atanamadı (boş bırakıldı)")

    return gdf


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("Türkiye OSM Sınır İndirici")
    print("Kaynak: OpenStreetMap Overpass API")
    print("Hedef : data/vector/turkey_*_osm.geojson")
    print("=" * 60)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    t_start = time.time()

    # ── İller ──────────────────────────────────────────────────────
    out_prov = OUT_DIR / "turkey_provinces_osm.geojson"
    if out_prov.exists():
        print(f"\n━━━ İller (admin_level=4) ━━━")
        print(f"  ↩ Mevcut dosya bulundu, yeniden indirilmiyor: {out_prov.name}")
        provinces = gpd.read_file(out_prov)
        print(f"  → {len(provinces)} il yüklendi")
    else:
        provinces = download_provinces()
        provinces.to_file(out_prov, driver="GeoJSON")
        print(f"  ✓ {out_prov.name}  ({out_prov.stat().st_size // 1024} KB)")

    # ── İlçeler ────────────────────────────────────────────────────
    out_dist = OUT_DIR / "turkey_districts_osm.geojson"
    if out_dist.exists():
        print(f"\n━━━ İlçeler (admin_level=6) ━━━")
        print(f"  ↩ Mevcut dosya bulundu, yeniden indirilmiyor: {out_dist.name}")
    else:
        time.sleep(5)  # Overpass rate limit için kısa bekleme
        districts = download_districts(provinces)
        districts.to_file(out_dist, driver="GeoJSON")
        print(f"  ✓ {out_dist.name}  ({out_dist.stat().st_size // 1024} KB)")

    elapsed = time.time() - t_start
    print(f"\n✅ Tamamlandı — {elapsed:.0f} saniye")
    print("\nSonraki adım:")
    print("  Backend'i yeniden başlatın (veya /geo/borders/* cache'ini temizleyin)")
    print("  Yeni OSM sınırlar basemap ile mükemmel hizalanmış olacak.")


if __name__ == "__main__":
    main()

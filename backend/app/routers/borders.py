"""
Il/ilçe/bölge sınırları API
=============================
Önce OSM GeoJSON dosyalarını (download_osm_borders.py ile üretilir) kullanır;
yoksa GADM shapefile'larına (gadm41_TUR_1/2.shp) geri döner.

OSM verileri basemap (OpenFreeMap Liberty) ile aynı kaynaktan geldiğinden
geometri kayması yaşanmaz.

GET /geo/borders/provinces  → 81 il sınırı
GET /geo/borders/districts  → ~960 ilçe sınırı
GET /geo/borders/regions    → 7 coğrafi bölge sınırı (il dissolve)
"""

import json
import logging
import unicodedata
from pathlib import Path

from fastapi import APIRouter
from fastapi.responses import Response

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/geo/borders", tags=["🗺️ Borders"])

_VECTOR_DIR = Path(__file__).parent.parent.parent / "data" / "vector"
_EMPTY_FC   = json.dumps({"type": "FeatureCollection", "features": []})

# ── Lazy cache ────────────────────────────────────────────────────────────────
_cache: dict[str, str] = {}

# ── Türkiye 7 Coğrafi Bölge → OSM NAME_1 eşlemesi ────────────────────────────
# OSM name:tr / name tag değerleri — _ascii_key() ile normalize edilerek eşleştirilir.
# Not: GADM fallback için de çalışır; ASCII normalizasyon GADM kısaltmalarının büyük
#      kısmını yakalar (örn. "İstanbul"→"istanbul" = "Istanbul"→"istanbul").
#      GADM-spesifik typo'lar (Kinkkale, Zinguldak, K.Maras, Afyon) artık kullanılmıyor.
TURKEY_REGIONS: dict[str, list[str]] = {
    "Marmara": [
        "İstanbul", "Tekirdağ", "Edirne", "Kırklareli",
        "Bursa", "Kocaeli", "Sakarya", "Bilecik",
        "Balıkesir", "Çanakkale", "Yalova",
    ],
    "Ege": [
        "İzmir", "Manisa", "Aydın", "Muğla",
        "Denizli", "Uşak", "Afyonkarahisar", "Kütahya",
    ],
    "Akdeniz": [
        "Antalya", "Isparta", "Burdur", "Mersin",
        "Adana", "Hatay", "Osmaniye", "Kahramanmaraş",
    ],
    "İç Anadolu": [
        "Ankara", "Konya", "Eskişehir", "Kırıkkale", "Kırşehir",
        "Nevşehir", "Niğde", "Aksaray", "Karaman", "Sivas",
        "Yozgat", "Çorum", "Kayseri", "Çankırı",
    ],
    "Karadeniz": [
        "Zonguldak", "Bartın", "Karabük", "Bolu", "Düzce",
        "Kastamonu", "Sinop", "Samsun", "Ordu", "Giresun",
        "Trabzon", "Rize", "Artvin", "Gümüşhane", "Bayburt",
        "Amasya", "Tokat",
    ],
    "Doğu Anadolu": [
        "Erzurum", "Erzincan", "Ağrı", "Kars", "Ardahan",
        "Iğdır", "Van", "Muş", "Bitlis", "Bingöl",
        "Tunceli", "Elazığ", "Malatya", "Hakkari", "Adıyaman",
    ],
    "Güneydoğu Anadolu": [
        "Gaziantep", "Şanlıurfa", "Diyarbakır", "Mardin",
        "Şırnak", "Siirt", "Batman", "Kilis",
    ],
}

# OSM'de Türkiye admin_level=4 sorgusu bazı il olmayan relation'ları da döndürür.
# Bunları il listesinden filtrele.
_OSM_NON_PROVINCE_NAMES = {"Ege"}

def _ascii_key(name: str) -> str:
    """'Gümüşhane' → 'gumushane', 'İstanbul' → 'istanbul' vb.
    GADM NAME_1 değerleri ASCII veya UTF-8 olabilir; normalize ederek karşılaştırıyoruz."""
    return unicodedata.normalize("NFKD", name.lower()).encode("ascii", "ignore").decode("ascii").strip()


# İl → bölge ters eşlemesi — ASCII-normalized anahtarlarla (case/accent insensitive)
_PROVINCE_TO_REGION: dict[str, str] = {
    _ascii_key(prov): region
    for region, provinces in TURKEY_REGIONS.items()
    for prov in provinces
}


def _resolve_source_path(level: int) -> tuple[Path, bool]:
    """
    Veri dosyasını çöz: OSM GeoJSON varsa tercih et, yoksa GADM'a geri dön.
    Returns: (path, is_osm)
    """
    osm_name  = {1: "turkey_provinces_osm.geojson", 2: "turkey_districts_osm.geojson"}
    gadm_name = {1: "gadm41_TUR_1.shp",             2: "gadm41_TUR_2.shp"}
    osm_path  = _VECTOR_DIR / osm_name[level]
    gadm_path = _VECTOR_DIR / gadm_name[level]
    if osm_path.exists():
        return osm_path, True
    return gadm_path, False


def _load_geojson(level: int, tolerance: float) -> str:
    """
    İl (level=1) veya ilçe (level=2) sınırlarını yükle, basitleştir, GeoJSON döndür.
    OSM GeoJSON dosyası mevcutsa onu kullanır (basemap ile mükemmel hizalama).
    Aksi halde GADM shapefile'ına geri döner.
    Sonuç belleğe alınır (cache).
    """
    key = str(level)
    if key in _cache:
        return _cache[key]

    src_path, is_osm = _resolve_source_path(level)
    if not src_path.exists():
        logger.warning("Sınır verisi bulunamadı (level=%d): %s", level, src_path)
        return _EMPTY_FC

    source_label = "OSM" if is_osm else "GADM"

    try:
        import geopandas as gpd

        logger.info("%s verisi yükleniyor (level=%d): %s", source_label, level, src_path)
        gdf = gpd.read_file(src_path)

        if gdf.crs is not None and gdf.crs.to_epsg() != 4326:
            gdf = gdf.to_crs(epsg=4326)

        # Gerekli sütunları seç (OSM'de GID_* sütunları olmayabilir — sorun değil)
        if level == 1:
            keep = [c for c in ["NAME_1", "GID_1"] if c in gdf.columns]
        else:
            keep = [c for c in ["NAME_1", "NAME_2", "GID_2"] if c in gdf.columns]
        gdf = gdf[keep + ["geometry"]].copy()

        # OSM il olmayan relation'ları filtrele (örn. "Ege" — il değil, coğrafi bölge)
        if level == 1 and is_osm and "NAME_1" in gdf.columns:
            before = len(gdf)
            gdf = gdf[~gdf["NAME_1"].isin(_OSM_NON_PROVINCE_NAMES)].copy()
            removed = before - len(gdf)
            if removed:
                logger.info("OSM il olmayan %d relation filtrelendi: %s", removed,
                            list(_OSM_NON_PROVINCE_NAMES))

        # İllere bölge adı ekle (JS filtreleme için kullanılır)
        # ASCII normalize edilerek eşleştirme: GADM "Gumushane" ve OSM "Gümüşhane"
        # her ikisi de "gumushane" → doğru bölgeye eşlenir
        if level == 1:
            gdf["REGION"] = gdf["NAME_1"].map(
                lambda x: _PROVINCE_TO_REGION.get(_ascii_key(x), "Diğer")
            )
            # OSM bazen Türkiye dışı ilçe/bölge relation'larını (örn. Yunan adaları
            # "Περιφερειακή Ενότητα ...") admin_level=4 sonucuna karıştırır.
            # Bilinen 81 il dışındakiler "Diğer"e düşer → hem İl Modu'nda hayalet
            # poligon, hem Bölge Modu'nda sahte bir "Diğer" dissolve'u yaratır.
            before = len(gdf)
            gdf = gdf[gdf["REGION"] != "Diğer"].copy()
            dropped = before - len(gdf)
            if dropped:
                logger.info(
                    "Türkiye dışı %d il/relation filtrelendi (REGION=='Diğer')",
                    dropped,
                )

        # Geometri basitleştirme (OSM verisi zaten optimize — küçük tolerans yeterli)
        tol = tolerance * 0.5 if is_osm else tolerance
        gdf["geometry"] = gdf["geometry"].simplify(tol, preserve_topology=True)

        result = gdf.to_json(ensure_ascii=True)
        _cache[key] = result
        logger.info(
            "%s hazır (level=%d, features=%d, ~%.0fKB)",
            source_label, level, len(gdf), len(result) / 1024,
        )
        return result

    except Exception as exc:
        logger.error("%s yükleme hatası (level=%d): %s", source_label, level, exc)
        return _EMPTY_FC


def _load_regions_geojson() -> str:
    """
    7 coğrafi bölge poligonunu döndürür.
    İl poligonları bölgeye göre dissolve edilir.
    OSM GeoJSON varsa tercih eder, yoksa GADM'a geri döner.
    Sonuç cache'lenir.
    """
    key = "regions"
    if key in _cache:
        return _cache[key]

    src_path, is_osm = _resolve_source_path(level=1)
    if not src_path.exists():
        logger.warning("Bölge için veri dosyası bulunamadı: %s", src_path)
        return _EMPTY_FC

    try:
        import geopandas as gpd

        gdf = gpd.read_file(src_path)
        if gdf.crs is not None and gdf.crs.to_epsg() != 4326:
            gdf = gdf.to_crs(epsg=4326)

        gdf = gdf[["NAME_1", "geometry"]].copy()
        gdf["REGION"] = gdf["NAME_1"].map(
            lambda x: _PROVINCE_TO_REGION.get(_ascii_key(x), "Diğer")
        )

        # Türkiye dışı relation'lar "Diğer"e düşer → dissolve öncesi at,
        # aksi halde Bölge Modu'nda Yunan adaları vb. "Diğer" bölgesi olarak çıkar.
        before = len(gdf)
        gdf = gdf[gdf["REGION"] != "Diğer"].copy()
        dropped = before - len(gdf)
        if dropped:
            logger.info(
                "Bölge dissolve öncesi Türkiye dışı %d relation atıldı", dropped,
            )

        # Bölgeye göre dissolve et (union)
        regions_gdf = gdf.dissolve(by="REGION", as_index=False)[["REGION", "geometry"]]

        # OSM verisi daha doğru geometriye sahip — daha düşük tolerans kullan
        tol = 0.0015 if is_osm else 0.003
        regions_gdf["geometry"] = regions_gdf["geometry"].simplify(tol, preserve_topology=True)

        result = regions_gdf.to_json(ensure_ascii=True)
        _cache[key] = result
        logger.info(
            "Bölge GeoJSON hazır (%s, %d bölge, ~%.0fKB)",
            "OSM" if is_osm else "GADM", len(regions_gdf), len(result) / 1024,
        )
        return result

    except Exception as exc:
        logger.error("Bölge GeoJSON yükleme hatası: %s", exc)
        return _EMPTY_FC


# ── Endpoint'ler ───────────────────────────────────────────────────────────────

@router.get("/provinces", summary="81 il sınırı (GADM TUR-1)")
def get_province_borders():
    """
    Türkiye'nin 81 il sınırını GeoJSON FeatureCollection olarak döndürür.
    Her feature'da NAME_1 (il adı) ve REGION (bölge adı) özellikleri bulunur.
    Geometri tolerance=0.002° ile basitleştirilmiştir (~200 m hassasiyet).
    """
    return Response(
        content=_load_geojson(level=1, tolerance=0.002),
        media_type="application/geo+json",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.get("/districts", summary="957 ilçe sınırı (GADM TUR-2)")
def get_district_borders():
    """
    Türkiye'nin ilçe sınırlarını GeoJSON FeatureCollection olarak döndürür.
    Her feature'da NAME_1 (il) ve NAME_2 (ilçe) özellikleri bulunur.
    Geometri tolerance=0.001° ile basitleştirilmiştir (~100 m hassasiyet).
    """
    return Response(
        content=_load_geojson(level=2, tolerance=0.001),
        media_type="application/geo+json",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.post("/cache/clear", summary="Sınır cache'ini temizle")
def clear_borders_cache():
    """Backend restart gerektirmeden cache'i temizler. Veri güncellemelerinden sonra kullanılır."""
    cleared = list(_cache.keys())
    _cache.clear()
    logger.info("Borders cache temizlendi: %s", cleared)
    return {"cleared": cleared, "message": "Cache temizlendi. Sonraki istek dosyaları yeniden yükleyecek."}


@router.get("/regions", summary="7 coğrafi bölge sınırı")
def get_region_borders():
    """
    Türkiye'nin 7 coğrafi bölge sınırını GeoJSON olarak döndürür.
    İl poligonları bölgeye göre birleştirilerek (dissolve) oluşturulur.
    Her feature'da REGION (bölge adı) özelliği bulunur.
    """
    return Response(
        content=_load_regions_geojson(),
        media_type="application/geo+json",
        headers={"Cache-Control": "public, max-age=86400"},
    )

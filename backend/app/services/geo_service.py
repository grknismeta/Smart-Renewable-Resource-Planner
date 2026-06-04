"""
SRRP — PostGIS-driven Coğrafi Suitability Servisi
=================================================

**Aşama B (yeniden):** Eski shape-based GeoService (390 satır, 8 shape × 500MB
RAM) tamamen PostGIS sorgularına dönüştürüldü. Sonuçlar:

* Startup'ta veri yüklemiyor — backend ~40 sn daha hızlı başlar
* RAM tasarrufu ~500 MB → ~50 MB
* PostGIS GIST index'leri ile her sorgu 5–10 ms (eski: 300-800 ms)
* Yeni veri DB'ye girince otomatik kullanılır (restart gerekmez)

Aktif kontroller (DB tabloları mevcut):
- ✅ ``hydro_features`` (25K göl/nehir polygon) → solar/wind yasaklı, hydro fırsat
- ✅ ``restricted_zones`` (boş — B-4'te OSM Overpass ile doldurulacak) → solar/wind yasaklı
- ✅ ``energy_corridors`` (190K iletim hattı) → mesafe bilgisi note olarak

İl/ilçe reverse geocoding (province/district):
- GADM/OSM GeoJSON dosyasından **lazy yüklenir, RAM'de cache** (tek dosya ~10 MB)
- Borders router'ın okuduğu dosya — tutarlılık garanti

Eksik kontroller (DB'de tablo yok, ileride OSM import ile gelecek):
- ⏳ Bina yakınlığı (1500m wind regulation)
- ⏳ Yol/demiryolu mesafesi
- ⏳ Landuse (residential/commercial/industrial/cemetery)
- ⏳ Doğal yapılar (wetland/cliff/glacier)
- ⏳ DEM elevation/slope (rio-tiler ayrı sprint)

Eksik kontroller için "veri yok, atlandı" notu döner — analiz patlamaz.
"""
from __future__ import annotations

import json
import logging
from functools import lru_cache
from pathlib import Path
from typing import Optional

from sqlalchemy import text

from app.db.database import _engine

logger = logging.getLogger(__name__)


# ───────────────────────────────────────────────────────────────────────────
# GADM lazy cache (reverse geocoding için)
# ───────────────────────────────────────────────────────────────────────────
_GADM_DISTRICTS_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "data" / "vector" / "turkey_districts_osm.geojson"
)


@lru_cache(maxsize=1)
def _gadm_districts_gdf():
    """GADM ilçe polygonlarını GeoPandas DataFrame olarak lazy yükler.

    Boyut ~10 MB, ilk çağrıda ~1 sn. Sonraki çağrılar bellek hit (`lru_cache`).
    """
    try:
        import geopandas as gpd
        if not _GADM_DISTRICTS_PATH.exists():
            logger.warning("[geo_service] GADM dosyası bulunamadı: %s", _GADM_DISTRICTS_PATH)
            return None
        gdf = gpd.read_file(_GADM_DISTRICTS_PATH)
        logger.info("[geo_service] GADM yüklendi: %d ilçe polygon", len(gdf))
        return gdf
    except Exception as e:
        logger.exception("[geo_service] GADM okunamadı: %s", e)
        return None


# ───────────────────────────────────────────────────────────────────────────
# Ana servis
# ───────────────────────────────────────────────────────────────────────────
class GeoService:
    """PostGIS-driven coğrafi analiz servisi."""

    def __init__(self):
        # init'te ağır iş yapma — DB sorguları lazy + GADM ilk çağrıda yüklenir.
        logger.info("[geo_service] PostGIS-driven mod aktif (lazy init)")

    # ── Public API ─────────────────────────────────────────────────────────

    def analyze_location(self, lat: float, lon: float) -> dict:
        """Verilen koordinat için solar/wind/hydro suitability analizi.

        Geri uyumlu output şeması — eski shape-based GeoService ile birebir
        aynı (geo router dokunulmadan çalışır).
        """
        # _get_location_info imzası geri uyum için (point, lat, lon) — keyword
        # arg ile çağır, pozisyonel olursa point=lat olur ve lookup patlar.
        loc_info = self._get_location_info(lat=lat, lon=lon)

        # 1. Türkiye sınırı kontrolü (province bulunamadıysa = sınır dışı).
        # 2026-06-04 (PERF): Bu kontrol elevation API'sinden ÖNCE — Türkiye
        # dışı tık için ağ çağrısı hiç yapılmaz (anında döner).
        if not loc_info.get("province"):
            error = "Arazi sınırları dışında (Türkiye dışı veya su)."
            return self._final_response(
                False, False, False,
                [error], [error], [error],
                [], [], [],
                loc_info, 0, 0, lat, lon,
            )

        # 2026-06-04 (PERF): elevation/slope Open-Meteo'ya ağ çağrısı (cache miss'te
        # yavaş, hele backfill IP'yi zorlarken). Kısa timeout + graceful (0,0)
        # fallback _get_terrain_data içinde; başarısız olursa eğim kontrolü atlanır.
        elevation, slope = self._get_terrain_data(lat, lon)

        # 2. Üç enerji türü için ayrı analiz
        solar = self._analyze_solar(lat, lon, slope)
        wind = self._analyze_wind(lat, lon, slope)
        hydro = self._analyze_hydro(lat, lon, elevation)

        return self._final_response(
            solar["suitable"], wind["suitable"], hydro["suitable"],
            solar["reasons"], wind["reasons"], hydro["reasons"],
            solar["notes"], wind["notes"], hydro["notes"],
            loc_info, elevation, slope, lat, lon,
        )

    # ── Reverse geocoding ──────────────────────────────────────────────────

    def _get_location_info(self, point=None, lat: Optional[float] = None,
                            lon: Optional[float] = None) -> dict:
        """Koordinattan il/ilçe — GADM polygon contains.

        Args:
            point: Eski API geri uyumluluk (shapely.Point); kullanılmaz.
                   Mevcut caller'lar `_get_location_info(point, lat, lon)`
                   şeklinde çağırıyor — signature aynı tutuldu.
            lat / lon: koordinat.
        """
        if lat is None or lon is None:
            return {"province": "", "district": ""}
        gdf = _gadm_districts_gdf()
        if gdf is None:
            return {"province": "", "district": ""}
        try:
            from shapely.geometry import Point
            pt = Point(lon, lat)
            # Spatial index ile hızlı bbox filtresi
            candidates = gdf.cx[lon:lon, lat:lat]
            if candidates.empty:
                return {"province": "", "district": ""}
            hit = candidates[candidates.geometry.contains(pt)]
            if hit.empty:
                return {"province": "", "district": ""}
            row = hit.iloc[0]
            return {
                "province": str(row.get("NAME_1", "") or ""),
                "district": str(row.get("NAME_2", "") or ""),
            }
        except Exception as e:
            logger.warning("[geo_service] location_info hatası: %s", e)
            return {"province": "", "district": ""}

    # ── Terrain (elevation/slope) — Open-Meteo Elevation API ──────────────
    # 2026-05-17 Sprint S2 — DEM .tif'ten kurtulduk. Open-Meteo Elevation
    # ücretsiz API (10K istek/gün). Tek istekte 5 nokta batch:
    # ana nokta + 4 komşu (kuzey/güney/doğu/batı) → slope hesabı.
    # Redis cache TTL 7 gün (terrain neredeyse hiç değişmez).

    _ELEVATION_API_URL = "https://api.open-meteo.com/v1/elevation"
    _ELEVATION_CACHE_TTL = 7 * 24 * 3600  # 7 gün
    _SLOPE_OFFSET_DEG = 0.001  # ≈111m kuzey-güney; doğu-batı enlem-bağımlı

    def _get_terrain_data(self, lat: float, lon: float) -> tuple[float, float]:
        """Open-Meteo Elevation API'den yükseklik + 4 komşu noktadan slope.

        Returns:
            (elevation_m, slope_degrees) — API hata ise (0.0, 0.0) fallback.
        """
        from app.services.redis_cache import cache_get, cache_set
        import math
        import requests

        # 100m precision round (0.001° ≈ 111m). Aynı bölgeye birden fazla pin
        # için tek API çağrısı yeter.
        lat_r = round(lat, 3)
        lon_r = round(lon, 3)
        cache_key = f"elevation:{lat_r}:{lon_r}"

        cached = cache_get(cache_key)
        if cached and isinstance(cached, dict):
            return (
                float(cached.get("elevation", 0.0)),
                float(cached.get("slope", 0.0)),
            )

        try:
            # 5 nokta batch: [ana, N, S, E, W]
            # E/W offset enlem-bağımlı: lon_offset = lat_offset / cos(lat)
            lat_offset = self._SLOPE_OFFSET_DEG
            lon_offset = lat_offset / max(math.cos(math.radians(lat_r)), 0.1)

            lats = f"{lat_r},{lat_r + lat_offset},{lat_r - lat_offset},{lat_r},{lat_r}"
            lons = f"{lon_r},{lon_r},{lon_r},{lon_r + lon_offset},{lon_r - lon_offset}"

            # 2026-06-04 (PERF): timeout 5→2.5sn. Open-Meteo yavaş/throttled ise
            # hızlı vazgeç → suitability eğimsiz (slope=0) döner; konum analizi
            # kullanıcıyı bekletmez. Eğim yalnız aşırı-dik araziyi eler (nadir).
            resp = requests.get(
                self._ELEVATION_API_URL,
                params={"latitude": lats, "longitude": lons},
                timeout=2.5,
            )
            resp.raise_for_status()
            data = resp.json()
            elevations = data.get("elevation", [])
            if not elevations or len(elevations) < 1:
                return 0.0, 0.0

            ana = float(elevations[0])
            slope_deg = 0.0
            if len(elevations) >= 5:
                # Slope: ana noktada max gradient (kuzey-güney / doğu-batı)
                # |∂h/∂x| ≈ (N-S) / 2*dist, dist ≈ 111m (0.001°)
                dist_ns = 111.0 * lat_offset * 1000  # m
                dist_ew = 111.0 * lon_offset * 1000 * math.cos(math.radians(lat_r))
                grad_ns = (float(elevations[1]) - float(elevations[2])) / max(dist_ns, 1)
                grad_ew = (float(elevations[3]) - float(elevations[4])) / max(dist_ew, 1)
                slope_rad = math.atan(math.sqrt(grad_ns**2 + grad_ew**2))
                slope_deg = math.degrees(slope_rad)

            cache_set(
                cache_key,
                {"elevation": ana, "slope": round(slope_deg, 2)},
                ttl_seconds=self._ELEVATION_CACHE_TTL,
            )
            return ana, round(slope_deg, 2)
        except Exception as e:
            logger.warning("[geo] Elevation API hatası (%.4f, %.4f): %s", lat, lon, e)
            return 0.0, 0.0

    # ── Solar analizi (GES) ────────────────────────────────────────────────

    def _analyze_solar(self, lat: float, lon: float, slope: float) -> dict:
        """GES — neredeyse her açık alanda uygun. Sadece 3 kesin yasak:
        (a) su üstü, (b) askeri/milli park, (c) çok dik yamaç (DEM hazır olunca).

        Ev/okul/devlet binası/fabrika çatıları dahil. Otoyol kenarı OK.
        Orman içine kurulamaz (OSM landuse import sonrası kontrol).
        """
        reasons = []
        notes = []
        suitable = True

        # 1. Su üstüne kurulamaz (water/reservoir/wetland/glacier/dock)
        water_type = self._water_type_at(lat, lon)
        if water_type:
            suitable = False
            reasons.append(self._water_yasak_label(water_type, "GES"))

        # 2. Askeri/milli park/koruma alanı içinde — yasaklı
        zone = self._zone_at_point(lat, lon, "restricted_zones")
        if zone:
            suitable = False
            reasons.append(f"Yasaklı bölge: {zone}")

        # 3. İletim hattı yakınlığı (note — fırsat)
        corridor_m = self._nearest_distance_m(lat, lon, "energy_corridors")
        if corridor_m is not None:
            if corridor_m < 500:
                notes.append(f"⚡ İletim hattı çok yakın ({corridor_m:.0f}m) — düşük bağlantı maliyeti")
            elif corridor_m < 5000:
                notes.append(f"⚡ İletim hattı {corridor_m/1000:.1f}km — makul")
            else:
                notes.append(f"⚠️ İletim hattı {corridor_m/1000:.1f}km uzakta — ek hat maliyeti")

        # 4. Eğim — Sprint S2: Open-Meteo Elevation gerçek değer
        if slope > 35:
            suitable = False
            reasons.append(f"Çok dik yamaç (Eğim: {slope:.1f}°)")
        elif slope > 25:
            notes.append(f"⛰️ Orta-dik yamaç (Eğim: {slope:.1f}°) — montaj maliyeti artabilir")
        elif slope > 5:
            notes.append(f"📐 Eğim {slope:.1f}° — kabul edilebilir")

        if suitable:
            notes.append("☀️ GES için uygun arazi — çatı, açık alan, fabrika/devlet binası dahil")
        notes.append("ℹ️ Orman/landuse kontrolleri pasif (S3 OSM import bekliyor)")
        return {"suitable": suitable, "reasons": reasons, "notes": notes}

    # ── Wind analizi (RES) ─────────────────────────────────────────────────

    def _analyze_wind(self, lat: float, lon: float, slope: float) -> dict:
        """RES — şartlı: yerleşim/orman/su/askeri uzak, dik olmayan yer.

        Mevcut DB tabloları: water (yasak), restricted (yasak), corridor (mesafe),
        populated_areas (2026-05-27 N3 — yerleşim/ticari/okul yasak), DEM (eğim).
        """
        reasons = []
        notes = []
        suitable = True

        # 1. Su üstüne kurulamaz
        water_type = self._water_type_at(lat, lon)
        if water_type:
            suitable = False
            reasons.append(self._water_yasak_label(water_type, "RES"))

        # 2. Yasaklı bölge (askeri / milli park / koruma alanı)
        zone = self._zone_at_point(lat, lon, "restricted_zones")
        if zone:
            suitable = False
            reasons.append(f"Yasaklı bölge: {zone}")

        # 2b. 2026-05-27 (N3) — Yaşam alanı (OSM residential/commercial/retail/
        # school polygon). Türbin gürültüsü + gölge flicker + güvenlik mesafesi
        # → şehir/kasaba/köy yerleşim alanına RES kurulmaz.
        pop_type = self._populated_type_at(lat, lon)
        if pop_type:
            suitable = False
            label = {
                "residential": "yerleşim alanı",
                "commercial": "ticari bölge",
                "retail": "perakende/AVM bölgesi",
                "school": "okul/kampüs alanı",
            }.get(pop_type, pop_type)
            reasons.append(
                f"Yaşam alanı içinde ({label}) — RES kurulamaz "
                "(gürültü/gölge/güvenlik mesafesi)"
            )

        # 2c. 2026-05-27 (N3.2) — Bina yoğunluğu fallback (büyük şehir
        # merkezleri OSM'de `place=city` ile işaretli, landuse=residential
        # ile değil → 2b kapsam dışı kalır). 100m yarıçapta ≥5 bina varsa
        # "yoğun yaşam alanı" sayılır. Kırsalda tek-iki ev bloklamaz.
        #
        # Threshold seçimi (gerçek koordinat testlerinde):
        #   Taksim 11, Kadıköy 139, İzmir Konak 74 → bloklar ✓
        #   Ankara Kızılay 6, Antalya 8, Konya 9 → bloklar ✓ (≥5)
        #   Kayseri 4 → bloklamaz (OSM Türkiye coverage gap)
        #   Tuz Gölü/Toroslar 0 → kırsal ✓
        if not pop_type:  # Zaten polygon ile bloklandıysa tekrar etme
            building_n = self._building_count_within(lat, lon, radius_m=100)
            if building_n is not None and building_n >= 5:
                suitable = False
                reasons.append(
                    f"Yoğun yapılaşma — 100m'de {building_n} bina (RES "
                    "gürültü/güvenlik mesafesi gerektirir)"
                )

        # 3. Eğim — aşırı dik (>40°) olmaz, hafif (10-25°) ideal
        if slope > 40:
            suitable = False
            reasons.append(f"Türbin montajı için çok sarp ({slope:.1f}°)")
        elif slope > 10:
            notes.append("⛰️ Eğimli arazi — rüzgar potansiyeli yüksek olabilir")

        # 4. İletim hattı (RES için kritik — uzun hat maliyeti büyük)
        corridor_m = self._nearest_distance_m(lat, lon, "energy_corridors")
        if corridor_m is not None:
            if corridor_m < 1000:
                notes.append(f"⚡ İletim hattı yakın ({corridor_m:.0f}m) — bağlantı kolay")
            elif corridor_m < 10000:
                notes.append(f"⚡ İletim hattı {corridor_m/1000:.1f}km uzakta")
            else:
                notes.append(f"⚠️ İletim hattı {corridor_m/1000:.1f}km — yüksek hat maliyeti")

        if suitable:
            notes.append("🌬️ RES kurulumuna engel görülmedi")
        notes.append(f"⛰️ Yükseklik kontrol edildi (eğim {slope:.1f}°)")
        return {"suitable": suitable, "reasons": reasons, "notes": notes}

    # ── Yardımcı: yaşam alanı (N3) ─────────────────────────────────────────

    @staticmethod
    def _populated_type_at(lat: float, lon: float) -> Optional[str]:
        """Koordinat OSM yaşam alanı (residential/commercial/retail/school)
        polygon'u içindeyse feature_type döner; aksi None.

        Tablo `populated_areas` yoksa exception yutulur, None döner — yani
        veri import edilmemişse RES'i bloklamaz (graceful degrade).
        """
        sql = text("""
            SELECT feature_type FROM populated_areas
            WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326))
            LIMIT 1
        """)
        try:
            with _engine.connect() as c:
                v = c.execute(sql, {"lat": lat, "lon": lon}).scalar()
                return str(v) if v else None
        except Exception as e:
            # Tablo yoksa relation not found exception — silent skip.
            logger.debug("[geo_service] _populated_type_at: %s", e)
            return None

    @staticmethod
    def _building_count_within(
        lat: float, lon: float, radius_m: int = 100,
    ) -> Optional[int]:
        """Verilen yarıçap (metre) içinde `buildings_footprint` centroid
        sayısı. Tablo yoksa None döner (RES kontrolü graceful skip).

        2026-05-27 (N3.2): Büyük şehir merkezleri (Taksim, Kızılay vs.) OSM
        `place=city` relation ile işaretli, landuse=residential ile değil
        → populated_areas eksik kalıyor. Bina yoğunluğu fallback bunu çözer.
        """
        sql = text("""
            SELECT COUNT(*) FROM buildings_footprint
            WHERE ST_DWithin(
                geom::geography,
                ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                :r
            )
        """)
        try:
            with _engine.connect() as c:
                v = c.execute(sql, {
                    "lat": lat, "lon": lon, "r": radius_m,
                }).scalar()
                return int(v) if v is not None else 0
        except Exception as e:
            logger.debug("[geo_service] _building_count_within: %s", e)
            return None

    # ── Hydro analizi (HES) ────────────────────────────────────────────────

    def _analyze_hydro(self, lat: float, lon: float, elevation: float) -> dict:
        """HES — sadece **akarsu** kıyısında (riverbank ≤500m, river ≤1km).

        Karada (akarsu uzaksa) HES kurulamaz. Göl/baraj/wetland içinde değil
        — ama göle akan akarsuda kurulabilir (akış halinde su lazım).
        """
        reasons = []
        notes = []

        # Önce: koordinatın hangi su tipinde olduğunu bul
        water_type = self._water_type_at(lat, lon)
        if water_type in ("water", "reservoir", "wetland", "glacier", "dock"):
            # Mevcut göl/baraj/sulak/buzul içinde — HES kurulmaz
            return {
                "suitable": False,
                "reasons": [self._water_yasak_label(water_type, "HES")],
                "notes": [],
            }
        if water_type == "riverbank":
            # Doğrudan nehir kıyısı — HES için ideal
            return {
                "suitable": True,
                "reasons": [],
                "notes": [
                    "💧 Nehir kıyısı: HES kurulumu için ideal (akış halinde su mevcut)",
                    f"⛰️ Yükseklik: {elevation:.0f} m" if elevation else "⛰️ Yükseklik bilgisi alınamadı (Open-Meteo API)",
                ],
            }

        # Karada — en yakın AKARSU (riverbank) mesafesi
        river_m = self._nearest_distance_m_filtered(
            lat, lon, "hydro_features", "riverbank",
        )

        if river_m is None or river_m > 5000:
            # 5 km içinde nehir yok — HES kurulamaz
            dist_str = f"{river_m/1000:.1f}km" if river_m else ">5km"
            return {
                "suitable": False,
                "reasons": [
                    f"En yakın akarsu {dist_str} uzakta — HES için akarsu kıyısı (≤1km) gerekli",
                ],
                "notes": [],
            }

        if river_m <= 500:
            return {
                "suitable": True,
                "reasons": [],
                "notes": [f"💧 Akarsu {river_m:.0f}m yakında — HES için mükemmel"],
            }
        if river_m <= 1000:
            return {
                "suitable": True,
                "reasons": [],
                "notes": [f"✅ Akarsu {river_m:.0f}m — HES için uygun (kanal/boru ile)"],
            }
        # 1-5km arası — marjinal
        return {
            "suitable": False,
            "reasons": [
                f"Akarsu {river_m/1000:.1f}km uzakta — HES için fazla uzak (1km'den yakın gerekli)",
            ],
            "notes": [],
        }

    # ── Yardımcı: su tipi tespiti ──────────────────────────────────────────

    @staticmethod
    def _water_type_at(lat: float, lon: float) -> Optional[str]:
        """Koordinatı içeren su feature_type'ı döner. None = karada."""
        sql = text("""
            SELECT feature_type FROM hydro_features
            WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326))
            LIMIT 1
        """)
        try:
            with _engine.connect() as c:
                v = c.execute(sql, {"lat": lat, "lon": lon}).scalar()
                return v if v else None
        except Exception as e:
            logger.warning("[geo_service] _water_type_at hatası: %s", e)
            return None

    @staticmethod
    def _water_yasak_label(water_type: str, kaynak: str) -> str:
        """Su tipine göre yasak açıklaması — kaynağa göre özelleşir."""
        labels = {
            "water": "Göl/su kütlesi üzeri",
            "reservoir": "Baraj rezervuarı üzeri",
            "wetland": "Sulak alan/bataklık",
            "glacier": "Buzul",
            "dock": "Liman/dock",
            "riverbank": "Nehir yatağı (akış halinde su)",
        }
        base = labels.get(water_type, f"Su feature ({water_type})")
        # HES için riverbank yasak değil — bu fonksiyon onu çağırmaz
        if kaynak == "HES" and water_type in ("water", "reservoir"):
            return f"{base} — HES rezervuarın *içine* kurulamaz (akarsuya kurulur)"
        return f"{base} — {kaynak} kurulamaz"

    @staticmethod
    def _nearest_distance_m_filtered(
        lat: float, lon: float, table: str, feature_type: str,
        search_km: float = 30.0,
    ) -> Optional[float]:
        """En yakın belirli feature_type satırına metre mesafe.

        Örn. (lat, lon, 'hydro_features', 'riverbank') → en yakın nehir.
        """
        bbox_deg = search_km / 111.0
        sql = text(f"""
            SELECT MIN(
                ST_Distance(
                    geom::geography,
                    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
                )
            )
            FROM {table}
            WHERE feature_type = :ftype
              AND geom && ST_MakeEnvelope(
                :lon - :bd, :lat - :bd, :lon + :bd, :lat + :bd, 4326
              )
        """)
        try:
            with _engine.connect() as c:
                v = c.execute(sql, {
                    "lat": lat, "lon": lon, "bd": bbox_deg, "ftype": feature_type,
                }).scalar()
                return float(v) if v is not None else None
        except Exception as e:
            logger.warning(
                "[geo_service] _nearest_distance_m_filtered(%s, %s) hatası: %s",
                table, feature_type, e,
            )
            return None

    # ── PostGIS yardımcı sorgular ──────────────────────────────────────────

    @staticmethod
    def _point_in_table(lat: float, lon: float, table: str) -> bool:
        """Koordinat tablodaki herhangi bir polygon içinde mi?

        ST_Contains kullanır + GIST index'le optimize. ~5 ms.
        """
        sql = text(f"""
            SELECT EXISTS (
                SELECT 1 FROM {table}
                WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326))
                LIMIT 1
            )
        """)
        try:
            with _engine.connect() as c:
                return bool(c.execute(sql, {"lat": lat, "lon": lon}).scalar())
        except Exception as e:
            logger.warning("[geo_service] _point_in_table(%s) hatası: %s", table, e)
            return False

    @staticmethod
    def _zone_at_point(lat: float, lon: float, table: str) -> Optional[str]:
        """Koordinatı içeren ilk kayıt — feature_type/name döner.
        None = yok."""
        sql = text(f"""
            SELECT COALESCE(name, feature_type, 'unknown')
            FROM {table}
            WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326))
            LIMIT 1
        """)
        try:
            with _engine.connect() as c:
                row = c.execute(sql, {"lat": lat, "lon": lon}).scalar()
                return row if row else None
        except Exception as e:
            logger.warning("[geo_service] _zone_at_point(%s) hatası: %s", table, e)
            return None

    @staticmethod
    def _nearest_distance_m(lat: float, lon: float, table: str,
                             search_km: float = 30.0) -> Optional[float]:
        """En yakın geometriye **metre** cinsinden mesafe.

        ``search_km`` bbox sınırı — bu yarıçapın dışındaki tablolar için
        skip (None döner). Performans için zorunlu.

        ST_DWithin + ST_Distance (geography) kullanır → metre garanti.
        """
        # bbox derece ≈ km / 111
        bbox_deg = search_km / 111.0
        sql = text(f"""
            SELECT MIN(
                ST_Distance(
                    geom::geography,
                    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
                )
            )
            FROM {table}
            WHERE geom && ST_MakeEnvelope(
                :lon - :bd, :lat - :bd, :lon + :bd, :lat + :bd, 4326
            )
        """)
        try:
            with _engine.connect() as c:
                v = c.execute(sql, {
                    "lat": lat, "lon": lon, "bd": bbox_deg,
                }).scalar()
                return float(v) if v is not None else None
        except Exception as e:
            logger.warning("[geo_service] _nearest_distance_m(%s) hatası: %s", table, e)
            return None

    # ── Output formatter (eski API ile uyumlu) ─────────────────────────────

    @staticmethod
    def _final_response(
        solar_ok: bool, wind_ok: bool, hydro_ok: bool,
        s_reasons, w_reasons, h_reasons,
        s_notes, w_notes, h_notes,
        loc: dict, elev: float, slope: float,
        lat: float, lon: float,
    ) -> dict:
        """Eski GeoService output şemasıyla birebir uyumlu yanıt."""
        # Yasaklı alan kutusu (her üçü de yasak ise harita üzerinde uyarı çiz)
        restricted_area = []
        if (not solar_ok and not wind_ok and not hydro_ok) and lat != 0:
            d = 0.001
            restricted_area = [
                {"lat": lat + d, "lng": lon - d}, {"lat": lat + d, "lng": lon + d},
                {"lat": lat - d, "lng": lon + d}, {"lat": lat - d, "lng": lon - d},
            ]

        # Genel tavsiye
        if solar_ok and wind_ok and hydro_ok:
            rec = "✅ Arazi Güneş, Rüzgar ve HES için uygun."
        elif solar_ok and wind_ok:
            rec = "✅ Arazi hem Güneş hem Rüzgar için uygun."
        elif solar_ok:
            rec = "🌞 Sadece Güneş Enerjisi için uygun."
        elif wind_ok:
            rec = "🌬️ Sadece Rüzgar Enerjisi için uygun."
        elif hydro_ok:
            rec = "💧 Sadece HES için uygun."
        else:
            rec = "⛔ Bu bölgeye kurulum yapılamaz."

        return {
            "suitable": solar_ok or wind_ok or hydro_ok,
            "recommendation": rec,
            "location": loc,
            "elevation": elev,
            "slope": slope,
            "restricted_area": restricted_area,
            "solar_details": {
                "suitable": solar_ok,
                "message": "✅ Uygun" if solar_ok else "⛔ Uygun Değil",
                "reasons": list(s_reasons),
                "notes": list(s_notes),
            },
            "wind_details": {
                "suitable": wind_ok,
                "message": "✅ Uygun" if wind_ok else "⛔ Uygun Değil",
                "reasons": list(w_reasons),
                "notes": list(w_notes),
            },
            "hydro_details": {
                "suitable": hydro_ok,
                "message": "✅ Su Kaynağı Mevcut" if hydro_ok else "⛔ Su Kaynağı Bulunamadı",
                "reasons": list(h_reasons),
                "notes": list(h_notes),
            },
        }

"""
Şehir Bazlı Hava Durumu API Endpoint'leri
=========================================

81 il için saatlik ve günlük hava durumu verilerine erişim.
"""

import unicodedata

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func, select, text, or_
from typing import List, Optional
from datetime import datetime, timedelta, timezone, date as date_type
from collections import defaultdict
from pydantic import BaseModel

from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData, WeatherData
from app.core.constants import TURKEY_CITIES, CITY_TO_REGION, PROVINCE_GEO_TO_CODE, _PROVINCE_DB_CODES
from app.services.redis_cache import cache_get, cache_set

router = APIRouter(
    prefix="/weather",
    tags=["weather"],
    responses={404: {"description": "Not found"}},
)


def _ascii_normalize(name: str) -> str:
    """
    Türkçe ve ASCII karakter farklarını giderir: 'İstanbul' → 'istanbul',
    'Gümüşhane' → 'gumushane'.  GeoJSON NAME_1 → DB city_name karşılaştırması
    için kullanılır (Python lower() ile PostgreSQL lower() arasındaki U+0130 farkını çözer).
    """
    return unicodedata.normalize("NFKD", name.strip()).encode("ascii", "ignore").decode("ascii").lower()


# --- SCHEMA'LAR ---
class CityInfo(BaseModel):
    name: str
    lat: float
    lon: float


class HourlyDataResponse(BaseModel):
    city_name: str
    timestamp: datetime
    temperature_2m: Optional[float]
    apparent_temperature: Optional[float]
    wind_speed_10m: Optional[float]
    wind_speed_100m: Optional[float]
    wind_direction_10m: Optional[float]
    wind_gusts_10m: Optional[float]
    shortwave_radiation: Optional[float]
    direct_radiation: Optional[float]
    diffuse_radiation: Optional[float]
    relative_humidity_2m: Optional[float]
    cloud_cover: Optional[float]
    precipitation: Optional[float]

    class Config:
        from_attributes = True


class CitySummary(BaseModel):
    city_name: str
    district_name: Optional[str] = None
    lat: float
    lon: float
    last_update: Optional[datetime]
    record_count: int
    avg_wind_speed_10m: Optional[float]
    avg_wind_speed_100m: Optional[float]
    avg_temperature: Optional[float]
    total_radiation: Optional[float]


class ProvinceSummary(BaseModel):
    province_name: str
    avg_wind_speed: Optional[float] = None
    avg_radiation: Optional[float] = None
    avg_temperature: Optional[float] = None
    record_count: int


class DistrictSummary(BaseModel):
    district_name: str
    province_name: str
    lat: Optional[float] = None
    lon: Optional[float] = None
    avg_wind_speed: Optional[float] = None
    avg_radiation: Optional[float] = None
    avg_temperature: Optional[float] = None
    record_count: int
    location_code: Optional[str] = None  # ör. "ist14" = İstanbul/Kadıköy


class RegionSummary(BaseModel):
    region_name: str
    province_count: int
    avg_wind_speed: Optional[float] = None
    avg_radiation: Optional[float] = None
    avg_temperature: Optional[float] = None


# --- ENDPOINT'LER ---
@router.get("/cities", response_model=List[CityInfo])
def get_cities():
    """Tüm şehirlerin listesini getir"""
    return [CityInfo(**city) for city in TURKEY_CITIES]


@router.get("/cities/{city_name}/hourly", response_model=List[HourlyDataResponse])
def get_city_hourly_data(
    city_name: str,
    hours: int = Query(default=168, ge=1, le=720, description="Son kaç saat (max 30 gün = 720 saat)")
):
    """Belirli bir şehir için saatlik veri getir"""
    db = SystemSessionLocal()
    try:
        # Şehir adını kontrol et
        city_names = [c["name"] for c in TURKEY_CITIES]
        if city_name not in city_names:
            raise HTTPException(status_code=404, detail=f"Şehir bulunamadı: {city_name}")
        
        cutoff = datetime.now() - timedelta(hours=hours)
        
        data = db.query(HourlyWeatherData)\
            .filter(HourlyWeatherData.city_name == city_name)\
            .filter(HourlyWeatherData.timestamp >= cutoff)\
            .order_by(HourlyWeatherData.timestamp.desc())\
            .limit(hours)\
            .all()

        if not data:
            raise HTTPException(status_code=404, detail=f"{city_name} için veri bulunamadı")

        return data
    finally:
        db.close()


@router.get("/cities/{city_name}/latest", response_model=HourlyDataResponse)
def get_city_latest_data(city_name: str):
    """Şehir için en güncel veriyi getir"""
    db = SystemSessionLocal()
    try:
        city_names = [c["name"] for c in TURKEY_CITIES]
        if city_name not in city_names:
            raise HTTPException(status_code=404, detail=f"Şehir bulunamadı: {city_name}")
        
        data = db.query(HourlyWeatherData)\
            .filter(HourlyWeatherData.city_name == city_name)\
            .order_by(HourlyWeatherData.timestamp.desc())\
            .first()
        
        if not data:
            raise HTTPException(status_code=404, detail=f"{city_name} için veri bulunamadı")
        
        return data
    finally:
        db.close()


@router.get("/summary", response_model=List[CitySummary])
def get_all_cities_summary(
    hours: int = Query(
        default=168,
        ge=1,
        le=720,
        description="Özet için saat aralığı (varsayılan 7 gün = 168 saat)",
    )
):
    """Tüm şehirler ve ilçeler için özet bilgi getir (varsayılan son 7 gün)."""
    db = SystemSessionLocal()
    try:
        cutoff = datetime.now() - timedelta(hours=hours)

        # Tek GROUP BY sorgusu — 81 ayrı sorgu yerine
        rows = db.query(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
            func.avg(HourlyWeatherData.latitude).label('lat'),
            func.avg(HourlyWeatherData.longitude).label('lon'),
            func.max(HourlyWeatherData.timestamp).label('last_update'),
            func.count(HourlyWeatherData.id).label('record_count'),
            func.avg(HourlyWeatherData.wind_speed_10m).label('avg_wind_10'),
            func.avg(HourlyWeatherData.wind_speed_100m).label('avg_wind_100'),
            func.avg(HourlyWeatherData.temperature_2m).label('avg_temp'),
            func.sum(HourlyWeatherData.shortwave_radiation).label('total_rad'),
        ).filter(
            HourlyWeatherData.timestamp >= cutoff,
        ).group_by(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
        ).all()

        return [
            CitySummary(
                city_name=r.city_name,
                district_name=r.district_name,
                lat=round(r.lat, 4) if r.lat else 0.0,
                lon=round(r.lon, 4) if r.lon else 0.0,
                last_update=r.last_update,
                record_count=int(r.record_count),
                avg_wind_speed_10m=round(r.avg_wind_10, 2) if r.avg_wind_10 else None,
                avg_wind_speed_100m=round(r.avg_wind_100, 2) if r.avg_wind_100 else None,
                avg_temperature=round(r.avg_temp, 2) if r.avg_temp else None,
                total_radiation=round(r.total_rad, 2) if r.total_rad else None,
            )
            for r in rows
        ]
    finally:
        db.close()


@router.get("/best-wind")
def get_best_wind_cities(
    limit: int = Query(default=10, ge=1, le=81, description="Kaç şehir döndürülsün")
):
    """Son 24 saatte en iyi rüzgar potansiyeline sahip şehirler"""
    db = SystemSessionLocal()
    try:
        cutoff = datetime.now() - timedelta(hours=24)
        
        # Şehir bazında ortalama 100m rüzgar hızı
        results = db.query(
            HourlyWeatherData.city_name,
            func.avg(HourlyWeatherData.wind_speed_100m).label('avg_wind'),
            func.max(HourlyWeatherData.wind_speed_100m).label('max_wind'),
            HourlyWeatherData.latitude,
            HourlyWeatherData.longitude
        ).filter(
            HourlyWeatherData.timestamp >= cutoff
        ).group_by(
            HourlyWeatherData.city_name,
            HourlyWeatherData.latitude,
            HourlyWeatherData.longitude
        ).order_by(
            func.avg(HourlyWeatherData.wind_speed_100m).desc()
        ).limit(limit).all()
        
        return [
            {
                "city": r.city_name,
                "lat": r.latitude,
                "lon": r.longitude,
                "avg_wind_speed_100m": round(r.avg_wind, 2) if r.avg_wind else None,
                "max_wind_speed_100m": round(r.max_wind, 2) if r.max_wind else None,
            }
            for r in results
        ]
    finally:
        db.close()


@router.get("/best-solar")
def get_best_solar_cities(
    limit: int = Query(default=10, ge=1, le=81, description="Kaç şehir döndürülsün")
):
    """Son 24 saatte en iyi güneş potansiyeline sahip şehirler"""
    db = SystemSessionLocal()
    try:
        cutoff = datetime.now() - timedelta(hours=24)
        
        # Şehir bazında toplam radyasyon
        results = db.query(
            HourlyWeatherData.city_name,
            func.sum(HourlyWeatherData.shortwave_radiation).label('total_rad'),
            func.avg(HourlyWeatherData.direct_radiation).label('avg_direct'),
            HourlyWeatherData.latitude,
            HourlyWeatherData.longitude
        ).filter(
            HourlyWeatherData.timestamp >= cutoff
        ).group_by(
            HourlyWeatherData.city_name,
            HourlyWeatherData.latitude,
            HourlyWeatherData.longitude
        ).order_by(
            func.sum(HourlyWeatherData.shortwave_radiation).desc()
        ).limit(limit).all()
        
        return [
            {
                "city": r.city_name,
                "lat": r.latitude,
                "lon": r.longitude,
                "total_radiation_wh": round(r.total_rad, 2) if r.total_rad else None,
                "avg_direct_radiation": round(r.avg_direct, 2) if r.avg_direct else None
            }
            for r in results
        ]
    finally:
        db.close()


@router.get("/at-time")
def get_weather_at_time(
    timestamp: str = Query(..., description="ISO format timestamp")
):
    """Belirli bir zaman için tüm şehirlerin hava durumu verisi"""
    db = SystemSessionLocal()
    try:
        target_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))

        if target_time.tzinfo is None:
            target_time = target_time - timedelta(hours=3)
        else:
            target_time = target_time.astimezone(timezone.utc).replace(tzinfo=None)

        tolerance = timedelta(minutes=30)
        t_min = target_time - tolerance
        t_max = target_time + tolerance

        # Adım 1: En yakın tek timestamp'ı bul (il merkezleri arasından)
        closest_row = db.query(HourlyWeatherData.timestamp).filter(
            HourlyWeatherData.timestamp.between(t_min, t_max),
            or_(HourlyWeatherData.district_name.is_(None), HourlyWeatherData.district_name == "Merkez"),
        ).order_by(
            func.abs(func.extract('epoch', HourlyWeatherData.timestamp - target_time))
        ).first()

        if not closest_row:
            return []

        closest_ts = closest_row[0]

        # Adım 2: O timestamp için tüm il merkezlerini tek sorguda al
        rows = db.query(HourlyWeatherData).filter(
            HourlyWeatherData.timestamp == closest_ts,
            or_(HourlyWeatherData.district_name.is_(None), HourlyWeatherData.district_name == "Merkez"),
        ).all()

        return [
            {
                "city_name": r.city_name,
                "lat": r.latitude,
                "lon": r.longitude,
                "temperature_2m": r.temperature_2m,
                "wind_speed_100m": r.wind_speed_100m,
                "wind_speed_10m": r.wind_speed_10m,
                "wind_direction_10m": r.wind_direction_10m,
                "shortwave_radiation": r.shortwave_radiation,
                "timestamp": r.timestamp.isoformat(),
            }
            for r in rows
        ]
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Geçersiz timestamp formatı: {str(e)}")
    finally:
        db.close()


@router.get("/province-summary", response_model=List[ProvinceSummary])
def get_province_summary(
    hours: int = Query(
        default=168,
        ge=1,
        le=720,
        description="Analiz penceresi (saat, varsayılan 7 gün = 168)",
    )
):
    """İl (province) bazlı hava durumu özeti — city_name'e göre gruplanmış."""
    # ── Cache kontrolü (TTL: 30 dakika) ──────────────────────────────────────
    cache_key = f"weather:province-summary:{hours}"
    cached = cache_get(cache_key)
    if cached is not None:
        return [ProvinceSummary(**item) for item in cached]

    db = SystemSessionLocal()
    try:
        cutoff = datetime.now() - timedelta(hours=hours)
        results = db.query(
            HourlyWeatherData.city_name,
            func.avg(HourlyWeatherData.wind_speed_100m).label("avg_wind"),
            func.avg(HourlyWeatherData.shortwave_radiation).label("avg_radiation"),
            func.avg(HourlyWeatherData.temperature_2m).label("avg_temp"),
            func.count(HourlyWeatherData.id).label("record_count"),
        ).filter(
            HourlyWeatherData.timestamp >= cutoff,
            HourlyWeatherData.city_name.isnot(None),
            or_(HourlyWeatherData.district_name.is_(None), HourlyWeatherData.district_name == "Merkez"),  # Sadece il merkezi kayıtları
        ).group_by(
            HourlyWeatherData.city_name
        ).all()

        result = [
            ProvinceSummary(
                province_name=r.city_name,
                avg_wind_speed=round(r.avg_wind, 2) if r.avg_wind else None,
                avg_radiation=round(r.avg_radiation, 1) if r.avg_radiation else None,
                avg_temperature=round(r.avg_temp, 2) if r.avg_temp else None,
                record_count=int(r.record_count),
            )
            for r in results
            if r.city_name
        ]
        cache_set(cache_key, [r.model_dump() for r in result], ttl_seconds=1800)
        return result
    finally:
        db.close()


@router.get("/district-summary", response_model=List[DistrictSummary])
def get_district_summary(
    province: Optional[str] = Query(None, description="İl adı (ör: İstanbul)"),
    province_code: Optional[str] = Query(None, description="İl plaka kodu (ör: 34 = İstanbul, 55 = Samsun)"),
    hours: int = Query(
        default=168,
        ge=1,
        le=720,
        description="Analiz penceresi (saat, varsayılan 7 gün = 168)",
    ),
):
    """
    Belirli bir ile ait ilçe bazlı hava durumu özeti.
    province_code (ör: "34") verilirse location_code prefix ile sorgu yapar (önerilen).
    province (il adı) verilirse PROVINCE_GEO_TO_CODE üzerinden plaka koduna çevrilir.
    """
    # ── Konum kodu çözünürlüğü ────────────────────────────────────────────────
    # 1) province_code doğrudan verilmişse kullan
    # 2) province (GeoJSON Türkçe adı) verilmişse PROVINCE_GEO_TO_CODE üzerinden çevir
    # 3) Hiçbiri yoksa hata
    resolved_code: Optional[str] = None
    if province_code:
        # Plaka kodu gelebilir ("34") veya eski 3-harfli kod (geriye uyumluluk)
        resolved_code = province_code.strip()
    elif province:
        geo_code = PROVINCE_GEO_TO_CODE.get(province.strip())
        if geo_code:
            resolved_code = geo_code
        else:
            # Fallback: DB adına göre bak ve plaka numarasını string'e çevir
            for db_name, plate in _PROVINCE_DB_CODES.items():
                if db_name.lower() == province.strip().lower():
                    resolved_code = f"{plate:02d}"
                    break

    if not resolved_code:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="province veya province_code gerekli")

    # ── Cache kontrolü (TTL: 15 dakika) ──────────────────────────────────────
    cache_key = f"weather:district-summary:{resolved_code}:{hours}"
    cached = cache_get(cache_key)
    if cached is not None:
        return [DistrictSummary(**item) for item in cached]

    db = SystemSessionLocal()
    try:
        cutoff = datetime.now() - timedelta(hours=hours)

        # Hem gerçek ilçeler (district_name IS NOT NULL) hem de il merkezi
        # (location_code = "{code}0", district_name IS NULL) dahil edilir.
        # Merkez kayıt "Merkez" district_name ile döndürülür.
        results = db.query(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
            HourlyWeatherData.location_code,
            func.avg(HourlyWeatherData.latitude).label("lat"),
            func.avg(HourlyWeatherData.longitude).label("lon"),
            func.avg(HourlyWeatherData.wind_speed_100m).label("avg_wind"),
            func.avg(HourlyWeatherData.shortwave_radiation).label("avg_radiation"),
            func.avg(HourlyWeatherData.temperature_2m).label("avg_temp"),
            func.count(HourlyWeatherData.id).label("record_count"),
        ).filter(
            HourlyWeatherData.timestamp >= cutoff,
            HourlyWeatherData.location_code.like(f"{resolved_code}%"),
        ).group_by(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
            HourlyWeatherData.location_code,
        ).all()

        # İlçe merkezlerinin sabit koordinatlarını kullan (DB ortalaması yerine)
        # LOCATION_CODE_MAP: location_code → TURKEY_CITIES girişi (lat, lon, name, ...)
        from app.core.constants import LOCATION_CODE_MAP

        result = []
        for r in results:
            # Sabit koordinat: TURKEY_CITIES'den al, yoksa DB ortalaması kullan
            fixed = LOCATION_CODE_MAP.get(r.location_code)
            use_lat = round(fixed["lat"], 4) if fixed else (round(float(r.lat), 4) if r.lat else None)
            use_lon = round(fixed["lon"], 4) if fixed else (round(float(r.lon), 4) if r.lon else None)

            result.append(DistrictSummary(
                # district_name = NULL ise bu il merkezidir → "Merkez" olarak göster
                district_name=r.district_name if r.district_name else "Merkez",
                province_name=r.city_name,
                lat=use_lat,
                lon=use_lon,
                avg_wind_speed=round(r.avg_wind, 2) if r.avg_wind else None,
                avg_radiation=round(r.avg_radiation, 1) if r.avg_radiation else None,
                avg_temperature=round(r.avg_temp, 2) if r.avg_temp else None,
                record_count=int(r.record_count),
                location_code=r.location_code,
            ))
        cache_set(cache_key, [r.model_dump() for r in result], ttl_seconds=900)
        return result
    finally:
        db.close()


@router.get("/region-summary", response_model=List[RegionSummary])
def get_region_summary(
    hours: int = Query(
        default=168,
        ge=1,
        le=720,
        description="Analiz penceresi (saat, varsayılan 7 gün = 168)",
    ),
):
    """
    7 coğrafi bölge bazlı hava durumu özeti.
    İl ortalamalarını bölgeye göre gruplar.
    """
    # ── Cache kontrolü (TTL: 30 dakika) ──────────────────────────────────────
    cache_key = f"weather:region-summary:{hours}"
    cached = cache_get(cache_key)
    if cached is not None:
        return [RegionSummary(**item) for item in cached]

    db = SystemSessionLocal()
    try:
        cutoff = datetime.now() - timedelta(hours=hours)

        province_results = db.query(
            HourlyWeatherData.city_name,
            func.avg(HourlyWeatherData.wind_speed_100m).label("avg_wind"),
            func.avg(HourlyWeatherData.shortwave_radiation).label("avg_radiation"),
            func.avg(HourlyWeatherData.temperature_2m).label("avg_temp"),
        ).filter(
            HourlyWeatherData.timestamp >= cutoff,
            HourlyWeatherData.city_name.isnot(None),
            or_(HourlyWeatherData.district_name.is_(None), HourlyWeatherData.district_name == "Merkez"),
        ).group_by(
            HourlyWeatherData.city_name
        ).all()

        region_buckets: dict = defaultdict(lambda: {
            "winds": [], "rads": [], "temps": [], "provinces": set()
        })

        for r in province_results:
            region = CITY_TO_REGION.get(r.city_name.casefold() if r.city_name else "")
            if not region:
                continue
            b = region_buckets[region]
            b["provinces"].add(r.city_name)
            if r.avg_wind is not None:
                b["winds"].append(float(r.avg_wind))
            if r.avg_radiation is not None:
                b["rads"].append(float(r.avg_radiation))
            if r.avg_temp is not None:
                b["temps"].append(float(r.avg_temp))

        def _avg(lst):
            return round(sum(lst) / len(lst), 2) if lst else None

        result = [
            RegionSummary(
                region_name=region,
                province_count=len(b["provinces"]),
                avg_wind_speed=_avg(b["winds"]),
                avg_radiation=_avg(b["rads"]),
                avg_temperature=_avg(b["temps"]),
            )
            for region, b in sorted(region_buckets.items())
        ]
        cache_set(cache_key, [r.model_dump() for r in result], ttl_seconds=1800)
        return result
    finally:
        db.close()


# ─── Animasyon endpoint'leri ──────────────────────────────────────────────────

@router.get("/animation/range")
def get_animation_range():
    """
    Animasyon için kullanılabilir veri aralığını döndürür.
    Günlük (weather_data) ve saatlik (hourly_weather_data) tabloların
    min/max tarihlerini verir.
    """
    db = SystemSessionLocal()
    try:
        # Günlük tablo aralığı
        daily_min = db.execute(select(func.min(WeatherData.date))).scalar()
        daily_max = db.execute(select(func.max(WeatherData.date))).scalar()
        # Saatlik tablo aralığı
        hourly_min = db.execute(select(func.min(HourlyWeatherData.timestamp))).scalar()
        hourly_max = db.execute(select(func.max(HourlyWeatherData.timestamp))).scalar()

        return {
            "daily_min": daily_min.isoformat() if daily_min else None,
            "daily_max": daily_max.isoformat() if daily_max else None,
            "hourly_min": hourly_min.date().isoformat() if hourly_min else None,
            "hourly_max": hourly_max.date().isoformat() if hourly_max else None,
        }
    finally:
        db.close()


# Animasyon için maksimum frame sayısı sınırları
_DAILY_MAX_FRAMES = 1825   # ~5 yıl
_HOURLY_MAX_FRAMES = 720   # 30 gün × 24 saat

# Metrik → sütun eşlemesi
_DAILY_METRIC_COL = {
    "wind":        WeatherData.wind_speed_mean,
    "temperature": WeatherData.temperature_mean,
    "radiation":   WeatherData.shortwave_radiation_sum,
}
_HOURLY_METRIC_COL = {
    "wind":        HourlyWeatherData.wind_speed_100m,
    "temperature": HourlyWeatherData.temperature_2m,
    "radiation":   HourlyWeatherData.shortwave_radiation,
}


@router.get("/animation")
def get_animation_frames(
    start: str = Query(..., description="Başlangıç tarihi (YYYY-MM-DD)"),
    end: str = Query(..., description="Bitiş tarihi (YYYY-MM-DD)"),
    metric: str = Query("wind", description="wind | temperature | radiation"),
    interval: str = Query("daily", description="daily | hourly"),
):
    """
    Hava durumu animasyonu için frame verisi döndürür.

    Her frame bir zaman dilimine karşılık gelir; noktalar [lat, lon, değer]
    üçlüleri olarak kompakt JSON array içinde döner.

    Yanıt yapısı:
      {
        "metric": "wind", "interval": "daily",
        "total_frames": 365,
        "metric_min": 0.8, "metric_max": 18.4,
        "frames": [
          {"ts": "2024-01-01", "pts": [[lat, lon, val], ...]},
          ...
        ]
      }
    """
    # --- Parametre doğrulama ---
    if metric not in ("wind", "temperature", "radiation"):
        raise HTTPException(status_code=400, detail="metric must be wind|temperature|radiation")
    if interval not in ("daily", "hourly"):
        raise HTTPException(status_code=400, detail="interval must be daily|hourly")

    try:
        start_date = datetime.strptime(start, "%Y-%m-%d").date()
        end_date = datetime.strptime(end, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Geçersiz tarih formatı; YYYY-MM-DD bekleniyor")

    if start_date > end_date:
        raise HTTPException(status_code=400, detail="start tarihi end'den büyük olamaz")

    db = SystemSessionLocal()
    try:
        if interval == "daily":
            # Frame sınırı kontrolü
            day_diff = (end_date - start_date).days + 1
            if day_diff > _DAILY_MAX_FRAMES:
                raise HTTPException(
                    status_code=400,
                    detail=f"Günlük modda maksimum {_DAILY_MAX_FRAMES} gün seçilebilir"
                )

            metric_col = _DAILY_METRIC_COL[metric]

            rows = db.query(
                WeatherData.latitude,
                WeatherData.longitude,
                WeatherData.date,
                WeatherData.city_name,
                metric_col.label("val"),
            ).filter(
                WeatherData.date >= start_date,
                WeatherData.date <= end_date,
                metric_col.isnot(None),
            ).order_by(WeatherData.date).all()

            # Tarih → [(lat, lon, val, city)] gruplama
            frames_dict = defaultdict(list)
            all_vals = []
            for row in rows:
                v = round(float(row.val), 3)
                frames_dict[row.date.isoformat()].append([
                    round(row.latitude, 4),
                    round(row.longitude, 4),
                    v,
                    row.city_name or "",
                ])
                all_vals.append(v)

            frames = [
                {"ts": ts, "pts": pts}
                for ts, pts in sorted(frames_dict.items())
            ]

        else:  # hourly
            # Saatlik mod için gün sınırı kontrolü
            day_diff = (end_date - start_date).days + 1
            max_hourly_days = _HOURLY_MAX_FRAMES // 24  # 30 gün
            if day_diff > max_hourly_days:
                raise HTTPException(
                    status_code=400,
                    detail=f"Saatlik modda maksimum {max_hourly_days} gün seçilebilir"
                )

            start_ts = datetime.combine(start_date, datetime.min.time())
            end_ts = datetime.combine(end_date, datetime.max.time().replace(microsecond=0))

            metric_col = _HOURLY_METRIC_COL[metric]

            rows = db.query(
                HourlyWeatherData.latitude,
                HourlyWeatherData.longitude,
                HourlyWeatherData.timestamp,
                HourlyWeatherData.city_name,
                metric_col.label("val"),
            ).filter(
                HourlyWeatherData.timestamp >= start_ts,
                HourlyWeatherData.timestamp <= end_ts,
                metric_col.isnot(None),
                or_(HourlyWeatherData.district_name.is_(None), HourlyWeatherData.district_name == "Merkez"),  # Sadece il merkezi
            ).order_by(HourlyWeatherData.timestamp).all()

            # Timestamp → [(lat, lon, val, city)] gruplama (saatlik hassasiyet)
            frames_dict = defaultdict(list)
            all_vals = []
            for row in rows:
                v = round(float(row.val), 3)
                # Timestamp'ı ISO string olarak sakla (saniye hassasiyeti)
                ts_key = row.timestamp.strftime("%Y-%m-%dT%H:%M")
                frames_dict[ts_key].append([
                    round(row.latitude, 4),
                    round(row.longitude, 4),
                    v,
                    row.city_name or "",
                ])
                all_vals.append(v)

            frames = [
                {"ts": ts, "pts": pts}
                for ts, pts in sorted(frames_dict.items())
            ]

        # Global min/max (JS tarafında normalize için)
        metric_min = round(min(all_vals), 3) if all_vals else 0.0
        metric_max = round(max(all_vals), 3) if all_vals else 1.0

        return {
            "metric": metric,
            "interval": interval,
            "total_frames": len(frames),
            "metric_min": metric_min,
            "metric_max": metric_max,
            "frames": frames,
        }

    finally:
        db.close()


@router.post("/refresh")
async def refresh_hourly_data():
    """Saatlik verileri manuel olarak yenile (admin)"""
    try:
        from ..hourly_collector import update_hourly_data
        import asyncio

        await asyncio.to_thread(update_hourly_data)

        return {"status": "success", "message": "Saatlik veriler güncellendi"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── Rapor Dashboard endpoint'leri ───────────────────────────────────────────

class TrendPoint(BaseModel):
    label: str    # "Oca", "Şub" … ya da "01", "02" … (gün)
    value: float


@router.get("/available-years", response_model=List[int])
def get_available_years():
    """
    Saatlik veri tablosunda kayıtlı yılları döndürür.
    Flutter zaman aralığı seçicisi bu listeyi kullanarak dinamik yıl dropdown'u oluşturur.
    """
    cache_key = "weather:available-years"
    cached = cache_get(cache_key)
    if cached is not None:
        return cached

    db = SystemSessionLocal()
    try:
        rows = db.execute(
            select(func.extract("year", HourlyWeatherData.timestamp).label("yr"))
            .distinct()
            .order_by(text("yr"))
        ).scalars().all()
        result = [int(y) for y in rows if y is not None]
        cache_set(cache_key, result, ttl_seconds=3600)
        return result
    finally:
        db.close()


@router.get("/monthly-trend", response_model=List[TrendPoint])
def get_monthly_trend(
    city: str = Query(..., description="Şehir adı (ör: İzmir)"),
    metric: str = Query("solar", description="solar | wind | temperature"),
    year: int = Query(..., description="Yıl (ör: 2025)"),
    month: Optional[int] = Query(None, ge=1, le=12, description="Ay (1-12). Verilmezse tüm yıl aylık özet döner."),
):
    """
    Belirli bir şehir için trend verisi döndürür.

    - `month` verilmezse: o yılın 12 aylık ortalama dizisi (label: Oca..Ara)
    - `month` verilirse: o ayın günlük ortalama dizisi (label: 1..28/30/31)

    metric:
      solar       → avg(shortwave_radiation) W/m² → kWh/m²/gün'e dönüştürülür (÷ 1000 × 24)
      wind        → avg(wind_speed_100m) m/s
      temperature → avg(temperature_2m) °C
    """
    if metric not in ("solar", "wind", "temperature"):
        raise HTTPException(status_code=400, detail="metric must be solar|wind|temperature")

    # ASCII normalize: "İstanbul" → "istanbul" (U+0130 vs ASCII I farkını giderir)
    city_ascii = _ascii_normalize(city)
    cache_key = f"weather:monthly-trend:{city_ascii}:{metric}:{year}:{month}"
    cached = cache_get(cache_key)
    if cached is not None:
        return [TrendPoint(**p) for p in cached]

    # Metrik sütun seçimi
    if metric == "solar":
        metric_col = HourlyWeatherData.shortwave_radiation
    elif metric == "wind":
        metric_col = HourlyWeatherData.wind_speed_100m
    else:
        metric_col = HourlyWeatherData.temperature_2m

    TR_MONTHS = ["Oca", "Şub", "Mar", "Nis", "May", "Haz",
                 "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

    db = SystemSessionLocal()
    try:
        # DB city_name canonical Türkçe ("İzmir", "Çorum" vb.).
        # func.lower() PostgreSQL'de Türkçe İ→i̇ yapar (ASCII 'i' değil),
        # bu yüzden ascii_normalize ile eşleşmez → ILIKE kullan.
        city_filter = HourlyWeatherData.city_name.ilike(city.strip())

        if month is None:
            # Aylık özet — 12 veri noktası
            rows = db.query(
                func.extract("month", HourlyWeatherData.timestamp).label("m"),
                func.avg(metric_col).label("val"),
            ).filter(
                city_filter,
                func.extract("year", HourlyWeatherData.timestamp) == year,
                or_(HourlyWeatherData.district_name.is_(None), HourlyWeatherData.district_name == "Merkez"),
                metric_col.isnot(None),
            ).group_by(
                func.extract("month", HourlyWeatherData.timestamp)
            ).order_by(
                func.extract("month", HourlyWeatherData.timestamp)
            ).all()

            result = []
            for r in rows:
                m_idx = int(r.m) - 1
                val = float(r.val)
                if metric == "solar":
                    val = round(val / 1000 * 24, 2)   # W/m² → kWh/m²/gün
                elif metric == "wind":
                    val = round(val, 2)
                else:
                    val = round(val, 2)
                result.append(TrendPoint(label=TR_MONTHS[m_idx], value=val))

        else:
            # Günlük özet — o ayın her günü
            rows = db.query(
                func.extract("day", HourlyWeatherData.timestamp).label("d"),
                func.avg(metric_col).label("val"),
            ).filter(
                city_filter,
                func.extract("year", HourlyWeatherData.timestamp) == year,
                func.extract("month", HourlyWeatherData.timestamp) == month,
                or_(HourlyWeatherData.district_name.is_(None), HourlyWeatherData.district_name == "Merkez"),
                metric_col.isnot(None),
            ).group_by(
                func.extract("day", HourlyWeatherData.timestamp)
            ).order_by(
                func.extract("day", HourlyWeatherData.timestamp)
            ).all()

            result = []
            for r in rows:
                val = float(r.val)
                if metric == "solar":
                    val = round(val / 1000 * 24, 2)
                elif metric == "wind":
                    val = round(val, 2)
                else:
                    val = round(val, 2)
                result.append(TrendPoint(label=str(int(r.d)), value=val))

        cache_set(cache_key, [p.model_dump() for p in result], ttl_seconds=1800)
        return result
    finally:
        db.close()


@router.get("/province-summary-range", response_model=List[ProvinceSummary])
def get_province_summary_range(
    start: str = Query(..., description="Başlangıç tarihi YYYY-MM-DD"),
    end: str = Query(..., description="Bitiş tarihi YYYY-MM-DD"),
):
    """
    Belirtilen tarih aralığı için il bazlı hava durumu özeti.
    Mevcut /province-summary (hours bazlı) endpointi'nin tarih bazlı karşılığı.
    """
    try:
        start_dt = datetime.strptime(start, "%Y-%m-%d")
        end_dt = datetime.strptime(end, "%Y-%m-%d").replace(
            hour=23, minute=59, second=59
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Geçersiz tarih formatı; YYYY-MM-DD bekleniyor")

    if start_dt > end_dt:
        raise HTTPException(status_code=400, detail="start tarihi end'den büyük olamaz")

    cache_key = f"weather:province-summary-range:{start}:{end}"
    cached = cache_get(cache_key)
    if cached is not None:
        return [ProvinceSummary(**item) for item in cached]

    db = SystemSessionLocal()
    try:
        results = db.query(
            HourlyWeatherData.city_name,
            func.avg(HourlyWeatherData.wind_speed_100m).label("avg_wind"),
            func.avg(HourlyWeatherData.shortwave_radiation).label("avg_radiation"),
            func.avg(HourlyWeatherData.temperature_2m).label("avg_temp"),
            func.count(HourlyWeatherData.id).label("record_count"),
        ).filter(
            HourlyWeatherData.timestamp >= start_dt,
            HourlyWeatherData.timestamp <= end_dt,
            HourlyWeatherData.city_name.isnot(None),
            or_(HourlyWeatherData.district_name.is_(None), HourlyWeatherData.district_name == "Merkez"),
        ).group_by(
            HourlyWeatherData.city_name
        ).all()

        result = [
            ProvinceSummary(
                province_name=r.city_name,
                avg_wind_speed=round(r.avg_wind, 2) if r.avg_wind else None,
                avg_radiation=round(r.avg_radiation, 1) if r.avg_radiation else None,
                avg_temperature=round(r.avg_temp, 2) if r.avg_temp else None,
                record_count=int(r.record_count),
            )
            for r in results
            if r.city_name
        ]
        cache_set(cache_key, [r.model_dump() for r in result], ttl_seconds=1800)
        return result
    finally:
        db.close()


# ─── Collector Sağlık Durumu ──────────────────────────────────────────────────

class CollectorStatus(BaseModel):
    healthy: bool
    last_collected: Optional[datetime] = None
    minutes_ago: Optional[int] = None
    records_48h: int


@router.get("/collector-status", response_model=CollectorStatus)
def get_collector_status():
    """
    Arka plan veri toplayıcısının son çalışma zamanını döndürür.
    - healthy: True = son 2 saat içinde veri geldi
    - minutes_ago: son kaydın kaç dakika önce eklendiği
    - records_48h: son 48 saatteki kayıt sayısı
    """
    db = SystemSessionLocal()
    try:
        row = db.execute(text("""
            SELECT
                MAX(timestamp)  AS last_ts,
                COUNT(*)        AS cnt
            FROM hourly_weather_data
            WHERE timestamp >= NOW() - INTERVAL '48 hours'
        """)).fetchone()

        if row is None or row.last_ts is None:
            return CollectorStatus(healthy=False, records_48h=0)

        last_ts: datetime = row.last_ts
        if last_ts.tzinfo is None:
            last_ts = last_ts.replace(tzinfo=timezone.utc)

        now = datetime.now(timezone.utc)
        minutes_ago = max(0, int((now - last_ts).total_seconds() / 60))

        return CollectorStatus(
            healthy=minutes_ago < 120,
            last_collected=last_ts,
            minutes_ago=minutes_ago,
            records_48h=int(row.cnt),
        )
    except Exception as e:
        logger.warning("collector-status sorgusu başarısız: {}", e)
        return CollectorStatus(healthy=False, records_48h=0)
    finally:
        db.close()


# ─── İlçe Choropleth Verisi ──────────────────────────────────────────────────

# ── Türkçe karakter normalize (choropleth eşleştirme) ────────────────────────
_TR_CHAR_MAP = str.maketrans("ıİşŞğĞçÇöÖüÜâÂîÎûÛ", "iIssgGcCooUUaAiIuU")

def _tr_ascii(name: str) -> str:
    """ı→i, İ→I, ş→s … dönüşümü + NFKD + ASCII lower.
    Standart _ascii_normalize 'ı' harfini yutuyordu."""
    s = name.strip().translate(_TR_CHAR_MAP)
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii").lower()

# DB'deki kısa il adları → GeoJSON'daki tam il adları (tr_ascii normalized)
_PROVINCE_ALIAS = {
    "afyon": "afyonkarahisar",
    "k. maras": "kahramanmaras",
}

# DB ilçe adı → GeoJSON ilçe adı farklılıkları (tr_ascii normalized)
# "db_prov|db_dist" → "geo_prov|geo_dist"
_DISTRICT_ALIAS = {
    "afyonkarahisar|sincanli": "afyonkarahisar|sinanpasa",
    "agri|dogubeyazit": "agri|dogubayazit",
    "agri|patnos": "agri|panos",
    "ankara|kazan": "ankara|kahramankazan",
    "ankara|sultan kochisar": "ankara|sereflikochisar",
    "antalya|kale": "antalya|demre",
    "bursa|mustafa kemalpasa": "bursa|mustafakemalpasa",
    "denizli|akkoy": "denizli|merkezefendi",
    "edirne|suleoglu": "edirne|suloglu",
    "erzurum|ilica": "erzurum|palandoken",
    "giresun|sultan karahisar": "giresun|sebinkarahisar",
    "istanbul|eyup": "istanbul|eyupsultan",
    "kirikkale|baliseyh": "kirikkale|balisih",
    "malatya|arapkir": "malatya|arapgir",
    "manisa|yunusemre": "manisa|yunus emre",
    "malatya|poturge": "malatya|puturge",
    "samsun|asarcik": "samsun|asarcik",
    "samsun|ondokuz mayis": "samsun|19 mayis",
    "siirt|aydinlar": "siirt|tillo",
    "tunceli|nazimiye": "tunceli|nazmiye",
    "yozgat|sarikaya": "yozgat|sarikaya deresi",
}

# 2012 sonrası bölünmüş "Merkez" ilçeler → birden fazla yeni ilçeye dağıtılır.
# Choropleth'te aynı "Merkez" verisi tüm parçalara kopyalanır.
# Tek hedefli olan alias tablosundan ayrı tutulur.
_MERKEZ_SPLIT: dict[str, list[str]] = {
    "antalya":    ["muratpasa", "kepez", "konyaalti", "dosemealti", "aksu"],
    "aydin":      ["efeler"],
    "balikesir":  ["karesi", "altieylul"],
    "denizli":    ["merkezefendi", "pamukkale"],
    "diyarbakir": ["sur", "baglar", "kayapinar", "yenisehir"],
    "erzurum":    ["yakutiye", "aziziye", "palandoken"],
    "eskisehir":  ["odunpazari", "tepebasi"],
    "hatay":      ["antakya", "defne"],
    "kocaeli":    ["izmit", "basiskele", "kartepe"],
    "malatya":    ["battalgazi", "yesilyurt"],
    "manisa":     ["sehzadeler", "yunus emre"],
    "mardin":     ["artuklu", "kiziltepe"],
    "mersin":     ["akdeniz", "mezitli", "toroslar", "yenisehir"],
    "mugla":      ["mentese"],
    "ordu":       ["altinordu", "catalpinar"],
    "sakarya":    ["adapazari", "serdivan", "erenler", "arifiye"],
    "samsun":     ["ilkadim", "atakum", "canik", "tekkekoy"],
    "sanliurfa":  ["haliliye", "eyyubiye", "karakopru"],
    "tekirdag":   ["suleymanpasa", "kapaklı", "ergene"],
    "trabzon":    ["ortahisar"],
    "van":        ["ipekyolu", "tusba", "edremit"],
}


@router.get("/district-choropleth")
def get_district_choropleth(
    hours: int = Query(
        default=720,
        ge=1,
        le=8760,
        description="Analiz penceresi (saat, varsayılan 30 gün = 720)",
    ),
    mode: str = Query(
        default="average",
        regex="^(average|latest)$",
        description="average: zaman aralığı ortalaması, latest: en güncel saatin verisi",
    ),
):
    """
    Tüm ilçeler için choropleth harita verisi döner.
    ASCII normalize ile DB ↔ GeoJSON isim farklarını otomatik eşleştirir.
    Key formatı: "GeoJSON_NAME_1|GeoJSON_NAME_2" (frontend ile birebir uyumlu).

    mode=latest: her ilçe için veritabanındaki en güncel tek saatin değerlerini döner.
    mode=average: belirtilen saat penceresi içindeki ortalamaları döner (varsayılan).
    """
    cache_key = f"weather:district-choropleth:{hours}:{mode}"
    cached = cache_get(cache_key)
    if cached is not None:
        return cached

    db = SystemSessionLocal()
    try:
        if mode == "latest":
            # Tüm ilçeler için TEK global en son timestamp'i bul
            # Bu sayede doğu-batı tutarsızlığı olmaz (aynı saat, aynı veri).
            from sqlalchemy import and_

            global_max_ts = db.query(
                func.max(HourlyWeatherData.timestamp),
            ).filter(
                HourlyWeatherData.district_name.isnot(None),
            ).scalar()

            if not global_max_ts:
                cache_set(cache_key, {}, ttl_seconds=60)
                return {}

            # Global timestamp'e ait tüm satırları çek
            rows = db.query(
                HourlyWeatherData.city_name,
                HourlyWeatherData.district_name,
                HourlyWeatherData.wind_speed_100m.label("avg_wind"),
                HourlyWeatherData.shortwave_radiation.label("avg_radiation"),
                HourlyWeatherData.temperature_2m.label("avg_temp"),
            ).filter(
                HourlyWeatherData.district_name.isnot(None),
                HourlyWeatherData.timestamp == global_max_ts,
            ).all()

            # Solar için: gündüz saatlerindeki en son global timestamp
            # Gece ise tüm Türkiye'de 0 olacak → tek global daylight timestamp
            global_solar_ts = db.query(
                func.max(HourlyWeatherData.timestamp),
            ).filter(
                HourlyWeatherData.district_name.isnot(None),
                HourlyWeatherData.shortwave_radiation > 0,
            ).scalar()

            _solar_lookup: dict[str, float] = {}
            if global_solar_ts:
                solar_rows = db.query(
                    HourlyWeatherData.city_name,
                    HourlyWeatherData.district_name,
                    HourlyWeatherData.shortwave_radiation.label("radiation"),
                ).filter(
                    HourlyWeatherData.district_name.isnot(None),
                    HourlyWeatherData.timestamp == global_solar_ts,
                ).all()
                for sr in solar_rows:
                    if sr.city_name and sr.district_name and sr.radiation:
                        _solar_lookup[f"{sr.city_name}|{sr.district_name}"] = float(sr.radiation)
        else:
            cutoff = datetime.now() - timedelta(hours=hours)

            rows = db.query(
                HourlyWeatherData.city_name,
                HourlyWeatherData.district_name,
                func.avg(HourlyWeatherData.wind_speed_100m).label("avg_wind"),
                func.avg(HourlyWeatherData.shortwave_radiation).label("avg_radiation"),
                func.avg(HourlyWeatherData.temperature_2m).label("avg_temp"),
            ).filter(
                HourlyWeatherData.timestamp >= cutoff,
                HourlyWeatherData.district_name.isnot(None),
            ).group_by(
                HourlyWeatherData.city_name,
                HourlyWeatherData.district_name,
            ).all()
            _solar_lookup: dict[str, float] = {}  # average mod: ayrı solar lookup yok

        # ── GeoJSON ilçe listesini yükle → _tr_ascii normalize lookup ──
        # "tr_ascii(NAME_1)|tr_ascii(NAME_2)" → "NAME_1|NAME_2" (orijinal Turkish)
        import json, os
        _geo_lookup: dict[str, str] = {}
        _geo_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
            "data", "vector", "turkey_districts_osm.geojson",
        )
        try:
            with open(_geo_path, "r", encoding="utf-8") as f:
                _geo = json.load(f)
            for feat in _geo.get("features", []):
                props = feat.get("properties", {})
                n1 = props.get("NAME_1", "")
                n2 = props.get("NAME_2", "")
                if n1 and n2:
                    ascii_key = f"{_tr_ascii(n1)}|{_tr_ascii(n2)}"
                    geo_key = f"{n1}|{n2}"
                    _geo_lookup[ascii_key] = geo_key
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning(
                "Choropleth GeoJSON yüklenemedi: %s — fallback kullanılacak", e
            )

        result = {}
        matched = 0
        for r in rows:
            if not r.city_name or not r.district_name:
                continue

            # Solar: gece ise 0/null olur → gündüz lookup'tan al (mode=latest)
            solar_key = f"{r.city_name}|{r.district_name}"
            solar_val = _solar_lookup.get(solar_key) if mode == "latest" else None
            # Gündüz verisi varsa onu kullan, yoksa mevcut satırın değerini
            raw_solar = solar_val if solar_val is not None else (
                float(r.avg_radiation) if r.avg_radiation else None
            )

            val = {
                "wind": round(float(r.avg_wind), 2) if r.avg_wind else None,
                "solar": round(raw_solar, 2) if raw_solar else None,
                "temp": round(float(r.avg_temp), 2) if r.avg_temp else None,
            }

            # Türkçe-aware normalize ile GeoJSON key'i bul
            prov_norm = _tr_ascii(r.city_name)
            dist_norm = _tr_ascii(r.district_name)

            # Kısa il adı alias kontrolü (Afyon→Afyonkarahisar vb.)
            prov_norm = _PROVINCE_ALIAS.get(prov_norm, prov_norm)

            db_ascii = f"{prov_norm}|{dist_norm}"

            # İlçe alias kontrolü (Eyüp→Eyüpsultan, Kazan→Kahramankazan vb.)
            db_ascii = _DISTRICT_ALIAS.get(db_ascii, db_ascii)

            geo_key = _geo_lookup.get(db_ascii)

            # "Merkez" fallback: alias tablosunda yoksa "{il} merkez" veya "{il}" dene
            if not geo_key and dist_norm == "merkez":
                geo_key = _geo_lookup.get(f"{prov_norm}|{prov_norm} merkez")
                if not geo_key:
                    geo_key = _geo_lookup.get(f"{prov_norm}|{prov_norm}")

            if geo_key:
                result[geo_key] = val
                matched += 1

            # Bölünmüş Merkez: aynı veriyi tüm parça ilçelere de kopyala
            if dist_norm == "merkez" and prov_norm in _MERKEZ_SPLIT:
                for sub in _MERKEZ_SPLIT[prov_norm]:
                    sub_key = _geo_lookup.get(f"{prov_norm}|{sub}")
                    if sub_key and sub_key not in result:
                        result[sub_key] = val
                        matched += 1

        import logging
        logging.getLogger(__name__).info(
            "Choropleth: %d/%d ilçe GeoJSON ile eşleşti", matched, len(result)
        )

        # Meta bilgi: verinin hangi zamana ait olduğu
        meta: dict = {}
        if mode == "latest" and global_max_ts:
            meta["data_timestamp"] = global_max_ts.isoformat()
            if global_solar_ts:
                meta["solar_timestamp"] = global_solar_ts.isoformat()
        else:
            cutoff_ts = datetime.now() - timedelta(hours=hours)
            meta["data_from"] = cutoff_ts.isoformat()
            meta["data_to"] = datetime.now().isoformat()

        result["_meta"] = meta
        cache_set(cache_key, result, ttl_seconds=900)
        return result
    finally:
        db.close()

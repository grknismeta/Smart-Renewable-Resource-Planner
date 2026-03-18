"""
Şehir Bazlı Hava Durumu API Endpoint'leri
=========================================

81 il için saatlik ve günlük hava durumu verilerine erişim.
"""

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func, select, text
from typing import List, Optional
from datetime import datetime, timedelta, timezone, date as date_type
from collections import defaultdict
from pydantic import BaseModel

from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData, WeatherData
from app.core.constants import TURKEY_CITIES, CITY_TO_REGION
from app.services.redis_cache import cache_get, cache_set

router = APIRouter(
    prefix="/weather",
    tags=["weather"],
    responses={404: {"description": "Not found"}},
)


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
        # İstenen saat aralığı için özet hesapla
        cutoff = datetime.now() - timedelta(hours=hours)
        
        summaries = []
        for location in TURKEY_CITIES:
            city_name = location["name"]
            district_name = location.get("district")
            
            # İstatistikler (city_name + district_name kombinasyonu ile)
            query = db.query(
                func.count(HourlyWeatherData.id).label('record_count'),
                func.max(HourlyWeatherData.timestamp).label('last_update'),
                func.avg(HourlyWeatherData.wind_speed_10m).label('avg_wind_10'),
                func.avg(HourlyWeatherData.wind_speed_100m).label('avg_wind_100'),
                func.avg(HourlyWeatherData.temperature_2m).label('avg_temp'),
                func.sum(HourlyWeatherData.shortwave_radiation).label('total_rad')
            ).filter(
                HourlyWeatherData.city_name == city_name,
                HourlyWeatherData.timestamp >= cutoff
            )
            
            # District filtresi ekle
            if district_name is not None:
                query = query.filter(HourlyWeatherData.district_name == district_name)
            else:
                query = query.filter(HourlyWeatherData.district_name.is_(None))
            
            stats = query.first()
            
            summaries.append(CitySummary(
                city_name=city_name,
                district_name=district_name,
                lat=location["lat"],
                lon=location["lon"],
                last_update=stats.last_update if stats else None,
                record_count=int(stats.record_count) if stats else 0,
                avg_wind_speed_10m=round(stats.avg_wind_10, 2) if stats and stats.avg_wind_10 else None,
                avg_wind_speed_100m=round(stats.avg_wind_100, 2) if stats and stats.avg_wind_100 else None,
                avg_temperature=round(stats.avg_temp, 2) if stats and stats.avg_temp else None,
                total_radiation=round(stats.total_rad, 2) if stats and stats.total_rad else None
            ))
        
        return summaries
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
                "max_wind_speed_100m": round(r.max_wind, 2) if r.max_wind else None
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
        # Timestamp'ı parse et
        # Timestamp'ı parse et
        target_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        
        # Eğer naive (timezone yoksa) ise TRT (UTC+3) kabul et ve UTC'ye çevir
        if target_time.tzinfo is None:
             target_time = target_time - timedelta(hours=3)
        else:
             # Already aware, convert to UTC
             target_time = target_time.astimezone(timezone.utc).replace(tzinfo=None)
        
        # +/- 30 dakika tolerans ile en yakın veriyi bul
        tolerance = timedelta(minutes=30)
        
        results = []
        for city in TURKEY_CITIES:
            city_name = city["name"]
            district_name = city.get("district")
            
            # En yakın zaman damgasına sahip kaydı bul
            query = db.query(HourlyWeatherData)\
                .filter(HourlyWeatherData.city_name == city_name)
            
            # District filtresi
            if district_name is not None:
                query = query.filter(HourlyWeatherData.district_name == district_name)
            else:
                query = query.filter(HourlyWeatherData.district_name.is_(None))
            
            data = query\
                .filter(HourlyWeatherData.timestamp >= target_time - tolerance)\
                .filter(HourlyWeatherData.timestamp <= target_time + tolerance)\
                .order_by(func.abs(
                    func.extract('epoch', HourlyWeatherData.timestamp - target_time)
                ))\
                .first()
            
            if data:
                results.append({
                    "city_name": city_name,
                    "lat": city["lat"],
                    "lon": city["lon"],
                    "temperature_2m": data.temperature_2m,
                    "wind_speed_100m": data.wind_speed_100m,
                    "wind_speed_10m": data.wind_speed_10m,
                    "wind_direction_10m": data.wind_direction_10m,
                    "shortwave_radiation": data.shortwave_radiation,
                    "timestamp": data.timestamp.isoformat()
                })
        
        return results
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
            HourlyWeatherData.district_name.is_(None),  # Sadece il merkezi kayıtları
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
    province: str = Query(..., description="İl adı (ör: İstanbul)"),
    hours: int = Query(
        default=168,
        ge=1,
        le=720,
        description="Analiz penceresi (saat, varsayılan 7 gün = 168)",
    ),
):
    """
    Belirli bir ile ait ilçe bazlı hava durumu özeti.
    district_name IS NOT NULL olan kayıtlardan city_name+district_name gruplama yapar.
    """
    # ── Cache kontrolü (TTL: 15 dakika, il bazlı key) ────────────────────────
    cache_key = f"weather:district-summary:{province.strip().lower()}:{hours}"
    cached = cache_get(cache_key)
    if cached is not None:
        return [DistrictSummary(**item) for item in cached]

    db = SystemSessionLocal()
    try:
        cutoff = datetime.now() - timedelta(hours=hours)
        province_lower = province.strip().lower()

        results = db.query(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
            func.avg(HourlyWeatherData.latitude).label("lat"),
            func.avg(HourlyWeatherData.longitude).label("lon"),
            func.avg(HourlyWeatherData.wind_speed_100m).label("avg_wind"),
            func.avg(HourlyWeatherData.shortwave_radiation).label("avg_radiation"),
            func.avg(HourlyWeatherData.temperature_2m).label("avg_temp"),
            func.count(HourlyWeatherData.id).label("record_count"),
        ).filter(
            HourlyWeatherData.timestamp >= cutoff,
            HourlyWeatherData.district_name.isnot(None),
            func.lower(HourlyWeatherData.city_name) == province_lower,
        ).group_by(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
        ).all()

        result = [
            DistrictSummary(
                district_name=r.district_name,
                province_name=r.city_name,
                lat=round(float(r.lat), 4) if r.lat else None,
                lon=round(float(r.lon), 4) if r.lon else None,
                avg_wind_speed=round(r.avg_wind, 2) if r.avg_wind else None,
                avg_radiation=round(r.avg_radiation, 1) if r.avg_radiation else None,
                avg_temperature=round(r.avg_temp, 2) if r.avg_temp else None,
                record_count=int(r.record_count),
            )
            for r in results
            if r.district_name
        ]
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
            HourlyWeatherData.district_name.is_(None),
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
                metric_col.label("val"),
            ).filter(
                WeatherData.date >= start_date,
                WeatherData.date <= end_date,
                metric_col.isnot(None),
            ).order_by(WeatherData.date).all()

            # Tarih → [(lat, lon, val)] gruplama
            frames_dict = defaultdict(list)
            all_vals = []
            for row in rows:
                v = round(float(row.val), 3)
                frames_dict[row.date.isoformat()].append([
                    round(row.latitude, 4),
                    round(row.longitude, 4),
                    v,
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
                metric_col.label("val"),
            ).filter(
                HourlyWeatherData.timestamp >= start_ts,
                HourlyWeatherData.timestamp <= end_ts,
                metric_col.isnot(None),
                HourlyWeatherData.district_name.is_(None),  # Sadece il merkezi
            ).order_by(HourlyWeatherData.timestamp).all()

            # Timestamp → [(lat, lon, val)] gruplama (saatlik hassasiyet)
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

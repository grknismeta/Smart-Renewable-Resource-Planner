"""
Şehir Bazlı Hava Durumu API Endpoint'leri
=========================================

81 il için saatlik ve günlük hava durumu verilerine erişim.
"""

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, timedelta
from pydantic import BaseModel

from backend.db.database import SystemSessionLocal
from backend.db.models import HourlyWeatherData
from ..turkey_cities import TURKEY_CITIES

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
        target_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        
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
                    func.julianday(HourlyWeatherData.timestamp) - func.julianday(target_time)
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

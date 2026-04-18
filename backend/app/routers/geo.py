from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services.geo_service import GeoService as GeoAnalyzer
from app.core.logger import logger

# Router'ı oluştur
router = APIRouter(tags=["Geo Spatial Analysis"])

# GeoAnalyzer'ı global (module-level) olarak başlatıyoruz ki her istekte shapefile yüklemesin.
# Bu işlem backend başlarken (router import edildiğinde) bir kez yapılır.
try:
    analyzer = GeoAnalyzer()
except Exception as e:
    logger.warning("GeoAnaliz başlatılamadı (Shapefile eksik olabilir): {}", e)
    analyzer = None


class GeoCheckRequest(BaseModel):
    latitude: float
    longitude: float


@router.get("/city")
def get_city_for_coords(lat: float, lon: float):
    """
    Koordinata göre il ve ilçe adını döndürür (reverse geocoding).
    Örnek: GET /geo/city?lat=39.92&lon=32.85
    """
    if analyzer is None:
        logger.error("GeoAnalyzer None — shapefile yüklenememiş! Backend'i yeniden başlatın.")
        return {"province": "", "district": "", "error": "geo_service_not_initialized"}
    try:
        from shapely.geometry import Point
        point = Point(lon, lat)
        info = analyzer._get_location_info(point, lat, lon)
        if not info.get("province"):
            logger.debug("Reverse geocoding: boş sonuç ({}, {}) — nokta Türkiye dışında olabilir", lat, lon)
        return info
    except Exception as e:
        logger.error("Reverse geocoding hatası ({}, {}): {}", lat, lon, e)
        return {"province": "", "district": ""}


@router.post("/check-suitability")
def check_geo_suitability(request: GeoCheckRequest):
    """
    Verilen koordinatın Rüzgar ve Güneş enerjisi için uygunluğunu analiz eder.
    Coğrafi kısıtlamaları (su, yol, bina, eğim) kontrol eder.
    """
    try:
        result = analyzer.analyze_location(request.latitude, request.longitude)
        return result
    except Exception as e:
        logger.error("Geo suitability hatası ({}, {}): {}", request.latitude, request.longitude, e)
        raise HTTPException(status_code=500, detail=str(e))

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from ..geo_analyzer import GeoAnalyzer

# Router'ı oluştur
router = APIRouter(tags=["Geo Spatial Analysis"])

# GeoAnalyzer'ı global (module-level) olarak başlatıyoruz ki her istekte shapefile yüklemesin.
# Bu işlem backend başlarken (router import edildiğinde) bir kez yapılır.
analyzer = GeoAnalyzer()



class GeoCheckRequest(BaseModel):
    latitude: float
    longitude: float

@router.post("/check-suitability")
async def check_geo_suitability(request: GeoCheckRequest):
    """
    Verilen koordinatın Rüzgar ve Güneş enerjisi için uygunluğunu analiz eder.
    Coğrafi kısıtlamaları (su, yol, bina, eğim) kontrol eder.
    """
    try:
        # Analizi çalıştır
        result = analyzer.analyze_location(request.latitude, request.longitude)
        return result
    except Exception as e:
        print(f"Geo Check Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
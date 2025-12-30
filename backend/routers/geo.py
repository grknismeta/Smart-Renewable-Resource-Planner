from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
# from backend.services.geo_service import GeoService as GeoAnalyzer
GeoAnalyzer = None # Geçici olarak devre dışı

# Router'ı oluştur
router = APIRouter(tags=["Geo Spatial Analysis"])

# GeoAnalyzer'ı global (module-level) olarak başlatıyoruz ki her istekte shapefile yüklemesin.
# Bu işlem backend başlarken (router import edildiğinde) bir kez yapılır.
analyzer = None # GeoAnalyzer()



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
        if analyzer is None:
             # Analiz motoru kapalıysa her yeri uygun kabul et
             return {
                "suitable": True,
                "recommendation": "⚠️ Coğrafi analiz devre dışı (Her yer uygun)",
                "location": {"province": "Bilinmiyor", "district": "Bilinmiyor"},
                "elevation": 0,
                "slope": 0,
                "restricted_area": [],
                "solar_details": {
                    "suitable": True,
                    "message": "✅ Analiz devre dışı (Uygun)",
                    "reasons": [],
                    "notes": ["Coğrafi kontrol yapılmadı"]
                },
                "wind_details": {
                    "suitable": True,
                    "message": "✅ Analiz devre dışı (Uygun)",
                    "reasons": [],
                    "notes": ["Coğrafi kontrol yapılmadı"]
                }
             }
             
        # Analizi çalıştır
        result = analyzer.analyze_location(request.latitude, request.longitude)
        return result
    except Exception as e:
        print(f"Geo Check Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
# Bu dosya, Türkiye'nin Doğu yarısını tarar (Boylam 35.5'ten 44.0'a kadar)
# Tek bir bilgisayarda (tek DB dosyasını hedefleyerek) parçalı çalışmaya uygundur.

import requests
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Dict, Any, Tuple, Optional
import time

# DÜZELTME: SystemSessionLocal import edildi
from .database import SystemSessionLocal as SessionLocal 
from . import models, schemas
from .solar_calculations import get_historical_hourly_solar_data
from .wind_calculations import get_historical_hourly_wind_data

# --- TEST SINIRLARI (Boylam: 35.5 - 44.0) ---
TURKEY_BOUNDS = {
    "lat_min": 36.0,
    "lat_max": 42.0,
    "lon_min": 35.5, # Doğu Bölgesi (Çakışmayı önlemek için 35.5'ten başladık)
    "lon_max": 44.0, 
}
GRID_STEP = 0.5 # Test amaçlı 0.5'te kalmalı

def calculate_logistics_score(lat: float, lon: float) -> float:
    """Simulates logistics score based on distance from center."""
    distance_factor = abs(lat - (TURKEY_BOUNDS["lat_max"] + TURKEY_BOUNDS["lat_min"]) / 2)
    score = max(0.4, 1.0 - (distance_factor / 10.0))
    return round(score, 2)

def perform_grid_analysis(db: Session, resource_type: str):
    """Performs grid scan and saves results to DB."""
    print(f"\n--- BAŞLANGIÇ: Grid Taraması ({resource_type}) - DOĞU ---")
    
    start_time = datetime.now()
    total_points = 0
    new_data_count = 0
    
    current_lat = TURKEY_BOUNDS["lat_min"]
    
    # 1. Grid noktalarında döngüye gir
    while current_lat <= TURKEY_BOUNDS["lat_max"]:
        current_lon = TURKEY_BOUNDS["lon_min"]
        
        while current_lon <= TURKEY_BOUNDS["lon_max"]:
            
            lat = round(current_lat, 2)
            lon = round(current_lon, 2)
            total_points += 1
            
            # 2. Önbellek Kontrolü (Veri 30 günden eskiyse güncelle)
            existing_analysis: Optional[models.GridAnalysis] = db.query(models.GridAnalysis).filter(
                models.GridAnalysis.latitude == lat,
                models.GridAnalysis.longitude == lon,
                models.GridAnalysis.type == resource_type
            ).first()
            
            is_valid_cache = False
            if existing_analysis and existing_analysis.updated_at is not None:
                 if (datetime.now() - existing_analysis.updated_at) < timedelta(days=30): # type: ignore
                     is_valid_cache = True
            
            if is_valid_cache:
                current_lon += GRID_STEP
                continue
            
            print(f" -> Hesaplama: {lat}, {lon}")
            
            # 3. Veriyi Çek ve ML Tahmini Yap
            data: Dict[str, Any] = {"error": "API çağrılmadı"}
            
            # --- HATA YÖNETİMİ (EXPONENTIAL BACKOFF) ---
            retry_attempts = 3
            for attempt in range(retry_attempts):
                try:
                    if resource_type == "Solar":
                        data_result = get_historical_hourly_solar_data(lat, lon)
                    elif resource_type == "Wind":
                        data_result = get_historical_hourly_wind_data(lat, lon)
                    else:
                        data_result = {"error": "Bilinmeyen kaynak tipi"}
                        
                    if isinstance(data_result, dict):
                        data = data_result
                    else:
                        data = {"error": "Hesaplama fonksiyonu geçersiz tip döndürdü."}
                        
                    if "error" not in data:
                        break
                    
                    if attempt < retry_attempts - 1 and "429 Client Error" in data.get("error", ""):
                        wait_time = 2 ** attempt * 10 
                        print(f"   [UYARI]: 429 hatası. {wait_time} saniye bekleniyor...")
                        time.sleep(wait_time)
                    else:
                        break 
                except Exception as e:
                    data = {"error": str(e)}
                    break
            # --- HATA YÖNETİMİ BİTTİ ---
            
            # 4. Skorlama ve Kayıt
            potential = data.get("annual_total_ghi_kwh", 0.0) if resource_type == "Solar" else data.get("avg_wind_speed_ms", 0.0)
            predicted_data = data.get("future_prediction", {}).get("monthly_predictions", []) 
            
            if "error" in data:
                print(f"   [SONUÇ]: Hesaplama başarısız oldu: {data['error']}")
                overall_score = 0.0 
                logistics_score = 0.0
            else:
                logistics_score = calculate_logistics_score(lat, lon)
                overall_score = float(potential) * logistics_score 
            
            new_data_count += 1
            
            if existing_analysis:
                existing_analysis.annual_potential_kwh_m2 = potential if resource_type == "Solar" else None # type: ignore
                existing_analysis.avg_wind_speed_ms = potential if resource_type == "Wind" else None # type: ignore
                existing_analysis.logistics_score = logistics_score # type: ignore
                existing_analysis.predicted_monthly_data = predicted_data # type: ignore
                existing_analysis.overall_score = overall_score # type: ignore
            else:
                db_grid = models.GridAnalysis(
                    latitude=lat,
                    longitude=lon,
                    type=resource_type,
                    annual_potential_kwh_m2=potential if resource_type == "Solar" else None,
                    avg_wind_speed_ms=potential if resource_type == "Wind" else None,
                    logistics_score=logistics_score,
                    predicted_monthly_data=predicted_data,
                    overall_score=overall_score,
                )
                db.add(db_grid)
            
            db.commit()
            
            current_lon += GRID_STEP
            
            # SABİT GECİKME
            time.sleep(5) 
            
        current_lat += GRID_STEP

    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds() / 60
    print(f"\n--- Grid Taraması Tamamlandı ({resource_type}) ---")
    print(f"Toplam Kontrol Edilen Nokta: {total_points}")
    print(f"Yeni Hesaplanan/Güncellenen Nokta: {new_data_count}")
    print(f"Süre: {duration:.1f} dakika.")
    
def run_grid_search_all():
    # DÜZELTME: SystemSessionLocal kullanıldı
    db = SessionLocal() 
    try:
        perform_grid_analysis(db, "Solar")
        perform_grid_analysis(db, "Wind")
    finally:
        db.close()

if __name__ == "__main__":
    run_grid_search_all()
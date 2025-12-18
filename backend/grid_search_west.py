import requests
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Dict, Any, Tuple, Optional
import time # <-- BU SATIRI EKLE

# DÜZELTME: SystemSessionLocal import edildi
from .database import SystemSessionLocal as SessionLocal 
from . import models, schemas
# Solar ve Wind fonksiyonlarını import ettiğimizden emin olalım
from .solar_calculations import get_historical_hourly_solar_data
from .wind_calculations import get_wind_speed_from_coordinates

# --- TÜRKİYE SINIRLARI ve GRID AYARLARI ---
TURKEY_BOUNDS = {
    "lat_min": 36.0,
    "lat_max": 42.0,
    "lon_min": 26.0,
    "lon_max": 44.0,
}
# 0.5 derece (~55 km). Test amaçlı geçici olarak düşürüldü.
GRID_STEP = 0.5 

def calculate_logistics_score(lat: float, lon: float) -> float:
    """
    Overpass API ile yol ve yerleşim yerine uzaklık skorunu hesaplar.
    Şimdilik bu kısım simülasyondur.
    """
    distance_factor = abs(lat - (TURKEY_BOUNDS["lat_max"] + TURKEY_BOUNDS["lat_min"]) / 2)
    score = max(0.4, 1.0 - (distance_factor / 10.0))
    return round(score, 2)

def perform_grid_analysis(db: Session, resource_type: str):
    """
    Belirli bir kaynak tipi için Türkiye üzerinde grid taraması yapar.
    """
    print(f"\n--- BAŞLANGIÇ: Grid Taraması ({resource_type}) ---")
    
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
            
            # 2. Önbellek Kontrolü (Veri 30 günden eskiyse VEYA SKOR SIFIRSA güncelle)
            existing_analysis: Optional[models.GridAnalysis] = db.query(models.GridAnalysis).filter(
                models.GridAnalysis.latitude == lat,
                models.GridAnalysis.longitude == lon,
                models.GridAnalysis.type == resource_type
            ).first()
            
            should_recalculate = True
            
            if existing_analysis is not None:
                # Kontrol 1: Başarılı Skor Kontrolü (Skor > 0.0 ise ATLA, 30 günlük kuralı sadece temizlik için kullan)
                if existing_analysis.overall_score > 0.0: # type: ignore
                    
                    # Kontrol 2: 30 günlük güncellik kontrolü (Sadece veriyi tazelemek için)
                    if existing_analysis.updated_at is not None:# 30 günden yeniyse ve skor > 0.0 ise ATLA
                        if (datetime.now() - existing_analysis.updated_at) < timedelta(days=30): # type: ignore
                            should_recalculate = False 
                    
                    # Eğer updated_at None ise (ki bu olmamalı) veya 30 günden eskiyse,
                    # Skor > 0.0 olduğu için yine de yeniden hesaplamayı kapatabiliriz, 
                    # ancak 30 günlük kurala uyalım. Şimdilik > 0.0 olanı atlayalım:
                    
                    # GEREKSİZ TEKRAR HESAPLAMAYI ÖNLEME:
                    # Skor 0'dan büyükse, 30 gün kuralı önemli değil, ATLA.
                    if should_recalculate == True: # Eğer yukarıdaki 30 gün kontrolünde True kaldıysa
                        should_recalculate = False # Güvenlik için tekrar hesaplama
                        # Pylance Hatasını gidermek için biraz daha sadeleştirebiliriz:
                        
                        # Eğer skor > 0.0 ise, HESAPLAMAYI KAPAT
                        if existing_analysis.overall_score > 0.0: # type: ignore
                            should_recalculate = False 
                
            # Eğer yeniden hesaplama yapmamamız gerekiyorsa (should_recalculate == False)
            if not should_recalculate:
                # Veri yeni/başarılı ve skor > 0.0, atla
                current_lon += GRID_STEP
                continue
            
            # Eğer buraya geldiyse: ya yeni bir nokta, ya skor = 0.0 (hata) ya da updated_at çok eski.
            
            print(f" -> Hesaplama: {lat}, {lon}")
            
            # 3. Veriyi Çek ve ML Tahmini Yap (Hata Kontrolü EKLENDİ)
            data: Dict[str, Any] = {"error": "API çağrılmadı"} # Başlangıç değeri
            
            # --- YENİ EKLENEN HATA YÖNETİMİ ---
            retry_attempts = 3
            for attempt in range(retry_attempts):
                try:
                    if resource_type == "Solar":
                        data_result = get_historical_hourly_solar_data(lat, lon)
                    elif resource_type == "Wind":
                        data_result = get_wind_speed_from_coordinates(lat, lon)
                    else:
                        data_result = {"error": "Bilinmeyen kaynak tipi"}
                        
                    # Hata kodu olarak str dönebilir, dict dönebilir. dict döndüğünden emin olalım.
                    if isinstance(data_result, dict):
                        data = data_result
                    else:
                        data = {"error": "Hesaplama fonksiyonu geçersiz tip döndürdü."}
                        
                    if "error" not in data:
                        break # Başarılı oldu, döngüden çık
                    
                    if attempt < retry_attempts - 1 and "429 Client Error" in data.get("error", ""):
                        wait_time = 2 ** attempt * 5 # 5, 10, 20 saniye bekle
                        print(f"   [UYARI]: 429 hatası. {wait_time} saniye bekleniyor...")
                        time.sleep(wait_time)
                    else:
                        break # Diğer hatalarda veya son denemede döngüden çık
                except Exception as e:
                    data = {"error": str(e)}
                    break
            # --- HATA YÖNETİMİ BİTTİ ---

            
            # Hata Giderildi: data'nın dict olduğundan emin olduktan sonra .get() çağırıyoruz.
            potential = data.get("annual_total_ghi_kwh", 0.0) if resource_type == "Solar" else data.get("avg_wind_speed_ms", 0.0)
            
            # predicted_data'yı güvenle alıyoruz
            predicted_data = data.get("future_prediction", {}).get("monthly_predictions", []) 
            
            # Hata Giderildi: Eğer hata varsa potential 0.0'dır, str olma ihtimali kalktı.
            if "error" in data:
                print(f"   [SONUÇ]: Hesaplama başarısız oldu: {data['error']}")
                overall_score = 0.0 
                logistics_score = 0.0
            else:
                # 4. Lojistik ve Genel Skorlama
                logistics_score = calculate_logistics_score(lat, lon)
                overall_score = float(potential) * logistics_score 
            
            # 5. Veritabanına Kaydet/Güncelle
            new_data_count += 1
            
            if existing_analysis:
                # Güncelle
                existing_analysis.annual_potential_kwh_m2 = potential if resource_type == "Solar" else None # type: ignore
                existing_analysis.avg_wind_speed_ms = potential if resource_type == "Wind" else None # type: ignore
                existing_analysis.logistics_score = logistics_score # type: ignore
                existing_analysis.predicted_monthly_data = predicted_data # type: ignore
                existing_analysis.overall_score = overall_score # type: ignore
                
            else:
                # Yeni Ekle
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
            
        current_lat += GRID_STEP

    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds() / 60
    print(f"\n--- Grid Taraması Tamamlandı ({resource_type}) ---")
    print(f"Toplam Kontrol Edilen Nokta: {total_points}")
    print(f"Yeni Hesaplanan/Güncellenen Nokta: {new_data_count}")
    print(f"Süre: {duration:.1f} dakika.")
    
def run_grid_search_all():
    """Tüm kaynak tipleri için taramayı başlatan ana fonksiyon."""
    db = SessionLocal()
    try:
        perform_grid_analysis(db, "Solar")
        perform_grid_analysis(db, "Wind")
    finally:
        db.close()

if __name__ == "__main__":
    run_grid_search_all()
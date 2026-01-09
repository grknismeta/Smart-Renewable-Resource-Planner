
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.db.database import SystemSessionLocal, SystemEngine, SystemBase
from app.db.models import WeatherData, GridAnalysis
import time

def generate_grid_analysis():
    """
    WeatherData tablosundaki ham verileri analiz eder ve 
    harita renklendirmesi için GridAnalysis tablosuna özet rapor yazar.
    """
    # Tablolarý garantile
    SystemBase.metadata.create_all(bind=SystemEngine)
    
    db = SystemSessionLocal()
    print("--- Grid Analiz Motoru Baþlatýlýyor ---")
    
    # 1. Mevcut Analizleri Temizle (Yeniden oluþturuyoruz)
    db.query(GridAnalysis).delete()
    db.commit()
    print("Eski harita verileri temizlendi.")

    # 2. Tüm benzersiz koordinatlarý bul
    locations = db.query(
        WeatherData.latitude, 
        WeatherData.longitude
    ).group_by(WeatherData.latitude, WeatherData.longitude).all()
    
    print(f"Toplam {len(locations)} farklý lokasyon analiz edilecek...")
    
    grid_objects = []
    
    for idx, (lat, lon) in enumerate(locations):
        # --- Ýstatistikleri Çek ---
        stats = db.query(
            func.avg(WeatherData.shortwave_radiation_sum).label("avg_rad"), # MJ/m2
            func.avg(WeatherData.wind_speed_mean).label("avg_wind")  # m/s
        ).filter(
            WeatherData.latitude == lat,
            WeatherData.longitude == lon
        ).first()
        
        if not stats: continue

        # --- GÜNEÞ ANALÝZÝ (Solar Grid) ---
        # MJ -> kWh (1 kWh = 3.6 MJ)
        avg_rad_kwh = (stats.avg_rad / 3.6) if stats.avg_rad else 0
        
        # Skorlama (0-100 arasý): Türkiye'de ortalama 3.8 - 5.5 kWh arasýdýr.
        # 3.0 altý = 0 puan, 6.0 üstü = 100 puan diyelim.
        solar_score = min(100, max(0, (avg_rad_kwh - 3.0) / (6.0 - 3.0) * 100))
        
        solar_grid = GridAnalysis(
            latitude=lat,
            longitude=lon,
            type="Solar",
            annual_potential_kwh_m2=avg_rad_kwh * 365,
            avg_wind_speed_ms=stats.avg_wind,
            overall_score=round(solar_score, 1),
            logistics_score=1.0 # Þimdilik sabit
        )
        grid_objects.append(solar_grid)

        # --- RÜZGAR ANALÝZÝ (Wind Grid) ---
        avg_wind = stats.avg_wind if stats.avg_wind else 0
        
        # Skorlama: 3 m/s altý çöp, 9 m/s üstü harika.
        wind_score = min(100, max(0, (avg_wind - 3.0) / (9.0 - 3.0) * 100))
        
        wind_grid = GridAnalysis(
            latitude=lat,
            longitude=lon,
            type="Wind",
            annual_potential_kwh_m2=0, # Rüzgar için bu alan boþ kalabilir
            avg_wind_speed_ms=avg_wind,
            overall_score=round(wind_score, 1),
            logistics_score=1.0
        )
        grid_objects.append(wind_grid)
        
        if idx % 50 == 0:
            print(f"Ýþlenen: {idx}/{len(locations)}")

    # Toplu Kayýt
    db.bulk_save_objects(grid_objects)
    db.commit()
    db.close()
    
    print(f" Analiz Tamamlandý! {len(grid_objects)} adet grid hücresi oluþturuldu.")
    print("Flutter haritasý artýk bu verileri kullanabilir.")

if __name__ == "__main__":
    generate_grid_analysis()
import openmeteo_requests
import requests_cache
import pandas as pd
from retry_requests import retry
from sqlalchemy import select
from sqlalchemy.orm import Session
from datetime import date
from .database import SystemSessionLocal, SystemEngine, SystemBase
from .models import WeatherData
import numpy as np
import time

# --- AYARLAR ---
START_DATE = "2014-01-01"
END_DATE = "2023-12-31"

# Türkiye Sınırları
LAT_MIN, LAT_MAX = 36.0, 42.0
LON_MIN, LON_MAX = 26.0, 45.0
GRID_STEP = 0.5 

# Arşiv API URL'si
OPEN_METEO_URL = "https://archive-api.open-meteo.com/v1/archive"

def generate_grid_points():
    """Türkiye haritası üzerinde grid noktaları oluşturur."""
    lats = np.arange(LAT_MIN, LAT_MAX, GRID_STEP)
    lons = np.arange(LON_MIN, LON_MAX, GRID_STEP)
    
    points = []
    for lat in lats:
        for lon in lons:
            points.append((round(lat, 2), round(lon, 2)))
    return points

def check_if_exists(db: Session, lat, lon):
    """Veritabanında bu nokta için veri var mı kontrol eder."""
    exists = db.execute(
        select(WeatherData.id).where(
            WeatherData.latitude == lat, 
            WeatherData.longitude == lon
        ).limit(1)
    ).first()
    return exists is not None

def setup_client():
    """
    Open-Meteo istemcisini cache ve retry mekanizmasıyla hazırlar.
    """
    # Önbellek dizini (.cache klasörüne kaydeder, expire_after=-1 sonsuza kadar tutar)
    cache_session = requests_cache.CachedSession('.cache', expire_after=-1)
    
    # Retry mekanizması: Hata alırsa 5 kereye kadar dener, her seferinde bekler
    retry_session = retry(cache_session, retries=5, backoff_factor=0.2)
    
    return openmeteo_requests.Client(session=retry_session)

def save_response_to_db(db: Session, response, lat, lon):
    """Open-Meteo Binary yanıtını işleyip DB'ye kaydeder."""
    
    # Günlük veriyi al
    daily = response.Daily()
    
    # İstenen değişkenlerin sırasına göre veriyi çekiyoruz (params'daki sırayla aynı olmalı)
    # 0: temperature_2m_mean
    # 1: wind_speed_10m_max
    # 2: wind_speed_10m_mean
    # 3: wind_direction_10m_dominant
    # 4: shortwave_radiation_sum
    
    daily_temp_mean = daily.Variables(0).ValuesAsNumpy()
    daily_wind_max = daily.Variables(1).ValuesAsNumpy()
    daily_wind_mean = daily.Variables(2).ValuesAsNumpy()
    daily_wind_dir = daily.Variables(3).ValuesAsNumpy()
    daily_rad_sum = daily.Variables(4).ValuesAsNumpy()

    # Tarih aralığını oluştur
    daily_data = {"date": pd.date_range(
        start=pd.to_datetime(daily.Time(), unit="s", utc=True),
        end=pd.to_datetime(daily.TimeEnd(), unit="s", utc=True),
        freq=pd.Timedelta(seconds=daily.Interval()),
        inclusive="left"
    )}
    
    dates = daily_data["date"]
    weather_objects = []
    
    for i in range(len(dates)):
        # Pandas Timestamp'i Python date objesine çevir
        current_date = dates[i].date()
        
        w_obj = WeatherData(
            latitude=lat,
            longitude=lon,
            date=current_date,
            temperature_mean=float(daily_temp_mean[i]),
            wind_speed_max=float(daily_wind_max[i]),
            wind_speed_mean=float(daily_wind_mean[i]),
            wind_direction_dominant=float(daily_wind_dir[i]),
            shortwave_radiation_sum=float(daily_rad_sum[i])
        )
        weather_objects.append(w_obj)
        
    db.bulk_save_objects(weather_objects)
    db.commit()

def main():
    # Tabloları oluştur
    SystemBase.metadata.create_all(bind=SystemEngine)
    
    # Client'ı hazırla
    openmeteo = setup_client()
    
    points = generate_grid_points()
    db = SystemSessionLocal()
    
    print("♻️  Veritabanı kontrol ediliyor...")
    points_to_fetch = []
    for lat, lon in points:
        if not check_if_exists(db, lat, lon):
            points_to_fetch.append((lat, lon))
            
    total = len(points)
    remaining = len(points_to_fetch)
    
    print(f"🌍 Toplam Hedef: {total}")
    print(f"🚀 İndirilecek: {remaining} nokta")
    print("📦 Mod: 'Open-Meteo SDK' (Otomatik Cache & Retry)")
    
    if remaining == 0:
        print("🎉 Tüm veriler zaten mevcut!")
        return

    # Değişkenler (Sırası save_response_to_db ile aynı olmalı)
    params = {
        "start_date": START_DATE,
        "end_date": END_DATE,
        "daily": ["temperature_2m_mean", "wind_speed_10m_max", "wind_speed_10m_mean", "wind_direction_10m_dominant", "shortwave_radiation_sum"],
        "timezone": "auto"
    }

    # Döngü
    for i, (lat, lon) in enumerate(points_to_fetch):
        params["latitude"] = lat
        params["longitude"] = lon
        
        try:
            # API Çağrısı (SDK otomatik retry yapar)
            responses = openmeteo.weather_api(OPEN_METEO_URL, params=params)
            response = responses[0] # Tek lokasyon istediğimiz için ilkini alıyoruz
            
            save_response_to_db(db, response, lat, lon)
            
            print(f"✅ [{i+1}/{remaining}] Kaydedildi: {lat}, {lon}")
            
            # Nezaket beklemesi (SDK hızlıdır ama sunucuyu yormayalım)
            time.sleep(1.5) 
            
        except Exception as e:
            print(f"❌ Hata ({lat}, {lon}): {e}")
            time.sleep(5) # Hata durumunda biraz bekle

    db.close()
    print("\n🎉 Veri toplama işlemi başarıyla tamamlandı!")

if __name__ == "__main__":
    main()
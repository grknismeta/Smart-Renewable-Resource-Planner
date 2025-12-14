import openmeteo_requests
import requests_cache
import pandas as pd
from retry_requests import retry
from sqlalchemy import select
from sqlalchemy.orm import Session
from datetime import date, datetime
from .database import SystemSessionLocal, SystemEngine, SystemBase
from .models import WeatherData
import numpy as np
import time

# --- AYARLAR ---
# Yıl bazlı çekme (her yıl için ayrı istek = daha güvenilir)
YEARS_TO_FETCH = list(range(2015, 2025))  # 2015-2024 (Archive API)
FETCH_2025 = True  # 2025 için ayrı forecast API kullan

# Türkiye Sınırları
LAT_MIN, LAT_MAX = 36.0, 42.0
LON_MIN, LON_MAX = 26.0, 45.0
GRID_STEP = 0.5 

# Batch ayarları - Rate limit'e takılmamak için küçük tutuyoruz
BATCH_SIZE = 10  # 10 nokta/istek (1 yıl verisi büyük)

# API URL'leri
ARCHIVE_API_URL = "https://archive-api.open-meteo.com/v1/archive"
FORECAST_API_URL = "https://historical-forecast-api.open-meteo.com/v1/forecast"

def generate_grid_points():
    """Türkiye haritası üzerinde grid noktaları oluşturur."""
    lats = np.arange(LAT_MIN, LAT_MAX, GRID_STEP)
    lons = np.arange(LON_MIN, LON_MAX, GRID_STEP)
    
    points = []
    for lat in lats:
        for lon in lons:
            points.append((round(lat, 2), round(lon, 2)))
    return points

def setup_client(timeout=120):
    """Open-Meteo istemcisini cache ve retry mekanizmasıyla hazırlar."""
    cache_session = requests_cache.CachedSession('.cache', expire_after=-1)
    # timeout parametresi requests session'a geçmez, bu yüzden retry'da backoff artırıyoruz
    retry_session = retry(cache_session, retries=5, backoff_factor=0.5)
    return openmeteo_requests.Client(session=retry_session)

def save_response_to_db(db: Session, response, lat, lon):
    """Open-Meteo Binary yanıtını işleyip DB'ye kaydeder."""
    daily = response.Daily()
    
    # Değişken sırası: temp_mean, wind_max, wind_mean, wind_dir, radiation
    daily_temp_mean = daily.Variables(0).ValuesAsNumpy()
    daily_wind_max = daily.Variables(1).ValuesAsNumpy()
    daily_wind_mean = daily.Variables(2).ValuesAsNumpy()
    daily_wind_dir = daily.Variables(3).ValuesAsNumpy()
    daily_rad_sum = daily.Variables(4).ValuesAsNumpy()

    dates = pd.date_range(
        start=pd.to_datetime(daily.Time(), unit="s", utc=True),
        end=pd.to_datetime(daily.TimeEnd(), unit="s", utc=True),
        freq=pd.Timedelta(seconds=daily.Interval()),
        inclusive="left"
    )
    
    weather_objects = []
    for i in range(len(dates)):
        w_obj = WeatherData(
            latitude=lat,
            longitude=lon,
            date=dates[i].date(),
            temperature_mean=float(daily_temp_mean[i]),
            wind_speed_max=float(daily_wind_max[i]),
            wind_speed_mean=float(daily_wind_mean[i]),
            wind_direction_dominant=float(daily_wind_dir[i]),
            shortwave_radiation_sum=float(daily_rad_sum[i])
        )
        weather_objects.append(w_obj)
        
    db.bulk_save_objects(weather_objects)

def check_if_exists_for_year(db: Session, lat: float, lon: float, year: int) -> bool:
    """Veritabanında bu nokta ve yıl için veri var mı kontrol eder."""
    start_date = date(year, 1, 1)
    end_date = date(year, 12, 31)
    
    exists = db.execute(
        select(WeatherData.id).where(
            WeatherData.latitude == lat, 
            WeatherData.longitude == lon,
            WeatherData.date >= start_date,
            WeatherData.date <= end_date
        ).limit(1)
    ).first()
    return exists is not None

def save_batch_responses_to_db(db: Session, responses, batch_points):
    """Toplu API yanıtlarını işleyip DB'ye kaydeder."""
    for idx, response in enumerate(responses):
        lat, lon = batch_points[idx]
        save_response_to_db(db, response, lat, lon)
    db.commit()

def fetch_year_data(openmeteo, db: Session, points: list, year: int, api_url: str):
    """Belirli bir yıl için tüm noktaların verisini çeker."""
    
    # Bu yıl için eksik noktaları bul
    points_to_fetch = []
    for lat, lon in points:
        if not check_if_exists_for_year(db, lat, lon, year):
            points_to_fetch.append((lat, lon))
    
    if not points_to_fetch:
        print(f"   ✓ {year} yılı zaten mevcut, atlanıyor...")
        return
    
    print(f"   📥 {year} yılı: {len(points_to_fetch)} nokta indirilecek")
    
    # 2025 için daha küçük batch (Historical Forecast API daha yavaş)
    current_batch_size = 3 if year == 2025 else BATCH_SIZE
    
    # Batch'lere ayır
    batches = [points_to_fetch[i:i + current_batch_size] for i in range(0, len(points_to_fetch), current_batch_size)]
    total_batches = len(batches)
    
    for batch_idx, batch_points in enumerate(batches):
        lats = [p[0] for p in batch_points]
        lons = [p[1] for p in batch_points]
        
        # 2025 için end_date bugünden 5 gün önce olmalı
        if year == 2025:
            end_date = (datetime.now() - pd.Timedelta(days=5)).strftime("%Y-%m-%d")
            start_date = "2025-01-01"
        else:
            start_date = f"{year}-01-01"
            end_date = f"{year}-12-31"
        
        params = {
            "latitude": lats,
            "longitude": lons,
            "start_date": start_date,
            "end_date": end_date,
            "daily": ["temperature_2m_mean", "wind_speed_10m_max", "wind_speed_10m_mean", "wind_direction_10m_dominant", "shortwave_radiation_sum"],
            "timezone": "auto"
        }
        
        max_retries = 5  # Daha fazla deneme
        for attempt in range(max_retries):
            try:
                responses = openmeteo.weather_api(api_url, params=params)
                save_batch_responses_to_db(db, responses, batch_points)
                
                print(f"      ✅ [{batch_idx+1}/{total_batches}] {len(batch_points)} nokta kaydedildi")
                time.sleep(5)  # Her başarılı istekten sonra 5 saniye bekle
                break
                
            except Exception as e:
                error_str = str(e)
                if "rate limit" in error_str.lower() or "limit exceeded" in error_str.lower():
                    # Exponential backoff: 60, 90, 120, 150, 180 saniye
                    wait_time = 60 + (attempt * 30)
                    print(f"      ⏳ Rate limit! {wait_time}s bekleniyor... (Deneme {attempt+1}/{max_retries})")
                    time.sleep(wait_time)
                else:
                    print(f"      ❌ Hata: {e}")
                    if attempt >= max_retries - 1:
                        print(f"      ⚠️ Batch atlandı!")
                        break
                    time.sleep(15)

def main():
    # Tabloları oluştur
    SystemBase.metadata.create_all(bind=SystemEngine)
    
    # Client'ı hazırla
    openmeteo = setup_client()
    
    points = generate_grid_points()
    db = SystemSessionLocal()
    
    print("=" * 50)
    print("🌍 OPEN-METEO VERİ TOPLAYICI")
    print("=" * 50)
    print(f"📍 Toplam nokta: {len(points)}")
    print(f"📅 Yıllar: {YEARS_TO_FETCH[0]} - {YEARS_TO_FETCH[-1]}" + (" + 2025" if FETCH_2025 else ""))
    print(f"📦 Batch boyutu: {BATCH_SIZE} nokta/istek")
    print("=" * 50)
    
    # Archive API ile 2015-2024 çek
    for year in YEARS_TO_FETCH:
        print(f"\n📆 {year} işleniyor...")
        fetch_year_data(openmeteo, db, points, year, ARCHIVE_API_URL)
    
    # 2025 için Historical Forecast API kullan
    if FETCH_2025:
        print(f"\n📆 2025 işleniyor (Historical Forecast API)...")
        fetch_year_data(openmeteo, db, points, 2025, FORECAST_API_URL)
    
    db.close()
    print("\n" + "=" * 50)
    print("🎉 Veri toplama işlemi tamamlandı!")
    print("=" * 50)

if __name__ == "__main__":
    main()
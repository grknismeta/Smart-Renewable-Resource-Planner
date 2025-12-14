"""
Günlük Veri Güncelleyici

Backend başladığında çalışır ve DB'deki son tarihten bugüne kadar
eksik olan günleri Open-Meteo Forecast API'den çeker.
"""

import openmeteo_requests
import requests_cache
import pandas as pd
from retry_requests import retry
from sqlalchemy import func, select
from sqlalchemy.orm import Session
from datetime import date, datetime, timedelta
from typing import List, Tuple
import asyncio
import time

from .database import SystemSessionLocal, SystemEngine
from .models import WeatherData

# API URL (Güncel veriler için Forecast API kullanılır)
FORECAST_API_URL = "https://api.open-meteo.com/v1/forecast"

# Türkiye grid noktaları (data_collector ile aynı)
LAT_MIN, LAT_MAX = 36.0, 42.0
LON_MIN, LON_MAX = 26.0, 45.0
GRID_STEP = 0.5

BATCH_SIZE = 15  # Forecast API daha hızlı, biraz büyük batch kullanabiliriz


def get_grid_points() -> List[Tuple[float, float]]:
    """Türkiye grid noktalarını döndürür."""
    import numpy as np
    lats = np.arange(LAT_MIN, LAT_MAX, GRID_STEP)
    lons = np.arange(LON_MIN, LON_MAX, GRID_STEP)
    
    points = []
    for lat in lats:
        for lon in lons:
            points.append((round(lat, 2), round(lon, 2)))
    return points


def get_last_date_in_db(db: Session) -> date | None:
    """Veritabanındaki en son veri tarihini döndürür."""
    result = db.execute(
        select(func.max(WeatherData.date))
    ).scalar()
    return result


def setup_client():
    """Open-Meteo client'ı hazırlar."""
    cache_session = requests_cache.CachedSession('.cache_daily', expire_after=3600)
    retry_session = retry(cache_session, retries=3, backoff_factor=0.3)
    return openmeteo_requests.Client(session=retry_session)


def save_responses_to_db(db: Session, responses, batch_points):
    """API yanıtlarını DB'ye kaydeder."""
    for idx, response in enumerate(responses):
        lat, lon = batch_points[idx]
        
        daily = response.Daily()
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
            # NaN kontrolü
            if pd.isna(daily_temp_mean[i]):
                continue
                
            w_obj = WeatherData(
                latitude=lat,
                longitude=lon,
                date=dates[i].date(),
                temperature_mean=float(daily_temp_mean[i]),
                wind_speed_max=float(daily_wind_max[i]) if not pd.isna(daily_wind_max[i]) else 0.0,
                wind_speed_mean=float(daily_wind_mean[i]) if not pd.isna(daily_wind_mean[i]) else 0.0,
                wind_direction_dominant=float(daily_wind_dir[i]) if not pd.isna(daily_wind_dir[i]) else 0.0,
                shortwave_radiation_sum=float(daily_rad_sum[i]) if not pd.isna(daily_rad_sum[i]) else 0.0
            )
            weather_objects.append(w_obj)
            
        if weather_objects:
            db.bulk_save_objects(weather_objects)
    
    db.commit()


def fetch_missing_days(start_date: date, end_date: date) -> int:
    """
    Belirtilen tarih aralığındaki eksik günleri çeker.
    Döndürür: Çekilen gün sayısı
    """
    openmeteo = setup_client()
    points = get_grid_points()
    db = SystemSessionLocal()
    
    days_fetched = 0
    
    try:
        # Batch'lere ayır
        batches = [points[i:i + BATCH_SIZE] for i in range(0, len(points), BATCH_SIZE)]
        
        for batch_idx, batch_points in enumerate(batches):
            lats = [p[0] for p in batch_points]
            lons = [p[1] for p in batch_points]
            
            params = {
                "latitude": lats,
                "longitude": lons,
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "daily": ["temperature_2m_mean", "wind_speed_10m_max", "wind_speed_10m_mean", 
                          "wind_direction_10m_dominant", "shortwave_radiation_sum"],
                "timezone": "auto"
            }
            
            try:
                responses = openmeteo.weather_api(FORECAST_API_URL, params=params)
                save_responses_to_db(db, responses, batch_points)
                
                if batch_idx == 0:
                    days_fetched = (end_date - start_date).days + 1
                    
                time.sleep(1)  # Rate limit koruması
                
            except Exception as e:
                print(f"[DailyUpdater] Batch {batch_idx+1} hatası: {e}")
                time.sleep(5)
                continue
                
    finally:
        db.close()
    
    return days_fetched


def check_and_update() -> str:
    """
    DB'yi kontrol eder ve eksik günleri doldurur.
    Backend başlangıcında çağrılır.
    
    Döndürür: Durum mesajı
    """
    db = SystemSessionLocal()
    
    try:
        last_date = get_last_date_in_db(db)
        
        if last_date is None:
            return "⚠️ Veritabanı boş. Lütfen 'python -m backend.data_collector' çalıştırın."
        
        today = date.today()
        # Forecast API genelde 2 gün öncesine kadar güvenilir veri verir
        target_date = today - timedelta(days=2)
        
        if last_date >= target_date:
            return f"✅ Veriler güncel (Son: {last_date})"
        
        # Eksik gün sayısı
        missing_days = (target_date - last_date).days
        
        if missing_days <= 0:
            return f"✅ Veriler güncel (Son: {last_date})"
        
        print(f"[DailyUpdater] {missing_days} gün eksik bulundu. Güncelleniyor...")
        
        # Eksik günleri çek (last_date'in ertesi gününden target_date'e kadar)
        start = last_date + timedelta(days=1)
        
        days_fetched = fetch_missing_days(start, target_date)
        
        return f"✅ {days_fetched} gün güncellendi ({start} → {target_date})"
        
    except Exception as e:
        return f"❌ Güncelleme hatası: {e}"
    finally:
        db.close()


async def async_check_and_update():
    """Asenkron wrapper - Backend başlangıcında çağrılır."""
    # CPU-bound işlemi thread pool'da çalıştır
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, check_and_update)
    print(f"[DailyUpdater] {result}")
    return result


# Test için
if __name__ == "__main__":
    print(check_and_update())

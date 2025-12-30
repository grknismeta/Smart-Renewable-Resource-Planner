import pandas as pd
from sqlalchemy import func
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import Optional, List
import time
import asyncio
import logging

from backend.db.database import SystemSessionLocal, SystemEngine, SystemBase
from backend.db.models import HourlyWeatherData
from backend.turkey_cities import TURKEY_CITIES

from .base import setup_client, FORECAST_API_URL, logger

# Configuration
HOURLY_PARAMS = [
    "temperature_2m",
    "apparent_temperature",
    "relative_humidity_2m",
    "precipitation",
    "cloud_cover",
    "wind_speed_10m",
    "wind_speed_100m",
    "wind_direction_10m",
    "wind_gusts_10m",
    "shortwave_radiation",
    "direct_radiation",
    "diffuse_radiation"
]

BATCH_SIZE = 10
DELAY_BETWEEN_BATCHES = 1.0

def create_hourly_tables():
    """Ensures hourly table exists."""
    SystemBase.metadata.create_all(bind=SystemEngine)

def fetch_hourly_data_batch(cities_batch: list, past_days: int = 7) -> list:
    """Fetches hourly data for a batch of cities."""
    if not cities_batch:
        return []
    
    lats = [city["lat"] for city in cities_batch]
    lons = [city["lon"] for city in cities_batch]
    
    client = setup_client(cache_name='.cache_hourly')
    
    params = {
        "latitude": lats,
        "longitude": lons,
        "hourly": HOURLY_PARAMS,
        "past_days": past_days,
        "forecast_days": 1,
        "timezone": "Europe/Istanbul"
    }
    
    return client.weather_api(FORECAST_API_URL, params=params)

def process_response(response, city: dict) -> List[HourlyWeatherData]:
    """Processes API response into DB objects."""
    hourly = response.Hourly()
    
    times = pd.date_range(
        start=pd.to_datetime(hourly.Time(), unit="s", utc=True),
        end=pd.to_datetime(hourly.TimeEnd(), unit="s", utc=True),
        freq=pd.Timedelta(seconds=hourly.Interval()),
        inclusive="left"
    )
    
    # Process variables dynamically if possible, or mapping
    # Note: Variable indices must match HOURLY_PARAMS order
    data = {}
    data["timestamp"] = times
    for idx, param in enumerate(HOURLY_PARAMS):
        data[param] = hourly.Variables(idx).ValuesAsNumpy()
        
    df = pd.DataFrame(data)
    
    records = []
    for _, row in df.iterrows():
        record = HourlyWeatherData(
            city_name=city["name"],
            district_name=city.get("district"),
            latitude=city["lat"],
            longitude=city["lon"],
            timestamp=row["timestamp"].to_pydatetime(),
            temperature_2m=float(row["temperature_2m"]) if pd.notna(row["temperature_2m"]) else None,
            apparent_temperature=float(row["apparent_temperature"]) if pd.notna(row["apparent_temperature"]) else None,
            relative_humidity_2m=float(row["relative_humidity_2m"]) if pd.notna(row["relative_humidity_2m"]) else None,
            precipitation=float(row["precipitation"]) if pd.notna(row["precipitation"]) else None,
            cloud_cover=float(row["cloud_cover"]) if pd.notna(row["cloud_cover"]) else None,
            wind_speed_10m=float(row["wind_speed_10m"]) if pd.notna(row["wind_speed_10m"]) else None,
            wind_speed_100m=float(row["wind_speed_100m"]) if pd.notna(row["wind_speed_100m"]) else None,
            wind_direction_10m=float(row["wind_direction_10m"]) if pd.notna(row["wind_direction_10m"]) else None,
            wind_gusts_10m=float(row["wind_gusts_10m"]) if pd.notna(row["wind_gusts_10m"]) else None,
            shortwave_radiation=float(row["shortwave_radiation"]) if pd.notna(row["shortwave_radiation"]) else None,
            direct_radiation=float(row["direct_radiation"]) if pd.notna(row["direct_radiation"]) else None,
            diffuse_radiation=float(row["diffuse_radiation"]) if pd.notna(row["diffuse_radiation"]) else None,
        )
        records.append(record)
    
    return records

def collect_hourly_data(past_days: int = 7, force_refresh: bool = False):
    """Collects hourly data for all cities, skipping those that are up-to-date."""
    create_hourly_tables()
    db = SystemSessionLocal()
    
    try:
        if force_refresh:
            deleted = db.query(HourlyWeatherData).delete()
            db.commit()
            logger.info(f"Force refresh: {deleted} records deleted")
            
        # 1. Hangi şehirlerin güncel olduğunu belirle
        total_cities_count = len(TURKEY_CITIES)
        cities_to_fetch = []
        
        # Şu anki zaman (Sistem yerel saati, veriler de yerel kaydediliyor)
        now = datetime.now()
        # Hedef: En azından şu anki saatin verisi olsun
        target_timestamp = now.replace(minute=0, second=0, microsecond=0)
        
        if not force_refresh:
            logger.info("Checking for existing data to minimize API calls...")
            
            # Her şehir için son timestamp'i kontrol et
            # (Performance note: Tek tek query yerine group by query daha iyi olurdu ama şehir sayısı az - 81)
            for city in TURKEY_CITIES:
                last_record = db.query(func.max(HourlyWeatherData.timestamp))\
                    .filter(HourlyWeatherData.city_name == city["name"])\
                    .scalar()
                
                # Eğer son kayıt şu andan ilerideyse veya şu anı kapsıyorsa atla
                if last_record and last_record >= target_timestamp:
                    continue
                
                cities_to_fetch.append(city)
        else:
            cities_to_fetch = TURKEY_CITIES

        if not cities_to_fetch:
            logger.info("✅ All cities are up-to-date. No API calls needed.")
            return

        logger.info(f"Downloading data for {len(cities_to_fetch)}/{total_cities_count} cities...")

        # 2. Sadece eksik olanları çek
        total_records = 0
        
        for i in range(0, len(cities_to_fetch), BATCH_SIZE):
            batch = cities_to_fetch[i:i+BATCH_SIZE]
            batch_num = i // BATCH_SIZE + 1
            total_batches = (len(cities_to_fetch) + BATCH_SIZE - 1) // BATCH_SIZE
            
            logger.info(f"Batch {batch_num}/{total_batches}: {', '.join([c['name'] for c in batch])}")
            
            try:
                responses = fetch_hourly_data_batch(batch, past_days)
                
                for response, city in zip(responses, batch):
                    records = process_response(response, city)
                    
                    for record in records:
                        # Check existance (Bu kısım hala gerekli çünkü fetch_hourly_data_batch geçmişi de getiriyor)
                        # Optimization: Sadece yeni kayıtları eklemeye odaklanabiliriz ama update daha güvenli
                        query = db.query(HourlyWeatherData).filter(
                            HourlyWeatherData.city_name == record.city_name,
                            HourlyWeatherData.timestamp == record.timestamp
                        )
                        if record.district_name:
                            query = query.filter(HourlyWeatherData.district_name == record.district_name)
                        else:
                            query = query.filter(HourlyWeatherData.district_name.is_(None))
                            
                        existing = query.first()
                        
                        if existing:
                            # Update fields
                            for key, value in vars(record).items():
                                if not key.startswith('_'):
                                    setattr(existing, key, value)
                        else:
                            db.add(record)
                            total_records += 1
                    
                    db.commit()
                    logger.info(f"  ✓ {city['name']}: {len(records)} hours fetched")
                
                if i + BATCH_SIZE < len(cities_to_fetch):
                    time.sleep(DELAY_BETWEEN_BATCHES)
                    
            except Exception as e:
                logger.error(f"Batch error: {e}")
                db.rollback()
                if "rate" in str(e).lower():
                    time.sleep(60)
                continue
                
        logger.info(f"✅ Update complete. {total_records} new hourly records added.")
        
    finally:
        db.close()

def update_hourly_data():
    """Updates hourly data (last 2 days)."""
    logger.info("🔄 Updating hourly data (last 2 days)...")
    collect_hourly_data(past_days=2, force_refresh=False)
    logger.info("✅ Hourly update complete")

async def async_update_hourly_data():
    """Async wrapper for startup task."""
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, update_hourly_data)

def get_city_hourly_data(city_name: str, hours: int = 168) -> list:
    """Retrieves hourly data for a city."""
    db = SystemSessionLocal()
    try:
        cutoff = datetime.now() - timedelta(hours=hours)
        data = db.query(HourlyWeatherData)\
            .filter(HourlyWeatherData.city_name == city_name)\
            .filter(HourlyWeatherData.timestamp >= cutoff)\
            .order_by(HourlyWeatherData.timestamp.desc())\
            .all()
        return data
    finally:
        db.close()

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--full":
        logging.basicConfig(level=logging.INFO)
        collect_hourly_data(past_days=7, force_refresh=True)
    else:
        logging.basicConfig(level=logging.INFO)
        update_hourly_data()

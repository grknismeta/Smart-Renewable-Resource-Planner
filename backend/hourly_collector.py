"""
Şehir Bazlı Saatlik Hava Durumu Veri Toplayıcı
==============================================

81 il için son 7 günlük saatlik veri çeker.
Open-Meteo Forecast API kullanır (Archive API'dan farklı limit havuzu).
"""

import openmeteo_requests
import requests_cache
from retry_requests import retry
from datetime import datetime, timedelta
import pandas as pd
from sqlalchemy.orm import Session
from sqlalchemy import func
import logging
from typing import Optional
import time

# Logging ayarları
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Cache ve retry ayarları
cache_session = requests_cache.CachedSession('.cache_hourly', expire_after=3600)  # 1 saat cache
retry_session = retry(cache_session, retries=5, backoff_factor=0.2)
openmeteo = openmeteo_requests.Client(session=retry_session)# type: ignore

# API endpoint
FORECAST_API_URL = "https://api.open-meteo.com/v1/forecast"

# Saatlik veri parametreleri
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

# Batch ayarları
BATCH_SIZE = 10  # Her istekte kaç şehir
DELAY_BETWEEN_BATCHES = 1.0  # İstekler arası bekleme (saniye)


def _get_imports():
    """Lazy import for module compatibility"""
    from .database import SystemEngine, SystemSessionLocal
    from .models import HourlyWeatherData, SystemBase
    from .turkey_cities import TURKEY_CITIES
    return SystemEngine, SystemSessionLocal, HourlyWeatherData, SystemBase, TURKEY_CITIES


def create_hourly_tables():
    """Saatlik veri tablosunu oluştur"""
    system_engine, SystemSessionLocal, HourlyWeatherData, SystemBase, TURKEY_CITIES = _get_imports()
    SystemBase.metadata.create_all(bind=system_engine)
    logger.info("HourlyWeatherData tablosu oluşturuldu/kontrol edildi")


def get_last_timestamp_for_city(db: Session, city_name: str) -> Optional[datetime]:
    """Şehir için veritabanındaki son zaman damgasını getir"""
    system_engine, SystemSessionLocal, HourlyWeatherData, SystemBase, TURKEY_CITIES = _get_imports()
    result = db.query(func.max(HourlyWeatherData.timestamp))\
        .filter(HourlyWeatherData.city_name == city_name)\
        .scalar()
    return result


def fetch_hourly_data_batch(cities_batch: list, past_days: int = 7) -> list:
    """
    Bir grup şehir için saatlik veri çek
    
    Args:
        cities_batch: Şehir listesi (name, lat, lon)
        past_days: Kaç gün geriye gidilecek
        
    Returns:
        API responses listesi
    """
    if not cities_batch:
        return []
    
    lats = [city["lat"] for city in cities_batch]
    lons = [city["lon"] for city in cities_batch]
    
    params = {
        "latitude": lats,
        "longitude": lons,
        "hourly": HOURLY_PARAMS,
        "past_days": past_days,
        "forecast_days": 1,  # Bugün + yarın için tahmin
        "timezone": "Europe/Istanbul"
    }
    
    try:
        responses = openmeteo.weather_api(FORECAST_API_URL, params=params)
        return responses
    except Exception as e:
        logger.error(f"API hatası: {e}")
        raise


def process_response(response, city: dict) -> list:
    """
    API yanıtını işle ve veritabanı kayıtlarına dönüştür
    """
    system_engine, SystemSessionLocal, HourlyWeatherData, SystemBase, TURKEY_CITIES = _get_imports()
    
    hourly = response.Hourly()
    
    # Zaman serisi
    times = pd.date_range(
        start=pd.to_datetime(hourly.Time(), unit="s", utc=True),
        end=pd.to_datetime(hourly.TimeEnd(), unit="s", utc=True),
        freq=pd.Timedelta(seconds=hourly.Interval()),
        inclusive="left"
    )
    
    # DataFrame oluştur
    data = {
        "timestamp": times,
        "temperature_2m": hourly.Variables(0).ValuesAsNumpy(),
        "apparent_temperature": hourly.Variables(1).ValuesAsNumpy(),
        "relative_humidity_2m": hourly.Variables(2).ValuesAsNumpy(),
        "precipitation": hourly.Variables(3).ValuesAsNumpy(),
        "cloud_cover": hourly.Variables(4).ValuesAsNumpy(),
        "wind_speed_10m": hourly.Variables(5).ValuesAsNumpy(),
        "wind_speed_100m": hourly.Variables(6).ValuesAsNumpy(),
        "wind_direction_10m": hourly.Variables(7).ValuesAsNumpy(),
        "wind_gusts_10m": hourly.Variables(8).ValuesAsNumpy(),
        "shortwave_radiation": hourly.Variables(9).ValuesAsNumpy(),
        "direct_radiation": hourly.Variables(10).ValuesAsNumpy(),
        "diffuse_radiation": hourly.Variables(11).ValuesAsNumpy(),
    }
    
    df = pd.DataFrame(data)
    
    # Kayıt listesi oluştur
    records = []
    for _, row in df.iterrows():
        record = HourlyWeatherData(
            city_name=city["name"],
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


def collect_all_cities_hourly(past_days: int = 7, force_refresh: bool = False):
    """
    Tüm şehirler için saatlik veri topla
    
    Args:
        past_days: Kaç gün geriye gidilecek
        force_refresh: True ise mevcut verileri sil ve yeniden çek
    """
    system_engine, SystemSessionLocal, HourlyWeatherData, SystemBase, TURKEY_CITIES = _get_imports()
    
    create_hourly_tables()
    
    db = SystemSessionLocal()
    
    try:
        if force_refresh:
            # Mevcut verileri temizle
            deleted = db.query(HourlyWeatherData).delete()
            db.commit()
            logger.info(f"Force refresh: {deleted} kayıt silindi")
        
        total_cities = len(TURKEY_CITIES)
        total_records = 0
        
        # Şehirleri batch'lere böl
        for i in range(0, total_cities, BATCH_SIZE):
            batch = TURKEY_CITIES[i:i+BATCH_SIZE]
            batch_num = i // BATCH_SIZE + 1
            total_batches = (total_cities + BATCH_SIZE - 1) // BATCH_SIZE
            
            logger.info(f"Batch {batch_num}/{total_batches}: {', '.join([c['name'] for c in batch])}")
            
            try:
                responses = fetch_hourly_data_batch(batch, past_days)
                
                for idx, (response, city) in enumerate(zip(responses, batch)):
                    records = process_response(response, city)
                    
                    # Mevcut verileri kontrol et ve güncelle
                    for record in records:
                        # Aynı şehir ve zaman için kayıt var mı?
                        existing = db.query(HourlyWeatherData).filter(
                            HourlyWeatherData.city_name == record.city_name,
                            HourlyWeatherData.timestamp == record.timestamp
                        ).first()
                        
                        if existing:
                            # Güncelle
                            for key, value in vars(record).items():
                                if not key.startswith('_'):
                                    setattr(existing, key, value)
                        else:
                            # Yeni kayıt ekle
                            db.add(record)
                            total_records += 1
                    
                    db.commit()
                    logger.info(f"  ✓ {city['name']}: {len(records)} saat verisi")
                
                # Batch'ler arası bekleme
                if i + BATCH_SIZE < total_cities:
                    time.sleep(DELAY_BETWEEN_BATCHES)
                    
            except Exception as e:
                logger.error(f"Batch hatası: {e}")
                db.rollback()
                # Rate limit ise bekle
                if "429" in str(e) or "rate" in str(e).lower():
                    logger.warning("Rate limit! 60 saniye bekleniyor...")
                    time.sleep(60)
                continue
        
        logger.info(f"✅ Toplam {total_records} yeni saatlik kayıt eklendi")
        
    except Exception as e:
        logger.error(f"Genel hata: {e}")
        db.rollback()
    finally:
        db.close()


def update_hourly_data():
    """
    Saatlik verileri güncelle - sadece eksik saatleri çek
    Son 24 saati yenile, eski verileri koru
    """
    system_engine, SystemSessionLocal, HourlyWeatherData, SystemBase, TURKEY_CITIES = _get_imports()
    
    create_hourly_tables()
    
    db = SystemSessionLocal()
    
    try:
        # Son 2 günlük veriyi çek (güncel tahminler için)
        logger.info("🔄 Saatlik veriler güncelleniyor (son 2 gün)...")
        collect_all_cities_hourly(past_days=2, force_refresh=False)
        logger.info("✅ Saatlik güncelleme tamamlandı")
        
    except Exception as e:
        logger.error(f"Güncelleme hatası: {e}")
    finally:
        db.close()


async def async_update_hourly():
    """Asenkron wrapper - startup'ta çalışır"""
    import asyncio
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, update_hourly_data)


def get_city_hourly_data(city_name: str, hours: int = 168) -> list:
    """
    Bir şehrin son X saatlik verisini getir
    
    Args:
        city_name: Şehir adı
        hours: Kaç saat (varsayılan 7 gün = 168 saat)
    """
    system_engine, SystemSessionLocal, HourlyWeatherData, SystemBase, TURKEY_CITIES = _get_imports()
    
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
    # Standalone çalıştırma için import'ları değiştir
    import sys
    sys.path.insert(0, '.')
    
    # Direct imports for standalone
    from database import SystemEngine, SystemSessionLocal
    from models import HourlyWeatherData, SystemBase
    from turkey_cities import TURKEY_CITIES
    
    def _get_imports():
        return SystemEngine, SystemSessionLocal, HourlyWeatherData, SystemBase, TURKEY_CITIES
    
    if len(sys.argv) > 1 and sys.argv[1] == "--full":
        # Tam 7 günlük veri çek
        logger.info("🚀 Tam saatlik veri toplama başlıyor (7 gün)...")
        collect_all_cities_hourly(past_days=7, force_refresh=True)
    else:
        # Güncelleme modu
        logger.info("🔄 Saatlik veri güncelleme başlıyor...")
        update_hourly_data()
    
    logger.info("✅ İşlem tamamlandı!")

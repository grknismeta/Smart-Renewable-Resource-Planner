import pandas as pd
from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone, date
from collections import defaultdict
from typing import List
import time
import asyncio
import logging

from app.db.database import SystemSessionLocal, SystemEngine, SystemBase
from app.db.models import HourlyWeatherData
from app.core.constants import TURKEY_CITIES

from .base import setup_client, FORECAST_API_URL, HISTORICAL_FORECAST_API_URL, logger

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

BATCH_SIZE = 50
DELAY_BETWEEN_BATCHES = 3.0   # saniye — rate limit aşmamak için
FORECAST_MAX_PAST_DAYS = 92   # Open-Meteo Forecast API geçmiş veri limiti (gün)


def create_hourly_tables():
    """Ensures hourly table exists."""
    SystemBase.metadata.create_all(bind=SystemEngine)


def process_response(response, city: dict) -> List[HourlyWeatherData]:
    """Processes API response into DB objects."""
    hourly = response.Hourly()

    times = pd.date_range(
        start=pd.to_datetime(hourly.Time(), unit="s", utc=True),
        end=pd.to_datetime(hourly.TimeEnd(), unit="s", utc=True),
        freq=pd.Timedelta(seconds=hourly.Interval()),
        inclusive="left"
    )

    data = {"timestamp": times}
    for idx, param in enumerate(HOURLY_PARAMS):
        data[param] = hourly.Variables(idx).ValuesAsNumpy()

    df = pd.DataFrame(data)

    records = []
    for _, row in df.iterrows():
        # Naive UTC — DB'deki TIMESTAMP WITHOUT TIME ZONE ile tutarlı
        ts = row["timestamp"].to_pydatetime()
        if ts.tzinfo is not None:
            ts = ts.astimezone(timezone.utc).replace(tzinfo=None)

        # İlçe kayıtları için city_name = province adı kullan
        # → district-summary sorgusu city_name == province ile çalışır
        _district = city.get("district")
        _city_name = city.get("province", city["name"]) if _district else city["name"]
        record = HourlyWeatherData(
            city_name=_city_name,
            district_name=_district,
            location_code=city.get("code"),
            latitude=city["lat"],
            longitude=city["lon"],
            timestamp=ts,
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


def _is_rate_limit(e: Exception) -> bool:
    s = str(e).lower()
    return "rate" in s or "minutely" in s or "limit exceeded" in s


def _save_responses(db, responses, batch):
    """Batch API yanıtlarını DB'ye kaydeder (ON CONFLICT DO NOTHING)."""
    total = 0
    cols = [c.name for c in HourlyWeatherData.__table__.columns if c.name != 'id']
    for response, city in zip(responses, batch):
        records = process_response(response, city)
        if not records:
            continue
        record_dicts = [{col: getattr(r, col) for col in cols} for r in records]
        stmt = pg_insert(HourlyWeatherData).values(record_dicts)
        stmt = stmt.on_conflict_do_nothing(
            index_elements=['latitude', 'longitude', 'timestamp']
        )
        db.execute(stmt)
        db.commit()
        total += len(records)
    return total


def _fetch_batch_with_retry(client, db, batch: list, api_url: str, params_extra: dict,
                             batch_label: str = "") -> int:
    """
    Tek batch için API isteği yapar, rate limit'te 65s bekleyip yeniden dener.
    Başarıda kaydedilen kayıt sayısını döndürür.
    """
    lats = [c["lat"] for c in batch]
    lons = [c["lon"] for c in batch]
    params = {
        "latitude": lats,
        "longitude": lons,
        "hourly": HOURLY_PARAMS,
        "timezone": "Europe/Istanbul",
        **params_extra,
    }

    max_retries = 3
    for attempt in range(max_retries):
        try:
            responses = client.weather_api(api_url, params=params)
            saved = _save_responses(db, responses, batch)
            logger.info(f"  ✓ {batch_label}: {saved} saat kaydedildi")
            return saved
        except Exception as e:
            if _is_rate_limit(e):
                wait = 65 + attempt * 15
                logger.warning(
                    f"  Rate limit — {wait}s bekleniyor "
                    f"(deneme {attempt + 1}/{max_retries}) [{batch_label}]"
                )
                db.rollback()
                time.sleep(wait)
            else:
                logger.error(f"  Batch hatası (deneme {attempt + 1}): {e} [{batch_label}]")
                db.rollback()
                if attempt < max_retries - 1:
                    time.sleep(5)
                else:
                    logger.error(f"  Batch atlandı: {batch_label}")
                    return 0
    return 0


def collect_hourly_data(force_refresh: bool = False):
    """
    Tüm şehirler için son timestamp'ten şu ana kadar olan saatlik veriyi doldurur.

    Mantık:
    - Her şehrin son kaydını kontrol et (koordinat bazlı)
    - Boşluk > 92 gün → Historical Forecast API (start_date/end_date)
    - Boşluk ≤ 92 gün → Forecast API (past_days)
    - Boşluk yok → atla
    """
    create_hourly_tables()
    db = SystemSessionLocal()
    client = setup_client(cache_name='.cache_hourly')

    try:
        if force_refresh:
            deleted = db.query(HourlyWeatherData).delete()
            db.commit()
            logger.info(f"Force refresh: {deleted} kayıt silindi")

        # Şu anki saat (naive UTC)
        now_utc = datetime.utcnow().replace(minute=0, second=0, microsecond=0)
        today = now_utc.date()
        yesterday = today - timedelta(days=1)
        forecast_cutoff_date = today - timedelta(days=FORECAST_MAX_PAST_DAYS)

        # Her şehrin son timestamp'ini tek sorguda çek (performans)
        # GROUP BY lat/lon → max(timestamp)
        from sqlalchemy import select, literal_column
        last_ts_rows = db.execute(
            select(
                HourlyWeatherData.latitude,
                HourlyWeatherData.longitude,
                func.max(HourlyWeatherData.timestamp).label("last_ts")
            ).group_by(HourlyWeatherData.latitude, HourlyWeatherData.longitude)
        ).fetchall()
        last_ts_map = {(row.latitude, row.longitude): row.last_ts for row in last_ts_rows}

        # Şehirleri gruplara ayır
        deep_gap_cities: List[tuple] = []   # (city, last_date) — boşluk > 92 gün
        recent_gap_cities: List[tuple] = [] # (city, last_date) — boşluk ≤ 92 gün

        for city in TURKEY_CITIES:
            key = (city["lat"], city["lon"])
            last_record = last_ts_map.get(key) if not force_refresh else None

            if last_record and last_record >= now_utc:
                continue  # Güncel, atla

            last_date = last_record.date() if last_record else date(2022, 1, 1)

            if last_date < forecast_cutoff_date:
                deep_gap_cities.append((city, last_date))
            else:
                recent_gap_cities.append((city, last_date))

        total_cities = len(deep_gap_cities) + len(recent_gap_cities)
        if total_cities == 0:
            logger.info("✅ Tüm şehirler güncel. API çağrısı gerekmiyor.")
            return

        logger.info(
            f"Güncelleme gerekiyor: {total_cities} şehir "
            f"(derin boşluk: {len(deep_gap_cities)}, yakın boşluk: {len(recent_gap_cities)})"
        )

        total_saved = 0

        # ── Pass 1: Derin boşluk → Historical Forecast API ───────────────────
        if deep_gap_cities:
            min_start = min(d for _, d in deep_gap_cities) + timedelta(days=1)
            hist_end = yesterday  # Historical Forecast API = dünü destekliyor

            if min_start <= hist_end:
                cities_deep = [c for c, _ in deep_gap_cities]
                total_batches = (len(cities_deep) + BATCH_SIZE - 1) // BATCH_SIZE
                logger.info(
                    f"[Pass 1] Derin backfill: {min_start} → {hist_end} "
                    f"({len(cities_deep)} şehir, {total_batches} batch)"
                )
                for i in range(0, len(cities_deep), BATCH_SIZE):
                    batch = cities_deep[i:i + BATCH_SIZE]
                    batch_num = i // BATCH_SIZE + 1
                    label = f"Pass1 batch {batch_num}/{total_batches}"
                    saved = _fetch_batch_with_retry(
                        client, db, batch,
                        HISTORICAL_FORECAST_API_URL,
                        {"start_date": min_start.isoformat(), "end_date": hist_end.isoformat()},
                        label
                    )
                    total_saved += saved
                    if i + BATCH_SIZE < len(cities_deep):
                        time.sleep(DELAY_BETWEEN_BATCHES)

            # Derin boşluk şehirlerini yakın geçmiş için de listeye ekle
            for city, _ in deep_gap_cities:
                recent_gap_cities.append((city, forecast_cutoff_date))

        # ── Pass 2: Yakın boşluk → Forecast API (per-bucket) ────────────────
        # Her şehir için gerçek boşluk günü hesaplanır; şehirler aynı
        # past_days değerine ihtiyaç duyanlar birlikte API'ye gönderilir.
        # Böylece güncel şehirler gereksiz yere eski veri çekmez.
        if recent_gap_cities:
            # Boşluğa göre bucket'lara grupla: past_days → [city, ...]
            bucket_map: dict = defaultdict(list)
            for city, last_date in recent_gap_cities:
                gap_days = (today - last_date).days
                # En yakın üst eşiğe yuvarlama: 1, 7, 30, 92
                for threshold in (1, 7, 30, FORECAST_MAX_PAST_DAYS):
                    if gap_days <= threshold:
                        bucket_map[threshold].append(city)
                        break
                else:
                    bucket_map[FORECAST_MAX_PAST_DAYS].append(city)

            for past_days_bucket, bucket_cities in sorted(bucket_map.items()):
                total_batches = (len(bucket_cities) + BATCH_SIZE - 1) // BATCH_SIZE
                logger.info(
                    f"[Pass 2] past_days={past_days_bucket}: "
                    f"{len(bucket_cities)} şehir, {total_batches} batch"
                )
                for i in range(0, len(bucket_cities), BATCH_SIZE):
                    batch = bucket_cities[i:i + BATCH_SIZE]
                    batch_num = i // BATCH_SIZE + 1
                    label = f"Pass2 pd={past_days_bucket} batch {batch_num}/{total_batches}"
                    saved = _fetch_batch_with_retry(
                        client, db, batch,
                        FORECAST_API_URL,
                        {"past_days": past_days_bucket, "forecast_days": 1},
                        label
                    )
                    total_saved += saved
                    if i + BATCH_SIZE < len(bucket_cities):
                        time.sleep(DELAY_BETWEEN_BATCHES)

        logger.info(f"✅ Saatlik güncelleme tamamlandı. Toplam {total_saved} kayıt eklendi.")

    finally:
        db.close()


def update_hourly_data():
    """Son saate kadar olan tüm boşlukları doldurur."""
    logger.info("🔄 Saatlik veriler güncelleniyor...")
    collect_hourly_data(force_refresh=False)
    logger.info("✅ Saatlik güncelleme tamamlandı")


async def async_update_hourly_data():
    """Async wrapper for startup task."""
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, update_hourly_data)


def get_city_hourly_data(city_name: str, hours: int = 168) -> list:
    """Retrieves hourly data for a city."""
    db = SystemSessionLocal()
    try:
        cutoff = datetime.utcnow() - timedelta(hours=hours)
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
        collect_hourly_data(force_refresh=True)
    else:
        logging.basicConfig(level=logging.INFO)
        update_hourly_data()

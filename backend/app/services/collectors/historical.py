import pandas as pd
from sqlalchemy import select, func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session
from datetime import date, datetime, timedelta
from typing import List, Tuple
import time
import asyncio
import numpy as np

from app.db.database import SystemSessionLocal, SystemEngine, SystemBase
from app.db.models import WeatherData

from .base import setup_client, ARCHIVE_API_URL, FORECAST_API_URL, HISTORICAL_FORECAST_API_URL, logger

# Constants
LAT_MIN, LAT_MAX = 36.0, 42.0
LON_MIN, LON_MAX = 26.0, 45.0
GRID_STEP = 0.5
BATCH_SIZE = 50
YEARS_TO_FETCH = list(range(2015, 2025))
FETCH_2025 = True

# Daily updater — rolling window & deep backfill settings
ROLLING_DAYS = 100               # Her startup'ta son 100 gün idempotent olarak çekilir
DEEP_BACKFILL_START = date(2025, 1, 1)  # Bu tarihten rolling_start-1'e kadar boşluk kontrol edilir
COMPLETENESS_THRESHOLD = 0.90    # %90 dolu ise deep backfill atlanır

def generate_grid_points() -> List[Tuple[float, float]]:
    """Generates grid points over Turkey."""
    lats = np.arange(LAT_MIN, LAT_MAX, GRID_STEP)
    lons = np.arange(LON_MIN, LON_MAX, GRID_STEP)
    
    points = []
    for lat in lats:
        for lon in lons:
            points.append((round(float(lat), 2), round(float(lon), 2)))
    return points

def save_response_to_db(db: Session, response, lat, lon):
    """Parses Open-Meteo Binary response and saves to DB."""
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

    record_dicts = []
    for i in range(len(dates)):
        temp = float(daily_temp_mean[i]) if not pd.isna(daily_temp_mean[i]) else None
        if temp is None:
            continue
        record_dicts.append({
            'latitude': lat,
            'longitude': lon,
            'date': dates[i].date(),
            'temperature_mean': temp,
            'wind_speed_max': float(daily_wind_max[i]) if not pd.isna(daily_wind_max[i]) else 0.0,
            'wind_speed_mean': float(daily_wind_mean[i]) if not pd.isna(daily_wind_mean[i]) else 0.0,
            'wind_direction_dominant': float(daily_wind_dir[i]) if not pd.isna(daily_wind_dir[i]) else 0.0,
            'shortwave_radiation_sum': float(daily_rad_sum[i]) if not pd.isna(daily_rad_sum[i]) else 0.0,
            'province_name': None,
            'district_name': None,
        })

    return record_dicts

def save_batch_responses_to_db(db: Session, responses, batch_points):
    """Saves a batch of API responses to DB using ON CONFLICT DO NOTHING.

    This prevents UniqueViolation when grid points overlap with existing
    bulk-imported province/district coordinates.
    """
    all_dicts = []
    for idx, response in enumerate(responses):
        lat, lon = batch_points[idx]
        all_dicts.extend(save_response_to_db(db, response, lat, lon))

    if not all_dicts:
        return

    stmt = pg_insert(WeatherData).values(all_dicts)
    stmt = stmt.on_conflict_do_nothing(
        index_elements=['latitude', 'longitude', 'date']
    )
    db.execute(stmt)
    db.commit()

# --- BULK HISTORICAL FETCH (from data_collector.py) ---

def check_if_exists_for_year(db: Session, lat: float, lon: float, year: int) -> bool:
    """Checks if data exists for a given point and year."""
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

def fetch_year_data(openmeteo, db: Session, points: list, year: int, api_url: str):
    """Fetches data for all points for a specific year."""
    
    points_to_fetch = []
    for lat, lon in points:
        if not check_if_exists_for_year(db, lat, lon, year):
            points_to_fetch.append((lat, lon))
    
    if not points_to_fetch:
        print(f"   ✓ {year} already exists, skipping...")
        return
    
    print(f"   📥 {year}: Fetching {len(points_to_fetch)} points")
    
    current_batch_size = 20 if year == 2025 else BATCH_SIZE
    
    batches = [points_to_fetch[i:i + current_batch_size] for i in range(0, len(points_to_fetch), current_batch_size)]
    total_batches = len(batches)
    
    for batch_idx, batch_points in enumerate(batches):
        lats = [p[0] for p in batch_points]
        lons = [p[1] for p in batch_points]
        
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
        
        max_retries = 5
        for attempt in range(max_retries):
            try:
                responses = openmeteo.weather_api(api_url, params=params)
                save_batch_responses_to_db(db, responses, batch_points)
                
                print(f"      ✅ [{batch_idx+1}/{total_batches}] {len(batch_points)} points saved")
                time.sleep(5)
                break
                
            except Exception as e:
                error_str = str(e)
                if "rate limit" in error_str.lower() or "limit exceeded" in error_str.lower() or "minutely" in error_str.lower():
                    wait_time = 60 + (attempt * 30)
                    print(f"      ⏳ Rate limit! Waiting {wait_time}s... (Attempt {attempt+1}/{max_retries})")
                    time.sleep(wait_time)
                else:
                    print(f"      ❌ Error: {e}")
                    if attempt >= max_retries - 1:
                        print(f"      ⚠️ Batch skipped!")
                        break
                    time.sleep(15)

def fetch_historical_grid_data():
    """Main function to fetch 10-year historical data for the grid."""
    SystemBase.metadata.create_all(bind=SystemEngine)
    openmeteo = setup_client(cache_name='.cache_historical')
    points = generate_grid_points()
    db = SystemSessionLocal()
    
    print("=" * 50)
    print("🌍 HISTORICAL DATA COLLECTOR")
    print("=" * 50)
    
    try:
        for year in YEARS_TO_FETCH:
            print(f"\n📆 Processing {year}...")
            fetch_year_data(openmeteo, db, points, year, ARCHIVE_API_URL)
        
        if FETCH_2025:
            print(f"\n📆 Processing 2025 (Historical Forecast API)...")
            fetch_year_data(openmeteo, db, points, 2025, HISTORICAL_FORECAST_API_URL)
            
    finally:
        db.close()
    
    print("\n" + "=" * 50)
    print("🎉 Historical data collection complete!")
    print("=" * 50)


# --- DAILY UPDATE (from daily_updater.py) ---

def fetch_missing_days(start_date: date, end_date: date,
                        api_url: str | None = None) -> int:
    """Fetches missing days for all grid points.

    Args:
        start_date: First date to fetch (inclusive).
        end_date:   Last date to fetch (inclusive).
        api_url:    Open-Meteo endpoint to use.  Defaults to FORECAST_API_URL
                    for the last ~92 days; pass HISTORICAL_FORECAST_API_URL
                    for older dates (supported back to 2022-01-01).
    """
    if api_url is None:
        api_url = FORECAST_API_URL

    openmeteo = setup_client(cache_name='.cache_daily')
    points = generate_grid_points()
    db = SystemSessionLocal()

    days_fetched = 0

    try:
        update_batch_size = 50
        batches = [points[i:i + update_batch_size]
                   for i in range(0, len(points), update_batch_size)]

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
                responses = openmeteo.weather_api(api_url, params=params)
                save_batch_responses_to_db(db, responses, batch_points)

                if batch_idx == 0:
                    days_fetched = (end_date - start_date).days + 1

                print(f"[DailyUpdater] Batch {batch_idx + 1}/{len(batches)}: "
                      f"{len(batch_points)} points processed & saved.")
                time.sleep(1)

            except Exception as e:
                err_str = str(e).lower()
                is_rate = "rate" in err_str or "minutely" in err_str or "limit exceeded" in err_str
                wait = 65 if is_rate else 5
                print(f"[DailyUpdater] Batch {batch_idx + 1} error ({'rate limit' if is_rate else 'genel'}): {e} — {wait}s bekleniyor")
                time.sleep(wait)
                continue

    finally:
        db.close()

    return days_fetched

def _check_gap_completeness(db: Session, start: date, end: date) -> float:
    """[start, end] aralığındaki coverage oranını döndürür (0.0–1.0).

    İlk grid point üzerinden örnekleme yapar (hızlı).
    """
    first_point = generate_grid_points()[0]
    lat, lon = first_point
    expected_days = (end - start).days + 1
    actual = db.execute(
        select(func.count(WeatherData.id)).where(
            WeatherData.latitude == lat,
            WeatherData.longitude == lon,
            WeatherData.date >= start,
            WeatherData.date <= end,
        )
    ).scalar() or 0
    return actual / expected_days if expected_days > 0 else 1.0


def update_daily_grid_data() -> str:
    """
    Startup'ta çalışır. İki adım:
    1. Rolling window: Son ROLLING_DAYS günü idempotent olarak çek (her zaman)
    2. Deep backfill: DEEP_BACKFILL_START'tan rolling_start-1'e kadar boşluk varsa doldur
    """
    db = SystemSessionLocal()
    try:
        today = date.today()
        yesterday = today - timedelta(days=1)
        results = []

        # ── Adım 1: Rolling Window (son ROLLING_DAYS gün, her startup) ───────
        rolling_start = today - timedelta(days=ROLLING_DAYS)
        print(f"[DailyUpdater] Rolling window: {rolling_start} → {yesterday}")
        fetched = fetch_missing_days(rolling_start, yesterday,
                                     api_url=HISTORICAL_FORECAST_API_URL)
        results.append(f"Rolling {ROLLING_DAYS}d: {fetched} days refreshed")

        # ── Adım 2: Deep Backfill (DEEP_BACKFILL_START → rolling_start-1) ───
        deep_end = rolling_start - timedelta(days=1)
        if DEEP_BACKFILL_START <= deep_end:
            coverage = _check_gap_completeness(db, DEEP_BACKFILL_START, deep_end)
            if coverage < COMPLETENESS_THRESHOLD:
                print(
                    f"[DailyUpdater] Deep gap {DEEP_BACKFILL_START}→{deep_end} "
                    f"coverage={coverage:.1%} < {COMPLETENESS_THRESHOLD:.0%}, backfilling..."
                )
                fetched2 = fetch_missing_days(DEEP_BACKFILL_START, deep_end,
                                              api_url=HISTORICAL_FORECAST_API_URL)
                results.append(f"Deep backfill: {fetched2} days filled")
            else:
                results.append(
                    f"Deep gap {DEEP_BACKFILL_START}→{deep_end} already "
                    f"{coverage:.1%} complete, skipped"
                )

        return "[OK] " + " | ".join(results)

    except Exception as e:
        return f"[ERROR] {e}"
    finally:
        db.close()

async def async_update_daily_grid_data():
    """Async wrapper for startup task."""
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, update_daily_grid_data)
    try:
        print(f"[HistoricalCollector] {result}")
    except UnicodeEncodeError:
        print(f"[HistoricalCollector] {result.encode('ascii', errors='replace').decode('ascii')}")
    return result

if __name__ == "__main__":
    # If run directly, perform full historical fetch
    fetch_historical_grid_data()

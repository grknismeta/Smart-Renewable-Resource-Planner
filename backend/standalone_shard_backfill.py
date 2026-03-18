"""
standalone_shard_backfill.py
==============================
SRRP — Bagimsiz, SQLite tabanli veri cekme scripti.
4 cihazda bagimsiz calismak icin tasarlanmistir.

Her cihaz:
  - Kendi SQLite DB dosyasini olusturur ve doldurur
  - Belirlenen shard'daki konumlari isler
  - Kesintisiz devam destekler (resume)

Veri icerigi:
  - Gunluk: 2016-2024 (9 yil, 5 degisken)
  - Saatlik: 2025 + 2026 devam ediyor (4 degisken)

Gereksinimler:
  pip install openmeteo-requests requests-cache retry-requests pandas

Calistirma (her cihazda):
  python standalone_shard_backfill.py --shard 1/4
  python standalone_shard_backfill.py --shard 2/4  --db-path /tmp/shard2.db
  python standalone_shard_backfill.py --shard 3/4
  python standalone_shard_backfill.py --shard 4/4

Birden fazla cihaz bitmeden diger cihaz calistirilabilir.
Birlesim icin: python merge_shard_dbs.py
"""

import sys
import os
import json
import sqlite3
import time
import argparse
from pathlib import Path
from datetime import date, datetime

# Windows encoding sorunu
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

import pandas as pd
import requests_cache
import openmeteo_requests
from retry_requests import retry

# ─── Yapilandirma ─────────────────────────────────────────────────────────────

ARCHIVE_API  = "https://archive-api.open-meteo.com/v1/archive"

# 9 yillik gunluk veri
DAILY_YEARS  = list(range(2016, 2025))  # 2016-2024

# Saatlik devam eden veri (2026 her calistirmada guncellenir)
HOURLY_YEARS = [2025, 2026]

BATCH_DELAY  = 12    # Her API cagrisi sonrasi bekleme (saniye)
RATE_WAIT    = 90    # Rate limit bekleme (saniye)
MAX_RETRIES  = 5

DAILY_PARAMS = [
    "temperature_2m_mean",
    "wind_speed_10m_max",
    "wind_speed_10m_mean",
    "wind_direction_10m_dominant",
    "shortwave_radiation_sum",
]

HOURLY_PARAMS = [
    "temperature_2m",
    "wind_speed_10m",
    "wind_direction_10m",
    "shortwave_radiation",
]

# ─── Sehir listesi ────────────────────────────────────────────────────────────

def load_cities():
    """
    turkey_districts.json (generate_turkey_districts_overpass.py ciktisi) varsa oradan,
    yoksa app/core/constants.py'den yukle.
    """
    json_path = Path(__file__).parent / "turkey_districts.json"
    if json_path.exists():
        with open(json_path, "r", encoding="utf-8") as f:
            cities = json.load(f)
        print(f"Sehir listesi: turkey_districts.json — {len(cities)} konum")
        return cities

    try:
        sys.path.insert(0, str(Path(__file__).parent))
        from app.core.constants import TURKEY_CITIES
        print(f"Sehir listesi: app.core.constants — {len(TURKEY_CITIES)} konum")
        return TURKEY_CITIES
    except ImportError:
        print("HATA: Ne turkey_districts.json ne de app/core/constants.py bulundu!")
        print("  Once calistirin: python generate_turkey_districts_overpass.py")
        sys.exit(1)

# ─── Arguman ─────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="SRRP Standalone Shard Backfill")
    p.add_argument(
        "--shard", default="1/1",
        help="Shard: N/M  (orn: --shard 2/4)  Varsayilan: 1/1 (tumu)"
    )
    p.add_argument(
        "--db-path", default=None,
        help="SQLite dosya yolu. Girilmezse srrp_shard_N_M.db kullanilir."
    )
    p.add_argument(
        "--batch-delay", type=int, default=BATCH_DELAY,
        help=f"API cagrisi arasi bekleme (saniye). Varsayilan: {BATCH_DELAY}"
    )
    p.add_argument(
        "--mode", choices=["all", "daily", "hourly"], default="all",
        help="Cekme modu: all | daily | hourly  Varsayilan: all"
    )
    return p.parse_args()

# ─── SQLite ───────────────────────────────────────────────────────────────────

_DDL = """
CREATE TABLE IF NOT EXISTS weather_daily (
    latitude                 REAL NOT NULL,
    longitude                REAL NOT NULL,
    province_name            TEXT,
    district_name            TEXT,
    date                     TEXT NOT NULL,
    temperature_mean         REAL,
    wind_speed_max           REAL,
    wind_speed_mean          REAL,
    wind_direction_dominant  REAL,
    shortwave_radiation_sum  REAL,
    PRIMARY KEY (latitude, longitude, date)
);

CREATE TABLE IF NOT EXISTS weather_hourly (
    latitude              REAL NOT NULL,
    longitude             REAL NOT NULL,
    province_name         TEXT,
    district_name         TEXT,
    timestamp             TEXT NOT NULL,
    temperature           REAL,
    wind_speed            REAL,
    wind_direction        REAL,
    shortwave_radiation   REAL,
    PRIMARY KEY (latitude, longitude, timestamp)
);

CREATE TABLE IF NOT EXISTS progress (
    latitude   REAL NOT NULL,
    longitude  REAL NOT NULL,
    task       TEXT NOT NULL,
    status     TEXT NOT NULL,
    updated_at TEXT,
    PRIMARY KEY (latitude, longitude, task)
);
"""

def init_db(db_path):
    conn = sqlite3.connect(db_path, check_same_thread=False)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.executescript(_DDL)
    conn.commit()
    return conn


def is_done(conn, lat, lon, task):
    row = conn.execute(
        "SELECT status FROM progress WHERE latitude=? AND longitude=? AND task=?",
        (lat, lon, task),
    ).fetchone()
    return row is not None and row[0] == "done"


def mark_done(conn, lat, lon, task):
    conn.execute(
        "INSERT OR REPLACE INTO progress "
        "(latitude, longitude, task, status, updated_at) "
        "VALUES (?, ?, ?, 'done', datetime('now'))",
        (lat, lon, task),
    )
    conn.commit()


def insert_daily(conn, records):
    conn.executemany(
        "INSERT OR IGNORE INTO weather_daily "
        "(latitude, longitude, province_name, district_name, date, "
        " temperature_mean, wind_speed_max, wind_speed_mean, "
        " wind_direction_dominant, shortwave_radiation_sum) "
        "VALUES (?,?,?,?,?,?,?,?,?,?)",
        records,
    )
    conn.commit()


def insert_hourly(conn, records):
    conn.executemany(
        "INSERT OR IGNORE INTO weather_hourly "
        "(latitude, longitude, province_name, district_name, timestamp, "
        " temperature, wind_speed, wind_direction, shortwave_radiation) "
        "VALUES (?,?,?,?,?,?,?,?,?)",
        records,
    )
    conn.commit()

# ─── Open-Meteo istemcisi ─────────────────────────────────────────────────────

def make_client():
    cache   = requests_cache.CachedSession(".cache_standalone", expire_after=-1)
    session = retry(cache, retries=3, backoff_factor=0.5)
    return openmeteo_requests.Client(session=session)

# ─── API cagrisi ──────────────────────────────────────────────────────────────

def safe_api_call(client, url, params):
    """Rate-limit korumalı API cagrisi."""
    for attempt in range(MAX_RETRIES):
        try:
            return client.weather_api(url, params=params)[0]
        except Exception as e:
            err = str(e).lower()
            if any(x in err for x in ("rate", "limit", "429", "too many")):
                wait = RATE_WAIT + attempt * 30
                print(f"\n      [WAIT] Rate limit — {wait}s bekleniyor ({attempt+1}/{MAX_RETRIES})")
                time.sleep(wait)
            else:
                print(f"\n      [ERR] Deneme {attempt+1}: {e}")
                if attempt < MAX_RETRIES - 1:
                    time.sleep(15)
                else:
                    raise
    return None

# ─── Veri cekme ───────────────────────────────────────────────────────────────

def _safe_float(arr, i):
    v = arr[i]
    return float(v) if not pd.isna(v) else None


def fetch_daily(client, lat, lon, province, district, year):
    today = date.today()
    end   = f"{year}-12-31" if year < today.year else today.strftime("%Y-%m-%d")

    params = {
        "latitude":   lat,
        "longitude":  lon,
        "start_date": f"{year}-01-01",
        "end_date":   end,
        "daily":      DAILY_PARAMS,
        "timezone":   "Europe/Istanbul",
    }

    resp = safe_api_call(client, ARCHIVE_API, params)
    if resp is None:
        return []

    daily = resp.Daily()
    times = pd.date_range(
        start    = pd.to_datetime(daily.Time(),    unit="s", utc=True),
        end      = pd.to_datetime(daily.TimeEnd(), unit="s", utc=True),
        freq     = pd.Timedelta(seconds=daily.Interval()),
        inclusive= "left",
    )

    arrs = [daily.Variables(i).ValuesAsNumpy() for i in range(len(DAILY_PARAMS))]

    records = []
    for i, t in enumerate(times):
        if pd.isna(arrs[0][i]):
            continue
        records.append((
            lat, lon, province, district,
            t.date().isoformat(),
            _safe_float(arrs[0], i),  # temperature_mean
            _safe_float(arrs[1], i),  # wind_speed_max
            _safe_float(arrs[2], i),  # wind_speed_mean
            _safe_float(arrs[3], i),  # wind_direction_dominant
            _safe_float(arrs[4], i),  # shortwave_radiation_sum
        ))
    return records


def fetch_hourly(client, lat, lon, province, district, year):
    today = date.today()
    start = f"{year}-01-01"
    end   = f"{year}-12-31" if year < today.year else today.strftime("%Y-%m-%d")

    if start == end:
        return []

    params = {
        "latitude":   lat,
        "longitude":  lon,
        "start_date": start,
        "end_date":   end,
        "hourly":     HOURLY_PARAMS,
        "timezone":   "Europe/Istanbul",
    }

    resp = safe_api_call(client, ARCHIVE_API, params)
    if resp is None:
        return []

    hourly = resp.Hourly()
    times  = pd.date_range(
        start    = pd.to_datetime(hourly.Time(),    unit="s", utc=True),
        end      = pd.to_datetime(hourly.TimeEnd(), unit="s", utc=True),
        freq     = pd.Timedelta(seconds=hourly.Interval()),
        inclusive= "left",
    )

    arrs = [hourly.Variables(i).ValuesAsNumpy() for i in range(len(HOURLY_PARAMS))]

    records = []
    for i, t in enumerate(times):
        if pd.isna(arrs[0][i]):
            continue
        records.append((
            lat, lon, province, district,
            t.strftime("%Y-%m-%dT%H:%M"),
            _safe_float(arrs[0], i),  # temperature
            _safe_float(arrs[1], i),  # wind_speed
            _safe_float(arrs[2], i),  # wind_direction
            _safe_float(arrs[3], i),  # shortwave_radiation
        ))
    return records

# ─── Ana dongu ────────────────────────────────────────────────────────────────

def main():
    args = parse_args()

    # Shard ayristir
    try:
        shard_n, shard_m = [int(x) for x in args.shard.split("/")]
        assert 1 <= shard_n <= shard_m
    except Exception:
        print(f"HATA: --shard formati yanlis: '{args.shard}'  (orn: 2/4)")
        sys.exit(1)

    delay = args.batch_delay
    mode  = args.mode
    today = date.today()

    cities       = load_cities()
    shard_cities = [c for i, c in enumerate(cities) if (i % shard_m) == (shard_n - 1)]

    db_path = args.db_path or f"srrp_shard_{shard_n}_{shard_m}.db"
    conn    = init_db(db_path)
    client  = make_client()

    # Ozet
    total_tasks = (
        len(shard_cities) * (len(DAILY_YEARS) if mode in ("all", "daily") else 0)
        + len(shard_cities) * (len(HOURLY_YEARS) if mode in ("all", "hourly") else 0)
    )

    print("=" * 65)
    print(f"SRRP Standalone Backfill — Shard {shard_n}/{shard_m}")
    print(f"Konum: {len(shard_cities)} / {len(cities)}  |  Gorev: ~{total_tasks}")
    print(f"Mod: {mode}  |  DB: {db_path}")
    print(f"Gunluk: {DAILY_YEARS[0]}-{DAILY_YEARS[-1]}  |  Saatlik: {HOURLY_YEARS}")
    print("=" * 65)

    stats = {"daily": 0, "hourly": 0, "skipped": 0, "errors": 0}

    for idx, city in enumerate(shard_cities, 1):
        lat      = city["lat"]
        lon      = city["lon"]
        province = city.get("province", "")
        district = city.get("district") or city.get("province", "")
        name     = city["name"]

        print(f"\n[{idx:4}/{len(shard_cities)}] {name} ({province})")

        # ── Gunluk: 2016-2024 ────────────────────────────────────────
        if mode in ("all", "daily"):
            for year in DAILY_YEARS:
                task = f"daily_{year}"
                if is_done(conn, lat, lon, task):
                    stats["skipped"] += 1
                    continue

                print(f"  G{year}... ", end="", flush=True)
                try:
                    records = fetch_daily(client, lat, lon, province, district, year)
                    if records:
                        insert_daily(conn, records)
                        print(f"{len(records)} kayit")
                        stats["daily"] += len(records)
                    else:
                        print("0 kayit")
                    mark_done(conn, lat, lon, task)
                    time.sleep(delay)
                except Exception as e:
                    print(f"HATA: {e}")
                    stats["errors"] += 1
                    time.sleep(20)

        # ── Saatlik: 2025 + 2026 (devam) ─────────────────────────────
        if mode in ("all", "hourly"):
            for year in HOURLY_YEARS:
                task = f"hourly_{year}"
                # 2026 devam ediyor: her calistirmada guncelle (done isaretleme)
                is_ongoing = (year >= today.year)

                if not is_ongoing and is_done(conn, lat, lon, task):
                    stats["skipped"] += 1
                    continue

                print(f"  S{year}... ", end="", flush=True)
                try:
                    records = fetch_hourly(client, lat, lon, province, district, year)
                    if records:
                        insert_hourly(conn, records)
                        print(f"{len(records)} kayit")
                        stats["hourly"] += len(records)
                    else:
                        print("0 kayit")
                    if not is_ongoing:
                        mark_done(conn, lat, lon, task)
                    time.sleep(delay)
                except Exception as e:
                    print(f"HATA: {e}")
                    stats["errors"] += 1
                    time.sleep(20)

    # DB istatistikleri
    daily_count  = conn.execute("SELECT COUNT(*) FROM weather_daily").fetchone()[0]
    hourly_count = conn.execute("SELECT COUNT(*) FROM weather_hourly").fetchone()[0]
    conn.close()

    print("\n" + "=" * 65)
    print(f"TAMAMLANDI  —  Shard {shard_n}/{shard_m}  ({len(shard_cities)} konum)")
    print(f"  Bu seferki gunluk  : {stats['daily']:,}")
    print(f"  Bu seferki saatlik : {stats['hourly']:,}")
    print(f"  Atlanan            : {stats['skipped']:,}")
    print(f"  Hata               : {stats['errors']}")
    print(f"  DB gunluk toplam   : {daily_count:,}")
    print(f"  DB saatlik toplam  : {hourly_count:,}")
    print(f"  DB dosyasi         : {db_path}")
    print("=" * 65)


if __name__ == "__main__":
    main()

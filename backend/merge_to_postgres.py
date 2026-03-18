"""
merge_to_postgres.py
=====================
4 SQLite shard dosyasini okuyup dogrudan PostgreSQL'e yazar.

Calistirma (tum shardlar tamamlandiktan sonra, ana makinede):
  python merge_to_postgres.py srrp_shard_1_4.db srrp_shard_2_4.db srrp_shard_3_4.db srrp_shard_4_4.db

Varsayilan hedef DB:
  postgresql://srrp_admin:srrp_secure_2026@localhost:5432/srrp_db

Farkli bir sunucu icin:
  python merge_to_postgres.py *.db --pg-url "postgresql://user:pass@host:5432/db"

Hedef tablolar:
  weather_data         — Gunluk (2016-2024), 5 degisken
  hourly_weather_data  — Saatlik (2025-2026), 4 degisken

Guvence:
  ON CONFLICT DO NOTHING — Ayni kayit iki kez gelmez.
  Kismi import sonrasi tekrar calistirmak guvenlidir.
"""

import sys
import sqlite3
import argparse
import time
from pathlib import Path

# psycopg2 kontrolu
try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    import subprocess
    print("psycopg2 kuruluyor...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary", "-q"])
    import psycopg2
    import psycopg2.extras

DEFAULT_PG = "postgresql://srrp_admin:srrp_secure_2026@localhost:5432/srrp_db"
BATCH_SIZE = 5_000   # Her seferinde kac satir aktarilsin

# ─── PostgreSQL schema ────────────────────────────────────────────────────────
# weather_data tablosuna eksik kolonlar varsa ekle, unique constraint varsa koru

_PREPARE_SQL = """
-- Eksik kolonlari ekle (zaten varsa hata vermez)
ALTER TABLE weather_data
    ADD COLUMN IF NOT EXISTS province_name VARCHAR,
    ADD COLUMN IF NOT EXISTS district_name VARCHAR;

-- Unique constraint yoksa olustur (ON CONFLICT icin gerekli)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'weather_data_lat_lon_date_uniq'
    ) THEN
        ALTER TABLE weather_data
            ADD CONSTRAINT weather_data_lat_lon_date_uniq
            UNIQUE (latitude, longitude, date);
    END IF;
END$$;

-- hourly_weather_data tablosu yoksa olustur
CREATE TABLE IF NOT EXISTS hourly_weather_data (
    id                   SERIAL PRIMARY KEY,
    city_name            VARCHAR,
    district_name        VARCHAR,
    latitude             FLOAT,
    longitude            FLOAT,
    timestamp            TIMESTAMP,
    temperature_2m       FLOAT,
    apparent_temperature FLOAT,
    wind_speed_10m       FLOAT,
    wind_speed_100m      FLOAT,
    wind_direction_10m   FLOAT,
    wind_gusts_10m       FLOAT,
    shortwave_radiation  FLOAT,
    direct_radiation     FLOAT,
    diffuse_radiation    FLOAT,
    relative_humidity_2m FLOAT,
    cloud_cover          FLOAT,
    precipitation        FLOAT
);

-- Unique constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'hourly_weather_data_lat_lon_ts_uniq'
    ) THEN
        ALTER TABLE hourly_weather_data
            ADD CONSTRAINT hourly_weather_data_lat_lon_ts_uniq
            UNIQUE (latitude, longitude, timestamp);
    END IF;
END$$;

-- Indexler
CREATE INDEX IF NOT EXISTS idx_wd_province   ON weather_data        (province_name);
CREATE INDEX IF NOT EXISTS idx_wd_district   ON weather_data        (district_name);
CREATE INDEX IF NOT EXISTS idx_wd_date       ON weather_data        (date);
CREATE INDEX IF NOT EXISTS idx_hwd_city      ON hourly_weather_data (city_name);
CREATE INDEX IF NOT EXISTS idx_hwd_ts        ON hourly_weather_data (timestamp);
"""

_INSERT_DAILY = """
INSERT INTO weather_data
    (latitude, longitude, province_name, district_name, date,
     temperature_mean, wind_speed_max, wind_speed_mean,
     wind_direction_dominant, shortwave_radiation_sum)
VALUES %s
ON CONFLICT ON CONSTRAINT weather_data_lat_lon_date_uniq DO NOTHING
"""

_INSERT_HOURLY = """
INSERT INTO hourly_weather_data
    (latitude, longitude, city_name, district_name, timestamp,
     temperature_2m, wind_speed_10m, wind_direction_10m, shortwave_radiation)
VALUES %s
ON CONFLICT ON CONSTRAINT hourly_weather_data_lat_lon_ts_uniq DO NOTHING
"""

# ─── Yardimcilar ─────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="SRRP SQLite -> PostgreSQL Aktarici")
    p.add_argument("shards", nargs="+", help="SQLite shard dosyalari")
    p.add_argument(
        "--pg-url", default=DEFAULT_PG,
        help=f"PostgreSQL URL (varsayilan: {DEFAULT_PG})"
    )
    p.add_argument(
        "--batch-size", type=int, default=BATCH_SIZE,
        help=f"Tek seferlik satirsayisi (varsayilan: {BATCH_SIZE})"
    )
    return p.parse_args()


def pg_connect(url):
    print(f"  PostgreSQL baglaniyor: {url[:50]}...")
    conn = psycopg2.connect(url)
    conn.autocommit = False
    return conn


def prepare_pg(pg):
    """Eksik kolonlar, unique constraint ve indexleri olustur."""
    print("  Schema hazirlaniyor...")
    with pg.cursor() as cur:
        cur.execute(_PREPARE_SQL)
    pg.commit()
    print("  Schema hazir.")


def sqlite_row_count(sl_conn, table):
    try:
        return sl_conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    except Exception:
        return 0


def import_daily(sl_conn, pg, batch_size):
    """SQLite weather_daily -> PostgreSQL weather_data"""
    total = sqlite_row_count(sl_conn, "weather_daily")
    if total == 0:
        print("    Gunluk kayit yok, atlanip geciliyor.")
        return 0

    inserted = 0
    offset   = 0
    t0       = time.time()

    while True:
        rows = sl_conn.execute(
            "SELECT latitude, longitude, province_name, district_name, date, "
            "       temperature_mean, wind_speed_max, wind_speed_mean, "
            "       wind_direction_dominant, shortwave_radiation_sum "
            "FROM weather_daily "
            "ORDER BY rowid "
            f"LIMIT {batch_size} OFFSET {offset}"
        ).fetchall()

        if not rows:
            break

        with pg.cursor() as cur:
            psycopg2.extras.execute_values(cur, _INSERT_DAILY, rows)
        pg.commit()

        inserted += len(rows)
        offset   += len(rows)
        elapsed   = time.time() - t0
        rate      = inserted / elapsed if elapsed > 0 else 0
        print(
            f"    Gunluk  {inserted:>8,} / {total:,}  "
            f"({100*inserted//total}%)  {rate:,.0f} kayit/s",
            end="\r"
        )

    print()
    return inserted


def import_hourly(sl_conn, pg, batch_size):
    """SQLite weather_hourly -> PostgreSQL hourly_weather_data"""
    total = sqlite_row_count(sl_conn, "weather_hourly")
    if total == 0:
        print("    Saatlik kayit yok, atlanip geciliyor.")
        return 0

    inserted = 0
    offset   = 0
    t0       = time.time()

    while True:
        rows = sl_conn.execute(
            "SELECT latitude, longitude, province_name, district_name, timestamp, "
            "       temperature, wind_speed, wind_direction, shortwave_radiation "
            "FROM weather_hourly "
            "ORDER BY rowid "
            f"LIMIT {batch_size} OFFSET {offset}"
        ).fetchall()

        if not rows:
            break

        with pg.cursor() as cur:
            psycopg2.extras.execute_values(cur, _INSERT_HOURLY, rows)
        pg.commit()

        inserted += len(rows)
        offset   += len(rows)
        elapsed   = time.time() - t0
        rate      = inserted / elapsed if elapsed > 0 else 0
        print(
            f"    Saatlik {inserted:>8,} / {total:,}  "
            f"({100*inserted//total}%)  {rate:,.0f} kayit/s",
            end="\r"
        )

    print()
    return inserted


# ─── Ana fonksiyon ────────────────────────────────────────────────────────────

def main():
    args = parse_args()

    # Dosya kontrolu
    shard_paths = []
    for p in args.shards:
        if Path(p).exists():
            shard_paths.append(p)
        else:
            print(f"  [UYARI] Dosya bulunamadi: {p}")

    if not shard_paths:
        print("HATA: Hicbir shard dosyasi bulunamadi.")
        sys.exit(1)

    pg = pg_connect(args.pg_url)
    prepare_pg(pg)

    total_daily  = 0
    total_hourly = 0

    print("\n" + "=" * 65)

    for shard_path in shard_paths:
        size_mb = Path(shard_path).stat().st_size / 1_048_576
        print(f"\n[SHARD] {shard_path}  ({size_mb:.0f} MB)")

        sl = sqlite3.connect(shard_path)

        d = import_daily(sl, pg, args.batch_size)
        h = import_hourly(sl, pg, args.batch_size)

        sl.close()

        total_daily  += d
        total_hourly += h
        print(f"  Bu shard: Gunluk +{d:,}  Saatlik +{h:,}")

    # PG son istatistik
    with pg.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM weather_data")
        pg_daily = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM hourly_weather_data")
        pg_hourly = cur.fetchone()[0]
        cur.execute(
            "SELECT COUNT(DISTINCT province_name) FROM weather_data "
            "WHERE province_name IS NOT NULL"
        )
        province_count = cur.fetchone()[0]

    pg.close()

    print("\n" + "=" * 65)
    print("AKTARIM TAMAMLANDI")
    print(f"  Bu seferlik gunluk  : +{total_daily:,}")
    print(f"  Bu seferlik saatlik : +{total_hourly:,}")
    print(f"  PostgreSQL gunluk   :  {pg_daily:,}  (weather_data)")
    print(f"  PostgreSQL saatlik  :  {pg_hourly:,}  (hourly_weather_data)")
    print(f"  Il sayisi           :  {province_count}")
    print("=" * 65)


if __name__ == "__main__":
    main()

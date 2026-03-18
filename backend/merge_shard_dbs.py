"""
merge_shard_dbs.py
===================
4 bagimsiz SQLite shard dosyasini tek bir veritabaninda birlestir.

Calistirma (tum shardlar tamamlandiktan sonra):
  python merge_shard_dbs.py srrp_shard_1_4.db srrp_shard_2_4.db srrp_shard_3_4.db srrp_shard_4_4.db

Cikti: srrp_merged.db  (veya --output ile degistir)

Ayni konuma ait kayitlar cakismaz (INSERT OR IGNORE).
Shardlar herhangi bir sirada birlestirilabilir.
"""

import sqlite3
import sys
import time
from pathlib import Path

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
"""

_IDX = """
CREATE INDEX IF NOT EXISTS idx_daily_province  ON weather_daily  (province_name);
CREATE INDEX IF NOT EXISTS idx_daily_district  ON weather_daily  (district_name);
CREATE INDEX IF NOT EXISTS idx_daily_date      ON weather_daily  (date);
CREATE INDEX IF NOT EXISTS idx_hourly_province ON weather_hourly (province_name);
CREATE INDEX IF NOT EXISTS idx_hourly_ts       ON weather_hourly (timestamp);
"""


def merge(shard_paths, out_path="srrp_merged.db"):
    print("=" * 65)
    print("SRRP Shard Birlestirici")
    print(f"Hedef DB: {out_path}")
    print(f"Kaynaklar: {shard_paths}")
    print("=" * 65)

    out = sqlite3.connect(out_path)
    out.execute("PRAGMA journal_mode=WAL")
    out.execute("PRAGMA synchronous=NORMAL")
    out.execute("PRAGMA cache_size=-65536")  # 64 MB cache
    out.executescript(_DDL)
    out.commit()

    total_daily  = 0
    total_hourly = 0

    for shard_path in shard_paths:
        if not Path(shard_path).exists():
            print(f"\n  [ATLA] Dosya bulunamadi: {shard_path}")
            continue

        size_mb = Path(shard_path).stat().st_size / 1_048_576
        print(f"\n  Birlestiriliyor: {shard_path}  ({size_mb:.1f} MB)")
        t0 = time.time()

        out.execute(f"ATTACH DATABASE '{shard_path}' AS shard")

        # Daily
        cur = out.execute(
            "INSERT OR IGNORE INTO weather_daily "
            "SELECT * FROM shard.weather_daily"
        )
        d_added = cur.rowcount

        # Hourly
        cur = out.execute(
            "INSERT OR IGNORE INTO weather_hourly "
            "SELECT * FROM shard.weather_hourly"
        )
        h_added = cur.rowcount

        out.commit()
        out.execute("DETACH DATABASE shard")

        elapsed = time.time() - t0
        print(f"    Gunluk +{d_added:,}  Saatlik +{h_added:,}  ({elapsed:.1f}s)")
        total_daily  += d_added
        total_hourly += h_added

    # Index olustur
    print("\n  Indexler olusturuluyor...")
    out.executescript(_IDX)
    out.commit()

    # Son istatistikler
    daily_total  = out.execute("SELECT COUNT(*) FROM weather_daily").fetchone()[0]
    hourly_total = out.execute("SELECT COUNT(*) FROM weather_hourly").fetchone()[0]
    province_count = out.execute(
        "SELECT COUNT(DISTINCT province_name) FROM weather_daily"
    ).fetchone()[0]
    district_count = out.execute(
        "SELECT COUNT(DISTINCT district_name) FROM weather_daily"
    ).fetchone()[0]

    out.close()

    out_size = Path(out_path).stat().st_size / 1_048_576

    print("\n" + "=" * 65)
    print("BIRLESME TAMAMLANDI")
    print(f"  Bu seferlik  gunluk  : +{total_daily:,}")
    print(f"  Bu seferlik  saatlik : +{total_hourly:,}")
    print(f"  Toplam       gunluk  :  {daily_total:,}")
    print(f"  Toplam       saatlik :  {hourly_total:,}")
    print(f"  Il sayisi            :  {province_count}")
    print(f"  Ilce sayisi          :  {district_count}")
    print(f"  DB boyutu            :  {out_size:.1f} MB")
    print(f"  Dosya                :  {out_path}")
    print("=" * 65)


def parse_args():
    import argparse
    p = argparse.ArgumentParser(description="SRRP Shard DB Birlestirici")
    p.add_argument("shards", nargs="+", help="Birlestirilecek SQLite shard dosyalari")
    p.add_argument(
        "--output", default="srrp_merged.db",
        help="Cikti dosyasi (varsayilan: srrp_merged.db)"
    )
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    merge(args.shards, args.output)

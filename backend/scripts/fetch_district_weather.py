r"""İlçe-bazlı günlük hava verisi backfill — DAĞITIK (2026-06-03).

GADM ilçe adları + centroid'leriyle (districts.csv) Open-Meteo Historical
Archive'dan GÜNLÜK çeker, `weather_data` şemasına uygun CSV yazar. Çıktı CSV'ler
birleştirilip prod DB'ye COPY edilir → ml_forecast yeniden üretilir.

Neden: weather_data ilçe adları eski/eksik (Merkez, reform öncesi) + cloud/precip
yalnız 5 ilde. GADM adlarıyla (Efeler, Ortahisar...) yeniden çekince harita
siyah ilçeleri kapanır + isim uyumu sağlanır.

DAĞITIK KULLANIM (Colab + PC + PC — her makinede SADECE `requests` gerekir):
    # districts.csv'yi her makineye kopyala. Sonra:
    python fetch_district_weather.py --districts districts.csv --shard 0 --of 3 --out w0.csv
    python fetch_district_weather.py --districts districts.csv --shard 1 --of 3 --out w1.csv
    python fetch_district_weather.py --districts districts.csv --shard 2 --of 3 --out w2.csv
    # Tek makine: --shard 0 --of 1

Birleştir + prod'a yükle (droplet):
    cat w0.csv w1.csv w2.csv  (başlık tekrarını ele alarak) → weather_district.csv
    \copy weather_data(latitude,longitude,date,province_name,district_name,
      shortwave_radiation_sum,wind_speed_mean,wind_speed_max,wind_direction_dominant,
      temperature_mean,precipitation_sum,cloud_cover_mean,relative_humidity_mean)
      FROM 'weather_district.csv' CSV HEADER
    # sonra: build_ml_forecasts.py --use-daily

API: https://archive-api.open-meteo.com/v1/archive (ücretsiz, ~600 req/dk).
"""
from __future__ import annotations

import argparse
import csv
import sys
import time
from datetime import date

try:
    import requests
except ImportError:
    print("HATA: `pip install requests` gerekli."); sys.exit(1)

try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass

API_URL = "https://archive-api.open-meteo.com/v1/archive"
RATE_DELAY = 2.0
RL_WAIT = 65.0
MAX_RETRY = 6

# Open-Meteo daily değişkeni → weather_data kolonu
DAILY_VARS = [
    "temperature_2m_mean",
    "precipitation_sum",
    "shortwave_radiation_sum",
    "cloud_cover_mean",
    "relative_humidity_2m_mean",
    "wind_speed_10m_mean",
    "wind_speed_10m_max",
    "wind_direction_10m_dominant",
]
# CSV/weather_data kolon sırası
OUT_COLS = [
    "latitude", "longitude", "date", "province_name", "district_name",
    "shortwave_radiation_sum", "wind_speed_mean", "wind_speed_max",
    "wind_direction_dominant", "temperature_mean", "precipitation_sum",
    "cloud_cover_mean", "relative_humidity_mean",
]


def _fetch(lat: float, lon: float, start: str, end: str):
    params = {
        "latitude": lat, "longitude": lon,
        "start_date": start, "end_date": end,
        "daily": ",".join(DAILY_VARS),
        "timezone": "Europe/Istanbul",
    }
    for attempt in range(MAX_RETRY):
        try:
            r = requests.get(API_URL, params=params, timeout=90)
            if r.status_code == 200:
                return r.json().get("daily")
            if r.status_code == 429:
                print(f"      … 429, {RL_WAIT:.0f}sn bekle ({attempt+1}/{MAX_RETRY})")
                time.sleep(RL_WAIT)
                continue
            print(f"      ! HTTP {r.status_code}: {r.text[:120]}")
            return None
        except Exception as e:
            print(f"      ! istek hatası: {e} — 10sn bekle")
            time.sleep(10)
    return None


def _rows(daily: dict, prov: str, dist: str, lat: float, lon: float):
    times = daily.get("time") or []
    def col(n): return daily.get(n) or [None] * len(times)
    temp = col("temperature_2m_mean"); precip = col("precipitation_sum")
    rad = col("shortwave_radiation_sum"); cloud = col("cloud_cover_mean")
    hum = col("relative_humidity_2m_mean"); wmean = col("wind_speed_10m_mean")
    wmax = col("wind_speed_10m_max"); wdir = col("wind_direction_10m_dominant")
    out = []
    for i, t in enumerate(times):
        out.append([
            lat, lon, t, prov, dist,
            rad[i], wmean[i], wmax[i], wdir[i], temp[i],
            precip[i], cloud[i], hum[i],
        ])
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--districts", default="districts.csv", help="il/ilçe/centroid CSV")
    p.add_argument("--shard", type=int, default=0, help="bu makinenin shard indeksi")
    p.add_argument("--of", type=int, default=1, help="toplam shard sayısı")
    p.add_argument("--start", default="2015-01-01")
    p.add_argument("--end", default=date.today().isoformat())
    p.add_argument("--out", default=None, help="çıktı CSV (varsayılan weather_shard_<i>.csv)")
    a = p.parse_args()

    out_path = a.out or f"weather_shard_{a.shard}.csv"
    with open(a.districts, encoding="utf-8") as f:
        all_d = list(csv.DictReader(f))
    # Deterministik shard (round-robin) — tüm makinelerde aynı sıralama
    mine = [d for i, d in enumerate(all_d) if i % a.of == a.shard]

    print("=" * 64)
    print(f"  İlçe weather backfill — shard {a.shard}/{a.of}")
    print(f"  {len(mine)}/{len(all_d)} ilçe · {a.start}→{a.end} · out={out_path}")
    print("=" * 64)

    written = 0
    with open(out_path, "w", encoding="utf-8", newline="") as fo:
        w = csv.writer(fo)
        w.writerow(OUT_COLS)
        for i, d in enumerate(mine, 1):
            prov, dist = d["province"], d["district"]
            lat, lon = float(d["lat"]), float(d["lon"])
            daily = _fetch(lat, lon, a.start, a.end)
            time.sleep(RATE_DELAY)
            if not daily:
                print(f"  [{i}/{len(mine)}] {prov}/{dist}: yanıtsız — atlandı")
                continue
            rows = _rows(daily, prov, dist, lat, lon)
            w.writerows(rows)
            written += len(rows)
            fo.flush()
            if i % 20 == 0:
                print(f"  ... {i}/{len(mine)} ilçe, {written} satır")

    print("\n" + "=" * 64)
    print(f"  BİTTİ — {written} günlük satır → {out_path}")
    print("=" * 64)


if __name__ == "__main__":
    main()

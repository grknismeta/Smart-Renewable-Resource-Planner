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
import os
import re
import sys
import time
from datetime import date, timedelta

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
MAX_RETRY = 3            # 429 transient genelde 1-2 denemede geçer; 3 yeterli
# Üst üste bu kadar ilçe 429 ile tükenirse KOTA DOLU say → pass'i erken bitir
# (kuru kotada her ilçeyi 3×65sn beklemek günlerce sürerdi). Resume ile kayıp yok.
ABORT_AFTER_RL = 3

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
    """Returns (daily_dict | None, rate_limited: bool). rate_limited=True ise
    429 nedeniyle başarısız (kota); çağıran üst üste 429'da pass'i durdurur."""
    params = {
        "latitude": lat, "longitude": lon,
        "start_date": start, "end_date": end,
        "daily": ",".join(DAILY_VARS),
        "timezone": "Europe/Istanbul",
    }
    saw_429 = False
    for attempt in range(MAX_RETRY):
        try:
            r = requests.get(API_URL, params=params, timeout=90)
            if r.status_code == 200:
                return r.json().get("daily"), False
            if r.status_code == 429:
                saw_429 = True
                print(f"      … 429, {RL_WAIT:.0f}sn bekle ({attempt+1}/{MAX_RETRY})")
                time.sleep(RL_WAIT)
                continue
            # Arşiv kesim tarihi (örn "...to 2026-06-02") günden güne değişir;
            # 400 gelince izin verilen max tarihi yakalayıp end_date'i kıs, retry.
            if r.status_code == 400 and "end_date" in r.text and "allowed range" in r.text:
                m = re.search(r"to (\d{4}-\d{2}-\d{2})", r.text)
                if m and params["end_date"] != m.group(1):
                    params["end_date"] = m.group(1)
                    print(f"      … end_date {m.group(1)}'e kısıldı, retry")
                    continue
            print(f"      ! HTTP {r.status_code}: {r.text[:120]}")
            return None, False
        except Exception as e:
            print(f"      ! istek hatası: {e} — 10sn bekle")
            time.sleep(10)
    return None, saw_429


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
    p.add_argument("--end", default=(date.today() - timedelta(days=1)).isoformat())
    p.add_argument("--out", default=None, help="çıktı CSV (varsayılan weather_shard_<i>.csv)")
    p.add_argument("--fresh", action="store_true",
                   help="mevcut CSV'yi SIFIRDAN yaz (resume yapma)")
    a = p.parse_args()

    out_path = a.out or f"weather_shard_{a.shard}.csv"
    with open(a.districts, encoding="utf-8") as f:
        all_d = list(csv.DictReader(f))
    # Deterministik shard (round-robin) — tüm makinelerde aynı sıralama
    mine = [d for i, d in enumerate(all_d) if i % a.of == a.shard]

    # ── RESUME (2026-06-03): Open-Meteo kotası tek IP'de hızla doluyor; tek
    # seferde 975 ilçe bitmiyor. Çıktı CSV varsa ÇEKİLMİŞ (province,district)
    # çiftlerini oku → atla, dosyaya EKLE (append). Atlanan/429 yiyen ilçeler
    # CSV'ye yazılmadığı için sonraki çalıştırmada otomatik TEKRAR denenir.
    # Böylece script'i kota açıldıkça defalarca çalıştır → veri birikir, kayıp yok.
    done = set()
    resume = (not a.fresh) and os.path.exists(out_path) and os.path.getsize(out_path) > 0
    if resume:
        try:
            with open(out_path, encoding="utf-8") as f:
                for row in csv.DictReader(f):
                    prov_n = (row.get("province_name") or "").strip()
                    dist_n = (row.get("district_name") or "").strip()
                    if prov_n:
                        done.add((prov_n, dist_n))
        except Exception as e:
            print(f"  ! mevcut CSV okunamadı ({e}) — sıfırdan yazılacak")
            resume = False
            done = set()

    todo = [d for d in mine
            if (d["province"].strip(), d["district"].strip()) not in done]

    print("=" * 64)
    print(f"  İlçe weather backfill — shard {a.shard}/{a.of}"
          + ("  [RESUME]" if resume else ""))
    print(f"  {len(mine)} ilçe · {len(done)} hazır · {len(todo)} kalan"
          f" · {a.start}→{a.end} · out={out_path}")
    print("=" * 64)

    if not todo:
        print("  Tüm ilçeler zaten çekilmiş — yapılacak iş yok.")
        return

    written = 0
    fetched = 0
    skipped = 0
    consec_rl = 0
    aborted = False
    mode = "a" if resume else "w"
    with open(out_path, mode, encoding="utf-8", newline="") as fo:
        w = csv.writer(fo)
        if not resume:
            w.writerow(OUT_COLS)
        for i, d in enumerate(todo, 1):
            prov, dist = d["province"], d["district"]
            lat, lon = float(d["lat"]), float(d["lon"])
            daily, rate_limited = _fetch(lat, lon, a.start, a.end)
            time.sleep(RATE_DELAY)
            if not daily:
                skipped += 1
                consec_rl = consec_rl + 1 if rate_limited else 0
                reason = "kota/429" if rate_limited else "yanıtsız"
                print(f"  [{i}/{len(todo)}] {prov}/{dist}: {reason} — atlandı "
                      f"(sonraki çalıştırmada tekrar denenecek)")
                # Üst üste ABORT_AFTER_RL kez 429 → kota dolu, pass'i bitir.
                if consec_rl >= ABORT_AFTER_RL:
                    aborted = True
                    print(f"\n  ⛔ Üst üste {consec_rl} ilçe kota (429) nedeniyle "
                          f"alınamadı → KOTA DOLU görünüyor, çekim durduruldu.")
                    break
                continue
            consec_rl = 0
            rows = _rows(daily, prov, dist, lat, lon)
            w.writerows(rows)
            written += len(rows)
            fetched += 1
            fo.flush()
            if i % 10 == 0:
                print(f"  ... {i}/{len(todo)} | {fetched} çekildi, {skipped} atlandı, "
                      f"{written} satır")

    remaining = len(todo) - fetched
    print("\n" + "=" * 64)
    print(f"  {'DURDURULDU (kota)' if aborted else 'BİTTİ'} — bu pass: {fetched} ilçe "
          f"çekildi, {skipped} atlandı, {written} yeni satır → {out_path}")
    print(f"  Toplam ilerleme: {len(done) + fetched}/{len(mine)} ilçe hazır, "
          f"{remaining} kaldı.")
    if remaining > 0:
        print(f"  → Kota açılınca (genelde saat başı / ertesi gün) AYNI komutu "
              f"TEKRAR çalıştır — resume otomatik, kalan {remaining} denenir.")
    print("=" * 64)


if __name__ == "__main__":
    main()

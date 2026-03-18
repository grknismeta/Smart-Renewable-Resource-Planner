"""
bulk_backfill_districts.py
==========================
SRRP — Il/Ilce bazli gunluk hava verisi doldurma scripti

Hedef : TURKEY_CITIES (292 sehir) x 2014-2024 gunluk veri
Strateji:
  1. Mevcut weather_data'da bu koordinata yakin (<=COORD_TOLERANCE) kayit varsa
     ve district_name NULL ise → UPDATE ile il/ilce adini ata (API cagrisi yok).
  2. Bir yil icin hic kayit yoksa → Open-Meteo Archive API'dan cek ve
     district_name / province_name ile INSERT et.
  3. Resume destegi: her sehir+yil icin once bakiyiz, zaten islendiyse atla.

Calistirma:
  cd backend
  venv/Scripts/python bulk_backfill_districts.py

Beklenen sure: ~1.5-2 saat (API limit korumalari dahil)
"""

import sys, os, argparse
# app paketini bul
sys.path.insert(0, os.path.dirname(__file__))

import psycopg2
import psycopg2.extras
import requests_cache
import openmeteo_requests
from retry_requests import retry
import pandas as pd
import time
from datetime import date

# ─── Konfigurasyon ───────────────────────────────────────────────────────────

DB_URL = "postgresql://srrp_admin:srrp_secure_2026@localhost:5432/srrp_db"
ARCHIVE_API = "https://archive-api.open-meteo.com/v1/archive"

YEARS = list(range(2014, 2025))     # 2014 dahil, 2024 dahil
COORD_TOL = 0.28                    # Koordinat eslesme toleransi (derece)
BATCH_DELAY = 10                    # API cagrisi sonrasi bekleme (saniye)
RATE_LIMIT_WAIT = 90                # Rate limit cezasi bekleme suresi
MAX_RETRIES = 5

# ─── Arguman ayristirici ─────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="SRRP Bulk Backfill")
    p.add_argument(
        "--shard", default="1/1",
        help="Hangi dilimi isle: N/M  (orn. --shard 2/4 -> 4 cihazdan 2.sini isle). Varsayilan: 1/1 (tumu)"
    )
    p.add_argument(
        "--db-url", default=None,
        help="PostgreSQL baglanti adresi. Girilmezse DB_URL sabiti kullanilir."
    )
    p.add_argument(
        "--batch-delay", type=int, default=BATCH_DELAY,
        help=f"Her API cagrisinin ardindan bekleme suresi (saniye). Varsayilan: {BATCH_DELAY}"
    )
    return p.parse_args()

DAILY_PARAMS = [
    "temperature_2m_mean",
    "wind_speed_10m_max",
    "wind_speed_10m_mean",
    "wind_direction_10m_dominant",
    "shortwave_radiation_sum",
]

# ─── Open-Meteo istemcisi ─────────────────────────────────────────────────────

def make_client():
    cache = requests_cache.CachedSession('.cache_backfill', expire_after=-1)
    retrying = retry(cache, retries=3, backoff_factor=0.5)
    return openmeteo_requests.Client(session=retrying)

# ─── Veritabani yardimcilari ─────────────────────────────────────────────────

def get_conn():
    return psycopg2.connect(DB_URL)

def years_in_db(cur, lat, lon, tol=COORD_TOL):
    """Verilen koordinata yakin kayitlarin hangi yillari kapsadigini dondurur."""
    cur.execute("""
        SELECT DISTINCT EXTRACT(YEAR FROM date)::int
        FROM weather_data
        WHERE latitude  BETWEEN %s AND %s
          AND longitude BETWEEN %s AND %s
    """, (lat - tol, lat + tol, lon - tol, lon + tol))
    return {row[0] for row in cur.fetchall()}

def years_named(cur, district):
    """district_name=district olan kayitlarin yillarini dondurur."""
    cur.execute("""
        SELECT DISTINCT EXTRACT(YEAR FROM date)::int
        FROM weather_data
        WHERE district_name = %s
    """, (district,))
    return {row[0] for row in cur.fetchall()}

def update_names(cur, lat, lon, province, district, tol=COORD_TOL):
    """Koordinata yakin, isimsiz kayitlara il/ilce adini atar."""
    cur.execute("""
        UPDATE weather_data
        SET province_name = %s,
            district_name = %s
        WHERE latitude  BETWEEN %s AND %s
          AND longitude BETWEEN %s AND %s
          AND province_name IS NULL
    """, (province, district, lat - tol, lat + tol, lon - tol, lon + tol))
    return cur.rowcount

def insert_daily_records(cur, records):
    """Yeni gunluk kayitlari toplu ekler — cakisan (lat, lon, date) satirlari atlar."""
    if not records:
        return 0
    psycopg2.extras.execute_values(cur, """
        INSERT INTO weather_data
            (latitude, longitude, date, temperature_mean,
             wind_speed_max, wind_speed_mean, wind_direction_dominant,
             shortwave_radiation_sum, province_name, district_name)
        VALUES %s
        ON CONFLICT DO NOTHING
    """, records)
    return len(records)

# ─── Open-Meteo veri cekme ───────────────────────────────────────────────────

def fetch_year(client, lat, lon, province, district, year):
    """Bir sehir + yil icin archive API'dan gunluk veri ceker."""
    # 2024 icin bitis tarihi 31 Aralik 2024; veri gelmemis olabilir → gun olarak ayarla
    end = f"{year}-12-31"
    if year == 2024:
        end = "2024-12-31"

    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": f"{year}-01-01",
        "end_date": end,
        "daily": DAILY_PARAMS,
        "timezone": "Europe/Istanbul",
    }

    for attempt in range(MAX_RETRIES):
        try:
            responses = client.weather_api(ARCHIVE_API, params=params)
            response = responses[0]
            daily = response.Daily()

            times = pd.date_range(
                start=pd.to_datetime(daily.Time(), unit="s", utc=True),
                end=pd.to_datetime(daily.TimeEnd(), unit="s", utc=True),
                freq=pd.Timedelta(seconds=daily.Interval()),
                inclusive="left",
            )

            def safe(arr, i):
                v = arr[i]
                return float(v) if not pd.isna(v) else 0.0

            t_arr  = daily.Variables(0).ValuesAsNumpy()
            wm_arr = daily.Variables(1).ValuesAsNumpy()
            wa_arr = daily.Variables(2).ValuesAsNumpy()
            wd_arr = daily.Variables(3).ValuesAsNumpy()
            sr_arr = daily.Variables(4).ValuesAsNumpy()

            records = []
            for i in range(len(times)):
                temp = t_arr[i]
                if pd.isna(temp):
                    continue
                records.append((
                    lat, lon, times[i].date(),
                    float(temp),
                    safe(wm_arr, i), safe(wa_arr, i), safe(wd_arr, i), safe(sr_arr, i),
                    province, district,
                ))
            return records

        except Exception as e:
            err = str(e).lower()
            if "rate" in err or "limit" in err or "429" in err:
                wait = RATE_LIMIT_WAIT + attempt * 30
                print(f"      [WAIT] Rate limit! {wait}s bekleniyor... ({attempt+1}/{MAX_RETRIES})")
                time.sleep(wait)
            else:
                print(f"      [ERR] {year} cekme hatasi (deneme {attempt+1}): {e}")
                if attempt < MAX_RETRIES - 1:
                    time.sleep(15)
                else:
                    raise

    return []

# ─── Ana dongu ────────────────────────────────────────────────────────────────

def main():
    args = parse_args()

    # ── Shard hesapla ──────────────────────────────────────────────
    try:
        shard_n, shard_m = [int(x) for x in args.shard.split("/")]
        assert 1 <= shard_n <= shard_m
    except Exception:
        print(f"HATA: --shard formati yanlis: '{args.shard}'  (ornek: 2/4)")
        sys.exit(1)

    db_url = args.db_url or DB_URL
    batch_delay = args.batch_delay

    from app.core.constants import TURKEY_CITIES

    # Shard bolumleme: 0-tabanli index'e gore
    all_cities = list(TURKEY_CITIES)
    shard_cities = [c for i, c in enumerate(all_cities) if (i % shard_m) == (shard_n - 1)]

    client = make_client()
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()

    total_cities = len(all_cities)
    shard_total  = len(shard_cities)
    print("=" * 60)
    print(f"SRRP Backfill — Shard {shard_n}/{shard_m}  ({shard_total} sehir / {total_cities} toplam)")
    print(f"Yillar: {YEARS[0]}-{YEARS[-1]}   DB: {db_url[:40]}...")
    print("=" * 60)

    stats = {"updated": 0, "inserted": 0, "skipped_years": 0, "errors": 0}

    for idx, city in enumerate(shard_cities, 1):
        lat      = city["lat"]
        lon      = city["lon"]
        province = city["province"]
        district = city.get("district") or city["province"]
        name     = city["name"]

        print(f"\n[{idx:3}/{shard_total}] {name} ({province})  lat={lat} lon={lon}")

        # ── Adim 1: Mevcut kayitlara isim ata ──────────────────────────
        upd = update_names(cur, lat, lon, province, district)
        conn.commit()
        if upd:
            print(f"  [UPD] {upd} mevcut kayit guncellendi (isim atandi)")
            stats["updated"] += upd

        # ── Adim 2: Hangi yillar zaten tam var? ────────────────────────
        # "Tam" = district_name ile kayit var
        named_years = years_named(cur, district)

        # Koordinata yakin (isimli ya da isimsiz) yillar
        nearby_years = years_in_db(cur, lat, lon)

        # Koordinata yakin oldugu halde adlandirilamamis yillar da "var" sayilir
        # (update yapildi; sonraki sorguda named_years icinde goruniyor olabilir
        #  ama commit sonrasi yeniden cekelim)
        if upd:
            named_years = years_named(cur, district)

        missing = [y for y in YEARS if y not in named_years and y not in nearby_years]
        nearby_unnamed = [y for y in YEARS if y in nearby_years and y not in named_years]

        # Yakin ama isimsiz kalan yillar icin tekrar update dene
        # (tolerance disinda kaliyorsa bunlar API'dan cekilmeli)
        if nearby_unnamed:
            # Zaten update yapildiysa tekrar calisir ama zarar vermez
            upd2 = update_names(cur, lat, lon, province, district)
            conn.commit()
            if upd2:
                stats["updated"] += upd2
            named_years = years_named(cur, district)
            missing = [y for y in YEARS if y not in named_years and y not in nearby_years]

        already_done = [y for y in YEARS if y in named_years]
        if already_done:
            print(f"  [OK] Mevcut yillar: {sorted(already_done)}")
            stats["skipped_years"] += len(already_done)

        if not missing:
            print(f"  [DONE] Tum yillar tamam!")
            continue

        print(f"  [DL] Cekilecek yillar: {missing}")

        # ── Adim 3: Eksik yillari API'dan cek ──────────────────────────
        for year in missing:
            print(f"     {year}... ", end="", flush=True)
            try:
                records = fetch_year(client, lat, lon, province, district, year)
                if records:
                    inserted = insert_daily_records(cur, records)
                    conn.commit()
                    print(f"{inserted} kayit eklendi")
                    stats["inserted"] += inserted
                else:
                    print("0 kayit (API bos donus)")
                time.sleep(batch_delay)
            except Exception as e:
                conn.rollback()
                print(f"HATA: {e}")
                stats["errors"] += 1
                time.sleep(20)

    cur.close()
    conn.close()

    print("\n" + "=" * 60)
    print(f"TAMAMLANDI  (Shard {shard_n}/{shard_m}  —  {shard_total} sehir islendi)")
    print(f"  Guncellenen kayit : {stats['updated']:,}")
    print(f"  Eklenen kayit     : {stats['inserted']:,}")
    print(f"  Atlanan yil sayisi: {stats['skipped_years']:,}")
    print(f"  Hata sayisi       : {stats['errors']}")
    print("=" * 60)


if __name__ == "__main__":
    main()

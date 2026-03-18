"""
srrp_backfill.py
=================
SRRP - Turkiye Yenilenebilir Enerji Veri Cekme Scripti

Her cihazda bagimsiz calisir. Paylasimli sunucu gerekmez.

Ne yapar:
  1. Gerekli Python paketlerini otomatik kurar
  2. Turkiye'deki ~1054 il/ilce merkezini OpenStreetMap'ten ceker
  3. Kendi SQLite veritabanini olusturur
  4. 2016-2024 gunluk hava verisini ceker (9 yil)
  5. 2025-2026 saatlik hava verisini ceker (devam ediyor)
  6. Herhangi bir noktada kesilirse devam eder (resume)

Kullanim:
  python srrp_backfill.py --shard 1/4
  python srrp_backfill.py --shard 2/4
  ...

Cikti: srrp_shard_1_4.db  (shard numarasina gore adlandirilir)
"""

# ==============================================================================
# ADIM 0 — Otomatik paket kurulumu (baska hicbir sey kurmaya gerek yok)
# ==============================================================================
import sys
import subprocess


def _ensure_packages():
    needed = [
        ("openmeteo-requests", "openmeteo_requests"),
        ("requests-cache",     "requests_cache"),
        ("retry-requests",     "retry_requests"),
        ("pandas",             "pandas"),
        ("requests",           "requests"),
    ]
    import importlib
    to_install = []
    for pkg, mod in needed:
        try:
            importlib.import_module(mod)
        except ImportError:
            to_install.append(pkg)

    if to_install:
        print(f"Kuruluyor: {', '.join(to_install)}")
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install"] + to_install + ["-q"]
        )
        print("  Kurulum tamamlandi.\n")


_ensure_packages()


# ==============================================================================
# Gercek importlar (kurulumdan SONRA)
# ==============================================================================
import os
import json
import sqlite3
import time
import argparse
from pathlib import Path
from datetime import date

import pandas as pd
import requests
import requests_cache
import openmeteo_requests
from retry_requests import retry

# Windows konsolunda Turkce karakter sorunu
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# ==============================================================================
# Yapilandirma
# ==============================================================================

ARCHIVE_API  = "https://archive-api.open-meteo.com/v1/archive"
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

DAILY_YEARS  = list(range(2016, 2025))   # 2016-2024 (9 yil)
HOURLY_YEARS = [2025, 2026]              # Saatlik, devam ediyor

BATCH_DELAY  = 12    # API cagrisi arasi bekleme (saniye)
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

# ==============================================================================
# Arguman
# ==============================================================================

def parse_args():
    p = argparse.ArgumentParser(
        description="SRRP Veri Cekme — Shard veya Manifest Modu"
    )
    p.add_argument(
        "--manifest", default=None,
        help="Manifest JSON dosyasi (distribute.py veya check_coverage.py ciktisi)"
    )
    p.add_argument(
        "--shard", default="1/1",
        help="Shard modu (manifest yoksa): N/M  (orn: --shard 2/4)"
    )
    p.add_argument(
        "--mode", choices=["all", "daily", "hourly"], default="all",
        help="Cekme modu (manifest olmadikca): all | daily | hourly"
    )
    p.add_argument(
        "--batch-delay", type=int, default=BATCH_DELAY,
        help=f"API cagrisi arasi bekleme (saniye). Varsayilan: {BATCH_DELAY}"
    )
    p.add_argument(
        "--db-path", default=None,
        help="SQLite dosya yolu (varsayilan: shard veya manifest ID'sine gore)"
    )
    return p.parse_args()


def load_manifest(path):
    """Manifest JSON dosyasini yukle."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

# ==============================================================================
# Sehir Listesi — Overpass API ile uretilir, yerel cache'de saklanir
# ==============================================================================

_CACHE_FILE = Path(__file__).parent / "turkey_districts.json"

_IL_QUERY = """
[out:json][timeout:60];
area["ISO3166-1"="TR"][admin_level=2]->.tr;
relation["boundary"="administrative"]["admin_level"="4"](area.tr);
out bb tags;
"""

_ILCE_QUERY = """
[out:json][timeout:180];
area["ISO3166-1"="TR"][admin_level=2]->.tr;
relation["boundary"="administrative"]["admin_level"="6"](area.tr);
out center tags;
"""


def _overpass_fetch(query, desc, retries=3):
    for attempt in range(retries):
        try:
            r = requests.post(
                OVERPASS_URL, data={"data": query}, timeout=240
            )
            r.raise_for_status()
            elements = r.json().get("elements", [])
            print(f"  {desc}: {len(elements)} eleman")
            return elements
        except Exception as e:
            wait = 30 * (attempt + 1)
            print(f"  [HATA] Deneme {attempt + 1}: {e}  ({wait}s sonra tekrar)")
            time.sleep(wait)
    return []


def _find_province_by_bbox(lat, lon, il_elements):
    for el in il_elements:
        bb = el.get("bounds", {})
        if not bb:
            continue
        if (
            bb.get("minlat", 999) <= lat <= bb.get("maxlat", -999)
            and bb.get("minlon", 999) <= lon <= bb.get("maxlon", -999)
        ):
            t = el.get("tags", {})
            return t.get("name:tr") or t.get("name") or ""
    return ""


def load_or_generate_cities():
    """
    Yerel cache varsa onu kullan. Yoksa Overpass'tan cek ve cache'e yaz.
    """
    if _CACHE_FILE.exists():
        with open(_CACHE_FILE, "r", encoding="utf-8") as f:
            cities = json.load(f)
        print(f"Sehir listesi: cache ({len(cities)} konum) — {_CACHE_FILE.name}")
        return cities

    print("Sehir listesi olusturuluyor (Overpass API)...")
    print("  Bu islem 1-2 dakika surebilir, sadece ilk seferinde yapilir.")

    il_elements   = _overpass_fetch(_IL_QUERY,   "Iller (admin=4)")
    time.sleep(3)
    ilce_elements = _overpass_fetch(_ILCE_QUERY, "Ilceler (admin=6)")

    cities  = []
    skipped = 0

    for el in ilce_elements:
        center = el.get("center", {})
        lat    = center.get("lat")
        lon    = center.get("lon")
        tags   = el.get("tags", {})
        name   = tags.get("name:tr") or tags.get("name") or ""

        if not name or lat is None or lon is None:
            skipped += 1
            continue

        province = (
            tags.get("is_in:province")
            or tags.get("addr:province")
            or _find_province_by_bbox(lat, lon, il_elements)
            or name
        )

        is_center = name.lower().strip() == province.lower().strip()
        cities.append({
            "name":     name,
            "province": province,
            "district": None if is_center else name,
            "lat":      round(lat, 4),
            "lon":      round(lon, 4),
        })

    cities.sort(key=lambda c: (c["province"], c["name"]))

    if len(cities) < 500:
        print(f"\n  [UYARI] Sadece {len(cities)} konum bulundu!")
        print("  Overpass gecici sorun yasaniyor olabilir.")
        print("  Script 10 dakika sonra tekrar denenecek...")
        time.sleep(600)
        return load_or_generate_cities()

    with open(_CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(cities, f, ensure_ascii=False, indent=2)

    print(f"  {len(cities)} konum uretildi ve kaydedildi ({skipped} atlanip).")
    return cities

# ==============================================================================
# SQLite Veritabani
# ==============================================================================

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
        "SELECT status FROM progress "
        "WHERE latitude=? AND longitude=? AND task=?",
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

# ==============================================================================
# Open-Meteo API
# ==============================================================================

def make_client():
    cache   = requests_cache.CachedSession(".srrp_api_cache", expire_after=-1)
    session = retry(cache, retries=3, backoff_factor=0.5)
    return openmeteo_requests.Client(session=session)


def safe_api_call(client, params):
    """Rate-limit korumalı arsiv API cagrisi."""
    for attempt in range(MAX_RETRIES):
        try:
            return client.weather_api(ARCHIVE_API, params=params)[0]
        except Exception as e:
            err = str(e).lower()
            if any(x in err for x in ("rate", "limit", "429", "too many")):
                wait = RATE_WAIT + attempt * 30
                print(
                    f"\n      [WAIT] Rate limit — "
                    f"{wait}s bekleniyor ({attempt + 1}/{MAX_RETRIES})"
                )
                time.sleep(wait)
            else:
                print(f"\n      [ERR] Deneme {attempt + 1}: {e}")
                if attempt < MAX_RETRIES - 1:
                    time.sleep(15)
                else:
                    raise
    return None


def _sf(arr, i):
    """Safe float: NaN ise None don."""
    v = arr[i]
    return float(v) if not pd.isna(v) else None


def fetch_daily(client, lat, lon, province, district, year):
    today = date.today()
    end   = f"{year}-12-31" if year < today.year else today.strftime("%Y-%m-%d")

    resp = safe_api_call(client, {
        "latitude":   lat,
        "longitude":  lon,
        "start_date": f"{year}-01-01",
        "end_date":   end,
        "daily":      DAILY_PARAMS,
        "timezone":   "Europe/Istanbul",
    })
    if resp is None:
        return []

    d     = resp.Daily()
    times = pd.date_range(
        start    = pd.to_datetime(d.Time(),    unit="s", utc=True),
        end      = pd.to_datetime(d.TimeEnd(), unit="s", utc=True),
        freq     = pd.Timedelta(seconds=d.Interval()),
        inclusive= "left",
    )
    arrs = [d.Variables(i).ValuesAsNumpy() for i in range(len(DAILY_PARAMS))]

    rows = []
    for i, t in enumerate(times):
        if pd.isna(arrs[0][i]):
            continue
        rows.append((
            lat, lon, province, district,
            t.date().isoformat(),
            _sf(arrs[0], i), _sf(arrs[1], i), _sf(arrs[2], i),
            _sf(arrs[3], i), _sf(arrs[4], i),
        ))
    return rows


def fetch_hourly(client, lat, lon, province, district, year):
    today = date.today()
    start = f"{year}-01-01"
    end   = f"{year}-12-31" if year < today.year else today.strftime("%Y-%m-%d")

    if start == end:
        return []

    resp = safe_api_call(client, {
        "latitude":   lat,
        "longitude":  lon,
        "start_date": start,
        "end_date":   end,
        "hourly":     HOURLY_PARAMS,
        "timezone":   "Europe/Istanbul",
    })
    if resp is None:
        return []

    h     = resp.Hourly()
    times = pd.date_range(
        start    = pd.to_datetime(h.Time(),    unit="s", utc=True),
        end      = pd.to_datetime(h.TimeEnd(), unit="s", utc=True),
        freq     = pd.Timedelta(seconds=h.Interval()),
        inclusive= "left",
    )
    arrs = [h.Variables(i).ValuesAsNumpy() for i in range(len(HOURLY_PARAMS))]

    rows = []
    for i, t in enumerate(times):
        if pd.isna(arrs[0][i]):
            continue
        rows.append((
            lat, lon, province, district,
            t.strftime("%Y-%m-%dT%H:%M"),
            _sf(arrs[0], i), _sf(arrs[1], i),
            _sf(arrs[2], i), _sf(arrs[3], i),
        ))
    return rows

# ==============================================================================
# Ana Dongu
# ==============================================================================

def _run_city(conn, client, city, allowed_tasks, delay, today, stats):
    """
    Tek bir sehir icin gorevleri calistir.
    allowed_tasks=None ise tum gorevler, aksi halde sadece listedekiler.
    """
    lat      = city["lat"]
    lon      = city["lon"]
    province = city.get("province", "")
    district = city.get("district") or province

    # Gunluk
    for year in DAILY_YEARS:
        task = f"daily_{year}"
        if allowed_tasks is not None and task not in allowed_tasks:
            continue
        if is_done(conn, lat, lon, task):
            stats["skip"] += 1
            continue
        print(f"  G{year}... ", end="", flush=True)
        try:
            rows = fetch_daily(client, lat, lon, province, district, year)
            if rows:
                insert_daily(conn, rows)
                print(f"{len(rows)} kayit")
                stats["daily"] += len(rows)
            else:
                print("0")
            mark_done(conn, lat, lon, task)
            time.sleep(delay)
        except Exception as e:
            print(f"HATA: {e}")
            stats["err"] += 1
            time.sleep(20)

    # Saatlik
    for year in HOURLY_YEARS:
        task    = f"hourly_{year}"
        ongoing = (year >= today.year)
        if allowed_tasks is not None and task not in allowed_tasks:
            continue
        if not ongoing and is_done(conn, lat, lon, task):
            stats["skip"] += 1
            continue
        print(f"  S{year}... ", end="", flush=True)
        try:
            rows = fetch_hourly(client, lat, lon, province, district, year)
            if rows:
                insert_hourly(conn, rows)
                print(f"{len(rows)} kayit")
                stats["hourly"] += len(rows)
            else:
                print("0")
            if not ongoing:
                mark_done(conn, lat, lon, task)
            time.sleep(delay)
        except Exception as e:
            print(f"HATA: {e}")
            stats["err"] += 1
            time.sleep(20)


def main():
    args  = parse_args()
    delay = args.batch_delay
    today = date.today()

    # ── Mod: Manifest mi, Shard mi? ───────────────────────────────────────────
    if args.manifest:
        # Manifest modu
        manifest     = load_manifest(args.manifest)
        work_cities  = manifest["cities"]
        manifest_id  = manifest.get("id", Path(args.manifest).stem)
        gap_mode     = manifest.get("mode") == "gap_fill"
        db_path      = args.db_path or f"srrp_{manifest_id}.db"

        print("\n" + "=" * 65)
        print(f"  SRRP Backfill — Manifest Modu")
        print(f"  Manifest  : {args.manifest}  ({manifest_id})")
        print(f"  Mod       : {'Gap Fill (sadece eksikler)' if gap_mode else 'Normal'}")
        print(f"  Konum     : {len(work_cities)}")
        print(f"  Veritabani: {db_path}")
        print("=" * 65)

    else:
        # Shard modu (orijinal)
        try:
            shard_n, shard_m = [int(x) for x in args.shard.split("/")]
            assert 1 <= shard_n <= shard_m
        except Exception:
            print(f"HATA: Yanlis shard formati: '{args.shard}'  (orn: 2/4)")
            sys.exit(1)

        all_cities  = load_or_generate_cities()
        work_cities = [
            c for i, c in enumerate(all_cities)
            if (i % shard_m) == (shard_n - 1)
        ]
        gap_mode    = False
        db_path     = args.db_path or f"srrp_shard_{shard_n}_{shard_m}.db"

        print("\n" + "=" * 65)
        print(f"  SRRP Backfill — Shard {shard_n}/{shard_m}")
        print(f"  Konum     : {len(work_cities)} / {len(all_cities)}")
        print(f"  Veritabani: {db_path}")
        print("=" * 65)

    conn   = init_db(db_path)
    client = make_client()
    stats  = {"daily": 0, "hourly": 0, "skip": 0, "err": 0}

    for idx, city in enumerate(work_cities, 1):
        name     = city["name"]
        province = city.get("province", "")

        # Gap fill modunda her sehirin sadece eksik gorevleri var
        allowed_tasks = set(city["only_tasks"]) if gap_mode and "only_tasks" in city else None

        task_label = (
            f"  [{','.join(allowed_tasks)}]" if allowed_tasks else ""
        )
        print(f"\n[{idx:4}/{len(work_cities)}] {name} ({province}){task_label}")

        _run_city(conn, client, city, allowed_tasks, delay, today, stats)

    # Sonuc
    daily_total  = conn.execute("SELECT COUNT(*) FROM weather_daily").fetchone()[0]
    hourly_total = conn.execute("SELECT COUNT(*) FROM weather_hourly").fetchone()[0]
    conn.close()

    label = args.manifest or args.shard
    print("\n" + "=" * 65)
    print(f"  TAMAMLANDI  — {label}")
    print(f"  Bu seferki gunluk  : +{stats['daily']:,}")
    print(f"  Bu seferki saatlik : +{stats['hourly']:,}")
    print(f"  Atlanan            :  {stats['skip']:,}")
    print(f"  Hata               :  {stats['err']}")
    print(f"  DB gunluk toplam   :  {daily_total:,}")
    print(f"  DB saatlik toplam  :  {hourly_total:,}")
    print(f"  Dosya              :  {db_path}")
    print("=" * 65)
    print("\nBitti! Bu pencereyi kapatin veya Enter'a basin.")
    input()


if __name__ == "__main__":
    main()

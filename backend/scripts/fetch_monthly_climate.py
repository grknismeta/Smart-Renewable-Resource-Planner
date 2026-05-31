r"""M-E.2 — 20 yıllık il-bazlı aylık iklim çekimi (2026-05-30).

Open-Meteo Historical Archive'dan 81 il için 2005→bugün GÜNLÜK çeker, lokal
olarak AYLIĞA toplulaştırır ve `monthly_climate` tablosuna yazar.

Neden bu yöntem (eski backfill yerine):
  - Eski backfill: ~1003 ilçe × satır-satır UPDATE → günler sürer (%4.5'te kaldı).
  - Bu: 81 il × 1 istek = ~2-3 dk. Tek çekimde precip+cloud+radiation+wind+temp.
  - İlçe ML zaten weather_data günlük aggregate kullanıyor; uzun-vade TREND için
    il-bazlı 20 yıl yeterli ve çok daha hızlı.

API: https://archive-api.open-meteo.com/v1/archive (ücretsiz, ~1 req/sn)

Toplulaştırma kuralları (aylık):
  - precipitation_sum        → ay TOPLAMI (mm)
  - shortwave_radiation_sum  → günlük sum'ların ay ORTALAMASI (weather_data ile uyumlu)
  - sunshine_hours           → sunshine_duration (sn) toplamı / 3600
  - cloud / humidity / temp / wind → ay ORTALAMASI

Resume: il bazında upsert. Yarıda kesilirse --skip-existing ile devam.

Kullanım:
    cd backend
    ..\.venv\Scripts\python.exe scripts\fetch_monthly_climate.py
    ..\.venv\Scripts\python.exe scripts\fetch_monthly_climate.py --province Konya
    ..\.venv\Scripts\python.exe scripts\fetch_monthly_climate.py --start 2005-01-01
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from collections import defaultdict
from datetime import date

try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

API_URL = "https://archive-api.open-meteo.com/v1/archive"
RATE_DELAY = 2.0   # saniye/istek (ağır archive istekleri için nazik)
RL_WAIT = 65.0     # 429 (dakikalık limit) sonrası bekleme
MAX_RETRY = 6      # 429 için aynı ili tekrar deneme

DAILY_VARS = [
    "temperature_2m_mean",
    "precipitation_sum",
    "shortwave_radiation_sum",
    "cloud_cover_mean",
    "relative_humidity_2m_mean",
    "wind_speed_10m_mean",
    "sunshine_duration",
]


def _province_coords(db, province_filter):
    """weather_data'dan il başına ortalama (centroid) koordinat."""
    from sqlalchemy import text
    sql = text("""
        SELECT province_name,
               AVG(latitude)  AS lat,
               AVG(longitude) AS lon
        FROM weather_data
        WHERE province_name IS NOT NULL
        GROUP BY province_name
        ORDER BY province_name
    """)
    rows = db.execute(sql).fetchall()
    out = [(r[0], float(r[1]), float(r[2])) for r in rows]
    if province_filter:
        from app.services.province_aliases import province_aliases
        variants = set(province_aliases(province_filter))
        out = [r for r in out if r[0] in variants]
    return out


def _fetch(lat: float, lon: float, start: str, end: str) -> dict | None:
    """429 (dakikalık limit) görünce bekleyip aynı isteği tekrar dener."""
    import requests
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": start,
        "end_date": end,
        "daily": ",".join(DAILY_VARS),
        "timezone": "Europe/Istanbul",
    }
    for attempt in range(MAX_RETRY):
        try:
            r = requests.get(API_URL, params=params, timeout=60)
            if r.status_code == 200:
                return r.json().get("daily")
            if r.status_code == 429:
                print(f"      … 429 dakikalık limit, {RL_WAIT:.0f}sn bekle "
                      f"(deneme {attempt + 1}/{MAX_RETRY})")
                time.sleep(RL_WAIT)
                continue
            print(f"      ! HTTP {r.status_code}: {r.text[:120]}")
            return None
        except Exception as e:
            print(f"      ! istek hatası: {e} — 10sn bekle")
            time.sleep(10)
    print("      ! 429 limiti aşılamadı (max retry)")
    return None


def _aggregate_monthly(daily: dict) -> list[dict]:
    """Günlük dizileri (year, month) bazında aylığa indir."""
    times = daily.get("time") or []
    if not times:
        return []

    def col(name):
        return daily.get(name) or [None] * len(times)

    temp = col("temperature_2m_mean")
    precip = col("precipitation_sum")
    rad = col("shortwave_radiation_sum")
    cloud = col("cloud_cover_mean")
    hum = col("relative_humidity_2m_mean")
    wmean = col("wind_speed_10m_mean")
    sun = col("sunshine_duration")

    buckets: dict[tuple[int, int], dict[str, list]] = defaultdict(
        lambda: {k: [] for k in
                 ("temp", "precip", "rad", "cloud", "hum", "wind", "sun")}
    )

    for i, t in enumerate(times):
        y, m = int(t[0:4]), int(t[5:7])
        b = buckets[(y, m)]
        if temp[i] is not None: b["temp"].append(temp[i])
        if precip[i] is not None: b["precip"].append(precip[i])
        if rad[i] is not None: b["rad"].append(rad[i])
        if cloud[i] is not None: b["cloud"].append(cloud[i])
        if hum[i] is not None: b["hum"].append(hum[i])
        if wmean[i] is not None: b["wind"].append(wmean[i])
        if sun[i] is not None: b["sun"].append(sun[i])

    def avg(xs): return sum(xs) / len(xs) if xs else None

    out = []
    for (y, m), b in sorted(buckets.items()):
        out.append({
            "year": y, "month": m,
            "temperature_mean": avg(b["temp"]),
            "precipitation_sum": sum(b["precip"]) if b["precip"] else None,
            "shortwave_radiation_sum": avg(b["rad"]),
            "cloud_cover_mean": avg(b["cloud"]),
            "relative_humidity_mean": avg(b["hum"]),
            "wind_speed_mean": avg(b["wind"]),
            "sunshine_hours": (sum(b["sun"]) / 3600.0) if b["sun"] else None,
            "n_days": max(len(b["temp"]), len(b["precip"]), len(b["rad"])),
        })
    return out


def main(province_filter, start_date: str, end_date: str,
         skip_existing: bool) -> None:
    from app.db.database import SystemEngine, SystemSessionLocal, SystemBase
    from app.db.models import MonthlyClimate
    from sqlalchemy import text
    from sqlalchemy.dialects.postgresql import insert as pg_insert

    # Tabloyu oluştur (yoksa)
    SystemBase.metadata.create_all(
        bind=SystemEngine, tables=[MonthlyClimate.__table__])

    print("=" * 64)
    print("  M-E.2 — monthly_climate (20 yıllık il-bazlı aylık)")
    print(f"  range={start_date} → {end_date} · "
          f"province={province_filter or 'TÜM 81 İL'} · skip={skip_existing}")
    print("=" * 64)

    with SystemSessionLocal() as db:
        provs = _province_coords(db, province_filter)
        print(f"Toplam {len(provs)} il\n")

        total_rows = 0
        for i, (prov, lat, lon) in enumerate(provs, 1):
            if skip_existing:
                cnt = db.execute(text(
                    "SELECT COUNT(*) FROM monthly_climate "
                    "WHERE province_name=:p"), {"p": prov}).scalar() or 0
                if cnt >= 200:  # ~20 yıl × 12 ≈ 240, büyük çoğunluk dolu
                    print(f"  [{i}/{len(provs)}] {prov}: {cnt} ay dolu — atlandı")
                    continue

            daily = _fetch(lat, lon, start_date, end_date)
            time.sleep(RATE_DELAY)
            if not daily:
                print(f"  [{i}/{len(provs)}] {prov}: API yanıtsız — atlandı")
                continue

            monthly = _aggregate_monthly(daily)
            if not monthly:
                print(f"  [{i}/{len(provs)}] {prov}: aylık veri yok")
                continue

            for row in monthly:
                stmt = pg_insert(MonthlyClimate).values(
                    province_name=prov, latitude=lat, longitude=lon,
                    source="open-meteo-archive", **row,
                )
                stmt = stmt.on_conflict_do_update(
                    constraint="uq_monthly_climate_key",
                    set_={
                        "temperature_mean": stmt.excluded.temperature_mean,
                        "precipitation_sum": stmt.excluded.precipitation_sum,
                        "shortwave_radiation_sum": stmt.excluded.shortwave_radiation_sum,
                        "cloud_cover_mean": stmt.excluded.cloud_cover_mean,
                        "relative_humidity_mean": stmt.excluded.relative_humidity_mean,
                        "wind_speed_mean": stmt.excluded.wind_speed_mean,
                        "sunshine_hours": stmt.excluded.sunshine_hours,
                        "n_days": stmt.excluded.n_days,
                    },
                )
                db.execute(stmt)
            db.commit()
            total_rows += len(monthly)
            rng = f"{monthly[0]['year']}/{monthly[0]['month']:02d}→{monthly[-1]['year']}/{monthly[-1]['month']:02d}"
            print(f"  [{i}/{len(provs)}] {prov}: {len(monthly)} ay ({rng}) ✓")

    print("\n" + "=" * 64)
    print(f"  BİTTİ — {total_rows} aylık satır yazıldı/güncellendi")
    print("=" * 64)


def run_local() -> None:
    """API'siz: weather_data'dan (2015-2026) tüm illeri aylıklaştır.

    Open-Meteo kotasına dokunmaz (saf SQL). Zaten API'den derin çekilmiş
    iller (source='open-meteo-archive') ATLANIR — üzerine yazılmaz. Sadece
    eksik illeri 2015-2026 temp/wind/radiation ile doldurur.
    precip/cloud weather_data'da çoğunlukla boş → NULL kalır (sonra opsiyonel).
    """
    from app.db.database import SystemEngine, SystemSessionLocal, SystemBase
    from app.db.models import MonthlyClimate
    from sqlalchemy import text
    from sqlalchemy.dialects.postgresql import insert as pg_insert

    SystemBase.metadata.create_all(
        bind=SystemEngine, tables=[MonthlyClimate.__table__])

    print("=" * 64)
    print("  M-E.2 (LOCAL) — weather_data → monthly_climate (API'siz)")
    print("=" * 64)

    with SystemSessionLocal() as db:
        # API'den derin çekilmiş illeri koru
        deep = {r[0] for r in db.execute(text(
            "SELECT DISTINCT province_name FROM monthly_climate "
            "WHERE source='open-meteo-archive'")).fetchall()}
        print(f"Korunan (derin/API) il: {len(deep)}")

        # weather_data il-bazlı aylık aggregate (tüm ilçelerin AVG'i)
        rows = db.execute(text("""
            SELECT province_name,
                   EXTRACT(YEAR  FROM date)::int  AS y,
                   EXTRACT(MONTH FROM date)::int  AS m,
                   AVG(temperature_mean)         AS temp,
                   AVG(wind_speed_mean)          AS wind,
                   AVG(shortwave_radiation_sum)  AS rad,
                   AVG(latitude)                 AS lat,
                   AVG(longitude)                AS lon,
                   COUNT(*)                      AS n
            FROM weather_data
            WHERE province_name IS NOT NULL
              AND temperature_mean IS NOT NULL
            GROUP BY province_name, y, m
            ORDER BY province_name, y, m
        """)).fetchall()

        total, provs = 0, set()
        for r in rows:
            if r.province_name in deep:
                continue
            provs.add(r.province_name)
            stmt = pg_insert(MonthlyClimate).values(
                province_name=r.province_name, latitude=r.lat, longitude=r.lon,
                year=r.y, month=r.m,
                temperature_mean=float(r.temp) if r.temp is not None else None,
                wind_speed_mean=float(r.wind) if r.wind is not None else None,
                shortwave_radiation_sum=float(r.rad) if r.rad is not None else None,
                n_days=int(r.n), source="weather_data-local",
            )
            stmt = stmt.on_conflict_do_update(
                constraint="uq_monthly_climate_key",
                set_={
                    "temperature_mean": stmt.excluded.temperature_mean,
                    "wind_speed_mean": stmt.excluded.wind_speed_mean,
                    "shortwave_radiation_sum": stmt.excluded.shortwave_radiation_sum,
                    "n_days": stmt.excluded.n_days,
                    "source": stmt.excluded.source,
                },
            )
            db.execute(stmt)
            total += 1
        db.commit()
        print(f"\n  BİTTİ — {len(provs)} il, {total} aylık satır (yerel)")
    print("=" * 64)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--province", default=None, help="Tek il filtresi")
    p.add_argument("--start", default="2005-01-01", help="Başlangıç (20 yıl)")
    p.add_argument("--end", default=date.today().isoformat(), help="Bitiş")
    p.add_argument("--no-skip-existing", action="store_true",
                   help="Dolu illeri de tekrar çek")
    p.add_argument("--local", action="store_true",
                   help="API'siz: weather_data'dan aylıklaştır (kota harcamaz)")
    args = p.parse_args()
    if args.local:
        run_local()
    else:
        main(province_filter=args.province,
             start_date=args.start, end_date=args.end,
             skip_existing=not args.no_skip_existing)

r"""M-E.1 — weather_data precipitation/cloud/humidity backfill (2026-05-28).

Open-Meteo Historical Archive API'den 2015→bugün günlük precipitation/cloud/
humidity çeker ve weather_data tablosuna işler.

API: https://archive-api.open-meteo.com/v1/archive
  - Ücretsiz, kayıt gerekmez
  - Günlük ~10K istek limit
  - Tek istekte 10+ yıl, çoklu metrik döner

Strateji:
  - weather_data'da distinct (province, district, lat, lon) → ~1003 lokasyon
  - Her lokasyon için tek API çağrısı (2015-01-01 → bugün, daily=precip+cloud+humidity)
  - Bulk UPDATE: matching date+province+district satırlarını set et
  - Rate limit: ~1 req/sec (saniyede 1, gün için fazlasıyla yeterli)
  - Resume: her ilçe bitince commit, yarıda kesilse kaldığı yerden devam

**Kullanım:**

    cd backend
    ..\.venv\Scripts\python.exe scripts\backfill_weather_extras.py
    ..\.venv\Scripts\python.exe scripts\backfill_weather_extras.py --province Konya
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from datetime import date, datetime

try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

API_URL = "https://archive-api.open-meteo.com/v1/archive"
RATE_DELAY = 1.0  # saniye/istek


def _distinct_locations(db, province_filter):
    from app.db.models import WeatherData
    from sqlalchemy import func
    q = db.query(
        WeatherData.province_name,
        WeatherData.district_name,
        func.avg(WeatherData.latitude).label("lat"),
        func.avg(WeatherData.longitude).label("lon"),
    ).filter(
        WeatherData.province_name.isnot(None),
        WeatherData.district_name.isnot(None),
    ).group_by(WeatherData.province_name, WeatherData.district_name)
    if province_filter:
        from app.services.province_aliases import province_aliases
        q = q.filter(WeatherData.province_name.in_(
            province_aliases(province_filter)))
    return q.all()


def _fetch(lat: float, lon: float, start: str, end: str) -> dict | None:
    """Open-Meteo Historical: tek lat/lon için daily precip+cloud+humidity."""
    import requests
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": start,
        "end_date": end,
        "daily": ",".join([
            "precipitation_sum",
            "cloud_cover_mean",
            "relative_humidity_2m_mean",
        ]),
        "timezone": "Europe/Istanbul",
    }
    try:
        r = requests.get(API_URL, params=params, timeout=30)
        if r.status_code != 200:
            return None
        return r.json().get("daily")
    except Exception:
        return None


def main(province_filter, start_date: str, end_date: str,
         skip_existing: bool) -> None:
    from app.db.database import SystemSessionLocal
    from app.db.models import WeatherData
    from sqlalchemy import text, func

    print("=" * 64)
    print("  M-E.1 — weather_data extras backfill")
    print(f"  range={start_date} → {end_date} · "
          f"province={province_filter or 'ALL'} · skip_existing={skip_existing}")
    print("=" * 64)

    total_updated = 0
    skipped = 0

    with SystemSessionLocal() as db:
        locs = _distinct_locations(db, province_filter)
        print(f"Toplam {len(locs)} lokasyon\n")

        for i, (prov, dist, lat, lon) in enumerate(locs, 1):
            if skip_existing:
                already = db.execute(text(
                    "SELECT COUNT(*) FROM weather_data "
                    "WHERE province_name=:p AND district_name=:d "
                    "AND precipitation_sum IS NOT NULL"
                ), {"p": prov, "d": dist}).scalar() or 0
                if already > 100:  # büyük çoğunluk dolu
                    skipped += 1
                    if i % 50 == 0:
                        print(f"  [{i}/{len(locs)}] {prov}|{dist} "
                              f"zaten dolu (atlandı)")
                    continue

            data = _fetch(float(lat), float(lon), start_date, end_date)
            time.sleep(RATE_DELAY)
            if not data:
                print(f"  X {prov}|{dist}: API yanıtsız")
                continue

            dates = data.get("time") or []
            precs = data.get("precipitation_sum") or []
            clouds = data.get("cloud_cover_mean") or []
            hums = data.get("relative_humidity_2m_mean") or []
            if not dates:
                continue

            # Bulk UPDATE — date + (prov, dist) eşleşmesi
            rows_to_update = []
            for d_str, p, c, h in zip(dates, precs, clouds, hums):
                rows_to_update.append({
                    "d": d_str, "p_": prov, "dist": dist,
                    "precip": p, "cloud": c, "hum": h,
                })

            # CASE WHEN style update — daha verimli: chunked UPDATE
            CHUNK = 500
            updated = 0
            for j in range(0, len(rows_to_update), CHUNK):
                chunk = rows_to_update[j:j + CHUNK]
                # Tek tek UPDATE (chunked transaction)
                for r in chunk:
                    res = db.execute(text("""
                        UPDATE weather_data
                        SET precipitation_sum = :precip,
                            cloud_cover_mean = :cloud,
                            relative_humidity_mean = :hum
                        WHERE date = :d
                          AND province_name = :p_
                          AND district_name = :dist
                    """), r)
                    updated += res.rowcount or 0
                db.commit()
            total_updated += updated

            if i % 10 == 0 or i <= 5:
                print(f"  [{i}/{len(locs)}] {prov}|{dist}: "
                      f"{len(dates)} gün, {updated} satır güncellendi")

    print("\n" + "=" * 64)
    print(f"  BİTTİ — toplam {total_updated} satır güncellendi, "
          f"{skipped} lokasyon atlandı (dolu)")
    print("=" * 64)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--province", default=None, help="Tek il filtresi")
    p.add_argument("--start", default="2015-12-31",
                   help="weather_data ile uyumlu başlangıç")
    p.add_argument("--end", default=date.today().isoformat(),
                   help="Bitiş tarihi (bugün default)")
    p.add_argument("--no-skip-existing", action="store_true",
                   help="Zaten dolu olan lokasyonları da tekrar çek")
    args = p.parse_args()
    main(province_filter=args.province,
         start_date=args.start, end_date=args.end,
         skip_existing=not args.no_skip_existing)

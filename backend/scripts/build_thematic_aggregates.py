r"""Ağır tematik harita pencereleri — aylık precompute batch (2026-05-28).

`sixMonth / yearly / season / twoYear / fiveYear / tenYear` modları her istekte
hesaplanmaz; bu batch ayda bir çalışıp `thematic_aggregate` tablosunu doldurur.
choropleth endpoint buradan anında okur.

**Veri kaynağı:** `weather_data` (günlük, 2015→bugün, 10+ yıl). Uzun pencereler
doğal olarak günlük arşivden beslenir. Kısa modlar (current/week/month/threeMonth)
bu batch'e dahil DEĞİL — onlar canlı `hourly_weather_data`'dan hesaplanır.

**Metrikler:** wind (wind_speed_mean), solar (shortwave_radiation_sum),
temp (temperature_mean).

**Kullanım:**

    cd backend
    ..\.venv\Scripts\python.exe scripts\build_thematic_aggregates.py
    ..\.venv\Scripts\python.exe scripts\build_thematic_aggregates.py --only-province

Plan: PLAN-2026-05-28-ML-CLIMATE-PROJECTION.md (T sprint)
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime, timedelta

try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# mode → gün penceresi (time_window.MODE_DAYS ile uyumlu, precompute alt kümesi)
MODE_DAYS = {
    "sixMonth": 180,
    "yearly": 365,
    "twoYear": 730,
    "fiveYear": 1825,
    "tenYear": 3650,
}
SEASON_MONTHS = {
    "winter": [12, 1, 2],
    "spring": [3, 4, 5],
    "summer": [6, 7, 8],
    "autumn": [9, 10, 11],
}

# metric → weather_data (günlük) kolonu
METRIC_COLS_DAILY = {
    "wind": "wind_speed_mean",
    "solar": "shortwave_radiation_sum",
    "temp": "temperature_mean",
}
# metric → hourly_weather_data (saatlik) kolonu
METRIC_COLS_HOURLY = {
    "wind": "wind_speed_100m",
    "solar": "shortwave_radiation",
    "temp": "temperature_2m",
}

# Veri kaynağı eşiği: ≤730 gün (≤2 yıl) → saatlik (yakın dönem, city_name dolu),
# >730 gün → günlük arşiv (weather_data, eski province_name dolu).
# Kullanıcı kuralı: "yakın saatlik, eski günlük".
HOURLY_MAX_DAYS = 730


def _aggregate_daily(db, scope: str, start, end, months):
    """weather_data (günlük) → 3 metrik AVG. {location_key: {wind,solar,temp,n}}"""
    from sqlalchemy import text

    group = "province_name" if scope == "province" else "province_name, district_name"
    where = ["date >= :start", "date <= :end", "province_name IS NOT NULL"]
    if scope == "district":
        where.append("district_name IS NOT NULL")
    if months:
        where.append("EXTRACT(MONTH FROM date) = ANY(:months)")
    where_sql = " AND ".join(where)

    sql = text(f"""
        SELECT {group},
               AVG(wind_speed_mean)         AS wind,
               AVG(shortwave_radiation_sum) AS solar,
               AVG(temperature_mean)        AS temp,
               COUNT(*)                     AS n
        FROM weather_data
        WHERE {where_sql}
        GROUP BY {group}
    """)
    params = {"start": start, "end": end}
    if months:
        params["months"] = list(months)
    return _rows_to_map(db.execute(sql, params).fetchall(), scope)


def _aggregate_hourly(db, scope: str, start, end, months):
    """hourly_weather_data (saatlik) → 3 metrik AVG. city_name/district_name."""
    from sqlalchemy import text

    group = "city_name" if scope == "province" else "city_name, district_name"
    where = ["timestamp >= :start", "timestamp <= :end", "city_name IS NOT NULL"]
    if scope == "district":
        where.append("district_name IS NOT NULL")
    if months:
        where.append("EXTRACT(MONTH FROM timestamp) = ANY(:months)")
    where_sql = " AND ".join(where)

    sql = text(f"""
        SELECT {group},
               AVG(wind_speed_100m)    AS wind,
               AVG(shortwave_radiation) AS solar,
               AVG(temperature_2m)     AS temp,
               COUNT(*)                AS n
        FROM hourly_weather_data
        WHERE {where_sql}
        GROUP BY {group}
    """)
    params = {"start": start, "end": end}
    if months:
        params["months"] = list(months)
    return _rows_to_map(db.execute(sql, params).fetchall(), scope)


def _rows_to_map(rows, scope):
    out = {}
    for r in rows:
        if scope == "province":
            key = r[0]
            wind, solar, temp, n = r[1], r[2], r[3], r[4]
        else:
            if not r[1]:
                continue
            key = f"{r[0]}|{r[1]}"
            wind, solar, temp, n = r[2], r[3], r[4], r[5]
        out[key] = {
            "wind": float(wind) if wind is not None else None,
            "solar": float(solar) if solar is not None else None,
            "temp": float(temp) if temp is not None else None,
            "n": int(n),
        }
    return out


def main(only_province: bool, dry_run: bool) -> None:
    from app.db.database import SystemSessionLocal
    from app.db.models import ThematicAggregate
    from sqlalchemy.dialects.postgresql import insert as pg_insert

    print("=" * 64)
    print("  Tematik Agregat Precompute (T-3)")
    print(f"  only_province={only_province} · dry_run={dry_run}")
    print("=" * 64)

    now = datetime.now()
    include_district = not only_province

    # (mode, season, days, months) varyantları
    variants = []
    for mode, days in MODE_DAYS.items():
        variants.append((mode, "-", days, None))
    for season, months in SEASON_MONTHS.items():
        variants.append(("season", season, 365, months))

    def _aggregate(db, scope, start, end, months):
        """Kaynak seçimi: ≤2 yıl saatlik, >2 yıl günlük; saatlik boşsa günlüğe düş."""
        days = (end - start).days
        use_hourly = days <= HOURLY_MAX_DAYS
        src = "hourly" if use_hourly else "daily"
        agg = (_aggregate_hourly(db, scope, start, end, months)
               if use_hourly
               else _aggregate_daily(db, scope, start, end, months))
        if not agg and use_hourly:
            agg = _aggregate_daily(db, scope, start, end, months)
            src = "daily"
        return agg, src

    written = 0
    with SystemSessionLocal() as db:
        # Kanonik ilçe listesi (en zengin kaynak = saatlik, 1277 ilçe).
        # Uzun pencerelerde günlük veride olmayan ilçeleri il değeriyle dolduracağız
        # (siyah delik önleme).
        canonical = []  # [(province, district)]
        if include_district:
            from sqlalchemy import text
            crows = db.execute(text(
                "SELECT DISTINCT city_name, district_name FROM hourly_weather_data "
                "WHERE city_name IS NOT NULL AND district_name IS NOT NULL"
            )).fetchall()
            canonical = [(r[0], r[1]) for r in crows]
            print(f"Kanonik ilçe sayısı: {len(canonical)}\n")

        for mode, season, days, months in variants:
            start = now - timedelta(days=days)
            # İl agregatı (hem province scope hem ilçe-fallback için)
            prov_agg, src = _aggregate(db, "province", start, now, months)
            rows = []
            for key, m in prov_agg.items():
                for metric in ("wind", "solar", "temp"):
                    rows.append({
                        "scope": "province", "location_key": key,
                        "metric": metric, "mode": mode, "season": season,
                        "value": round(m[metric], 4) if m[metric] is not None else None,
                        "sample_count": m["n"], "source": src,
                    })

            # İl fallback için alias-normalize lookup (saatlik city_name vs
            # günlük province_name isim farkını köprüle).
            from app.services.province_aliases import province_aliases
            prov_lookup = {}
            for pname, pm in prov_agg.items():
                prov_lookup[pname] = pm
                try:
                    for variant in province_aliases(pname):
                        prov_lookup.setdefault(variant, pm)
                except Exception:
                    pass

            dist_count = 0
            fill_count = 0
            miss_count = 0
            if include_district:
                dist_agg, dsrc = _aggregate(db, "district", start, now, months)
                dist_count = len(dist_agg)
                # Kanonik her ilçe için: kendi verisi yoksa il değerini kullan
                for prov, dist in canonical:
                    dkey = f"{prov}|{dist}"
                    m = dist_agg.get(dkey)
                    if m is not None:
                        rsrc, n = dsrc, m["n"]
                        vals = m
                    else:
                        # İl fallback (siyah delik önleme) — alias destekli
                        pm = prov_lookup.get(prov)
                        if pm is None:
                            miss_count += 1
                            continue
                        vals = pm
                        rsrc = f"{src}_prov_fallback"
                        n = 0
                        fill_count += 1
                    for metric in ("wind", "solar", "temp"):
                        rows.append({
                            "scope": "district", "location_key": dkey,
                            "metric": metric, "mode": mode, "season": season,
                            "value": round(vals[metric], 4) if vals[metric] is not None else None,
                            "sample_count": n, "source": rsrc,
                        })

            if not dry_run and rows:
                CHUNK = 1000
                for i in range(0, len(rows), CHUNK):
                    chunk = rows[i:i + CHUNK]
                    stmt = pg_insert(ThematicAggregate.__table__).values(chunk)
                    stmt = stmt.on_conflict_do_update(
                        constraint="uq_thematic_aggregate_key",
                        set_={
                            "value": stmt.excluded.value,
                            "sample_count": stmt.excluded.sample_count,
                            "source": stmt.excluded.source,
                            "computed_at": now,
                        },
                    )
                    db.execute(stmt)
                db.commit()
            written += len(rows)
            print(f"  {mode:9s} {season:7s} [{src:6s}] → il {len(prov_agg)}, "
                  f"ilçe {dist_count} gerçek + {fill_count} fallback "
                  f"({miss_count} eşleşmedi), {len(rows)} satır")

    print("\n" + "=" * 64)
    print(f"  BİTTİ — {written} satır {'(dry-run)' if dry_run else 'yazıldı'}")
    print("=" * 64)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--only-province", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    main(only_province=args.only_province, dry_run=args.dry_run)

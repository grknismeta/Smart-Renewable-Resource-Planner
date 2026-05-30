r"""Zaman simülasyonu uzun pencere frame precompute (T-6, 2026-05-28).

2y/5y/10y haftalık/aylık zaman simülasyonu için her hafta/ay başına bir frame
değeri önceden hesaplar → `thematic_timeseries` tablosu. Animasyon her istekte
milyonlarca satır taramaz.

**Kaynak:** `weather_data` (günlük, 2015→bugün) — birim tutarlılığı için TEK
kaynak (hourly/daily karışımı animasyonda zıplama yaratırdı). Recent ~1 yıl
province_name backfill boşluğu olabilir (ayrı veri işi); o frame'ler seyrek.

**Kapsam:**
  - monthly: il + ilçe (10 yıl ≈ 120 frame)
  - weekly : sadece il (10 yıl ≈ 520 frame; ilçe×haftalık çok ağır + animasyon
             için pratik değil)

**Metrikler:** wind (wind_speed_mean), solar (shortwave_radiation_sum),
temp (temperature_mean).

**Kullanım:**

    cd backend
    ..\.venv\Scripts\python.exe scripts\build_thematic_timeseries.py
    ..\.venv\Scripts\python.exe scripts\build_thematic_timeseries.py --years 10

Plan: PLAN-2026-05-28-ML-CLIMATE-PROJECTION.md (T-6)
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

METRIC_COLS = {
    "wind": "wind_speed_mean",
    "solar": "shortwave_radiation_sum",
    "temp": "temperature_mean",
}


def _fetch(db, scope: str, period_type: str, start):
    """date_trunc ile tek sorgu — (location, period, wind, solar, temp)."""
    from sqlalchemy import text

    trunc = "month" if period_type == "month" else "week"
    if scope == "province":
        loc_select = "province_name"
        loc_group = "province_name"
    else:
        loc_select = "province_name, district_name"
        loc_group = "province_name, district_name"

    where = ["date >= :start", "province_name IS NOT NULL"]
    if scope == "district":
        where.append("district_name IS NOT NULL")
    where_sql = " AND ".join(where)

    sql = text(f"""
        SELECT {loc_select},
               date_trunc('{trunc}', date)::date AS period_start,
               AVG(wind_speed_mean)         AS wind,
               AVG(shortwave_radiation_sum) AS solar,
               AVG(temperature_mean)        AS temp
        FROM weather_data
        WHERE {where_sql}
        GROUP BY {loc_group}, date_trunc('{trunc}', date)
    """)
    rows = db.execute(sql, {"start": start}).fetchall()

    out = []  # (location_key, period_start, {wind,solar,temp})
    for r in rows:
        if scope == "province":
            key = r[0]
            ps, wind, solar, temp = r[1], r[2], r[3], r[4]
        else:
            if not r[1]:
                continue
            key = f"{r[0]}|{r[1]}"
            ps, wind, solar, temp = r[2], r[3], r[4], r[5]
        out.append((key, ps, {
            "wind": float(wind) if wind is not None else None,
            "solar": float(solar) if solar is not None else None,
            "temp": float(temp) if temp is not None else None,
        }))
    return out


def main(years: int, dry_run: bool) -> None:
    from app.db.database import SystemSessionLocal
    from app.db.models import ThematicTimeseries
    from sqlalchemy.dialects.postgresql import insert as pg_insert

    print("=" * 64)
    print("  Tematik Zaman-Serisi Precompute (T-6)")
    print(f"  years={years} · dry_run={dry_run}")
    print("=" * 64)

    start = datetime.now() - timedelta(days=years * 365 + 30)

    # (scope, period_type)
    plan = [
        ("province", "month"),
        ("district", "month"),
        ("province", "week"),
    ]

    written = 0
    with SystemSessionLocal() as db:
        for scope, period_type in plan:
            data = _fetch(db, scope, period_type, start)
            rows = []
            for key, ps, m in data:
                for metric in ("wind", "solar", "temp"):
                    v = m[metric]
                    rows.append({
                        "scope": scope,
                        "location_key": key,
                        "metric": metric,
                        "period_type": period_type,
                        "period_start": ps,
                        "value": round(v, 4) if v is not None else None,
                        "source": "daily",
                    })
            if not dry_run and rows:
                CHUNK = 2000
                for i in range(0, len(rows), CHUNK):
                    chunk = rows[i:i + CHUNK]
                    stmt = pg_insert(ThematicTimeseries.__table__).values(chunk)
                    stmt = stmt.on_conflict_do_update(
                        constraint="uq_thematic_timeseries_key",
                        set_={
                            "value": stmt.excluded.value,
                            "source": stmt.excluded.source,
                            "computed_at": datetime.now(),
                        },
                    )
                    db.execute(stmt)
                db.commit()
            written += len(rows)
            periods = len({ps for _, ps, _ in data})
            locs = len({k for k, _, _ in data})
            print(f"  [{scope:8s}] {period_type:5s} → {locs} lokasyon × "
                  f"{periods} dönem = {len(rows)} satır")

    print("\n" + "=" * 64)
    print(f"  BİTTİ — {written} satır {'(dry-run)' if dry_run else 'yazıldı'}")
    print("=" * 64)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--years", type=int, default=10)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    main(years=max(1, min(10, args.years)), dry_run=args.dry_run)

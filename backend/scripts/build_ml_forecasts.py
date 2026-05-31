r"""Sprint M-A.4 — ML forecast batch precompute (2026-05-28).

Tüm il + ilçe × metrik × senaryo kombinasyonları için en iyi modeli seçer,
RCP senaryo deltalarını uygular ve `ml_forecast` tablosuna yazar. Tematik
harita + Projeksiyon tab bu tablodan anında okur.

**Kullanım:**

    cd backend
    ..\.venv\Scripts\python.exe scripts\build_ml_forecasts.py
    ..\.venv\Scripts\python.exe scripts\build_ml_forecasts.py --years 10 --only-province
    ..\.venv\Scripts\python.exe scripts\build_ml_forecasts.py --province Konya

Aylık çözünürlük. "Günlük hava" DEĞİL — iklim normali + trend + RCP senaryo.
Plan: PLAN-2026-05-28-ML-CLIMATE-PROJECTION.md
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import date

try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Kaynak → hesaplanacak metrikler (frontend ile uyumlu)
RESOURCE_METRICS = {
    "solar": ["sunshine", "cloud"],
    "wind": ["cloud", "precipitation"],
    "hydro": ["discharge", "precipitation"],
}

SCENARIOS = ["baseline", "rcp45", "rcp85"]


def _distinct_locations(db, only_province: bool, province_filter):
    """climatology'den (province, district, resource) kombinasyonları."""
    from app.db.models import Climatology
    q = db.query(
        Climatology.province_name,
        Climatology.district_name,
        Climatology.resource_type,
    )
    if only_province:
        q = q.filter(Climatology.district_name.is_(None))
    if province_filter:
        from app.services.province_aliases import province_aliases
        q = q.filter(Climatology.province_name.in_(province_aliases(province_filter)))
    return q.distinct().all()


def _distinct_locations_daily(db, only_province: bool, province_filter):
    """weather_data günlük tablosundan (province, district) — ilçe + il daily ML.

    weather_data'da il-seviyesi satır YOK (district_name hep dolu), o yüzden
    her il için (province, None) sentetik scope eklenir (province aggregate
    get_monthly_series_from_daily ile zaten elde edilir).
    """
    from app.db.models import WeatherData
    q = db.query(
        WeatherData.province_name,
        WeatherData.district_name,
    ).filter(WeatherData.province_name.isnot(None),
             WeatherData.district_name.isnot(None))
    if province_filter:
        from app.services.province_aliases import province_aliases
        q = q.filter(WeatherData.province_name.in_(province_aliases(province_filter)))
    rows = q.distinct().all()

    out = []
    provinces_seen = set()
    if not only_province:
        # İlçe satırları (1003 kombinasyon)
        for p, d in rows:
            out.append((p, d, "solar"))
            provinces_seen.add(p)
    else:
        provinces_seen = {p for p, _ in rows}
    # Her il için sentetik (province, None) — il-seviyesi forecast
    for p in sorted(provinces_seen):
        out.append((p, None, "solar"))
    return out

# Daily mode: hangi resource hangi metric'i besler
DAILY_RESOURCE_METRICS = {
    "solar": ["sunshine"],  # weather_data shortwave_radiation_sum
}


def main(years: int, only_province: bool, province_filter, dry_run: bool,
         use_daily: bool = False) -> None:
    from app.db.database import SystemSessionLocal
    from app.db.models import MlForecast
    from app.services.ml_batch_service import (
        get_monthly_series,
        get_monthly_series_best,
        select_best_monthly_forecast,
    )
    from app.services.climate_scenarios import scenario_factor
    from sqlalchemy.dialects.postgresql import insert as pg_insert

    print("=" * 64)
    print("  ML Forecast Batch Precompute (M-A.4)")
    print(f"  horizon={years}y · only_province={only_province} · "
          f"province={province_filter or 'ALL'} · dry_run={dry_run} · "
          f"use_daily={use_daily}")
    print("=" * 64)

    start_year = date.today().year
    horizon = years * 12

    written = 0
    skipped = 0
    loc_count = 0

    resource_metrics = DAILY_RESOURCE_METRICS if use_daily else RESOURCE_METRICS

    with SystemSessionLocal() as db:
        if use_daily:
            locations = _distinct_locations_daily(db, only_province, province_filter)
            print(f"DAILY mode — Toplam {len(locations)} (il/ilçe × kaynak)\n")
        else:
            locations = _distinct_locations(db, only_province, province_filter)
            print(f"Toplam {len(locations)} (il/ilçe × kaynak) kombinasyonu.\n")

        for prov, district, resource in locations:
            if resource not in resource_metrics:
                continue
            scope = "province" if district is None else "district"
            for metric in resource_metrics[resource]:
                if use_daily:
                    # İl-scope'ta monthly_climate (20y, ~257 ay) tercih edilir;
                    # ilçede daily aggregate. (get_monthly_series_best yönetir.)
                    series, series_start = get_monthly_series_best(
                        prov, district, metric,
                    )
                    if series and series_start:
                        start_date = date(series_start.year, series_start.month, 1)
                    else:
                        start_date = date(start_year, 1, 1)
                else:
                    series = get_monthly_series(prov, district, resource, metric)
                    start_date = date(start_year - 5, 1, 1)
                if not series:
                    skipped += 1
                    continue

                label = f"{prov}_{district or '-'}_{resource}_{metric}"
                try:
                    values, lowers, uppers, method, mape = \
                        select_best_monthly_forecast(
                            series, start_date, horizon, label,
                        )
                except Exception as e:
                    print(f"  X {label}: {e}")
                    skipped += 1
                    continue

                loc_count += 1
                rows = []
                for i, v in enumerate(values):
                    d = date(start_year + (i // 12), (i % 12) + 1, 1)
                    year_offset = d.year - start_year
                    for scenario in SCENARIOS:
                        factor = scenario_factor(scenario, metric, year_offset)
                        rows.append({
                            "scope": scope,
                            "province_name": prov,
                            "district_name": district,
                            "resource": resource,
                            "metric": metric,
                            "scenario": scenario,
                            "year": d.year,
                            "month": d.month,
                            "value": round(v * factor, 4),
                            "lower": round((lowers[i] or v) * factor, 4),
                            "upper": round((uppers[i] or v) * factor, 4),
                            "method": method,
                            "mape": mape,
                        })

                if dry_run:
                    written += len(rows)
                    continue

                # Upsert (conflict = unique key → güncelle)
                stmt = pg_insert(MlForecast.__table__).values(rows)
                stmt = stmt.on_conflict_do_update(
                    constraint="uq_ml_forecast_key",
                    set_={
                        "value": stmt.excluded.value,
                        "lower": stmt.excluded.lower,
                        "upper": stmt.excluded.upper,
                        "method": stmt.excluded.method,
                        "mape": stmt.excluded.mape,
                        "computed_at": date.today(),
                    },
                )
                db.execute(stmt)
                db.commit()
                written += len(rows)

            if loc_count and loc_count % 25 == 0:
                print(f"  ... {loc_count} seri işlendi, {written} satır yazıldı")

    print("\n" + "=" * 64)
    print(f"  BİTTİ — {loc_count} seri, {written} satır {'(dry-run)' if dry_run else 'yazıldı'}, "
          f"{skipped} atlandı (veri yok)")
    print("=" * 64)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--years", type=int, default=10, help="Forecast ufku (1-10)")
    p.add_argument("--only-province", action="store_true",
                   help="Sadece il bazlı (ilçeleri atla)")
    p.add_argument("--province", default=None, help="Tek il (debug)")
    p.add_argument("--dry-run", action="store_true",
                   help="DB'ye yazma, sadece say")
    p.add_argument("--use-daily", action="store_true",
                   help="weather_data günlük tablosundan ilçe daily aggregate "
                        "kullan (M-F: ilçe ML)")
    args = p.parse_args()
    main(
        years=max(1, min(10, args.years)),
        only_province=args.only_province,
        province_filter=args.province,
        dry_run=args.dry_run,
        use_daily=args.use_daily,
    )

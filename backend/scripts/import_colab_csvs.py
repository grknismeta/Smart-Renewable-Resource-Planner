r"""R0 Colab CSV'lerini climatology tablosuna import et (2026-05-20).

4 CSV dosyasını okur, ilçe granüler agrege eder, climatology'nin
yeni JSON kolonlarına (Migration 016) yazar:

- `wind_direction_histogram.csv`  → climatology.wind_direction_histogram
- `monthly_cloud_cover.csv`       → climatology.monthly_cloud_cover
- `climate_monthly.csv`           → climatology.monthly_precipitation
                                    + climatology.monthly_sunshine_hours
- `river_discharge_monthly.csv`   → climatology.monthly_river_discharge

İlçe satırları (`district_name IS NOT NULL`) için tek tek import edilir.
İl bazlı satırlar (`district_name IS NULL`) için ilçelerin **ortalaması**
alınır (ASCII fold + alias ile match).

**Kullanım:**

    cd backend
    # CSV'leri colab/ klasörüne koy (default), veya --csv-dir ile belirt
    .\venv\Scripts\python.exe scripts\import_colab_csvs.py
    .\venv\Scripts\python.exe scripts\import_colab_csvs.py --dry-run
    .\venv\Scripts\python.exe scripts\import_colab_csvs.py --csv-dir D:\indirilenler

CSV bulunamazsa o veri kümesi atlanır (eksik sprintler için kabul edilebilir).
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional

# Repo root'tan başlat
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import pandas as pd  # noqa: E402

from app.db.database import SystemSessionLocal  # noqa: E402
from app.db.models import Climatology  # noqa: E402
from app.services.climatology_service import _tr_ascii_fold  # noqa: E402
from app.services.province_aliases import province_aliases  # noqa: E402

DEFAULT_CSV_DIR = Path(__file__).resolve().parent.parent.parent / "colab"

CSV_FILES = {
    "wind_hist": "wind_direction_histogram.csv",
    "cloud": "monthly_cloud_cover.csv",
    "climate": "climate_monthly.csv",
    "discharge": "river_discharge_monthly.csv",
}


# ── Helper: il+ilçe → climatology row(s) ──────────────────────────────────────

def _find_climatology_rows(
    db, province: str, district: Optional[str]
) -> List[Climatology]:
    """Climatology'deki ilgili satırları bul.

    Aynı il+ilçe için 3 satır var (wind/solar/hydro). Hepsine aynı JSON
    yazılacak (çünkü iklim verisi kaynak tipinden bağımsız).

    province_aliases ile DB'deki ASCII fold + alias varyasyonlarını dene.
    """
    variants = province_aliases(province)
    q = db.query(Climatology).filter(Climatology.province_name.in_(variants))
    if district:
        district_variants = [district, _tr_ascii_fold(district)]
        q = q.filter(Climatology.district_name.in_(district_variants))
    else:
        q = q.filter(Climatology.district_name.is_(None))
    return q.all()


# ── 1. Wind Direction Histogram (A scripti) ──────────────────────────────────

def import_wind_histogram(db, csv_path: Path, dry_run: bool) -> Dict[str, int]:
    """wind_direction_histogram.csv → wind_direction_histogram JSON.

    CSV satırı: province, district, month (0-12), direction (N..NW), freq_pct
    Hedef JSON: {"0": {"N": pct, "NE": pct, ...}, "1": {...}, ..., "12": {...}}
    """
    if not csv_path.exists():
        print(f"  [SKIP] {csv_path.name} yok")
        return {"missing": 1}

    df = pd.read_csv(csv_path)
    print(f"  Okundu: {len(df):,} satır")

    # (province, district) bazlı grupla
    grouped = df.groupby(["province", "district"])
    matched = unmatched = updated = 0

    for (province, district), sub in grouped:
        # Build JSON: {"0": {"N": .., ...}, "1": {...}, ...}
        histogram: Dict[str, Dict[str, float]] = {}
        for month, mrows in sub.groupby("month"):
            histogram[str(int(month))] = {
                row["direction"]: float(row["freq_pct"])
                for _, row in mrows.iterrows()
            }

        rows = _find_climatology_rows(db, province, district)
        if not rows:
            unmatched += 1
            continue
        matched += 1
        for r in rows:
            r.wind_direction_histogram = histogram
            updated += 1

    # İl bazlı (district_name IS NULL) için ilçelerin ortalaması
    province_groups = df.groupby("province")
    for province, sub in province_groups:
        # Her (month, direction) için ortalama freq
        avg = sub.groupby(["month", "direction"])["freq_pct"].mean().reset_index()
        histogram: Dict[str, Dict[str, float]] = {}
        for month, mrows in avg.groupby("month"):
            histogram[str(int(month))] = {
                row["direction"]: round(float(row["freq_pct"]), 2)
                for _, row in mrows.iterrows()
            }
        # district=None satırlarına yaz
        rows = _find_climatology_rows(db, province, None)
        for r in rows:
            r.wind_direction_histogram = histogram
            updated += 1

    if not dry_run:
        db.commit()
    return {"matched": matched, "unmatched": unmatched, "updated": updated}


# ── 2. Monthly Cloud Cover (A scripti) ───────────────────────────────────────

def import_cloud_cover(db, csv_path: Path, dry_run: bool) -> Dict[str, int]:
    """monthly_cloud_cover.csv → monthly_cloud_cover JSON.

    CSV satırı: province, district, month (1-12), cloud_cover_pct
    Hedef JSON: [jan_pct, feb_pct, ..., dec_pct] — 12 değer
    """
    if not csv_path.exists():
        print(f"  [SKIP] {csv_path.name} yok")
        return {"missing": 1}

    df = pd.read_csv(csv_path)
    print(f"  Okundu: {len(df):,} satır")

    matched = unmatched = updated = 0
    for (province, district), sub in df.groupby(["province", "district"]):
        monthly = [None] * 12
        for _, row in sub.iterrows():
            monthly[int(row["month"]) - 1] = round(float(row["cloud_cover_pct"]), 2)

        rows = _find_climatology_rows(db, province, district)
        if not rows:
            unmatched += 1
            continue
        matched += 1
        for r in rows:
            r.monthly_cloud_cover = monthly
            updated += 1

    # İl bazlı ortalama
    for province, sub in df.groupby("province"):
        avg = sub.groupby("month")["cloud_cover_pct"].mean()
        monthly = [round(float(avg.get(m, 0)), 2) for m in range(1, 13)]
        for r in _find_climatology_rows(db, province, None):
            r.monthly_cloud_cover = monthly
            updated += 1

    if not dry_run:
        db.commit()
    return {"matched": matched, "unmatched": unmatched, "updated": updated}


# ── 3. Climate Monthly (B scripti) — precipitation + sunshine ────────────────

def import_climate_monthly(db, csv_path: Path, dry_run: bool) -> Dict[str, int]:
    """climate_monthly.csv → monthly_precipitation + monthly_sunshine_hours JSON.

    CSV satırı: province, district, year (2015-2024), month (1-12),
                precip_mm, sunshine_hours_month
    Hedef JSON: [jan, ..., dec] — 12 değer (10 yıl ortalaması)
    """
    if not csv_path.exists():
        print(f"  [SKIP] {csv_path.name} yok")
        return {"missing": 1}

    df = pd.read_csv(csv_path)
    print(f"  Okundu: {len(df):,} satır")

    # 10 yıl ortalama: (province, district, month) → mean
    agg = df.groupby(["province", "district", "month"]).agg(
        precip_avg=("precip_mm", "mean"),
        sunshine_avg=("sunshine_hours_month", "mean"),
    ).reset_index()

    matched = unmatched = updated = 0
    for (province, district), sub in agg.groupby(["province", "district"]):
        precip = [None] * 12
        sunshine = [None] * 12
        for _, row in sub.iterrows():
            m = int(row["month"]) - 1
            precip[m] = round(float(row["precip_avg"]), 1)
            sunshine[m] = round(float(row["sunshine_avg"]), 0)

        rows = _find_climatology_rows(db, province, district)
        if not rows:
            unmatched += 1
            continue
        matched += 1
        for r in rows:
            r.monthly_precipitation = precip
            r.monthly_sunshine_hours = sunshine
            updated += 1

    # İl bazlı (ilçe ortalamasından)
    province_agg = df.groupby(["province", "month"]).agg(
        precip_avg=("precip_mm", "mean"),
        sunshine_avg=("sunshine_hours_month", "mean"),
    ).reset_index()
    for province, sub in province_agg.groupby("province"):
        precip = [None] * 12
        sunshine = [None] * 12
        for _, row in sub.iterrows():
            m = int(row["month"]) - 1
            precip[m] = round(float(row["precip_avg"]), 1)
            sunshine[m] = round(float(row["sunshine_avg"]), 0)
        for r in _find_climatology_rows(db, province, None):
            r.monthly_precipitation = precip
            r.monthly_sunshine_hours = sunshine
            updated += 1

    if not dry_run:
        db.commit()
    return {"matched": matched, "unmatched": unmatched, "updated": updated}


# ── 4. River Discharge (C scripti) ───────────────────────────────────────────

def import_river_discharge(db, csv_path: Path, dry_run: bool) -> Dict[str, int]:
    """river_discharge_monthly.csv → monthly_river_discharge JSON.

    CSV satırı: province, district, year, month, discharge_mean/min/max_m3s
    Hedef JSON: [{"mean": .., "min": .., "max": ..}, × 12]
    """
    if not csv_path.exists():
        print(f"  [SKIP] {csv_path.name} yok")
        return {"missing": 1}

    df = pd.read_csv(csv_path)
    print(f"  Okundu: {len(df):,} satır")

    # 10 yıl ortalama
    agg = df.groupby(["province", "district", "month"]).agg(
        mean=("discharge_mean_m3s", "mean"),
        min=("discharge_min_m3s", "mean"),  # min of monthly means
        max=("discharge_max_m3s", "mean"),
    ).reset_index()

    matched = unmatched = updated = 0
    for (province, district), sub in agg.groupby(["province", "district"]):
        monthly: List[Dict] = [{}] * 12
        for _, row in sub.iterrows():
            m = int(row["month"]) - 1
            monthly[m] = {
                "mean": round(float(row["mean"]), 3),
                "min": round(float(row["min"]), 3),
                "max": round(float(row["max"]), 3),
            }
        # Boş ay varsa None
        monthly = [m if m else None for m in monthly]

        rows = _find_climatology_rows(db, province, district)
        if not rows:
            unmatched += 1
            continue
        matched += 1
        for r in rows:
            r.monthly_river_discharge = monthly
            updated += 1

    # İl bazlı
    province_agg = df.groupby(["province", "month"]).agg(
        mean=("discharge_mean_m3s", "mean"),
        min=("discharge_min_m3s", "mean"),
        max=("discharge_max_m3s", "mean"),
    ).reset_index()
    for province, sub in province_agg.groupby("province"):
        monthly: List[Dict] = [None] * 12
        for _, row in sub.iterrows():
            m = int(row["month"]) - 1
            monthly[m] = {
                "mean": round(float(row["mean"]), 3),
                "min": round(float(row["min"]), 3),
                "max": round(float(row["max"]), 3),
            }
        for r in _find_climatology_rows(db, province, None):
            r.monthly_river_discharge = monthly
            updated += 1

    if not dry_run:
        db.commit()
    return {"matched": matched, "unmatched": unmatched, "updated": updated}


# ── Main ──────────────────────────────────────────────────────────────────────

def main(csv_dir: Path, dry_run: bool) -> None:
    print(f"{'=' * 60}")
    print(f"R0 CSV -> climatology import {'(DRY RUN)' if dry_run else ''}")
    print(f"CSV dizini: {csv_dir}")
    print(f"{'=' * 60}\n")

    with SystemSessionLocal() as db:
        for label, fn in CSV_FILES.items():
            csv_path = csv_dir / fn
            print(f"[{label}] {csv_path.name}")
            if label == "wind_hist":
                stats = import_wind_histogram(db, csv_path, dry_run)
            elif label == "cloud":
                stats = import_cloud_cover(db, csv_path, dry_run)
            elif label == "climate":
                stats = import_climate_monthly(db, csv_path, dry_run)
            elif label == "discharge":
                stats = import_river_discharge(db, csv_path, dry_run)
            print(f"  -> {stats}\n")

    print("OK Tamamlandi." + (" (commit edilmedi)" if dry_run else ""))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--csv-dir",
        type=Path,
        default=DEFAULT_CSV_DIR,
        help=f"CSV klasörü (default: {DEFAULT_CSV_DIR})",
    )
    parser.add_argument("--dry-run", "-n", action="store_true", help="Commit etme")
    args = parser.parse_args()
    main(args.csv_dir, args.dry_run)

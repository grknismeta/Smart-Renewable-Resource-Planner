"""Climatology province naming canonical fix (2026-05-24).

Climatology'de tarihsel olarak aynı il iki farklı formatta birikti:
    "Balıkesir" (Türkçe) + "Balikesir" (ASCII fold) → 2 ayrı satır
İmport script bir versiyona yazıyor, diğeri NULL kalıyor → UI'da
"mock fallback" görünüyor. Bu script climatology'yi temizler:

1. Her ASCII satır için → Türkçe canonical karşılığı var mı?
   a. VARSA: ASCII satırının JSON kolonlarındaki dolu verileri Türkçe'ye
      MERGE et (NULL alanlar için), ASCII satırını SİL.
   b. YOKSA: ASCII satırını Türkçe'ye RENAME (province_name UPDATE).
2. Sonuç: 81 il × 3 kaynak = 243 satır, hepsi Türkçe canonical.

Kullanım:
    cd backend
    .\\venv\\Scripts\\python.exe scripts\\dedup_climatology.py --dry-run
    .\\venv\\Scripts\\python.exe scripts\\dedup_climatology.py
"""
from __future__ import annotations

import argparse
import os
import sys
from typing import Dict, List

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.db.database import SystemSessionLocal  # noqa: E402
from app.db.models import Climatology  # noqa: E402
from app.services.province_aliases import _ASCII_TO_TR  # noqa: E402

# Climatology'nin canonical Türkçe'ye taşınacak JSON + skalar alanları
_MERGE_FIELDS = [
    "avg_wind_speed_10y", "weibull_k", "weibull_c",
    "avg_solar_irradiance_10y", "avg_ghi_wm2",
    "avg_temperature_10y", "seasonal_variance",
    "capacity_factor", "hourly_typical_profile", "score_climatology",
    "wind_direction_histogram", "monthly_precipitation",
    "monthly_cloud_cover", "monthly_sunshine_hours",
    "monthly_river_discharge",
    "sample_count_daily", "sample_count_hourly",
    "data_start_date", "data_end_date",
]


def _merge_into(target: Climatology, source: Climatology) -> List[str]:
    """source'tan target'a — target NULL ise source değerini ata.
    Liste: hangi alanlar merge edildi."""
    merged = []
    for f in _MERGE_FIELDS:
        if getattr(target, f, None) is None and getattr(source, f, None) is not None:
            setattr(target, f, getattr(source, f))
            merged.append(f)
    return merged


def main(dry_run: bool) -> None:
    print(f"{'=' * 60}")
    print(f"Climatology canonical fix {'(DRY RUN)' if dry_run else ''}")
    print(f"{'=' * 60}\n")

    with SystemSessionLocal() as db:
        # Tüm il bazlı satırlar (district_name IS NULL)
        rows = (
            db.query(Climatology)
            .filter(Climatology.district_name.is_(None))
            .all()
        )

        # province_name → resource_type → row map
        by_canonical: Dict[str, Dict[str, Climatology]] = {}
        for r in rows:
            canonical = _ASCII_TO_TR.get(r.province_name, r.province_name)
            by_canonical.setdefault(canonical, {})
            existing = by_canonical[canonical].get(r.resource_type)
            if existing is None:
                by_canonical[canonical][r.resource_type] = r
            else:
                # Aynı (canonical, resource_type) için 2 satır var — DUPLICATE
                # Türkçe olanı tutmaya çalış (yoksa ilk gelen)
                if r.province_name == canonical and existing.province_name != canonical:
                    by_canonical[canonical][r.resource_type] = r

        merged_count = 0
        renamed_count = 0
        deleted_count = 0

        for canonical, by_resource in by_canonical.items():
            for resource_type, primary in by_resource.items():
                # primary = canonical Türkçe satır (ya da tek mevcut)
                # Aynı (canonical, resource_type) için diğer satırları (ASCII)
                # bul ve primary'e merge et + sil
                duplicates = [
                    r for r in rows
                    if r.id != primary.id
                    and _ASCII_TO_TR.get(r.province_name, r.province_name) == canonical
                    and r.resource_type == resource_type
                ]
                for dup in duplicates:
                    merged = _merge_into(primary, dup)
                    print(
                        f"  MERGE {dup.province_name}→{canonical} ({resource_type}): "
                        f"{len(merged)} alan taşındı, sil"
                    )
                    merged_count += len(merged)
                    if not dry_run:
                        db.delete(dup)
                    deleted_count += 1

                # primary ASCII ise Türkçe canonical'a rename
                if primary.province_name != canonical:
                    print(
                        f"  RENAME {primary.province_name}→{canonical} ({resource_type})"
                    )
                    if not dry_run:
                        primary.province_name = canonical
                    renamed_count += 1

        if not dry_run:
            db.commit()

        # Doğrula
        if not dry_run:
            after = (
                db.query(Climatology.province_name)
                .filter(Climatology.district_name.is_(None))
                .distinct()
                .count()
            )
            print(f"\n📊 Sonuç:")
            print(f"  Merge edilen alan: {merged_count}")
            print(f"  Rename edilen satır: {renamed_count}")
            print(f"  Silinen dublike: {deleted_count}")
            print(f"  Distinct il (sonra): {after} (hedef: 81)")
        else:
            print(f"\n📊 DRY RUN özet:")
            print(f"  Merge edilecek alan: {merged_count}")
            print(f"  Rename edilecek satır: {renamed_count}")
            print(f"  Silinecek dublike: {deleted_count}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", "-n", action="store_true")
    main(p.parse_args().dry_run)

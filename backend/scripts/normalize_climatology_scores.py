"""Climatology score'larını kaynak-içi min-max normalize eder (2026-05-25).

**Problem:**
Mevcut `score_climatology` formülü mutlak eşikler kullanıyor (örn. wind 3-9
m/s lineer skala, solar GHI 100-300 W/m²). Türkiye'nin gerçek rüzgar
ortalaması 6+ m/s olduğu için **her wind score 50+** çıkıyor; solar ortalaması
düşük olduğu için **her solar score 30-55 bandında** sıkışıyor. Sonuç:

  - Bölge kartlarında "Güneş her zaman düşük" görünüyor
  - Rüzgar her zaman lider gibi
  - Kullanıcı için yanıltıcı kıyaslama

**Çözüm:**
Her kaynak (solar/wind/hydro) İÇİN ayrı min-max normalize:

    score_normalized = (raw - min_raw) / (max_raw - min_raw) × 100

Böylece her kaynakta en iyi il **100**, en kötü il **0**. Kıyaslama
**adil** olur — Türkiye'nin en güneşli ili 100, en az güneşli 0.

**Genel MW karşılaştırması** için ayrı bir endpoint/tab gerekir (frontend
kullanıcının istediği "ayrı listeleme tuşu"). Şu an estimatedMw alanı
zaten kapasite kıyaslaması veriyor; raw_score raw olarak kalır ve gerekirse
ileride okunur.

**Kullanım:**

    cd backend
    .\\venv\\Scripts\\python.exe scripts\\normalize_climatology_scores.py
    .\\venv\\Scripts\\python.exe scripts\\normalize_climatology_scores.py --dry-run

**Güvenlik:** Mevcut `score_climatology` değerleri **üzerine yazılır**.
Eski raw değer DB'de saklanmıyordu (formül ile yeniden hesaplanabilir),
yine de --dry-run ile önce kontrol et.
"""
from __future__ import annotations

import argparse
import os
import sys
from typing import Dict, List, Tuple

try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.db.database import SystemSessionLocal  # noqa: E402
from app.db.models import Climatology  # noqa: E402


def main(dry_run: bool) -> None:
    print(f"{'=' * 60}")
    print(f"Climatology score normalize {'(DRY-RUN)' if dry_run else ''}")
    print(f"{'=' * 60}\n")

    with SystemSessionLocal() as db:
        rows = (
            db.query(Climatology)
            .filter(
                Climatology.district_name.is_(None),  # sadece il bazlı
                Climatology.score_climatology.isnot(None),
            )
            .all()
        )

        # Kaynak başına grupla
        by_resource: Dict[str, List[Climatology]] = {}
        for r in rows:
            by_resource.setdefault(r.resource_type, []).append(r)  # type: ignore

        print(f"Toplam il bazlı satır: {len(rows)}")
        for resource, items in by_resource.items():
            scores = [float(r.score_climatology) for r in items]  # type: ignore
            if not scores:
                continue
            min_s = min(scores)
            max_s = max(scores)
            span = max_s - min_s
            print(
                f"\n📊 {resource}: {len(items)} il, "
                f"raw aralık [{min_s:.2f} — {max_s:.2f}] (span={span:.2f})"
            )

            if span < 0.01:
                print(f"  ⚠️  Span çok dar — normalize anlamsız, atlanıyor.")
                continue

            # Min-max normalize → 0-100
            updated: List[Tuple[str, float, float]] = []
            for r in items:
                old = float(r.score_climatology)  # type: ignore
                new = (old - min_s) / span * 100
                new = round(new, 2)
                if abs(new - old) > 0.5:
                    updated.append((r.province_name, old, new))  # type: ignore
                if not dry_run:
                    r.score_climatology = new  # type: ignore

            # En çok değişen 5 örnek
            updated.sort(key=lambda x: abs(x[2] - x[1]), reverse=True)
            print(f"  {len(updated)} il güncellendi. Örnek (en büyük 5 değişim):")
            for name, old, new in updated[:5]:
                delta = new - old
                sign = "+" if delta >= 0 else ""
                print(
                    f"    {name:<20s} {old:6.2f} → {new:6.2f} "
                    f"({sign}{delta:.2f})"
                )

        if not dry_run:
            db.commit()
            print(f"\n✅ Commit edildi.")
        else:
            print(f"\n💡 Dry-run: değişiklikler kaydedilmedi.")

        # Doğrulama: yeni dağılım
        if not dry_run:
            print(f"\n🔍 Yeni dağılım:")
            for resource, items in by_resource.items():
                # Refresh edilmiş objeler
                refreshed = (
                    db.query(Climatology)
                    .filter(
                        Climatology.resource_type == resource,
                        Climatology.district_name.is_(None),
                        Climatology.score_climatology.isnot(None),
                    )
                    .all()
                )
                if not refreshed:
                    continue
                scores = [float(r.score_climatology) for r in refreshed]  # type: ignore
                print(
                    f"  {resource}: min={min(scores):.1f}  "
                    f"max={max(scores):.1f}  "
                    f"avg={sum(scores) / len(scores):.1f}"
                )


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", "-n", action="store_true",
                   help="Raporla, değişiklik yapma")
    args = p.parse_args()
    main(dry_run=args.dry_run)

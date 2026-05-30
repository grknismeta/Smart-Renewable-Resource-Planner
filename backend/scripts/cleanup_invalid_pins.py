"""Geçersiz pin temizleme (2026-05-25).

P2/6 frontend validation yeni pin'leri engelliyor — ancak DB'de hâlâ:
  - capacity_mw < 0.001 (≈ 1 kW altı; anlamsız)
  - city NULL (reverse-geocode olmamış, generation kaynak bulamaz)
  - name = "Yeni Kaynak" + capacity ~0 (kullanıcı submit etti ama veri eksikti)

gibi orphan kayıtlar var. Bu script onları:
  - Listeler (--dry-run varsayılan)
  - Opsiyonel olarak siler (--delete)
  - Opsiyonel olarak `fix_existing_pins.py` benzeri capacity yeniden
    hesaplama dener (--fix) — yeniden hesaplandığı halde hâlâ < 0.001 ise sil

**Kullanım:**

    cd backend
    .\\venv\\Scripts\\python.exe scripts\\cleanup_invalid_pins.py
    .\\venv\\Scripts\\python.exe scripts\\cleanup_invalid_pins.py --fix
    .\\venv\\Scripts\\python.exe scripts\\cleanup_invalid_pins.py --delete

**Güvenlik:** --delete olmadan **HİÇBİR** kayıt silinmez. Önce --dry-run ile
ne silineceğini gör.
"""
from __future__ import annotations

import argparse
import os
import sys
from typing import List, Tuple

# Windows console (cp1254) Unicode oklarını encode edemediği için UTF-8'e
# zorla. Aksi halde "→" gibi karakterler UnicodeEncodeError patlar.
try:
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
except Exception:
    pass

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.db.database import UserSessionLocal  # noqa: E402
from app.db.models import Pin  # noqa: E402

MIN_CAPACITY_MW = 0.001  # 1 kW altı = anlamsız


def _classify(pin: Pin) -> List[str]:
    """Pin'in neden 'geçersiz' olduğunu döner — boş liste = geçerli."""
    issues = []
    cap = float(pin.capacity_mw or 0)
    if cap < MIN_CAPACITY_MW:
        issues.append(f"capacity_mw={cap:.4f} (<{MIN_CAPACITY_MW})")
    if not pin.city or not str(pin.city).strip():
        issues.append("city=NULL")
    # Default placeholder name + zero capacity → muhtemelen iptal edilmiş submit
    if (
        (pin.title or "").strip().lower() in ("yeni kaynak", "yeni kaynağı", "")
        and cap < 0.01
    ):
        issues.append("placeholder_name + zero capacity")
    # HES için flow/head zorunlu (P2/6 yeni kural — eski pin'lerde olmayabilir)
    if str(pin.type or "") == "Hidroelektrik":
        flow = float(pin.flow_rate or 0)
        head = float(pin.head_height or 0)
        if flow <= 0 or head <= 0:
            issues.append(f"HES_missing flow={flow} head={head}")
    return issues


def main(dry_run: bool, do_delete: bool, do_fix: bool) -> None:
    if do_delete and dry_run:
        print("⚠️  --delete ve --dry-run birlikte verilemez. --delete üstün tutuluyor.")
        dry_run = False

    print(f"{'=' * 60}")
    print(
        f"Geçersiz pin temizleme "
        f"{'(DRY-RUN)' if dry_run and not do_delete else ''}"
        f"{'  +FIX' if do_fix else ''}"
        f"{'  +DELETE' if do_delete else ''}"
    )
    print(f"{'=' * 60}\n")

    with UserSessionLocal() as db:
        all_pins = db.query(Pin).all()
        bad: List[Tuple[Pin, List[str]]] = []
        for p in all_pins:
            issues = _classify(p)
            if issues:
                bad.append((p, issues))

        print(f"Toplam pin: {len(all_pins)}, geçersiz aday: {len(bad)}\n")
        if not bad:
            print("✓ Tüm pin'ler geçerli — yapacak bir şey yok.")
            return

        # Detay tablosu
        for pin, issues in bad:
            print(
                f"  Pin #{pin.id:<4d}  type={str(pin.type or '?'):<14s}  "
                f"city={str(pin.city or '?'):<14s}  "
                f"name={str(pin.title or '?')[:24]:<24s}  "
                f"→ {', '.join(issues)}"
            )

        # FIX modu — capacity yeniden hesapla (frontend formülüyle)
        fixed_count = 0
        still_bad: List[Tuple[Pin, List[str]]] = []
        if do_fix:
            print(f"\n🔧 FIX modu: capacity yeniden hesaplanıyor...")
            for pin, _ in bad:
                new_cap = _recompute_capacity(pin)
                if new_cap is not None and new_cap >= MIN_CAPACITY_MW:
                    print(
                        f"  Pin #{pin.id}: capacity {pin.capacity_mw} → "
                        f"{new_cap:.4f} MW"
                    )
                    if not dry_run:
                        pin.capacity_mw = new_cap  # type: ignore
                    fixed_count += 1
                else:
                    still_bad.append((pin, _classify(pin)))
            if not dry_run:
                db.commit()

        # DELETE modu
        delete_count = 0
        if do_delete:
            targets = still_bad if do_fix else bad
            print(f"\n🗑️  DELETE modu: {len(targets)} pin siliniyor...")
            for pin, _ in targets:
                print(
                    f"  DELETE Pin #{pin.id} ({pin.title or 'noname'} · "
                    f"{pin.type or 'notype'})"
                )
                db.delete(pin)
                delete_count += 1
            db.commit()

        print(f"\n📊 Özet:")
        print(f"  Geçersiz pin:     {len(bad)}")
        if do_fix:
            print(f"  Fix edilen:       {fixed_count}")
            print(f"  Fix sonrası kalan: {len(still_bad)}")
        if do_delete:
            print(f"  Silinen:          {delete_count}")
        elif not do_fix:
            print(f"  (--delete vermediniz, hiçbir şey silinmedi.)")


def _recompute_capacity(pin: Pin):
    """fix_existing_pins'in compute_capacity_mw mantığının özetlenmiş hali.

    Sadece pin alanlarına dayanır (Equipment lookup'a girmez — daha ayrıntılı
    çözüm için scripts/fix_existing_pins.py'yi tercih edin)."""
    t = str(pin.type or "")
    if t == "Hidroelektrik":
        flow = float(pin.flow_rate or 0)
        head = float(pin.head_height or 0)
        if flow > 0 and head > 0:
            return 8.5 * flow * head / 1000.0
        return None
    if t == "Güneş Paneli":
        area = float(pin.panel_area or 0)
        if area >= 10:
            # 0.20 default efficiency (equipment lookup yapmıyoruz)
            return area * 0.20 / 1000.0
        return None
    # RES için pin'de equipment_id var ama rated_power_kw bilgisi join gerek;
    # bu script kapsamı dışında. Mevcut değer < threshold ise dokunma.
    cap = float(pin.capacity_mw or 0)
    return cap if cap >= MIN_CAPACITY_MW else None


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", "-n", action="store_true",
                   help="Sadece raporla, değişiklik yapma (varsayılan)")
    p.add_argument("--fix", action="store_true",
                   help="Geçersiz capacity'leri pin alanlarından yeniden hesapla")
    p.add_argument("--delete", action="store_true",
                   help="Hâlâ geçersiz olan pin'leri SİL (DİKKAT: kalıcı)")
    args = p.parse_args()
    # Hiçbir --flag verilmediyse default dry-run
    dry = args.dry_run or (not args.fix and not args.delete)
    main(dry_run=dry, do_delete=args.delete, do_fix=args.fix)

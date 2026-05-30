"""Bulk-fix mevcut pin'ler (2026-05-19).

İki problem var:

1. **city/district NULL** — Eski pin'ler (Pin model'e bu alanlar eklenmeden
   önce oluşturulanlar) reverse-geocode edilmemiş. Generation endpoint
   pin'in city'sini kullanır; null ise `no_data` döner.

2. **capacity_mw tek panel** — Frontend `PinDialogViewModel.getSelectedCapacityMw`
   eskiden `equipment.rated_power_kw / 1000` yapıyordu. GES için bu tek
   panelin (275W) MW karşılığı = 0.000275 MW = imkansız küçük. Yeni
   formül:
     - GES: `panel_area × efficiency × 1 kW/m² / 1000`
     - HES: `8.5 × flow_rate × head_height / 1000`
     - RES: `equipment.rated_power_kw / 1000` (tek türbin, değişmez)

Bu script tüm mevcut pin'leri tarar:
  - city/district null ise GeoService offline GADM reverse-geocode ile doldurur
  - capacity_mw'i yeni formülle yeniden hesaplar

**Kullanım:**
    cd backend
    .\venv\Scripts\python.exe scripts\fix_existing_pins.py

**Dry-run (değişiklik yapmadan rapor):**
    .\venv\Scripts\python.exe scripts\fix_existing_pins.py --dry-run
"""
from __future__ import annotations

import sys
from typing import Optional

# Repo root'tan başlat
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.db.database import UserSessionLocal, SystemSessionLocal
from app.db.models import Pin, Equipment
from app.services.geo_service import GeoService


def compute_capacity_mw(pin: Pin, system_db) -> Optional[float]:
    """Pin tipi + alanları için doğru capacity_mw döner.

    PinDialogViewModel.getSelectedCapacityMw frontend formülünün
    backend muadili. Veri eksikse None döner (mevcut değer korunur).
    """
    if pin.type == "Hidroelektrik":
        if (pin.flow_rate and pin.head_height
                and pin.flow_rate > 0 and pin.head_height > 0):
            # P_kW ≈ 8.5 × Q × H (Türkiye pratik formül, η≈0.85)
            return round(8.5 * float(pin.flow_rate) * float(pin.head_height) / 1000, 4)
        return None  # flow/head yoksa mevcut değeri koru

    if pin.type == "Güneş Paneli":
        efficiency = 0.20  # default
        if pin.equipment_id:
            eq = system_db.query(Equipment).filter(
                Equipment.id == pin.equipment_id
            ).first()
            if eq and eq.efficiency and eq.efficiency > 0:
                efficiency = float(eq.efficiency)
        panel_area = float(pin.panel_area or 10.0)
        # capacity_kw = panel_area × efficiency × 1 kW/m² (STC)
        return round(panel_area * efficiency / 1000, 4)

    if pin.type == "Rüzgar Türbini":
        if pin.equipment_id:
            eq = system_db.query(Equipment).filter(
                Equipment.id == pin.equipment_id
            ).first()
            if eq and eq.rated_power_kw:
                return round(float(eq.rated_power_kw) / 1000, 4)
        return None  # equipment yoksa mevcut değeri koru

    return None


def main(dry_run: bool = False) -> None:
    geo = GeoService()
    print(f'{"=== DRY RUN ===" if dry_run else "=== BULK FIX BAŞLIYOR ==="}')
    print()

    fixed_geocode = 0
    fixed_capacity = 0
    unchanged = 0
    errors = 0

    with UserSessionLocal() as udb, SystemSessionLocal() as sdb:
        pins = udb.query(Pin).all()
        print(f'Toplam {len(pins)} pin tarandı.')
        print()

        for pin in pins:
            try:
                changes: list[str] = []
                old_city = pin.city
                old_district = pin.district
                old_capacity = pin.capacity_mw

                # 1) Reverse geocode (city/district null ise)
                if not pin.city or not pin.district:
                    loc = geo._get_location_info(
                        lat=float(pin.latitude),
                        lon=float(pin.longitude),
                    )
                    new_city = loc.get("province") or None
                    new_district = loc.get("district") or None
                    if new_city and not pin.city:
                        pin.city = new_city
                        changes.append(f'city: NULL→{new_city}')
                    if new_district and not pin.district:
                        pin.district = new_district
                        changes.append(f'dist: NULL→{new_district}')
                    if new_city or new_district:
                        fixed_geocode += 1

                # 2) capacity_mw recompute
                new_cap = compute_capacity_mw(pin, sdb)
                if (new_cap is not None
                        and abs(new_cap - float(old_capacity or 0)) > 0.0001):
                    pin.capacity_mw = new_cap
                    changes.append(
                        f'cap: {old_capacity:.6f}→{new_cap:.4f} MW'
                    )
                    fixed_capacity += 1

                if changes:
                    print(
                        f'  #{pin.id:3} ({pin.type[:6]:6} {pin.city or "?":<12}'
                        f'/{pin.district or "?":<12}): '
                        f'{" | ".join(changes)}'
                    )
                else:
                    unchanged += 1

            except Exception as e:
                errors += 1
                print(f'  #{pin.id:3} HATA: {e}')

        if not dry_run:
            udb.commit()
            print()
            print('UserDB commit edildi.')

    print()
    print('=== ÖZET ===')
    print(f'  Reverse geocode düzeltildi: {fixed_geocode}')
    print(f'  Capacity recompute edildi:  {fixed_capacity}')
    print(f'  Değişiklik yok:             {unchanged}')
    print(f'  Hata:                       {errors}')
    if dry_run:
        print()
        print('  (DRY RUN — hiçbir şey commit edilmedi)')


if __name__ == "__main__":
    dry = "--dry-run" in sys.argv or "-n" in sys.argv
    main(dry_run=dry)

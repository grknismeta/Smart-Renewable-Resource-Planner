"""
HES (Hidroelektrik) Türbin Ekipmanlarını Veri Tabanına Ekle
==============================================================
Çalıştırma: python -m scripts.seed_hes_equipment (backend kök klasöründen)
veya: python backend/scripts/seed_hes_equipment.py
"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.db.database import get_system_db_session
from app.db.models import Equipment

HES_TURBINES = [
    {
        "name": "Kaplan Türbin — 50 kW",
        "type": "Hydro",
        "rated_power_kw": 50.0,
        "efficiency": 0.90,
        "cost_per_unit": 75000.0,
        "maintenance_cost_annual": 2500.0,
        "specs": {
            "turbine_type": "Kaplan",
            "head_range_m": [2, 40],
            "flow_range_m3s": [0.5, 800],
            "description": "Düşük düşü, yüksek debi — nehir tipi HES",
        },
    },
    {
        "name": "Kaplan Türbin — 250 kW",
        "type": "Hydro",
        "rated_power_kw": 250.0,
        "efficiency": 0.90,
        "cost_per_unit": 300000.0,
        "maintenance_cost_annual": 8000.0,
        "specs": {
            "turbine_type": "Kaplan",
            "head_range_m": [2, 40],
            "flow_range_m3s": [0.5, 800],
            "description": "Düşük düşü, yüksek debi — nehir tipi HES",
        },
    },
    {
        "name": "Francis Türbin — 500 kW",
        "type": "Hydro",
        "rated_power_kw": 500.0,
        "efficiency": 0.85,
        "cost_per_unit": 600000.0,
        "maintenance_cost_annual": 15000.0,
        "specs": {
            "turbine_type": "Francis",
            "head_range_m": [10, 700],
            "flow_range_m3s": [0.1, 200],
            "description": "Orta düşü, orta debi — en yaygın baraj türbini",
        },
    },
    {
        "name": "Francis Türbin — 2 MW",
        "type": "Hydro",
        "rated_power_kw": 2000.0,
        "efficiency": 0.87,
        "cost_per_unit": 2500000.0,
        "maintenance_cost_annual": 60000.0,
        "specs": {
            "turbine_type": "Francis",
            "head_range_m": [10, 700],
            "flow_range_m3s": [0.1, 200],
            "description": "Orta düşü, orta debi — büyük baraj türbini",
        },
    },
    {
        "name": "Pelton Türbin — 100 kW",
        "type": "Hydro",
        "rated_power_kw": 100.0,
        "efficiency": 0.88,
        "cost_per_unit": 150000.0,
        "maintenance_cost_annual": 4000.0,
        "specs": {
            "turbine_type": "Pelton",
            "head_range_m": [50, 1800],
            "flow_range_m3s": [0.01, 50],
            "description": "Yüksek düşü, düşük debi — dağlık bölge HES",
        },
    },
    {
        "name": "Pelton Türbin — 1 MW",
        "type": "Hydro",
        "rated_power_kw": 1000.0,
        "efficiency": 0.88,
        "cost_per_unit": 1200000.0,
        "maintenance_cost_annual": 35000.0,
        "specs": {
            "turbine_type": "Pelton",
            "head_range_m": [50, 1800],
            "flow_range_m3s": [0.01, 50],
            "description": "Yüksek düşü, düşük debi — Türkiye dağlık bölge",
        },
    },
]


def seed_hes_equipment():
    db = get_system_db_session()
    try:
        existing_hydro = db.query(Equipment).filter(Equipment.type == "Hydro").count()
        if existing_hydro > 0:
            print(f"✅ Zaten {existing_hydro} HES ekipmanı mevcut. Seed atlandı.")
            return

        for t in HES_TURBINES:
            eq = Equipment(
                name=t["name"],
                type=t["type"],
                rated_power_kw=t["rated_power_kw"],
                efficiency=t["efficiency"],
                cost_per_unit=t["cost_per_unit"],
                maintenance_cost_annual=t["maintenance_cost_annual"],
                specs=t["specs"],
            )
            db.add(eq)

        db.commit()
        print(f"✅ {len(HES_TURBINES)} HES türbin ekipmanı başarıyla eklendi.")
    except Exception as e:
        db.rollback()
        print(f"❌ Hata: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_hes_equipment()

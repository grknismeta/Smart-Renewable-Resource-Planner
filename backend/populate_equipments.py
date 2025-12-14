from sqlalchemy.orm import Session
from .database import SystemSessionLocal, SystemEngine, SystemBase
from .models import Equipment

def populate_default_equipments():
    """
    Sistem veritabanını varsayılan Güneş Panelleri ve Rüzgar Türbinleri ile doldurur.
    """
    # Tabloların varlığından emin ol
    SystemBase.metadata.create_all(bind=SystemEngine)
    db = SystemSessionLocal()

    # --- RÜZGAR TÜRBİNLERİ ---
    turbines = [
        {
            "name": "Vestas V136-3.45 MW",
            "type": "Wind",
            "rated_power_kw": 3450.0,
            "efficiency": 0.45, # Teorik maksimuma yakın
            "cost_per_unit": 3500000.0, # Yaklaşık 3.5M USD
            "maintenance_cost_annual": 40000.0,
            "specs": {
                "rotor_diameter_m": 136,
                "hub_height_m": 112,
                # Basitleştirilmiş Güç Eğrisi (m/s -> kW)
                "power_curve": {
                    "3": 0, "3.5": 50, "4": 180, "5": 450, "6": 900, "7": 1500, 
                    "8": 2200, "9": 2900, "10": 3300, "11": 3450, "25": 3450
                }
            }
        },
        {
            "name": "GE Renewable 2.5-100",
            "type": "Wind",
            "rated_power_kw": 2500.0,
            "efficiency": 0.42,
            "cost_per_unit": 2800000.0,
            "maintenance_cost_annual": 30000.0,
            "specs": {
                "rotor_diameter_m": 100,
                "hub_height_m": 85,
                "power_curve": {
                    "3": 0, "4": 120, "5": 380, "6": 750, "7": 1300, 
                    "8": 1900, "9": 2300, "10": 2500, "25": 2500
                }
            }
        },
        {
            "name": "Nordex N149/4.0-4.5",
            "type": "Wind",
            "rated_power_kw": 4500.0,
            "efficiency": 0.48,
            "cost_per_unit": 4200000.0,
            "maintenance_cost_annual": 50000.0,
            "specs": {
                "rotor_diameter_m": 149,
                "hub_height_m": 120,
                "power_curve": {
                    "3": 50, "5": 600, "7": 1800, "9": 3200, "11": 4200, "13": 4500
                }
            }
        }
    ]

    # --- GÜNEŞ PANELLERİ ---
    panels = [
        {
            "name": "Standart Polikristal 275W",
            "type": "Solar",
            "rated_power_kw": 0.275,
            "efficiency": 0.17,
            "cost_per_unit": 150.0, # Panel başına
            "maintenance_cost_annual": 5.0,
            "specs": {
                "area_m2": 1.6,
                "type": "Polycrystalline",
                "temp_coeff": -0.40
            }
        },
        {
            "name": "Yüksek Verim Monokristal 400W",
            "type": "Solar",
            "rated_power_kw": 0.400,
            "efficiency": 0.21,
            "cost_per_unit": 220.0,
            "maintenance_cost_annual": 5.0,
            "specs": {
                "area_m2": 1.9,
                "type": "Monocrystalline",
                "temp_coeff": -0.35
            }
        },
        {
            "name": "Bifacial (Çift Yüzlü) 550W",
            "type": "Solar",
            "rated_power_kw": 0.550,
            "efficiency": 0.23,
            "cost_per_unit": 300.0,
            "maintenance_cost_annual": 8.0,
            "specs": {
                "area_m2": 2.4,
                "type": "Bifacial",
                "temp_coeff": -0.30
            }
        }
    ]

    # DB'ye Ekleme
    all_items = turbines + panels
    count = 0
    
    for item in all_items:
        # Önce var mı kontrol et (Tekrar tekrar çalıştırılınca çakışmasın)
        exists = db.query(Equipment).filter(Equipment.name == item["name"]).first()
        if not exists:
            db_item = Equipment(**item)
            db.add(db_item)
            count += 1
    
    db.commit()
    db.close()
    print(f"✅ Başarılı: {count} yeni ekipman veritabanına eklendi.")

if __name__ == "__main__":
    populate_default_equipments()
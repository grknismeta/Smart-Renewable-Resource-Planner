from .db.database import SystemEngine, SystemBase, SystemSessionLocal, UserEngine, UserBase, UserSessionLocal, UserPinsEngine, UserPinsBase
from .db import models

def init_db():
    # 1. User DB (Pinler, Kullanıcılar, Senaryolar) tablolarını oluştur
    models.UserBase.metadata.create_all(bind=UserEngine)
    
    # 2. System DB (Ekipmanlar, Grid Analizi) tablolarını oluştur
    models.SystemBase.metadata.create_all(bind=SystemEngine)

    # 3. User Pins DB (Hesaplama Sonuçları) tabloyu oluştur
    models.UserPinsBase.metadata.create_all(bind=UserPinsEngine)
    
    # Sadece System DB'ye yazmak için Session aç
    db = SystemSessionLocal()
    
    # --- EKİPMANLARI KONTROL ET VE EKLE (SADECE SYSTEM DB'YE) ---
    if db.query(models.Equipment).count() == 0:
        print("Ekipman veritabanı boş, örnek veriler System DB'ye ekleniyor...")
        
        equipments = [
            # --- GÜNEŞ PANELLERİ ---
            models.Equipment(
                name="Standart Mono-Kristal Panel",
                type="Solar",
                rated_power_kw=0.450, # 450 Watt
                efficiency=0.21,      # %21 Verim
                cost_per_unit=200.0,  # 200 Dolar
                maintenance_cost_annual=5.0,
                specs={"temp_coefficient": -0.0035, "area_m2": 2.2}
            ),
            models.Equipment(
                name="Premium Yüksek Verimli Panel",
                type="Solar",
                rated_power_kw=0.600, # 600 Watt
                efficiency=0.23,      # %23 Verim
                cost_per_unit=350.0,
                maintenance_cost_annual=8.0,
                specs={"temp_coefficient": -0.0029, "area_m2": 2.4}
            ),
            
            # --- RÜZGAR TÜRBİNLERİ ---
            models.Equipment(
                name="Enercon E-138 (Orta Ölçek)",
                type="Wind",
                rated_power_kw=3500.0, # 3.5 MW
                efficiency=1.0, # Rüzgar için güç eğrisi kullanılır
                cost_per_unit=3500000.0, # 3.5 Milyon Dolar
                maintenance_cost_annual=40000.0,
                # Örnek Güç Eğrisi (Hız m/s : Güç kW)
                specs={
                    "hub_height": 130,
                    "power_curve": {
                        "3": 50, "5": 400, "7": 1200, "9": 2200, 
                        "11": 3100, "13": 3500, "25": 3500
                    }
                }
            ),
            models.Equipment(
                name="Vestas V162 (Büyük Ölçek)",
                type="Wind",
                rated_power_kw=6200.0, # 6.2 MW
                efficiency=1.0,
                cost_per_unit=6000000.0,
                maintenance_cost_annual=70000.0,
                specs={
                    "hub_height": 160,
                    "power_curve": {
                        "3": 100, "5": 800, "7": 2500, "9": 4500, 
                        "11": 5800, "13": 6200, "22": 6200
                    }
                }
            )
        ]
        
        db.add_all(equipments)
        db.commit()
        print("Örnek ekipmanlar System DB'ye eklendi.")
    else:
        print("Ekipmanlar System DB'de zaten mevcut.")
        
    db.close()

if __name__ == "__main__":
    init_db()
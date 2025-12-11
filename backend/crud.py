from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import Optional, List

from . import models, schemas, auth, solar_calculations
from .solar_calculations import calculate_solar_power_production
from .wind_calculations import get_historical_wind_data
# --- Kullanıcı (User) İşlemleri (DÜZELTİLDİ) ---

def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()

def create_user(db: Session, user: schemas.UserCreate):
    hashed_password = auth.get_password_hash(user.password)
    db_user = models.User(email=user.email, hashed_password=hashed_password)
    
    try:
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        return db_user
    except IntegrityError:
        db.rollback() 
        return None 
    except Exception as e:
        db.rollback()
        print(f"Kullanıcı oluşturulurken beklenmedik hata: {e}")
        return None
        

def get_equipments(db: Session, type: str | None = None, skip: int = 0, limit: int = 100):
    """
    Tüm ekipmanları veya belirli bir tipe (Solar/Wind) göre filtreleyerek getirir.
    """
    query = db.query(models.Equipment)
    if type:
        query = query.filter(models.Equipment.type == type)
    return query.offset(skip).limit(limit).all()

def get_equipment(db: Session, equipment_id: int):
    return db.query(models.Equipment).filter(models.Equipment.id == equipment_id).first()

# --- Pin (Konum) İşlemleri (Güncellendi) ---

def get_pin_by_id(db: Session, pin_id: int, user_id: int):
    """(YENİ) Belirli bir pini, sahibine göre getirir."""
    return db.query(models.Pin).filter(
        models.Pin.id == pin_id,
        models.Pin.owner_id == user_id
    ).first()

def get_pins_by_owner(db: Session, owner_id: int, skip: int = 0, limit: int = 100):
    """Belirli bir kullanıcıya ait tüm pinleri döndürür."""
    return db.query(models.Pin).filter(models.Pin.owner_id == owner_id).offset(skip).limit(limit).all()

# backend/crud.py
def create_pin_for_user(db: Session, pin: schemas.PinCreate, user_id: int):
    print(f"CRUD: {pin.latitude}, {pin.longitude} için veri analizi yapılıyor...")
    
    # Varsayılan değerler
    avg_solar = None
    avg_wind = None
    
    # Pin tipine göre otomatik analiz yapıp 'Önizleme' verilerini dolduruyoruz.
    # Bu sayede listede "Ortalama X kWh" yazabilecek.
    
    if pin.type == "Güneş Paneli":
        # Güneş için 1m2'lik ham potansiyeli çek
        solar_res = calculate_solar_power_production(
            latitude=pin.latitude,
            longitude=pin.longitude,
            panel_area=1.0
        )
        if "error" not in solar_res:
            avg_solar = solar_res.get("daily_avg_potential_kwh_m2")
            
    elif pin.type == "Rüzgar Türbini":
        # Rüzgar için 100m yükseklikteki ortalama hızı çek
        wind_res = get_historical_wind_data(
            latitude=pin.latitude,
            longitude=pin.longitude
        )
        if "error" not in wind_res:
            avg_wind = wind_res.get("avg_wind_speed_ms")

    # Modeli oluştur
    # Pydantic modelini sözlüğe çevir
    pin_data = pin.model_dump()
    
    # ID ve OwnerID'yi manuel yönetiyoruz (Client göndermez)
    pin_data["owner_id"] = user_id
    
    # Hesaplanan özet verileri ekle
    pin_data["avg_solar_irradiance"] = avg_solar
    pin_data["avg_wind_speed"] = avg_wind

    # Veritabanı nesnesini oluştur
    db_pin = models.Pin(**pin_data)
    
    db.add(db_pin)
    db.commit()
    db.refresh(db_pin)
    return db_pin

def delete_pin_by_id(db: Session, pin_id: int, user_id: int):
    """
    Belirli bir pini siler (sadece sahibi silebilir).
    """
    db_pin = db.query(models.Pin).filter(
        models.Pin.id == pin_id,
        models.Pin.owner_id == user_id
    ).first()
    
    if db_pin:
        db.delete(db_pin)
        db.commit()
        return True
    
    return False
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func
from typing import Optional, List, Union

# Updated imports
from backend.db import models
from backend.schemas import schemas
from backend import auth

# --- KULLANICI (User) İŞLEMLERİ ---

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
        print(f"Kullanıcı oluşturulurken hata: {e}")
        return None

# --- EKİPMAN (System DB) İŞLEMLERİ ---

def get_equipments(db: Session, type: Optional[str] = None, skip: int = 0, limit: int = 100):
    # db: SystemSession olmalı
    print(f'[CRUD.get_equipments] type={type}, skip={skip}, limit={limit}')
    query = db.query(models.Equipment)
    total_count = query.count()
    print(f'[CRUD.get_equipments] Toplam equipment sayısı: {total_count}')
    if type:
        query = query.filter(models.Equipment.type == type)
        filtered_count = query.count()
        print(f'[CRUD.get_equipments] {type} filtresi sonrası: {filtered_count}')
    result = query.offset(skip).limit(limit).all()
    print(f'[CRUD.get_equipments] Döndürülen: {len(result)} ekipman')
    return result

def get_equipment(db: Session, equipment_id: int):
    # db: SystemSession olmalı
    return db.query(models.Equipment).filter(models.Equipment.id == equipment_id).first()

# --- PIN (User DB + System DB) İŞLEMLERİ ---

def get_pin_by_id(db: Session, pin_id: int, user_id: int):
    return db.query(models.Pin).filter(
        models.Pin.id == pin_id,
        models.Pin.owner_id == user_id
    ).first()

def get_pins_by_owner(db: Session, owner_id: int, skip: int = 0, limit: int = 100):
    return db.query(models.Pin).filter(models.Pin.owner_id == owner_id).offset(skip).limit(limit).all()

# DÜZELTME: system_db parametresini Optional yaptık
def create_pin_for_user(
    db: Session, 
    pin: schemas.PinCreate, 
    user_id: int, 
    system_db: Optional[Session] = None
):
    """
    Pin oluşturur. Eğer system_db verilirse, oradan hava durumu ortalamalarını çeker.
    """
    print(f"CRUD: {pin.latitude}, {pin.longitude} kayıt ediliyor...")
    
    avg_solar = None
    avg_wind = None
    
    # System DB varsa gerçek veriden ortalama çek
    if system_db:
        try:
            # Koordinat yuvarlama (Grid eşleşmesi için)
            lat_round = round(pin.latitude * 2) / 2
            lon_round = round(pin.longitude * 2) / 2
            
            if pin.type == "Güneş Paneli":
                # Tüm zamanların ortalama radyasyonu
                # Not: WeatherData modelini burada kullanabilmek için models.WeatherData import edilmiş olmalı
                # Eğer models.py içinde WeatherData yoksa bu blok çalışmaz (try-except ile korunuyor)
                avg_val = system_db.query(func.avg(models.WeatherData.shortwave_radiation_sum)).filter(
                    models.WeatherData.latitude == lat_round,
                    models.WeatherData.longitude == lon_round
                ).scalar()
                if avg_val: avg_solar = round(avg_val, 2)
                
            elif pin.type == "Rüzgar Türbini":
                # Tüm zamanların ortalama rüzgar hızı
                avg_val = system_db.query(func.avg(models.WeatherData.wind_speed_mean)).filter(
                    models.WeatherData.latitude == lat_round,
                    models.WeatherData.longitude == lon_round
                ).scalar()
                if avg_val: avg_wind = round(avg_val, 2)
                
        except Exception as e:
            print(f"Hava verisi çekilirken hata (Önemsiz): {e}")

    # Pydantic -> Dict
    pin_data = pin.model_dump()
    pin_data["owner_id"] = user_id
    
    # Hesaplanan özet verileri ekle
    pin_data["avg_solar_irradiance"] = avg_solar
    pin_data["avg_wind_speed"] = avg_wind

    db_pin = models.Pin(**pin_data)
    
    db.add(db_pin)
    db.commit()
    db.refresh(db_pin)
    return db_pin

def delete_pin_by_id(db: Session, pin_id: int, user_id: int):
    db_pin = db.query(models.Pin).filter(
        models.Pin.id == pin_id,
        models.Pin.owner_id == user_id
    ).first()
    
    if db_pin:
        # Önce ilişkili scenarios'ları güncelle (pin_id'yi null yap)
        db.query(models.Scenario).filter(
            models.Scenario.pin_id == pin_id
        ).update({"pin_id": None}, synchronize_session=False)
        
        # Sonra pin'i sil
        db.delete(db_pin)
        db.commit()
        return True
    
    return False

# ... (delete_pin_by_id remains same)

def update_pin(db: Session, pin_id: int, pin_update: schemas.PinCreate, user_id: int):
    db_pin = db.query(models.Pin).filter(
        models.Pin.id == pin_id,
        models.Pin.owner_id == user_id
    ).first()
    
    if not db_pin:
        return None
        
    # Update fields
    pin_data = pin_update.model_dump(exclude_unset=True)
    for key, value in pin_data.items():
        setattr(db_pin, key, value)
        
    db.commit()
    db.refresh(db_pin)
    return db_pin

# --- WEATHER DATA (Sistem DB) İŞLEMLERİ ---

def get_weather_stats(system_db: Session, latitude: float, longitude: float):
    """
    Belirli bir konumun 10 yıllık hava verisi istatistiklerini hesaplar.
    """
    # Grid noktasına yuvarla (Veri toplarken kullandığımız hassasiyet: 0.5)
    lat_round = round(latitude * 2) / 2
    lon_round = round(longitude * 2) / 2
    
    # 1. Genel Ortalamalar
    stats = system_db.query(
        func.avg(models.WeatherData.shortwave_radiation_sum).label("avg_rad"),
        func.avg(models.WeatherData.wind_speed_mean).label("avg_wind"),
        func.avg(models.WeatherData.temperature_mean).label("avg_temp")
    ).filter(
        models.WeatherData.latitude == lat_round,
        models.WeatherData.longitude == lon_round
    ).first()
    
    if not stats or stats.avg_rad is None:
        return None # Veri yoksa None dön
        
    # 2. Aylık Dağılım (Mevsimsellik Analizi için)
    # SQLite'da strftime('%m', date) ayı verir.
    monthly_data = system_db.query(
        func.strftime('%m', models.WeatherData.date).label("month"),
        func.avg(models.WeatherData.shortwave_radiation_sum).label("avg_rad"),
        func.avg(models.WeatherData.wind_speed_mean).label("avg_wind")
    ).filter(
        models.WeatherData.latitude == lat_round,
        models.WeatherData.longitude == lon_round
    ).group_by("month").order_by("month").all()
    
    # Aylık veriyi sözlüğe çevir { "01": {...}, "02": {...} }
    monthly_dict = {}
    for m in monthly_data:
        monthly_dict[m.month] = {
            "solar": m.avg_rad, # MJ/m2 veya kWh/m2 (birimi kontrol etmeli)
            "wind": m.avg_wind  # m/s
        }
        
    return {
        "annual_avg": {
            "solar": stats.avg_rad,
            "wind": stats.avg_wind,
            "temp": stats.avg_temp
        },
        "monthly": monthly_dict
    }

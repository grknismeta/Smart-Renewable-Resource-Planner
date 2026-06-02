from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func, extract
from typing import Optional, List, Union

# Updated imports
from app.db import models
from app.schemas import schemas
from app import auth

# --- KULLANICI (User) İŞLEMLERİ ---

def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()

def create_user(db: Session, user: schemas.UserCreate):
    hashed_password = auth.get_password_hash(user.password)
    db_user = models.User(
        email=user.email,
        full_name=(user.full_name or '').strip() or None,
        hashed_password=hashed_password,
    )
    
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


def get_or_create_oauth_user(db: Session, email: str, full_name: Optional[str] = None):
    """AUTH-3 (2026-06-01): OAuth (Google/GitHub) ile gelen kullanıcı — e-posta
    ile eşle; yoksa parolasız oluştur (rastgele kullanılamaz hash → parola
    login'i imkânsız). full_name boşsa doldur."""
    import secrets as _secrets
    user = get_user_by_email(db, email)
    if user:
        if full_name and not user.full_name:
            user.full_name = full_name.strip() or None
            db.commit()
            db.refresh(user)
        return user
    db_user = models.User(
        email=email,
        full_name=(full_name or '').strip() or None,
        hashed_password=auth.get_password_hash(_secrets.token_urlsafe(32)),
    )
    try:
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        return db_user
    except IntegrityError:
        db.rollback()
        return get_user_by_email(db, email)  # yarış: araya kayıt girdiyse onu al


def update_user_profile(db: Session, user: models.User, full_name: Optional[str]):
    """HESABIM (2026-06-02): kullanıcının ad-soyad'ını günceller.
    full_name boş/None ise alan temizlenir (None)."""
    user.full_name = (full_name or '').strip() or None
    db.commit()
    db.refresh(user)
    return user


def update_user_password(db: Session, user: models.User, new_password: str):
    """HESABIM (2026-06-02): kullanıcının parolasını yeniden hash'leyip kaydeder.
    Çağıran taraf mevcut parolayı zaten doğrulamış olmalı."""
    user.hashed_password = auth.get_password_hash(new_password)
    db.commit()
    db.refresh(user)
    return user

# --- EKİPMAN (System DB) İŞLEMLERİ ---

def get_equipments(db: Session, type: Optional[str] = None, skip: int = 0, limit: int = 100,
                   user_id: Optional[int] = None):
    """
    Ekipman listesi: sistem ekipmanları (owner_id IS NULL) + (user_id varsa)
    kullanıcının kendi eklediği ekipmanlar.
    2026-05-17 Sprint A — user-aware filtering.
    """
    print(f'[CRUD.get_equipments] type={type}, user_id={user_id}, skip={skip}, limit={limit}')
    query = db.query(models.Equipment)
    if type:
        query = query.filter(models.Equipment.type == type)
    if user_id is not None:
        # Sistem ekipmanları (owner_id NULL) + kullanıcının kendi'leri
        query = query.filter(
            (models.Equipment.owner_id == None) | (models.Equipment.owner_id == user_id)  # noqa: E711
        )
    else:
        # Geriye uyum: user_id verilmezse sadece sistem ekipmanları
        query = query.filter(models.Equipment.owner_id == None)  # noqa: E711
    result = query.offset(skip).limit(limit).all()
    print(f'[CRUD.get_equipments] Döndürülen: {len(result)} ekipman')
    return result

def get_equipment(db: Session, equipment_id: int):
    # db: SystemSession olmalı
    return db.query(models.Equipment).filter(models.Equipment.id == equipment_id).first()

def create_user_equipment(db: Session, equipment_data, user_id: int):
    """
    Kullanıcının kendi ekipmanını oluşturur. owner_id = user_id ile insert.
    2026-05-17 Sprint A.
    """
    db_eq = models.Equipment(
        name=equipment_data.name,
        type=equipment_data.type,
        rated_power_kw=equipment_data.rated_power_kw,
        efficiency=equipment_data.efficiency,
        cost_per_unit=equipment_data.cost_per_unit or 0.0,
        specs=equipment_data.specs or {},
        owner_id=user_id,
    )
    db.add(db_eq)
    db.commit()
    db.refresh(db_eq)
    return db_eq

def delete_user_equipment(db: Session, equipment_id: int, user_id: int) -> bool:
    """
    Kullanıcının kendi ekipmanını siler. Sistem ekipmanları silinemez
    (owner_id NULL — query eşleşmez).
    """
    eq = db.query(models.Equipment).filter(
        models.Equipment.id == equipment_id,
        models.Equipment.owner_id == user_id,
    ).first()
    if not eq:
        return False
    db.delete(eq)
    db.commit()
    return True

def update_user_equipment(db: Session, equipment_id: int, equipment_data, user_id: int):
    """
    Kullanıcının kendi ekipmanını günceller. Sistem ekipmanları (owner_id NULL)
    güncellenemez — owner_id filter eşleşmez, None döner.
    2026-05-17 — 'Kullanıcının eklediği santral tipleri düzenlenebilir' isteği.
    """
    eq = db.query(models.Equipment).filter(
        models.Equipment.id == equipment_id,
        models.Equipment.owner_id == user_id,
    ).first()
    if not eq:
        return None
    eq.name = equipment_data.name
    eq.type = equipment_data.type
    eq.rated_power_kw = equipment_data.rated_power_kw
    eq.efficiency = equipment_data.efficiency
    eq.cost_per_unit = equipment_data.cost_per_unit or 0.0
    eq.specs = equipment_data.specs or {}
    db.commit()
    db.refresh(eq)
    return eq

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
    # PostgreSQL uyumluluğu için strftime('%m') yerine SQLAlchemy 'extract' metodu kullanılıyor.
    monthly_data = system_db.query(
        extract('month', models.WeatherData.date).label("month"),
        func.avg(models.WeatherData.shortwave_radiation_sum).label("avg_rad"),
        func.avg(models.WeatherData.wind_speed_mean).label("avg_wind")
    ).filter(
        models.WeatherData.latitude == lat_round,
        models.WeatherData.longitude == lon_round
    ).group_by("month").order_by("month").all()
    
    # Aylık veriyi sözlüğe çevir { "01": {...}, "02": {...} }
    monthly_dict = {}
    for m in monthly_data:
        # extract('month') integer döner (örn: 1). Frontend'in bozulmaması için string'e çevirip başına 0 ekliyoruz ("01").
        month_str = f"{int(m.month):02d}" if m.month else "00"
        monthly_dict[month_str] = {
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

# --- PIN ANALİZİ (PinAnalysis) İŞLEMLERİ ---

def create_or_update_pin_analysis(db: Session, pin_id: int, result_data: dict):
    """
    Pin için hesaplanan analiz sonucunu kaydeder veya günceller.
    """
    # Mevcut analizi kontrol et
    db_analysis = db.query(models.PinAnalysis).filter(models.PinAnalysis.pin_id == pin_id).first()
    
    if db_analysis:
        # Varsa güncelle
        db_analysis.result_data = result_data
    else:
        # Yoksa oluştur
        db_analysis = models.PinAnalysis(pin_id=pin_id, result_data=result_data)
        db.add(db_analysis)
        
    try:
        db.commit()
        db.refresh(db_analysis)
        return db_analysis
    except Exception as e:
        db.rollback()
        print(f"Analiz kaydedilirken hata: {e}")
        return None
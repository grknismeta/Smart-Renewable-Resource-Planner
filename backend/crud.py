from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from typing import Optional, List

from . import models, schemas, auth, solar_calculations

# --- Kullanıcı (User) İşlemleri (DÜZELTİLDİ) ---

def get_user_by_email(db: Session, email: str):
    """
    (HATA DÜZELTMESİ)
    Verilen email adresine sahip kullanıcıyı döndürür.
    (get_user_by_username -> get_user_by_email olarak düzeltildi)
    """
    return db.query(models.User).filter(models.User.email == email).first()

def create_user(db: Session, user: schemas.UserCreate):
    """
    (HATA DÜZELTMESİ)
    Yeni bir kullanıcı oluşturur (email ve şifrelenmiş parola ile).
    """
    hashed_password = auth.get_password_hash(user.password)
    
    # (HATA DÜZELTMESİ) 'username' -> 'email'
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

def create_pin_for_user(db: Session, pin: schemas.PinCreate, user_id: int):
    """
    Belirli bir kullanıcı için yeni bir pin oluşturur.
    (turbine_model_id desteği eklendi)
    """
    db_pin = models.Pin(**pin.model_dump(), owner_id=user_id)
    
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

# --- Türbin (Turbine) İşlemleri (YENİ) ---

def get_turbine_by_id(db: Session, turbine_id: int):
    """ID'ye göre bir türbin modelini getirir."""
    return db.query(models.Turbine).filter(models.Turbine.id == turbine_id).first()

def get_default_turbine(db: Session):
    """(YENİ) Standart (is_default=True) olan türbin modelini getirir."""
    return db.query(models.Turbine).filter(models.Turbine.is_default == True).first()

def get_turbines(db: Session, skip: int = 0, limit: int = 100):
    """Tüm türbin modellerini listeler."""
    return db.query(models.Turbine).offset(skip).limit(limit).all()

def create_turbine(db: Session, turbine: schemas.TurbineCreate):
    """Yeni bir türbin modeli oluşturur."""
    
    # Eğer bu türbin "default" olarak ayarlanıyorsa,
    # diğer tüm türbinlerin "default" işaretini kaldır.
    if turbine.is_default:
        db.query(models.Turbine).update({"is_default": False})

    db_turbine = models.Turbine(**turbine.model_dump())
    try:
        db.add(db_turbine)
        db.commit()
        db.refresh(db_turbine)
        return db_turbine
    except IntegrityError: # (model_name unique hatası)
        db.rollback()
        return None

# --- GÜNEŞ PANELİ CRUD İŞLEMLERİ ---

#   def create_solar_panel(db: Session, panel: schemas.SolarPanelCreate) -> models.SolarPanel:

def create_solar_panel(db: Session, panel: schemas.SolarPanelCreate) -> Optional[models.SolarPanel]:
    """Yeni güneş paneli modeli oluşturur"""
    # Eğer bu panel default olarak ayarlanıyorsa,
    # diğer tüm panellerin default işaretini kaldır
    if panel.is_default:
        db.query(models.SolarPanel).update({"is_default": False})

    db_panel = models.SolarPanel(**panel.model_dump())
    try:
        db.add(db_panel)
        db.commit()
        db.refresh(db_panel)
        return db_panel
    except IntegrityError:  # model_name unique hatası
        db.rollback()
        return None

def get_solar_panels(db: Session, skip: int = 0, limit: int = 100) -> List[models.SolarPanel]:
    """Tüm güneş paneli modellerini listeler"""
    return db.query(models.SolarPanel).offset(skip).limit(limit).all()

def get_solar_panel_by_id(db: Session, panel_id: int) -> Optional[models.SolarPanel]:
    """ID'ye göre güneş paneli modeli getirir"""
    return db.query(models.SolarPanel).filter(models.SolarPanel.id == panel_id).first()

def get_default_solar_panel(db: Session) -> Optional[models.SolarPanel]:
    """Varsayılan güneş paneli modelini getirir"""
    return db.query(models.SolarPanel).filter(models.SolarPanel.is_default == True).first()

def set_default_solar_panel(db: Session, panel_id: int) -> Optional[models.SolarPanel]:
    """Belirtilen paneli varsayılan olarak ayarlar"""
    # Önce tüm panellerin varsayılan durumunu kaldır
    db.query(models.SolarPanel).update({"is_default": False})
    
    # Belirtilen paneli varsayılan yap
    panel = get_solar_panel_by_id(db, panel_id)
    if panel:
        # DÜZELTME: Doğrudan atama yerine setattr kullanıyoruz
        setattr(panel, 'is_default', True)
        
        db.commit()
        db.refresh(panel)
    return panel

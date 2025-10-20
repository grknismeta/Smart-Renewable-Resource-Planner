from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError # Veritabanı kısıtlama hatalarını yakalamak için

import models
import schemas
import auth

# --- Kullanıcı (User) İşlemleri ---

def get_user_by_email(db: Session, email: str):
    """Verilen e-posta adresine sahip kullanıcıyı döndürür."""
    return db.query(models.User).filter(models.User.email == email).first()

def create_user(db: Session, user: schemas.UserCreate):
    """Yeni bir kullanıcı oluşturur ve parolayı şifreleyerek veritabanına kaydeder."""
    
    hashed_password = auth.get_password_hash(user.password)
    db_user = models.User(email=user.email, hashed_password=hashed_password)
    
    try:
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        return db_user
    except IntegrityError:
        # Eğer commit sırasında kısıtlama hatası olursa (örn: unique email ihlali)
        db.rollback() 
        # Bu hata zaten routers/users.py'de yakalanmalı, ancak ekstra güvenlik için rollback yapıldı.
        return None 
    except Exception as e:
        db.rollback()
        # Diğer hatalar için
        print(f"Kullanıcı oluşturulurken beklenmedik hata: {e}")
        raise # Hatayı yukarı fırlat
        
# --- Pin (Kaynak) İşlemleri ---

def get_pins_by_owner(db: Session, user_id: int):
    """Belirli bir kullanıcıya ait tüm pinleri (kaynakları) döndürür."""
    return db.query(models.Pin).filter(models.Pin.owner_id == user_id).all()

def create_user_pin(db: Session, pin: schemas.PinBase, user_id: int):
    """Belirli bir kullanıcı için haritaya yeni bir pin ekler."""
    
    # PinBase şemasından gelen verileri models.Pin'e dönüştürürken user_id'yi ekle
    db_pin = models.Pin(
        owner_id=user_id,
        latitude=pin.latitude,
        longitude=pin.longitude,
        name=pin.name,
        type=pin.type,
        capacity_mw=pin.capacity_mw
    )
    
    db.add(db_pin)
    db.commit()
    db.refresh(db_pin)
    return db_pin

def delete_user_pin(db: Session, pin_id: int, user_id: int):
    """Belirli bir kullanıcıya ait bir pini siler."""
    
    # Pini bul ve kullanıcının sahibi olduğunu doğrula
    db_pin = db.query(models.Pin).filter(
        models.Pin.id == pin_id,
        models.Pin.owner_id == user_id
    ).first()
    
    if db_pin:
        db.delete(db_pin)
        db.commit()
        return True # Başarılı
    return False # Pin bulunamadı veya kullanıcıya ait değil
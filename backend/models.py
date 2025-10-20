from sqlalchemy import Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship
from database import Base # Doğrudan import

# Kullanıcı tablosu
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    
    # Kullanıcının sahip olduğu tüm pinleri temsil eder
    pins = relationship("Pin", back_populates="owner")

# Pin/Resource tablosu
class Pin(Base):
    __tablename__ = "pins"

    id = Column(Integer, primary_key=True, index=True)
    # Temel Konum Bilgileri
    latitude = Column(Float)
    longitude = Column(Float)
    
    # Kaynak Bilgileri (Hesaplama için gerekli)
    name = Column(String, index=True, default="Yeni Kaynak")
    type = Column(String, default="Güneş Paneli") # Örn: "Güneş Paneli", "Rüzgar Türbini"
    capacity_mw = Column(Float, default=1.0) # Varsayılan Kapasite
    
    # Yabancı Anahtar: Hangi kullanıcıya ait olduğunu gösterir
    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="pins")

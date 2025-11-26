from sqlalchemy import Column, Integer, String, Float, ForeignKey, Boolean, JSON, ARRAY
from sqlalchemy.orm import relationship
from .database import Base

# --- GÜNEŞ PANELİ TABLOSU ---
class SolarPanel(Base):
    __tablename__ = "solar_panels"
    
    id = Column(Integer, primary_key=True, index=True)
    model_name = Column(String, index=True, unique=True)
    power_rating_w = Column(Float)
    dimensions_m = Column(JSON)  # {"length": float, "width": float}
    base_efficiency = Column(Float)
    temp_coefficient = Column(Float)
    is_default = Column(Boolean, default=False)
    
    # Bu panel modelini kullanan pinler
    pins = relationship("Pin", back_populates="panel_model")

# Kullanıcı tablosu (Değişiklik yok)
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    
    pins = relationship("Pin", back_populates="owner")

# --- YENİ TABLO ---
# PNG'deki "özellikleri girme" ve "standart rüzgar gülü" istekleri için
class Turbine(Base):
    __tablename__ = "turbines"
    
    id = Column(Integer, primary_key=True, index=True)
    model_name = Column(String, index=True, unique=True)
    rated_power_kw = Column(Float)
    is_default = Column(Boolean, default=False) # Standart türbini belirlemek için
    
    # Güç eğrisini (Power Curve) JSON olarak saklayacağız
    # Format: {"3": 0, "4": 70, "5": 150 ...}
    power_curve_data = Column(JSON) 
    
    # Bu türbini kullanan pinler
    pins = relationship("Pin", back_populates="turbine_model")


# Pin/Resource tablosu (Güncellendi)
class Pin(Base):
    __tablename__ = "pins"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    latitude = Column(Float)
    longitude = Column(Float)
    
    avg_solar_irradiance = Column(Float, nullable=True)
    
    name = Column(String, index=True, default="Yeni Kaynak")
    # "Rüzgar Türbini" veya "Güneş Paneli"
    type = Column(String, default="Güneş Paneli")
    capacity_mw = Column(Float, default=1.0)
    
    # --- YENİ SÜTUNLAR (GÜNEŞ PANELİ İÇİN) ---
    panel_tilt = Column(Float, nullable=True)  # Panel eğim açısı (derece)
    panel_azimuth = Column(Float, nullable=True)  # Yön açısı (derece)
    panel_area = Column(Float, nullable=True)  # Toplam panel alanı (m²)
    
    # Sahip (Kullanıcı) ilişkisi
    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="pins")
    
    # Türbin model ilişkisi (opsiyonel)
    turbine_model_id = Column(Integer, ForeignKey("turbines.id"), nullable=True)
    turbine_model = relationship("Turbine", back_populates="pins")
    
    # Panel model ilişkisi (opsiyonel)
    panel_model_id = Column(Integer, ForeignKey("solar_panels.id"), nullable=True)
    panel_model = relationship("SolarPanel", back_populates="pins")

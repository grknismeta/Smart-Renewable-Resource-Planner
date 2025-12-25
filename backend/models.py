from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, JSON, Boolean, Text, Date
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import UserBase, SystemBase

# ===============================================
# A) KULLANICI VERİTABANI (UserBase) Modelleri
# ===============================================

class User(UserBase):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    pins = relationship("Pin", back_populates="owner")
    scenarios = relationship("Scenario", back_populates="owner")

class Pin(UserBase):
    __tablename__ = "pins"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True, nullable=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    type = Column(String, default="Güneş Paneli") 
    capacity_mw = Column(Float, default=1.0)
    panel_area = Column(Float, nullable=True)
    
    avg_solar_irradiance = Column(Float, nullable=True)
    avg_wind_speed = Column(Float, nullable=True)

    # Equipment (SystemDB) ile ilişki ID üzerinden manuel kurulacak
    equipment_id = Column(Integer, nullable=True)

    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="pins")
    
    analysis = relationship("PinAnalysis", back_populates="pin", uselist=False, cascade="all, delete-orphan")
    scenarios = relationship("Scenario", back_populates="pin", cascade="all, delete-orphan", foreign_keys="Scenario.pin_id", passive_deletes=True)

    # --- LEGACY UYUMLULUK (Eski router'ların patlamaması için geçici) ---
    # Eski kodlar pin.turbine_model_id ararsa hata almamaları için:
    # turbine_model_id = Column(Integer, nullable=True) 
    # panel_model_id = Column(Integer, nullable=True)

class PinAnalysis(UserBase):
    __tablename__ = "pin_analyses"
    id = Column(Integer, primary_key=True, index=True)
    pin_id = Column(Integer, ForeignKey("pins.id"), unique=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    result_data = Column(JSON)
    pin = relationship("Pin", back_populates="analysis")

class Scenario(UserBase):
    __tablename__ = "scenarios"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    description = Column(Text, nullable=True)
    # Geriye dönük uyumluluk için pin_id kalsın (nullable)
    pin_id = Column(Integer, ForeignKey("pins.id"), nullable=True)
    pin = relationship("Pin", back_populates="scenarios")
    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="scenarios")
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)
    result_data = Column(JSON) 
    created_at = Column(DateTime(timezone=True), server_default=func.now())

# ===============================================
# B) SİSTEM VERİTABANI (SystemBase) Modelleri
# ===============================================

class Equipment(SystemBase): 
    __tablename__ = "equipments"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    type = Column(String) 
    rated_power_kw = Column(Float)
    efficiency = Column(Float)
    specs = Column(JSON) 
    cost_per_unit = Column(Float)
    maintenance_cost_annual = Column(Float)

class GridAnalysis(SystemBase):
    __tablename__ = "grid_analyses"
    id = Column(Integer, primary_key=True, index=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    type = Column(String, index=True, nullable=False)
    annual_potential_kwh_m2 = Column(Float, nullable=True)
    avg_wind_speed_ms = Column(Float, nullable=True)
    logistics_score = Column(Float, default=1.0) 
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    predicted_monthly_data = Column(JSON)
    overall_score = Column(Float, index=True, default=0.0)

# --- EKLENEN KISIM: Veri Çekme Motoru İçin Gerekli ---
class WeatherData(SystemBase):
    __tablename__ = "weather_data"
    
    id = Column(Integer, primary_key=True, index=True)
    latitude = Column(Float, index=True)
    longitude = Column(Float, index=True)
    date = Column(Date, index=True)
    
    # Güneş
    shortwave_radiation_sum = Column(Float) 
    # Rüzgar
    wind_speed_mean = Column(Float)
    wind_speed_max = Column(Float)
    wind_direction_dominant = Column(Float)
    # Genel
    temperature_mean = Column(Float)


# --- ŞEHİR BAZLI SAATLİK VERİ ---
class HourlyWeatherData(SystemBase):
    """81 il için saatlik hava durumu verisi"""
    __tablename__ = "hourly_weather_data"
    
    id = Column(Integer, primary_key=True, index=True)
    city_name = Column(String, index=True)  # Şehir adı
    latitude = Column(Float)
    longitude = Column(Float)
    timestamp = Column(DateTime, index=True)  # Saat bazlı zaman damgası
    
    # Sıcaklık
    temperature_2m = Column(Float)  # °C
    apparent_temperature = Column(Float)  # Hissedilen sıcaklık
    
    # Rüzgar
    wind_speed_10m = Column(Float)  # m/s
    wind_speed_100m = Column(Float)  # m/s (türbin yüksekliği)
    wind_direction_10m = Column(Float)  # derece
    wind_gusts_10m = Column(Float)  # Rüzgar hamleleri
    
    # Güneş
    shortwave_radiation = Column(Float)  # W/m²
    direct_radiation = Column(Float)  # W/m²
    diffuse_radiation = Column(Float)  # W/m²
    
    # Nem ve Bulut
    relative_humidity_2m = Column(Float)  # %
    cloud_cover = Column(Float)  # %
    
    # Yağış
    precipitation = Column(Float)  # mm


# --- LEGACY MODELLER (Eski Routers'ı kurtarmak için) ---
# backend/routers/turbines.py ve solar_panels.py dosyaları hala bunları import ediyor.
# Projeyi refactor edene kadar bunları silmemeliyiz.
class SolarPanel(SystemBase):
    __tablename__ = "legacy_solar_panels" # Tablo adı çakışmasın
    id = Column(Integer, primary_key=True, index=True)
    model_name = Column(String)
    is_default = Column(Boolean, default=False)

class Turbine(SystemBase):
    __tablename__ = "legacy_turbines"
    id = Column(Integer, primary_key=True, index=True)
    model_name = Column(String)
    is_default = Column(Boolean, default=False)
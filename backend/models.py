from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, JSON, Boolean, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    pins = relationship("Pin", back_populates="owner")
    scenarios = relationship("Scenario", back_populates="owner")

class Equipment(Base):
    __tablename__ = "equipments"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    type = Column(String) 
    rated_power_kw = Column(Float)
    efficiency = Column(Float)
    specs = Column(JSON) 
    cost_per_unit = Column(Float)
    maintenance_cost_annual = Column(Float)

class Pin(Base):
    __tablename__ = "pins"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True, nullable=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    type = Column(String, default="Güneş Paneli") 
    capacity_mw = Column(Float, default=1.0)
    panel_area = Column(Float, nullable=True)
    
    # Hızlı Önizleme Verisi
    avg_solar_irradiance = Column(Float, nullable=True)
    avg_wind_speed = Column(Float, nullable=True)

    # --- BU KISIM EKSİK OLABİLİR ---
    equipment_id = Column(Integer, ForeignKey("equipments.id"), nullable=True)
    equipment = relationship("Equipment")
    # -------------------------------

    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="pins")
    
    analysis = relationship("PinAnalysis", back_populates="pin", uselist=False, cascade="all, delete-orphan")
    scenarios = relationship("Scenario", back_populates="pin")

class PinAnalysis(Base):
    __tablename__ = "pin_analyses"
    id = Column(Integer, primary_key=True, index=True)
    pin_id = Column(Integer, ForeignKey("pins.id"), unique=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    result_data = Column(JSON)
    pin = relationship("Pin", back_populates="analysis")

class Scenario(Base):
    __tablename__ = "scenarios"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    description = Column(Text, nullable=True)
    pin_id = Column(Integer, ForeignKey("pins.id"))
    pin = relationship("Pin", back_populates="scenarios")
    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="scenarios")
    start_date = Column(DateTime)
    end_date = Column(DateTime)
    result_data = Column(JSON) 
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class GridAnalysis(Base):
    """
    Tüm Türkiye'yi tarayarak elde edilen coğrafi analiz ve potansiyel önbelleği.
    Akıllı öneri sistemi bu veriyi kullanır.
    """
    __tablename__ = "grid_analyses" # <-- Bu zorunludur

    id = Column(Integer, primary_key=True, index=True)
    
    # Grid Noktası Koordinatları
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    
    # Analiz Tipi: Solar veya Wind
    type = Column(String, index=True, nullable=False)
    
    # Özet Skorlar
    annual_potential_kwh_m2 = Column(Float, nullable=True)
    avg_wind_speed_ms = Column(Float, nullable=True)
    
    # Coğrafi Kısıtlama Skorları
    logistics_score = Column(Float, default=1.0) 
    
    # Tahmin Verisinin En Son Güncellenme Tarihi
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Gelecek Tahmini (ML) Verisi (Aylık döküm, JSON olarak)
    predicted_monthly_data = Column(JSON)
    
    # Verimlilik Sıralaması için Hızlı Erişim Skoru
    overall_score = Column(Float, index=True, default=0.0)
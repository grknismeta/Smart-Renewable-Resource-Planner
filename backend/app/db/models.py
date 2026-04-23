from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, JSON, Boolean, Text, Date, Index, UniqueConstraint
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

    # HES (Hidroelektrik) spesifik alanlar
    flow_rate = Column(Float, nullable=True)        # Debi (m³/s)
    head_height = Column(Float, nullable=True)      # Düşü yüksekliği (m)
    basin_area_km2 = Column(Float, nullable=True)   # Havza alanı (km²)

    # Konum bilgisi (Reverse geocoding — pin oluşturulurken bir kez kaydedilir)
    city = Column(String, nullable=True)           # İl (örn. "Adıyaman")
    district = Column(String, nullable=True)       # İlçe (örn. "Merkez")
    water_body_name = Column(String, nullable=True) # HES için göl/nehir adı

    # Equipment (SystemDB) ile ilişki ID üzerinden manuel kurulacak
    equipment_id = Column(Integer, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="pins")
    
    analysis = relationship("PinAnalysis", back_populates="pin", uselist=False, cascade="all, delete-orphan")
    scenarios = relationship("Scenario", back_populates="pin", cascade="all, delete-orphan", foreign_keys="Scenario.pin_id", passive_deletes=True)

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
    
    # Yeni çoklu pin desteği
    pin_ids = Column(JSON, nullable=True) 
    
    # Geriye dönük uyumluluk için pin_id kalsın (nullable)
    pin_id = Column(Integer, ForeignKey("pins.id"), nullable=True)
    pin = relationship("Pin", back_populates="scenarios")
    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="scenarios")
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)
    result_data = Column(JSON)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Enerji depolama (Feature E)
    battery_capacity_kwh = Column(Float, nullable=True)      # kWh — 0 veya None = depolama yok
    battery_efficiency_pct = Column(Float, nullable=True)    # Şarj/deşarj verimi (0-100), tipik 90
    battery_cost_usd_per_kwh = Column(Float, nullable=True)  # Maliyet $/kWh, tipik 300

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

    # Konum (backfill scripti ve merge tarafından doldurulur)
    province_name = Column(String, index=True, nullable=True)
    district_name = Column(String, index=True, nullable=True)

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
    """81 il ve ilçeler için saatlik hava durumu verisi"""
    __tablename__ = "hourly_weather_data"
    __table_args__ = (
        Index('ix_hourly_lat_lon_ts', 'latitude', 'longitude', 'timestamp'),
        {'extend_existing': True},
    )

    id = Column(Integer, primary_key=True, index=True)
    city_name = Column(String, index=True)  # Şehir adı (İl)
    district_name = Column(String, index=True, nullable=True)  # İlçe adı
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

    # Konum kodu (ör. "ist0" = İstanbul il, "ist14" = Kadıköy)
    location_code = Column(String(10), nullable=True, index=True)


# --- İL × KAYNAK SKOR TABLOSU (Faz 1 — Tek Kaynak) ---
class ProvinceAnalysis(SystemBase):
    """
    81 il × 3 kaynak (wind/solar/hydro) için ön-hesaplanmış skorlar.
    Raporlar, İl Analizi, Önerilen Bölgeler ve Choropleth bu tablodan beslenir.
    Saatlik scheduler tetiklemesi sonrası yeniden hesaplanır (incremental).
    """
    __tablename__ = "province_analysis"
    __table_args__ = (
        UniqueConstraint("province_name", "resource_type", name="uq_province_resource"),
        Index("ix_province_analysis_type_score6m", "resource_type", "score_6m"),
    )

    id = Column(Integer, primary_key=True, index=True)
    province_name = Column(String, nullable=False, index=True)
    resource_type = Column(String, nullable=False, index=True)  # wind | solar | hydro

    # Normalize 0-100 skorlar (4 pencere: 30 / 90 / 180 / 365 gün)
    score_1m = Column(Float, nullable=True)
    score_3m = Column(Float, nullable=True)
    score_6m = Column(Float, nullable=True)
    score_yearly = Column(Float, nullable=True)

    # Ham metrikler (debug / detay ekranları için)
    avg_wind_speed = Column(Float, nullable=True)           # m/s @ 100m
    avg_solar_radiation = Column(Float, nullable=True)      # W/m² shortwave
    avg_temperature = Column(Float, nullable=True)          # °C
    capacity_factor = Column(Float, nullable=True)          # 0-1

    sample_count = Column(Integer, nullable=True)           # kaç saatlik kayıttan üretildi
    computed_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


# --- SCHEDULER META (son çalışma zamanı — "228 dk önce" fix) ---
class SchedulerMeta(SystemBase):
    """
    APScheduler iş'lerinin son çalışma bilgisi.
    /system/status endpoint'i bu tablodan last_run_at okur.
    """
    __tablename__ = "scheduler_meta"

    id = Column(Integer, primary_key=True, index=True)
    job_name = Column(String, unique=True, nullable=False, index=True)
    last_run_at = Column(DateTime(timezone=True), nullable=True)
    next_run_at = Column(DateTime(timezone=True), nullable=True)
    last_status = Column(String, nullable=True)             # ok | fail | running
    last_duration_seconds = Column(Float, nullable=True)
    last_error = Column(Text, nullable=True)
    run_count = Column(Integer, default=0)


# ===============================================
# C) KULLANICI PIN VERİLERİ (UserPinsBase) - user_pins_data.db
# ===============================================
from .database import UserPinsBase

class PinCalculationResult(UserPinsBase):
    """
    Kullanıcıların haritaya koyduğu pinler için hesaplanan detaylı sonuçlar.
    Her hesaplamada burası güncellenir veya yeni kayıt atılır.
    """
    __tablename__ = "pin_calculation_results"

    id = Column(Integer, primary_key=True, index=True)
    pin_id = Column(Integer, index=True) # UserDB'deki Pin ID'si (Loose Coupling)
    latitude = Column(Float)
    longitude = Column(Float)
    
    calculated_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Yıllık Toplamlar
    annual_total_energy_kwh = Column(Float, default=0.0) # Üretilen toplam enerji tahmin
    capacity_factor = Column(Float, default=0.0)
    
    # İklim Verileri (Özet)
    avg_wind_speed = Column(Float, nullable=True)
    avg_solar_irradiance = Column(Float, nullable=True) # kWh/m2/day
    avg_temperature = Column(Float, nullable=True)
    
    # Detaylı Aylık Veri (JSON)
    # Format: 
    # [
    #   {"month": 1, "avg_wind": 5.2, "avg_solar": 2.1, "avg_temp": 4.5, "energy_kwh": 350.0},
    #   ...
    # ]
    monthly_data = Column(JSON)

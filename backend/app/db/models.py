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
    full_name = Column(String, nullable=True)  # 2026-06-01 (AUTH-1): ad soyad
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

    # 2026-05-17 Sprint A — Gelişmiş Ayarlar manuel parametre alanları
    # GES (Güneş Paneli):
    panel_tilt = Column(Float, nullable=True)       # Panel eğim açısı (°), 0-90
    panel_azimuth = Column(Float, nullable=True)    # Panel azimuth (°), 0-360 (180=güney)
    panel_power_w = Column(Float, nullable=True)    # Tek panel rated power (W)
    # RES (Rüzgar Türbini):
    hub_height = Column(Float, nullable=True)       # Kule yüksekliği (m)
    rotor_diameter = Column(Float, nullable=True)   # Rotor çapı (m)
    rated_power_kw = Column(Float, nullable=True)   # Türbin nominal güç (kW)

    # Konum bilgisi (Reverse geocoding — pin oluşturulurken bir kez kaydedilir)
    city = Column(String, nullable=True)           # İl (örn. "Adıyaman")
    district = Column(String, nullable=True)       # İlçe (örn. "Merkez")
    water_body_name = Column(String, nullable=True) # HES için göl/nehir adı

    # Equipment (SystemDB) ile ilişki ID üzerinden manuel kurulacak
    equipment_id = Column(Integer, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    # 2026-05-17 S1 — Santralin gerçek kuruluş tarihi.
    # Pin generation history bu tarihten itibaren hesaplanır. NULL ise
    # `created_at` kullanılır (geriye uyum). Migration 015.
    installation_date = Column(DateTime(timezone=True), nullable=True)

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
    # 2026-05-17 Sprint A — User-aware equipment.
    # NULL  = sistem ekipmanı (varsayılan kütüphane, tüm kullanıcılar görür)
    # Dolu  = kullanıcının kendi eklediği (sadece o kullanıcı görür)
    # FK kurmuyoruz — SystemBase vs UserBase ayrı veritabanı olabilir.
    owner_id = Column(Integer, nullable=True, index=True)
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
    # M-E.1 (2026-05-28): precipitation/cloud/humidity Open-Meteo Historical backfill
    precipitation_sum = Column(Float, nullable=True)        # mm/gün
    cloud_cover_mean = Column(Float, nullable=True)         # %
    relative_humidity_mean = Column(Float, nullable=True)   # %


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


# --- CLIMATOLOGY (S1 — 2026-05-17) ---
class Climatology(SystemBase):
    """
    10+ yıl günlük + 2 yıl saatlik veriden tek seferlik hesaplanan iklim
    metrikleri. 81 il × 3 tip × (opsiyonel ilçe) = ~243 il satırı + ~2880
    ilçe satırı. 6 ayda bir refresh job ile güncellenir.

    `province_analysis` deprecate edildi; mevcut endpoint'ler bu tablodan
    okur. Manisa örneği: bölge karakteri statik kalır, son ay az rüzgar
    diye listeden düşmez.

    Migration: 015_climatology_and_pin_install_date
    Plan: BACKEND-PLAN-2026-05-17.md S1
    """
    __tablename__ = "climatology"
    __table_args__ = (
        UniqueConstraint(
            "province_name", "district_name", "resource_type",
            name="uq_climatology_loc_resource",
        ),
        Index("ix_climatology_type_score",
              "resource_type", "score_climatology"),
    )

    id = Column(Integer, primary_key=True, index=True)
    province_name = Column(String, nullable=False, index=True)
    # district_name NULL = il bazlı toplam; dolu = belirli ilçe
    district_name = Column(String, nullable=True, index=True)
    resource_type = Column(String, nullable=False, index=True)  # wind|solar|hydro

    # Rüzgar metrikleri
    avg_wind_speed_10y = Column(Float, nullable=True)   # m/s @ 100m
    weibull_k = Column(Float, nullable=True)            # şekil (süreklilik)
    weibull_c = Column(Float, nullable=True)            # skala

    # Güneş metrikleri
    avg_solar_irradiance_10y = Column(Float, nullable=True)  # kWh/m²/yıl
    avg_ghi_wm2 = Column(Float, nullable=True)               # W/m² ortalama

    # Termal / genel
    avg_temperature_10y = Column(Float, nullable=True)  # °C
    seasonal_variance = Column(Float, nullable=True)    # 0-1 normalize

    # Teknik üretkenlik (kaynak tipine göre formül)
    capacity_factor = Column(Float, nullable=True)  # 0-1

    # 12 ay × 24 saat tipik profil (Pin generation interpolasyonu için)
    hourly_typical_profile = Column(JSON, nullable=True)

    # ── v3 Raporlar için aylık seriler (Migration 016, 2026-05-20) ──
    # Open-Meteo'dan R0 Colab tarafından çekilir.
    # wind_direction_histogram: {"0": {"N": freq_pct, "NE": ..., }, "1": {...}, ... "12": {...}}
    #   Key 0 = yıllık ortalama, 1-12 = aylar
    wind_direction_histogram = Column(JSON, nullable=True)
    # monthly_precipitation: [jan_mm, feb_mm, ..., dec_mm] — 12 değer (10 yıl ort.)
    monthly_precipitation = Column(JSON, nullable=True)
    # monthly_cloud_cover: [jan_pct, ..., dec_pct] — 12 değer
    monthly_cloud_cover = Column(JSON, nullable=True)
    # monthly_sunshine_hours: [jan_h, ..., dec_h] — 12 değer (10 yıl ort.)
    monthly_sunshine_hours = Column(JSON, nullable=True)
    # monthly_river_discharge: [{"mean": .., "min": .., "max": ..}, ...] — 12 obje
    monthly_river_discharge = Column(JSON, nullable=True)

    # Multi-criteria skor (statik, climatology bazlı)
    score_climatology = Column(Float, nullable=True)  # 0-100

    # Meta
    sample_count_daily = Column(Integer, nullable=True)
    sample_count_hourly = Column(Integer, nullable=True)
    data_start_date = Column(DateTime(timezone=True), nullable=True)
    data_end_date = Column(DateTime(timezone=True), nullable=True)
    computed_at = Column(DateTime(timezone=True),
                         server_default=func.now(), onupdate=func.now())


# --- ML PRECOMPUTE FORECAST (Sprint M-A, 2026-05-28) ---
class MlForecast(SystemBase):
    """Önceden hesaplanmış iklim projeksiyonu — batch job çıktısı.

    `build_ml_forecasts.py` tüm il + ilçe × metrik × senaryo kombinasyonları
    için SARIMAX/Holt-Winters çalıştırıp en iyi modeli seçer ve sonucu buraya
    yazar. Tematik harita + Projeksiyon tab bu tablodan **anında** okur (model
    fit beklemez).

    Bilimsel çerçeve: aylık iklim normali + uzun-vade trend + RCP senaryo.
    "Günlük hava tahmini" DEĞİL (kaos ufku ~14 gün); günlük gösterim aylık
    değerden mevsimsel interpolasyonla üretilir.

    Granülerlik: aylık. Anahtar = (scope, province, district, resource, metric,
    scenario, year, month).

    Migration: 017_ml_forecast
    Plan: PLAN-2026-05-28-ML-CLIMATE-PROJECTION.md
    """
    __tablename__ = "ml_forecast"
    __table_args__ = (
        UniqueConstraint(
            "scope", "province_name", "district_name", "resource",
            "metric", "scenario", "year", "month",
            name="uq_ml_forecast_key",
            # 2026-06-02 (ML-1 fix): PG varsayılanı NULL'ları DISTINCT sayar →
            # il-scope satırları (district_name NULL) on_conflict ile asla
            # tekilleşmiyordu → her precompute koşusu il satırlarını TEKRAR
            # ekliyordu (kirlilik). NULLS NOT DISTINCT (PG15+) ile NULL'lar eşit
            # sayılır → upsert il satırlarında da çalışır.
            postgresql_nulls_not_distinct=True,
        ),
        # Choropleth sorgusu: belirli metrik+senaryo+yıl için tüm iller
        Index("ix_ml_forecast_choropleth",
              "scope", "metric", "scenario", "year"),
        Index("ix_ml_forecast_location",
              "province_name", "district_name", "resource", "metric"),
    )

    id = Column(Integer, primary_key=True, index=True)
    # "province" = il bazlı toplam; "district" = ilçe
    scope = Column(String, nullable=False, index=True)
    province_name = Column(String, nullable=False, index=True)
    district_name = Column(String, nullable=True, index=True)
    resource = Column(String, nullable=False)   # solar | wind | hydro
    metric = Column(String, nullable=False)     # sunshine|precipitation|cloud|discharge
    scenario = Column(String, nullable=False, default="baseline")  # baseline|rcp45|rcp85

    year = Column(Integer, nullable=False)
    month = Column(Integer, nullable=False)     # 1-12

    value = Column(Float, nullable=False)
    lower = Column(Float, nullable=True)        # 95% CI alt
    upper = Column(Float, nullable=True)        # 95% CI üst

    # Model meta (en iyi seçilen)
    method = Column(String, nullable=True)      # sarimax_auto|sarimax_default|holt_winters|linear_seasonal|fallback
    mape = Column(Float, nullable=True)         # holdout MAPE (model seçim skoru)

    computed_at = Column(DateTime(timezone=True),
                         server_default=func.now(), onupdate=func.now())


# --- TEMATİK HARİTA PRECOMPUTE AGREGAT (2026-05-28) ---
class ThematicAggregate(SystemBase):
    """Ayda bir hesaplanan ağır tematik harita pencereleri.

    `sixMonth / yearly / season / twoYear / fiveYear / tenYear` modları her
    istekte hesaplanmaz; `build_thematic_aggregates.py` aylık batch ile bu
    tabloyu doldurur, choropleth endpoint buradan **anında** okur.

    Veri kaynağı hibrit: yakın dönem `hourly_weather_data` (saatlik), eski
    dönem `weather_data` (günlük). Batch bu farkı yönetir.

    Anahtar = (scope, location_key, metric, mode, season).
    - scope: "province" | "district"
    - location_key: il adı (province) veya "İl|İlçe" (district)
    - metric: "wind" | "solar" | "temp"
    - mode: sixMonth|yearly|season|twoYear|fiveYear|tenYear
    - season: winter|spring|summer|autumn (sadece mode=season) yoksa "-"

    Migration: 018_thematic_aggregate
    Plan: PLAN-2026-05-28-ML-CLIMATE-PROJECTION.md (T sprint)
    """
    __tablename__ = "thematic_aggregate"
    __table_args__ = (
        UniqueConstraint(
            "scope", "location_key", "metric", "mode", "season",
            name="uq_thematic_aggregate_key",
        ),
        Index("ix_thematic_aggregate_lookup",
              "scope", "metric", "mode", "season"),
    )

    id = Column(Integer, primary_key=True, index=True)
    scope = Column(String, nullable=False, index=True)
    location_key = Column(String, nullable=False, index=True)
    metric = Column(String, nullable=False)
    mode = Column(String, nullable=False)
    season = Column(String, nullable=False, default="-")

    value = Column(Float, nullable=True)
    sample_count = Column(Integer, nullable=True)
    source = Column(String, nullable=True)  # hourly | daily | hybrid
    computed_at = Column(DateTime(timezone=True),
                         server_default=func.now(), onupdate=func.now())


# --- TEMATİK ZAMAN-SERİSİ PRECOMPUTE (T-6, 2026-05-28) ---
class ThematicTimeseries(SystemBase):
    """Zaman simülasyonu uzun pencereleri için hafta/ay başına precompute.

    `thematic_aggregate` tek-pencere ORTALAMASI tutar (choropleth için). Zaman
    simülasyonu ise her hafta/ay için AYRI frame ister (2y/5y/10y haftalık veya
    aylık adımlama). Bu tablo o frame'leri önceden hesaplar — animasyon her
    istekte milyonlarca satır taramaz.

    `build_thematic_timeseries.py` aylık batch ile doldurur (date_trunc GROUP BY).
    Kaynak hibrit: yakın saatlik, eski günlük (build script yönetir).

    Anahtar = (scope, location_key, metric, period_type, period_start).
    - period_type: "month" | "week"
    - period_start: ilgili ay/haftanın ilk günü (Date)

    Migration: 019_thematic_timeseries
    Plan: PLAN-2026-05-28-ML-CLIMATE-PROJECTION.md (T-6)
    """
    __tablename__ = "thematic_timeseries"
    __table_args__ = (
        UniqueConstraint(
            "scope", "location_key", "metric", "period_type", "period_start",
            name="uq_thematic_timeseries_key",
        ),
        Index("ix_thematic_timeseries_lookup",
              "scope", "metric", "period_type", "period_start"),
    )

    id = Column(Integer, primary_key=True, index=True)
    scope = Column(String, nullable=False, index=True)
    location_key = Column(String, nullable=False, index=True)
    metric = Column(String, nullable=False)        # wind | solar | temp
    period_type = Column(String, nullable=False)   # month | week
    period_start = Column(Date, nullable=False, index=True)

    value = Column(Float, nullable=True)
    source = Column(String, nullable=True)         # hourly | daily
    computed_at = Column(DateTime(timezone=True),
                         server_default=func.now(), onupdate=func.now())


# --- UZUN-VADE AYLIK İKLİM (M-E.2, 2026-05-30) ---
class MonthlyClimate(SystemBase):
    """20 yıllık il-bazlı aylık iklim serisi (Open-Meteo Archive, 2005→bugün).

    weather_data sadece 2015'ten ve ilçe bazlı; ML trend sinyali için kısa.
    Bu tablo 81 il için 2005-2026 ayını **tek API çağrısı/il** ile çeker
    (günlük → aylık lokal toplulaştırma). Tüm metrikler aynı satırda:
    precip + cloud + radiation + wind + temp → hem M-E.2 (uzun trend) hem
    M-G.2 (cloud×radiation exog) tek kaynaktan beslenir.

    Granülerlik: aylık, il bazlı (ilçe YOK — ilçe ML günlük aggregate kullanır).
    Anahtar = (province_name, year, month).

    Kaynak: archive-api.open-meteo.com (ücretsiz, ~1 req/sn).
    Plan: PLAN-2026-05-28-ML-CLIMATE-PROJECTION.md (M-E.2)
    """
    __tablename__ = "monthly_climate"
    __table_args__ = (
        UniqueConstraint("province_name", "year", "month",
                         name="uq_monthly_climate_key"),
        Index("ix_monthly_climate_lookup", "province_name", "year", "month"),
    )

    id = Column(Integer, primary_key=True, index=True)
    province_name = Column(String, nullable=False, index=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    year = Column(Integer, nullable=False)
    month = Column(Integer, nullable=False)   # 1-12

    # Aylık toplulaştırılmış metrikler
    precipitation_sum = Column(Float, nullable=True)        # ay toplamı (mm)
    cloud_cover_mean = Column(Float, nullable=True)         # ay ort (%)
    relative_humidity_mean = Column(Float, nullable=True)   # ay ort (%)
    shortwave_radiation_sum = Column(Float, nullable=True)  # günlük sum ay ort (MJ/m²)
    wind_speed_mean = Column(Float, nullable=True)          # ay ort (m/s veya km/h)
    temperature_mean = Column(Float, nullable=True)         # ay ort (°C)
    sunshine_hours = Column(Float, nullable=True)           # ay toplamı (saat)

    n_days = Column(Integer, nullable=True)                 # toplulaştırılan gün sayısı
    source = Column(String, nullable=True, default="open-meteo-archive")
    computed_at = Column(DateTime(timezone=True),
                         server_default=func.now(), onupdate=func.now())


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

import re
from pydantic import BaseModel, Field, field_validator, model_validator
from typing import List, Optional, Dict, Literal, Any
from datetime import datetime, date

# 2026-06-01 (güvenlik): basit e-posta format regex'i. EmailStr yerine regex —
# `email-validator` paket bağımlılığı eklemeden çalışır. Login eşleşmesini
# bozmamak için lowercase YAPMIYORUZ (yalnız strip + format).
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

# --- AUTH & USER ---
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

class UserBase(BaseModel):
    email: str
    full_name: Optional[str] = None  # 2026-06-01 (AUTH-1): ad soyad

class UserCreate(UserBase):
    password: str

    # 2026-06-02 (fix): E-posta validasyonu UserBase'den BURAYA taşındı. UserBase'de
    # iken UserResponse'u da (okuma) etkiliyordu; DB'de eski/geçersiz e-posta
    # (ör. "user") olan kullanıcı /users/me'de 500 (ResponseValidationError)
    # veriyordu. Validasyon yalnız KAYIT girişinde anlamlı.
    @field_validator("email")
    @classmethod
    def _validate_email(cls, v: str) -> str:
        v = (v or "").strip()
        if not _EMAIL_RE.match(v):
            raise ValueError("Geçerli bir e-posta adresi girin.")
        return v

    @field_validator("password")
    @classmethod
    def _validate_password(cls, v: str) -> str:
        # 2026-06-01 (güvenlik): minimum parola uzunluğu. Yalnız KAYIT'ta
        # geçerli — mevcut kullanıcı login'ini etkilemez.
        if v is None or len(v) < 8:
            raise ValueError("Parola en az 8 karakter olmalı.")
        return v

class UserResponse(UserBase):
    id: int
    is_active: bool
    created_at: Optional[datetime] = None
    class Config:
        from_attributes = True

# AUTH-3 (2026-06-01): Google ID-token ile giriş isteği.
class GoogleAuthRequest(BaseModel):
    id_token: str

# HESABIM (2026-06-02): profil güncelleme — şimdilik yalnız ad-soyad düzenlenir.
# E-posta login anahtarı olduğu için burada değiştirilmez (ayrı/ileride akış).
class UserUpdate(BaseModel):
    full_name: Optional[str] = None

# HESABIM (2026-06-02): parola değiştirme. new_password min-8 (kayıttaki kuralla aynı).
class PasswordChange(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _validate_new_password(cls, v: str) -> str:
        if v is None or len(v) < 8:
            raise ValueError("Yeni parola en az 8 karakter olmalı.")
        if len(v) > 72:
            raise ValueError("Yeni parola en fazla 72 karakter olabilir.")
        return v

# --- EKİPMAN ---
class EquipmentBase(BaseModel):
    name: str
    type: str
    rated_power_kw: float
    efficiency: Optional[float] = None
    cost_per_unit: Optional[float] = 0.0
    specs: Optional[Dict[str, Any]] = {}

class EquipmentCreate(EquipmentBase):
    pass

class EquipmentResponse(EquipmentBase):
    id: int
    # 2026-05-17 — owner_id None ise sistem ekipmanı, dolu ise kullanıcı-özel.
    # Frontend bu alana göre "kendi modelim mi sistem mi" ayrımı yapar.
    owner_id: Optional[int] = None
    class Config:
        from_attributes = True

# --- PIN (HARİTA İĞNESİ) ---
class PinBase(BaseModel):
    latitude: float
    longitude: float
    title: Optional[str] = "Yeni Kaynak"
    type: Literal["Güneş Paneli", "Rüzgar Türbini", "Hidroelektrik"] = "Güneş Paneli"
    capacity_mw: float = 1.0
    panel_area: Optional[float] = None
    equipment_id: Optional[int] = None
    # HES spesifik alanlar
    flow_rate: Optional[float] = None          # Debi (m³/s)
    head_height: Optional[float] = None        # Düşü yüksekliği (m)
    basin_area_km2: Optional[float] = None     # Havza alanı (km²)
    # 2026-05-17 Sprint A — Gelişmiş Ayarlar manuel parametreler.
    # GES (Güneş Paneli)
    panel_tilt: Optional[float] = None         # Panel eğim açısı (°)
    panel_azimuth: Optional[float] = None      # Panel azimuth (°)
    panel_power_w: Optional[float] = None      # Tek panel gücü (W)
    # RES (Rüzgar Türbini)
    hub_height: Optional[float] = None         # Kule yüksekliği (m)
    rotor_diameter: Optional[float] = None     # Rotor çapı (m)
    rated_power_kw: Optional[float] = None     # Nominal güç (kW)
    # Konum bilgisi (reverse geocoding — pin oluşturulurken frontend gönderir)
    city: Optional[str] = None                 # İl
    district: Optional[str] = None            # İlçe
    water_body_name: Optional[str] = None     # HES için göl/nehir adı

class PinCreate(PinBase):
    """Yeni pin oluşturma payload'ı.

    2026-05-25 (P2/6c): Frontend validation (PinDialogViewModel.validate)
    backend tarafından da zorlanır — direkt API çağrısıyla geçersiz pin
    kayıt edilmesin. Kurallar PinDialogViewModel ile birebir:
      - capacity_mw ≥ 0.001 (≈1 kW altı reddedilir)
      - HES: flow_rate > 0 ve head_height > 0 zorunlu
      - GES: panel_area ≥ 10 m² zorunlu (yoksa equipment_id ile hesaplanmalı)
    """

    @model_validator(mode="after")
    def _validate_capacity_and_type_fields(self) -> "PinCreate":
        if self.capacity_mw < 0.001:
            raise ValueError(
                f"capacity_mw çok düşük ({self.capacity_mw:.4f} MW). "
                "Minimum 0.001 MW (≈1 kW) olmalı."
            )
        if self.type == "Hidroelektrik":
            if not self.flow_rate or self.flow_rate <= 0:
                raise ValueError("HES için flow_rate (m³/s) zorunlu ve > 0 olmalı.")
            if not self.head_height or self.head_height <= 0:
                raise ValueError("HES için head_height (m) zorunlu ve > 0 olmalı.")
        elif self.type == "Güneş Paneli":
            if not self.panel_area or self.panel_area < 10:
                raise ValueError(
                    "GES için panel_area en az 10 m² olmalı "
                    f"(verilen: {self.panel_area})."
                )
        elif self.type == "Rüzgar Türbini":
            # RES capacity_mw equipment'tan hesaplanır, ≥ 0.001 yeterli (üstte check var).
            pass
        return self

class PinResponse(PinBase):
    id: int
    owner_id: int
    avg_solar_irradiance: Optional[float] = None
    avg_wind_speed: Optional[float] = None
    created_at: Optional[datetime] = None
    equipment_name: Optional[str] = None
    
    # Analiz sonuçlarını (varsa) döndürmek için
    analysis: Optional[Dict[str, Any]] = None 
    
    @field_validator('analysis', mode='before')
    @classmethod
    def parse_analysis(cls, v: Any) -> Optional[Dict[str, Any]]:
        # SQLalchemy modeli (PinAnalysis) gelirse içindeki JSON'ı al
        if hasattr(v, 'result_data'):
            return v.result_data
        # Zaten dict veya None ise olduğu gibi dön
        return v

    class Config:
        from_attributes = True

# --- HESAPLAMA SONUÇLARI (GRAFİK & FİNANS İÇİN) ---

class FinancialAnalysis(BaseModel):
    """Yatırım Geri Dönüş Analizi — Türkiye 2024-2025 YEKDEM/Piyasa değerleriyle"""
    initial_investment_usd: float
    annual_earnings_usd: float
    payback_period_years: float
    roi_percentage: float
    # ── Gelişmiş metrikler ─────────────────────────────────────────────────────
    lcoe_usd_kwh: float = 0.0           # Normalleştirilmiş Enerji Maliyeti ($/kWh)
    npv_usd: float = 0.0                # Net Bugünkü Değer — %8 iskonto oranıyla
    irr_percentage: float = 0.0         # İç Verim Oranı (%)
    lifetime_revenue_usd: float = 0.0   # Ömür boyu brüt gelir ($)
    pricing_mode: str = "yekdem"        # "yekdem" | "market"
    price_per_kwh_usd: float = 0.07     # İlk yıl birim fiyat ($/kWh)
    lifetime_years: int = 25            # Sistem ömrü (yıl)

class WindCalculationResponse(BaseModel):
    wind_speed_m_s: float
    power_output_kw: float
    turbine_model: str
    potential_kwh_annual: float
    capacity_factor: float
    # Grafik için aylık veri: {"Ocak": 500.5, "Şubat": 450.2 ...}
    monthly_production: Optional[Dict[str, float]] = None 
    financials: Optional[FinancialAnalysis] = None

class SolarCalculationResponse(BaseModel):
    solar_irradiance_kw_m2: float
    temperature_celsius: float
    panel_efficiency: float
    power_output_kw: float
    panel_model: str
    potential_kwh_annual: float
    performance_ratio: float
    # Grafik için aylık veri
    monthly_production: Optional[Dict[str, float]] = None
    financials: Optional[FinancialAnalysis] = None

class HydroCalculationResponse(BaseModel):
    """Hidroelektrik (HES) hesaplama sonuçları"""
    predicted_annual_production_kwh: float
    rated_power_kw: float
    avg_flow_rate_m3s: float
    gross_flow_rate_m3s: Optional[float] = None        # Brüt debi (can suyu kesintisi öncesi)
    environmental_flow_deducted: bool = True            # Can suyu kesintisi uygulandı mı?
    head_height_m: float
    turbine_type: str
    turbine_efficiency: float
    turbine_description: str
    suggested_turbine: str
    capacity_factor: float
    monthly_production: Optional[Dict[str, float]] = None
    monthly_flow_rates: Optional[Dict[str, float]] = None
    financials: Optional[FinancialAnalysis] = None         # HES finansal analizi
    plant_type: Optional[str] = None                       # "Nehir Tipi HES" | "Barajlı" vb.
    economic_viability_warning: Optional[str] = None       # Min debi eşiği uyarısı

class PinCalculationResponse(BaseModel):
    resource_type: Literal["Rüzgar Türbini", "Güneş Paneli", "Hidroelektrik"]
    wind_calculation: Optional[WindCalculationResponse] = None
    solar_calculation: Optional[SolarCalculationResponse] = None
    hydro_calculation: Optional[HydroCalculationResponse] = None

# --- GRID HARİTASI ---
class GridResponse(BaseModel):
    id: int
    latitude: float
    longitude: float
    type: str
    overall_score: float
    
    class Config:
        from_attributes = True

# --- RAPORLAMA ---

class RegionalSite(BaseModel):
    city: str
    district: Optional[str] = None
    type: str
    latitude: float
    longitude: float
    overall_score: float
    annual_potential_kwh_m2: Optional[float] = None
    avg_wind_speed_ms: Optional[float] = None
    annual_solar_irradiance_kwh_m2: Optional[float] = None
    
    # Generic display fields for dynamic reports (Yearly/Monthly/Instant)
    display_value: Optional[float] = None
    display_unit: Optional[str] = None
    
    rank: int


class RegionalStats(BaseModel):
    max_score: float
    min_score: float
    avg_score: float
    site_count: int


class RegionalReportResponse(BaseModel):
    region: str
    type: Literal["Solar", "Wind"]
    generated_at: datetime
    period_days: int = 365
    items: List[RegionalSite]
    stats: Optional[RegionalStats] = None

# --- SENARYO ---

class ScenarioCreate(BaseModel):
    name: str
    description: Optional[str] = None
    pin_ids: List[int] = []  # Artık birden fazla pin desteklenir
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    # Enerji depolama
    battery_capacity_kwh: Optional[float] = None
    battery_efficiency_pct: Optional[float] = None
    battery_cost_usd_per_kwh: Optional[float] = None

class ScenarioResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    pin_ids: List[int] = []
    # Geriye dönük uyumluluk için
    pin_id: Optional[int] = None
    owner_id: int
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    result_data: Optional[Dict[str, Any]] = None
    created_at: Optional[datetime] = None
    # Enerji depolama
    battery_capacity_kwh: Optional[float] = None
    battery_efficiency_pct: Optional[float] = None
    battery_cost_usd_per_kwh: Optional[float] = None

    class Config:
        from_attributes = True

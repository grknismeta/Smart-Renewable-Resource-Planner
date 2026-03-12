from pydantic import BaseModel, Field, field_validator
from typing import List, Optional, Dict, Literal, Any
from datetime import datetime, date

# --- AUTH & USER ---
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

class UserBase(BaseModel):
    email: str

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: int
    is_active: bool
    created_at: Optional[datetime] = None
    class Config:
        from_attributes = True

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
    # Konum bilgisi (reverse geocoding — pin oluşturulurken frontend gönderir)
    city: Optional[str] = None                 # İl
    district: Optional[str] = None            # İlçe
    water_body_name: Optional[str] = None     # HES için göl/nehir adı

class PinCreate(PinBase):
    pass

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

from pydantic import BaseModel, Field
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
    type: Literal["Güneş Paneli", "Rüzgar Türbini"] = "Güneş Paneli"
    capacity_mw: float = 1.0
    panel_area: Optional[float] = None
    equipment_id: Optional[int] = None

class PinCreate(PinBase):
    pass

class PinResponse(PinBase):
    id: int
    owner_id: int
    avg_solar_irradiance: Optional[float] = None
    avg_wind_speed: Optional[float] = None
    created_at: Optional[datetime] = None # DB'de varsa
    equipment_name: Optional[str] = None # Manuel join ile doldurulacak

    class Config:
        from_attributes = True

# --- HESAPLAMA SONUÇLARI (GRAFİK & FİNANS İÇİN) ---

class FinancialAnalysis(BaseModel):
    """Yatırım Geri Dönüş Analizi"""
    initial_investment_usd: float
    annual_earnings_usd: float
    payback_period_years: float
    roi_percentage: float

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

class PinCalculationResponse(BaseModel):
    resource_type: Literal["Rüzgar Türbini", "Güneş Paneli"]
    wind_calculation: Optional[WindCalculationResponse] = None
    solar_calculation: Optional[SolarCalculationResponse] = None

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
    
    class Config:
        from_attributes = True
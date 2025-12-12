
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Literal, Any
from datetime import datetime

# --- EKİPMAN ŞEMALARI (YENİ) ---
class EquipmentBase(BaseModel):
    name: str
    type: Literal["Solar", "Wind"]
    rated_power_kw: float
    efficiency: float
    cost_per_unit: float
    maintenance_cost_annual: float
    specs: Dict[str, Any] = {} # Esnek teknik özellikler

class EquipmentCreate(EquipmentBase):
    pass

class EquipmentResponse(EquipmentBase):
    id: int
    class Config:
        from_attributes = True

# --- KULLANICI ŞEMALARI ---
class UserBase(BaseModel):
    email: str

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: int
    is_active: bool
    created_at: datetime
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

# --- PIN ŞEMALARI ---
class PinBase(BaseModel):
    latitude: float
    longitude: float
    title: Optional[str] = "Yeni Kaynak"
    type: Literal["Güneş Paneli", "Rüzgar Türbini"] = "Güneş Paneli"
    capacity_mw: float = 1.0
    panel_area: Optional[float] = None
    
    # Yeni Alan: Seçilen Ekipman ID'si
    equipment_id: Optional[int] = None

class PinCreate(PinBase):
    pass

class PinResponse(PinBase):
    id: int
    owner_id: int
    avg_solar_irradiance: Optional[float] = None
    avg_wind_speed: Optional[float] = None
    
    # Ekipman detayını da döndürebiliriz
    equipment: Optional[EquipmentResponse] = None

    class Config:
        from_attributes = True

# --- Enerji Hesaplama Şemaları (DÜZELTİLDİ) ---
class WindCalculationResponse(BaseModel):
    """Rüzgar enerjisi hesaplama sonuçları"""
    wind_speed_m_s: float
    power_output_kw: float
    turbine_model: str
    
    # DÜZELTME: Bu alanları 'Optional' (seçenekli) yaptık
    potential_kwh_annual: Optional[float] = None
    capacity_factor: Optional[float] = None

class SolarCalculationResponse(BaseModel):
    """Güneş enerjisi hesaplama sonuçları"""
    solar_irradiance_kw_m2: float
    temperature_celsius: float
    panel_efficiency: float
    power_output_kw: float
    panel_model: str

    # DÜZELTME: Bu alanları 'Optional' (seçenekli) yaptık
    potential_kwh_annual: Optional[float] = None
    performance_ratio: Optional[float] = None

class PinCalculationResponse(BaseModel):
    """
    /pins/{pin_id}/calculate endpoint'inden dönen sonuç modeli.
    Kaynak tipine göre wind veya solar hesaplama sonuçlarını içerir.
    """
    resource_type: Literal["Rüzgar Türbini", "Güneş Paneli"]
    wind_calculation: Optional[WindCalculationResponse] = None
    solar_calculation: Optional[SolarCalculationResponse] = None

# --- GRID ŞEMALARI (YENİ EKLENECEK) ---
class GridBase(BaseModel):
    latitude: float
    longitude: float
    type: str
    overall_score: float

class GridResponse(GridBase):
    id: int
    class Config:
        from_attributes = True
        
# --- SENARYO ŞEMALARI (YENİ) ---
class ScenarioBase(BaseModel):
    name: str
    description: Optional[str] = None
    pin_id: int
    start_date: datetime
    end_date: datetime

class ScenarioCreate(ScenarioBase):
    pass

class ScenarioResponse(ScenarioBase):
    id: int
    owner_id: int
    result_data: Dict[str, Any] # ML Sonuçları burada olacak
    created_at: datetime

    class Config:
        from_attributes = True
    

from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Dict, Literal

# --- Güneş Paneli Şemaları ---
class SolarPanelBase(BaseModel):
    model_name: str
    power_rating_w: float
    dimensions_m: Dict[str, float]  # {"length": float, "width": float}
    base_efficiency: float  # 0-1 arası
    
    @field_validator('base_efficiency')
    def validate_efficiency(cls, v):
        if not 0 < v < 1:
            raise ValueError('Verim 0 ile 1 arasında olmalıdır')
        return v
    temp_coefficient: float
    is_default: bool = False

class SolarPanelCreate(SolarPanelBase):
    pass

class SolarPanelResponse(SolarPanelBase):
    id: int
    class Config:
        from_attributes = True

# --- Kimlik Doğrulama Şemaları ---
class UserBase(BaseModel):
    email: str

class UserCreate(UserBase):
    password: str = Field(..., max_length=1024)
    
class UserResponse(UserBase):
    id: int
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

# --- Türbin Şemaları ---
class TurbineBase(BaseModel):
    model_name: str
    rated_power_kw: float
    is_default: bool = False
    power_curve_data: Dict[float, float]

class TurbineCreate(TurbineBase):
    pass

class TurbineResponse(TurbineBase):
    id: int
    class Config:
        from_attributes = True


# --- Pin (Kaynak) Şemaları ---

class PinBase(BaseModel):
    latitude: float
    longitude: float
    name: str = Field(default="Yeni Kaynak")
    type: Literal["Rüzgar Türbini", "Güneş Paneli"] = Field(default="Rüzgar Türbini")
    capacity_mw: Optional[float] = Field(default=1.0)
    
    turbine_model_id: Optional[int] = None
    
    panel_model_id: Optional[int] = None
    panel_tilt: Optional[float] = Field(default=35.0)
    panel_azimuth: Optional[float] = Field(default=180.0)
    panel_area: Optional[float] = None

class PinCreate(PinBase):
    pass

class PinResponse(PinBase):
    id: int
    owner_id: int
    avg_solar_irradiance: Optional[float] = None
    turbine_model_id: Optional[int] = None
    
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

from pydantic import BaseModel, Field
from typing import Optional

# --- Kimlik Doğrulama Şemaları ---

class UserBase(BaseModel):
    email: str

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: int
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

# --- Pin (Kaynak) Şemaları ---

# Pin oluşturma/güncelleme için temel yapı
class PinBase(BaseModel):
    latitude: float
    longitude: float
    name: str = Field(default="Yeni Kaynak")
    type: str = Field(default="Güneş Paneli")
    capacity_mw: float = Field(default=1.0)

# API'dan dönen Pin verisi (id ve sahibinin kimliği de dahil)
class PinResponse(PinBase):
    id: int
    owner_id: int
    
    class Config:
        from_attributes = True

# --- Enerji Hesaplama Şeması ---

# Hesaplama API'sinden dönen sonucu temsil eder
class PinResult(PinBase):
    # Hesaplama sonuçları buraya eklenecek
    potential_kwh_annual: float # Yıllık potansiyel enerji üretimi (kWh)
    estimated_cost: float        # Tahmini Kurulum Maliyeti (TL/USD)
    roi_years: float             # Yatırımın Geri Dönüş Süresi (Yıl)
    
    class Config:
        from_attributes = True
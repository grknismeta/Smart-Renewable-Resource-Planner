# routers/pins.py

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

import schemas
import crud
import auth
import models
from database import SessionLocal

# API uç noktalarını gruplamak için APIRouter kullanıyoruz.
router = APIRouter(
    prefix="/pins",
    tags=["Harita Pinleri & Hesaplama"],
)

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# --- Enerji Hesaplama İş Mantığı (Basit Simülasyon) ---

def simulate_energy_calculation(pin: schemas.PinBase) -> schemas.PinResult:
    """
    Konum (latitude, longitude) ve kaynak tipine göre basit bir enerji ve maliyet
    hesaplaması simüle eder.
    
    GERÇEK PROJEDE BURAYA:
    1. Konuma göre OpenWeatherMap veya NASA POWER API'larından meteorolojik veri çekme
    2. Enerji verim formüllerini uygulama
    3. Maliyet ve ROI (Geri Dönüş Süresi) hesaplama
    fonksiyonları eklenecektir.
    """
    
    # Simülasyon Sabitleri (Konum hassasiyetini göstermek için kasten ayarlandı)
    BASE_YIELD = 1000000.0  # Temel yıllık kWh üretimi
    BASE_COST = 50000.0    # Temel Kurulum Maliyeti (USD)
    
    # 1. Konuma göre verim katsayısı hesaplama (Simülasyon)
    # Ege Bölgesi (38.0 - 39.5 Enlem) civarı yüksek verim katsayısı
    latitude_factor = 1.0 - abs(pin.latitude - 38.6) / 5.0 
    
    # 2. Kaynak Tipine göre verim katsayısı (Simülasyon)
    if pin.type.lower() == "rüzgar türbini":
        type_factor = 1.2 # Rüzgar türbinleri daha fazla enerji üretsin
        # Rüzgar kulesi maliyeti daha yüksektir.
        estimated_cost = BASE_COST * 1.5 * pin.capacity_mw 
        
    elif pin.type.lower() == "güneş paneli":
        type_factor = 0.8
        estimated_cost = BASE_COST * pin.capacity_mw
    
    else:
        type_factor = 0.5
        estimated_cost = BASE_COST * 0.7 * pin.capacity_mw
        
    # 3. Yıllık Enerji Hesaplaması
    potential_kwh_annual = BASE_YIELD * pin.capacity_mw * latitude_factor * type_factor
    
    # 4. Yatırımın Geri Dönüş Süresi (ROI) Hesaplaması
    # Ortalama kWh fiyatı 0.15 USD/kWh (Simülasyon)
    ANNUAL_REVENUE = potential_kwh_annual * 0.15 
    roi_years = estimated_cost / ANNUAL_REVENUE if ANNUAL_REVENUE > 0 else 999.0
    
    
    # Hesaplama sonucunu PinResult şemasına uygun olarak döndür
    return schemas.PinResult(
        latitude=pin.latitude,
        longitude=pin.longitude,
        name=pin.name,
        type=pin.type,
        capacity_mw=pin.capacity_mw,
        potential_kwh_annual=potential_kwh_annual,
        estimated_cost=estimated_cost,
        roi_years=roi_years
    )


# --- API Uç Noktaları ---

# 1. Yeni Pin Ekleme
@router.post("/", response_model=schemas.PinResponse, status_code=status.HTTP_201_CREATED)
def create_pin_for_current_user(
    pin: schemas.PinBase,
    db: Session = Depends(get_db),
    # Token'ı doğrular ve kullanıcının objesini döndürür
    current_user: models.User = Depends(auth.get_current_user)
):
    """Giriş yapmış kullanıcıya ait yeni bir harita pini (kaynağı) ekler."""
    return crud.create_user_pin(db=db, pin=pin, user_id=current_user.id)

# 2. Kullanıcıya Ait Pinleri Çekme
@router.get("/", response_model=List[schemas.PinResponse])
def read_pins_for_current_user(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    """Giriş yapmış kullanıcının harita pinlerinin (kaynaklarının) listesini döndürür."""
    # Pinleri crud.py üzerinden kullanıcı ID'sine göre çekiyoruz
    pins = crud.get_pins_by_owner(db=db, user_id=current_user.id)
    return pins

# 3. Pin Silme
@router.delete("/{pin_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_pin_for_current_user(
    pin_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    """Belirtilen ID'ye sahip pini, sadece sahibiyse siler."""
    success = crud.delete_user_pin(db=db, pin_id=pin_id, user_id=current_user.id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pin bulunamadı veya bu kullanıcıya ait değil."
        )
    # 204 No Content başarılı silme anlamına gelir, return'e gerek yok.

# 4. Enerji Hesaplama Uç Noktası
@router.post("/calculate", response_model=schemas.PinResult)
def calculate_resource_potential(
    pin_data: schemas.PinBase,
    current_user: models.User = Depends(auth.get_current_user)
):
    """
    Gönderilen kaynak verisine (konum, tip, kapasite) göre potansiyel enerji verimini,
    maliyetini ve ROI'sini hesaplar ve döndürür.
    (Bu endpoint, pini veritabanına kaydetmez, sadece hesaplama yapar.)
    """
    # Enerji Hesaplama İş Mantığını çağır
    result = simulate_energy_calculation(pin_data)
    return result
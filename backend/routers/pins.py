from fastapi import APIRouter, Depends, HTTPException, Header, status
from sqlalchemy.orm import Session
from typing import List, Optional, cast

from .. import crud, models, schemas, auth, solar_calculations, wind_calculations
from ..database import get_db
from ..schemas import PinCalculationResponse, SolarCalculationResponse, WindCalculationResponse, PinBase

router = APIRouter()

@router.post("/", response_model=schemas.PinResponse, status_code=status.HTTP_201_CREATED)
def create_pin(
    pin: schemas.PinCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Kimliği doğrulanmış kullanıcı için yeni bir harita pini oluşturur.
    Hesaplama mantığı CRUD katmanındadır.
    """
    user_id = cast(int, current_user.id)
    return crud.create_pin_for_user(db=db, pin=pin, user_id=user_id)


@router.get("/", response_model=List[schemas.PinResponse])
def read_pins_for_user(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Kullanıcının pinlerini listeler.
    """
    user_id = cast(int, current_user.id)
    pins = crud.get_pins_by_owner(db, owner_id=user_id, skip=skip, limit=limit)
    return pins

@router.post(
    "/calculate", 
    response_model=PinCalculationResponse,
    summary="Bir pinin potansiyelini, kaydetmeden hesaplar"
)
def calculate_pin_potential(
    pin_data: PinBase, 
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Veritabanına kaydetmeden anlık hesaplama yapar.
    """
    print(f"Hesaplama isteği: {pin_data.type} - {pin_data.latitude}, {pin_data.longitude}")

    if pin_data.type == "Güneş Paneli":
        panel_area = pin_data.panel_area or 10.0 # Varsayılan 10m2
        
        # --- YENİ FONKSİYONU ÇAĞIRIYORUZ ---
        results = solar_calculations.calculate_solar_power_production(
            latitude=pin_data.latitude,
            longitude=pin_data.longitude,
            panel_area=panel_area
        )
        
        if "error" in results:
             raise HTTPException(status_code=500, detail="Veri analizi başarısız.")

        # Response Modelini Doldurma
        solar_response = SolarCalculationResponse(
            solar_irradiance_kw_m2=results["daily_avg_potential_kwh_m2"], 
            temperature_celsius=25.0, # Ortalamayı buraya da koyabiliriz
            panel_efficiency=0.20,
            power_output_kw=results["system_annual_production_kwh"], # DİKKAT: Yıllık Toplam Üretim (kWh)
            panel_model="Veri Analizli Standart"
        )
        
        return PinCalculationResponse(
            resource_type="Güneş Paneli",
            solar_calculation=solar_response
        )

    elif pin_data.type == "Rüzgar Türbini":
        # Rüzgar kısmı şimdilik aynı kalıyor
        wind_speed = wind_calculations.get_wind_speed_from_coordinates(
            pin_data.latitude, pin_data.longitude
        )
        power_curve = wind_calculations.EXAMPLE_TURBINE_POWER_CURVE
        power_kw = wind_calculations.get_power_from_curve(wind_speed, power_curve)
        
        wind_response = WindCalculationResponse(
            wind_speed_m_s=wind_speed,
            power_output_kw=power_kw,
            turbine_model="Standart Türbin"
        )
        
        return PinCalculationResponse(
            resource_type="Rüzgar Türbini",
            wind_calculation=wind_response
        )
    
    else:
        raise HTTPException(status_code=400, detail="Geçersiz kaynak tipi.")
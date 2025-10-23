# routers/pins.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Union, cast

from .. import crud, schemas, auth, models, wind_calculations, solar_calculations
from ..database import SessionLocal
from ..database import get_db

router = APIRouter(
    prefix="/pins",
    tags=["Pins & Calculations"]
)

# Dependency (get_db)

@router.post("/", response_model=schemas.PinResponse, status_code=status.HTTP_201_CREATED)
def create_pin(
    pin: schemas.PinCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Kimliği doğrulanmış kullanıcı için yeni bir harita pini (kaynak) oluşturur.
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
    Kimliği doğrulanmış kullanıcının sahip olduğu tüm pinleri listeler.
    """
    user_id = cast(int, current_user.id)
    pins = crud.get_pins_by_owner(db, owner_id=user_id, skip=skip, limit=limit)
    return pins

@router.delete("/{pin_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_pin(
    pin_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Kimliği doğrulanmış kullanıcının sahip olduğu bir pini siler.
    """
    user_id = cast(int, current_user.id)
    success = crud.delete_pin_by_id(db, pin_id=pin_id, user_id=user_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pin bulunamadı veya bu kullanıcıya ait değil."
        )
    return {"message": "Pin başarıyla silindi."}


# --- YENİ HESAPLAMA ENDPOINT'İ ---

@router.get("/{pin_id}/calculate", response_model=schemas.PinCalculationResponse)
def calculate_pin_power(
    pin_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Belirli bir pin'in potansiyel enerji üretimini hesaplar.
    """
    # 1. Pini veritabanından bul
    user_id = cast(int, current_user.id)
    pin = crud.get_pin_by_id(db, pin_id=pin_id, user_id=user_id)
    if not pin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pin bulunamadı veya bu kullanıcıya ait değil."
        )

    # 2. Kaynak tipine göre hesaplama yap
    pin_type = str(pin.type)
    if pin_type == "Rüzgar Türbini":
        return calculate_wind_power(db, pin)
    elif pin_type == "Güneş Paneli":
        return calculate_solar_power(db, pin)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Bilinmeyen kaynak tipi: {pin_type}"
        )

def calculate_wind_power(db: Session, pin: models.Pin) -> schemas.PinCalculationResponse:
    """Rüzgar türbini güç hesaplaması"""
    # Pin verilerini tek sorguda al
    pin_data = db.query(
        models.Pin.latitude,
        models.Pin.longitude,
        models.Pin.turbine_model_id
    ).filter_by(id=pin.id).first()

    if not pin_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pin bulunamadı"
        )

    try:
        # Rüzgar hızını hesapla
        wind_speed = wind_calculations.get_wind_speed_from_coordinates(
            float(pin_data.latitude),
            float(pin_data.longitude)
        )
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Geçersiz koordinat değerleri"
        )

    # Türbin modelini al
    turbine_data = None
    if pin_data.turbine_model_id:
        turbine_data = db.query(
            models.Turbine.power_curve_data,
            models.Turbine.model_name
        ).filter_by(id=pin_data.turbine_model_id).first()

    if not turbine_data:
        turbine_data = db.query(
            models.Turbine.power_curve_data,
            models.Turbine.model_name
        ).filter_by(is_default=True).first()

    if not turbine_data or not turbine_data.power_curve_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hesaplama için standart (default) bir türbin modeli bulunamadı."
        )

    try:
        power_curve = dict(turbine_data.power_curve_data)
        power_kw = wind_calculations.get_power_from_curve(
            wind_speed,
            power_curve
        )
    except (TypeError, ValueError) as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Güç hesaplama hatası: {str(e)}"
        )

    # Yanıtı oluştur
    wind_calc = schemas.WindCalculationResponse(
        wind_speed_m_s=wind_speed,
        power_output_kw=power_kw,
        turbine_model=turbine_data.model_name
    )

    return schemas.PinCalculationResponse(
        resource_type="Rüzgar Türbini",
        wind_calculation=wind_calc
    )

def calculate_solar_power(db: Session, pin: models.Pin) -> schemas.PinCalculationResponse:
    """Güneş paneli güç hesaplaması"""
    # Pin verilerini tek sorguda al
    pin_data = db.query(
        models.Pin.latitude,
        models.Pin.longitude,
        models.Pin.panel_model_id,
        models.Pin.panel_area,
        models.Pin.panel_tilt,
        models.Pin.panel_azimuth
    ).filter_by(id=pin.id).first()
    
    if not pin_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pin bulunamadı"
        )

    # Panel modelini al
    panel_data = None
    if pin_data.panel_model_id:
        panel_data = db.query(
            models.SolarPanel.dimensions_m,
            models.SolarPanel.base_efficiency,
            models.SolarPanel.temp_coefficient,
            models.SolarPanel.model_name
        ).filter_by(id=pin_data.panel_model_id).first()

    if not panel_data:
        panel_data = db.query(
            models.SolarPanel.dimensions_m,
            models.SolarPanel.base_efficiency,
            models.SolarPanel.temp_coefficient,
            models.SolarPanel.model_name
        ).filter_by(is_default=True).first()

    if not panel_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hesaplama için standart (default) bir panel modeli bulunamadı."
        )

    try:
        # Panel boyutlarını hazırla
        dimensions = dict(panel_data.dimensions_m)
        default_area = float(dimensions["length"]) * float(dimensions["width"])

        # Değerleri dönüştür
        panel_area = float(pin_data.panel_area) if pin_data.panel_area is not None else 100.0
        tilt_angle = float(pin_data.panel_tilt) if pin_data.panel_tilt is not None else 35.0
        azimuth_angle = float(pin_data.panel_azimuth) if pin_data.panel_azimuth is not None else 180.0
        latitude = float(pin_data.latitude)
        longitude = float(pin_data.longitude)
        base_efficiency = float(panel_data.base_efficiency)
        temp_coefficient = float(panel_data.temp_coefficient)

        # Güç hesaplaması
        result = solar_calculations.calculate_solar_power(
            latitude=latitude,
            longitude=longitude,
            panel_area=panel_area,
            tilt_angle=tilt_angle,
            azimuth_angle=azimuth_angle,
            base_efficiency=base_efficiency,
            temp_coefficient=temp_coefficient
        )

        # Yanıtı oluştur
        solar_calc = schemas.SolarCalculationResponse(
            solar_irradiance_kw_m2=result["solar_irradiance_kw_m2"],
            temperature_celsius=result["temperature_celsius"],
            panel_efficiency=result["panel_efficiency"],
            power_output_kw=result["power_output_kw"],
            panel_model=panel_data.model_name
        )
    except (TypeError, ValueError, KeyError) as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Güç hesaplama hatası: {str(e)}"
        )

    return schemas.PinCalculationResponse(
        resource_type="Güneş Paneli",
        solar_calculation=solar_calc
    )

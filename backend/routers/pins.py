from fastapi import APIRouter, Depends, HTTPException, Header, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional, cast, Union

from .. import crud, models, schemas, auth, solar_calculations, wind_calculations
from ..database import get_db, get_system_db # get_system_db'yi import ettik
from ..schemas import PinCalculationResponse, SolarCalculationResponse, WindCalculationResponse, PinBase

router = APIRouter()

@router.post("/", response_model=schemas.PinResponse, status_code=status.HTTP_201_CREATED)
def create_pin(
    pin: schemas.PinCreate,
    db: Session = Depends(get_db),
    system_db: Session = Depends(get_system_db), # YENİ: Sistem veritabanı bağlantısı
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Kimliği doğrulanmış kullanıcı için yeni bir harita pini oluşturur.
    SystemDB kullanarak o konumun hava verilerini (varsa) çeker.
    """
    user_id = cast(int, current_user.id)
    # system_db'yi crud fonksiyonuna gönderiyoruz
    return crud.create_pin_for_user(db=db, pin=pin, user_id=user_id, system_db=system_db)


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
    db: Session = Depends(get_db),
    system_db: Session = Depends(get_system_db), # system_db kullanımı
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Veritabanına kaydetmeden anlık hesaplama yapar.
    """
    print(f"Hesaplama isteği: {pin_data.type} - {pin_data.latitude}, {pin_data.longitude}")

    # --- EKİPMAN SEÇİMİ ---
    selected_equipment: Optional[models.Equipment] = None
    if pin_data.equipment_id is not None:
        # Ekipman verisi SystemDB'den çekilir
        selected_equipment = crud.get_equipment(system_db, pin_data.equipment_id)
        if selected_equipment is None:
            print("Uyarı: Seçilen ekipman ID bulunamadı, varsayılanlar kullanılacak.")

    if pin_data.type == "Güneş Paneli":
        panel_area = pin_data.panel_area or 10.0
        efficiency: float = 0.20
        model_name: str = "Veri Analizli Standart Panel"
        
        if selected_equipment is not None and str(selected_equipment.type) == "Solar":
            efficiency = float(selected_equipment.efficiency) # type: ignore
            model_name = str(selected_equipment.name) # type: ignore
            
        # --- HESAPLAMA ---
        results = solar_calculations.calculate_solar_power_production(
            latitude=pin_data.latitude,
            longitude=pin_data.longitude,
            panel_area=panel_area,
            panel_efficiency=efficiency 
        )
        
        if "error" in results:
             raise HTTPException(status_code=500, detail=results["error"])

        solar_response = SolarCalculationResponse(
            solar_irradiance_kw_m2=results["daily_avg_potential_kwh_m2"], 
            temperature_celsius=25.0,
            panel_efficiency=efficiency,
            power_output_kw=results["predicted_annual_production_kwh"],
            panel_model=model_name
        )
        
        return PinCalculationResponse(
            resource_type="Güneş Paneli",
            solar_calculation=solar_response
        )
    
    elif pin_data.type == "Rüzgar Türbini":
        
        power_curve = wind_calculations.EXAMPLE_TURBINE_POWER_CURVE
        model_name: str = "Standart 3.3MW Türbin"

        if selected_equipment is not None and str(selected_equipment.type) == "Wind":
            model_name = str(selected_equipment.name) # type: ignore
            specs_data = selected_equipment.specs
            if specs_data is not None and "power_curve" in specs_data:
                raw_curve = specs_data["power_curve"]
                power_curve = {float(k): float(v) for k, v in raw_curve.items()} # type: ignore

        # Veri Çekme (Şu anlık API/Modül üzerinden, ileride SystemDB'den çekilebilir)
        wind_speed = wind_calculations.get_wind_speed_from_coordinates(
            pin_data.latitude, pin_data.longitude
        )
        
        # HASSAS HESAPLAMA ÇAĞRISI
        results = wind_calculations.calculate_wind_power_production(
            latitude=pin_data.latitude,
            longitude=pin_data.longitude
        )
        
        if "error" in results: raise HTTPException(status_code=500, detail=results["error"])
        
        wind_response = WindCalculationResponse(
            wind_speed_m_s=round(results["avg_wind_speed_ms"], 2),
            power_output_kw=round(results["predicted_annual_production_kwh"], 0),
            turbine_model=model_name
        )
        
        return PinCalculationResponse(
            resource_type="Rüzgar Türbini",
            wind_calculation=wind_response
        )
    
    else:
        raise HTTPException(status_code=400, detail="Geçersiz kaynak tipi.")


# --- GRID ENDPOINT ---
@router.get("/map-data", response_model=List[schemas.GridResponse])
def get_grid_map_data(
    type: str = Query(..., description="Analiz tipi: Solar veya Wind"),
    db: Session = Depends(get_system_db), # Grid verisi SystemDB'de
    current_user: models.User = Depends(auth.get_current_active_user)
):
    if type not in ["Solar", "Wind"]:
        raise HTTPException(status_code=400, detail="Geçersiz analiz tipi. 'Solar' veya 'Wind' olmalı.")
    
    grid_data = db.query(models.GridAnalysis).filter(
        models.GridAnalysis.type == type,
        models.GridAnalysis.overall_score > 0.0
    ).all()
    
    return grid_data
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, cast, Any, Dict
from datetime import datetime
import json

from .. import crud, models, schemas, auth, solar_calculations, wind_calculations
from ..database import get_db
# ML modülünü import ediyoruz
from ..ml_predictor import predict_future_production 

router = APIRouter()

@router.post("/", response_model=schemas.ScenarioResponse, status_code=status.HTTP_201_CREATED)
def create_scenario(
    scenario: schemas.ScenarioCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Yeni bir senaryo oluşturur. Artık birden fazla pin destekler.
    """
    # Pin sahipliği kontrolü
    for pin_id in scenario.pin_ids:
        db_pin = db.query(models.Pin).filter(models.Pin.id == pin_id).first()
        if not db_pin: # type: ignore
            raise HTTPException(status_code=404, detail=f"Pin {pin_id} bulunamadı")
        if db_pin.owner_id != current_user.id: # type: ignore
            raise HTTPException(status_code=403, detail=f"Pin {pin_id}'e erişim yetkiniz yok")

    # Senaryo oluştur (hesaplama olmadan)
    db_scenario = models.Scenario(
        name=scenario.name,
        description=scenario.description,
        pin_ids=scenario.pin_ids,
        # Geriye dönük uyumluluk: ilk pin varsa pin_id'ye yaz
        pin_id=scenario.pin_ids[0] if scenario.pin_ids else None,
        owner_id=current_user.id,
        start_date=scenario.start_date,
        end_date=scenario.end_date,
        result_data={} # Boş başlar, calculate ile doldurulur
    )
    
    db.add(db_scenario)
    db.commit()
    db.refresh(db_scenario)
    
    # pin_ids'i list olarak döndür
    if isinstance(db_scenario.pin_ids, str):
        try:
            db_scenario.pin_ids = json.loads(db_scenario.pin_ids)  # type: ignore
        except:
            db_scenario.pin_ids = []  # type: ignore
    else:
        db_scenario.pin_ids = list(db_scenario.pin_ids or [])  # type: ignore
    
    return db_scenario

@router.get("/", response_model=List[schemas.ScenarioResponse])
def read_scenarios(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Kullanıcının tüm senaryolarını listeler."""
    return db.query(models.Scenario).filter(models.Scenario.owner_id == current_user.id).all()


@router.post("/{scenario_id}/calculate", response_model=schemas.ScenarioResponse)
def calculate_scenario(
    scenario_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Mevcut bir senaryonun pinleri için ML hesaplaması yapar.
    start_date ve end_date senaryoda kayıtlı olmalı.
    """
    db_scenario = db.query(models.Scenario).filter(
        models.Scenario.id == scenario_id,
        models.Scenario.owner_id == current_user.id
    ).first()
    
    if not db_scenario: # type: ignore
        raise HTTPException(status_code=404, detail="Senaryo bulunamadı")
    
    pin_ids = db_scenario.pin_ids or [] # type: ignore
    # pin_ids JSON'dan gelebilir, list'e çevir
    if isinstance(pin_ids, str):
        try:
            pin_ids = json.loads(pin_ids)
        except:
            pin_ids = []
    # Safely convert to list of integers
    pin_id_list = []
    for p in pin_ids:
        try:
            pin_id_list.append(int(p))  # type: ignore
        except (ValueError, TypeError):
            continue
    pin_ids = pin_id_list
    if not pin_ids:
        raise HTTPException(status_code=400, detail="Senaryoda pin yok")
    
    start_date = db_scenario.start_date # type: ignore
    end_date = db_scenario.end_date # type: ignore
    
    if start_date is None or end_date is None:
        raise HTTPException(status_code=400, detail="Senaryo tarih aralığı eksik")
    
    # Ensure start_date and end_date are datetime objects, not Column objects
    if isinstance(start_date, datetime):
        start_date = cast(datetime, start_date)
    else:
        start_date = cast(datetime, start_date)
    
    if isinstance(end_date, datetime):
        end_date = cast(datetime, end_date)
    else:
        end_date = cast(datetime, end_date)
    
    print(f"Senaryo Hesaplanıyor: {start_date} - {end_date}")
    
    # Her pin için hesaplama yap
    pin_results = []
    total_solar_kwh = 0.0
    total_wind_kwh = 0.0
    solar_count = 0
    wind_count = 0
    
    for pin_id in pin_ids:
        db_pin = db.query(models.Pin).filter(models.Pin.id == pin_id).first()
        if not db_pin: # type: ignore
            continue
            
        pin_type = str(db_pin.type or "Güneş Paneli").strip() # type: ignore
        pin_lat = float(db_pin.latitude) # type: ignore
        pin_lon = float(db_pin.longitude) # type: ignore
        pin_title = str(db_pin.name or "Pin") # type: ignore
        
        prediction_result: Dict[str, Any] = {"pin_id": pin_id, "pin_name": pin_title, "type": pin_type}
        
        if "Güneş" in pin_type or "Solar" in pin_type or pin_type == "Güneş Paneli":
            historical_data = solar_calculations.get_historical_hourly_solar_data(pin_lat, pin_lon)
            
            if "error" not in historical_data and "raw_data_for_ml" in historical_data:
                raw_data = historical_data["raw_data_for_ml"]
                ml_forecast = predict_future_production(
                    hourly_data=raw_data,
                    resource_type="solar",
                    start_date=start_date,
                    end_date=end_date
                )
                
                if "error" not in ml_forecast:
                    prediction_result.update(ml_forecast)
                    total_solar_kwh += ml_forecast.get("total_prediction_value", 0.0)
                    solar_count += 1
                else:
                    prediction_result["error"] = ml_forecast.get("error", "ML hatası")
            else:
                prediction_result["error"] = "Geçmiş veri alınamadı"
                
        elif "Rüzgar" in pin_type or "Wind" in pin_type or pin_type == "Rüzgar Türbini":
            # Get weather statistics for this pin from database
            db_weather = db.query(models.WeatherData).filter(
                models.WeatherData.pin_id == pin_id
            ).order_by(models.WeatherData.date.desc()).first()
            
            weather_stats = None
            if db_weather and db_weather.data:
                weather_stats = db_weather.data
            
            wind_data = wind_calculations.calculate_wind_power_production(pin_lat, pin_lon, weather_stats or {})
            
            if "error" not in wind_data:
                prediction_result["info"] = "Rüzgar yıllık tahmin"
                prediction_result.update(wind_data)
                total_wind_kwh += wind_data.get("predicted_annual_production_kwh", 0.0)
                wind_count += 1
            else:
                prediction_result["error"] = "Rüzgar verisi alınamadı"
        
        pin_results.append(prediction_result)
    
    # Toplu sonuçları kaydet
    summary = {
        "total_solar_kwh": total_solar_kwh,
        "total_wind_kwh": total_wind_kwh,
        "total_kwh": total_solar_kwh + total_wind_kwh,
        "solar_count": solar_count,
        "wind_count": wind_count,
        "pin_results": pin_results
    }
    
    db_scenario.result_data = summary # type: ignore
    db.commit()
    db.refresh(db_scenario)
    
    # pin_ids'i list olarak döndür
    if isinstance(db_scenario.pin_ids, str):
        try:
            db_scenario.pin_ids = json.loads(db_scenario.pin_ids)  # type: ignore
        except:
            db_scenario.pin_ids = []  # type: ignore
    else:
        db_scenario.pin_ids = list(db_scenario.pin_ids or [])  # type: ignore
    
    return db_scenario
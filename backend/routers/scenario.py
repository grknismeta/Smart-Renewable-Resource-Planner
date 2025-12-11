from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, cast, Any, Dict
from datetime import datetime

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
    Belirtilen Pin ve Tarih Aralığı için özel bir ML Tahmin Senaryosu oluşturur ve kaydeder.
    """
    # 1. Pin'i veritabanından çek
    db_pin = db.query(models.Pin).filter(models.Pin.id == scenario.pin_id).first()
    
    # Pylance, db_pin'in ColumnElement olabileceğini düşündüğü için hata verir.
    # # type: ignore ile bu kontrolü geçiyoruz çünkü .first() sonucu ya instance ya None'dır.
    if not db_pin: # type: ignore
        raise HTTPException(status_code=404, detail="Pin bulunamadı")
    
    # Sahiplik kontrolü
    if db_pin.owner_id != current_user.id: # type: ignore
        raise HTTPException(status_code=403, detail="Bu pine senaryo ekleme yetkiniz yok")

    print(f"Senaryo Hesaplanıyor: {scenario.start_date} - {scenario.end_date}")

    # --- PYLANCE DÜZELTMESİ ---
    # Veritabanı sütunlarını Python tiplerine dönüştürürken type ignore kullanıyoruz
    pin_type = str(db_pin.type) # type: ignore
    pin_lat = float(db_pin.latitude) # type: ignore
    pin_lon = float(db_pin.longitude) # type: ignore
    
    prediction_result: Dict[str, Any] = {}
    
    # 2. Pin Tipine Göre ML Tahmini Yap
    if pin_type == "Güneş Paneli":
        # Güneş için geçmiş ham veriyi çek (ML Eğitimi için)
        historical_data = solar_calculations.get_historical_hourly_solar_data(
            pin_lat, pin_lon
        )
        
        if "error" not in historical_data and "raw_data_for_ml" in historical_data:
            # Ham veri mevcut, ML motoruna gönder
            raw_data = historical_data["raw_data_for_ml"]
            
            # ML ile belirtilen tarih aralığı için tahmin üret
            ml_forecast = predict_future_production(
                hourly_data=raw_data,
                resource_type="solar",
                start_date=scenario.start_date,
                end_date=scenario.end_date
            )
            
            if "error" not in ml_forecast:
                prediction_result = ml_forecast
            else:
                prediction_result = {"error": "ML Tahmini başarısız oldu."}
        else:
            prediction_result = {"error": "Geçmiş veri çekilemediği için tahmin yapılamadı."}

    elif pin_type == "Rüzgar Türbini":
        # Rüzgar için geçmiş ham veriyi çek
        historical_data = wind_calculations.get_historical_hourly_wind_data(
            pin_lat, pin_lon
        )
        
        # Not: wind_calculations.py dosyasında 'raw_data_for_ml' döndürdüğümüzden emin olmalıyız.
        # Eğer henüz yoksa, 'ml_training_data' hazırlayan bir mantık wind_calculations.py içinde olmalı.
        # Basitlik için burada historical_data içinde 'future_prediction' varsa onu kullanıyoruz.
        
        if "error" not in historical_data and "future_prediction" in historical_data:
             # Eğer özel tarih aralığı destekleniyorsa (raw_data varsa) yeniden hesaplanabilir.
             # Şimdilik standart 1 yıllık tahmini kullanıyoruz.
             prediction_result = {
                 "info": "Rüzgar senaryosu için yıllık standart tahmin kullanıldı.",
                 "monthly_predictions": historical_data["future_prediction"].get("monthly_predictions", []),
                 "total_prediction_value": historical_data["future_prediction"].get("total_prediction_value", 0.0),
                 "start_date": scenario.start_date.isoformat(),
                 "end_date": scenario.end_date.isoformat()
             }
        else:
             prediction_result = {"error": "Rüzgar verisi alınamadı."}

    # 3. Veritabanına Kaydet
    db_scenario = models.Scenario(
        name=scenario.name,
        description=scenario.description,
        pin_id=scenario.pin_id,
        owner_id=current_user.id,
        start_date=scenario.start_date,
        end_date=scenario.end_date,
        result_data=prediction_result # Hesaplanan sonuç
    )
    
    db.add(db_scenario)
    db.commit()
    db.refresh(db_scenario)
    
    return db_scenario

@router.get("/", response_model=List[schemas.ScenarioResponse])
def read_scenarios(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Kullanıcının tüm senaryolarını listeler."""
    return db.query(models.Scenario).filter(models.Scenario.owner_id == current_user.id).all()
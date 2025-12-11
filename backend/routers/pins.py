from fastapi import APIRouter, Depends, HTTPException, Header, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional, cast, Union

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
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Veritabanına kaydetmeden anlık hesaplama yapar.
    """
    print(f"Hesaplama isteği: {pin_data.type} - {pin_data.latitude}, {pin_data.longitude}")

    # --- EKİPMAN SEÇİMİ ---
    selected_equipment: Optional[models.Equipment] = None
    if pin_data.equipment_id is not None:
        selected_equipment = crud.get_equipment(db, pin_data.equipment_id)
        if selected_equipment is None:
            print("Uyarı: Seçilen ekipman ID bulunamadı, varsayılanlar kullanılacak.")

    if pin_data.type == "Güneş Paneli":
        panel_area = pin_data.panel_area or 10.0
        
        # Pylance Hatası Düzeltmesi: Tip zorlaması yapılıyor
        efficiency: float = 0.20
        model_name: str = "Veri Analizli Standart Panel"
        
        # Dinamik Ekipman Kullanımı
        if selected_equipment is not None and str(selected_equipment.type) == "Solar":
            efficiency = float(selected_equipment.efficiency) # type: ignore
            model_name = str(selected_equipment.name) # type: ignore
            
        # --- HESAPLAMA ---
        results = solar_calculations.calculate_solar_power_production(
            latitude=pin_data.latitude,
            longitude=pin_data.longitude,
            panel_area=panel_area,
            panel_efficiency=efficiency # Dinamik verim
        )
        
        if "error" in results:
             raise HTTPException(status_code=500, detail=results["error"])

        # Response Modelini Doldurma
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
        
        # Varsayılanlar
        power_curve = wind_calculations.EXAMPLE_TURBINE_POWER_CURVE
        model_name: str = "Standart 3.3MW Türbin"

        # Dinamik Ekipman Kullanımı
        if selected_equipment is not None and str(selected_equipment.type) == "Wind":
            model_name = str(selected_equipment.name) # type: ignore
            
            # Hata Giderildi: specs'i açıkça kontrol et ve kullan (Pylance'ı yatıştırmak için)
            specs_data = selected_equipment.specs
            if specs_data is not None and "power_curve" in specs_data: # <--- DÜZELTİLDİ
                raw_curve = specs_data["power_curve"]
                power_curve = {float(k): float(v) for k, v in raw_curve.items()} # type: ignore

        # Veri Çekme
        wind_speed = wind_calculations.get_wind_speed_from_coordinates(
            pin_data.latitude, pin_data.longitude
        )
        
        # Seçilen eğriye göre güç hesabı (Bu, ML tabanlı hesaplamanın sadeleştirilmişidir)
        power_kw = wind_calculations.get_power_from_curve(wind_speed, power_curve)
        annual_kwh = power_kw * 8760 
        
        # HASSAS HESAPLAMA ÇAĞRISI (ML ve 10 yıllık veri)
        results = wind_calculations.calculate_wind_power_production(
            latitude=pin_data.latitude,
            longitude=pin_data.longitude
        )
        
        if "error" in results: raise HTTPException(status_code=500, detail=results["error"])
        
        wind_response = WindCalculationResponse(
            wind_speed_m_s=round(results["avg_wind_speed_ms"], 2),
            power_output_kw=round(results["predicted_annual_production_kwh"], 0), # Gelecek Tahmini Üretimi
            turbine_model=model_name # Tip zorlaması yapıldığı için sorun kalmadı
        )
        
        return PinCalculationResponse(
            resource_type="Rüzgar Türbini",
            wind_calculation=wind_response
        )
    
    else:
        raise HTTPException(status_code=400, detail="Geçersiz kaynak tipi.")


# --- YENİ EKLENEN GRID HARİTASI ENDPOINT'İ ---
@router.get("/map-data", response_model=List[schemas.GridResponse])
def get_grid_map_data(
    type: str = Query(..., description="Analiz tipi: Solar veya Wind"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Tüm Türkiye için önbelleklenmiş Grid Skorlarını (Akıllı Tavsiye Haritası) döndürür.
    Flutter bu veriyi haritayı renklendirmek için kullanır.
    """
    if type not in ["Solar", "Wind"]:
        raise HTTPException(status_code=400, detail="Geçersiz analiz tipi. 'Solar' veya 'Wind' olmalı.")
    
    # GridAnalysis tablosundaki verileri çek
    grid_data = db.query(models.GridAnalysis).filter(
        models.GridAnalysis.type == type,
        models.GridAnalysis.overall_score > 0.0
    ).all()
    
    return grid_data
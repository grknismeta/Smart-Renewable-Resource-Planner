from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.concurrency import run_in_threadpool # <--- SİHİRLİ İMPORT
from sqlalchemy.orm import Session
from typing import List, Optional, cast, Dict, Any

from .. import auth # Updated import
from app.crud import crud
from app.schemas import schemas
from app.db import models
from app.services import solar_service as solar_calculations, wind_service as wind_calculations
from app.services.hydro_service import calculate_annual_hydro_production, suggest_turbine_type
from app.db.database import get_db, get_system_db, get_user_pins_db
from app.schemas.schemas import PinCalculationResponse, SolarCalculationResponse, WindCalculationResponse, HydroCalculationResponse, PinBase, FinancialAnalysis

router = APIRouter()

# --- YARDIMCI FONKSİYON: FİNANSAL HESAPLAMA ---
def calculate_financials(annual_kwh: float, type: str) -> FinancialAnalysis:
    """
    Basit yatırım geri dönüş hesabı (Yatırımcı Sunumu İçin)
    """
    electricity_price_usd = 0.12 # kWh başına gelir (Dolar)
    
    initial_cost = 0.0
    if type == "Solar":
        # 10m2, 1.5-2 kW sistem ~ 2000-3000 USD kurulum maliyeti
        initial_cost = 2500.0 
    else:
        # Küçük türbin maliyeti
        initial_cost = 4000.0
        
    annual_earning = annual_kwh * electricity_price_usd
    payback_years = initial_cost / annual_earning if annual_earning > 0 else 99.0
    roi = (annual_earning / initial_cost) * 100 if initial_cost > 0 else 0.0
    
    return FinancialAnalysis(
        initial_investment_usd=initial_cost,
        annual_earnings_usd=round(annual_earning, 2),
        payback_period_years=round(payback_years, 1),
        roi_percentage=round(roi, 1)
    )

# --- ENDPOINTLER ---

@router.post("/", response_model=schemas.PinResponse, status_code=status.HTTP_201_CREATED)
def create_pin(
    pin: schemas.PinCreate,
    db: Session = Depends(get_db),
    system_db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    user_id = cast(int, current_user.id)
    return crud.create_pin_for_user(db=db, pin=pin, user_id=user_id, system_db=system_db)

@router.get("/", response_model=List[schemas.PinResponse])
def read_pins_for_user(
    skip: int = 0, limit: int = 100,
    db: Session = Depends(get_db),
    system_db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    user_id = cast(int, current_user.id)
    pins = crud.get_pins_by_owner(db, owner_id=user_id, skip=skip, limit=limit)
    
    # Ekipman isimlerini doldur (Cross-DB Join manuel)
    equipment_ids = {p.equipment_id for p in pins if p.equipment_id is not None} # type: ignore
    
    equipment_map = {}
    if equipment_ids:
        eqs = system_db.query(models.Equipment).filter(models.Equipment.id.in_(equipment_ids)).all()
        equipment_map = {e.id: e.name for e in eqs}
        
    for p in pins:
        if p.equipment_id in equipment_map: # type: ignore
            setattr(p, "equipment_name", equipment_map[p.equipment_id]) # type: ignore
            
    print(f'[Pins Router] GET /pins/ - user_id={user_id}, {len(pins)} pin döndürüldü')
    return pins

@router.delete("/{pin_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_pin(
    pin_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """Pin silme endpoint'i"""
    user_id = cast(int, current_user.id)
    success = crud.delete_pin_by_id(db, pin_id=pin_id, user_id=user_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pin bulunamadı veya bu kullanıcıya ait değil."
        )

@router.put("/{pin_id}", response_model=schemas.PinResponse)
def update_pin(
    pin_id: int,
    pin: schemas.PinCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    user_id = cast(int, current_user.id)
    updated_pin = crud.update_pin(db=db, pin_id=pin_id, pin_update=pin, user_id=user_id)
    if not updated_pin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pin bulunamadı veya bu kullanıcıya ait değil."
        )
    return updated_pin

@router.post("/calculate", response_model=PinCalculationResponse)
async def calculate_pin_potential(
    pin_data: PinBase, 
    db: Session = Depends(get_db),
    system_db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Veritabanına kaydetmeden anlık hesaplama yapar.
    PERFORMANS: Hesaplamalar ana thread'i tıkamaması için threadpool'da çalıştırılır.
    """
    # 1. Hava Verilerini Çek
    weather_stats = crud.get_weather_stats(system_db, float(pin_data.latitude), float(pin_data.longitude))
    if weather_stats is None: weather_stats = {}
    
    selected_equipment: Optional[models.Equipment] = None
    if pin_data.equipment_id is not None:
        selected_equipment = crud.get_equipment(system_db, pin_data.equipment_id)

    if pin_data.type == "Güneş Paneli":
        panel_area = float(pin_data.panel_area or 10.0)
        efficiency: float = 0.20
        model_name: str = "Veri Analizli Standart Panel"
        
        if selected_equipment is not None and str(selected_equipment.type) == "Solar":
            eff_val = selected_equipment.efficiency
            if eff_val is not None: efficiency = float(cast(float, eff_val))
            model_name = str(selected_equipment.name)

        # ASYNC WRAPPER: Bu işlem CPU'yu yorar, arka plana atıyoruz.
        results = await run_in_threadpool(
            solar_calculations.calculate_solar_power_production,
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            panel_area=panel_area,
            panel_efficiency=efficiency,
            weather_stats=weather_stats
        )
        
        if "error" in results: raise HTTPException(status_code=500, detail=results["error"])
        
        
        annual_kwh = float(results["predicted_annual_production_kwh"])
        solar_res = SolarCalculationResponse(
            solar_irradiance_kw_m2=float(results["daily_avg_potential_kwh_m2"]),
            temperature_celsius=25.0,
            panel_efficiency=efficiency,
            power_output_kw=annual_kwh,
            panel_model=model_name,
            potential_kwh_annual=annual_kwh,
            performance_ratio=0.80,
            monthly_production=results.get("month_by_month_prediction"),
            financials=None # Basitlik için
        )
        return PinCalculationResponse(resource_type="Güneş Paneli", solar_calculation=solar_res)

    elif pin_data.type == "Rüzgar Türbini":
        model_name = "Standart 3.3MW Türbin"
        if selected_equipment is not None and str(selected_equipment.type) == "Wind":
             model_name = str(selected_equipment.name)

        # ASYNC WRAPPER: Rüzgar hesabı da ağır olabilir.
        results = await run_in_threadpool(
            wind_calculations.calculate_wind_power_production,
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            weather_stats=weather_stats
        )
        
        if "error" in results: raise HTTPException(status_code=500, detail=results["error"])
        
        annual_kwh = float(results["predicted_annual_production_kwh"])
        
        avg_monthly = annual_kwh / 12.0
        monthly_sim = { "Ocak": avg_monthly * 1.2, "Haziran": avg_monthly * 0.8 } # Örnek kısaltma

        wind_res = WindCalculationResponse(
            wind_speed_m_s=float(results["avg_wind_speed_ms"]),
            power_output_kw=annual_kwh,
            turbine_model=model_name,
            potential_kwh_annual=annual_kwh,
            capacity_factor=float(results.get("capacity_factor", 0.3)),
            monthly_production=monthly_sim,
            financials=None
        )
        return PinCalculationResponse(resource_type="Rüzgar Türbini", wind_calculation=wind_res)

    elif pin_data.type == "Hidroelektrik":
        # HES hesaplama
        flow_rate = pin_data.flow_rate
        head_height = pin_data.head_height
        basin_area_km2 = pin_data.basin_area_km2

        if head_height is None or head_height <= 0:
            raise HTTPException(status_code=400, detail="HES için düşü yüksekliği (head_height) zorunludur.")

        if (flow_rate is None or flow_rate <= 0) and (basin_area_km2 is None or basin_area_km2 <= 0):
            raise HTTPException(status_code=400, detail="Debi (flow_rate) veya Havza Alanı (basin_area_km2) girilmelidir.")

        turbine_type = suggest_turbine_type(head_height)
        # Ekipman varsa türünü al
        if selected_equipment is not None and str(selected_equipment.type) == "Hydro":
            specs = selected_equipment.specs or {}
            turbine_type = specs.get("turbine_type", turbine_type)

        hydro_results = await run_in_threadpool(
            calculate_annual_hydro_production,
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            head_height=head_height,
            turbine_type=turbine_type,
            flow_rate=flow_rate if (flow_rate and flow_rate > 0) else None,
            basin_area_km2=basin_area_km2 if (basin_area_km2 and basin_area_km2 > 0) else None,
        )

        if "error" in hydro_results:
            raise HTTPException(status_code=500, detail=hydro_results["error"])

        hydro_res = HydroCalculationResponse(**hydro_results)
        return PinCalculationResponse(resource_type="Hidroelektrik", hydro_calculation=hydro_res)

    else:
        raise HTTPException(status_code=400, detail="Geçersiz tip")

@router.get("/map-data", response_model=List[schemas.GridResponse])
def get_grid_map_data(
    type: str = Query(..., description="Solar veya Wind"),
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    if type not in ["Solar", "Wind"]:
        raise HTTPException(status_code=400, detail="Geçersiz tip")

    return db.query(models.GridAnalysis).filter(
        models.GridAnalysis.type == type,
        models.GridAnalysis.overall_score > 0.0
    ).all()

@router.post("/{pin_id}/analyze", response_model=schemas.PinResponse)
async def analyze_pin(
    pin_id: int,
    db: Session = Depends(get_db),
    system_db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Mevcut bir pin için analiz çalıştırır ve sonucu kaydeder.
    """
    user_id = cast(int, current_user.id)
    
    # 1. Pin'i bul
    pin_obj = crud.get_pin_by_id(db, pin_id, user_id)
    if not pin_obj:
        raise HTTPException(status_code=404, detail="Pin bulunamadı")
        
    # 2. Schema'ya çevir (PinBase)
    pin_data = schemas.PinBase(
        latitude=pin_obj.latitude, # type: ignore
        longitude=pin_obj.longitude, # type: ignore
        title=pin_obj.title, # type: ignore
        type=pin_obj.type, # type: ignore
        capacity_mw=pin_obj.capacity_mw, # type: ignore
        panel_area=pin_obj.panel_area, # type: ignore
        equipment_id=pin_obj.equipment_id # type: ignore
    )
    
    # 3. Hesaplama yap (calculate_pin_potential mantığı)
    weather_stats = crud.get_weather_stats(system_db, float(pin_data.latitude), float(pin_data.longitude))
    if weather_stats is None: weather_stats = {}
    
    selected_equipment: Optional[models.Equipment] = None
    if pin_data.equipment_id is not None:
        selected_equipment = crud.get_equipment(system_db, pin_data.equipment_id)
        
    calculation_result = None
    
    if pin_data.type == "Güneş Paneli":
        panel_area = float(pin_data.panel_area or 10.0)
        efficiency: float = 0.20
        model_name: str = "Veri Analizli Standart Panel"
        
        if selected_equipment is not None and str(selected_equipment.type) == "Solar":
            eff_val = selected_equipment.efficiency
            if eff_val is not None: efficiency = float(cast(float, eff_val))
            model_name = str(selected_equipment.name)

        results = await run_in_threadpool(
            solar_calculations.calculate_solar_power_production,
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            panel_area=panel_area,
            panel_efficiency=efficiency,
            weather_stats=weather_stats
        )
        
        if "error" in results: raise HTTPException(status_code=500, detail=results["error"])
        
        annual_kwh = float(results["predicted_annual_production_kwh"])
        avg_rad = float(results["daily_avg_potential_kwh_m2"])
        
        # Finansal analiz (Basit)
        financials = calculate_financials(annual_kwh, "Solar")
        
        solar_res = schemas.SolarCalculationResponse(
            solar_irradiance_kw_m2=avg_rad,
            temperature_celsius=25.0,
            panel_efficiency=efficiency,
            power_output_kw=annual_kwh,
            panel_model=model_name,
            potential_kwh_annual=annual_kwh,
            performance_ratio=0.80,
            monthly_production=results.get("month_by_month_prediction"),
            financials=financials
        )
        
        calculation_result = schemas.PinCalculationResponse(
            resource_type="Güneş Paneli", 
            solar_calculation=solar_res
        ).model_dump()
        
        # Pinin özet alanlarını güncelle
        crud.update_pin(db, pin_id, schemas.PinCreate(**pin_data.model_dump()), user_id)
        # Sadece irradiance update etmek istiyoruz ama update_pin full obje alıyor.
        # Manuel update yapalım:
        pin_obj.avg_solar_irradiance = avg_rad
        
    elif pin_data.type == "Rüzgar Türbini":
        model_name = "Standart 3.3MW Türbin"
        if selected_equipment is not None and str(selected_equipment.type) == "Wind":
             model_name = str(selected_equipment.name)

        results = await run_in_threadpool(
            wind_calculations.calculate_wind_power_production,
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            weather_stats=weather_stats
        )
        
        if "error" in results: raise HTTPException(status_code=500, detail=results["error"])
        
        annual_kwh = float(results["predicted_annual_production_kwh"])
        avg_speed = float(results["avg_wind_speed_ms"])
        avg_monthly = annual_kwh / 12.0
        # Basit bir aylık dağılım (Simülasyon)
        monthly_sim = { "Ocak": avg_monthly * 1.2, "Haziran": avg_monthly * 0.8 } 

        financials = calculate_financials(annual_kwh, "Wind")

        wind_res = schemas.WindCalculationResponse(
            wind_speed_m_s=avg_speed,
            power_output_kw=annual_kwh,
            turbine_model=model_name,
            potential_kwh_annual=annual_kwh,
            capacity_factor=float(results.get("capacity_factor", 0.3)),
            monthly_production=monthly_sim,
            financials=financials
        )
        
        calculation_result = schemas.PinCalculationResponse(
            resource_type="Rüzgar Türbini", 
            wind_calculation=wind_res
        ).model_dump()
        
        pin_obj.avg_wind_speed = avg_speed

    # 4. Sonucu Kaydedelim (PinAnalysis)
    if calculation_result:
        crud.create_or_update_pin_analysis(db, pin_id, calculation_result)
        db.commit() # Pin update'i de commitler
        
    # 5. Güncel pin'i analiziyle beraber dön
    db.refresh(pin_obj)
    
    # Analysis verisini schema'ya maplemek için:
    # SQLalchemy modelinde 'analysis' ilişkisi var.
    # PinResponse içinde 'analysis' alanı var (Dict).
    # result_data JSON olduğu için direkt Dict olarak gelir.
    
    # Yanıtı hazırla
    resp = schemas.PinResponse.model_validate(pin_obj)
    if pin_obj.analysis:
        resp.analysis = pin_obj.analysis.result_data
        
    return resp
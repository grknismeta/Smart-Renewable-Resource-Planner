from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional, cast, Dict, Any

from .. import crud, models, schemas, auth, solar_calculations, wind_calculations
from ..database import get_db, get_system_db
from ..schemas import PinCalculationResponse, SolarCalculationResponse, WindCalculationResponse, PinBase, FinancialAnalysis

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
    current_user: models.User = Depends(auth.get_current_active_user)
):
    user_id = cast(int, current_user.id)
    pins = crud.get_pins_by_owner(db, owner_id=user_id, skip=skip, limit=limit)
    print(f'[Pins Router] GET /pins/ - user_id={user_id}, {len(pins)} pin döndürüldü')
    return pins

@router.post("/calculate", response_model=PinCalculationResponse)
def calculate_pin_potential(
    pin_data: PinBase, 
    db: Session = Depends(get_db),
    system_db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    # 1. Hava Verilerini Çek
    # crud.get_weather_stats returns Dict[str, Any] or None.
    weather_stats = crud.get_weather_stats(system_db, float(pin_data.latitude), float(pin_data.longitude))
    
    # Handle None weather_stats to avoid Pylance errors later
    if weather_stats is None:
        print(f"Bilgi: ({pin_data.latitude}, {pin_data.longitude}) için veri yok. Fallback kullanılıyor.")
        weather_stats = {} 
    
    # 2. Ekipman
    selected_equipment: Optional[models.Equipment] = None
    if pin_data.equipment_id is not None:
        selected_equipment = crud.get_equipment(system_db, pin_data.equipment_id)

    # --- GÜNEŞ ---
    if pin_data.type == "Güneş Paneli":
        panel_area = float(pin_data.panel_area or 10.0)
        efficiency: float = 0.20
        model_name: str = "Veri Analizli Standart Panel"
        
        # Pylance fix: Explicit check for None
        if selected_equipment is not None and str(selected_equipment.type) == "Solar":
            # Extract value from Column and cast to float if not None
            eff_val = selected_equipment.efficiency
            if eff_val is not None:
                efficiency = float(cast(float, eff_val))
            model_name = str(selected_equipment.name)

        results = solar_calculations.calculate_solar_power_production(
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            panel_area=panel_area,
            panel_efficiency=efficiency,
            weather_stats=weather_stats
        )
        
        annual_kwh = float(results["predicted_annual_production_kwh"])
        
        solar_res = SolarCalculationResponse(
            solar_irradiance_kw_m2=float(results["daily_avg_potential_kwh_m2"]),
            temperature_celsius=25.0,
            panel_efficiency=efficiency,
            power_output_kw=annual_kwh,
            panel_model=model_name,
            potential_kwh_annual=annual_kwh,
            performance_ratio=0.80,
            monthly_production=results.get("month_by_month_prediction"), # Grafik verisi
            financials=calculate_financials(annual_kwh, "Solar") # Finans verisi
        )
        return PinCalculationResponse(resource_type="Güneş Paneli", solar_calculation=solar_res)

    # --- RÜZGAR ---
    elif pin_data.type == "Rüzgar Türbini":
        model_name = "Standart 3.3MW Türbin"
        
        # Pylance fix: Explicit check for None
        if selected_equipment is not None and str(selected_equipment.type) == "Wind":
            model_name = str(selected_equipment.name)

        results = wind_calculations.calculate_wind_power_production(
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            weather_stats=weather_stats
        )
        
        annual_kwh = float(results["predicted_annual_production_kwh"])
        
        # Rüzgar için basit aylık simülasyon (Backend hesaplamıyorsa burada üret)
        # Rüzgar kışın %20 daha fazladır genelde.
        avg_monthly = annual_kwh / 12.0
        monthly_sim = {
            "Ocak": avg_monthly * 1.2, "Şubat": avg_monthly * 1.1, "Mart": avg_monthly * 1.1,
            "Nisan": avg_monthly * 1.0, "Mayıs": avg_monthly * 0.9, "Haziran": avg_monthly * 0.8,
            "Temmuz": avg_monthly * 0.8, "Ağustos": avg_monthly * 0.8, "Eylül": avg_monthly * 0.9,
            "Ekim": avg_monthly * 1.0, "Kasım": avg_monthly * 1.1, "Aralık": avg_monthly * 1.2
        }

        wind_res = WindCalculationResponse(
            wind_speed_m_s=float(results["avg_wind_speed_ms"]),
            power_output_kw=annual_kwh,
            turbine_model=model_name,
            potential_kwh_annual=annual_kwh,
            capacity_factor=float(results["capacity_factor"]),
            monthly_production=monthly_sim, # Simüle edilmiş grafik verisi
            financials=calculate_financials(annual_kwh, "Wind")
        )
        return PinCalculationResponse(resource_type="Rüzgar Türbini", wind_calculation=wind_res)

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
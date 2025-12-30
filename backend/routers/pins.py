from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional, cast, Dict, Any

from backend import auth
from backend.crud import crud
from backend.schemas import schemas
from backend.db import models
from backend.services import solar_service as solar_calculations, wind_service as wind_calculations
from backend.db.database import get_db, get_system_db, get_user_pins_db
from backend.schemas.schemas import PinCalculationResponse, SolarCalculationResponse, WindCalculationResponse, PinBase, FinancialAnalysis

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
def calculate_pin_potential(
    pin_data: PinBase, 
    db: Session = Depends(get_db),
    system_db: Session = Depends(get_system_db),
    user_pins_db: Session = Depends(get_user_pins_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Pinin potansiyelini hesaplar.
    1. Grid verisi var mı bakar (Hızlı).
    2. Yoksa veya detay gerekliyse On-Demand Collector ile gerçek veri çeker.
    3. Sonuçları `user_pins_data.db`'ye kaydeder.
    """
    
    # 1. On-Demand Veri Çekme (Grid'den bağımsız her nokta için)
    # Performans notu: Her 'hesapla' butonunda API'ye gitmek istemiyorsak burada DB kontrolü yapmalıyız.
    # Ancak pin_id request'te gelmiyor (PinBase). Pin yaratılmadan hesaplanıyor olabilir.
    # Eğer bu geçici bir hesaplama ise (Create Screen), enlem/boylama göre cache/DB bakabiliriz.
    
    from backend.services.collectors.on_demand import fetch_point_climate_data
    
    # Önce o koordinata yakın hesaplanmış bir veri var mı? (Cache mantığı)
    # Hassasiyet: 0.001 derece (~100m)
    cached_result = user_pins_db.query(models.PinCalculationResult).filter(
        models.PinCalculationResult.latitude > pin_data.latitude - 0.001,
        models.PinCalculationResult.latitude < pin_data.latitude + 0.001,
        models.PinCalculationResult.longitude > pin_data.longitude - 0.001,
        models.PinCalculationResult.longitude < pin_data.longitude + 0.001
    ).order_by(models.PinCalculationResult.calculated_at.desc()).first()
    
    climate_data = {}
    
    if cached_result:
        # Cache Hit
        print(f"Cache Hit for ({pin_data.latitude}, {pin_data.longitude})")
        climate_data = {
           "annual_summary": {
               "avg_wind": cached_result.avg_wind_speed,
               "total_solar_kwh_m2": cached_result.avg_solar_irradiance * 365 if cached_result.avg_solar_irradiance else 0, # Reverse log
               "avg_temp": cached_result.avg_temperature
           },
           "monthly_data": cached_result.monthly_data
        }
    else:
        # Cache Miss - Fetch Live
        print(f"Fetching live data for ({pin_data.latitude}, {pin_data.longitude})")
        fetched = fetch_point_climate_data(pin_data.latitude, pin_data.longitude)
        if "error" in fetched:
            # Fallback to Grid Data if API fails
            grid_weather = crud.get_weather_stats(system_db, pin_data.latitude, pin_data.longitude)
            # Convert grid format to consistent format... (Complexity skipped for brevity, using simple fallback)
            if grid_weather and "annual_avg" in grid_weather:
                 climate_data = {
                    "annual_summary": {
                        "avg_wind": grid_weather["annual_avg"]["wind"],
                        "total_solar_kwh_m2": (grid_weather["annual_avg"]["solar"] / 3.6) * 365,
                        "avg_temp": 15.0 # Dummy
                    },
                    "monthly_data": [] # Grid doesn't store monthly detail in same format yet
                 }
        else:
            climate_data = fetched
            
            # Save to User Pins DB for next time
            new_cache = models.PinCalculationResult(
                latitude=pin_data.latitude,
                longitude=pin_data.longitude,
                pin_id=None, # Henüz pin kaydedilmediyse null
                annual_total_energy_kwh=0, # Enerji aşağıda hesaplanacak
                avg_wind_speed=fetched["annual_summary"]["avg_wind"],
                avg_solar_irradiance=fetched["annual_summary"]["daily_avg_solar_kwh_m2"],
                avg_temperature=fetched["annual_summary"]["avg_temp"],
                monthly_data=fetched["monthly_data"]
            )
            user_pins_db.add(new_cache)
            user_pins_db.commit()
            cached_result = new_cache # Referans al
    
    # 2. Ekipman Seçimi
    selected_equipment: Optional[models.Equipment] = None
    if pin_data.equipment_id is not None:
        selected_equipment = crud.get_equipment(system_db, pin_data.equipment_id)
        
    # --- GÜNEŞ HESABI ---
    if pin_data.type == "Güneş Paneli":
        panel_area = float(pin_data.panel_area or 10.0)
        efficiency: float = 0.20
        model_name: str = "Veri Analizli Standart Panel"
        
        if selected_equipment and str(selected_equipment.type) == "Solar":
            eff_val = selected_equipment.efficiency
            if eff_val is not None: efficiency = float(cast(float, eff_val))
            model_name = str(selected_equipment.name)
            
        # Basit Fiziksel Hesap
        # E = H * A * eff * PR
        # H (Annual Solar) var mı?
        annual_solar_kwh_m2 = climate_data.get("annual_summary", {}).get("total_solar_kwh_m2", 1600.0)
        
        annual_production = annual_solar_kwh_m2 * panel_area * efficiency * 0.80 # PR
        
        # Aylık Dağılım
        monthly_prod_dict = {}
        monthly_stats = climate_data.get("monthly_data", [])
        if monthly_stats:
            for m in monthly_stats:
                # m['total_solar_kwh_m2'] aylık toplam ışınım
                m_prod = m['total_solar_kwh_m2'] * panel_area * efficiency * 0.80
                # Ay ismini bul
                month_names = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
                m_name = month_names[m['month']]
                monthly_prod_dict[m_name] = round(m_prod, 2)
        else:
             monthly_prod_dict = {"Genel": round(annual_production/12, 2)}

        # DB Update (Energy)
        if cached_result:
            cached_result.annual_total_energy_kwh = annual_production
            user_pins_db.commit()

        solar_res = SolarCalculationResponse(
            solar_irradiance_kw_m2=round(annual_solar_kwh_m2 / 365, 2), # Daily avg
            temperature_celsius=climate_data.get("annual_summary", {}).get("avg_temp", 25.0),
            panel_efficiency=efficiency,
            power_output_kw=annual_production, # Yıllık
            panel_model=model_name,
            potential_kwh_annual=round(annual_production, 2),
            performance_ratio=0.80,
            monthly_production=monthly_prod_dict, 
            financials=calculate_financials(annual_production, "Solar")
        )
        return PinCalculationResponse(resource_type="Güneş Paneli", solar_calculation=solar_res)

    # --- RÜZGAR HESABI ---
    elif pin_data.type == "Rüzgar Türbini":
        model_name = "Standart 3.3MW Türbin"
        if selected_equipment and str(selected_equipment.type) == "Wind":
            model_name = str(selected_equipment.name)
            
        avg_speed = climate_data.get("annual_summary", {}).get("avg_wind", 6.0)
        
        # Wind Service Reuse (Logic only)
        # Rüzgar servisi dict bekliyor, ona uygun formatı hazırlayalım
        weather_stats_adapter = {
            "annual_avg": {"wind": avg_speed}
        }
        
        wind_results = wind_calculations.calculate_wind_power_production(
            pin_data.latitude, pin_data.longitude, weather_stats_adapter
        )
        
        annual_production = wind_results["predicted_annual_production_kwh"]
        
        # Aylık Dağılım
        monthly_prod_dict = {}
        monthly_stats = climate_data.get("monthly_data", [])
        if monthly_stats:
             # Rüzgar hızı küpü ile orantılı olduğu için aylık hıza göre oranlayacağız
             total_speed_cubed = sum([m['avg_wind']**3 for m in monthly_stats])
             if total_speed_cubed > 0:
                 for m in monthly_stats:
                     share = (m['avg_wind']**3) / total_speed_cubed
                     m_prod = annual_production * share
                     month_names = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
                     m_name = month_names[m['month']]
                     monthly_prod_dict[m_name] = round(m_prod, 2)
        
        if not monthly_prod_dict:
             monthly_prod_dict = {"Genel": round(annual_production/12, 2)}

        # DB Update
        if cached_result:
            cached_result.annual_total_energy_kwh = annual_production
            user_pins_db.commit()

        wind_res = WindCalculationResponse(
            wind_speed_m_s=wind_results["avg_wind_speed_ms"],
            power_output_kw=annual_production,
            turbine_model=model_name,
            potential_kwh_annual=annual_production,
            capacity_factor=wind_results["capacity_factor"],
            monthly_production=monthly_prod_dict,
            financials=calculate_financials(annual_production, "Wind")
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
from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.concurrency import run_in_threadpool # <--- SİHİRLİ İMPORT
from sqlalchemy.orm import Session
from typing import List, Optional, cast, Dict, Any

from .. import auth # Updated import
from app.crud import crud
from app.schemas import schemas
from app.db import models
from app.services import solar_service as solar_calculations, wind_service as wind_calculations
from app.services.hydro_service import calculate_annual_hydro_production, suggest_turbine_type, analyze_two_points
from app.services.hourly_weather_helper import get_hourly_weather_for_pin
from app.db.database import get_db, get_system_db, get_user_pins_db
from app.schemas.schemas import PinCalculationResponse, SolarCalculationResponse, WindCalculationResponse, HydroCalculationResponse, PinBase, FinancialAnalysis

router = APIRouter()

# ---------------------------------------------------------------------------
# Kaynak başı finansal parametreler — Türkiye 2024-2025
#   capex_per_kw   : Kurulum maliyeti ($/kW kurulu güç)
#   om_per_kw_yr   : Yıllık işletme-bakım maliyeti ($/kW/yıl)
#   lifetime       : Sistem ömrü (yıl)
#   yekdem_price   : YEKDEM garantili alım fiyatı ($/kWh, ilk 10 yıl)
#   market_price   : Serbest piyasa fiyatı ($/kWh, YEKDEM sonrası)
#   yekdem_years   : YEKDEM garanti süresi (yıl)
#   degradation    : Yıllık verim düşüşü (0.0 = yok, 0.005 = %0.5)
# ---------------------------------------------------------------------------
_FINANCIAL_PARAMS: dict = {
    "Solar": dict(
        capex_per_kw=700.0, om_per_kw_yr=10.0, lifetime=25,
        yekdem_price=0.133, market_price=0.070, yekdem_years=10,
        degradation=0.005,   # Güneş paneli: %0.5/yıl degredason
    ),
    "Wind": dict(
        capex_per_kw=1200.0, om_per_kw_yr=15.0, lifetime=20,
        yekdem_price=0.073, market_price=0.070, yekdem_years=10,
        degradation=0.0,
    ),
    "Hydro": dict(
        capex_per_kw=2500.0, om_per_kw_yr=12.0, lifetime=40,
        yekdem_price=0.073, market_price=0.070, yekdem_years=10,
        degradation=0.0,
    ),
}


def _npv_at_rate(
    r: float, capex: float, annual_kwh: float, om_annual: float,
    lifetime: int, degradation: float,
    yekdem_yrs: int, price_yekdem: float, price_market: float,
) -> float:
    total = -capex
    for t in range(1, lifetime + 1):
        production = annual_kwh * ((1.0 - degradation) ** (t - 1))
        price     = price_yekdem if t <= yekdem_yrs else price_market
        net_cf    = production * price - om_annual
        total    += net_cf / ((1.0 + r) ** t)
    return total


def _calculate_irr(
    capex: float, annual_kwh: float, om_annual: float,
    lifetime: int, degradation: float,
    yekdem_yrs: int, price_yekdem: float, price_market: float,
) -> float:
    """Bisection yöntemiyle İç Verim Oranı (IRR) hesaplar."""
    if capex <= 0:
        return 0.0

    def f(r: float) -> float:
        return _npv_at_rate(r, capex, annual_kwh, om_annual, lifetime,
                            degradation, yekdem_yrs, price_yekdem, price_market)

    if f(0.0) <= 0:
        return -0.50          # Proje hiç geri dönmüyor

    high = 5.0               # %500 üst sınır
    if f(high) > 0:
        return 5.0           # IRR > %500 → gerçekçi değil, kapat

    low = 0.0
    for _ in range(80):
        mid = (low + high) / 2.0
        if abs(high - low) < 1e-6:
            break
        if f(mid) > 0:
            low = mid
        else:
            high = mid
    return (low + high) / 2.0


def _calculate_payback(
    capex: float, annual_kwh: float, om_annual: float,
    lifetime: int, degradation: float,
    yekdem_yrs: int, price_yekdem: float, price_market: float,
) -> float:
    """Kümülatif nakit akışlarına göre geri ödeme süresini hesaplar."""
    cumulative = 0.0
    for t in range(1, lifetime + 1):
        production = annual_kwh * ((1.0 - degradation) ** (t - 1))
        price      = price_yekdem if t <= yekdem_yrs else price_market
        net_cf     = production * price - om_annual
        cumulative += net_cf
        if cumulative >= capex:
            prev     = cumulative - net_cf
            fraction = (capex - prev) / net_cf if net_cf > 0 else 0.0
            return float(t - 1) + fraction
    return float(lifetime)   # Ömür içinde geri dönmüyor


# --- YARDIMCI FONKSİYON: FİNANSAL HESAPLAMA ---
def calculate_financials(
    annual_kwh: float,
    resource_type: str,     # "Solar" | "Wind" | "Hydro"
    capacity_kw: float,
    pricing_mode: str = "yekdem",
) -> FinancialAnalysis:
    """
    Gerçekçi yatırım geri dönüş analizi — Türkiye 2024-2025 değerleriyle.

    NPV  : %8 iskonto oranıyla Net Bugünkü Değer
    LCOE : Normalleştirilmiş Enerji Maliyeti ($/kWh)
    IRR  : İç Verim Oranı (bisection ile)
    YEKDEM: İlk 10 yıl garantili tarife, ardından serbest piyasa
    """
    p = _FINANCIAL_PARAMS.get(resource_type, _FINANCIAL_PARAMS["Solar"])

    capacity_kw = max(capacity_kw, 0.001)
    capex       = p["capex_per_kw"]   * capacity_kw
    om_annual   = p["om_per_kw_yr"]   * capacity_kw
    lifetime    = p["lifetime"]
    degradation = p["degradation"]
    r           = 0.08  # %8 iskonto oranı

    if pricing_mode == "yekdem":
        price_yekdem = p["yekdem_price"]
        price_market = p["market_price"]
        yekdem_yrs   = p["yekdem_years"]
    else:                              # "market"
        price_yekdem = p["market_price"]
        price_market = p["market_price"]
        yekdem_yrs   = 0

    # ── Nakit akışı simülasyonu ───────────────────────────────────────────────
    pv_cashflows     = 0.0
    pv_energy        = 0.0
    pv_costs         = capex      # CAPEX bugünkü değeri maliyet toplamına eklendi
    lifetime_revenue = 0.0

    for t in range(1, lifetime + 1):
        production = annual_kwh * ((1.0 - degradation) ** (t - 1))
        price      = price_yekdem if t <= yekdem_yrs else price_market
        revenue    = production * price
        net_cf     = revenue - om_annual
        discount   = (1.0 + r) ** t
        pv_cashflows  += net_cf    / discount
        pv_energy     += production / discount
        pv_costs      += om_annual  / discount   # O&M'in bugünkü değeri
        lifetime_revenue += revenue

    npv  = pv_cashflows - capex
    lcoe = pv_costs / pv_energy if pv_energy > 0 else 0.0

    irr_val = _calculate_irr(
        capex, annual_kwh, om_annual, lifetime, degradation,
        yekdem_yrs, price_yekdem, price_market,
    )
    payback = _calculate_payback(
        capex, annual_kwh, om_annual, lifetime, degradation,
        yekdem_yrs, price_yekdem, price_market,
    )

    first_price    = price_yekdem if yekdem_yrs >= 1 else price_market
    annual_earning = annual_kwh * first_price - om_annual
    roi            = (annual_earning / capex) * 100 if capex > 0 else 0.0

    return FinancialAnalysis(
        initial_investment_usd = round(capex, 0),
        annual_earnings_usd    = round(annual_earning, 2),
        payback_period_years   = round(payback, 1),
        roi_percentage         = round(roi, 1),
        lcoe_usd_kwh           = round(lcoe, 4),
        npv_usd                = round(npv, 0),
        irr_percentage         = round(irr_val * 100, 1),
        lifetime_revenue_usd   = round(lifetime_revenue, 0),
        pricing_mode           = pricing_mode,
        price_per_kwh_usd      = first_price,
        lifetime_years         = lifetime,
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
    # 1. Hava Verilerini Çek — önce saatlik, bulamazsa grid fallback
    hourly_result = await run_in_threadpool(
        get_hourly_weather_for_pin,
        system_db, float(pin_data.latitude), float(pin_data.longitude), 365
    )
    hourly_data = hourly_result.get("hours", []) if hourly_result else []

    # Fallback: saatlik veri yoksa eski grid ortalaması
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

        # Saatlik veriden hesapla, yoksa fallback
        results = await run_in_threadpool(
            solar_calculations.calculate_solar_power_production,
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            panel_area=panel_area,
            panel_efficiency=efficiency,
            weather_stats=weather_stats,
            hourly_data=hourly_data,
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

        # Saatlik veriden hesapla, yoksa fallback
        results = await run_in_threadpool(
            wind_calculations.calculate_wind_power_production,
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            weather_stats=weather_stats,
            hourly_data=hourly_data,
        )
        
        if "error" in results: raise HTTPException(status_code=500, detail=results["error"])
        
        annual_kwh = float(results["predicted_annual_production_kwh"])

        # Saatlik veriden gelen aylık kırılımı kullan, yoksa basit sim
        monthly_prod = results.get("month_by_month_prediction")
        if not monthly_prod:
            avg_monthly = annual_kwh / 12.0
            monthly_prod = {"Ocak": avg_monthly * 1.2, "Haziran": avg_monthly * 0.8}

        wind_res = WindCalculationResponse(
            wind_speed_m_s=float(results["avg_wind_speed_ms"]),
            power_output_kw=annual_kwh,
            turbine_model=model_name,
            potential_kwh_annual=annual_kwh,
            capacity_factor=float(results.get("capacity_factor", 0.3)),
            monthly_production=monthly_prod,
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
    ).order_by(models.GridAnalysis.overall_score.desc()).limit(1000).all()

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
        equipment_id=pin_obj.equipment_id, # type: ignore
        flow_rate=pin_obj.flow_rate, # type: ignore
        head_height=pin_obj.head_height, # type: ignore
        basin_area_km2=pin_obj.basin_area_km2, # type: ignore
    )
    
    # 3. Hesaplama yap — önce saatlik veri, sonra fallback
    hourly_result = await run_in_threadpool(
        get_hourly_weather_for_pin,
        system_db, float(pin_data.latitude), float(pin_data.longitude), 365
    )
    hourly_data = hourly_result.get("hours", []) if hourly_result else []

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
            weather_stats=weather_stats,
            hourly_data=hourly_data,
        )

        if "error" in results: raise HTTPException(status_code=500, detail=results["error"])

        annual_kwh = float(results["predicted_annual_production_kwh"])
        avg_rad = float(results["daily_avg_potential_kwh_m2"])

        # Panel kapasitesi fizikten türetilir: kWp = alan(m²) × verim × 1kW/m²
        capacity_kw_solar = panel_area * efficiency
        financials = calculate_financials(annual_kwh, "Solar", capacity_kw_solar)

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

        # Pinin avg_solar_irradiance alanını güncelle (commit sonraki blokta yapılıyor)
        pin_obj.avg_solar_irradiance = avg_rad

    elif pin_data.type == "Rüzgar Türbini":
        model_name = "Standart 3.3MW Türbin"
        if selected_equipment is not None and str(selected_equipment.type) == "Wind":
             model_name = str(selected_equipment.name)

        results = await run_in_threadpool(
            wind_calculations.calculate_wind_power_production,
            latitude=float(pin_data.latitude),
            longitude=float(pin_data.longitude),
            weather_stats=weather_stats,
            hourly_data=hourly_data,
        )
        
        if "error" in results: raise HTTPException(status_code=500, detail=results["error"])
        
        annual_kwh = float(results["predicted_annual_production_kwh"])
        avg_speed = float(results["avg_wind_speed_ms"])

        # Saatlik veriden gelen aylık kırılımı kullan
        monthly_prod = results.get("month_by_month_prediction")
        if not monthly_prod:
            avg_monthly = annual_kwh / 12.0
            monthly_prod = {"Ocak": avg_monthly * 1.2, "Haziran": avg_monthly * 0.8}

        # Kapasite: kullanıcının girdiği MW → kW
        capacity_kw_wind = float(pin_data.capacity_mw) * 1000.0
        financials = calculate_financials(annual_kwh, "Wind", capacity_kw_wind)

        wind_res = schemas.WindCalculationResponse(
            wind_speed_m_s=avg_speed,
            power_output_kw=annual_kwh,
            turbine_model=model_name,
            potential_kwh_annual=annual_kwh,
            capacity_factor=float(results.get("capacity_factor", 0.3)),
            monthly_production=monthly_prod,
            financials=financials
        )
        
        calculation_result = schemas.PinCalculationResponse(
            resource_type="Rüzgar Türbini", 
            wind_calculation=wind_res
        ).model_dump()
        
        pin_obj.avg_wind_speed = avg_speed

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
        if selected_equipment is not None and str(selected_equipment.type) == "Hydro":
            specs_data = selected_equipment.specs or {}
            turbine_type = specs_data.get("turbine_type", turbine_type)

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

        # HES finansal analizi — servisten gelen rated_power_kw kullanılır
        hes_annual_kwh = float(hydro_results.get("predicted_annual_production_kwh", 0.0))
        hes_rated_kw   = float(hydro_results.get("rated_power_kw", 0.0))
        hes_financials = calculate_financials(hes_annual_kwh, "Hydro", hes_rated_kw)

        hydro_res = schemas.HydroCalculationResponse(**hydro_results, financials=hes_financials)
        calculation_result = schemas.PinCalculationResponse(
            resource_type="Hidroelektrik",
            hydro_calculation=hydro_res
        ).model_dump()

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


# --- HES: İKİ NOKTA ELEVATION ANALİZİ ---

from pydantic import BaseModel as PydanticBaseModel

class TwoPointRequest(PydanticBaseModel):
    """İki noktalı HES düşü analizi isteği"""
    intake_lat: float
    intake_lon: float
    turbine_lat: float
    turbine_lon: float
    flow_rate: Optional[float] = None

@router.post("/hydro/elevation")
async def hydro_elevation_analysis(
    req: TwoPointRequest,
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    İki nokta (Su Alma Yapısı ve Türbin) arasında:
    - Rakım farkı (Brüt Düşü)
    - Mesafe (Kuş uçuşu + arazi düzeltmeli)
    - Cebri Boru (Penstock) maliyet tahmini
    - Önerilen türbin tipi
    hesaplar.
    """
    result = await run_in_threadpool(
        analyze_two_points,
        intake_lat=req.intake_lat,
        intake_lon=req.intake_lon,
        turbine_lat=req.turbine_lat,
        turbine_lon=req.turbine_lon,
        flow_rate=req.flow_rate,
    )
    
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])

    return result


# ── Toplu Pin Re-Analiz ──────────────────────────────────────────────────────

@router.post("/batch/reanalyze")
async def batch_reanalyze_pins(
    db: Session = Depends(get_db),
    system_db: Session = Depends(get_system_db),
    user_pins_db: Session = Depends(get_user_pins_db),
    current_user: models.User = Depends(auth.get_current_active_user),
):
    """
    Kullanıcının tüm pinlerini güncel saatlik verilerle yeniden analiz eder.
    Frontend'den "Tüm Pinleri Güncelle" butonu ile tetiklenir.
    """
    user_id = cast(int, current_user.id)
    pins = crud.get_pins_by_owner(db, user_id, limit=500)

    if not pins:
        return {"updated": 0, "errors": 0, "message": "Pin bulunamadı"}

    updated = 0
    errors = 0
    details: list = []

    for pin_obj in pins:
        try:
            lat = float(pin_obj.latitude)  # type: ignore
            lon = float(pin_obj.longitude)  # type: ignore
            pin_type = str(pin_obj.type)  # type: ignore

            # Saatlik veri çek
            hourly_result = await run_in_threadpool(
                get_hourly_weather_for_pin, system_db, lat, lon, 365
            )
            hourly_data = hourly_result.get("hours", []) if hourly_result else []
            weather_stats = crud.get_weather_stats(system_db, lat, lon) or {}

            result_data: Optional[dict] = None

            if pin_type == "Güneş Paneli":
                panel_area = float(pin_obj.panel_area or 10.0)  # type: ignore
                efficiency = 0.20
                eq = crud.get_equipment(system_db, pin_obj.equipment_id) if pin_obj.equipment_id else None  # type: ignore
                if eq and str(eq.type) == "Solar" and eq.efficiency:
                    efficiency = float(eq.efficiency)

                results = await run_in_threadpool(
                    solar_calculations.calculate_solar_power_production,
                    latitude=lat, longitude=lon,
                    panel_area=panel_area, panel_efficiency=efficiency,
                    weather_stats=weather_stats, hourly_data=hourly_data,
                )
                if "error" not in results:
                    annual_kwh = float(results["predicted_annual_production_kwh"])
                    capacity_kw = panel_area * efficiency
                    financials = calculate_financials(annual_kwh, "Solar", capacity_kw)
                    result_data = {
                        "resource_type": "Güneş Paneli",
                        "solar_calculation": {
                            "solar_irradiance_kw_m2": results["daily_avg_potential_kwh_m2"],
                            "potential_kwh_annual": annual_kwh,
                            "monthly_production": results.get("month_by_month_prediction"),
                            "financials": financials,
                            "method": results.get("method"),
                        },
                    }
                    pin_obj.avg_solar_irradiance = results["daily_avg_potential_kwh_m2"]  # type: ignore

            elif pin_type == "Rüzgar Türbini":
                results = await run_in_threadpool(
                    wind_calculations.calculate_wind_power_production,
                    latitude=lat, longitude=lon,
                    weather_stats=weather_stats, hourly_data=hourly_data,
                )
                if "error" not in results:
                    annual_kwh = float(results["predicted_annual_production_kwh"])
                    capacity_kw = float(pin_obj.capacity_mw or 3.3) * 1000.0  # type: ignore
                    financials = calculate_financials(annual_kwh, "Wind", capacity_kw)
                    result_data = {
                        "resource_type": "Rüzgar Türbini",
                        "wind_calculation": {
                            "wind_speed_m_s": results["avg_wind_speed_ms"],
                            "potential_kwh_annual": annual_kwh,
                            "capacity_factor": results.get("capacity_factor"),
                            "monthly_production": results.get("month_by_month_prediction"),
                            "financials": financials,
                            "method": results.get("method"),
                        },
                    }
                    pin_obj.avg_wind_speed = results["avg_wind_speed_ms"]  # type: ignore

            # HES pinlerini atla (yağış verisi zaten uzun süreli)

            if result_data:
                crud.create_or_update_pin_analysis(user_pins_db, int(pin_obj.id), result_data)  # type: ignore
                updated += 1
                details.append({"pin_id": pin_obj.id, "status": "ok"})  # type: ignore
            else:
                details.append({"pin_id": pin_obj.id, "status": "skipped"})  # type: ignore

        except Exception as e:
            errors += 1
            details.append({"pin_id": pin_obj.id, "status": "error", "msg": str(e)})  # type: ignore

    try:
        db.commit()
    except Exception:
        db.rollback()

    return {
        "updated": updated,
        "errors": errors,
        "total": len(pins),
        "details": details,
    }
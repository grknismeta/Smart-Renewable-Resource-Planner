from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Dict, Any, Optional, cast
from pydantic import BaseModel
import math

from .. import crud, models, schemas, auth
from ..database import get_system_db

router = APIRouter(
    prefix="/optimization",
    tags=["Optimization"],
)

# --- İSTEK & CEVAP MODELLERİ ---

class OptimizationRequest(BaseModel):
    # Seçilen Alan (Bounding Box)
    top_left_lat: float
    top_left_lon: float
    bottom_right_lat: float
    bottom_right_lon: float
    
    equipment_id: int # Hangi türbin kullanılacak?
    
    # Kısıtlamalar (Opsiyonel)
    min_distance_m: float = 0.0 

class OptimizedPoint(BaseModel):
    latitude: float
    longitude: float
    wind_speed_ms: float
    annual_production_kwh: float
    score: float 

class OptimizationResponse(BaseModel):
    total_capacity_mw: float
    total_annual_production_kwh: float
    turbine_count: int
    points: List[OptimizedPoint]

# --- YARDIMCI MATEMATİK ---
def haversine_distance(lat1, lon1, lat2, lon2):
    """İki koordinat arası metre cinsinden mesafe."""
    R = 6371000 
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2) * math.sin(dlambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

# --- ENDPOINT ---

@router.post("/wind-placement", response_model=OptimizationResponse)
def optimize_wind_farm_placement(
    req: OptimizationRequest,
    db: Session = Depends(get_system_db),
):
    """
    Seçilen alanda optimum rüzgar türbini yerleşimini hesaplar.
    """
    
    # 1. Ekipman Bilgisi
    equipment_orm = crud.get_equipment(db, req.equipment_id)
    if not equipment_orm:
        raise HTTPException(status_code=400, detail="Ekipman bulunamadı.")
        
    # Pylance için: equipment değişkenini model tipine zorla
    equipment = cast(models.Equipment, equipment_orm)
    
    # Tip kontrolü için güvenli erişim (Any cast ile)
    eq_type: Any = equipment.type
    if str(eq_type) != "Wind":
        raise HTTPException(status_code=400, detail="Geçerli bir rüzgar türbini seçilmelidir.")
    
    rotor_diameter = 100.0 # Varsayılan
    
    # Pylance Fix: 'specs' alanını güvenli bir şekilde dict olarak al
    specs_val = cast(Optional[Dict[str, Any]], equipment.specs)
    
    if specs_val is not None and isinstance(specs_val, dict) and "rotor_diameter_m" in specs_val:
        val = specs_val["rotor_diameter_m"]
        # Gelen değerin sayısal olduğundan emin ol
        try:
            rotor_diameter = float(val)
        except (ValueError, TypeError):
            pass # Varsayılan kalır
    
    # İki türbin arası minimum mesafe
    min_dist = req.min_distance_m if req.min_distance_m > 0 else (rotor_diameter * 5)
    
    # 2. Bölgedeki Grid Verilerini Çek
    query = db.query(models.GridAnalysis).filter(
        models.GridAnalysis.type == "Wind",
        models.GridAnalysis.latitude <= req.top_left_lat,
        models.GridAnalysis.latitude >= req.bottom_right_lat,
        models.GridAnalysis.longitude >= req.top_left_lon,
        models.GridAnalysis.longitude <= req.bottom_right_lon,
        models.GridAnalysis.overall_score > 20 
    )
    
    # Pylance Fix: Sonucu açıkça liste olarak işaretle
    results = query.all()
    grid_points = cast(List[models.GridAnalysis], results)
    
    # 'if not grid_points' yerine len() kontrolü
    if len(grid_points) == 0:
        return OptimizationResponse(total_capacity_mw=0.0, total_annual_production_kwh=0.0, turbine_count=0, points=[])

    # 3. Puanlama ve Sıralama
    candidates = []
    for gp in grid_points:
        # Pylance Fix: SQLAlchemy modellerinden gelen değerleri Any olarak alıp sonra float'a çeviriyoruz.
        # Bu yöntem Pylance'ın "Column[Unknown]" hatasını bypass eder.
        
        ws_val: Any = gp.avg_wind_speed_ms
        speed = float(ws_val) if ws_val is not None else 0.0
        
        lat_val: Any = gp.latitude
        lon_val: Any = gp.longitude
        
        candidates.append({
            "lat": float(lat_val),
            "lon": float(lon_val),
            "speed": speed,
            "score": speed 
        })
    
    candidates.sort(key=lambda x: x["score"], reverse=True)
    
    # 4. Yerleşim Algoritması (Greedy Placement)
    placed_turbines = []
    
    for candidate in candidates:
        is_valid = True
        for placed in placed_turbines:
            dist = haversine_distance(candidate["lat"], candidate["lon"], placed["lat"], placed["lon"])
            if dist < min_dist:
                is_valid = False
                break
        
        if is_valid:
            placed_turbines.append(candidate)
            # Limit (Sunucu güvenliği)
            if len(placed_turbines) >= 50: 
                break
    
    # 5. Sonuçları Hazırla
    final_points = []
    total_prod = 0.0
    
    # Pylance Fix: Rated power değerini güvenli al (Any cast ile)
    rp_val: Any = equipment.rated_power_kw
    rated_power = float(rp_val) if rp_val is not None else 0.0
    
    for t in placed_turbines:
        # Basit üretim tahmini
        speed = t["speed"]
        # Hız negatif olamaz
        speed = max(0.0, speed)
        
        cf = min(0.50, max(0.20, (speed - 3.0) / 10.0))
        prod = rated_power * cf * 8760
        
        total_prod += prod
        
        final_points.append(OptimizedPoint(
            latitude=t["lat"],
            longitude=t["lon"],
            wind_speed_ms=speed,
            annual_production_kwh=round(prod, 0),
            score=round(t["score"] * 10, 1)
        ))
        
    return OptimizationResponse(
        total_capacity_mw=len(final_points) * (rated_power / 1000.0),
        total_annual_production_kwh=round(total_prod, 0),
        turbine_count=len(final_points),
        points=final_points
    )
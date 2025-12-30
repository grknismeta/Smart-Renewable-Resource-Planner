from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, cast, Any, Dict
from datetime import datetime
import json

from backend import auth
from backend.crud import crud
from backend.db import models
from backend.schemas import schemas
# Services moved
from backend.services import solar_service as solar_calculations, wind_service as wind_calculations
from backend.db.database import get_db
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
    scenarios = db.query(models.Scenario).filter(models.Scenario.owner_id == current_user.id).all()
    
    # JSON/String/None -> List Dönüşümü
    for sc in scenarios:
        if sc.pin_ids is None: # type: ignore
            sc.pin_ids = [] # type: ignore
        elif isinstance(sc.pin_ids, str):
            try:
                sc.pin_ids = json.loads(sc.pin_ids) # type: ignore
            except:
                sc.pin_ids = [] # type: ignore
        else:
            # Already a list or dict? Ensure list
            sc.pin_ids = list(sc.pin_ids) # type: ignore
            
    return scenarios


@router.put("/{scenario_id}", response_model=schemas.ScenarioResponse)
def update_scenario(
    scenario_id: int,
    scenario: schemas.ScenarioCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Mevcut bir senaryoyu günceller.
    """
    db_scenario = db.query(models.Scenario).filter(
        models.Scenario.id == scenario_id,
        models.Scenario.owner_id == current_user.id
    ).first()

    if not db_scenario:
        raise HTTPException(status_code=404, detail="Senaryo bulunamadı")

    # Pin sahipliği kontrolü
    for pin_id in scenario.pin_ids:
        db_pin = db.query(models.Pin).filter(models.Pin.id == pin_id).first()
        if not db_pin:
             raise HTTPException(status_code=404, detail=f"Pin {pin_id} bulunamadı")
        if db_pin.owner_id != current_user.id:
             raise HTTPException(status_code=403, detail=f"Pin {pin_id}'e erişim yetkiniz yok")

    db_scenario.name = scenario.name # type: ignore
    db_scenario.description = scenario.description # type: ignore
    db_scenario.pin_ids = scenario.pin_ids # type: ignore
    # Geriye dönük uyumluluk
    db_scenario.pin_id = scenario.pin_ids[0] if scenario.pin_ids else None # type: ignore
    db_scenario.start_date = scenario.start_date # type: ignore
    db_scenario.end_date = scenario.end_date # type: ignore
    
    # Parametreler değiştiği için eski sonuçları geçersiz kılabiliriz veya tutabiliriz.
    # Genelde parametre değişince yeniden hesaplama gerekir, bu yüzden sonucu temizleyebiliriz 
    # veya kullanıcı hesapla diyene kadar eskiyi gösterebiliriz.
    # Temizlemek daha güvenli:
    db_scenario.result_data = {} # type: ignore

    db.commit()
    db.refresh(db_scenario)

    # pin_ids formatı
    if isinstance(db_scenario.pin_ids, str):
        try:
            db_scenario.pin_ids = json.loads(db_scenario.pin_ids) # type: ignore
        except:
            db_scenario.pin_ids = [] # type: ignore
    else:
        db_scenario.pin_ids = list(db_scenario.pin_ids or []) # type: ignore

    return db_scenario


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
    
    if start_date is None or end_date is None:
        raise HTTPException(status_code=400, detail="Senaryo tarih aralığı eksik")
    
    # Robust Date Parsing
    def parse_dt(d):
        if isinstance(d, datetime):
            return d
        if isinstance(d, str):
            try:
                # Try IS0 8601 first
                return datetime.fromisoformat(d.replace('Z', '+00:00'))
            except ValueError:
                # Try simple date format
                try:
                    return datetime.strptime(d[:10], "%Y-%m-%d")
                except:
                    pass
        return None

    start_date_obj = parse_dt(start_date)
    end_date_obj = parse_dt(end_date)
    
    if not start_date_obj or not end_date_obj:
        raise HTTPException(status_code=400, detail="Geçersiz tarih formatı")
    
    start_date = start_date_obj
    end_date = end_date_obj
    
    print(f"Senaryo Hesaplanıyor: {start_date} - {end_date}")
    
    # Her pin için hesaplama yap
    pin_results = []
    total_solar_kwh = 0.0
    total_wind_kwh = 0.0
    solar_count = 0
    wind_count = 0
    
    # On-Demand Service Import
    from backend.services.collectors.on_demand import fetch_point_climate_data

    try:
        for pin_id in pin_ids:
            db_pin = db.query(models.Pin).filter(models.Pin.id == pin_id).first()
            if not db_pin: # type: ignore
                continue
                
            pin_type = str(db_pin.type or "Güneş Paneli").strip() # type: ignore
            pin_lat = float(db_pin.latitude) # type: ignore
            pin_lon = float(db_pin.longitude) # type: ignore
            pin_title = str(db_pin.title or "Pin") # type: ignore
            
            prediction_result: Dict[str, Any] = {"pin_id": pin_id, "pin_name": pin_title, "type": pin_type}
            
            # --- Common Data Fetching (Efficient) ---
            # Fetch climate data once for both Solar and Wind using the robust On-Demand service
            # This avoids the complex and error-prone invalid DB queries for 'WeatherData'
            # and fulfills the "No ML" requirement by using physical math on real data.
            climate_data = fetch_point_climate_data(pin_lat, pin_lon, years=1)
            
            if "error" in climate_data:
                prediction_result["error"] = f"Hava verisi alınamadı: {climate_data['error']}"
                pin_results.append(prediction_result)
                continue

            annual_summary = climate_data.get("annual_summary", {})

            if "Güneş" in pin_type or "Solar" in pin_type or pin_type == "Güneş Paneli":
                try:
                    # Basit Fiziksel Hesap (NO ML)
                    # E = H * A * eff * PR
                    annual_solar_kwh_m2 = annual_summary.get("total_solar_kwh_m2", 1600.0)
                    
                    # Varsayılanlar
                    panel_area = float(db_pin.panel_area or 10.0) # type: ignore
                    efficiency = 0.20
                    PR = 0.80
                    
                    annual_production = annual_solar_kwh_m2 * panel_area * efficiency * PR
                    
                    # Sonuçları formatla
                    prediction_result.update({
                        "total_prediction_value": round(annual_production, 2),
                        "daily_avg_production": round(annual_production / 365, 2),
                        "info": "Yıllık fiziksel simülasyon (ML Kullanılmadı)"
                    })
                    
                    # Aylık dağılım (Grafik için)
                    monthly_data = climate_data.get("monthly_data", [])
                    history = []
                    today = datetime.now()
                    for m in monthly_data:
                         # Basit bir tarih oluştur (Geçmiş 1 yıl gibi göster)
                         # 2024-01-15 gibi
                         m_num = m['month']
                         y_val = today.year - 1 if m_num > today.month else today.year
                         d_str = f"{y_val}-{m_num:02d}-15"
                         
                         m_prod = m['total_solar_kwh_m2'] * panel_area * efficiency * PR
                         history.append({
                             "ds": d_str,
                             "y": round(m_prod, 2)
                         })
                    
                    prediction_result["history"] = history
                    prediction_result["future"] = [] # ML yok, gelecek tahmini boş

                    total_solar_kwh += annual_production
                    solar_count += 1
                        
                except Exception as e:
                    print(f"Error calculating solar for pin {pin_id}: {e}")
                    prediction_result["error"] = f"Solar hesaplama hatası: {str(e)}"
                
            elif "Rüzgar" in pin_type or "Wind" in pin_type or pin_type == "Rüzgar Türbini":
                try:
                    # Wind Service Reuse (Logic only)
                    avg_speed = annual_summary.get("avg_wind", 6.0)
                    
                    weather_stats_adapter = {
                        "annual_avg": {"wind": avg_speed}
                    }
                    
                    wind_calc = wind_calculations.calculate_wind_power_production(pin_lat, pin_lon, weather_stats_adapter)
                    annual_prod = wind_calc["predicted_annual_production_kwh"]
                    
                    prediction_result.update({
                        "total_prediction_value": round(annual_prod, 2),
                        "daily_avg_production": round(annual_prod / 365, 2),
                        "info": "Rüzgar fiziksel hesaplama"
                    })
                    
                    # Aylık Dağılım (Simüle veya Gerçek Rüzgar Verisinden)
                    monthly_data = climate_data.get("monthly_data", [])
                    history = []
                    today = datetime.now()
                    
                    # Rüzgar hızı küpü ile orantılı dağıt
                    total_speed_cubed = sum([m['avg_wind']**3 for m in monthly_data]) if monthly_data else 1
                    
                    for m in monthly_data:
                         m_num = m['month']
                         y_val = today.year - 1 if m_num > today.month else today.year
                         d_str = f"{y_val}-{m_num:02d}-15"
                         
                         share = (m['avg_wind']**3) / total_speed_cubed if total_speed_cubed > 0 else 1/12
                         m_prod = annual_prod * share
                         
                         history.append({
                             "ds": d_str,
                             "y": round(m_prod, 2)
                         })
                         
                    prediction_result["history"] = history
                    prediction_result["future"] = []

                    total_wind_kwh += annual_prod
                    wind_count += 1
                    
                except Exception as e:
                     print(f"Error calculating wind for pin {pin_id}: {e}")
                     prediction_result["error"] = f"Rüzgar hesaplama hatası: {str(e)}"
            
            pin_results.append(prediction_result)
            
    except Exception as e:
        print(f"Global calculation error: {e}")
        pass

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

@router.post("/{scenario_id}/pins", response_model=schemas.ScenarioResponse)
def add_pins_to_scenario(
    scenario_id: int,
    pin_ids: List[int],
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Mevcut bir senaryoya pin(ler) ekler.
    """
    db_scenario = db.query(models.Scenario).filter(
        models.Scenario.id == scenario_id,
        models.Scenario.owner_id == current_user.id
    ).first()

    if not db_scenario:
        raise HTTPException(status_code=404, detail="Senaryo bulunamadı")

    # Pin sahipliği kontrolü
    for pin_id in pin_ids:
        db_pin = db.query(models.Pin).filter(models.Pin.id == pin_id).first()
        if not db_pin:
            raise HTTPException(status_code=404, detail=f"Pin {pin_id} bulunamadı")
        if db_pin.owner_id != current_user.id:
            raise HTTPException(status_code=403, detail=f"Pin {pin_id}'e erişim yetkiniz yok")

    # Mevcut pinleri al
    current_pins = db_scenario.pin_ids or []
    if isinstance(current_pins, str):
        try:
            current_pins = json.loads(current_pins)
        except:
            current_pins = []
    else:
        current_pins = list(current_pins) # Ensure list

    # Yeni pinleri ekle (duplicate kontrolü opsiyonel, set ile yapılabilir ama sıra önemli olabilir)
    # Şimdilik direkt ekleyelim, duplicate varsa da sorun olmaz ama temizlik için set kullanabiliriz
    
    # Int dönüşümü ve merge
    current_pin_ids = [int(p) for p in current_pins]
    new_pin_ids = [int(p) for p in pin_ids]
    
    # Sadece listede olmayanları ekle
    for pid in new_pin_ids:
        if pid not in current_pin_ids:
            current_pin_ids.append(pid)

    db_scenario.pin_ids = current_pin_ids
    db.commit()
    db.refresh(db_scenario)

    # Return formatting
    if isinstance(db_scenario.pin_ids, str):
        try:
            db_scenario.pin_ids = json.loads(db_scenario.pin_ids)
        except:
            db_scenario.pin_ids = []
    else:
        db_scenario.pin_ids = list(db_scenario.pin_ids or [])

    return db_scenario
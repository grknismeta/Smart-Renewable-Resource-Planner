from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, cast, Any, Dict
from datetime import datetime, timedelta
import json

from app import auth
from app.crud import crud
from app.core.logger import logger
from app.db import models
from app.schemas import schemas
# Services moved
from app.services import solar_service as solar_calculations, wind_service as wind_calculations
from app.db.database import get_db
# ML modülünü import ediyoruz
# from ..ml_predictor import predict_future_production 

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
        result_data={},  # Boş başlar, calculate ile doldurulur
        battery_capacity_kwh=scenario.battery_capacity_kwh,
        battery_efficiency_pct=scenario.battery_efficiency_pct,
        battery_cost_usd_per_kwh=scenario.battery_cost_usd_per_kwh,
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
        logger.warning(
            "Senaryo {} PUT → 404: senaryo yok ya da owner uyumsuz (owner={})",
            scenario_id, current_user.id,
        )
        raise HTTPException(status_code=404, detail="Senaryo bulunamadı")

    # Pin sahipliği kontrolü
    for pin_id in scenario.pin_ids:
        db_pin = db.query(models.Pin).filter(models.Pin.id == pin_id).first()
        if not db_pin:
             logger.warning(
                 "Senaryo {} PUT → 404: Pin {} DB'de yok "
                 "(muhtemelen silinmiş dangling referans; payload pin_ids={})",
                 scenario_id, pin_id, scenario.pin_ids,
             )
             raise HTTPException(
                 status_code=404,
                 detail=(
                     f"Pin {pin_id} artık mevcut değil (silinmiş olabilir). "
                     "Senaryoyu düzenlerken bu pini seçimden çıkarın."
                 ),
             )
        if db_pin.owner_id != current_user.id:
             logger.warning(
                 "Senaryo {} PUT → 403: Pin {} owner={} ama current_user={}",
                 scenario_id, pin_id, db_pin.owner_id, current_user.id,
             )
             raise HTTPException(status_code=403, detail=f"Pin {pin_id}'e erişim yetkiniz yok")

    db_scenario.name = scenario.name # type: ignore
    db_scenario.description = scenario.description # type: ignore
    db_scenario.pin_ids = scenario.pin_ids # type: ignore
    # Geriye dönük uyumluluk
    db_scenario.pin_id = scenario.pin_ids[0] if scenario.pin_ids else None # type: ignore
    db_scenario.start_date = scenario.start_date # type: ignore
    db_scenario.end_date = scenario.end_date # type: ignore
    db_scenario.battery_capacity_kwh = scenario.battery_capacity_kwh # type: ignore
    db_scenario.battery_efficiency_pct = scenario.battery_efficiency_pct # type: ignore
    db_scenario.battery_cost_usd_per_kwh = scenario.battery_cost_usd_per_kwh # type: ignore

    # Parametreler değiştiği için eski sonuçları geçersiz kıl
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


def _monthly_distribution(pin, resource_type: str) -> List[float]:
    """Pin'in yıllık üretimini 12 aya dağıtmak için oransal profil döner.

    2026-05-25 (P1/4): Senaryo aylık breakdown için.
    - **GES (solar):** monthly_sunshine_hours profili — daha güneşli ay = daha
      yüksek pay.
    - **HES (hydro):** monthly_river_discharge.mean profili — debinin yüksek
      olduğu ay = daha yüksek pay.
    - **RES (wind):** monthly wind speed verisi yok (climatology'de eksik) →
      düz dağılım (her ay 1/12).

    Dönen list 12 eleman, toplamı 1.0. Profil bulunamazsa düz dağılım.
    """
    from app.db.database import SystemSessionLocal
    from app.services.province_aliases import province_aliases

    flat = [1.0 / 12] * 12
    city = getattr(pin, "city", None)
    if not city:
        return flat
    try:
        with SystemSessionLocal() as sdb:
            variants = province_aliases(str(city))
            # Climatology row'unu çek (resource_type filtre yok — monthly veriler
            # tüm satırlarda aynı olabilir, ilk uygun olanı al)
            rows = (
                sdb.query(models.Climatology)
                .filter(
                    models.Climatology.province_name.in_(variants),
                    models.Climatology.district_name.is_(None),
                )
                .all()
            )
            if not rows:
                return flat

            if resource_type == "solar":
                # monthly_sunshine_hours: [h_jan, ..., h_dec]
                for r in rows:
                    sh = getattr(r, "monthly_sunshine_hours", None)
                    if isinstance(sh, list) and len(sh) == 12:
                        total = sum(sh)
                        if total > 0:
                            return [float(x) / total for x in sh]
            elif resource_type == "hydro":
                # monthly_river_discharge: [{"mean": .., "min": .., "max": ..}, ...]
                for r in rows:
                    md = getattr(r, "monthly_river_discharge", None)
                    if isinstance(md, list) and len(md) == 12:
                        means = []
                        for m in md:
                            if isinstance(m, dict):
                                v = m.get("mean", 0)
                                means.append(float(v) if v else 0.0)
                            else:
                                means.append(0.0)
                        total = sum(means)
                        if total > 0:
                            return [m / total for m in means]
            # RES için profil yok → düz dağılım
    except Exception as e:
        logger.debug("monthly_distribution okunamadı ({}): {}", city, e)
    return flat


def _climatology_capacity_factor(pin, resource_type: str) -> float:
    """Pin'in ilinin climatology capacity_factor'ünü döner (0-1).

    Senaryo yıllık üretimi: capacity_mw × 1000 × CF × 8760.
    CF 10-yıl ortalamadan statik hesaplanır — saatlik veri kapsamından
    bağımsız, tutarlı. Climatology'de kayıt yoksa sektör fallback'i.
    """
    from app.db.database import SystemSessionLocal
    from app.services.province_aliases import province_aliases

    fallback = {"solar": 0.16, "wind": 0.30, "hydro": 0.45}
    city = getattr(pin, "city", None)
    if not city:
        return fallback.get(resource_type, 0.20)
    try:
        with SystemSessionLocal() as sdb:
            variants = province_aliases(str(city))
            row = (
                sdb.query(models.Climatology)
                .filter(
                    models.Climatology.province_name.in_(variants),
                    models.Climatology.resource_type == resource_type,
                    models.Climatology.district_name.is_(None),
                )
                .first()
            )
            if row and row.capacity_factor:
                return float(row.capacity_factor)
    except Exception as e:
        logger.debug("climatology CF okunamadı ({}): {}", city, e)
    return fallback.get(resource_type, 0.20)


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
        logger.warning(
            "Senaryo {} /calculate → 400: pin listesi boş (owner={})",
            scenario_id, current_user.id,
        )
        raise HTTPException(
            status_code=400,
            detail="Bu senaryoda hesaplanacak pin yok. Lütfen senaryoya en az bir pin ekleyin.",
        )

    start_date = db_scenario.start_date # type: ignore
    end_date = db_scenario.end_date # type: ignore

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

    # 2026-05-26 (N1): start_date hâlâ zorunlu (geçmişten başlamalı), ama
    # end_date null ise "süresiz" sayılır → bugüne kadar üret. Kullanıcı
    # "şu ana kadar" demek için end_date'i boş bırakabilir. Yeni veri
    # geldikçe senaryo otomatik genişler (recalculate ettiğinde).
    if start_date_obj is None:
        logger.warning(
            "Senaryo {} /calculate → 400: start_date eksik/geçersiz "
            "(start={!r})",
            scenario_id, start_date,
        )
        raise HTTPException(
            status_code=400,
            detail=(
                "Senaryonun Başlangıç tarihi eksik veya geçersiz. "
                "Senaryoyu düzenleyip Başlangıç tarihini seçin."
            ),
        )
    if end_date_obj is None:
        # Süresiz senaryo — bugüne kadar üretmeye devam ediyor.
        end_date_obj = datetime.utcnow()
        logger.info(
            "Senaryo {} süresiz: end_date null → bugün ({}) kullanılıyor",
            scenario_id, end_date_obj.date(),
        )

    start_date = start_date_obj
    end_date = end_date_obj
    
    logger.info("Senaryo hesaplanıyor: {} - {}", start_date, end_date)
    
    # Her pin için hesaplama yap
    pin_results = []
    total_solar_kwh = 0.0
    total_wind_kwh = 0.0
    total_hydro_kwh = 0.0
    solar_count = 0
    wind_count = 0
    hydro_count = 0
    # 2026-05-25 (P1/4): Aylık breakdown — pin başına climatology profilinden
    # oran çekip yıllık üretimi 12 aya dağıt, toplam aylık dizini güncelle.
    monthly_total_kwh = [0.0] * 12
    monthly_solar_kwh = [0.0] * 12
    monthly_wind_kwh = [0.0] * 12
    monthly_hydro_kwh = [0.0] * 12
    
    # DB-tabanlı hesaplama — 2026-05-21 refactor.
    # Eski yöntem her pin için canlı Open-Meteo çağrısı (`fetch_point_climate_data`)
    # yapıyordu → API kotası dolunca senaryo hesaplaması çöküyordu. Yeni yöntem:
    #   - GES/RES: `compute_pin_generation` (climatology + hourly_weather_data, DB)
    #   - HES: calculate_annual_hydro_production (debi/düşü fiziksel hesabı, DB-based)
    # Artık kota bağımsız + pin_generation_service ile tutarlı.
    #
    # 2026-05-27 (Q1 bug fix): Eski kod `HydroService` class import etmeye
    # çalışıyordu, ama hydro_service.py modüle-level fonksiyonlar içeriyor
    # (class yok) → ImportError → 500 → senaryo "henüz hesaplanmamış" kalıyordu.
    from app.services.hydro_service import calculate_annual_hydro_production

    for pin_id in pin_ids:
        db_pin = db.query(models.Pin).filter(models.Pin.id == pin_id).first()
        if not db_pin:  # type: ignore
            continue

        pin_type = str(db_pin.type or "Güneş Paneli").strip()  # type: ignore
        pin_name = str(
            getattr(db_pin, "name", None)
            or getattr(db_pin, "title", None)
            or f"Pin {pin_id}"
        )
        prediction_result: Dict[str, Any] = {
            "pin_id": pin_id, "pin_name": pin_name, "type": pin_type,
        }

        is_hydro = (
            "Hidro" in pin_type or "Hydro" in pin_type or "HES" in pin_type
        )

        if is_hydro:
            # HES — debi/düşü fiziksel hesabı (DB-based, kota bağımsız)
            try:
                flow_rate = float(db_pin.flow_rate) if db_pin.flow_rate else None  # type: ignore
                head_height = float(db_pin.head_height) if db_pin.head_height else None  # type: ignore
                basin_area_km2 = float(db_pin.basin_area_km2) if db_pin.basin_area_km2 else None  # type: ignore

                if flow_rate is None and basin_area_km2 is None:
                    prediction_result["error"] = "HES için debi veya havza alanı gerekli"
                    pin_results.append(prediction_result)
                    continue

                # Q1 (2026-05-27): head_height zorunlu (fonksiyon imzası).
                # Yoksa Türkiye HES ortalaması ~50m default — kullanıcı pin
                # formunda eksik bıraktıysa çökmek yerine makul tahmin yap.
                hydro_results = calculate_annual_hydro_production(
                    latitude=float(db_pin.latitude),  # type: ignore
                    longitude=float(db_pin.longitude),  # type: ignore
                    head_height=head_height if head_height is not None else 50.0,
                    flow_rate=flow_rate,
                    basin_area_km2=basin_area_km2,
                )
                annual_prod = hydro_results.get("predicted_annual_production_kwh", 0.0)
                # 2026-05-25 (P1/4): Aylık dağılım — climatology
                # monthly_river_discharge profilinden oranlama.
                profile = _monthly_distribution(db_pin, "hydro")
                pin_monthly = [round(annual_prod * p, 2) for p in profile]
                prediction_result.update({
                    "total_prediction_value": round(annual_prod, 2),
                    "daily_avg_production": round(annual_prod / 365, 2),
                    "monthly_kwh": pin_monthly,
                    "info": f"HES fiziksel hesaplama ({hydro_results.get('turbine_type', '')})",
                    "history": [],
                    "future": [],
                })
                for i, v in enumerate(pin_monthly):
                    monthly_total_kwh[i] += v
                    monthly_hydro_kwh[i] += v
                total_hydro_kwh += annual_prod
                hydro_count += 1
            except Exception as e:
                logger.warning("HES hesaplama hatası (pin {}): {}", pin_id, e)
                prediction_result["error"] = f"HES hesaplama hatası: {str(e)}"
        else:
            # GES + RES — climatology capacity_factor bazlı yıllık üretim.
            # annual_kwh = capacity_mw × 1000 × CF × 8760
            # CF 10-yıl ortalamadan statik; saatlik veri kapsamından bağımsız,
            # tutarlı (compute_pin_generation eksik-veri illerde düşük çıkıyordu).
            try:
                is_solar = "Güneş" in pin_type or "Solar" in pin_type
                resource = "solar" if is_solar else "wind"
                cf = _climatology_capacity_factor(db_pin, resource)
                cap_mw = float(db_pin.capacity_mw or 1.0)  # type: ignore
                annual_prod = cap_mw * 1000.0 * cf * 8760.0
                # 2026-05-25 (P1/4): GES için monthly_sunshine_hours profili,
                # RES için düz dağılım (climatology'de aylık wind yok).
                profile = _monthly_distribution(db_pin, resource)
                pin_monthly = [round(annual_prod * p, 2) for p in profile]
                prediction_result.update({
                    "total_prediction_value": round(annual_prod, 2),
                    "daily_avg_production": round(annual_prod / 365, 2),
                    "capacity_factor": round(cf, 3),
                    "monthly_kwh": pin_monthly,
                    "info": f"Climatology CF bazlı (KF %{cf * 100:.1f})",
                    "history": [],
                    "future": [],
                })
                for i, v in enumerate(pin_monthly):
                    monthly_total_kwh[i] += v
                    if is_solar:
                        monthly_solar_kwh[i] += v
                    else:
                        monthly_wind_kwh[i] += v
                if is_solar:
                    total_solar_kwh += annual_prod
                    solar_count += 1
                else:
                    total_wind_kwh += annual_prod
                    wind_count += 1
            except Exception as e:
                logger.warning("Pin {} üretim hesabı hatası: {}", pin_id, e)
                prediction_result["error"] = f"Hesaplama hatası: {str(e)}"

        pin_results.append(prediction_result)

    # Toplu sonuçları kaydet
    # 2026-05-25 (P1/4): monthly_breakdown — yıllık üretim 12 aya dağıtılmış
    # halde. Climatology profilinden alındı (solar → sunshine, hydro →
    # discharge, wind → düz). Frontend bar chart için kullanılır.
    monthly_breakdown = [
        {
            "month": i + 1,
            "total_kwh": round(monthly_total_kwh[i], 2),
            "solar_kwh": round(monthly_solar_kwh[i], 2),
            "wind_kwh": round(monthly_wind_kwh[i], 2),
            "hydro_kwh": round(monthly_hydro_kwh[i], 2),
        }
        for i in range(12)
    ]
    summary = {
        "total_solar_kwh": total_solar_kwh,
        "total_wind_kwh": total_wind_kwh,
        "total_hydro_kwh": total_hydro_kwh,
        "total_kwh": total_solar_kwh + total_wind_kwh + total_hydro_kwh,
        "solar_count": solar_count,
        "wind_count": wind_count,
        "hydro_count": hydro_count,
        "monthly_breakdown": monthly_breakdown,
        "pin_results": pin_results,
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


# ─── 3.A — Finansal Projeksiyon ─────────────────────────────────────────────

@router.get("/{scenario_id}/financials")
def get_scenario_financials(
    scenario_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_active_user),
):
    """Senaryonun finansal metriklerini hesaplar (Aşama 3.A).

    Yanıt: ``FinancialMetrics`` (CAPEX, OPEX, LCOE, payback, NPV, IRR,
    yıllık üretim, CO₂ avoidance, 25 yıllık nakit akışı).

    Pin'ler senaryonun ``pin_ids`` listesinden okunur; her pin için
    ``capacity_mw`` zorunlu, ``capacity_factor`` opsiyonel
    (yoksa sektör fallback değeri kullanılır).

    Varsayımlar `app/core/finance_constants.py` default'larından gelir;
    Settings → varsayım override (3.A.6) ileride DB'ye taşınabilir.
    """
    from app.services.finance_service import (
        compute_scenario_financials,
        PinFinanceInput,
    )

    db_scenario = (
        db.query(models.Scenario)
        .filter(models.Scenario.id == scenario_id)
        .first()
    )
    if not db_scenario:
        raise HTTPException(status_code=404, detail="Senaryo bulunamadı")
    if db_scenario.owner_id != current_user.id:  # type: ignore
        raise HTTPException(status_code=403, detail="Yetkiniz yok")

    # pin_ids JSON veya list olabilir; normalize et
    raw_pin_ids = db_scenario.pin_ids
    if isinstance(raw_pin_ids, str):
        try:
            raw_pin_ids = json.loads(raw_pin_ids)
        except Exception:
            raw_pin_ids = []
    pin_ids: list[int] = list(raw_pin_ids or [])

    # Pin'leri çek + capacity_factor için latest PinCalculationResult
    pin_inputs: list[PinFinanceInput] = []
    for pid in pin_ids:
        db_pin = db.query(models.Pin).filter(models.Pin.id == pid).first()
        if not db_pin:
            logger.warning(
                "Senaryo {} financials: pin {} DB'de yok (dangling) — atlanıyor",
                scenario_id, pid,
            )
            continue

        # capacity_factor: PinCalculationResult'tan latest (varsa)
        cf: float | None = None
        try:
            from app.db.database import UserPinsSessionLocal
            with UserPinsSessionLocal() as up_db:
                latest_calc = (
                    up_db.query(models.PinCalculationResult)
                    .filter(models.PinCalculationResult.pin_id == pid)
                    .order_by(models.PinCalculationResult.created_at.desc())
                    .first()
                )
                if latest_calc and latest_calc.capacity_factor:  # type: ignore
                    cf = float(latest_calc.capacity_factor)  # type: ignore
        except Exception as e:
            logger.debug("Pin {} capacity_factor okunamadı: {}", pid, e)

        pin_inputs.append(PinFinanceInput(
            pin_id=int(db_pin.id),  # type: ignore
            pin_type=str(db_pin.type),  # type: ignore
            capacity_mw=float(db_pin.capacity_mw or 1.0),  # type: ignore
            capacity_factor=cf,
        ))

    metrics = compute_scenario_financials(pin_inputs)

    # FinancialMetrics dataclass → dict
    return {
        "scenario_id": scenario_id,
        "scenario_name": db_scenario.name,
        "capex_total": metrics.capex_total,
        "opex_yearly": metrics.opex_yearly,
        "annual_revenue": metrics.annual_revenue,
        "annual_production_kwh": metrics.annual_production_kwh,
        "annual_co2_avoided_tons": metrics.annual_co2_avoided_tons,
        "lcoe_usd_per_kwh": metrics.lcoe_usd_per_kwh,
        "payback_period_years": metrics.payback_period_years,
        "npv_usd": metrics.npv_usd,
        "irr_pct": metrics.irr_pct,
        "project_lifetime_years": metrics.project_lifetime_years,
        "yearly_cashflows": metrics.yearly_cashflows,
        "cumulative_cashflows": metrics.cumulative_cashflows,
        "per_pin": metrics.per_pin,
        "assumptions_used": metrics.assumptions_used,
    }
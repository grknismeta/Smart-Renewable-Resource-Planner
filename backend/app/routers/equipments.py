from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import time

from app import auth
from app.crud import crud
from app.schemas import schemas
from app.db import models
from app.db.database import get_system_db

router = APIRouter()

# Basit bellek-içi cache (ekipman listesi nadiren değişir)
_eq_cache: dict[str, tuple[float, list]] = {}
_EQ_CACHE_TTL = 300  # 5 dakika

@router.get("/", response_model=List[schemas.EquipmentResponse])
def read_equipments(
    type: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Sistemde kayıtlı rüzgar türbini ve güneş paneli modellerini listeler.
    Opsiyonel olarak 'type' (Solar/Wind) ile filtreleme yapılabilir.
    """
    cache_key = f"{type}:{skip}:{limit}"
    now = time.time()
    if cache_key in _eq_cache:
        ts, data = _eq_cache[cache_key]
        if now - ts < _EQ_CACHE_TTL:
            return data

    equipments = crud.get_equipments(db, type=type, skip=skip, limit=limit)
    _eq_cache[cache_key] = (now, equipments)
    return equipments

@router.get("/{equipment_id}", response_model=schemas.EquipmentResponse)
def read_equipment(
    equipment_id: int,
    db: Session = Depends(get_system_db), # DÜZELTME YAPILDI
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Tek bir ekipmanın detaylarını getirir.
    """
    equipment = crud.get_equipment(db, equipment_id=equipment_id)
    if equipment is None:
        raise HTTPException(status_code=404, detail="Ekipman bulunamadı")
    return equipment
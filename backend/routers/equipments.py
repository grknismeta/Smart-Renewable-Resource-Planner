from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from .. import crud, models, schemas, auth
from ..database import get_system_db # DÜZELTME: get_db yerine get_system_db

router = APIRouter()

@router.get("/", response_model=List[schemas.EquipmentResponse])
def read_equipments(
    type: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_system_db), # DÜZELTME YAPILDI
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Sistemde kayıtlı rüzgar türbini ve güneş paneli modellerini listeler.
    Opsiyonel olarak 'type' (Solar/Wind) ile filtreleme yapılabilir.
    """
    print(f'[Equipments Router] GET /equipments/ - type={type}, user_id={current_user.id}')
    equipments = crud.get_equipments(db, type=type, skip=skip, limit=limit)
    print(f'[Equipments Router] {len(equipments)} ekipman döndürülüyor')
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
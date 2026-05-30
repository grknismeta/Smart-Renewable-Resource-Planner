from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app import auth
from app.crud import crud
from app.schemas import schemas
from app.db import models
from app.db.database import get_system_db

router = APIRouter()

# 2026-05-17 Sprint A — cache devre dışı bırakıldı (user-aware filtering
# nedeniyle her kullanıcının listesi farklı; kullanıcı yeni ekipman
# eklediğinde anında görünmeli).

@router.get("/", response_model=List[schemas.EquipmentResponse])
def read_equipments(
    type: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Ekipman listesi: sistem ekipmanları + kullanıcının kendi eklediği'ler.
    Opsiyonel 'type' filtresi (Solar/Wind/Hydro).
    """
    return crud.get_equipments(
        db, type=type, skip=skip, limit=limit,
        user_id=current_user.id,
    )

@router.post("/", response_model=schemas.EquipmentResponse,
             status_code=status.HTTP_201_CREATED)
def create_equipment(
    equipment: schemas.EquipmentCreate,
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Kullanıcının kendi ekipmanını kaydeder (Panel/Türbin tipi).
    owner_id = current_user.id ile insert edilir; sadece bu kullanıcı görür.
    2026-05-17 Sprint A — 'Gelişmiş Ayarlar > Tipi Kaydet' butonu için.
    """
    return crud.create_user_equipment(db, equipment, current_user.id)

@router.get("/{equipment_id}", response_model=schemas.EquipmentResponse)
def read_equipment(
    equipment_id: int,
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Tek ekipman detayı. Sistem ekipmanı veya kullanıcının kendi'si olabilir;
    başka kullanıcının ekipmanına erişim engellenir.
    """
    equipment = crud.get_equipment(db, equipment_id=equipment_id)
    if equipment is None:
        raise HTTPException(status_code=404, detail="Ekipman bulunamadı")
    # Başka kullanıcının ekipmanı (owner_id dolu ve user'a ait değil) → 404
    if equipment.owner_id is not None and equipment.owner_id != current_user.id:
        raise HTTPException(status_code=404, detail="Ekipman bulunamadı")
    return equipment

@router.put("/{equipment_id}", response_model=schemas.EquipmentResponse)
def update_equipment(
    equipment_id: int,
    equipment: schemas.EquipmentCreate,
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Kullanıcının kendi ekipmanını günceller (name, rated_power_kw, specs vs.).
    Sistem ekipmanları (owner_id NULL) güncellenemez → 404.
    2026-05-17 — 'Kullanıcının eklediği santral tipleri düzenlenebilir' isteği.
    """
    updated = crud.update_user_equipment(db, equipment_id, equipment, current_user.id)
    if not updated:
        raise HTTPException(
            status_code=404,
            detail="Ekipman bulunamadı veya düzenleme yetkiniz yok",
        )
    return updated

@router.delete("/{equipment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_equipment(
    equipment_id: int,
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Kullanıcının kendi ekipmanını siler. Sistem ekipmanları silinemez (404).
    """
    ok = crud.delete_user_equipment(db, equipment_id, current_user.id)
    if not ok:
        raise HTTPException(
            status_code=404,
            detail="Ekipman bulunamadı veya silme yetkiniz yok",
        )
    return None
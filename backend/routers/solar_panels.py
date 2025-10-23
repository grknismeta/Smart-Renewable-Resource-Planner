# routers/solar_panels.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from .. import crud, schemas, auth, models, solar_calculations
from ..database import SessionLocal
from ..database import get_db

router = APIRouter(
    prefix="/solar-panels",
    tags=["Solar Panel Models"]
)

# Dependency (get_db)

@router.post("/", response_model=schemas.SolarPanelResponse, status_code=status.HTTP_201_CREATED)
def create_solar_panel(
    panel: schemas.SolarPanelCreate, 
    db: Session = Depends(get_db)
):
    """
    Veritabanına yeni bir güneş paneli modeli ekler.
    """
    # Standart panel verisini eklemek için örnek:
    if not crud.get_default_solar_panel(db):
        from .. import solar_calculations
        default_panel_data = schemas.SolarPanelCreate(
            **solar_calculations.EXAMPLE_PANEL_SPECS
        )
        crud.create_solar_panel(db=db, panel=default_panel_data)
        
    return crud.create_solar_panel(db=db, panel=panel)

@router.get("/", response_model=List[schemas.SolarPanelResponse])
def get_all_solar_panels(db: Session = Depends(get_db)):
    """
    Sistemde kayıtlı tüm güneş paneli modellerini listeler.
    """
    return crud.get_solar_panels(db)

@router.get("/{panel_id}", response_model=schemas.SolarPanelResponse)
def get_solar_panel(panel_id: int, db: Session = Depends(get_db)):
    """
    Belirli bir güneş paneli modelini getirir.
    """
    panel = crud.get_solar_panel_by_id(db, panel_id=panel_id)
    if not panel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Panel modeli bulunamadı."
        )
    return panel
# routers/turbines.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from .. import crud, schemas, auth, models
from ..database import SessionLocal
from ..database import get_db

router = APIRouter(
    prefix="/turbines",
    tags=["Turbine Models"]
)

# Dependency (get_db)

@router.post("/", response_model=schemas.TurbineResponse, status_code=status.HTTP_201_CREATED)
def create_turbine(
    turbine: schemas.TurbineCreate, 
    db: Session = Depends(get_db)
    # TODO: Bu endpoint'i sadece adminlerin kullanabilmesi için koruma eklenebilir.
    # current_user: models.User = Depends(auth.get_current_active_user)
):
    """
    Veritabanına yeni bir rüzgar türbini modeli ekler.
    (Flutter'daki 'özellik girme' widget'ının verilerini burası kaydeder)
    """
    # Standart (default) türbin verisini eklemek için örnek bir kullanım:
    # if not crud.get_default_turbine(db):
    #     from .. import wind_calculations
    #     default_turbine_data = schemas.TurbineCreate(
    #         model_name="Standart 2MW Türbin",
    #         rated_power_kw=2000,
    #         is_default=True,
    #         power_curve_data=wind_calculations.EXAMPLE_TURBINE_POWER_CURVE
    #     )
    #     crud.create_turbine(db=db, turbine=default_turbine_data)
        
    return crud.create_turbine(db=db, turbine=turbine)

@router.get("/", response_model=List[schemas.TurbineResponse])
def get_all_turbines(db: Session = Depends(get_db)):
    """
    Sistemde kayıtlı tüm rüzgar türbini modellerini listeler.
    (Flutter'daki 'Türbin Seçimi' widget'ı bu listeyi kullanabilir)
    """
    return crud.get_turbines(db)

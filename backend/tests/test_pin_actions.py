import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db import models
from app.crud import crud
from app.schemas import schemas
from datetime import datetime

# Use an in-memory SQLite database for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="function")
def db_session():
    """Create a fresh database for each test."""
    models.UserBase.metadata.create_all(bind=engine)
    models.UserPinsBase.metadata.create_all(bind=engine)
    models.SystemBase.metadata.create_all(bind=engine)
    
    session = TestingSessionLocal()
    yield session
    session.close()
    models.UserBase.metadata.drop_all(bind=engine)

def test_pin_properties_persistence(db_session):
    """
    Verify that all properties including panel_area are saved correctly.
    """
    user = crud.create_user(db_session, schemas.UserCreate(email="props@test.com", password="pw"))
    
    pin_data = schemas.PinCreate(
        latitude=10.0,
        longitude=20.0,
        title="Solar Farm",
        type="Güneş Paneli",
        capacity_mw=5.0,
        panel_area=125.0, # The field we fixed
        equipment_id=99
    )
    
    pin = crud.create_pin_for_user(db_session, pin_data, user.id)
    
    # 1. Verify returned object
    assert pin.panel_area == 125.0
    assert pin.capacity_mw == 5.0
    
    # 2. Verify DB retrieval
    fetched = crud.get_pin_by_id(db_session, pin.id, user.id)
    assert fetched.panel_area == 125.0
    assert fetched.equipment_id == 99

def test_analysis_persistence(db_session):
    """
    Simulate the analyze flow: result calculation -> save to DB.
    """
    user = crud.create_user(db_session, schemas.UserCreate(email="analys@test.com", password="pw"))
    pin = crud.create_pin_for_user(
        db_session, 
        schemas.PinCreate(latitude=1, longitude=1, title="Test"), 
        user.id
    )
    
    # Mock calculation result (PinCalculationResponse.model_dump())
    result_data = {
        "resource_type": "Güneş Paneli",
        "solar_calculation": {
            "solar_irradiance_kw_m2": 5.5,
            "potential_kwh_annual": 12000.0,
            "monthly_production": {"Ocak": 800, "Temmuz": 1500},
            "financials": {"roi_percentage": 15.0} # etc
        }
    }
    
    # 1. Save Analysis
    analysis = crud.create_or_update_pin_analysis(db_session, pin.id, result_data)
    assert analysis is not None
    assert analysis.pin_id == pin.id
    assert analysis.result_data["resource_type"] == "Güneş Paneli"
    
    # 2. Update Analysis (Re-calculate)
    new_result = result_data.copy()
    new_result["solar_calculation"]["potential_kwh_annual"] = 13000.0
    
    updated = crud.create_or_update_pin_analysis(db_session, pin.id, new_result)
    assert updated.id == analysis.id # Should update same record
    assert updated.result_data["solar_calculation"]["potential_kwh_annual"] == 13000.0
    
    # 3. Verify accessing from Pin side
    db_session.refresh(pin)
    assert pin.analysis is not None
    assert pin.analysis.result_data["solar_calculation"]["monthly_production"]["Ocak"] == 800

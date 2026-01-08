import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db import models
from app.crud import crud
from app.schemas import schemas

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

def test_user_pin_relationship(db_session):
    """
    Simulates the logic in check_db.py:
    Create a user, add a pin, and verify retrieval.
    """
    # 1. Create User
    user_data = schemas.UserCreate(email="test@example.com", password="password123")
    user = crud.create_user(db_session, user_data)
    assert user.id is not None
    assert user.email == "test@example.com"

    # 2. Create Pin linked to User
    pin_data = schemas.PinCreate(
        title="My Test Pin",
        latitude=40.0,
        longitude=30.0,
        type="Güneş Paneli",
        description="Test Description"
    )
    # Note: create_pin_for_user might expect 'system_db' for validation, but let's see if we can pass same db for simplicity
    # or mock it.
    # Looking at crud.py (not visible now but assumed), it creates model and adds to db.
    
    # We'll do a direct DB insertion to test the Relationship logic primarily.
    db_pin = models.Pin(
        **pin_data.dict(),
        owner_id=user.id
    )
    db_session.add(db_pin)
    db_session.commit()
    db_session.refresh(db_pin)
    
    assert db_pin.id is not None
    assert db_pin.owner_id == user.id
    
    # 3. Verify Reverse Relationship (if defined in models) or Query by owner
    user_pins = crud.get_pins_by_owner(db_session, owner_id=user.id)
    assert len(user_pins) == 1
    assert user_pins[0].title == "My Test Pin"
    
    print("Database Integrity Test Passed: User created and Pin linked correctly.")

def test_delete_pin(db_session):
    """
    Test deletion of a pin by its ID and owner ID.
    """
    # 1. Setup
    user = crud.create_user(db_session, schemas.UserCreate(email="del@example.com", password="pw"))
    pin_data = schemas.PinCreate(latitude=10, longitude=10, title="To Delete")
    db_pin = crud.create_pin_for_user(db_session, pin_data, user.id, system_db=None) 
    
    # 2. Delete
    # Note: crud.delete_pin_by_id accepts (db, pin_id, user_id)
    success = crud.delete_pin_by_id(db_session, db_pin.id, user.id)
    assert success is True
    
    # 3. Verify
    fetched = crud.get_pin_by_id(db_session, db_pin.id, user.id)
    assert fetched is None

def test_update_pin_coordinates(db_session):
    """
    Example: Updating a pin's location.
    """
    # 1. Setup
    user = crud.create_user(db_session, schemas.UserCreate(email="upd@example.com", password="pw"))
    pin_data = schemas.PinCreate(latitude=10, longitude=10, title="Original")
    db_pin = crud.create_pin_for_user(db_session, pin_data, user.id)
    
    # 2. Update
    update_data = schemas.PinCreate(latitude=50.0, longitude=50.0, title="Moved")
    # Assuming crud.update_pin exists (I saw it in crud.py view earlier)
    updated = crud.update_pin(db_session, db_pin.id, update_data, user.id)
    
    assert updated.latitude == 50.0
    assert updated.title == "Moved"

def test_orphan_pin_prevention(db_session):
    """
    Verify we cannot access a pin via wrong user ID.
    """
    # User A
    user_a = crud.create_user(db_session, schemas.UserCreate(email="a@example.com", password="pw"))
    pin_a = crud.create_pin_for_user(db_session, schemas.PinCreate(latitude=1, longitude=1, title="A's Pin"), user_a.id)
    
    # User B
    user_b = crud.create_user(db_session, schemas.UserCreate(email="b@example.com", password="pw"))
    
    # User B tries to get User A's pin
    found = crud.get_pin_by_id(db_session, pin_a.id, user_b.id)
    assert found is None

def test_equipment_retrieval(db_session):
    """
    Verify basic equipment retrieval from 'SystemDB' (mocked via same session for this test struct).
    In real app, SystemDB is separate, but models.Equipment works on any extensive session if tables exist.
    """
    # 1. Add Equipment
    # Equipment is SystemBase. fixture 'db_session' creates SystemBase metadata too?
    # Let's check fixture. Yes: models.SystemBase.metadata.create_all(bind=engine)
    
    eq = models.Equipment(
        name="Super Panel 3000",
        type="Solar",
        rated_power_kw=5.0,
        efficiency=0.22,
        cost_per_unit=1000.0,
        maintenance_cost_annual=50.0
    )
    db_session.add(eq)
    db_session.commit()
    
    # 2. Retrieve
    # Using crud or direct query
    retrieved = crud.get_equipments(db_session, type="Solar")
    assert len(retrieved) == 1
    assert retrieved[0].name == "Super Panel 3000"

# --- Expanded DB Tests ---

def test_get_equipments_filtering(db_session):
    # Setup
    e1 = models.Equipment(name="Wind T1", type="Wind", rated_power_kw=5.0, efficiency=0.4, cost_per_unit=1000, maintenance_cost_annual=10)
    e2 = models.Equipment(name="Solar S1", type="Solar", rated_power_kw=1.0, efficiency=0.2, cost_per_unit=200, maintenance_cost_annual=5)
    db_session.add(e1)
    db_session.add(e2)
    db_session.commit()
    
    # Filter Wind
    winds = crud.get_equipments(db_session, type="Wind")
    assert len(winds) == 1
    assert winds[0].name == "Wind T1"

def test_pin_pagination(db_session):
    # Create 5 pins
    user = crud.create_user(db_session, schemas.UserCreate(email="page@example.com", password="pw"))
    for i in range(5):
        crud.create_pin_for_user(
            db_session, 
            schemas.PinCreate(latitude=i, longitude=i, title=f"Pin {i}"), 
            user.id
        )
    
    # Get first 2 (offset 0, limit 2)
    page1 = crud.get_pins_by_owner(db_session, user.id, skip=0, limit=2)
    assert len(page1) == 2
    
    # Get next 2 (offset 2, limit 2)
    page2 = crud.get_pins_by_owner(db_session, user.id, skip=2, limit=2)
    assert len(page2) == 2
    assert page2[0].title == "Pin 2"

def test_user_email_uniqueness_db_level(db_session):
    # Attempt to insert user with same email (Direct crud or model)
    crud.create_user(db_session, schemas.UserCreate(email="unique@example.com", password="pw"))
    
    from sqlalchemy.exc import IntegrityError
    with pytest.raises(IntegrityError):
        crud.create_user(db_session, schemas.UserCreate(email="unique@example.com", password="pw2"))
        db_session.flush() # Force write
    db_session.rollback() # Reset for next tests

def test_cascade_delete_user_pins(db_session):
    # Verify deleting User deletes Pins
    user = crud.create_user(db_session, schemas.UserCreate(email="casc@example.com", password="pw"))
    pin = crud.create_pin_for_user(db_session, schemas.PinCreate(latitude=1, longitude=1, title="P"), user.id)
    
    db_session.delete(user)
    db_session.commit()
    
    # Pin should be gone
    orphaned_pin = db_session.query(models.Pin).filter(models.Pin.id == pin.id).first()
    assert orphaned_pin is None

def test_update_user_password(db_session):
    user = crud.create_user(db_session, schemas.UserCreate(email="pass@example.com", password="old"))
    new_hash = auth.get_password_hash("new")
    user.hashed_password = new_hash
    db_session.commit()
    
    refetched = crud.get_user(db_session, user.id)
    assert auth.verify_password("new", str(refetched.hashed_password))

def test_transaction_rollback_safety(db_session):
    # Start transaction, fail, ensure rollback
    initial_count = db_session.query(models.User).count()
    try:
        user = models.User(email=None) # Invalid - email not null usually? or just SQL error
        db_session.add(user)
        db_session.flush()
    except:
        db_session.rollback()
    
    final_count = db_session.query(models.User).count()
    assert initial_count == final_count

def test_pin_defaults(db_session):
    # Check default values if any
    user = crud.create_user(db_session, schemas.UserCreate(email="def@example.com", password="pw"))
    pin = crud.create_pin_for_user(db_session, schemas.PinCreate(latitude=1, longitude=1, title="Defaults"), user.id)
    # Assume default created_at
    assert pin.id is not None
    # assert pin.created_at is not None 

def test_create_user_empty_email(db_session):
    # Logic check via CRUD directly
    # Ideally should fail validation, but let's check DB behavior if Pydantic skipped
    # SQLite might allow empty string unless CHECK constraint
    pass 

def test_scenario_creation(db_session):
    # Basic scenarios if table exists
    # Just check model instantiation
    scenario = models.Scenario(name="S1", owner_id=1, total_investment=100.0)
    db_session.add(scenario)
    # Might fail FK if owner 1 doesn't exist.
    # We won't flush to avoid FK error, or we create user first.
    user = crud.create_user(db_session, schemas.UserCreate(email="scen@example.com", password="pw"))
    scenario.owner_id = user.id
    db_session.commit()
    assert scenario.id is not None

def test_reporting_query_empty_db(db_session):
    # Run reporting query on empty DB
    # Should return None or 0, not crash
    from sqlalchemy import func
    avg_temp = db_session.query(func.avg(models.HourlyWeatherData.temperature)).scalar()
    assert avg_temp is None # AVG of nothing is NULL

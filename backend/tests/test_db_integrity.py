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

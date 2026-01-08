import pytest
from datetime import datetime, timedelta
from sqlalchemy import create_engine, func
from sqlalchemy.orm import sessionmaker
from app.db import models

# In-memory DB for System Data
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="function")
def system_db():
    models.SystemBase.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    yield session
    session.close()
    models.SystemBase.metadata.drop_all(bind=engine)

def test_hourly_weather_aggregation(system_db):
    """
    Simulates logic from debug_reports_query.py:
    Verify that we can correctly aggregate hourly data to get average temperatures.
    """
    # 1. Setup Mock Data
    city = "TestCity"
    base_time = datetime.utcnow()
    
    # Insert 3 records: 10C, 20C, 30C -> Avg should be 20C
    temps = [10.0, 20.0, 30.0]
    
    for i, temp in enumerate(temps):
        record = models.HourlyWeatherData(
            city_name=city,
            latitude=39.0,
            longitude=32.0,
            timestamp=base_time - timedelta(hours=i), # recent timestamps
            temperature_2m=temp,
            relative_humidity_2m=50,
            precipitation=0,
            wind_speed_10m=5.0
        )
        system_db.add(record)
    
    system_db.commit()
    
    # 2. Run Aggregation Query
    cutoff = base_time - timedelta(hours=24)
    
    # Logic copied from debug_reports_query.py
    result = system_db.query(
        models.HourlyWeatherData.city_name,
        func.avg(models.HourlyWeatherData.temperature_2m).label("avg_temp")
    ).filter(
        models.HourlyWeatherData.timestamp >= cutoff,
        models.HourlyWeatherData.city_name == city
    ).group_by(models.HourlyWeatherData.city_name).first()
    
    # 3. Assertions
    assert result is not None
    assert result.city_name == city
    # SQLite might return float or decimal, roughly 20.0
    assert abs(result.avg_temp - 20.0) < 0.01
    
    print(f"Reporting Logic Test Passed: Avg Temp {result.avg_temp} matches expected 20.0")

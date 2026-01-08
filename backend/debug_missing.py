from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData
from app.core.constants import TURKEY_CITIES

def find_missing_cities():
    db = SystemSessionLocal()
    try:
        all_cities = [c["name"] for c in TURKEY_CITIES]
        existing_cities = db.query(HourlyWeatherData.city_name).distinct().all()
        existing_names = set(r[0] for r in existing_cities)
        
        missing = []
        for city in all_cities:
            if city not in existing_names:
                missing.append(city)
                
        print(f"Total Config Cities: {len(all_cities)}")
        print(f"Total DB Cities: {len(existing_names)}")
        print(f"Missing Cities: {missing}")
        
    finally:
        db.close()

if __name__ == "__main__":
    find_missing_cities()

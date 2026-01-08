from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData
from sqlalchemy import func

def check_cities():
    db = SystemSessionLocal()
    try:
        cities = ["İstanbul", "İzmir", "Ankara", "Erzurum", "Van", "Hakkari", "Kars"]
        print(f"{'City':<15} | {'Count':<8} | {'Latest Timestamp'}")
        print("-" * 45)
        
        for city in cities:
            count = db.query(HourlyWeatherData).filter(HourlyWeatherData.city_name == city).count()
            latest = db.query(func.max(HourlyWeatherData.timestamp)).filter(HourlyWeatherData.city_name == city).scalar()
            print(f"{city:<15} | {count:<8} | {latest}")
            
    finally:
        db.close()

if __name__ == "__main__":
    check_cities()

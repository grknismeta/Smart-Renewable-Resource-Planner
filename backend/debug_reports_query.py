from datetime import datetime, timedelta
from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData
from sqlalchemy import func

def test_reports_query():
    db = SystemSessionLocal()
    try:
        cutoff = datetime.utcnow() - timedelta(hours=72)
        print(f"Cutoff (UTC): {cutoff}")
        
        hourly_query = db.query(
            HourlyWeatherData.city_name,
            func.max(HourlyWeatherData.latitude).label("lat"),
            func.max(HourlyWeatherData.longitude).label("lon"),
            func.avg(HourlyWeatherData.temperature_2m).label("avg_temp")
        ).filter(HourlyWeatherData.timestamp >= cutoff).group_by(HourlyWeatherData.city_name).all()
        
        print(f"Total Rows Returned: {len(hourly_query)}")
        
        # Check specific eastern cities
        eastern_cities = ["Kars", "Van", "Hakkari", "Iğdır", "Erzurum", "Ağrı"]
        found_cities = [r.city_name for r in hourly_query]
        
        for city in eastern_cities:
            if city in found_cities:
                # Find the row
                row = next(r for r in hourly_query if r.city_name == city)
                print(f"✅ Found {city}: Lat={row.lat}, Lon={row.lon}, Temp={row.avg_temp}")
            else:
                print(f"❌ MISSING {city}")
                
        # Find max longitude
        if hourly_query:
            max_lon = max([r.lon for r in hourly_query if r.lon is not None])
            print(f"Max Longitude in Result: {max_lon}")
            
    finally:
        db.close()

if __name__ == "__main__":
    test_reports_query()

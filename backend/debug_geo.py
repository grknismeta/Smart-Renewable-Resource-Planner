import os
import sys

# Add app to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from app.services.geo_service import GeoService
    import geopandas as gpd
    from shapely.geometry import Point
except ImportError as e:
    print(f"Import Error: {e}")
    sys.exit(1)

def test_geo():
    print("🚀 Starting GeoService Debug...")
    
    # 1. Initialize Service
    try:
        service = GeoService()
    except Exception as e:
        print(f"❌ Service Initialization Failed: {e}")
        return

    # 2. Check Loaded Data
    print("\n📊 Data Status:")
    print(f" - Country Border: {'✅ Loaded' if service.country_border is not None else '❌ Failed'}")
    if service.country_border is not None:
        print(f"   CRS: {service.country_border.crs}")
    
    print(f" - Provinces: {'✅ Loaded' if service.provinces_gdf is not None else '❌ Failed'}")
    print(f" - Water: {'✅ Loaded' if service.water_gdf is not None else '❌ Failed'}")
    print(f" - Buildings: {'✅ Loaded' if service.buildings_gdf is not None else '❌ Failed'}")

    # 3. Test Point (Ankara - Should be Safe/Suitable or Restricted based on layer)
    # Ankara Coordinates: 39.9334, 32.8597
    lat, lon = 39.9334, 32.8597
    print(f"\n📍 Testing Ankara ({lat}, {lon})...")
    
    result = service.analyze_location(lat, lon)
    print("Result:", result['suitable'])
    print("Recommendation:", result['recommendation'])
    print("Reasons:", result['solar_details']['reasons'])

    # 4. Test Point (Black Sea - Should be Restricted/Water)
    # Coordinates: 42.0, 32.0 (Approximately north of Turkey in sea)
    lat_sea, lon_sea = 42.5, 32.0
    print(f"\n📍 Testing Sea ({lat_sea}, {lon_sea})...")
    
    result_sea = service.analyze_location(lat_sea, lon_sea)
    print("Result:", result_sea['suitable'])
    print("Recommendation:", result_sea['recommendation'])
    
    if result_sea['suitable']:
         print("❌ FAILS: Sea should not be suitable!")
    else:
         print("✅ SUCCESS: Sea is restricted.")

if __name__ == "__main__":
    test_geo()

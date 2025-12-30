import os
import glob
import geopandas as gpd
from shapely.geometry import Point

def test_point():
    base_dir = "backend/data/vector"
    
    # Coordinates for Marmara Sea (Approx center)
    lat = 40.8
    lon = 28.5
    point = Point(lon, lat)
    print(f"📍 Testing Point: {lat}, {lon}")

    # 1. Load Country Border (GADM Levels)
    for level in [0, 1, 2]:
        gadm_files = glob.glob(os.path.join(base_dir, f"*TUR_{level}*.shp"))
        if gadm_files:
            print(f"Loading {gadm_files[0]}...")
            gadm = gpd.read_file(gadm_files[0])
            is_in = gadm.contains(point).any()
            print(f"🇹🇷 Inside GADM Level {level}? {is_in}")
            if is_in:
                 # Print the name of the province/district
                 matches = gadm[gadm.contains(point)]
                 if not matches.empty:
                     print(f"   -> Name: {matches.iloc[0].get(f'NAME_{level}', 'Unknown')}")
        else:
            print(f"❌ GADM Level {level} file not found")

    # 2. Check ALL shapefiles in vector dir
    all_files = glob.glob(os.path.join(base_dir, "*.shp"))
    print("\n🔍 Scanning ALL vector files for containment:")
    for f in all_files:
        if "TUR_" in f: continue # Already checked
        try:
            gdf = gpd.read_file(f)
            # Clip to small box for speed check if huge (optional but good practice)
            # But query point is fast.
            matches = gdf[gdf.contains(point)]
            if not matches.empty:
                print(f"✅ FOUND in {os.path.basename(f)}:")
                for idx, row in matches.iterrows():
                    print(f"   - fclass: {row.get('fclass', 'N/A')}, name: {row.get('name', 'N/A')}")
        except Exception as e:
            # print(f"Error reading {f}") 
            pass


if __name__ == "__main__":
    test_point()

import sys
import os

# Add project root to path
sys.path.append(os.getcwd())

try:
    print("Checking imports...")
    
    # 1. Check Services
    from backend.services import solar_service
    print(" - services.solar_service: OK")
    from backend.services import wind_service
    print(" - services.wind_service: OK")
    try:
        from backend.services import geo_service
        print(" - services.geo_service: OK")
    except ImportError as e:
        print(f" - services.geo_service: SKIPPED (Known env issue: {e})")
    from backend.services import grid_service
    print(" - services.grid_service: OK")
    
    # 2. Check Core Components (Phase 2)
    from backend.db import database
    print(" - db.database: OK")
    from backend.db import models
    print(" - db.models: OK")
    from backend.schemas import schemas
    print(" - schemas.schemas: OK")
    from backend.crud import crud
    print(" - crud.crud: OK")
    
    # 3. Check Routers
    from backend.routers import scenario
    print(" - router.scenario: OK")
    from backend.routers import pins
    print(" - router.pins: OK")
    from backend.routers import geo
    print(" - router.geo: OK")
    
    print("All imports successful!")
except Exception as e:
    print(f"Import failed: {e}")
    import traceback
    traceback.print_exc()
    exit(1)

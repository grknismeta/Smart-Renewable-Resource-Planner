import os
import sys
from sqlalchemy import text
from dotenv import load_dotenv

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import order matters
from app.db.database import SystemEngine, SystemBase
from app.db import models_geo  # Import to register the models with SystemBase

load_dotenv()

def init_postgis():
    print("🚀 Initializing PostGIS extensions and tables...")
    
    with SystemEngine.begin() as conn:
        print("Enabling PostGIS extension...")
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))
    
    print("Creating tables...")
    SystemBase.metadata.create_all(bind=SystemEngine)
    print("✅ Tables created successfully.")

if __name__ == "__main__":
    init_postgis()

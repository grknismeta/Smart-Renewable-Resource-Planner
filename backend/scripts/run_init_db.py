#!/usr/bin/env python3
"""
Initialize database with equipment data
Run this script to populate the system database with turbine and solar panel models
"""
import sys
import os

# Add parent directory to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))

from backend.init_db import init_db

if __name__ == "__main__":
    print("🔄 Initializing database...")
    init_db()
    print("✅ Database initialization complete!")
    print("\nYou can now use the equipment models in the application.")

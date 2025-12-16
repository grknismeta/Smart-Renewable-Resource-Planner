#!/usr/bin/env python3
"""
Reset database after schema changes
This drops all user_db tables and recreates them
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from backend.database import UserEngine, UserBase
from backend import models

def reset_user_db():
    """Drop all tables in user_db and recreate them"""
    print("⚠️  Dropping all tables in user_db...")
    UserBase.metadata.drop_all(bind=UserEngine)
    
    print("🔄 Recreating all tables...")
    models.UserBase.metadata.create_all(bind=UserEngine)
    
    print("✅ User database reset successfully!")

if __name__ == "__main__":
    reset_user_db()

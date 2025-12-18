#!/usr/bin/env python3
"""Check database contents"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from backend.database import UserSessionLocal
from backend import models, crud

db = UserSessionLocal()

# Check users
print("=== USERS IN DATABASE ===")
users = db.query(models.User).all()
print(f"Total users: {len(users)}")
for user in users:
    print(f"  - {user.email} (id={user.id})")

# Check pins
print("\n=== PINS IN DATABASE ===")
pins = db.query(models.Pin).all()
print(f"Total pins: {len(pins)}")
for pin in pins:
    print(f"  - {pin.title} ({pin.type}) at ({pin.latitude}, {pin.longitude}) - owner_id={pin.owner_id}")

# Check pins for first user
if users:
    first_user = users[0]
    print(f"\n=== PINS FOR {first_user.email} ===")
    user_pins = crud.get_pins_by_owner(db, owner_id=first_user.id)
    print(f"Total pins: {len(user_pins)}")
    for pin in user_pins:
        print(f"  - {pin.title} ({pin.type}) at ({pin.latitude}, {pin.longitude})")

db.close()

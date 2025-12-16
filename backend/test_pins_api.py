#!/usr/bin/env python3
"""
Test script to verify /pins/ API endpoint
Run this after starting the backend with: python -m uvicorn backend.main:app --reload
"""

import requests
import json
import sys

# Backend URL
BASE_URL = "http://localhost:8000"

def test_pins_api():
    """Test the /pins/ endpoint"""
    
    # First, try to get pins without token (should fail)
    print("1. Testing /pins/ WITHOUT token (should fail with 403):")
    response = requests.get(f"{BASE_URL}/pins/")
    print(f"   Status: {response.status_code}")
    print(f"   Response: {response.text}\n")
    
    # Create a test user (register)
    print("2. Registering test user:")
    test_email = "test@example.com"
    test_password = "TestPassword123!"
    
    register_response = requests.post(
        f"{BASE_URL}/register",
        json={"email": test_email, "password": test_password}
    )
    print(f"   Status: {register_response.status_code}")
    if register_response.status_code == 200:
        print(f"   Message: User registered successfully\n")
    else:
        print(f"   Response: {register_response.text}\n")
    
    # Login
    print("3. Logging in:")
    login_response = requests.post(
        f"{BASE_URL}/login",
        json={"email": test_email, "password": test_password}
    )
    print(f"   Status: {login_response.status_code}")
    
    if login_response.status_code != 200:
        print(f"   ERROR: Login failed!")
        print(f"   Response: {login_response.text}")
        return
    
    token = login_response.json().get("access_token")
    print(f"   Token obtained: {token[:20]}...\n")
    
    # Get pins with token
    print("4. Testing /pins/ WITH token:")
    headers = {"Authorization": f"Bearer {token}"}
    pins_response = requests.get(f"{BASE_URL}/pins/", headers=headers)
    print(f"   Status: {pins_response.status_code}")
    
    if pins_response.status_code == 200:
        pins = pins_response.json()
        print(f"   Number of pins: {len(pins)}")
        print(f"   Pins data: {json.dumps(pins, indent=2)}\n")
    else:
        print(f"   ERROR: Failed to fetch pins!")
        print(f"   Response: {pins_response.text}\n")
    
    # Try to add a test pin
    print("5. Adding a test pin:")
    pin_data = {
        "latitude": 41.0082,
        "longitude": 28.9784,
        "name": "Test Solar Panel",
        "type": "Güneş Paneli",
        "capacity_mw": 0.5
    }
    
    add_pin_response = requests.post(
        f"{BASE_URL}/pins/",
        json=pin_data,
        headers=headers
    )
    print(f"   Status: {add_pin_response.status_code}")
    print(f"   Response: {add_pin_response.text}\n")
    
    # Get pins again to see if the new pin is there
    print("6. Fetching pins again after adding:")
    pins_response = requests.get(f"{BASE_URL}/pins/", headers=headers)
    print(f"   Status: {pins_response.status_code}")
    
    if pins_response.status_code == 200:
        pins = pins_response.json()
        print(f"   Number of pins: {len(pins)}")
        if pins:
            print(f"   First pin: {json.dumps(pins[0], indent=2)}")
    else:
        print(f"   ERROR: Failed to fetch pins!")
        print(f"   Response: {pins_response.text}")

if __name__ == "__main__":
    try:
        test_pins_api()
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

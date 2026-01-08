from fastapi.testclient import TestClient
from app.main import app
import os

client = TestClient(app)

# Mock Environment Variables if needed, but TestClient usually loads app which loads .env
# We might need to handle the case where .env is missing or different.
# But since we just created .env, it should be fine.

def test_read_main():
    response = client.get("/")
    assert response.status_code == 200
    # Assuming root returns something, or 404 if not defined. 
    # Let's assume 200 or 404 is acceptable for "Server running" check, 
    # but strictly we want specific endpoints.

def test_auth_login_fail():
    response = client.post("/users/token", data={"username": "wrong@example.com", "password": "wrongpassword"})
    # Expect 401 or 400 depending on implementation
    assert response.status_code in [401, 400]

def test_create_pin_unauthorized():
    # Try to create a pin without token
    response = client.post("/pins/", json={
        "latitude": 39.0, 
        "longitude": 32.0, 
        "title": "Test Pin", 
        "type": "Güneş Paneli"
    })
    assert response.status_code == 401

# Note: Valid login test is hard without a seeded user. 
# We'd need to mock dependency override for get_db to use a test DB.
# However, we can test the logic flow if we can use a temporary DB override in TestClient.
# For simplicity in this suite, we will focus on the Logic and DB Integrity tests for full coverage,
# but we can add more mock-based API tests here.

import pytest
from app import auth

def test_register_user_success():
    # Since we are running against the live app in TestClient (which uses real DB unless overridden),
    # we should be careful. 
    # Ideally, we override_dependency in conftest.
    # But for now, we will use a random email to ensure success.
    import random
    rand_id = random.randint(1000, 99999)
    email = f"testuser{rand_id}@example.com"
    
    response = client.post("/users/register", json={
        "email": email, 
        "password": "securepassword",
        "full_name": "Test User"
    })
    # Accept 201 Created or 200 OK depending on implementation
    assert response.status_code in [200, 201]
    data = response.json()
    assert data["email"] == email

def test_register_duplicate_email():
    # Register same user twice (using a fixed temp email check or relying on previous test)
    # We'll try to register 'duplicate@example.com' twice.
    email = "duplicate@example.com"
    client.post("/users/register", json={"email": email, "password": "p"}) # Ensure exists
    
    response = client.post("/users/register", json={"email": email, "password": "p"})
    assert response.status_code == 400
    assert "zaten kayıtlı" in response.json()["detail"] or "already registered" in response.json()["detail"]

def test_login_success():
    # 1. Create user
    email = "login_test@example.com"
    password = "loginpass123"
    client.post("/users/register", json={"email": email, "password": password})
    
    # 2. Login
    response = client.post("/users/token", data={"username": email, "password": password})
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    return data["access_token"] # Use in next test?

def test_get_users_me():
    # 1. Get Token
    email = "profile_test@example.com"
    password = "pass"
    client.post("/users/register", json={"email": email, "password": password})
    login_res = client.post("/users/token", data={"username": email, "password": password})
    token = login_res.json()["access_token"]
    
    # 2. Access Protected Endpoint
    headers = {"Authorization": f"Bearer {token}"}
    response = client.get("/users/me", headers=headers)
    assert response.status_code == 200
    assert response.json()["email"] == email

# --- Expanded API Tests ---

def test_register_invalid_email_format():
    response = client.post("/users/register", json={
        "email": "invalid-email-format", # Missing @
        "password": "pass"
    })
    # Pydantic validation should catch this = 422
    assert response.status_code == 422 

def test_register_short_password():
    # If policy exists. Assume min length 4?
    response = client.post("/users/register", json={
        "email": "short@example.com", 
        "password": "123" 
    })
    # If no policy, this might pass (200). Logic check:
    # Let's assume standard security best practice (fail) or just check it doesn't crash 500.
    assert response.status_code in [200, 201, 400, 422]

def test_get_nonexistent_endpoint():
    response = client.get("/this/does/not/exist")
    assert response.status_code == 404

def test_delete_without_token():
    # DELETE /pins/{id} needs auth
    response = client.delete("/pins/9999")
    assert response.status_code == 401

def test_put_without_token():
    # PUT /pins/{id} needs auth
    response = client.put("/pins/9999", json={"title": "Hacker Update"})
    assert response.status_code == 401

def test_post_pin_invalid_coordinates():
    # Helper to get token first
    # In real test suite, use fixture. Here we repeat login for isolation.
    email = "coord_test@example.com"
    pwd = "pass"
    client.post("/users/register", json={"email": email, "password": pwd})
    token = client.post("/users/token", data={"username": email, "password": pwd}).json()["access_token"]
    
    headers = {"Authorization": f"Bearer {token}"}
    
    # Latitude > 90 is invalid
    response = client.post("/pins/", json={
        "latitude": 95.0, 
        "longitude": 30.0,
        "title": "Invalid Lat"
    }, headers=headers)
    
    # Ideally 422 (Validation Error)
    assert response.status_code == 422

def test_health_check_explicit():
    # /health often used by load balancers
    # If not implemented, verify 404. If implemented, 200.
    # We checked modules, didn't see explicit /health.
    response = client.get("/health")
    assert response.status_code in [200, 404]

def test_login_missing_fields():
    # Missing password
    response = client.post("/users/token", data={"username": "missing@example.com"})
    assert response.status_code == 422

def test_token_format_validation():
    # Send malformed token header
    headers = {"Authorization": "Bearer malformed.token.structure"}
    response = client.get("/users/me", headers=headers)
    assert response.status_code == 401

def test_empty_json_body_on_post():
    # POST /users/register with empty body
    response = client.post("/users/register", json={})
    assert response.status_code == 422

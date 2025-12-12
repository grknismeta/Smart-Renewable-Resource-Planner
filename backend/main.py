from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .database import UserEngine, SystemEngine
from . import models

# --- ROUTERLARI IMPORT ET ---
# DİKKAT: Eski 'turbines' ve 'solar_panels' dosyaları yerine artık 'equipments' var.
from .routers import pins, users, equipments, scenario 
# ----------------------------

# Veritabanı tablolarını oluştur (Eğer yoksa)
models.SystemBase.metadata.create_all(bind=SystemEngine)
models.UserBase.metadata.create_all(bind=UserEngine)

app = FastAPI(
    title="Smart Renewable Resource Planner (SRRP) API",
    description="Güneş ve Rüzgar enerjisi potansiyeli hesaplama ve planlama API'si",
    version="1.0.0"
)

# --- CORS AYARLARI ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- ROUTERLARI UYGULAMAYA EKLE ---
app.include_router(pins.router, prefix="/pins", tags=["Pins"])
app.include_router(users.router, prefix="/users", tags=["Users"])

# Yeni Ekipman Router'ı (Rüzgar türbinleri ve Güneş panelleri burada)
app.include_router(equipments.router, prefix="/equipments", tags=["Equipments"])

# Senaryo Router'ı (ML Tahmin Senaryoları)
app.include_router(scenario.router, prefix="/scenarios", tags=["Scenarios"])

@app.get("/")
def read_root():
    return {"message": "SRRP API başarıyla çalışıyor! 🚀"}
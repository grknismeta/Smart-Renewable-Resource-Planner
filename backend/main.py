from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .database import UserEngine, SystemEngine
from . import models

# --- ROUTERLARI IMPORT ET ---
from .routers import pins, users, equipments, optimization # Optimization Eklendi

# Veritabanı tablolarını oluştur
models.SystemBase.metadata.create_all(bind=SystemEngine)
models.UserBase.metadata.create_all(bind=UserEngine)


# --- STARTUP/SHUTDOWN YAŞAM DÖNGÜSÜ ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Backend başladığında çalışır
    print("🚀 Backend başlatılıyor...")
    
    # Eksik günleri kontrol et ve doldur (arka planda)
    try:
        from .daily_updater import async_check_and_update
        import asyncio
        asyncio.create_task(async_check_and_update())
    except Exception as e:
        print(f"[DailyUpdater] Başlatma hatası: {e}")
    
    yield  # Uygulama çalışıyor
    
    # Shutdown: Backend kapanırken çalışır
    print("👋 Backend kapatılıyor...")


app = FastAPI(
    title="Smart Renewable Resource Planner (SRRP) API",
    description="Güneş ve Rüzgar enerjisi potansiyeli hesaplama ve planlama API'si",
    version="2.1.0",
    lifespan=lifespan
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
app.include_router(equipments.router, prefix="/equipments", tags=["Equipments"])
app.include_router(optimization.router) # Prefix router içinde tanımlı

@app.get("/")
def read_root():
    return {"message": "SRRP API başarıyla çalışıyor! 🚀 Sistem: Optimizasyon Modülü Aktif."}
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .db.database import UserEngine, SystemEngine, UserPinsEngine
from .db import models

# --- ROUTERLARI IMPORT ET ---
from .routers import pins, users, equipments, optimization, weather, reports, scenario, geo

# Veritabanı tablolarını oluştur
models.SystemBase.metadata.create_all(bind=SystemEngine)
models.UserBase.metadata.create_all(bind=UserEngine)
models.UserPinsBase.metadata.create_all(bind=UserPinsEngine)


# --- STARTUP/SHUTDOWN YAŞAM DÖNGÜSÜ ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Backend başladığında çalışır
    print("🚀 Backend başlatılıyor...")
    
    import asyncio
    
    # 1. Günlük veri eksiklerini kontrol et ve doldur
    try:
        from .services.collectors.historical import async_update_daily_grid_data
        asyncio.create_task(async_update_daily_grid_data())
        print("📅 Günlük veri güncelleyici başlatıldı")
    except Exception as e:
        print(f"[DailyUpdater] Başlatma hatası: {e}")
        
    # 2. Saatlik verileri güncelle
    try:
        from .services.collectors.hourly import async_update_hourly_data
        asyncio.create_task(async_update_hourly_data())
        print("⏱️ Saatlik veri güncelleyici başlatıldı")
    except Exception as e:
        print(f"[HourlyUpdater] Başlatma hatası: {e}")

    # 3. Yıllık/Aylık Ağ Analizini Güncelle (Local DB'den)
    try:
        from .services.grid_service import GridService
        from .db.database import SystemSessionLocal
        from fastapi.concurrency import run_in_threadpool
        
        async def run_grid_aggregation():
            print("🗺️ Grid Analiz Servisi başlatılıyor...")
            db = SystemSessionLocal()
            try:
                # Bloklamaması için threadpool'da çalıştır
                service = GridService()
                await run_in_threadpool(service.calculate_and_update_from_local_db, db)
            except Exception as e:
                print(f"[GridAggregator] Hata: {e}")
            finally:
                db.close()
                
        asyncio.create_task(run_grid_aggregation())
        
    except Exception as e:
         print(f"[GridAggregator] Başlatma hatası: {e}")
    
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
app.include_router(weather.router)  # Şehir bazlı hava durumu
app.include_router(reports.router, tags=["Reports"])
app.include_router(scenario.router, prefix="/scenarios", tags=["Scenarios"])
app.include_router(geo.router, prefix="/geo", tags=["Geo Analysis"])

@app.get("/")
def read_root():
    return {"message": "SRRP API başarıyla çalışıyor! 🚀 Sistem: Optimizasyon Modülü Aktif."}
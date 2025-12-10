# main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from contextlib import asynccontextmanager
from .database import SessionLocal, engine
from . import models, crud, test_data
from .routers import users, pins, turbines, solar_panels
from . import models, schemas, auth, database
from .solar_calculations import calculate_panel_efficiency
from .wind_calculations import get_power_from_curve  
# 1. Veritabanı tabloları oluşturulur (yeni Turbine tablosu dahil).
models.Base.metadata.create_all(bind=engine)

# YENİ STARTUP EVENT'İ
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Uygulama başladığında
    db = SessionLocal()
    try:
        # Standart türbin ve panellerin olduğundan emin ol
        if not crud.get_default_turbine(db) and not crud.get_default_solar_panel(db):
            print("Varsayılan türbin ve panel modelleri oluşturuluyor...")
            test_data.create_test_data(db)
        else:
            print("Varsayılan modeller zaten mevcut.")
    finally:
        db.close()

    yield
    # Uygulama kapandığında (gerekirse buraya kod eklenebilir)

# 2. FastAPI uygulaması oluşturulur.
app = FastAPI(
    title="SRRP Backend API",
    description="Smart Renewable Resources Project - Yenilenebilir Kaynak Planlama API'si",
    version="1.0.0",
)

# 3. CORS ayarları oluşturulan app'e eklenir.
origins = ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 4. Router'lar uygulamaya dahil edilir.
# (Kullanıcı giriş/kayıt işlemleri)
app.include_router(users.router, prefix="/users", tags=["Users"]) 
# (Pin oluşturma, listeleme ve HESAPLAMA işlemleri)
app.include_router(pins.router, prefix="/pins", tags=["Pins"])
# (Türbin modellerini yönetmek için router)
app.include_router(turbines.router)
# (Güneş paneli modellerini yönetmek için YENİ router)
app.include_router(solar_panels.router)

# 5. Kök Uç Nokta
@app.get("/")
def read_root():
    return {"message": "SRRP Backend çalışıyor! /docs adresini ziyaret edin."}


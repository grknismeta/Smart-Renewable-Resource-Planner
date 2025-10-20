# main.py

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
# from sqlalchemy.orm import Session 

# Düzeltildi: .models yerine direkt models import edildi.
import models 
from database import engine 
from routers import users, pins 


# 1. Veritabanı tabloları oluşturulur.
models.Base.metadata.create_all(bind=engine)

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
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 4. Router'lar uygulamaya dahil edilir.
app.include_router(users.router)
app.include_router(pins.router)

# 5. Kök Uç Nokta
@app.get("/")
def read_root():
    return {"message": "SRRP Backend çalışıyor! /docs adresini ziyaret edin."}

# NOT: Eski SessionLocal import'u main.py'den kaldırıldı.
# database dependency'si router'lar içinde tanımlanmıştır.

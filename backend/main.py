from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from fastapi.middleware.cors import CORSMiddleware

import models
import schemas
from database import SessionLocal, engine

# 1. Veritabanı tabloları oluşturulur.
models.Base.metadata.create_all(bind=engine)

# 2. FastAPI uygulaması SADECE BİR KERE burada oluşturulur.
app = FastAPI()

# 3. CORS ayarları oluşturulan app'e eklenir.
origins = ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 4. Veri ekleme bloğu çalışır.
db = None
try:
    db = SessionLocal()
    if db.query(models.Resource).count() == 0:
        print("Veritabanı boş, başlangıç verileri ekleniyor...")
        db.add_all([
            models.Resource(name="Manisa Rüzgar Enerji Santrali", type="Rüzgar Türbini", capacity_mw=250.5),
            models.Resource(name="Gediz Güneş Tarlası", type="Güneş Paneli", capacity_mw=120.0),
            models.Resource(name="Demirköprü Barajı", type="Hidroelektrik", capacity_mw=69.0)
        ])
        db.commit()
        print("Başlangıç verileri eklendi.")
finally:
    if db:
        db.close()

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- API ENDPOINT'LERİ ---

@app.get("/")
def read_root():
    return {"message": "SRRP Backend'i çalışıyor!"}

@app.get("/api/resources")
def get_resources(db: Session = Depends(get_db)):
    resources = db.query(models.Resource).all()
    return resources

@app.post("/api/resources")
def create_resource(resource: schemas.ResourceCreate, db: Session = Depends(get_db)):
    # Bu fonksiyon artık veritabanına gerçekten kayıt yapıyor.
    new_resource = models.Resource(
        name=resource.name,
        type=resource.type,
        capacity_mw=resource.capacity_mw
    )
    db.add(new_resource)
    db.commit()
    db.refresh(new_resource)
    return new_resource
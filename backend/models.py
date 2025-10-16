from sqlalchemy import Column, Integer, String, Float
from database import Base

# "resources" adında bir tabloyu temsil eden Python class'ı oluşturuyoruz.
class Resource(Base):
    __tablename__ = "resources" # Tablonun veritabanındaki adı

    # Tablonun sütunlarını ve özelliklerini tanımlıyoruz.
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    type = Column(String) # Örn: "Güneş Paneli", "Rüzgar Türbini"
    capacity_mw = Column(Float) # Kapasitesi (Megawatt cinsinden)
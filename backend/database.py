from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# 1. Veritabanı dosyasının adını ve yolunu belirliyoruz.
SQLALCHEMY_DATABASE_URL = "sqlite:///./database.db"

# 2. SQLAlchemy "engine"ini oluşturuyoruz.
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# 3. Veritabanına yapılacak her bir işlem (session) için bir "fabrika" oluşturuyoruz.
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 4. Modellerimizi (veritabanı tablolarımız) oluştururken miras alacağımız ana (Base) class'ı tanımlıyoruz.
Base = declarative_base()
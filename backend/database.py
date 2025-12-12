from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator

# --- 1. SİSTEM VERİTABANI (Grid Analizi, Ekipmanlar) ---
# Grid Taraması gibi büyük ve sabit veriler burada saklanır.
SYSTEM_DB_URL = "sqlite:///./backend/system_data.db"

SystemEngine = create_engine(
    SYSTEM_DB_URL, connect_args={"check_same_thread": False}
)
SystemSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=SystemEngine)
SystemBase = declarative_base()


# --- 2. KULLANICI VERİTABANI (User, Pin, Scenario) ---
# Kullanıcı hesapları ve oluşturduğu dinamik içerikler burada saklanır.
USER_DB_URL = "sqlite:///./backend/user_data.db"

UserEngine = create_engine(
    USER_DB_URL, connect_args={"check_same_thread": False}
)
UserSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=UserEngine)
UserBase = declarative_base()


# Dependency function (Artık iki DB'yi de yönetebiliriz, ancak varsayılan User DB'dir)
def get_db() -> Generator[Session, None, None]:
    db = UserSessionLocal()
    try:
        yield db
    finally:
        db.close()

# System Session için özel dependency (Sadece System modelleri için kullanılır)
def get_system_db() -> Generator[Session, None, None]:
    db = SystemSessionLocal()
    try:
        yield db
    finally:
        db.close()
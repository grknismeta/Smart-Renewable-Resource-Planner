from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator
import os

# ─── TEK BAĞLANTI — Tüm tablolar aynı PostgreSQL veritabanında ─────────────
# Docker Compose'dan gelen DATABASE_URL'yi al, yoksa varsayılanı kullan.
# Eski SQLite (user_data.db / user_pins_data.db) tamamen kaldırıldı.
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://srrp_admin:srrp_secure_2026@localhost:5432/srrp_db",
)

# pool_pre_ping: bağlantı düşmüşse otomatik yenile
_engine = create_engine(DATABASE_URL, pool_pre_ping=True)
_SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_engine)

# ─── Logical Base'ler — kod organizasyonu için korundu, hepsi aynı engine ──
SystemBase   = declarative_base()   # Sistem/GEO verileri
UserBase     = declarative_base()   # Kullanıcılar, Pinler, Senaryolar
UserPinsBase = declarative_base()   # Pin hesaplama sonuçları

# ─── Engine alias'ları — geriye dönük uyumluluk (diğer modüller için) ───────
SystemEngine        = _engine
UserEngine          = _engine
UserPinsEngine      = _engine
SystemSessionLocal  = _SessionLocal
UserSessionLocal    = _SessionLocal
UserPinsSessionLocal = _SessionLocal

# ─── Dependency'ler ─────────────────────────────────────────────────────────

def get_db() -> Generator[Session, None, None]:
    """Kullanıcı/Pin/Senaryo işlemleri için oturum döner."""
    db = _SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_system_db() -> Generator[Session, None, None]:
    """Sistem/GEO verileri için oturum döner (get_db ile aynı DB)."""
    db = _SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_user_pins_db() -> Generator[Session, None, None]:
    """Pin hesaplama sonuçları için oturum döner (get_db ile aynı DB)."""
    db = _SessionLocal()
    try:
        yield db
    finally:
        db.close()

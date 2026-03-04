from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .db.database import UserEngine, SystemEngine, UserPinsEngine
from .db import models

import os
import sys
from datetime import datetime

# ─── ANSI Renk Kodları ────────────────────────────────────────────────────────
_C = {
    "reset":  "\033[0m",
    "bold":   "\033[1m",
    "dim":    "\033[2m",
    "green":  "\033[92m",
    "cyan":   "\033[96m",
    "yellow": "\033[93m",
    "red":    "\033[91m",
    "blue":   "\033[94m",
    "gray":   "\033[90m",
    "teal":   "\033[36m",
    "white":  "\033[97m",
}

def _c(color: str, text: str) -> str:
    """ANSI renkli metin. Windows'ta VT100 desteklenmiyorsa düz döner."""
    if sys.platform == "win32":
        try:
            import ctypes
            k = ctypes.windll.kernel32
            k.SetConsoleMode(k.GetStdHandle(-11), 7)
        except Exception:
            return text
    return f"{_C.get(color, '')}{text}{_C['reset']}"

def _section(title: str, emoji: str = ""):
    prefix = f"{emoji}  " if emoji else ""
    bar = "─" * (54 - len(prefix + title))
    print(f"\n  {_c('teal', prefix + title)} {_c('gray', bar)}")

def _row(label: str, value: str, ok: bool | None = None):
    if ok is True:
        state = _c("green", "● AKTİF")
    elif ok is False:
        state = _c("gray", "○ Devre Dışı")
    else:
        state = _c("cyan", value)
    print(f"    {_c('gray', label.ljust(28))} {state}")

def _ok(msg: str):
    print(f"    {_c('green', '✔')}  {msg}")

def _info(msg: str):
    print(f"    {_c('cyan', '→')}  {msg}")

def _warn(msg: str):
    print(f"    {_c('yellow', '⚠')}  {msg}")

def _err(msg: str):
    print(f"    {_c('red', '✖')}  {msg}")

def print_banner():
    print()
    print(_c("green", "  ╔══════════════════════════════════════════════════════════╗"))
    print(_c("green", "  ║") + _c("bold", "   ⚡  Smart Renewable Resource Planner") + _c("gray", "  API v2.1.0    ") + _c("green", "║"))
    print(_c("green", "  ╚══════════════════════════════════════════════════════════╝"))
    print()
    now = datetime.now().strftime("%d.%m.%Y %H:%M")
    print(f"  {_c('gray', '🕐 Başlangıç:')}  {_c('white', now)}")

# ─── ROUTERLARI IMPORT ET ─────────────────────────────────────────────────────
from .routers import pins, users, equipments, optimization, weather, reports, scenario, tiles

# Coğrafya analiz motoru
_GEO_ENABLED = os.getenv("GEO_ANALYSIS_ENABLED", "false").lower() == "true"
if _GEO_ENABLED:
    from .routers import geo

# Veritabanı tablolarını oluştur
models.SystemBase.metadata.create_all(bind=SystemEngine)
models.UserBase.metadata.create_all(bind=UserEngine)
models.UserPinsBase.metadata.create_all(bind=UserPinsEngine)


# ─── STARTUP / SHUTDOWN ───────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    print_banner()

    _section("Arkaplan Servisler", "🔧")

    import asyncio

    # 1. Günlük veri güncelleme
    try:
        from .services.collectors.historical import async_update_daily_grid_data
        asyncio.create_task(async_update_daily_grid_data())
        _ok("Günlük Grid Veri Güncelleyici başlatıldı")
    except Exception as e:
        _warn(f"Günlük Grid Güncelleyici başlatılamadı: {e}")

    # 2. Saatlik veri güncelleme
    try:
        from .services.collectors.hourly import async_update_hourly_data
        asyncio.create_task(async_update_hourly_data())
        _ok("Saatlik Hava Veri Güncelleyici başlatıldı")
    except Exception as e:
        _warn(f"Saatlik Hava Güncelleyici başlatılamadı: {e}")

    # 3. Grid Agregasyon Servisi
    try:
        from .services.grid_service import GridService
        from .db.database import SystemSessionLocal
        from fastapi.concurrency import run_in_threadpool

        async def run_grid_aggregation():
            _info("Grid Analiz agregasyonu çalışıyor (arka planda)...")
            db = SystemSessionLocal()
            try:
                service = GridService()
                await run_in_threadpool(service.calculate_and_update_from_local_db, db)
                _ok("Grid Analiz agregasyonu tamamlandı")
            except Exception as e:
                _err(f"Grid Analiz Hatası: {e}")
            finally:
                db.close()

        asyncio.create_task(run_grid_aggregation())
    except Exception as e:
        _warn(f"Grid Agregator başlatılamadı: {e}")

    _section("Sunucu Hazır", "🚀")
    _row("Ana URL",      "http://localhost:8000")
    _row("Swagger UI",   "http://localhost:8000/docs")
    _row("Redoc",        "http://localhost:8000/redoc")
    _row("GEO Analizi",  "", ok=_GEO_ENABLED)
    print()
    print(_c("gray", "  " + "─" * 58))
    print(_c("gray", "  Loglar ↓") + _c("dim", "  (Durdurmak için Ctrl+C)"))
    print(_c("gray", "  " + "─" * 58))
    print()

    yield

    # Shutdown
    print()
    print(_c("gray", "  " + "─" * 58))
    _info("Kapatma isteği alındı. Servisler durduruluyor...")
    print(_c("yellow", "  👋 Backend güvenli şekilde kapatıldı."))
    print()


# ─── FASTAPI UYGULAMASI ────────────────────────────────────────────────────────
app = FastAPI(
    title="Smart Renewable Resource Planner (SRRP) API",
    description="Güneş, Rüzgar ve Hidroelektrik enerji potansiyeli hesaplama ve planlama API'si",
    version="2.1.0",
    lifespan=lifespan,
)

# CORS Ayarları
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── ROUTER'LAR ───────────────────────────────────────────────────────────────
app.include_router(pins.router,         prefix="/pins",       tags=["📍 Pins"])
app.include_router(users.router,        prefix="/users",      tags=["👤 Users"])
app.include_router(equipments.router,   prefix="/equipments", tags=["⚙️ Equipments"])
app.include_router(optimization.router)                                           # Prefix router içinde
app.include_router(weather.router)                                                # Şehir bazlı hava
app.include_router(reports.router,      tags=["📊 Reports"])
app.include_router(scenario.router,     prefix="/scenarios",  tags=["🗂️ Scenarios"])
app.include_router(tiles.router,        prefix="/api/v1/tiles", tags=["🗺️ Map Tiles (MVT)"])

if _GEO_ENABLED:
    app.include_router(geo.router, prefix="/geo", tags=["🗺️ Geo Analysis"])
else:
    from fastapi import APIRouter
    from fastapi.responses import JSONResponse

    _stub_geo = APIRouter()

    @_stub_geo.post("/check-suitability")
    async def geo_stub_check(request: dict = None):
        return JSONResponse({
            "suitable": True,
            "geo_disabled": True,
            "message": "Coğrafya analizi devre dışı. Tüm alanlar kurulabilir sayılıyor.",
        })

    app.include_router(_stub_geo, prefix="/geo", tags=["🗺️ Geo (Stub)"])


# ─── ROOT ENDPOINT ────────────────────────────────────────────────────────────
@app.get("/", tags=["🏠 Root"])
def read_root():
    return {
        "status": "ok",
        "message": "SRRP API çalışıyor ⚡",
        "version": "2.1.0",
        "docs": "/docs",
    }
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .db.database import UserEngine, SystemEngine, UserPinsEngine
from .db import models

# models_geo (GeoAlchemy2 bağımlılığı): tablolar oluşturulabilmesi için import edilmeli.
# geoalchemy2 kurulu değilse sessizce atla — uygulama tile/geo olmadan çalışmaya devam eder.
_POSTGIS_AVAILABLE = False
try:
    from .db import models_geo  # type: ignore
    _POSTGIS_AVAILABLE = True
except (ImportError, Exception):
    pass

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

def _safe_print(text: str):
    """Windows cp1254 uyumlu print — encode edilemeyen karakterleri '?' ile değiştirir."""
    try:
        print(text)
    except UnicodeEncodeError:
        print(text.encode(sys.stdout.encoding or "ascii", errors="replace").decode(sys.stdout.encoding or "ascii"))

def _section(title: str, emoji: str = ""):
    prefix = f"{emoji}  " if emoji else ""
    bar = "-" * max(0, 54 - len(prefix + title))
    _safe_print(f"\n  {_c('teal', prefix + title)} {_c('gray', bar)}")

def _row(label: str, value: str, ok: bool | None = None):
    if ok is True:
        state = _c("green", "[AKTIF]")
    elif ok is False:
        state = _c("gray", "[Devre Disi]")
    else:
        state = _c("cyan", value)
    _safe_print(f"    {_c('gray', label.ljust(28))} {state}")

def _ok(msg: str):
    _safe_print(f"    {_c('green', '[OK]')}  {msg}")

def _info(msg: str):
    _safe_print(f"    {_c('cyan', '->')}  {msg}")

def _warn(msg: str):
    _safe_print(f"    {_c('yellow', '[!]')}  {msg}")

def _err(msg: str):
    _safe_print(f"    {_c('red', '[X]')}  {msg}")

def print_banner():
    _safe_print("")
    _safe_print(_c("green", "  +----------------------------------------------------------+"))
    _safe_print(_c("green", "  |") + _c("bold", "   * Smart Renewable Resource Planner") + _c("gray", "  API v2.1.0    ") + _c("green", "|"))
    _safe_print(_c("green", "  +----------------------------------------------------------+"))
    _safe_print("")
    now = datetime.now().strftime("%d.%m.%Y %H:%M")
    _safe_print(f"  {_c('gray', 'Baslangiç:')}  {_c('white', now)}")

# ─── ROUTERLARI IMPORT ET ─────────────────────────────────────────────────────
from .routers import pins, users, equipments, optimization, weather, reports, scenario, tiles, recommendations, wind_vectors, borders

# Coğrafya analiz motoru
_GEO_ENABLED = os.getenv("GEO_ANALYSIS_ENABLED", "false").lower() == "true"
if _GEO_ENABLED:
    from .routers import geo

# Veritabanı tablolarını oluştur (PostgreSQL — tek engine, tüm Base'ler)
models.SystemBase.metadata.create_all(bind=SystemEngine)
models.UserBase.metadata.create_all(bind=UserEngine)
models.UserPinsBase.metadata.create_all(bind=UserPinsEngine)


# ─── ONE-TIME MIGRATIONS ─────────────────────────────────────────────────────
def _wind_migration_needed() -> bool:
    """Flag dosyası kontrolü — migration zaten yapıldı mı?"""
    import os
    return not os.path.exists(
        os.path.join(os.path.dirname(__file__), ".wind_migration_done")
    )


def _run_wind_speed_migration_sync():
    """Eski km/h rüzgar verilerini m/s'ye dönüştür (batch'li, arka plan).

    wind_speed_unit: 'ms' parametresi eklenmeden önce toplanan tüm veriler
    km/h birimindeydi ama m/s olarak kaydedildi. Bu migration 3.6'ya bölerek düzeltir.
    """
    import os
    from .db.database import SystemSessionLocal
    from .db.models import HourlyWeatherData
    from sqlalchemy import update, text

    flag_path = os.path.join(os.path.dirname(__file__), ".wind_migration_done")
    cutoff = datetime(2026, 4, 10, 0, 0, 0)
    BATCH = 50_000  # 50K satır per commit — DB'yi kilitlemez

    _info("Rüzgar hızı migration başlıyor (arka planda, batch=50K)...")

    db = SystemSessionLocal()
    try:
        total_fixed = 0
        while True:
            # Batch: sadece henüz düzeltilmemiş satırları al
            # wind_speed_10m > 15 → büyük olasılıkla km/h (doğru m/s nadiren >15)
            result = db.execute(
                text("""
                    UPDATE hourly_weather_data
                    SET wind_speed_10m  = wind_speed_10m  / 3.6,
                        wind_speed_100m = wind_speed_100m / 3.6,
                        wind_gusts_10m  = wind_gusts_10m  / 3.6
                    WHERE id IN (
                        SELECT id FROM hourly_weather_data
                        WHERE timestamp < :cutoff
                          AND wind_speed_10m IS NOT NULL
                          AND wind_speed_10m > 15
                        LIMIT :batch_size
                    )
                """),
                {"cutoff": cutoff, "batch_size": BATCH},
            )
            db.commit()
            affected = result.rowcount
            total_fixed += affected
            if affected < BATCH:
                break  # Son batch — bitti

        _ok(f"Rüzgar hızı migration tamamlandı: {total_fixed} kayıt düzeltildi")

        with open(flag_path, "w") as f:
            f.write(f"Migration completed at {datetime.now().isoformat()}\n")
            f.write(f"Total rows fixed: {total_fixed}\n")
    except Exception as e:
        _warn(f"Rüzgar hızı migration hatası: {e}")
    finally:
        db.close()


# ─── STARTUP / SHUTDOWN ───────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    print_banner()

    _section("Arkaplan Servisler", "[*]")

    import asyncio
    from concurrent.futures import ThreadPoolExecutor

    # 0. Rüzgar hızı migration (arka planda, sunucu başlamasını engellemez)
    if _wind_migration_needed():
        _info("Rüzgar hızı migration arka planda başlatılıyor...")
        _migration_pool = ThreadPoolExecutor(max_workers=1, thread_name_prefix="wind-migration")
        asyncio.get_event_loop().run_in_executor(_migration_pool, _run_wind_speed_migration_sync)
    else:
        _ok("Rüzgar hızı migration: zaten tamamlanmış")

    # 1. Günlük veri güncelleme
    try:
        from .services.collectors.historical import async_update_daily_grid_data
        asyncio.create_task(async_update_daily_grid_data())
        _ok("Günlük Grid Veri Güncelleyici başlatıldı")
    except Exception as e:
        _warn(f"Günlük Grid Güncelleyici başlatılamadı: {e}")

    # 2. Saatlik veri güncelleme — başlangıçta bir kez + her 1 saatte tekrar
    try:
        from .services.collectors.hourly import async_update_hourly_data

        async def _periodic_hourly_update():
            """İlk çalıştırma + periyodik 1 saatlik döngü."""
            await async_update_hourly_data()
            _ok("Saatlik Hava Veri Güncelleyici ilk çalıştırma tamamlandı")
            while True:
                await asyncio.sleep(3600)  # 1 saat bekle
                try:
                    _info("Periyodik saatlik veri güncellemesi başlıyor...")
                    await async_update_hourly_data()
                    _ok("Periyodik saatlik veri güncellemesi tamamlandı")
                except Exception as exc:
                    _warn(f"Periyodik güncelleme hatası: {exc}")

        asyncio.create_task(_periodic_hourly_update())
        _ok("Saatlik Hava Veri Güncelleyici başlatıldı (1 saatte bir tekrar)")
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

    # 4. PostGIS GIST Mekansal İndeksleri — yoksa oluştur
    if _POSTGIS_AVAILABLE:
        try:
            from .routers.tiles import ensure_spatial_indexes
            asyncio.create_task(ensure_spatial_indexes())
            _ok("PostGIS GIST indeks kontrolü başlatıldı")
        except Exception as e:
            _warn(f"GIST indeks oluşturulamadı: {e}")

    _section("Sunucu Hazir", "[>>]")
    _row("Ana URL",      "http://localhost:8000")
    _row("Swagger UI",   "http://localhost:8000/docs")
    _row("Redoc",        "http://localhost:8000/redoc")
    _row("GEO Analizi",  "", ok=_GEO_ENABLED)
    print()
    _safe_print(_c("gray", "  " + "-" * 58))
    _safe_print(_c("gray", "  Loglar:") + _c("dim", "  (Durdurmak icin Ctrl+C)"))
    _safe_print(_c("gray", "  " + "-" * 58))
    _safe_print("")

    yield

    # Shutdown
    _safe_print("")
    _safe_print(_c("gray", "  " + "-" * 58))
    _info("Kapatma istegi alindi. Servisler durduruluyor...")
    _safe_print(_c("yellow", "  Backend guvenli sekilde kapatildi."))
    _safe_print("")


# ─── OPENAPI TAG AÇIKLAMALARI ──────────────────────────────────────────────────
_tags_metadata = [
    {"name": "🏠 Root",             "description": "API sağlık kontrolü"},
    {"name": "👤 Users",            "description": "Kullanıcı kayıt, giriş ve profil yönetimi"},
    {"name": "📍 Pins",             "description": "Enerji kaynağı pinleri — oluşturma, listeleme, analiz"},
    {"name": "⚙️ Equipments",      "description": "Güneş paneli / rüzgar türbini / HES ekipman kataloğu"},
    {"name": "🗂️ Scenarios",       "description": "Senaryo oluşturma, düzenleme ve enerji simülasyonu"},
    {"name": "📊 Reports",          "description": "Bölgesel enerji potansiyeli raporları"},
    {"name": "🌤️ Weather",         "description": "Şehir bazlı hava durumu ve güneş/rüzgar verileri"},
    {"name": "🗺️ Map Tiles (MVT)", "description": "Mapbox Vector Tile (MVT/PBF) — harita katmanları"},
    {"name": "🗺️ Geo Analysis",    "description": "PostGIS tabanlı coğrafya uygunluk analizi (opsiyonel)"},
    {"name": "🗺️ Geo (Stub)",      "description": "Geo analiz devre dışıyken stub endpoint'ler"},
    {"name": "🛠️ Optimization",    "description": "Türbin/panel konumlandırma optimizasyon algoritmaları"},
    {"name": "🧭 Recommendations", "description": "Weibull analizine dayalı akıllı bölge önerileri"},
]

# ─── FASTAPI UYGULAMASI ────────────────────────────────────────────────────────
app = FastAPI(
    title="Smart Renewable Resource Planner (SRRP) API",
    description="""
## ⚡ Akıllı Yenilenebilir Kaynak Planlayıcısı

Güneş, rüzgar ve hidroelektrik enerji potansiyelini analiz eden REST API.

### Özellikler
- **Pin Yönetimi** — Harita üzerinde enerji kaynaklarını işaretle ve analiz et
- **Senaryo Simülasyonu** — 7 günlük güneş/rüzgar/HES enerji üretim hesabı
- **Bölgesel Raporlar** — Türkiye geneli potansiyel analizi ve sıralama
- **Harita Tile'ları** — PostGIS vector tile (MVT/PBF) servisi
- **Coğrafya Analizi** — GIS tabanlı uygunluk ve yasak alan kontrolü

### Kimlik Doğrulama
Korumalı endpoint'ler `Authorization: Bearer <token>` header'ı gerektirir.
Token almak için → `POST /users/login`
""",
    version="2.1.0",
    contact={"name": "SRRP Geliştirici", "url": "http://localhost:8000"},
    license_info={"name": "MIT"},
    openapi_tags=_tags_metadata,
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
app.include_router(tiles.router,        prefix="/api/v1/tiles",    tags=["🗺️ Map Tiles (MVT)"])
app.include_router(recommendations.router)                                        # Prefix router içinde
app.include_router(wind_vectors.router)                                           # Parçacık akış verisi
app.include_router(borders.router)                                                # GADM il/ilçe sınırları

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

    @_stub_geo.get("/city")
    async def geo_stub_city(lat: float, lon: float):
        return {"province": "", "district": ""}

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
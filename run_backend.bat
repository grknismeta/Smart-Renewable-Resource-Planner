@echo off
chcp 65001 > nul
cls

REM ============================================================
REM  COĞRAFYA ANALİZ MOTORU (GeoService — PostGIS-driven, Aşama B)
REM  true  → Aktif (lazy init, ~50 MB RAM, sorgu 5-10ms)
REM  false → Devre dışı (/geo endpoint'leri kapalı)
REM
REM  Eski shape-based 500MB RAM/30sn startup mimarisi emekliye ayrıldı.
REM  Şimdi PostGIS GIST index'leri + lazy GADM cache kullanılıyor.
REM ============================================================
set GEO_ANALYSIS_ENABLED=true
echo.
echo  [92m╔══════════════════════════════════════════════════════════════╗[0m
echo  [92m║   ⚡  Smart Renewable Resource Planner — Backend v2.1.0      ║[0m
echo  [92m╚══════════════════════════════════════════════════════════════╝[0m
echo.
echo  [96m📡 Sunucu adresi .[0m http://localhost:8000
echo  [96m📖 API Dokümantasyonu [0m.. http://localhost:8000/docs
echo  [96m🔍 Redoc .[0m.............. http://localhost:8000/redoc
echo.
echo  [93m⚙  Yapılandırma[0m
if "%GEO_ANALYSIS_ENABLED%"=="true" (
    echo     GEO Analiz Motoru [92m● AKTİF[0m
) else (
    echo     GEO Analiz Motoru [90m○ Devre Dışı[0m
)
echo.
echo  [90m──────────────────────────────────────────────────────────────[0m
echo.
cd backend

REM Proje kokündeki .venv'i aktiflestirir (backend\venv degil, ..\.venv)
if exist ..\.venv\Scripts\activate.bat (
    call ..\.venv\Scripts\activate.bat
) else (
    echo  UYARI: .venv bulunamadi, sistem Python kullaniliyor.
)

REM Dogrudan .venv icindeki uvicorn'u cagir (aktivasyon basarisiz olsa bile)
..\.venv\Scripts\uvicorn.exe app.main:app --reload --host 0.0.0.0
echo.
echo  [91m✖  Sunucu durduruldu.[0m
pause

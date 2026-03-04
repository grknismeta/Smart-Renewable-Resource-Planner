@echo off
chcp 65001 > nul
cls

REM ============================================================
REM  COĞ̈RAFYA ANALİZ MOTORU (GeoService)
REM  true  → Aktif (shapefile yükler, suitability kontrolü yapar)
REM  false → Devre dışı (hızlı başlangıç, /geo endpoint'i kapalı)
REM ============================================================
set GEO_ANALYSIS_ENABLED=false

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
if exist venv\Scripts\activate.bat (
    call venv\Scripts\activate.bat
)
uvicorn app.main:app --reload --host 0.0.0.0
echo.
echo  [91m✖  Sunucu durduruldu.[0m
pause

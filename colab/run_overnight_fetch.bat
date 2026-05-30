@echo off
chcp 65001 >nul
REM ============================================================
REM SRRP — Gece otomatik veri cekme (2026-05-20)
REM ============================================================
REM Open-Meteo gunluk kotasi UTC 00:00'da (TR 03:00) resetlenir.
REM Bu script 04:00'te Windows Zamanlanmis Gorev ile tetiklenir.
REM
REM Her script (A/B/C) 4 kez calistirilir — resume sayesinde her
REM gecis kalan ilceleri toplar. Calistirmalar arasi 3 dk bekleme
REM (Open-Meteo burst korumasi).
REM
REM Sonunda import_colab_csvs.py ile DB'ye yazilir.
REM ============================================================

set REPO=C:\Projelerim\smart_renewable_resource_planner
set LOG=%REPO%\colab\overnight_fetch.log
set PY=%REPO%\backend\venv\Scripts\python.exe

cd /d "%REPO%\colab"

echo === SRRP Overnight Fetch === > "%LOG%"
echo Baslangic: %date% %time% >> "%LOG%"
echo. >> "%LOG%"

echo --- A: wind direction + cloud cover --- >> "%LOG%"
for /L %%i in (1,1,4) do (
  echo [A gecis %%i] %time% >> "%LOG%"
  "%PY%" -X utf8 A_open_meteo_hourly.py >> "%LOG%" 2>&1
  timeout /t 180 /nobreak >nul
)
echo. >> "%LOG%"

echo --- B: precipitation + sunshine --- >> "%LOG%"
for /L %%i in (1,1,4) do (
  echo [B gecis %%i] %time% >> "%LOG%"
  "%PY%" -X utf8 B_open_meteo_daily.py >> "%LOG%" 2>&1
  timeout /t 180 /nobreak >nul
)
echo. >> "%LOG%"

echo --- C: river discharge --- >> "%LOG%"
for /L %%i in (1,1,4) do (
  echo [C gecis %%i] %time% >> "%LOG%"
  "%PY%" -X utf8 C_open_meteo_flood.py >> "%LOG%" 2>&1
  timeout /t 180 /nobreak >nul
)
echo. >> "%LOG%"

echo --- DB Import --- >> "%LOG%"
cd /d "%REPO%\backend"
"%PY%" -X utf8 scripts\import_colab_csvs.py >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo Bitis: %date% %time% >> "%LOG%"
echo === TAMAMLANDI === >> "%LOG%"

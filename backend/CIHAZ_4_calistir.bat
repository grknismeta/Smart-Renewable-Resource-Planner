@echo off
chcp 65001 >nul 2>&1
title SRRP - Cihaz 4

echo ============================================================
echo  SRRP Veri Cekme - CIHAZ 4
echo ============================================================
echo.

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [HATA] Python bulunamadi!
    echo Kurun: https://www.python.org/downloads/
    echo Kurulumda "Add Python to PATH" secin!
    pause & exit /b 1
)

if exist manifest_cihaz_4.json (
    echo Manifest bulundu: manifest_cihaz_4.json
    python srrp_backfill.py --manifest manifest_cihaz_4.json
) else if exist gap_cihaz_4.json (
    echo Gap manifest bulundu: gap_cihaz_4.json
    python srrp_backfill.py --manifest gap_cihaz_4.json
) else (
    echo Manifest yok, shard modu: 4/4
    python srrp_backfill.py --shard 4/4
)

echo.
pause

@echo off
echo Backend baslatiliyor...
cd backend
if exist venv\Scripts\activate.bat (
    call venv\Scripts\activate.bat
)
uvicorn app.main:app --reload --host 0.0.0.0
pause

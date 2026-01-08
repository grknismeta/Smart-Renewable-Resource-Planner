@echo off
echo Backend baslatiliyor...
cd backend
if exist venv\Scripts\activate.bat (
    call venv\Scripts\activate.bat
)
cd app
uvicorn main:app --reload
pause

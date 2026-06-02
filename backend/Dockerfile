FROM python:3.11-slim

# System dependencies for GDAL/GeoPandas/Rasterio
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    gdal-bin \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Python dependencies (context = proje kökü → requirements backend/ altında)
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY backend/ ./backend/

# Kod `from app.db import ...` (mutlak) kullanıyor → `backend/` cwd'sinden
# `app.main` olarak çalıştır (lokaldeki gibi). Aksi halde `app` paketi bulunamaz.
WORKDIR /app/backend

# Run with uvicorn (prod: --reload yok)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

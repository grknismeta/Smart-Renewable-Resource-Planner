"""
Rüzgar Vektör Endpoint'i
========================

Parçacık akış animasyonu için şehir bazlı U/V rüzgar bileşenlerini döner.
Son 24 saatteki ortalama rüzgar hızı ve yönünden hesaplanır.
"""

from fastapi import APIRouter
from sqlalchemy import func
from datetime import datetime, timedelta, timezone
from math import sin, cos, radians

from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData
from app.core.constants import TURKEY_CITIES

router = APIRouter(
    prefix="/wind-vectors",
    tags=["💨 Wind Vectors"],
)


@router.get("")
def get_wind_vectors():
    """
    Son 24 saatteki ortalama rüzgar hızı ve yönünden U/V bileşenlerini hesaplar.

    Open-Meteo rüzgar yönü meteorolojik konvansiyonla verilir:
    direction = rüzgarın GELDİĞİ yön (0° = kuzeyden, 90° = doğudan, …)

    Parçacık animasyonu için rüzgarın GİTTİĞİ yönü hesaplamalıyız:
    U =  -speed × sin(direction_rad)  → doğu bileşeni (pozitif = doğuya)
    V =  -speed × cos(direction_rad)  → kuzey bileşeni (pozitif = kuzeye)

    Örnek: direction=0° (kuzeyden geliyor, güneye gidiyor)
      U = -sin(0) = 0, V = -cos(0) = -1  → bearing=180° (güney) ✓
    """
    db = SystemSessionLocal()
    try:
        cutoff = datetime.now(timezone.utc) - timedelta(days=7)  # 24h yerine 7 gün — veri olmadığında boş dönmesin

        rows = (
            db.query(
                HourlyWeatherData.city_name,
                func.avg(HourlyWeatherData.wind_speed_100m).label("avg_speed"),
                func.avg(HourlyWeatherData.wind_direction_10m).label("avg_dir"),
            )
            .filter(HourlyWeatherData.timestamp >= cutoff)
            .filter(HourlyWeatherData.wind_speed_100m.isnot(None))
            .filter(HourlyWeatherData.wind_direction_10m.isnot(None))
            .group_by(HourlyWeatherData.city_name)
            .all()
        )

        city_lookup = {c["name"]: c for c in TURKEY_CITIES}
        result = []

        for row in rows:
            city_info = city_lookup.get(row.city_name)
            if not city_info:
                continue

            # Open-Meteo varsayılan birimi km/h — m/s'ye çevir (÷ 3.6)
            speed_ms = float(row.avg_speed or 0) / 3.6
            direction = float(row.avg_dir or 0)
            dir_rad = radians(direction)

            u = -speed_ms * sin(dir_rad)
            v = -speed_ms * cos(dir_rad)

            result.append({
                "city": row.city_name,
                "lat": city_info["lat"],
                "lon": city_info["lon"],
                "u": round(u, 3),
                "v": round(v, 3),
                "speed": round(speed_ms, 2),
            })

        return result

    finally:
        db.close()

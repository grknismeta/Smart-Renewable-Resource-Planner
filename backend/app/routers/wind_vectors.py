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

    U = speed × sin(direction)  (doğu-batı bileşeni)
    V = speed × cos(direction)  (kuzey-güney bileşeni)
    """
    db = SystemSessionLocal()
    try:
        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)

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

            speed = float(row.avg_speed or 0)
            direction = float(row.avg_dir or 0)
            dir_rad = radians(direction)

            u = speed * sin(dir_rad)
            v = speed * cos(dir_rad)

            result.append({
                "city": row.city_name,
                "lat": city_info["lat"],
                "lon": city_info["lon"],
                "u": round(u, 3),
                "v": round(v, 3),
                "speed": round(speed, 2),
            })

        return result

    finally:
        db.close()

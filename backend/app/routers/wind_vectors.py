"""
Rüzgar Vektör Endpoint'i
========================

Parçacık akış animasyonu için U/V rüzgar bileşenlerini döner.
İki mod: il bazlı (81 nokta) ve ilçe bazlı yoğun (~1000 nokta).
"""

from fastapi import APIRouter, Query
from sqlalchemy import func
from datetime import datetime, timedelta, timezone
from math import sin, cos, radians, sqrt

from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData
from app.core.constants import TURKEY_CITIES

router = APIRouter(
    prefix="/wind-vectors",
    tags=["💨 Wind Vectors"],
)


def _compute_uv(speed_ms: float, direction: float):
    """Meteorolojik yön → U/V bileşenleri (rüzgarın GİTTİĞİ yön)."""
    dir_rad = radians(direction)
    u = -speed_ms * sin(dir_rad)
    v = -speed_ms * cos(dir_rad)
    return round(u, 3), round(v, 3)


@router.get("")
def get_wind_vectors(dense: bool = Query(False, description="True = ilçe bazlı yoğun veri (~1000 nokta)")):
    """
    Rüzgar akış animasyonu için U/V bileşenlerini hesaplar.

    - dense=false (varsayılan): İl bazlı ~81 nokta
    - dense=true: İlçe bazlı ~1000 nokta (konum koordinatları DB'den)

    Open-Meteo rüzgar yönü meteorolojik konvansiyonla verilir:
    direction = rüzgarın GELDİĞİ yön (0° = kuzeyden, 90° = doğudan)

    U =  -speed × sin(dir)  → doğu bileşeni
    V =  -speed × cos(dir)  → kuzey bileşeni
    """
    db = SystemSessionLocal()
    try:
        cutoff_fresh = datetime.now(timezone.utc) - timedelta(hours=48)
        cutoff_fallback = datetime.now(timezone.utc) - timedelta(days=7)

        if dense:
            # ── İlçe bazlı yoğun veri ──
            # location_code + lat/lon bazında grupla → ~1000 nokta
            rows = _query_dense(db, cutoff_fresh)
            if len(rows) < 50:
                rows = _query_dense(db, cutoff_fallback)
            return _build_dense_result(rows)
        else:
            # ── İl bazlı (eski davranış) ──
            rows = _query_city(db, cutoff_fresh)
            if len(rows) < 20:
                rows = _query_city(db, cutoff_fallback)
            return _build_city_result(rows)

    finally:
        db.close()


def _query_city(db, cutoff):
    return (
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


def _query_dense(db, cutoff):
    """İlçe bazlı: location_code + koordinat gruplu."""
    return (
        db.query(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
            func.avg(HourlyWeatherData.latitude).label("lat"),
            func.avg(HourlyWeatherData.longitude).label("lon"),
            func.avg(HourlyWeatherData.wind_speed_100m).label("avg_speed"),
            func.avg(HourlyWeatherData.wind_direction_10m).label("avg_dir"),
        )
        .filter(HourlyWeatherData.timestamp >= cutoff)
        .filter(HourlyWeatherData.wind_speed_100m.isnot(None))
        .filter(HourlyWeatherData.wind_direction_10m.isnot(None))
        .group_by(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
        )
        .all()
    )


def _build_city_result(rows):
    city_lookup = {c["name"]: c for c in TURKEY_CITIES}
    result = []
    for row in rows:
        city_info = city_lookup.get(row.city_name)
        if not city_info:
            continue
        speed_ms = float(row.avg_speed or 0)
        direction = float(row.avg_dir or 0)
        u, v = _compute_uv(speed_ms, direction)
        result.append({
            "city": row.city_name,
            "lat": city_info["lat"],
            "lon": city_info["lon"],
            "u": u, "v": v,
            "speed": round(speed_ms, 2),
        })
    return result


def _build_dense_result(rows):
    result = []
    for row in rows:
        lat = float(row.lat or 0)
        lon = float(row.lon or 0)
        if lat == 0 or lon == 0:
            continue
        speed_ms = float(row.avg_speed or 0)
        direction = float(row.avg_dir or 0)
        u, v = _compute_uv(speed_ms, direction)
        label = row.district_name or row.city_name or ""
        result.append({
            "city": label,
            "lat": round(lat, 4),
            "lon": round(lon, 4),
            "u": u, "v": v,
            "speed": round(speed_ms, 2),
        })
    return result

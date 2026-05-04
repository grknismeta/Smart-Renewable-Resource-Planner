"""
Rüzgar Vektör Endpoint'i
========================

Parçacık akış animasyonu için U/V rüzgar bileşenlerini döner.
İki mod: il bazlı (81 nokta) ve ilçe bazlı yoğun (~1000 nokta).

Zaman penceresi (``mode``/``season``) tematik harita katmanlarıyla ortak
(ortak helper: ``app.core.time_window``).

- ``current`` (default)           : son 48 saat taze + 7 gün fallback (anlık)
- ``yearly``                      : son 365 gün (iklimsel ortalama)
- ``season`` + ``season=winter.`` : son 365 gün + mevsim ay filtresi
"""

from fastapi import APIRouter, Query
from sqlalchemy import func, extract
from datetime import datetime, timedelta, timezone
from math import sin, cos, radians

from app.db.database import SystemSessionLocal
from app.db.models import HourlyWeatherData
from app.core.constants import TURKEY_CITIES
from app.core.time_window import resolve_time_window

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
def get_wind_vectors(
    dense: bool = Query(False, description="True = ilçe bazlı yoğun veri (~1000 nokta)"),
    mode: str = Query(
        "current",
        regex="^(current|week|month|threeMonth|sixMonth|yearly|season)$",
        description=(
            "Zaman penceresi: current (anlık 48h fresh+7d fallback) | "
            "week (7g) | month (30g) | threeMonth (90g) | sixMonth (180g) | "
            "yearly (365g) | season (365g + ay filtresi)"
        ),
    ),
    season: str | None = Query(
        None,
        regex="^(winter|spring|summer|autumn)$",
        description="mode=season için zorunlu",
    ),
):
    """
    Rüzgar akış animasyonu için U/V bileşenlerini hesaplar.

    - ``dense=false`` (varsayılan): İl bazlı ~81 nokta
    - ``dense=true``: İlçe bazlı ~1000 nokta

    Open-Meteo rüzgar yönü meteorolojik konvansiyonla verilir:
    direction = rüzgarın GELDİĞİ yön (0° = kuzeyden, 90° = doğudan)

    U =  -speed × sin(dir)  → doğu bileşeni
    V =  -speed × cos(dir)  → kuzey bileşeni

    Not: yearly/season modunda speed ve direction ayrı ayrı ortalanır.
    Uzun pencerede yönün skaler ortalaması tam doğru değil (doğrusu
    u/v bileşenlerinin ortalaması), ama grafik amaçlı yeterli.
    """
    db = SystemSessionLocal()
    try:
        if mode == "current":
            cutoff_fresh = datetime.now(timezone.utc) - timedelta(hours=48)
            cutoff_fallback = datetime.now(timezone.utc) - timedelta(days=7)
            filters_fresh = [HourlyWeatherData.timestamp >= cutoff_fresh]
            filters_fallback = [HourlyWeatherData.timestamp >= cutoff_fallback]

            if dense:
                rows = _query_dense(db, filters_fresh)
                if len(rows) < 50:
                    rows = _query_dense(db, filters_fallback)
                return _build_dense_result(rows)
            else:
                rows = _query_city(db, filters_fresh)
                if len(rows) < 20:
                    rows = _query_city(db, filters_fallback)
                return _build_city_result(rows)

        # yearly / season — 365 günlük pencere + opsiyonel ay filtresi
        tw = resolve_time_window(mode, season)
        filters = [
            HourlyWeatherData.timestamp >= tw.start,
            HourlyWeatherData.timestamp <= tw.end,
        ]
        if tw.months:
            filters.append(extract("month", HourlyWeatherData.timestamp).in_(tw.months))

        if dense:
            rows = _query_dense(db, filters)
            return _build_dense_result(rows)
        else:
            rows = _query_city(db, filters)
            return _build_city_result(rows)

    finally:
        db.close()


def _query_city(db, filters):
    q = db.query(
        HourlyWeatherData.city_name,
        func.avg(HourlyWeatherData.wind_speed_100m).label("avg_speed"),
        func.avg(HourlyWeatherData.wind_direction_10m).label("avg_dir"),
    ).filter(
        HourlyWeatherData.wind_speed_100m.isnot(None),
        HourlyWeatherData.wind_direction_10m.isnot(None),
    )
    for f in filters:
        q = q.filter(f)
    return q.group_by(HourlyWeatherData.city_name).all()


def _query_dense(db, filters):
    """İlçe bazlı: location_code + koordinat gruplu."""
    q = db.query(
        HourlyWeatherData.city_name,
        HourlyWeatherData.district_name,
        func.avg(HourlyWeatherData.latitude).label("lat"),
        func.avg(HourlyWeatherData.longitude).label("lon"),
        func.avg(HourlyWeatherData.wind_speed_100m).label("avg_speed"),
        func.avg(HourlyWeatherData.wind_direction_10m).label("avg_dir"),
    ).filter(
        HourlyWeatherData.wind_speed_100m.isnot(None),
        HourlyWeatherData.wind_direction_10m.isnot(None),
    )
    for f in filters:
        q = q.filter(f)
    return q.group_by(
        HourlyWeatherData.city_name,
        HourlyWeatherData.district_name,
    ).all()


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

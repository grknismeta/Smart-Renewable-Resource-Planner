"""
SRRP v2.1 — Saatlik Hava Verisi Helper
========================================
Pin hesaplamaları için HourlyWeatherData tablosundan
gerçek saatlik veri çeker.
"""

from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from app.db.models import HourlyWeatherData


def get_hourly_weather_for_pin(
    system_db: Session,
    latitude: float,
    longitude: float,
    days: int = 365,
) -> Dict[str, Any]:
    """
    Verilen koordinata en yakın noktanın saatlik hava verilerini çeker.

    HourlyWeatherData tablosunda her kayıt bir il/ilçe merkezinin
    saatlik değeridir. Pin koordinatına en yakın kaydı bulur ve
    son `days` gün içindeki tüm saatlik verileri döner.

    Returns:
        {
            "city_name": str,
            "district_name": str | None,
            "hours": [
                {
                    "ts": datetime,
                    "ghi_wm2": float,        # shortwave_radiation (W/m²)
                    "wind10_ms": float,       # wind_speed_10m (m/s)
                    "wind100_ms": float,      # wind_speed_100m (m/s)
                    "temp_c": float,          # temperature_2m (°C)
                    "precip_mm": float,       # precipitation (mm)
                    "cloud_pct": float,       # cloud_cover (%)
                }, ...
            ],
            "count": int,
            "date_range": (min_ts, max_ts),
        }
    """
    cutoff = datetime.utcnow() - timedelta(days=days)

    # ── 1. En yakın noktayı bul ──────────────────────────────────────
    # Son kaydı referans alarak en yakın lat/lon eşleşmesini bul.
    # Karesel mesafe yeterli (Türkiye ölçeğinde cos düzeltmesine gerek yok).
    nearest = (
        system_db.query(
            HourlyWeatherData.city_name,
            HourlyWeatherData.district_name,
            HourlyWeatherData.latitude,
            HourlyWeatherData.longitude,
        )
        .filter(HourlyWeatherData.timestamp >= cutoff)
        .order_by(
            (
                func.pow(HourlyWeatherData.latitude - latitude, 2)
                + func.pow(HourlyWeatherData.longitude - longitude, 2)
            )
        )
        .limit(1)
        .first()
    )

    if nearest is None:
        return {"hours": [], "count": 0, "error": "Yakın veri noktası bulunamadı"}

    city = nearest.city_name
    district = nearest.district_name
    near_lat = nearest.latitude
    near_lon = nearest.longitude

    # ── 2. Saatlik verileri çek ──────────────────────────────────────
    rows = (
        system_db.query(
            HourlyWeatherData.timestamp,
            HourlyWeatherData.shortwave_radiation,
            HourlyWeatherData.wind_speed_10m,
            HourlyWeatherData.wind_speed_100m,
            HourlyWeatherData.temperature_2m,
            HourlyWeatherData.precipitation,
            HourlyWeatherData.cloud_cover,
        )
        .filter(
            and_(
                HourlyWeatherData.latitude == near_lat,
                HourlyWeatherData.longitude == near_lon,
                HourlyWeatherData.timestamp >= cutoff,
            )
        )
        .order_by(HourlyWeatherData.timestamp)
        .all()
    )

    hours: List[Dict[str, Any]] = []
    for r in rows:
        hours.append({
            "ts": r.timestamp,
            "ghi_wm2": float(r.shortwave_radiation or 0.0),
            "wind10_ms": float(r.wind_speed_10m or 0.0),
            "wind100_ms": float(r.wind_speed_100m or 0.0),
            "temp_c": float(r.temperature_2m or 0.0),
            "precip_mm": float(r.precipitation or 0.0),
            "cloud_pct": float(r.cloud_cover or 0.0),
        })

    date_range = (hours[0]["ts"], hours[-1]["ts"]) if hours else (None, None)

    return {
        "city_name": city,
        "district_name": district,
        "hours": hours,
        "count": len(hours),
        "date_range": date_range,
    }


def aggregate_hourly_to_monthly(
    hours: List[Dict[str, Any]],
) -> Dict[int, Dict[str, Any]]:
    """
    Saatlik veri listesini aylık toplamlar / ortalamalar şeklinde gruplar.

    Returns:
        {
            1: {"ghi_sum_wh": ..., "wind_avg_ms": ..., "temp_avg_c": ...,
                "precip_sum_mm": ..., "hour_count": ...},
            ...
        }
    """
    monthly: Dict[int, Dict[str, float]] = {}

    for h in hours:
        ts: datetime = h["ts"]
        m = ts.month
        if m not in monthly:
            monthly[m] = {
                "ghi_sum_wh": 0.0,
                "wind_sum_ms": 0.0,
                "wind100_sum_ms": 0.0,
                "temp_sum_c": 0.0,
                "precip_sum_mm": 0.0,
                "hour_count": 0,
            }
        bucket = monthly[m]
        # shortwave_radiation W/m² × 1 saat = Wh/m²
        bucket["ghi_sum_wh"] += h["ghi_wm2"]
        bucket["wind_sum_ms"] += h["wind10_ms"]
        bucket["wind100_sum_ms"] += h["wind100_ms"]
        bucket["temp_sum_c"] += h["temp_c"]
        bucket["precip_sum_mm"] += h["precip_mm"]
        bucket["hour_count"] += 1

    result: Dict[int, Dict[str, Any]] = {}
    for m, b in monthly.items():
        n = b["hour_count"] or 1
        result[m] = {
            "ghi_sum_wh": b["ghi_sum_wh"],       # Toplam Wh/m²
            "ghi_sum_kwh": b["ghi_sum_wh"] / 1000.0,  # Toplam kWh/m²
            "wind_avg_ms": b["wind_sum_ms"] / n,
            "wind100_avg_ms": b["wind100_sum_ms"] / n,
            "temp_avg_c": b["temp_sum_c"] / n,
            "precip_sum_mm": b["precip_sum_mm"],
            "hour_count": b["hour_count"],
        }

    return result

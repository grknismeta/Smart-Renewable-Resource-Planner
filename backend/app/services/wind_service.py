"""
SRRP v2.1 — Rüzgar Enerjisi Hesaplama Servisi
================================================
Gerçek saatlik rüzgar hızı verileriyle yıllık rüzgar enerjisi üretim tahmini.

Her saat için türbin güç eğrisinden anlık güç (kW) hesaplanır,
saatlik güçlerin toplamı yıllık enerji üretimini (kWh) verir.
Ortalama hız × 8760 saat yöntemi kullanılmaz.
"""

import math
from typing import Dict, Any, List, Union
from datetime import datetime


# ── Standart Türbin Güç Eğrisi (3.3 MW) ──────────────────────────────────────
# Rüzgar Hızı (m/s) → Güç Çıkışı (kW)
EXAMPLE_TURBINE_POWER_CURVE: Dict[Union[int, float], Union[int, float]] = {
    0: 0, 1: 0, 2: 0,
    3: 50, 4: 150, 5: 350, 6: 600, 7: 950, 8: 1400,
    9: 1900, 10: 2300, 11: 2700,
    12: 3000, 13: 3200, 14: 3300, 25: 3300, 30: 0,
}

# Türkçe ay isimleri
MONTH_NAMES_TR = [
    "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
    "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
]


def get_power_from_curve(
    wind_speed: float,
    curve: Dict[Union[int, float], Union[int, float]] = None,
) -> float:
    """
    Verilen rüzgar hızında türbinin ne kadar güç (kW) üreteceğini hesaplar.
    Ara değerler için lineer interpolasyon yapar.
    """
    if curve is None:
        curve = EXAMPLE_TURBINE_POWER_CURVE

    speeds = sorted(curve.keys())

    if wind_speed < speeds[0] or wind_speed > speeds[-1]:
        return 0.0

    if wind_speed in curve:
        return float(curve[wind_speed])

    lower = max([s for s in speeds if s <= wind_speed], default=0)
    upper = min([s for s in speeds if s >= wind_speed], default=max(speeds))

    if lower == upper:
        return float(curve[lower])

    p_lower = curve[lower]
    p_upper = curve[upper]
    ratio = (wind_speed - lower) / (upper - lower)
    return float(p_lower + ratio * (p_upper - p_lower))


def calculate_wind_from_hourly(
    hourly_data: List[Dict[str, Any]],
    use_100m: bool = True,
    power_curve: Dict[Union[int, float], Union[int, float]] = None,
) -> Dict[str, Any]:
    """
    Gerçek saatlik rüzgar hızı verilerinden yıllık rüzgar enerjisi üretim hesabı.

    Her saat için:
        1. Rüzgar hızını al (tercihen 100m, yoksa 10m)
        2. Güç eğrisinden anlık kW değerini hesapla
        3. 1 saat × kW = kWh olarak topla

    Args:
        hourly_data: hourly_weather_helper'dan gelen saatlik veri listesi
            [{"ts": datetime, "wind10_ms": float, "wind100_ms": float, ...}, ...]
        use_100m: 100m rüzgar hızını kullan (türbin hub yüksekliği)
        power_curve: Özel güç eğrisi (None ise 3.3 MW varsayılan)

    Returns:
        {
            "predicted_annual_production_kwh": float,
            "avg_wind_speed_ms": float,
            "capacity_factor": float,
            "month_by_month_prediction": {"Ocak": ..., ...},
            "hours_used": int,
            "data_period_days": int,
            "method": "hourly_real_data"
        }
    """
    if power_curve is None:
        power_curve = EXAMPLE_TURBINE_POWER_CURVE

    if not hourly_data:
        return {
            "predicted_annual_production_kwh": 0,
            "avg_wind_speed_ms": 0,
            "capacity_factor": 0,
            "month_by_month_prediction": {},
            "hours_used": 0,
            "method": "no_data",
            "error": "Saatlik veri bulunamadı",
        }

    # ── Saatlik güç hesabı ───────────────────────────────────────────
    monthly_kwh: Dict[int, float] = {}
    monthly_hours: Dict[int, int] = {}
    monthly_wind_sum: Dict[int, float] = {}
    total_production_kwh = 0.0
    total_wind_sum = 0.0
    valid_hours = 0

    for h in hourly_data:
        wind = h.get("wind100_ms", 0.0) if use_100m else h.get("wind10_ms", 0.0)
        wind = wind or 0.0
        ts: datetime = h["ts"]
        month = ts.month

        # Güç eğrisinden anlık güç (kW)
        power_kw = get_power_from_curve(wind, power_curve)

        # 1 saat × kW = kWh
        hour_kwh = power_kw  # power_kw × 1h = kWh

        total_production_kwh += hour_kwh
        total_wind_sum += wind
        valid_hours += 1

        monthly_kwh[month] = monthly_kwh.get(month, 0.0) + hour_kwh
        monthly_hours[month] = monthly_hours.get(month, 0) + 1
        monthly_wind_sum[month] = monthly_wind_sum.get(month, 0.0) + wind

    # ── Veri dönemi ve yıllık ölçekleme ──────────────────────────────
    if hourly_data:
        ts_min = hourly_data[0]["ts"]
        ts_max = hourly_data[-1]["ts"]
        data_days = max((ts_max - ts_min).days, 1)
    else:
        data_days = 1

    scale_factor = 365.0 / data_days if data_days < 365 else 1.0
    annual_production = total_production_kwh * scale_factor

    # Ortalama rüzgar hızı
    avg_wind = total_wind_sum / valid_hours if valid_hours > 0 else 0.0

    # Kapasite faktörü
    rated_power_kw = max(power_curve.values())
    capacity_factor = 0.0
    if rated_power_kw > 0:
        capacity_factor = annual_production / (float(rated_power_kw) * 8760)
        capacity_factor = min(capacity_factor, 0.70)  # Fiziksel üst sınır

    # ── Aylık kırılım ────────────────────────────────────────────────
    month_by_month: Dict[str, float] = {}
    for i in range(12):
        m = i + 1
        if m in monthly_kwh:
            expected_hours = [744, 672, 744, 720, 744, 720,
                              744, 744, 720, 744, 720, 744][i]
            actual_hours = monthly_hours.get(m, expected_hours)
            ratio = expected_hours / actual_hours if actual_hours > 0 else 1.0
            ratio = min(ratio, 2.0)
            month_by_month[MONTH_NAMES_TR[i]] = round(monthly_kwh[m] * ratio, 2)
        else:
            month_by_month[MONTH_NAMES_TR[i]] = round(annual_production / 12, 2)

    return {
        "predicted_annual_production_kwh": round(annual_production, 0),
        "avg_wind_speed_ms": round(avg_wind, 2),
        "capacity_factor": round(capacity_factor, 3),
        "month_by_month_prediction": month_by_month,
        "hours_used": valid_hours,
        "data_period_days": data_days,
        "method": "hourly_real_data",
    }


# ── Legacy uyumluluk ─────────────────────────────────────────────────────────

def calculate_wind_power_production(
    latitude: float,
    longitude: float,
    weather_stats: Dict[str, Any] = None,  # type: ignore
    hourly_data: List[Dict[str, Any]] = None,  # type: ignore
) -> Dict[str, Any]:
    """
    Backward-compatible wrapper.
    Eğer hourly_data varsa gerçek saatlik hesaplama yapar,
    yoksa eski weather_stats fallback'ine düşer.
    """
    # Yeni yol: gerçek saatlik veri
    if hourly_data and len(hourly_data) > 100:
        result = calculate_wind_from_hourly(hourly_data=hourly_data)
        return result

    # Eski yol: weather_stats ile ortalama tabanlı (fallback)
    if weather_stats and "annual_avg" in weather_stats and weather_stats["annual_avg"].get("wind") is not None:
        avg_speed = weather_stats["annual_avg"]["wind"]
    else:
        print(f"Uyari: ({latitude}, {longitude}) icin ruzgar verisi yok. Varsayilan kullaniliyor.")
        avg_speed = 6.0

    base_power_kw = get_power_from_curve(avg_speed)
    variability_factor = 1.6 if avg_speed < 8 else 1.2
    predicted_avg_power_kw = base_power_kw * variability_factor
    annual_production = predicted_avg_power_kw * 8760

    rated_power = max(EXAMPLE_TURBINE_POWER_CURVE.values())
    capacity_factor = 0
    if rated_power > 0:
        capacity_factor = annual_production / (rated_power * 8760)
    if capacity_factor > 0.55:
        capacity_factor = 0.55
        annual_production = rated_power * 8760 * 0.55

    return {
        "avg_wind_speed_ms": round(avg_speed, 2),
        "predicted_annual_production_kwh": round(annual_production, 0),
        "capacity_factor": round(capacity_factor, 3),
        "method": "legacy_grid_avg",
    }


# ── Uyumluluk Fonksiyonu ─────────────────────────────────────────────────────
def get_wind_speed_from_coordinates(lat, lon):
    return 6.0

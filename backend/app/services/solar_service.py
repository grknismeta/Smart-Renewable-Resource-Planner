"""
SRRP v2.1 — Güneş Enerjisi Hesaplama Servisi
===============================================
Gerçek saatlik GHI verileriyle yıllık güneş enerjisi üretim tahmini.

Formül (saatlik):
    E_hour = GHI(W/m²) × A × η × PR / 1000  →  kWh

GHI her saat için Wh/m² olarak değerlendirilir (1 saat × W/m² = Wh/m²).
Yıllık toplam tüm saatlerin basit toplamıdır — ortalama ya da tahmin yok.
"""

from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
import requests


# ── Türkçe ay isimleri ────────────────────────────────────────────────────────
MONTH_NAMES_TR = [
    "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
    "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
]


def _temperature_correction(temp_c: float, noct: float = 45.0) -> float:
    """
    Hücre sıcaklığına göre verim düzeltme katsayısı.
    PV paneller 25 °C üzerinde her derece için ~%0.4 verim kaybeder.

    NOCT (Nominal Operating Cell Temperature): Tipik değer 45°C.
    Hücre sıcaklığı = ortam + (NOCT - 20) × (G / 800)
    Basitleştirme: referans ışınım 800 W/m² varsayılır → t_cell ≈ temp_c + (NOCT - 20)
    """
    t_cell = temp_c + (noct - 20)  # NOCT=45 → temp_c + 25
    loss_per_degree = 0.004  # %0.4/°C
    delta = t_cell - 25.0
    factor = 1.0 - (delta * loss_per_degree)
    return max(factor, 0.5)  # Minimum %50 verim


def calculate_solar_from_hourly(
    hourly_data: List[Dict[str, Any]],
    panel_area: float = 10.0,
    panel_efficiency: float = 0.20,
    performance_ratio: float = 0.80,
    apply_temp_correction: bool = True,
) -> Dict[str, Any]:
    """
    Gerçek saatlik GHI verilerinden yıllık güneş enerjisi üretim hesabı.

    Args:
        hourly_data: hourly_weather_helper'dan gelen saatlik veri listesi
            [{"ts": datetime, "ghi_wm2": float, "temp_c": float, ...}, ...]
        panel_area: Panel alanı (m²)
        panel_efficiency: Panel verimi (0-1)
        performance_ratio: Sistem kayıp oranı (kablo, inverter, toz vb.)
        apply_temp_correction: Sıcaklık düzeltmesi uygulansın mı

    Returns:
        {
            "predicted_annual_production_kwh": float,
            "daily_avg_potential_kwh_m2": float,
            "month_by_month_prediction": {"Ocak": ..., ...},
            "total_ghi_kwh_m2": float,
            "hours_used": int,
            "data_period_days": int,
            "method": "hourly_real_data"
        }
    """
    if not hourly_data:
        return {
            "predicted_annual_production_kwh": 0,
            "daily_avg_potential_kwh_m2": 0,
            "month_by_month_prediction": {},
            "hours_used": 0,
            "method": "no_data",
            "error": "Saatlik veri bulunamadı",
        }

    # ── Saatlik üretim hesabı ────────────────────────────────────────
    monthly_kwh: Dict[int, float] = {}
    monthly_ghi_wh: Dict[int, float] = {}
    monthly_hours: Dict[int, int] = {}
    total_production_kwh = 0.0
    total_ghi_wh = 0.0

    for h in hourly_data:
        ghi = h.get("ghi_wm2", 0.0) or 0.0
        if ghi <= 0:
            continue

        temp = h.get("temp_c", 25.0) or 25.0
        ts: datetime = h["ts"]
        month = ts.month

        # Sıcaklık düzeltmesi
        temp_factor = _temperature_correction(temp) if apply_temp_correction else 1.0

        # Saatlik üretim: GHI(W/m²) × 1h = Wh/m²
        # E_hour = (GHI_Wh/m² × A × η × PR × temp_factor) / 1000 → kWh
        hour_kwh = (ghi * panel_area * panel_efficiency * performance_ratio * temp_factor) / 1000.0

        total_production_kwh += hour_kwh
        total_ghi_wh += ghi

        monthly_kwh[month] = monthly_kwh.get(month, 0.0) + hour_kwh
        monthly_ghi_wh[month] = monthly_ghi_wh.get(month, 0.0) + ghi
        monthly_hours[month] = monthly_hours.get(month, 0) + 1

    # ── Veri dönemi ve yıllık ölçekleme ──────────────────────────────
    if hourly_data:
        ts_min = hourly_data[0]["ts"]
        ts_max = hourly_data[-1]["ts"]
        data_days = max((ts_max - ts_min).days, 1)
    else:
        data_days = 1

    # Eğer veri 365 günden azsa, yıllık değere oranla
    scale_factor = 365.0 / data_days if data_days < 365 else 1.0
    annual_production = total_production_kwh * scale_factor

    # Günlük ortalama GHI (kWh/m²)
    total_ghi_kwh_m2 = total_ghi_wh / 1000.0
    daily_avg_ghi = total_ghi_kwh_m2 / data_days

    # ── Aylık kırılım ────────────────────────────────────────────────
    month_by_month: Dict[str, float] = {}
    for i in range(12):
        m = i + 1
        if m in monthly_kwh:
            # Eğer o ay kısmen veriliyse (örneğin Mart ayından sadece 15 gün),
            # aylık değeri ölçekle
            expected_hours = [744, 672, 744, 720, 744, 720,
                              744, 744, 720, 744, 720, 744][i]
            actual_hours = monthly_hours.get(m, expected_hours)
            ratio = expected_hours / actual_hours if actual_hours > 0 else 1.0
            # Çok büyük ölçeklemeyi engelle (en fazla ×2)
            ratio = min(ratio, 2.0)
            month_by_month[MONTH_NAMES_TR[i]] = round(monthly_kwh[m] * ratio, 2)
        else:
            # Veri olmayan aylar için yıllık ortalamanın 1/12'si
            month_by_month[MONTH_NAMES_TR[i]] = round(annual_production / 12, 2)

    return {
        "predicted_annual_production_kwh": round(annual_production, 2),
        "daily_avg_potential_kwh_m2": round(daily_avg_ghi, 2),
        "month_by_month_prediction": month_by_month,
        "total_ghi_kwh_m2": round(total_ghi_kwh_m2, 2),
        "hours_used": len(hourly_data),
        "data_period_days": data_days,
        "method": "hourly_real_data",
    }


# ── Legacy uyumluluk ─────────────────────────────────────────────────────────
# Eski weather_stats formatıyla çağrıldığında düşük-kalite fallback

def calculate_solar_power_production(
    latitude: float,
    longitude: float,
    panel_area: float,
    panel_efficiency: float = 0.20,
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
        return calculate_solar_from_hourly(
            hourly_data=hourly_data,
            panel_area=panel_area,
            panel_efficiency=panel_efficiency,
        )

    # Eski yol: weather_stats ile ortalama tabanlı (fallback)
    if weather_stats and "annual_avg" in weather_stats and weather_stats["annual_avg"].get("solar") is not None:
        daily_irradiance_mj = weather_stats["annual_avg"]["solar"]
        daily_irradiance_kwh = daily_irradiance_mj / 3.6
        monthly_distribution = weather_stats.get("monthly", {})
    else:
        print(f"Uyari: ({latitude}, {longitude}) icin DB verisi yok. Tahmini hesap yapiliyor.")
        daily_irradiance_kwh = 5.5 - ((latitude - 36) * 0.2)
        monthly_distribution = None

    PR = 0.80
    daily_production = daily_irradiance_kwh * panel_area * panel_efficiency * PR
    annual_production = daily_production * 365

    month_names = MONTH_NAMES_TR
    monthly_preds: Dict[str, float] = {}

    if monthly_distribution:
        sorted_months = sorted(monthly_distribution.keys())
        for i, m_code in enumerate(sorted_months):
            if i >= 12:
                break
            m_stats = monthly_distribution[m_code]
            if m_stats.get("solar"):
                m_rad_kwh = m_stats["solar"] / 3.6
                m_prod = m_rad_kwh * panel_area * panel_efficiency * PR * 30.4
                monthly_preds[month_names[int(m_code) - 1]] = round(m_prod, 2)
            else:
                monthly_preds[month_names[int(m_code) - 1]] = 0
        for m in month_names:
            if m not in monthly_preds:
                monthly_preds[m] = round(annual_production / 12, 2)
    else:
        for i, m in enumerate(month_names):
            weight = 1 + (0.4 * (1 if 2 < i < 8 else -1))
            monthly_preds[m] = round((annual_production / 12) * weight, 2)

    return {
        "daily_avg_potential_kwh_m2": round(daily_irradiance_kwh, 2),
        "predicted_annual_production_kwh": round(annual_production, 2),
        "month_by_month_prediction": monthly_preds,
        "method": "legacy_grid_avg",
    }


def get_historical_hourly_solar_data(latitude: float, longitude: float) -> Dict[str, Any]:
    """
    Open-Meteo Archive API'den son ~1 yilin saatlik gunes ve hava verilerini ceker.
    (Legacy: Dis API cagrisi — yeni hesaplamalar icin kullanilmiyor.)
    """
    end_date = datetime.now() - timedelta(days=5)
    start_date = end_date - timedelta(days=365)
    str_start = start_date.strftime("%Y-%m-%d")
    str_end = end_date.strftime("%Y-%m-%d")

    base_url = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": str_start,
        "end_date": str_end,
        "hourly": "shortwave_radiation,direct_normal_irradiance,diffuse_radiation,temperature_2m,cloud_cover",
        "timezone": "auto",
    }

    try:
        resp = requests.get(base_url, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        hourly = data.get("hourly", {})
        time_list = hourly.get("time", [])
        ghi_list = hourly.get("shortwave_radiation", [])
        temp_list = hourly.get("temperature_2m", [])
        cloud_list = hourly.get("cloud_cover", [])

        if not ghi_list:
            return {"error": "Bos veri"}

        valid_ghi = [x for x in ghi_list if x is not None]
        total_annual_ghi_wh = sum(valid_ghi)
        total_annual_ghi_kwh = total_annual_ghi_wh / 1000.0
        daily_avg_kwh = total_annual_ghi_kwh / 365.0

        monthly_data: Dict[str, Dict[str, float]] = {}
        for i, t in enumerate(time_list):
            if i >= len(ghi_list):
                break
            ghi = ghi_list[i]
            if ghi is None:
                continue
            month = str(t).split("-")[1]
            m = monthly_data.setdefault(month, {"sum_ghi": 0.0, "sum_temp": 0.0, "avg_cloud": 0.0, "count": 0.0})
            m["sum_ghi"] += float(ghi)
            m["sum_temp"] += float(temp_list[i] or 0.0) if i < len(temp_list) else 0.0
            m["avg_cloud"] += float(cloud_list[i] or 0.0) if i < len(cloud_list) else 0.0
            m["count"] += 1.0

        monthly_stats = []
        for month in sorted(monthly_data.keys()):
            stats = monthly_data[month]
            count = stats["count"] or 1.0
            monthly_stats.append({
                "month": int(month),
                "total_production_kwh_m2": round(stats["sum_ghi"] / 1000.0, 2),
                "avg_temperature_c": round(stats["sum_temp"] / count, 1),
                "avg_cloud_cover": round(stats["avg_cloud"] / count, 1),
            })

        return {
            "annual_total_ghi_kwh": total_annual_ghi_kwh,
            "daily_avg_kwh": daily_avg_kwh,
            "monthly_stats": monthly_stats,
            "hourly_data_count": len(time_list),
        }
    except requests.RequestException as e:
        return {"error": f"API Hatasi: {e}"}

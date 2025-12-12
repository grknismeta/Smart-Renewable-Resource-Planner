import requests # <-- IMPORT EKLENDİ
import statistics
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any

# --- YENİ IMPORT ---
from .ml_predictor import predict_future_production 
# -------------------

STC_TEMPERATURE = 25.0
EXAMPLE_PANEL_SPECS = {
    "model_name": "Standart 400W Panel",
    "power_rating_w": 400,
    "dimensions_m": {"length": 2.0, "width": 1.0},
    "base_efficiency": 0.20,
    "temp_coefficient": -0.005,
    "is_default": True
}

def get_historical_hourly_solar_data(latitude: float, longitude: float) -> Dict[str, Any]:
    """
    Open-Meteo Archive API'den veri çeker VE ML ile gelecek tahmini yapar.
    """
    # 1. Tarih Aralığı (10 YILLIK GENİŞ VERİ SETİ)
    end_date = datetime.now() - timedelta(days=5) 
    days_to_fetch = 3650 # 10 Yıl
    start_date = end_date - timedelta(days=days_to_fetch)
    
    str_start = start_date.strftime("%Y-%m-%d")
    str_end = end_date.strftime("%Y-%m-%d")
    
    print(f"--- VERİ ÇEKİLİYOR (10 Yıllık) ---")
    print(f"Aralık: {str_start} - {str_end}")
    
    BASE_URL = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": str_start,
        "end_date": str_end,
        "hourly": "shortwave_radiation,temperature_2m", 
        "timezone": "auto"
    }

    try:
        response = requests.get(BASE_URL, params=params)
        response.raise_for_status() # <-- Hata kodunu yakalamak için kritik satır
        data = response.json()
        
        hourly = data.get("hourly", {})
        time_list = hourly.get("time", [])
        ghi_list = hourly.get("shortwave_radiation", []) # W/m²
        temp_list = hourly.get("temperature_2m", []) # °C
        
        if not ghi_list:
            return {"error": "Boş veri"}

        # --- 1. GEÇMİŞ VERİ ANALİZİ (NORMALİZASYON) ---
        valid_ghi = [x for x in ghi_list if x is not None]
        total_fetched_ghi_kwh = sum(valid_ghi) / 1000.0
        
        actual_days_fetched = len(time_list) / 24.0
        if actual_days_fetched > 0:
            daily_avg_kwh = total_fetched_ghi_kwh / actual_days_fetched
        else:
            daily_avg_kwh = 0.0
        
        annual_avg_ghi_kwh = daily_avg_kwh * 365.0
        
        print(f"10 Yıllık Toplam: {total_fetched_ghi_kwh:.2f} kWh/m²")
        print(f"Yıllık Ortalama: {annual_avg_ghi_kwh:.2f} kWh/m²")
        
        # --- 2. AYLIK GRUPLAMA (ORTALAMA) ---
        monthly_aggregate = {} 
        
        for i, time_str in enumerate(time_list):
            if ghi_list[i] is None: continue
            month = time_str.split("-")[1] 
            
            if month not in monthly_aggregate:
                monthly_aggregate[month] = {"ghi_sum": 0.0, "temp_sum": 0.0, "hours": 0}
            
            monthly_aggregate[month]["ghi_sum"] += ghi_list[i]
            monthly_aggregate[month]["temp_sum"] += (temp_list[i] or 0)
            monthly_aggregate[month]["hours"] += 1
            
        processed_monthly_stats = []
        for m in sorted(monthly_aggregate.keys()):
            stats = monthly_aggregate[m]
            
            if stats["hours"] > 0:
                avg_hourly_ghi_kw = (stats["ghi_sum"] / stats["hours"]) / 1000.0
                avg_monthly_total_kwh = avg_hourly_ghi_kw * 24 * 30.4
                avg_temp = stats["temp_sum"] / stats["hours"]
            else:
                avg_monthly_total_kwh = 0
                avg_temp = 0
            
            processed_monthly_stats.append({
                "month": int(m),
                "total_production_kwh_m2": round(avg_monthly_total_kwh, 2),
                "avg_temperature_c": round(avg_temp, 1)
            })

        # --- 3. ML İÇİN VERİ HAZIRLIĞI VE TAHMİN ---
        ml_training_data = []
        for i in range(len(time_list)):
            if ghi_list[i] is not None:
                ml_training_data.append({
                    "time": time_list[i],
                    "value": ghi_list[i] 
                })
        
        future_prediction = predict_future_production(ml_training_data, resource_type="solar")

        return {
            "annual_total_ghi_kwh": annual_avg_ghi_kwh,
            "daily_avg_kwh": daily_avg_kwh,
            "monthly_stats": processed_monthly_stats,
            "future_prediction": future_prediction,
            "raw_data_for_ml": ml_training_data
        }

    except requests.exceptions.HTTPError as errh:
        print(f"Hata: {errh}")
        return {"error": str(errh)}
    except requests.exceptions.RequestException as erre:
        print(f"İstek Hatası: {erre}")
        return {"error": str(erre)}
    except Exception as e:
        print(f"Genel Hata: {e}")
        return {"error": str(e)}

# --- SİSTEM HESAPLAMA ---
def calculate_solar_power_production(
    latitude: float,
    longitude: float,
    panel_area: float,
    panel_efficiency: float = 0.20,
    performance_ratio: float = 0.75
) -> Dict:
    
    data = get_historical_hourly_solar_data(latitude, longitude)
    
    if "error" in data:
        return {"error": data["error"]}
    
    # 10 Yıllık ortalamaya dayalı standart hesap
    annual_ghi = data["annual_total_ghi_kwh"]
    annual_energy_kwh = panel_area * annual_ghi * panel_efficiency * performance_ratio
    
    # ML Tahminine dayalı hesap (Gelecek yıl)
    predicted_ghi = data["future_prediction"].get("total_prediction_value", 0.0) # total_prediction_value kullanılır
    predicted_annual_energy_kwh = panel_area * predicted_ghi * panel_efficiency * performance_ratio

    # ML Aylık Verileri İşle
    ml_monthly_system_production = []
    if "monthly_predictions" in data["future_prediction"]:
        for pred in data["future_prediction"]["monthly_predictions"]:
            prod = pred["prediction"] * panel_area * panel_efficiency * performance_ratio
            ml_monthly_system_production.append({
                "year": pred["year"],
                "month": pred["month"],
                "predicted_production_kwh": round(prod, 2)
            })

    return {
        "annual_potential_kwh_m2": annual_ghi,
        "daily_avg_potential_kwh_m2": data["daily_avg_kwh"],
        "system_annual_production_kwh": annual_energy_kwh,
        "predicted_annual_production_kwh": predicted_annual_energy_kwh,
        "monthly_breakdown": data["monthly_stats"],
        "future_monthly_breakdown": ml_monthly_system_production,
        "raw_data_for_ml": data["raw_data_for_ml"] # Senaryo için ham veriyi taşı
    }

# Uyumluluk
def get_annual_average_solar_potential(latitude: float, longitude: float) -> float | None:
    data = get_historical_hourly_solar_data(latitude, longitude)
    if "error" in data: return None
    return data["daily_avg_kwh"]

def calculate_solar_irradiance(*args, **kwargs): return 0.0
def calculate_panel_efficiency(*args, **kwargs): return 0.0
def get_temperature_from_coordinates(*args, **kwargs): return 0.0
def calculate_solar_power(*args, **kwargs): return {}
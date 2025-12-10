import requests
import statistics
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any

# --- SABİTLER ---
STC_TEMPERATURE = 25.0

EXAMPLE_PANEL_SPECS = {
    "model_name": "Standart 400W Panel",
    "power_rating_w": 400,
    "dimensions_m": {"length": 2.0, "width": 1.0},  # 2m²/panel
    "base_efficiency": 0.20, # %20 Verim (Güncel teknolojiye uygun)
    "temp_coefficient": -0.005,
    "is_default": True
}
# 
def get_historical_hourly_solar_data(latitude: float, longitude: float) -> Dict[str, Any]:
    """
    Open-Meteo Archive API'den son 1 yılın SAATLİK verilerini çeker.
    Bu ana fonksiyondur.
    """
    
    # 1. Tarih Aralığı (Geçen yılın bugünü - 5 gün önce)
    end_date = datetime.now() - timedelta(days=5) 
    start_date = end_date - timedelta(days=365)
    
    str_start = start_date.strftime("%Y-%m-%d")
    str_end = end_date.strftime("%Y-%m-%d")
    
    print(f"--- VERİ ÇEKİLİYOR ---")
    print(f"Konum: {latitude}, {longitude}")
    print(f"Aralık: {str_start} - {str_end}")

    BASE_URL = "https://archive-api.open-meteo.com/v1/archive"
    
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": str_start,
        "end_date": str_end,
        "hourly": "shortwave_radiation,direct_normal_irradiance,diffuse_radiation,temperature_2m,cloud_cover",
        "timezone": "auto"
    }

    try:
        response = requests.get(BASE_URL, params=params)
        response.raise_for_status()
        data = response.json()
        
        hourly = data.get("hourly", {})
        
        # Veri listeleri
        time_list = hourly.get("time", [])
        ghi_list = hourly.get("shortwave_radiation", []) # W/m²
        temp_list = hourly.get("temperature_2m", []) # °C
        cloud_list = hourly.get("cloud_cover", []) # %
        
        if not ghi_list:
            print("Hata: API'den boş veri döndü.")
            return {"error": "Boş veri"}

        # --- İŞLEME 1: Yıllık Toplam ---
        valid_ghi = [x for x in ghi_list if x is not None]
        total_annual_ghi_wh = sum(valid_ghi)
        total_annual_ghi_kwh = total_annual_ghi_wh / 1000.0 # kWh/m²
        
        daily_avg_kwh = total_annual_ghi_kwh / 365.0
        
        print(f"Yıllık Toplam Işınım: {total_annual_ghi_kwh:.2f} kWh/m²")

        # --- İŞLEME 2: Aylık Gruplama ---
        monthly_data = {}
        
        for i, time_str in enumerate(time_list):
            if ghi_list[i] is None: continue
            month = time_str.split("-")[1] 
            
            if month not in monthly_data:
                monthly_data[month] = {"sum_ghi": 0.0, "sum_temp": 0.0, "count": 0}
            
            monthly_data[month]["sum_ghi"] += ghi_list[i]
            monthly_data[month]["sum_temp"] += (temp_list[i] or 0)
            monthly_data[month]["count"] += 1
            
        processed_monthly_stats = []
        for m in sorted(monthly_data.keys()):
            stats = monthly_data[m]
            processed_monthly_stats.append({
                "month": int(m),
                "total_production_kwh_m2": round(stats["sum_ghi"] / 1000.0, 2),
                "avg_temperature_c": round(stats["sum_temp"] / stats["count"], 1)
            })

        return {
            "annual_total_ghi_kwh": total_annual_ghi_kwh,
            "daily_avg_kwh": daily_avg_kwh,
            "monthly_stats": processed_monthly_stats,
        }

    except Exception as e:
        print(f"API Bağlantı Hatası: {e}")
        return {"error": str(e)}

# --- SİSTEM HESAPLAMA (Calculate Endpoint İçin) ---
def calculate_solar_power_production(
    latitude: float,
    longitude: float,
    panel_area: float,
    panel_efficiency: float = 0.20,
    performance_ratio: float = 0.75
) -> Dict:
    
    # Yeni veri çekme fonksiyonunu kullan
    data = get_historical_hourly_solar_data(latitude, longitude)
    
    if "error" in data:
        return {"error": data["error"]}
    
    annual_ghi = data["annual_total_ghi_kwh"]
    annual_energy_kwh = panel_area * annual_ghi * panel_efficiency * performance_ratio
    
    return {
        "annual_potential_kwh_m2": data["annual_total_ghi_kwh"],
        "daily_avg_potential_kwh_m2": data["daily_avg_kwh"],
        "system_annual_production_kwh": annual_energy_kwh,
        "monthly_breakdown": data["monthly_stats"]
    }

# --- UYUMLULUK MODU (CRUD.PY HATASINI ÇÖZEN KISIM) ---
# crud.py eski ismiyle bu fonksiyonu arıyor.
# Biz de eski ismi koruyup, yeni sisteme yönlendiriyoruz.

def get_annual_average_solar_potential(latitude: float, longitude: float) -> float | None:
    """
    Eski sistem uyumluluğu için köprü fonksiyon.
    Yeni 'get_historical_hourly_solar_data' fonksiyonunu çağırır 
    ve sadece 'daily_avg_kwh' değerini döndürür.
    """
    print("UYARI: Eski fonksiyon çağrıldı, yeni sisteme yönlendiriliyor...")
    data = get_historical_hourly_solar_data(latitude, longitude)
    
    if "error" in data:
        return None
        
    return data["daily_avg_kwh"]

# Eski simülasyon fonksiyonları için de boş wrapperlar (Hata vermemesi için)
def calculate_solar_irradiance(*args, **kwargs): return 0.0
def calculate_panel_efficiency(*args, **kwargs): return 0.0
def get_temperature_from_coordinates(*args, **kwargs): return 0.0
def calculate_solar_power(*args, **kwargs): return {}
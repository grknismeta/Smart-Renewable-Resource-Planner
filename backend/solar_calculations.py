# solar_calculations.py
import math
from typing import Dict, Optional
import requests
import statistics

# DÜZELTME: Fonksiyon adı Pylance hatasını gidermek için değiştirildi
def get_current_solar_data(
    latitude: float,
    longitude: float,
    tilt_angle: float,
    azimuth_angle: float
) -> Dict[str, float]:
    """
    Belirli bir konumdaki ANLIK güneş verilerini hesaplar/çeker.
    
    !!! ÖNEMLİ !!!
    BU FONKSİYON ŞU ANDA SİMÜLASYONDUR (PLACEHOLDER).
    (Hareket Planı Faz 1 - Gerçek API ile değiştirilecek)
    
    :return: Işınım (kW/m²) ve Sıcaklık (°C) içeren bir sözlük
    """
    print(f"ANLIK güneş ve sıcaklık verisi {latitude}, {longitude} için çekiliyor (simülasyon)...")
    
    # Şimdilik simülasyon değerleri:
    simulated_irradiance = 0.8  # kW/m²
    simulated_temp = 25.0       # °C
    
    return {
        "irradiance": simulated_irradiance,
        "temperature": simulated_temp
    }

def calculate_panel_efficiency(
    temperature: float,
    base_efficiency: float = 0.15,
    temp_coefficient: float = -0.005
) -> float:
    """
    Sıcaklığa bağlı panel verimini hesaplar.
    """
    temp_difference = temperature - 25  # 25°C referans sıcaklık
    efficiency = base_efficiency * (1 + (temp_coefficient * temp_difference))
    return max(0.0, efficiency)  # Verim negatif olamaz


def calculate_solar_power(
    latitude: float,
    longitude: float,
    panel_area: float,
    tilt_angle: float = 35,
    azimuth_angle: float = 180,
    base_efficiency: float = 0.15,
    temp_coefficient: float = -0.005
) -> Dict[str, float]:
    """
    Güneş enerjisi sisteminin anlık güç üretimini hesaplar.
    (Artık simülasyon yerine 'get_current_solar_data'yı çağırıyor)
    """
    
    # 1. ANLIK verileri (ışınım ve sıcaklık) al
    solar_data = get_current_solar_data(
        latitude, longitude, tilt_angle, azimuth_angle
    )
    irradiance = solar_data["irradiance"]
    temperature = solar_data["temperature"]
    
    # 2. Sıcaklığa göre panel verimini hesapla
    efficiency = calculate_panel_efficiency(
        temperature, base_efficiency, temp_coefficient
    )
    
    # 3. Güç üretimini hesapla (kW)
    # P = Işınım * Alan * Verim
    power_output = irradiance * panel_area * efficiency
    
    return {
        "solar_irradiance_kw_m2": irradiance,
        "temperature_celsius": temperature,
        "panel_efficiency": efficiency,
        "power_output_kw": power_output
    }

# Örnek panel özellikleri (veritabanında saklanacak)
EXAMPLE_PANEL_SPECS = {
    "model_name": "Standart 400W Panel",
    "power_rating_w": 400,
    "dimensions_m": {"length": 2.0, "width": 1.0},
    "base_efficiency": 0.15,
    "temp_coefficient": -0.005,
    "is_default": True
}


def get_annual_average_solar_potential(latitude: float, longitude: float) -> float | None:
    """
    Belirtilen koordinatlar için Open-Meteo API'den 2023 yılına ait
    günlük güneş ışınımı verilerini (MJ/m²) çeker ve yıllık ortalamayı
    (kWh/m²/gün) olarak döndürür.
    """
    BASE_URL = "https://archive-api.open-meteo.com/v1/archive"

    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": "2023-01-01",
        "end_date": "2023-12-31",
        "daily": "shortwave_radiation_sum", # BİRİMİ: MJ/m² (Megajul)
        "timezone": "auto"
    }

    try:
        response = requests.get(BASE_URL, params=params)
        response.raise_for_status() 
        data = response.json()

        daily_values_mj = data.get("daily", {}).get("shortwave_radiation_sum", [])

        if not daily_values_mj:
            print(f"Hata: {latitude},{longitude} için Open-Meteo'dan veri alınamadı.")
            return None

        valid_values_mj = [v for v in daily_values_mj if v is not None]

        if not valid_values_mj:
            print(f"Hata: {latitude},{longitude} için sadece geçersiz veri (null) döndü.")
            return None

        avg_daily_mj = statistics.mean(valid_values_mj)
        
        # 1 kWh = 3.6 MJ
        avg_daily_kwh = avg_daily_mj / 3.6
        
        return avg_daily_kwh

    except requests.exceptions.RequestException as e:
        print(f"Open-Meteo API'ye bağlanırken hata oluştu: {e}")
        return None
    except (KeyError, statistics.StatisticsError):
        print(f"Hata: Open-Meteo yanıtı beklenmedik bir formatta veya boş veri.")
        return None

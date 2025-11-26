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
    Belirli bir konumdaki ANLIK güneş verilerini (ışınım ve sıcaklık)
    Open-Meteo Forecast API'sinden çeker.
    
    (Simülasyon kaldırıldı, artık GERÇEK veri çekiyor)
    """
    print(f"ANLIK güneş ve sıcaklık verisi {latitude}, {longitude} için çekiliyor (GERÇEK API)...")

    API_URL = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "current": "temperature_2m,shortwave_radiation", # Anlık sıcaklık ve ışınımı istiyoruz
        "timezone": "auto"
    }

    try:
        response = requests.get(API_URL, params=params)
        response.raise_for_status()
        data = response.json().get("current", {})
        
        # 1. Sıcaklığı al (°C)
        current_temp = data.get("temperature_2m", 25.0) # Hata olursa 25 döner

        # 2. Işınımı al (API'den W/m² olarak gelir)
        irradiance_wm2 = data.get("shortwave_radiation", 800.0) # Hata olursa 800 döner
        
        # 3. Birimi W/m² -> kW/m²'ye çevir (1000'e böl)
        current_irradiance_kwm2 = irradiance_wm2 / 1000.0
        
        return {
            "irradiance": current_irradiance_kwm2,
            "temperature": current_temp
        }
        
    except Exception as e:
        print(f"Hata: Anlık güneş verisi çekilemedi, simülasyon kullanılıyor: {e}")
        # API isteği başarısız olursa eski simülasyon değerlerine dön
        return {
            "irradiance": 0.8, # kW/m²
            "temperature": 25.0 # °C
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
    (Artık GERÇEK API verisini çağıran 'get_current_solar_data'yı çağırıyor)
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
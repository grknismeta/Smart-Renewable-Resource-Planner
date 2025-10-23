# solar_calculations.py
import math
from typing import Dict, Optional

def calculate_solar_irradiance(
    latitude: float,
    longitude: float,
    tilt_angle: float,
    azimuth_angle: float
) -> float:
    """
    Belirli bir konumdaki güneş ışınım şiddetini hesaplar (kW/m²).
    
    !!! ÖNEMLİ !!!
    BU FONKSİYON ŞU ANDA SİMÜLASYONDUR (PLACEHOLDER).
    Bir sonraki adımda PVGIS veya NASA verisini sorgulayacak şekilde güncellenecek.
    
    :param latitude: Enlem
    :param longitude: Boylam
    :param tilt_angle: Panel eğim açısı (derece)
    :param azimuth_angle: Yön açısı (derece, 0=Kuzey, 90=Doğu, 180=Güney, 270=Batı)
    :return: Işınım şiddeti (kW/m²)
    """
    print(f"Güneş ışınım verisi {latitude}, {longitude} koordinatları için çekiliyor (simülasyon)...")
    
    # Şimdilik simülasyon değeri:
    # Gerçekte, bu değer lat/lon/açılara göre değişmeli
    simulated_irradiance = 0.8  # kW/m²
    return simulated_irradiance

def calculate_panel_efficiency(
    temperature: float,
    base_efficiency: float = 0.15,
    temp_coefficient: float = -0.005
) -> float:
    """
    Sıcaklığa bağlı panel verimini hesaplar.
    
    :param temperature: Ortam sıcaklığı (°C)
    :param base_efficiency: Referans koşullardaki (25°C) panel verimi
    :param temp_coefficient: Sıcaklık katsayısı (%/°C)
    :return: Güncel panel verimi (0-1 arası)
    """
    temp_difference = temperature - 25  # 25°C referans sıcaklık
    efficiency = base_efficiency * (1 + (temp_coefficient * temp_difference))
    return max(0.0, efficiency)  # Verim negatif olamaz

def get_temperature_from_coordinates(lat: float, lon: float) -> float:
    """
    Belirtilen koordinatlardaki sıcaklığı (°C) döndürür.
    
    !!! ÖNEMLİ !!!
    BU FONKSİYON ŞU ANDA SİMÜLASYONDUR (PLACEHOLDER).
    Bir sonraki adımda meteoroloji verisini sorgulayacak şekilde güncellenecek.
    """
    print(f"Sıcaklık verisi {lat}, {lon} koordinatları için çekiliyor (simülasyon)...")
    simulated_temp = 25.0
    return simulated_temp

def calculate_solar_power(
    latitude: float,
    longitude: float,
    panel_area: float,
    tilt_angle: float = 35,  # Türkiye için optimum eğim ~35°
    azimuth_angle: float = 180,  # Güney yönü
    base_efficiency: float = 0.15,  # %15 temel verim
    temp_coefficient: float = -0.005  # -%0.5/°C sıcaklık katsayısı
) -> Dict[str, float]:
    """
    Güneş enerjisi sisteminin anlık güç üretimini hesaplar.
    
    :param latitude: Enlem
    :param longitude: Boylam
    :param panel_area: Toplam panel alanı (m²)
    :param tilt_angle: Panel eğim açısı (derece)
    :param azimuth_angle: Yön açısı (derece)
    :param base_efficiency: Panel temel verimi (0-1 arası)
    :param temp_coefficient: Sıcaklık katsayısı
    :return: Hesaplama sonuçları
    """
    # 1. Işınım şiddetini hesapla
    irradiance = calculate_solar_irradiance(
        latitude, longitude, tilt_angle, azimuth_angle
    )
    
    # 2. Sıcaklığı al ve panel verimini hesapla
    temperature = get_temperature_from_coordinates(latitude, longitude)
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
    "dimensions_m": {"length": 2.0, "width": 1.0},  # 2m²/panel
    "base_efficiency": 0.15,
    "temp_coefficient": -0.005,
    "is_default": True
}
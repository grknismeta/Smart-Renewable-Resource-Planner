# wind_calculations.py
# Bu dosya, rüzgar türbinlerinin enerji üretimi ve 
# maliyet hesaplamalarını içerecektir.

import math
from typing import Dict
import requests

def get_power_from_curve(wind_speed: float, power_curve: Dict[float, float]) -> float:
    """
    Bir türbinin güç eğrisini (power curve) kullanarak, 
    belirli bir rüzgar hızındaki anlık güç üretimini (kW) hesaplar.
    
    Güç eğrisi (sözlük) içindeki veriler arasında lineer interpolasyon yapar.

    :param wind_speed: Rüzgar hızı (m/s).
    :param power_curve: Türbin modeline ait güç eğrisi. 
                        Format: {hız_ms: guc_kw}
    :return: Anlık güç üretimi (kW).
    """
    
    if not power_curve:
        return 0.0

    # Güç eğrisini hızlara (key'lere) göre sıralayalım
    # JSON'dan gelen key'ler string olabilir, float'a çevirip sıralayalım
    try:
        sorted_speeds = sorted([float(k) for k in power_curve.keys()])
        
        # Orijinal power_curve'ün key'leri string ise, 
        # float key'lere sahip yeni bir dict oluşturalım.
        float_key_curve = {float(k): float(v) for k, v in power_curve.items()}
    except ValueError:
        print("Hata: Güç eğrisi verisi bozuk.")
        return 0.0
    
    # 1. Rüzgar hızı, eğrinin altındaysa (cut-in speed altı)
    if wind_speed < sorted_speeds[0]:
        return 0.0
    
    # 2. Rüzgar hızı, eğrinin üstündeyse (cut-out speed üstü)
    if wind_speed > sorted_speeds[-1]:
        return 0.0
    
    # 3. Rüzgar hızı eğride tam olarak varsa
    if wind_speed in float_key_curve:
        return float_key_curve[wind_speed]

    # 4. Rüzgar hızı ara bir değerdeyse (Lineer Interpolasyon)
    #    y = y1 + (x - x1) * (y2 - y1) / (x2 - x1)
    
    lower_speed = sorted_speeds[0]
    upper_speed = sorted_speeds[-1]
    
    # Hızı kapsayan alt ve üst sınırları bul
    for speed in sorted_speeds:
        if speed <= wind_speed:
            lower_speed = speed
        if speed >= wind_speed:
            upper_speed = speed
            break

    if lower_speed == upper_speed:
        return float_key_curve[lower_speed]

    lower_power = float_key_curve[lower_speed]
    upper_power = float_key_curve[upper_speed]
    
    # Bölme hatasını engelle (eğer upper_speed == lower_speed ise)
    if (upper_speed - lower_speed) == 0:
        return lower_power

    # Interpolasyon
    interpolated_power = lower_power + (wind_speed - lower_speed) * (upper_power - lower_power) / (upper_speed - lower_speed)
    
    return interpolated_power

def get_current_wind_speed(latitude: float, longitude: float, height: int = 100) -> float:
    """
    Open-Meteo'dan anlık rüzgar hızını (m/s) çeker.
    Türbinler için 100m yükseklik varsayılanıdır.
    """
    API_URL = "[https://api.open-meteo.com/v1/forecast](https://api.open-meteo.com/v1/forecast)"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "current": f"wind_speed_{height}m", # Örn: wind_speed_100m
        "timezone": "auto"
    }
    try:
        response = requests.get(API_URL, params=params)
        response.raise_for_status()
        data = response.json().get("current", {})
        return data.get(f"wind_speed_{height}m", 8.5) # Hata olursa 8.5 döner
    except Exception as e:
        print(f"Hata: Anlık rüzgar verisi çekilemedi: {e}")
        return 8.5 # Simülasyon


# --- ÖRNEK STANDART GÜÇ EĞRİSİ ---
# PNG'deki "standart bir rüzgar gülü belirt" isteği için
# Bu veriyi veritabanındaki 'turbines' tablosuna ekleyeceğiz.
EXAMPLE_TURBINE_POWER_CURVE: Dict[float, float] = {
    0: 0,
    1: 0,
    2: 0,
    3: 0,       # Cut-in hızı (çalışmaya başlama)
    4: 70,
    5: 150,
    6: 300,
    7: 500,
    8: 800,
    9: 1200,
    10: 1600,
    11: 1900,
    12: 2000,   # Rated hızı (tam kapasite)
    13: 2000,
    14: 2000,
    15: 2000,
    16: 2000,
    17: 2000,
    18: 2000,
    19: 2000,
    20: 2000,
    21: 2000,
    22: 2000,
    23: 2000,
    24: 2000,
    25: 0        # Cut-out hızı (koruma için durma)
}

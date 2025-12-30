import math
from typing import Dict, Any, List, Union

# --- Standart Türbin Güç Eğrisi (3.3 MW) ---
# Rüzgar Hızı (m/s) -> Güç Çıkışı (kW)
EXAMPLE_TURBINE_POWER_CURVE: Dict[Union[int, float], Union[int, float]] = {
    0: 0, 1: 0, 2: 0, 
    3: 50, 4: 150, 5: 350, 6: 600, 7: 950, 8: 1400, 
    9: 1900, 10: 2300, 11: 2700, 
    12: 3000, 13: 3200, 14: 3300, 25: 3300, 30: 0 
}

def get_power_from_curve(wind_speed: float, curve: Dict[Union[int, float], Union[int, float]]) -> float:
    """
    Verilen rüzgar hızında türbinin ne kadar güç (kW) üreteceğini hesaplar.
    Ara değerler için lineer interpolasyon yapar.
    """
    speeds = sorted(curve.keys())
    
    # Sınırların dışındaysa
    if wind_speed < speeds[0] or wind_speed > speeds[-1]:
        return 0.0
    
    if wind_speed in curve:
        return curve[wind_speed]
    
    # Alt ve üst sınırları bul
    lower = max([s for s in speeds if s <= wind_speed], default=0)
    upper = min([s for s in speeds if s >= wind_speed], default=max(speeds))
    
    if lower == upper: return curve[lower]
    
    # İnterpolasyon
    p_lower = curve[lower]
    p_upper = curve[upper]
    
    ratio = (wind_speed - lower) / (upper - lower)
    return p_lower + ratio * (p_upper - p_lower)

def calculate_wind_power_production(
    latitude: float, 
    longitude: float, 
    weather_stats: Dict[str, Any] = None # type: ignore
) -> Dict[str, Any]:
    """
    Veritabanı istatistiklerini kullanarak Rüzgar Potansiyeli hesaplar.
    """
    
    # 1. Rüzgar Hızı Çekme
    if weather_stats and "annual_avg" in weather_stats and weather_stats["annual_avg"]["wind"] is not None:
        avg_speed = weather_stats["annual_avg"]["wind"]
    else:
        # Fallback (Veri yoksa)
        print(f"Uyarı: ({latitude}, {longitude}) için rüzgar verisi yok. Varsayılan kullanılıyor.")
        avg_speed = 6.0 # m/s (Türkiye ortalamasına yakın kabul edilebilir bir değer)

    # 2. Üretim Hesabı
    # Rüzgar türbinlerinde ortalama hızdan güç hesabı yapmak (P = 1/2 * rho * A * v^3)
    # hataya açıktır çünkü hızın küpü ile orantılıdır. 
    # Bu yüzden "Variability Factor" (Değişkenlik Çarpanı) kullanıyoruz.
    # Rayleigh dağılımı varsayımıyla bu çarpan ~1.91 civarındadır (Enerji Deseni Faktörü).
    # Ancak biz daha muhafazakar bir yaklaşım izleyelim:
    
    # Ortalama hızdaki teorik güç
    base_power_kw = get_power_from_curve(avg_speed, EXAMPLE_TURBINE_POWER_CURVE)
    
    # Düzeltme Faktörü (Gerçek dünya koşulları)
    # Düşük rüzgarlarda dalgalanma pozitiftir, çok yüksek rüzgarlarda negatiftir.
    variability_factor = 1.6 if avg_speed < 8 else 1.2
    
    predicted_avg_power_kw = base_power_kw * variability_factor
    
    # Yıllık Enerji (8760 saat)
    annual_production = predicted_avg_power_kw * 8760
    
    # Kapasite Faktörü Hesabı
    rated_power = max(EXAMPLE_TURBINE_POWER_CURVE.values()) # 3300 kW
    capacity_factor = 0
    if rated_power > 0:
        capacity_factor = annual_production / (rated_power * 8760)

    # Mantık kontrolü (CF %50'yi geçmemeli, gerçekçi olmaz)
    if capacity_factor > 0.55:
        capacity_factor = 0.55
        annual_production = rated_power * 8760 * 0.55

    return {
        "avg_wind_speed_ms": round(avg_speed, 2),
        "predicted_annual_production_kwh": round(annual_production, 0),
        "capacity_factor": round(capacity_factor, 3)
    }

# --- Uyumluluk Fonksiyonu (Eski kodlar kırılmasın diye) ---
def get_wind_speed_from_coordinates(lat, lon):
    # Bu fonksiyon artık router içinde weather_stats üzerinden hallediliyor
    # ama yine de çağrılırsa diye basit bir değer dönelim.
    return 6.0

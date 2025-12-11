import requests
import statistics
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any

# --- YENİ IMPORT ---
from .ml_predictor import predict_future_production 
# -------------------

# --- ÖRNEK TÜRBİN GÜÇ EĞRİSİ (3.3 MW) ---
# Hız (m/s) : Güç (kW)
EXAMPLE_TURBINE_POWER_CURVE: Dict[float, float] = {
    0: 0, 1: 0, 2: 0, 
    3: 50,    # Cut-in
    4: 150, 5: 350, 6: 600, 7: 950, 8: 1400, 
    9: 1900, 10: 2300, 11: 2700, 
    12: 3000, # Rated Power'a yaklaşım
    13: 3200, 14: 3300, 25: 3300, 26: 0 # Cut-out
}

def get_power_from_curve(wind_speed_ms: float, power_curve: Dict[float, float]) -> float:
    """
    Belirli bir rüzgar hızında (m/s), türbin güç eğrisinden (kW) üretim değerini çeker.
    Lineer interpolasyon kullanır.
    """
    if not power_curve: return 0.0
    if wind_speed_ms < 0: return 0.0

    sorted_speeds = sorted([float(k) for k in power_curve.keys()])
    
    # Sınır kontrolü (Cut-in altı veya Cut-out üstü)
    if wind_speed_ms < sorted_speeds[0] or wind_speed_ms > sorted_speeds[-1]:
        return 0.0
        
    # Tam eşleşme varsa
    if wind_speed_ms in power_curve:
        return power_curve[wind_speed_ms]

    # Interpolasyon (Ara değer bulma)
    lower_speed = sorted_speeds[0]
    upper_speed = sorted_speeds[-1]
    
    for s in sorted_speeds:
        if s <= wind_speed_ms: lower_speed = s
        if s >= wind_speed_ms: 
            upper_speed = s
            break
            
    if lower_speed == upper_speed: return power_curve[lower_speed]
        
    lower_power = power_curve[lower_speed]
    upper_power = power_curve[upper_speed]
    
    # Lineer İnterpolasyon Formülü
    interpolated_power = lower_power + (wind_speed_ms - lower_speed) * \
                         (upper_power - lower_power) / (upper_speed - lower_speed)
                         
    return interpolated_power

def get_historical_hourly_wind_data(latitude: float, longitude: float) -> Dict[str, Any]:
    """
    Open-Meteo Archive API'den son 10 yılın SAATLİK rüzgar verilerini çeker.
    ML tahmini ve detaylı analiz yapar.
    """
    # 1. Tarih Aralığı (10 Yıl)
    end_date = datetime.now() - timedelta(days=5) 
    days_to_fetch = 3650 
    start_date = end_date - timedelta(days=days_to_fetch)
    
    str_start = start_date.strftime("%Y-%m-%d")
    str_end = end_date.strftime("%Y-%m-%d")
    
    print(f"--- RÜZGAR VERİSİ ÇEKİLİYOR (10 Yıllık) ---")
    print(f"Aralık: {str_start} - {str_end}")

    BASE_URL = "https://archive-api.open-meteo.com/v1/archive"
    
    # 100m yükseklik (Türbin seviyesi) verisi çekiyoruz
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "start_date": str_start,
        "end_date": str_end,
        "hourly": "wind_speed_100m,wind_direction_100m",
        "timezone": "auto"
    }

    try:
        response = requests.get(BASE_URL, params=params)
        response.raise_for_status()
        data = response.json()
        
        hourly = data.get("hourly", {})
        time_list = hourly.get("time", [])
        ws_list_kmh = hourly.get("wind_speed_100m", []) # km/h
        
        if not ws_list_kmh:
            return {"error": "Boş rüzgar verisi"}

        # --- 1. GEÇMİŞ VERİ ANALİZİ ---
        # Rüzgar hızını m/s'ye çeviriyoruz
        valid_ws_ms = [(x / 3.6) for x in ws_list_kmh if x is not None]
        
        # 10 Yıllık Ortalama Hız
        avg_wind_speed_ms = statistics.mean(valid_ws_ms)
        print(f"10 Yıllık Ortalama Rüzgar Hızı: {avg_wind_speed_ms:.2f} m/s")

        # --- 2. SAATLİK ÜRETİM SİMÜLASYONU (Hassas Hesap) ---
        # Ortalama hızdan hesaplamak yerine, her saatin hızını güç eğrisine sokup topluyoruz.
        # Bu yöntem rüzgarın değişkenliğini (küp kuralı) hesaba kattığı için çok daha doğrudur.
        total_energy_kwh = 0.0
        for ws in valid_ws_ms:
            power_kw = get_power_from_curve(ws, EXAMPLE_TURBINE_POWER_CURVE)
            total_energy_kwh += power_kw * 1.0 # Güç * 1 saat = Enerji
            
        # Toplam enerjiyi 1 yıla indirge
        actual_years = len(time_list) / 8760.0
        annual_avg_production_kwh = total_energy_kwh / actual_years
        
        print(f"Hesaplanan Yıllık Ortalama Üretim: {annual_avg_production_kwh:.0f} kWh")

        # --- 3. AYLIK GRUPLAMA (Grafik İçin) ---
        monthly_aggregate = {} 
        
        for i, time_str in enumerate(time_list):
            if ws_list_kmh[i] is None: continue
            month = time_str.split("-")[1] 
            
            if month not in monthly_aggregate:
                monthly_aggregate[month] = {"ws_sum": 0.0, "count": 0}
            
            # km/h -> m/s çevirerek topla
            monthly_aggregate[month]["ws_sum"] += (ws_list_kmh[i] / 3.6)
            monthly_aggregate[month]["count"] += 1
            
        processed_monthly_stats = []
        for m in sorted(monthly_aggregate.keys()):
            stats = monthly_aggregate[m]
            avg_ws = stats["ws_sum"] / stats["count"]
            
            # O ay için tahmini üretim (Basitleştirilmiş: Ortalama hız * Saat)
            # Not: Grafik için ortalama hız daha anlamlı olabilir
            processed_monthly_stats.append({
                "month": int(m),
                "avg_wind_speed_ms": round(avg_ws, 2),
                # "estimated_kwh": ... (İstenirse eklenebilir)
            })

        # --- 4. ML İÇİN VERİ HAZIRLIĞI VE TAHMİN ---
        ml_training_data = []
        for i in range(len(time_list)):
            if ws_list_kmh[i] is not None:
                ml_training_data.append({
                    "time": time_list[i],
                    "value": ws_list_kmh[i] / 3.6 # m/s olarak eğitiyoruz
                })
        
        # ML Motorunu Çalıştır
        future_prediction = predict_future_production(ml_training_data, resource_type="wind")

        return {
            "avg_wind_speed_ms": avg_wind_speed_ms,
            "annual_production_kwh": annual_avg_production_kwh,
            "monthly_stats": processed_monthly_stats,
            "future_prediction": future_prediction
        }

    except Exception as e:
        print(f"Rüzgar API Hatası: {e}")
        return {"error": str(e)}

# --- SİSTEM HESAPLAMA ---
def calculate_wind_power_production(
    latitude: float,
    longitude: float,
    # turbine_model_id: int = None # İleride eklenecek
) -> Dict:
    
    # 1. Gerçek Veriyi Çek
    data = get_historical_hourly_wind_data(latitude, longitude)
    
    if "error" in data:
        return {"error": data["error"]}
    
    # Geçmiş veriye dayalı yıllık üretim (Saatlik simülasyon sonucu)
    annual_production_kwh = data["annual_production_kwh"]
    
    # ML Gelecek Tahmini (Rüzgar Hızı Tahmini)
    # ML bize aylık ortalama hız tahminlerini verir.
    # Gelecek yılın toplam üretimini tahmin etmek için bu hızları güç eğrisine sokuyoruz.
    
    predicted_annual_production = 0.0
    ml_monthly_system_production = []
    
    if "monthly_predictions" in data["future_prediction"]:
        for pred in data["future_prediction"]["monthly_predictions"]:
            pred_speed_ms = pred["prediction"]
            
            # Bu ayın ortalama gücünü bul (Basitleştirilmiş)
            # Not: Ortalama hızdan güç bulmak, küp kuralı nedeniyle düşük sonuç verir.
            # Düzeltme faktörü (Rayleigh Distribution Factor) ~1.91 eklenebilir veya
            # ML'den saatlik tahmin istenebilir. Şimdilik basitleştirilmiş haliyle bırakıyoruz.
            avg_power_kw = get_power_from_curve(pred_speed_ms, EXAMPLE_TURBINE_POWER_CURVE)
            
            # Ayı 730 saat kabul et
            monthly_prod = avg_power_kw * 730.0 
            predicted_annual_production += monthly_prod
            
            ml_monthly_system_production.append({
                "year": pred["year"],
                "month": pred["month"],
                "predicted_wind_speed_ms": pred_speed_ms,
                "predicted_production_kwh": round(monthly_prod, 2)
            })

    return {
        "avg_wind_speed_ms": data["avg_wind_speed_ms"],
        "system_annual_production_kwh": annual_production_kwh, # Geçmiş (Kesin)
        "predicted_annual_production_kwh": predicted_annual_production, # Gelecek (Tahmin)
        "monthly_breakdown": data["monthly_stats"],
        "future_monthly_breakdown": ml_monthly_system_production
    }

# --- UYUMLULUK MODU ---
def get_historical_wind_data(latitude: float, longitude: float) -> Dict[str, Any]:
    # Eski kodların (crud.py) çağırabileceği basit veri dönüşü
    data = get_historical_hourly_wind_data(latitude, longitude)
    if "error" in data:
        return {"error": data["error"]}
    return {
        "avg_wind_speed_ms": data["avg_wind_speed_ms"],
        # Diğer eski alanlar gerekirse buraya eklenebilir
    }

def get_wind_speed_from_coordinates(lat: float, lon: float) -> float:
    data = get_historical_hourly_wind_data(lat, lon)
    if "error" in data: return 0.0
    return data["avg_wind_speed_ms"]
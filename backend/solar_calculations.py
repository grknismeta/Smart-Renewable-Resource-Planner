from typing import Dict, Any, List
from datetime import datetime, timedelta
import requests

def calculate_solar_power_production(
    latitude: float, 
    longitude: float, 
    panel_area: float, 
    panel_efficiency: float = 0.20,
    weather_stats: Dict[str, Any] = None # type: ignore
) -> Dict[str, Any]:
    """
    Veritabanından gelen gerçek verilerle (weather_stats) yıllık üretim hesabı yapar.
    ML veya dış API kullanmaz. Tamamen fiziksel ve istatistikseldir.
    """
    
    # --- 1. Radyasyon Verisi Belirleme ---
    if weather_stats and "annual_avg" in weather_stats and weather_stats["annual_avg"]["solar"] is not None:
        # Veritabanında kayıtlı 'shortwave_radiation_sum' verisi MJ/m² birimindedir.
        # Elektrik üretimi için bunu kWh/m² birimine çevirmeliyiz.
        # 1 kWh = 3.6 MJ  =>  kWh = MJ / 3.6
        daily_irradiance_mj = weather_stats["annual_avg"]["solar"]
        daily_irradiance_kwh = daily_irradiance_mj / 3.6
        
        monthly_distribution = weather_stats.get("monthly", {})
    else:
        # Eğer veri yoksa (Fallback), Türkiye ortalaması veya enlem bazlı tahmin
        print(f"Uyarı: ({latitude}, {longitude}) için DB verisi yok. Tahmini hesap yapılıyor.")
        # Enlem arttıkça radyasyon düşer (Basit model)
        daily_irradiance_kwh = 5.5 - ((latitude - 36) * 0.2) 
        monthly_distribution = None

    # --- 2. Fiziksel Üretim Formülü ---
    # E = A * r * H * PR
    # PR (Performans Oranı): Sıcaklık kaybı, kablo kaybı, inverter verimi (~0.80 ideal)
    PR = 0.80 
    
    # Günlük Ortalama Üretim (kWh)
    daily_production = daily_irradiance_kwh * panel_area * panel_efficiency * PR
    
    # Yıllık Toplam Üretim (kWh)
    annual_production = daily_production * 365
    
    # --- 3. Aylık Kırılım (Grafikler İçin) ---
    month_names = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    
    monthly_preds = {}
    
    if monthly_distribution:
        # Gerçek aylık verileri kullan
        # monthly_distribution formatı: { '01': {'solar': 12.5, 'wind': 3.2}, ... }
        sorted_months = sorted(monthly_distribution.keys())
        
        for i, m_code in enumerate(sorted_months):
            if i >= 12: break # Güvenlik
            
            m_stats = monthly_distribution[m_code]
            if m_stats["solar"]:
                m_rad_kwh = m_stats["solar"] / 3.6
                # Ay ortalama 30.4 gün
                m_prod = m_rad_kwh * panel_area * panel_efficiency * PR * 30.4
                monthly_preds[month_names[int(m_code)-1]] = round(m_prod, 2)
            else:
                monthly_preds[month_names[int(m_code)-1]] = 0
                
        # Eksik ay varsa doldur (Nadir durum)
        for m in month_names:
            if m not in monthly_preds:
                monthly_preds[m] = round(annual_production / 12, 2)
    else:
        # Veri yoksa mevsimsel dağılım simülasyonu (Yazın çok, kışın az)
        for i, m in enumerate(month_names):
            # Basit sinüs eğrisi benzeri ağırlıklandırma
            weight = 1 + (0.4 * (1 if 2 < i < 8 else -1))
            monthly_preds[m] = round((annual_production / 12) * weight, 2)

    # --- 4. Sonuç Dönüşü ---
    return {
        "daily_avg_potential_kwh_m2": round(daily_irradiance_kwh, 2),
        "predicted_annual_production_kwh": round(annual_production, 2),
        "month_by_month_prediction": monthly_preds
    }


def get_historical_hourly_solar_data(latitude: float, longitude: float) -> Dict[str, Any]:
    """
    Open-Meteo Archive API'den son ~1 yılın saatlik güneş ve hava verilerini çeker.

    Döner:
    - annual_total_ghi_kwh: Yıllık toplam GHI (kWh/m²)
    - daily_avg_kwh: Günlük ortalama GHI (kWh/m²)
    - monthly_stats: Aylık toplamlara dair liste [{month, total_production_kwh_m2, avg_temperature_c, avg_cloud_cover}]
    - raw_data_for_ml: ML için ham saatlik veri listesi [{time, ghi, temp, cloud}]
    - hourly_data_count: Saatlik kayıt sayısı
    - error: Opsiyonel hata mesajı
    """

    # Son 1 yıl; veri sağlayıcı gecikmeleri için 5 gün geriden kapat
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
        ghi_list = hourly.get("shortwave_radiation", [])  # W/m²
        temp_list = hourly.get("temperature_2m", [])
        cloud_list = hourly.get("cloud_cover", [])

        if not ghi_list:
            return {"error": "Boş veri"}

        # Yıllık toplam (Wh/m²) -> kWh/m²
        valid_ghi = [x for x in ghi_list if x is not None]
        total_annual_ghi_wh = sum(valid_ghi)
        total_annual_ghi_kwh = total_annual_ghi_wh / 1000.0
        daily_avg_kwh = total_annual_ghi_kwh / 365.0

        # Aylık istatistikler
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

        monthly_stats: List[Dict[str, Any]] = []
        for month in sorted(monthly_data.keys()):
            stats = monthly_data[month]
            count = stats["count"] or 1.0
            monthly_stats.append({
                "month": int(month),
                "total_production_kwh_m2": round(stats["sum_ghi"] / 1000.0, 2),
                "avg_temperature_c": round(stats["sum_temp"] / count, 1),
                "avg_cloud_cover": round(stats["avg_cloud"] / count, 1),
            })

        raw_data_for_ml: List[Dict[str, Any]] = []
        n = len(time_list)
        for i in range(n):
            raw_data_for_ml.append({
                "time": time_list[i] if i < len(time_list) else None,
                "ghi": ghi_list[i] if i < len(ghi_list) else None,
                "temp": temp_list[i] if i < len(temp_list) else None,
                "cloud": cloud_list[i] if i < len(cloud_list) else None,
            })

        return {
            "annual_total_ghi_kwh": total_annual_ghi_kwh,
            "daily_avg_kwh": daily_avg_kwh,
            "monthly_stats": monthly_stats,
            "raw_data_for_ml": raw_data_for_ml,
            "hourly_data_count": len(raw_data_for_ml),
        }
    except requests.RequestException as e:
        return {"error": f"API Hatası: {e}"}
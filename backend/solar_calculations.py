from typing import Dict, Any, List

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
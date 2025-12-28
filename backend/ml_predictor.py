import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional

def predict_future_production(
    hourly_data: List[Dict[str, Any]], 
    resource_type: str = "solar", 
    start_date: Optional[datetime] = None, 
    end_date: Optional[datetime] = None
) -> Dict[str, Any]:
    """
    Geçmiş verilerle eğitilen modelle, belirtilen tarih aralığı için tahmin üretir.
    Eğer tarih verilmezse varsayılan olarak gelecek 1 yılı tahmin eder.
    """
    print(f"--- ML Modeli Çalışıyor ({resource_type.upper()}) ---")
    
    if not hourly_data:
        return {"error": "Eğitim verisi yok"}

    # 1. Veri Hazırlığı
    df = pd.DataFrame(hourly_data)
    df['time'] = pd.to_datetime(df['time'])

    # Hedef sütunu tespit et (geriye dönük uyumluluk için birden fazla isim desteklenir)
    # Solar için genellikle 'ghi' (shortwave_radiation), bazı akışlarda 'value' kullanılıyor.
    target_candidates = [
        'value',
        'ghi',
        'shortwave_radiation',
        'power',
        'wind_speed_100m',
        'wind_speed',
    ]

    target_col: Optional[str] = None
    for col in target_candidates:
        if col in df.columns:
            target_col = col
            break

    if target_col is None:
        # Açık ve kullanıcı-dostu bir hata döndürerek 500 yerine kontrollü yanıt verelim
        return {
            "error": "ML eğitim hedefi için uygun sütun bulunamadı",
            "expected_any_of": target_candidates,
            "available_columns": list(df.columns)
        }
    
    # Özellik Mühendisliği (Feature Engineering)
    # Pylance hatalarını susturmak için # type: ignore kullanıyoruz
    df['hour'] = df['time'].dt.hour # type: ignore
    df['day_of_year'] = df['time'].dt.dayofyear # type: ignore
    df['month'] = df['time'].dt.month # type: ignore
    
    X = df[['hour', 'day_of_year', 'month']]
    y = df[target_col]
    
    # NaN değerleri temizle (Scikit-learn NaN sevmez)
    combined = pd.concat([X, y], axis=1).dropna()
    if combined.empty:
        return {"error": "Eğitim için yeterli geçerli veri yok (Hepsi NaN)"}
        
    X = combined[['hour', 'day_of_year', 'month']]
    y = combined[target_col]

    # 2. Model Eğitimi
    model = RandomForestRegressor(n_estimators=100, random_state=42, n_jobs=-1)
    model.fit(X, y)
    
    # 3. Gelecek Tarih Aralığını Belirle (Tip Güvenli Hale Getirildi)
    
    # Pandas Timestamp'i Python datetime'a çevir (Pylance için)
    last_ts = df['time'].max()
    last_historical_date: datetime = pd.to_datetime(last_ts).to_pydatetime() # type: ignore

    # Hesaplamalarda kullanılacak kesin (None olmayan) tarihler
    calc_start_date: datetime
    calc_end_date: datetime

    if start_date:
        calc_start_date = start_date
    else:
        # Varsayılan: Verinin bittiği yerden 1 saat sonrası
        calc_start_date = last_historical_date + timedelta(hours=1)

    if end_date:
        calc_end_date = end_date
    else:
        # Varsayılan: Başlangıçtan 1 yıl sonrası
        calc_end_date = calc_start_date + timedelta(days=365)

    print(f"Tahmin Aralığı: {calc_start_date} -> {calc_end_date}")
    
    # 4. Gelecek Tarihleri Oluştur
    future_dates = pd.date_range(start=calc_start_date, end=calc_end_date, freq='h')
    
    if len(future_dates) == 0:
        return {"error": "Geçersiz tarih aralığı"}

    future_df = pd.DataFrame({'time': future_dates})
    future_df['hour'] = future_df['time'].dt.hour # type: ignore
    future_df['day_of_year'] = future_df['time'].dt.dayofyear # type: ignore
    future_df['month'] = future_df['time'].dt.month # type: ignore
    
    # 5. Tahmin Yap
    X_future = future_df[['hour', 'day_of_year', 'month']]
    predictions = model.predict(X_future)
    future_df['predicted_value'] = predictions
    
    # 6. Sonuçları Aylık/Yıllık Özetle
    monthly_predictions = []
    future_df['year'] = future_df['time'].dt.year # type: ignore
    
    grouped = future_df.groupby(['year', 'month'])
    total_prediction_sum = 0.0
    
    for (year, month), group in grouped:
        if resource_type == "solar":
            # W/m2 -> kWh/m2
            monthly_total = group['predicted_value'].sum() / 1000.0
            total_prediction_sum += monthly_total
            unit = "kWh/m²"
        else: # wind
            # Rüzgar: Ortalama Hız (m/s)
            monthly_total = group['predicted_value'].mean()
            unit = "m/s"
            
        monthly_predictions.append({
            "year": int(year),
            "month": int(month),
            "prediction": round(monthly_total, 2),
            "unit": unit
        })

    # Rüzgar için yıllık ortalama hızı döndür
    if resource_type == "wind":
        total_prediction_sum = future_df['predicted_value'].mean()

    return {
        "start_date": calc_start_date.isoformat(),
        "end_date": calc_end_date.isoformat(),
        "monthly_predictions": monthly_predictions,
        "total_prediction_value": round(total_prediction_sum, 2) 
    }
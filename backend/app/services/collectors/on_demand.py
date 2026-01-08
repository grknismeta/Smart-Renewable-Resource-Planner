import pandas as pd
from datetime import datetime, timedelta
import requests_cache
from retry_requests import retry
import openmeteo_requests

from .base import setup_client, ARCHIVE_API_URL

def fetch_point_climate_data(lat: float, lon: float, years: int = 1) -> dict:
    """
    Fetches comprehensive climate data (Solar + Wind + Temp) for a specific point.
    Used for on-demand pin calculations.
    
    Returns:
        dict: {
            "annual_summary": { "avg_wind": ..., "avg_solar": ..., "avg_temp": ... },
            "monthly_data": [ ... ],
            "raw_hourly": [ ... ] (Optional, for ML)
        }
    """
    # Setup client with longer cache since historical data doesn't change often
    # but we want to refresh if user requests explicit recalc (handled by cache name or clearing)
    client = setup_client(cache_name='.cache_ondemand', expire_after=86400) # 24h cache
    
    end_date = datetime.now() - timedelta(days=5)
    start_date = end_date - timedelta(days=365 * years)
    
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": start_date.strftime("%Y-%m-%d"),
        "end_date": end_date.strftime("%Y-%m-%d"),
        "hourly": [
            "temperature_2m", 
            "wind_speed_10m", 
            "wind_direction_10m", 
            "shortwave_radiation", # GHI
            "direct_normal_irradiance",
            "diffuse_radiation",
            "cloud_cover"
        ],
        "timezone": "auto"
    }
    
    try:
        responses = client.weather_api(ARCHIVE_API_URL, params=params)
        response = responses[0]
        
        # Process Hourly Data
        hourly = response.Hourly()
        hourly_data = {
            "date": pd.date_range(
                start=pd.to_datetime(hourly.Time(), unit="s", utc=True),
                end=pd.to_datetime(hourly.TimeEnd(), unit="s", utc=True),
                freq=pd.Timedelta(seconds=hourly.Interval()),
                inclusive="left"
            )
        }
        
        # Indices based on params order
        variables = [
            "temperature_2m", 
            "wind_speed_10m", 
            "wind_direction_10m", 
            "shortwave_radiation",
            "direct_normal_irradiance",
            "diffuse_radiation",
            "cloud_cover"
        ]
        
        for i, var in enumerate(variables):
            hourly_data[var] = hourly.Variables(i).ValuesAsNumpy()
            
        df = pd.DataFrame(data=hourly_data)
        
        # --- Aggregations ---
        
        # 1. Monthly Stats
        df['month'] = df['date'].dt.month
        monthly_stats = []
        
        for month in range(1, 13):
            m_df = df[df['month'] == month]
            if m_df.empty: continue
            
            # Solar: Sum(GHI) Wh/m2 -> kWh/m2
            # GHI is instantaneous power (W/m2). Hourly data sum implicitly = Energy (Wh/m2)
            total_ghi_wh = m_df['shortwave_radiation'].sum()
            total_ghi_kwh = total_ghi_wh / 1000.0
            
            # Wind: Mean Speed
            avg_wind = m_df['wind_speed_10m'].mean()
            
            # Temp: Mean
            avg_temp = m_df['temperature_2m'].mean()
            
            # Cloud: Mean
            avg_cloud = m_df['cloud_cover'].mean()
            
            monthly_stats.append({
                "month": month,
                "avg_wind": float(avg_wind) if not pd.isna(avg_wind) else 0.0,
                "total_solar_kwh_m2": float(total_ghi_kwh) if not pd.isna(total_ghi_kwh) else 0.0,
                "avg_temp": float(avg_temp) if not pd.isna(avg_temp) else 0.0,
                "avg_cloud": float(avg_cloud) if not pd.isna(avg_cloud) else 0.0
            })
            
        # 2. Annual Summary
        annual_summary = {
            "avg_wind": float(df['wind_speed_10m'].mean()),
            "avg_temp": float(df['temperature_2m'].mean()),
            "total_solar_kwh_m2": float(df['shortwave_radiation'].sum() / 1000.0), # Annual total
            "daily_avg_solar_kwh_m2": float((df['shortwave_radiation'].sum() / 1000.0) / 365.0)
        }
        
        # 3. Raw Data (For ML - condensed)
        # return limited columns or full depending on need. `solar_service` needed: time, ghi, temp, cloud
        raw_export = []
        # Optimization: Don't export all rows if not needed, but ML needs them.
        # Check performance impact? 8760 rows is small.
        # But `solar_service` logic built a list of dicts.
        
        return {
            "annual_summary": annual_summary,
            "monthly_data": monthly_stats,
            "raw_dataframe": df # Keeping DF internally might be complex to serialize, convert on usage
        }
        
    except Exception as e:
        print(f"OnDemand Fetch Error: {e}")
        return {"error": str(e)}

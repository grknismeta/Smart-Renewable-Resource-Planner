import time
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, Union

from sqlalchemy.orm import Session
from ..db import models
from .solar_service import get_historical_hourly_solar_data
# Import wind calculation - get_historical_hourly_wind_data does not exist, using get_wind_speed_from_coordinates
from .wind_service import get_wind_speed_from_coordinates

class GridService:
    def __init__(self):
        # Default Turkey Bounds
        self.TURKEY_BOUNDS = {
            "lat_min": 36.0,
            "lat_max": 42.0,
            "lon_min": 26.0,
            "lon_max": 44.0,
        }

    def _calculate_logistics_score(self, lat: float) -> float:
        """
        Simulates logistics score based on distance from center.
        """
        distance_factor = abs(lat - (self.TURKEY_BOUNDS["lat_max"] + self.TURKEY_BOUNDS["lat_min"]) / 2)
        score = max(0.4, 1.0 - (distance_factor / 10.0))
        return round(score, 2)

    def perform_grid_analysis(
        self,
        db: Session,
        resource_type: str,
        lat_min: Optional[float] = None,
        lat_max: Optional[float] = None,
        lon_min: Optional[float] = None,
        lon_max: Optional[float] = None,
        step: float = 0.5
    ):
        """
        Performs grid scan and saves results to DB with dynamic bounds.
        """
        start_lat = lat_min if lat_min is not None else self.TURKEY_BOUNDS["lat_min"]
        end_lat = lat_max if lat_max is not None else self.TURKEY_BOUNDS["lat_max"]
        start_lon = lon_min if lon_min is not None else self.TURKEY_BOUNDS["lon_min"]
        end_lon = lon_max if lon_max is not None else self.TURKEY_BOUNDS["lon_max"]

        print(f"\n--- START: Grid Scan ({resource_type}) ---")
        print(f"Bounds: Lat[{start_lat}-{end_lat}], Lon[{start_lon}-{end_lon}], Step: {step}")

        start_time = datetime.now()
        total_points = 0
        new_data_count = 0

        current_lat = start_lat

        while current_lat <= end_lat:
            current_lon = start_lon
            
            while current_lon <= end_lon:
                
                lat = round(current_lat, 2)
                lon = round(current_lon, 2)
                total_points += 1
                
                # Check DB for existing analysis
                existing_analysis: Optional[models.GridAnalysis] = db.query(models.GridAnalysis).filter(
                    models.GridAnalysis.latitude == lat,
                    models.GridAnalysis.longitude == lon,
                    models.GridAnalysis.type == resource_type
                ).first()
                
                should_recalculate = True
                
                if existing_analysis:
                    if existing_analysis.overall_score > 0.0:
                         if existing_analysis.updated_at and (datetime.now() - existing_analysis.updated_at) < timedelta(days=30):
                             should_recalculate = False

                if not should_recalculate:
                    current_lon += step
                    continue
                
                print(f" -> Calculation: {lat}, {lon}")
                
                 # Fetch Data & ML Prediction
                data: Dict[str, Any] = {"error": "API not called"}
                
                retry_attempts = 3
                for attempt in range(retry_attempts):
                    try:
                        data_result = None
                        if resource_type == "Solar":
                            data_result = get_historical_hourly_solar_data(lat, lon)
                        elif resource_type == "Wind":
                            # get_wind_speed_from_coordinates returns float (e.g. 6.0) currently
                            val = get_wind_speed_from_coordinates(lat, lon)
                            if isinstance(val, (int, float)):
                                data_result = {
                                    "avg_wind_speed_ms": float(val),
                                    "future_prediction": {} 
                                }
                            elif isinstance(val, dict):
                                data_result = val
                        else:
                            data_result = {"error": "Unknown resource type"}
                            
                        if isinstance(data_result, dict):
                            data = data_result
                        else:
                            data = {"error": f"Invalid return type: {type(data_result)}"}
                            
                        if "error" not in data:
                            break
                        
                        if attempt < retry_attempts - 1 and "429 Client Error" in data.get("error", ""):
                            wait_time = 2 ** attempt * 5
                            print(f"   [WARN]: 429 Error. Waiting {wait_time}s...")
                            time.sleep(wait_time)
                        else:
                            break 
                    except Exception as e:
                        data = {"error": str(e)}
                        break
                
                # Scoring
                potential = data.get("annual_total_ghi_kwh", 0.0) if resource_type == "Solar" else data.get("avg_wind_speed_ms", 0.0)
                predicted_data = data.get("future_prediction", {}).get("monthly_predictions", []) 
                
                if "error" in data:
                    print(f"   [RESULT]: Failed: {data['error']}")
                    overall_score = 0.0 
                    logistics_score = 0.0
                else:
                    logistics_score = self._calculate_logistics_score(lat)
                    overall_score = float(potential) * logistics_score 
                
                new_data_count += 1
                
                if existing_analysis:
                    existing_analysis.annual_potential_kwh_m2 = potential if resource_type == "Solar" else None
                    existing_analysis.avg_wind_speed_ms = potential if resource_type == "Wind" else None
                    existing_analysis.logistics_score = logistics_score
                    existing_analysis.predicted_monthly_data = predicted_data
                    existing_analysis.overall_score = overall_score
                    existing_analysis.updated_at = datetime.now()
                else:
                    db_grid = models.GridAnalysis(
                        latitude=lat,
                        longitude=lon,
                        type=resource_type,
                        annual_potential_kwh_m2=potential if resource_type == "Solar" else None,
                        avg_wind_speed_ms=potential if resource_type == "Wind" else None,
                        logistics_score=logistics_score,
                        predicted_monthly_data=predicted_data,
                        overall_score=overall_score,
                    )
                    db.add(db_grid)
                
                try:
                    db.commit()
                except Exception as e:
                    print(f"   [ERROR]: DB Commit failed: {e}")
                    db.rollback()
                
                current_lon += step
                
                # Rate Limiting
                time.sleep(1) # Reduced to 1s for service
            
            current_lat += step

        duration = (end_time - start_time).total_seconds() / 60
        print(f"\n--- Grid Scan Complete ({resource_type}) ---")
        print(f"Total Points Checked: {total_points}")
        print(f"New/Updated Points: {new_data_count}")
        print(f"Duration: {duration:.1f} minutes.")

    def calculate_and_update_from_local_db(self, db: Session):
        """
        Uses LOCAL HourlyWeatherData to populate GridAnalysis.
        BROADCASTS Province data to all its Districts to ensure full coverage.
        Calculates REAL monthly averages.
        """
        from sqlalchemy import func, extract
        from datetime import datetime
        from ..core.constants import TURKEY_CITIES
        
        print("\n[GridService] Starting Local Aggregation (Real Monthly + Broadcast)...")
        start_time = datetime.now()
        
        # 1. Calculate Monthly Stats per PROVINCE (city_name)
        # We assume HourlyWeatherData is mostly Province-based.
        # Structure: { "Adana": { "Wind": {1: 3.5, 2: 4.0...}, "Solar": {1: 120, ...} } }
        
        print("[GridService] step 1: Aggregating Weather Data by Province & Month...")
        
        # We need to process Wind and Solar separately or together.
        # Group by City and Month.
        # PostgreSQL extract('month', ...) kullanılır.
        # ~150k satır için SQL aggregation tercih edilir.
        # Basit yaklaşım: önce tüm şehir adlarını al.
        
        unique_cities = db.query(models.HourlyWeatherData.city_name).distinct().all()
        unique_cities = [c[0] for c in unique_cities]
        
        province_stats = {} 
        
        for city in unique_cities:
            # Get all data for this city
            # Optional: Limit to last year? .filter(models.HourlyWeatherData.timestamp >= ...)
            # For now take all available history for "Average"
            
            raw_data = db.query(
                models.HourlyWeatherData.timestamp,
                models.HourlyWeatherData.wind_speed_100m,
                models.HourlyWeatherData.shortwave_radiation
            ).filter(
                models.HourlyWeatherData.city_name == city
            ).all()
            
            p_data = {
                "wind_sums": {}, "wind_counts": {},
                "solar_sums": {} # Sum of Solar Radiation (Wh/m2)
            }
            
            for row in raw_data:
                m = row.timestamp.month
                
                # Wind
                w = row.wind_speed_100m or 0.0
                p_data["wind_sums"][m] = p_data["wind_sums"].get(m, 0.0) + w
                p_data["wind_counts"][m] = p_data["wind_counts"].get(m, 0) + 1
                
                # Solar
                s = row.shortwave_radiation or 0.0
                p_data["solar_sums"][m] = p_data["solar_sums"].get(m, 0.0) + s
            
            # Finalize Monthly Avgs
            final_months = {}
            total_annual_solar = 0.0
            total_annual_wind_accum = 0.0
            total_annual_wind_count = 0
            
            # Map month numbers to Turkish names
            month_map = {
                1: "Ocak", 2: "Şubat", 3: "Mart", 4: "Nisan", 5: "Mayıs", 6: "Haziran",
                7: "Temmuz", 8: "Ağustos", 9: "Eylül", 10: "Ekim", 11: "Kasım", 12: "Aralık"
            }
            
            for m in range(1, 13):
                m_name = month_map[m]
                
                # Wind Avg
                w_sum = p_data["wind_sums"].get(m, 0.0)
                w_cnt = p_data["wind_counts"].get(m, 0)
                w_avg = (w_sum / w_cnt) if w_cnt > 0 else 0.0
                
                # Solar Total (Monthly) -> Convert Wh to kWh
                # Note: 'shortwave_radiation' is usually instantaneous Power (W/m2) or Hourly Energy?
                # If it's W/m2 (Power) from ERA5 hourly, then Sum of 24h = Daily Energy (Wh/m2).
                # Sum of Month = Monthly Energy (Wh/m2).
                
                s_sum = p_data["solar_sums"].get(m, 0.0)
                s_kwh = s_sum / 1000.0
                
                final_months[m_name] = {
                    "wind": w_avg,
                    "solar": s_kwh
                }
                
                total_annual_solar += s_kwh
                total_annual_wind_accum += w_sum
                total_annual_wind_count += w_cnt

            avg_annual_wind = (total_annual_wind_accum / total_annual_wind_count) if total_annual_wind_count > 0 else 0.0
            
            province_stats[city] = {
                "monthly": final_months,
                "annual_solar": total_annual_solar,
                "annual_wind": avg_annual_wind
            }
            
        print(f"[GridService] Aggregated data for {len(province_stats)} provinces.")

        # 2. MATCH & DISTRIBUTE to GridAnalysis (All Districts)
        # We iterate over TURKEY_CITIES (which contains all districts)
        # If a district's province is in our stats, we use that data.
        
        updated_count = 0
        
        for location_def in TURKEY_CITIES:
            p_name = location_def["province"]
            
            # Find stats for this province (Case insensitive?)
            # Database cities might differ slightly? 'istanbul' vs 'İstanbul'
            # Let's try direct match first, then normalized
            
            stats = province_stats.get(p_name)
            if not stats:
                continue # No data for this province yet
                
            # Prepare Data
            lat = location_def["lat"]
            lon = location_def["lon"]
            
            monthly_wind = {k: v["wind"] for k, v in stats["monthly"].items()}
            monthly_solar = {k: v["solar"] for k, v in stats["monthly"].items()}
            # Add "Ortalama"
            monthly_wind["Ortalama"] = stats["annual_wind"]
            monthly_solar["Ortalama"] = stats["annual_solar"] / 12.0
            
            # Logistics Score
            log_score = self._calculate_logistics_score(lat)
            
            # --- WIND UPDATE ---
            wind_val = stats["annual_wind"]
            wind_score = min(100.0, wind_val * 10) * log_score
            self._upsert_grid_analysis(
                db, lat, lon, "Wind", wind_val, None, wind_score, log_score, monthly_wind
            )
            
            # --- SOLAR UPDATE ---
            solar_val = stats["annual_solar"]
            solar_score = min(100.0, (solar_val / 20.0)) * log_score
            self._upsert_grid_analysis(
                db, lat, lon, "Solar", None, solar_val, solar_score, log_score, monthly_solar
            )
            
            updated_count += 1
            
        try:
            db.commit()
            print(f"[GridService] Broadcast Complete. Updated {updated_count} grid points (Districts included) in {(datetime.now() - start_time).total_seconds():.1f}s")
        except Exception as e:
            print(f"[GridService] Error committing: {e}")
            db.rollback()

    def _upsert_grid_analysis(
        self, db: Session, lat, lon, type_str, wind_val, solar_val, overall, log_score, monthly
    ):
        # Optional: Snap to grid? Or use exact city coords.
        # Sticking to exact coords from HourlyData is better for "City" based reports.
        
        existing = db.query(models.GridAnalysis).filter(
            models.GridAnalysis.latitude == lat,
            models.GridAnalysis.longitude == lon,
            models.GridAnalysis.type == type_str
        ).first()
        
        if existing:
            existing.avg_wind_speed_ms = wind_val
            existing.annual_potential_kwh_m2 = solar_val
            existing.overall_score = overall
            existing.logistics_score = log_score
            existing.predicted_monthly_data = monthly
            existing.updated_at = datetime.now()
        else:
            new_rec = models.GridAnalysis(
                latitude=lat,
                longitude=lon,
                type=type_str,
                avg_wind_speed_ms=wind_val,
                annual_potential_kwh_m2=solar_val,
                overall_score=overall,
                logistics_score=log_score,
                predicted_monthly_data=monthly
            )
            db.add(new_rec)

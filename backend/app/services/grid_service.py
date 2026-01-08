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

        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds() / 60
        print(f"\n--- Grid Scan Complete ({resource_type}) ---")
        print(f"Total Points Checked: {total_points}")
        print(f"New/Updated Points: {new_data_count}")
        print(f"Duration: {duration:.1f} minutes.")

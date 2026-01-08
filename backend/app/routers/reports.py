from datetime import datetime, timedelta
from typing import List, Dict, cast

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app import auth
from app.db import models
from app.schemas import schemas
from app.db.database import get_system_db, get_db
# Yeni yapıdaki fonksiyonları ve veri setini import ediyoruz
from app.core.constants import TURKEY_CITIES, get_location_by_name

router = APIRouter(prefix="/reports")

# Bölge -> İl listesi haritası (Yeni province alanıyla eşleşir)
REGION_CITIES: Dict[str, List[str]] = {
    "marmara": [
        "İstanbul", "Edirne", "Kırklareli", "Tekirdağ", "Kocaeli",
        "Sakarya", "Yalova", "Balıkesir", "Bursa", "Çanakkale", "Bilecik",
    ],
    "ege": [
        "İzmir", "Manisa", "Aydın", "Muğla", "Denizli", "Uşak", "Kütahya", "Afyonkarahisar",
    ],
    "akdeniz": [
        "Antalya", "Mersin", "Adana", "Hatay", "Osmaniye", "Isparta", "Burdur", "Kahramanmaraş",
    ],
    "iç anadolu": [
        "Ankara", "Eskişehir", "Konya", "Kayseri", "Sivas", "Aksaray",
        "Karaman", "Kırıkkale", "Kırşehir", "Niğde", "Nevşehir", "Yozgat", "Çankırı",
    ],
    "karadeniz": [
        "Trabzon", "Rize", "Artvin", "Giresun", "Ordu", "Samsun", "Sinop",
        "Gümüşhane", "Bayburt", "Tokat", "Amasya", "Çorum", "Bolu",
        "Kastamonu", "Bartın", "Zonguldak", "Düzce", "Karabük",
    ],
    "doğu anadolu": [
        "Erzurum", "Erzincan", "Kars", "Ağrı", "Iğdır", "Van", "Muş",
        "Bitlis", "Hakkari", "Tunceli", "Bingöl", "Malatya", "Elazığ", "Ardahan",
    ],
    "güneydoğu anadolu": [
        "Gaziantep", "Şanlıurfa", "Diyarbakır", "Mardin", "Batman", "Siirt", "Şırnak", "Adıyaman", "Kilis",
    ],
}

# Hızlı arama için İl -> Bölge haritası
CITY_TO_REGION: Dict[str, str] = {
    city.casefold(): region for region, cities in REGION_CITIES.items() for city in cities
}

REGION_ALIASES = {
    "ic anadolu": "iç anadolu",
    "iç anadolu bölgesi": "iç anadolu",
    "dogu anadolu": "doğu anadolu",
    "güneydogu anadolu": "güneydoğu anadolu",
    "guneydogu anadolu": "güneydoğu anadolu",
    "karadeniz bölgesi": "karadeniz",
    "ege bölgesi": "ege",
    "akdeniz bölgesi": "akdeniz",
    "marmara bölgesi": "marmara",
}

def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    from math import radians, sin, cos, sqrt, atan2
    R = 6371.0
    d_lat = radians(lat2 - lat1)
    d_lon = radians(lon2 - lon1)
    a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c

def _normalize(value: str) -> str:
    # Türkçe karakter düzeltmesi (İ -> i)
    value = value.replace("İ", "i").replace("I", "ı")
    key = value.strip().casefold()
    return REGION_ALIASES.get(key, key)

def _find_nearest_location(lat: float, lon: float) -> str:
    """Koordinata en yakın lokasyonun benzersiz adını (name - İlçe veya Merkez) döner."""
    best = None
    best_dist = 1e9
    for loc in TURKEY_CITIES:
        dist = _haversine(lat, lon, loc["lat"], loc["lon"])
        if dist < best_dist:
            best_dist = dist
            best = loc["name"]
    return best or "Bilinmiyor"

@router.get("/regional", response_model=schemas.RegionalReportResponse)
def get_regional_report(
    region: str = Query(..., description="Ege, Marmara vb. veya 'Tümü'"),
    type: str = Query("Wind", description="Solar veya Wind"),
    interval: str = Query("Yıllık", description="Yıllık, Aylık, Anlık"),
    limit: int = Query(400, ge=1, le=500),
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user),
):
    region_key = _normalize(region)
    type_norm = "Solar" if type.lower().startswith("s") else "Wind"
    is_all_regions = region_key in {"tümü", "tum", "tumu", "all", "tumü"}

    if region_key not in REGION_CITIES and not is_all_regions:
        raise HTTPException(status_code=400, detail="Geçersiz bölge adı")

    items: List[schemas.RegionalSite] = []
    location_best: Dict[str, Dict] = {}

    # --- ANLIK VERİ SENARYOSU ---
    if interval == "Anlık":
        # Son 24 saatteki en güncel veriyi çekelim
        cutoff = datetime.utcnow() - timedelta(hours=24)
        
        # En son timestamp'i bulmak için subquery
        latest_ts_sub = db.query(func.max(models.HourlyWeatherData.timestamp)).scalar()
        if not latest_ts_sub:
             # Hiç veri yoksa boş dön
             return schemas.RegionalReportResponse(
                region=region.title(),
                type=type_norm,
                generated_at=datetime.utcnow(),
                period_days=1,
                items=[],
                stats=None
            )
            
        target_ts = latest_ts_sub # En güncel saat
        
        hourly_query = db.query(
            models.HourlyWeatherData.city_name,
            models.HourlyWeatherData.district_name,
            models.HourlyWeatherData.latitude,
            models.HourlyWeatherData.longitude,
            models.HourlyWeatherData.wind_speed_100m, # Wind
            models.HourlyWeatherData.shortwave_radiation, # solar
            models.HourlyWeatherData.temperature_2m,
        ).filter(models.HourlyWeatherData.timestamp == target_ts).all()
        
        for r in hourly_query:
             # İl/Bölge Filtreleme
             # city_name muhtemelen İl adıdır (SystemDB yapısına göre)
             loc_data = get_location_by_name(r.city_name)
             if not loc_data: continue

             city_province = loc_data["province"]
             city_region = CITY_TO_REGION.get(city_province.casefold())

             if not is_all_regions and city_region != region_key:
                continue
             
             # Değer Belirleme
             display_val = 0.0
             display_unit = ""
             score = 0.0
             
             if type_norm == "Wind":
                 display_val = float(r.wind_speed_100m or 0.0)
                 display_unit = "m/s"
                 score = display_val * 10 # Basit skorlama
             else: # Solar
                 display_val = float(r.shortwave_radiation or 0.0)
                 display_unit = "W/m²"
                 score = display_val / 5.0 # Basit skorlama
             
             # Listeye Ekle
             # Aynı şehir/ilçe tekrar edebilir mi? HourlyWeatherData il bazlıysa unique'dir.
             items.append(
                schemas.RegionalSite(
                    city=city_province,
                    district=r.district_name or loc_data["district"],
                    type=type_norm,
                    latitude=float(r.latitude or loc_data["lat"]),
                    longitude=float(r.longitude or loc_data["lon"]),
                    overall_score=score,
                    annual_potential_kwh_m2=None, # Anlık raporda yıllık yok
                    display_value=display_val,
                    display_unit=display_unit,
                    rank=0
                )
             )

    # --- YILLIK / AYLIK VERİ SENARYOSU (GridAnalysis) ---
    else:
        # Mevcut mantık (GridAnalysis)
        rows: List[models.GridAnalysis] = (
            db.query(models.GridAnalysis)
            .filter(
                models.GridAnalysis.type == type_norm,
                models.GridAnalysis.overall_score > 0.0,
            )
            .all()
        )

        for row in rows:
            r_lat = cast(float, row.latitude)
            r_lon = cast(float, row.longitude)
            
            matched_name = _find_nearest_location(r_lat, r_lon)
            loc_data = get_location_by_name(matched_name)
            
            if not loc_data:
                continue

            city_province = loc_data["province"]
            city_region = CITY_TO_REGION.get(city_province.casefold())

            if not is_all_regions and city_region != region_key:
                continue

            current_score = cast(float, row.overall_score)
            annual_pot = cast(float, row.annual_potential_kwh_m2 or 0.0)
            avg_wind = cast(float, row.avg_wind_speed_ms or 0.0)
            
            # Display Value Hesapla
            disp_val = 0.0
            disp_unit = ""
            
            # JSON'dan Aylık Veri Çekme
            # JSON'dan Aylık Veri Çekme
            monthly_data = row.predicted_monthly_data or {}
            
            # --- FIX: Handle List vs Dict ---
            # Old API data might be: [{"month": "September", "prediction": ...}, ...]
            # New Aggregation is: {"Ocak": 123.4, ...}
            
            val_monthly = None
            
            month_map = {
                1: "Ocak", 2: "Şubat", 3: "Mart", 4: "Nisan", 5: "Mayıs", 6: "Haziran",
                7: "Temmuz", 8: "Ağustos", 9: "Eylül", 10: "Ekim", 11: "Kasım", 12: "Aralık"
            }
            current_month_index = datetime.now().month
            current_month_name = month_map.get(current_month_index, "Ocak")

            if isinstance(monthly_data, dict):
                 val_monthly = monthly_data.get(current_month_name)
            elif isinstance(monthly_data, list):
                 # Try to find month in list
                 # Assuming structure: {"month": "MonthName", ...}
                 # English names might be present.
                 # Let's just fallback to None if it's a list for now, or match if possible.
                 pass

            if type_norm == "Wind":
                 if interval == "Aylık":
                     if val_monthly is not None:
                         disp_val = float(val_monthly)
                     else:
                         disp_val = avg_wind # Fallback
                         
                     disp_unit = f"m/s ({current_month_name})"
                 else:
                     disp_val = avg_wind
                     disp_unit = "m/s (Yıllık Ort.)"
            else:
                # Solar
                if interval == "Aylık":
                    if val_monthly is not None:
                         disp_val = float(val_monthly)
                    else:
                        # Fallback: Yıllık / 12
                        disp_val = annual_pot / 12.0
                        
                    disp_unit = f"kWh/m² ({current_month_name})"
                else: # Yıllık
                    disp_val = annual_pot
                    disp_unit = "kWh/m² (Yıllık)"

            # Best location logic
            if matched_name not in location_best or current_score > location_best[matched_name]["score"]:
                location_best[matched_name] = {
                    "city": city_province,
                    "district": loc_data["district"],
                    "latitude": loc_data["lat"],
                    "longitude": loc_data["lon"],
                    "score": current_score,
                    "annual_potential": annual_pot,
                    "avg_wind": cast(float | None, row.avg_wind_speed_ms),
                    "display_val": disp_val,
                    "display_unit": disp_unit
                }
        
        # GridAnalysis döngüsü bitti, location_best->items çevir
        for data in location_best.values():
            items.append(
                schemas.RegionalSite(
                    city=data["city"],
                    district=data["district"],
                    type=type_norm,
                    latitude=data["latitude"],
                    longitude=data["longitude"],
                    overall_score=data["score"],
                    annual_potential_kwh_m2=data["annual_potential"],
                    avg_wind_speed_ms=data["avg_wind"],
                    annual_solar_irradiance_kwh_m2=data["annual_potential"] if type_norm == "Solar" else None,
                    display_value=data["display_val"],
                    display_unit=data["display_unit"],
                    rank=0,
                )
            )

    # Ortak Sıralama ve Limit
    items.sort(key=lambda x: x.overall_score, reverse=True)
    items = items[:limit]

    for i, it in enumerate(items):
        it.rank = i + 1

    if not items:
        # Boş ise stats None dönebilir
        return schemas.RegionalReportResponse(
            region=region.title(),
            type=type_norm,
            generated_at=datetime.utcnow(),
            period_days=365 if interval != "Anlık" else 1,
            items=[],
            stats=None,
        )

    # İstatistikler
    scores = [i.overall_score for i in items]
    stats = schemas.RegionalStats(
        max_score=max(scores),
        min_score=min(scores),
        avg_score=sum(scores) / len(scores),
        site_count=len(items),
    )

    return schemas.RegionalReportResponse(
        region=region.title(),
        type=type_norm,
        generated_at=datetime.utcnow(),
        period_days=30 if interval == "Aylık" else (1 if interval == "Anlık" else 365),
        items=items,
        stats=stats,
    )

@router.get("/interpolated-map", response_model=List[Dict[str, float]])
def get_interpolated_map(
    type: str = Query(..., description="Solar veya Wind"),
    resolution: float = Query(0.1, description="Grid resolution (degrees)"),
    system_db: Session = Depends(get_system_db)
):
    """
    Tüm Türkiye için enterpolasyon ile oluşturulmuş sürekli ısı haritası verisi döndürür.
    """
    from app.services.interpolation_service import InterpolationService
    
    # 1. Mevcut Tüm Veriyi Topla (Grid + Hourly fallback)
    
    # A. GridAnalysis Verileri
    grid_query = system_db.query(models.GridAnalysis).filter(
        models.GridAnalysis.type == type,
        models.GridAnalysis.overall_score > 0
    ).all()
    
    points = []
    for g in grid_query:
        val = float(g.overall_score)
        points.append({
            "lat": float(g.latitude), 
            "lon": float(g.longitude), 
            "value": val
        })
        
    # B. Eksik Bölgeler İçin Hourly Data (Fallback)
    # Temperature için ana veri kaynağı burası olabilir (GridAnalysis'de Temp yoksa)
    
    cutoff = datetime.utcnow() - timedelta(hours=72)
    
    # Sorguyu dinamik yap (Type'a göre select değişebilir)
    hourly_query = system_db.query(
        models.HourlyWeatherData.city_name,
        func.max(models.HourlyWeatherData.latitude).label("lat"),
        func.max(models.HourlyWeatherData.longitude).label("lon"),
        func.avg(models.HourlyWeatherData.wind_speed_100m).label("avg_wind"),
        func.avg(models.HourlyWeatherData.temperature_2m).label("avg_temp"),
        func.sum(models.HourlyWeatherData.shortwave_radiation).label("total_rad")
    ).filter(models.HourlyWeatherData.timestamp >= cutoff).group_by(models.HourlyWeatherData.city_name).all()
    
    for h in hourly_query:
        # Puanlama mantığı
        val = 0.0
        if type == "Wind":
             # 10 m/s -> ~100 puan
             val = float(h.avg_wind or 0) * 10
        elif type == "Solar":
             # Wh -> Score tahmini
             solar_est = (float(h.total_rad or 0) * 0.12)
             val = solar_est / 20.0
        elif type == "Temperature":
             # Doğrudan derece
             val = float(h.avg_temp or 0)
             
        points.append({
            "lat": float(h.lat),
            "lon": float(h.lon),
            "value": val
        })
        
    if not points:
        return []

    # 2. Enterpolasyon Servisini Çağır
    try:
        # IDW Power ayarı (1.5 daha yumuşak)
        interpolated_grid = InterpolationService.interpolate_points(
            points, 
            value_key="value", 
            resolution=resolution,
            power=1.5
        )
        return interpolated_grid
    except Exception as e:
        print(f"Interpolasyon hatası: {e}")
        return []
from datetime import datetime, timedelta
from typing import List, Dict, cast

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from backend import auth
from backend.db import models
from backend.schemas import schemas
from backend.db.database import get_system_db, get_db
# Yeni yapıdaki fonksiyonları ve veri setini import ediyoruz
from ..turkey_cities import TURKEY_CITIES, get_location_by_name

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
    limit: int = Query(400, ge=1, le=500),
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user),
):
    region_key = _normalize(region)
    type_norm = "Solar" if type.lower().startswith("s") else "Wind"
    is_all_regions = region_key in {"tümü", "tum", "tumu", "all", "tumü"}

    if region_key not in REGION_CITIES and not is_all_regions:
        raise HTTPException(status_code=400, detail="Geçersiz bölge adı")

    # 1. Önce Grid Analiz verilerini kontrol ediyoruz (10 Yıllık Projeksiyon)
    rows: List[models.GridAnalysis] = (
        db.query(models.GridAnalysis)
        .filter(
            models.GridAnalysis.type == type_norm,
            models.GridAnalysis.overall_score > 0.0,
        )
        .order_by(models.GridAnalysis.overall_score.desc())
        .all()
    )

    items: List[schemas.RegionalSite] = []
    location_best: Dict[str, Dict] = {}

    for row in rows:
        r_lat = cast(float, row.latitude)
        r_lon = cast(float, row.longitude)
        
        # En yakın yerleşimi bul (Örn: "Salihli" veya "Manisa")
        matched_name = _find_nearest_location(r_lat, r_lon)
        loc_data = get_location_by_name(matched_name)
        
        if not loc_data:
            continue

        # Bölge Kontrolü: Province (İl) üzerinden
        city_province = loc_data["province"]
        city_region = CITY_TO_REGION.get(city_province.casefold())

        if not is_all_regions and city_region != region_key:
            continue

        current_score = cast(float, row.overall_score)
        
        # Lokasyon bazında en iyi skoru güncelle
        if matched_name not in location_best or current_score > location_best[matched_name]["score"]:
            location_best[matched_name] = {
                "city": city_province,
                "district": loc_data["district"],
                "latitude": loc_data["lat"],
                "longitude": loc_data["lon"],
                "score": current_score,
                "annual_potential": cast(float | None, row.annual_potential_kwh_m2),
                "avg_wind": cast(float | None, row.avg_wind_speed_ms)
            }

    # 2. Eksik şehirleri Hourly verilerden (Son 72 saat) tamamla (Coverage Fill)
    cutoff = datetime.utcnow() - timedelta(hours=72)
    hourly_query = db.query(
        models.HourlyWeatherData.city_name.label("name"),
        func.avg(models.HourlyWeatherData.wind_speed_100m).label("avg_wind"),
        func.sum(models.HourlyWeatherData.shortwave_radiation).label("total_rad")
    ).filter(models.HourlyWeatherData.timestamp >= cutoff).group_by(models.HourlyWeatherData.city_name).all()

    for r in hourly_query:
        # Şehir zaten GridAnalysis'ten geldiyse atla (Orası daha hassas)
        # Ancak burada isim eşleştirmesi önemli: Hourly'deki isim turkey_cities'teki "name" ile aynı olmalı.
        # Genelde aynıdır. Yine de nearest_location ile normalize edelim veya direkt bakalım.
        loc_data = get_location_by_name(r.name)
        if not loc_data: continue
        
        # GridAnalysis'te zaten bulunduysa atla
        if loc_data["name"] in location_best:
            continue

        city_province = loc_data["province"]
        city_region = CITY_TO_REGION.get(city_province.casefold())

        if not is_all_regions and city_region != region_key:
            continue

        # Skorlama (GridService ile uyumlu ölçekleme)
        # Solar: 3 günlük toplam (Wh/m2) -> Yıllık Tahmin (kWh/m2)
        # Kabaca: (TotalWh / 3) * 365 / 1000 ~= TotalWh * 0.12
        # Wind: Avg Speed (m/s) -> Direkt hız puanı (Lojistik faktörü varsayılan 1.0)
        
        solar_est = (float(r.total_rad) * 0.12) if r.total_rad else 0
        wind_est = float(r.avg_wind) if r.avg_wind else 0
        
        score = wind_est if type_norm == "Wind" else solar_est
        
        location_best[loc_data["name"]] = {
            "city": city_province,
            "district": loc_data["district"],
            "latitude": loc_data["lat"],
            "longitude": loc_data["lon"],
            "score": score,
            "annual_potential": solar_est if type_norm == "Solar" else None,
            "avg_wind": wind_est if type_norm == "Wind" else None
        }

    # Sözlükteki sonuçları şemaya dönüştür
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
                rank=0,
            )
        )

    # Sıralama ve Limit
    items.sort(key=lambda x: x.overall_score, reverse=True)
    items = items[:limit]

    for i, it in enumerate(items):
        it.rank = i + 1

    if not items:
        return schemas.RegionalReportResponse(
            region=region.title(),
            type=type_norm,
            generated_at=datetime.utcnow(),
            period_days=365,
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
        period_days=365,
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
    from backend.services.interpolation_service import InterpolationService
    
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
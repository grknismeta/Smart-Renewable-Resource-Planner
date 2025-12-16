from datetime import datetime, timedelta
from typing import List, Dict, cast

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from .. import models, schemas, auth
from ..database import get_system_db
from sqlalchemy import func

router = APIRouter(prefix="/reports")

# Bölge -> Şehir listesi haritası
REGION_CITIES: Dict[str, List[str]] = {
    "marmara": [
        "İstanbul",
        "Edirne",
        "Kırklareli",
        "Tekirdağ",
        "Kocaeli",
        "Sakarya",
        "Yalova",
        "Balıkesir",
        "Bursa",
        "Çanakkale",
        "Bilecik",
    ],
    "ege": [
        "İzmir",
        "Manisa",
        "Aydın",
        "Muğla",
        "Denizli",
        "Uşak",
        "Kütahya",
        "Afyonkarahisar",
    ],
    "akdeniz": [
        "Antalya",
        "Mersin",
        "Adana",
        "Hatay",
        "Osmaniye",
        "Isparta",
        "Burdur",
        "Kahramanmaraş",
    ],
    "iç anadolu": [
        "Ankara",
        "Eskişehir",
        "Konya",
        "Kayseri",
        "Sivas",
        "Aksaray",
        "Karaman",
        "Kırıkkale",
        "Kırşehir",
        "Niğde",
        "Nevşehir",
        "Yozgat",
        "Çankırı",
    ],
    "karadeniz": [
        "Trabzon",
        "Rize",
        "Artvin",
        "Giresun",
        "Ordu",
        "Samsun",
        "Sinop",
        "Gümüşhane",
        "Bayburt",
        "Tokat",
        "Amasya",
        "Çorum",
        "Bolu",
        "Kastamonu",
        "Bartın",
        "Zonguldak",
        "Düzce",
    ],
    "doğu anadolu": [
        "Erzurum",
        "Erzincan",
        "Kars",
        "Ağrı",
        "Iğdır",
        "Van",
        "Muş",
        "Bitlis",
        "Hakkari",
        "Tunceli",
        "Bingöl",
        "Malatya",
        "Elazığ",
        "Ardahan",
    ],
    "güneydoğu anadolu": [
        "Gaziantep",
        "Şanlıurfa",
        "Diyarbakır",
        "Mardin",
        "Batman",
        "Siirt",
        "Şırnak",
        "Adıyaman",
        "Kilis",
    ],
}

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
    key = value.strip().casefold()
    return REGION_ALIASES.get(key, key)


def _find_nearest_city(lat: float, lon: float) -> str:
    # Fallback simple mapping: choose city whose name has closest lat/lon from turkey_cities
    from ..turkey_cities import TURKEY_CITIES

    best = None
    best_dist = 1e9
    for city in TURKEY_CITIES:
        dist = _haversine(lat, lon, city["lat"], city["lon"])
        if dist < best_dist:
            best_dist = dist
            best = city["name"]
    return best or "Bilinmiyor"


@router.get("/regional", response_model=schemas.RegionalReportResponse)
def get_regional_report(
    region: str = Query(..., description="Ege, Marmara, Karadeniz vb. veya 'Tümü'"),
    type: str = Query("Wind", description="Solar veya Wind"),
    limit: int = Query(80, ge=1, le=500),
    db: Session = Depends(get_system_db),
    current_user: models.User = Depends(auth.get_current_active_user),
):
    region_key = _normalize(region)
    type_norm = "Solar" if type.lower().startswith("s") else "Wind"

    if region_key not in REGION_CITIES and region_key not in {"tümü", "tum", "tumu", "all", "tumü"}:
        raise HTTPException(status_code=400, detail="Geçersiz bölge adı")

    results: List[models.GridAnalysis] = (
        db.query(models.GridAnalysis)
        .filter(
            models.GridAnalysis.type == type_norm,
            models.GridAnalysis.overall_score > 0.0,
        )
        .order_by(models.GridAnalysis.overall_score.desc())
        .all()
    )

    items: List[schemas.RegionalSite] = []

    def _emit_from_grid(rows: List[models.GridAnalysis]):
        local_items: List[schemas.RegionalSite] = []
        for row in rows:
            lat = cast(float, row.latitude)
            lon = cast(float, row.longitude)
            city_name = _find_nearest_city(lat, lon)
            city_region = CITY_TO_REGION.get(city_name.casefold())

            if region_key not in {"tümü", "tum", "tumu", "all", "tumü"}:
                if city_region != region_key:
                    continue

            annual_potential = cast(float | None, row.annual_potential_kwh_m2)
            avg_wind = cast(float | None, row.avg_wind_speed_ms)
            score = cast(float, row.overall_score)

            local_items.append(
                schemas.RegionalSite(
                    city=city_name,
                    district=None,
                    type=type_norm,
                    latitude=lat,
                    longitude=lon,
                    overall_score=score,
                    annual_potential_kwh_m2=annual_potential,
                    avg_wind_speed_ms=avg_wind,
                    annual_solar_irradiance_kwh_m2=annual_potential,
                    rank=0,
                )
            )
            if len(local_items) >= limit:
                break
        # Rank doldur
        for i, it in enumerate(local_items):
            it.rank = i + 1
        return local_items

    items = _emit_from_grid(results)

    # Fallback: GridAnalysis boş ise saatlik veriden skor hesapla
    if not items:
        # Son 72 saate göre şehir bazlı skorlar
        cutoff = datetime.utcnow() - timedelta(hours=72)

        # type_norm 'Wind' ise rüzgar, 'Solar' ise radyasyon bazlı skor hesapla
        if type_norm == "Wind":
            wind_rows = (
                db.query(
                    models.HourlyWeatherData.city_name.label("city"),
                    func.avg(models.HourlyWeatherData.wind_speed_100m).label("avg_wind"),
                    func.max(models.HourlyWeatherData.wind_speed_100m).label("max_wind"),
                    func.min(models.HourlyWeatherData.wind_speed_100m).label("min_wind"),
                    func.max(models.HourlyWeatherData.latitude).label("lat"),
                    func.max(models.HourlyWeatherData.longitude).label("lon"),
                )
                .filter(models.HourlyWeatherData.timestamp >= cutoff)
                .group_by(models.HourlyWeatherData.city_name)
                .all()
            )

            # Skor = avg_wind * 10 (yaklaşık 0-100 bandına)
            scored = []
            for r in wind_rows:
                city_name = r.city
                city_region = CITY_TO_REGION.get(city_name.casefold())
                if region_key not in {"tümü", "tum", "tumu", "all", "tumü"}:
                    if city_region != region_key:
                        continue
                avg_wind = float(r.avg_wind) if r.avg_wind is not None else 0.0
                score = max(0.0, avg_wind * 10.0)
                scored.append(
                    {
                        "city": city_name,
                        "lat": float(r.lat) if r.lat is not None else 0.0,
                        "lon": float(r.lon) if r.lon is not None else 0.0,
                        "score": score,
                        "avg_wind": avg_wind,
                    }
                )

            scored.sort(key=lambda x: x["score"], reverse=True)
            for i, r in enumerate(scored[:limit]):
                items.append(
                    schemas.RegionalSite(
                        city=r["city"],
                        district=None,
                        type=type_norm,
                        latitude=r["lat"],
                        longitude=r["lon"],
                        overall_score=r["score"],
                        annual_potential_kwh_m2=None,
                        avg_wind_speed_ms=r["avg_wind"],
                        annual_solar_irradiance_kwh_m2=None,
                        rank=i + 1,
                    )
                )
        else:
            solar_rows = (
                db.query(
                    models.HourlyWeatherData.city_name.label("city"),
                    func.sum(models.HourlyWeatherData.shortwave_radiation).label("total_rad"),
                    func.avg(models.HourlyWeatherData.direct_radiation).label("avg_direct"),
                    func.max(models.HourlyWeatherData.latitude).label("lat"),
                    func.max(models.HourlyWeatherData.longitude).label("lon"),
                )
                .filter(models.HourlyWeatherData.timestamp >= cutoff)
                .group_by(models.HourlyWeatherData.city_name)
                .all()
            )

            # Skor = toplam radyasyon (normalize edilmemiş). Kaba bir sıralama için yeterli.
            scored = []
            for r in solar_rows:
                city_name = r.city
                city_region = CITY_TO_REGION.get(city_name.casefold())
                if region_key not in {"tümü", "tum", "tumu", "all", "tumü"}:
                    if city_region != region_key:
                        continue
                total_rad = float(r.total_rad) if r.total_rad is not None else 0.0
                score = max(0.0, total_rad)
                scored.append(
                    {
                        "city": city_name,
                        "lat": float(r.lat) if r.lat is not None else 0.0,
                        "lon": float(r.lon) if r.lon is not None else 0.0,
                        "score": score,
                        "total_rad": total_rad,
                    }
                )

            scored.sort(key=lambda x: x["score"], reverse=True)
            for i, r in enumerate(scored[:limit]):
                items.append(
                    schemas.RegionalSite(
                        city=r["city"],
                        district=None,
                        type=type_norm,
                        latitude=r["lat"],
                        longitude=r["lon"],
                        overall_score=r["score"],
                        annual_potential_kwh_m2=r["total_rad"],
                        avg_wind_speed_ms=None,
                        annual_solar_irradiance_kwh_m2=r["total_rad"],
                        rank=i + 1,
                    )
                )

    if not items:
        return schemas.RegionalReportResponse(
            region=region.title(),
            type=type_norm,
            generated_at=datetime.utcnow(),
            period_days=365,
            items=[],
            stats=None,
        )

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

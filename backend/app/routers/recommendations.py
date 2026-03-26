"""
Akıllı Bölge Önerileri API
===========================

Weibull dağılımı parametrelerini ve istatistiksel analizi kullanarak
Türkiye'deki en iyi rüzgar, güneş ve HES bölgelerini sıralar.

Weibull parametreleri:
  k (şekil)  : rüzgar hızı değişkenliğini gösterir (yüksek k = tutarlı rüzgar)
  λ (ölçek)  : ortalama rüzgar hızıyla ilişkilidir

Kategoriler:
  Güçlü         : v̄ > 7 m/s
  Stabil        : k > 2.5 (tutarlı, düşük varyans)
  Yüksek Sirkülasyon : σ > 3 (değişken ama yoğun)
  Güçsüz        : 3 ≤ v̄ ≤ 5 m/s
  Nadir         : v̄ < 3 m/s
"""

import math
from typing import List, Optional
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Query
from pydantic import BaseModel
from sqlalchemy import text

from app.db.database import SystemSessionLocal
from app.core.logger import logger

router = APIRouter(
    prefix="/recommendations",
    tags=["🧭 Recommendations"],
)


# ── Pydantic Modeller ──────────────────────────────────────────────────────────

class WindRoseData(BaseModel):
    """16 yönlü rüzgar gülü verisi."""
    directions: List[float]   # 0..360 — her dilimin merkezi
    frequencies: List[float]  # Her yöndeki veri sayısı (%)
    avg_speeds: List[float]   # Her yöndeki ortalama hız (m/s)


class RecommendedCity(BaseModel):
    name: str
    lat: float
    lon: float

    # Rüzgar istatistikleri
    avg_wind_speed: Optional[float] = None   # m/s
    max_wind_speed: Optional[float] = None
    wind_category: Optional[str] = None      # Güçlü / Stabil / Yüksek Sirkülasyon / Güçsüz / Nadir
    weibull_k: Optional[float] = None        # Şekil parametresi
    weibull_lambda: Optional[float] = None   # Ölçek parametresi
    wind_std: Optional[float] = None         # Standart sapma
    wind_rose: Optional[WindRoseData] = None

    # Güneş istatistikleri
    avg_radiation: Optional[float] = None    # W/m²
    total_radiation_kwh: Optional[float] = None  # kWh/m²
    solar_category: Optional[str] = None     # Yüksek / Orta / Düşük

    record_count: int = 0
    score: float = 0.0                       # Genel puan (0-100)


class RecommendationsResponse(BaseModel):
    wind_strong: List[RecommendedCity]        # v̄ > 7 m/s
    wind_stable: List[RecommendedCity]        # Yüksek k (tutarlı rüzgar)
    wind_circulation: List[RecommendedCity]   # Yüksek σ (değişken ama yoğun)
    wind_weak: List[RecommendedCity]          # Güçsüz rüzgar
    solar_top: List[RecommendedCity]          # En yüksek ışınım
    solar_irradiance_top: List[RecommendedCity]   # En yüksek anlık ışınım (W/m²)
    wind_annual_efficiency: List[RecommendedCity]  # Yıllık rüzgar verimliliği (k × v̄)
    solar_annual_efficiency: List[RecommendedCity] # Yıllık ışınım verimliliği (toplam kWh/m²)
    generated_at: datetime
    hours_analyzed: int


# ── Yardımcı Fonksiyonlar ──────────────────────────────────────────────────────

def _weibull_k(speeds: List[float]) -> float:
    """
    Method of Moments ile Weibull k (şekil) parametresi tahmini.
    k ≈ (σ/μ)^{-1.086}  [Justus et al. 1978 yaklaşımı]
    """
    if len(speeds) < 2:
        return 1.0
    mu = sum(speeds) / len(speeds)
    if mu == 0:
        return 1.0
    variance = sum((s - mu) ** 2 for s in speeds) / (len(speeds) - 1)
    sigma = math.sqrt(variance) if variance > 0 else 0.001
    k = (sigma / mu) ** -1.086
    return max(0.5, min(k, 10.0))  # Makul aralık


def _weibull_lambda(speeds: List[float], k: float) -> float:
    """
    Weibull λ (ölçek) parametresi = μ / Γ(1 + 1/k)
    Γ fonksiyonu için yaklaşım: math.gamma kullan
    """
    if not speeds:
        return 1.0
    mu = sum(speeds) / len(speeds)
    try:
        gamma_term = math.gamma(1 + 1 / k)
    except Exception:
        gamma_term = 1.0
    lam = mu / gamma_term if gamma_term > 0 else mu
    return max(0.1, lam)


def _wind_category(avg: float, k: float, std: float) -> str:
    """Weibull parametrelerine göre rüzgar kategorisi."""
    if avg > 7.0:
        return "Güçlü"
    if k > 2.5 and avg >= 5.0:
        return "Stabil"
    if std > 3.0 and avg >= 5.0:
        return "Yüksek Sirkülasyon"
    if 3.0 <= avg <= 5.0:
        return "Güçsüz"
    return "Nadir"


def _solar_category(avg_radiation: float) -> str:
    """Ortalama kısa dalga radyasyonuna göre güneş kategorisi."""
    if avg_radiation > 400:
        return "Yüksek"
    if avg_radiation > 200:
        return "Orta"
    return "Düşük"


def _compute_wind_rose(
    speeds: List[float],
    directions: List[float],
    n_sectors: int = 16,
) -> WindRoseData:
    """16 yönlü rüzgar gülü verisi hesaplar."""
    sector_size = 360.0 / n_sectors
    counts = [0] * n_sectors
    speed_sums = [0.0] * n_sectors
    centers = [i * sector_size + sector_size / 2 for i in range(n_sectors)]

    for spd, direction in zip(speeds, directions):
        if direction is None:
            continue
        sector_idx = int((direction % 360) / sector_size) % n_sectors
        counts[sector_idx] += 1
        speed_sums[sector_idx] += spd

    total = max(sum(counts), 1)
    frequencies = [c / total * 100 for c in counts]
    avg_speeds = [
        (speed_sums[i] / counts[i]) if counts[i] > 0 else 0.0
        for i in range(n_sectors)
    ]

    return WindRoseData(
        directions=centers,
        frequencies=frequencies,
        avg_speeds=avg_speeds,
    )


# ── DB Sorgusu ─────────────────────────────────────────────────────────────────

def _fetch_city_stats(hours: int) -> List[dict]:
    """
    Son N saatin hava durumu verilerini şehir bazında toplar.
    wind_speed_10m, wind_direction_10m, shortwave_radiation kullanır.
    """
    db = SystemSessionLocal()
    try:
        since = datetime.now() - timedelta(hours=hours)  # naive, DB'deki kayıtlarla uyumlu
        result = db.execute(text("""
            SELECT
                city_name,
                AVG(latitude)          AS lat,
                AVG(longitude)         AS lon,
                AVG(wind_speed_10m)    AS avg_wind,
                MAX(wind_speed_10m)    AS max_wind,
                STDDEV(wind_speed_10m) AS std_wind,
                AVG(shortwave_radiation) AS avg_radiation,
                SUM(shortwave_radiation) / 1000.0 AS total_radiation_kwh,
                COUNT(*)               AS record_count,
                array_agg(wind_speed_10m    ORDER BY timestamp) AS speeds_arr,
                array_agg(wind_direction_10m ORDER BY timestamp) AS dirs_arr
            FROM hourly_weather_data
            WHERE timestamp >= :since
              AND wind_speed_10m IS NOT NULL
              AND district_name IS NULL
            GROUP BY city_name
            HAVING COUNT(*) >= 6
            ORDER BY avg_wind DESC NULLS LAST
        """), {"since": since}).fetchall()
        return [dict(r._mapping) for r in result]
    except Exception as e:
        logger.warning("Recommendations DB query failed: {}", e)
        return []
    finally:
        db.close()


# ── Endpoint ───────────────────────────────────────────────────────────────────

@router.get("", response_model=RecommendationsResponse)
async def get_recommendations(
    hours: int = Query(168, ge=24, le=720, description="Analiz penceresi (saat, 24-720)"),
    top_n: int = Query(8, ge=1, le=20, description="Kategori başına sonuç sayısı"),
):
    """
    Türkiye genelinde akıllı bölge önerilerini döndürür.

    - **hours**: Son kaç saatlik veri analiz edilsin (varsayılan: 168 = 7 gün)
    - **top_n**: Her kategoride kaç şehir dönsün (varsayılan: 8)
    """
    import asyncio
    stats = await asyncio.to_thread(_fetch_city_stats, hours)

    if not stats:
        logger.warning("Recommendations: Yeterli veri bulunamadı (hours={})", hours)

    cities: List[RecommendedCity] = []

    for row in stats:
        # Open-Meteo varsayılan birimi km/h — m/s'ye çevir (÷ 3.6)
        # Tüm eşik değerleri (> 7, >= 5 vb.) ve Weibull hesapları m/s bekler.
        avg_wind = float(row["avg_wind"] or 0) / 3.6
        max_wind = float(row["max_wind"] or 0) / 3.6
        std_wind = float(row["std_wind"] or 0) / 3.6   # std sapma doğrusal ölçeklenir
        avg_rad  = float(row["avg_radiation"] or 0)
        total_rad_kwh = float(row["total_radiation_kwh"] or 0)
        count    = int(row["record_count"] or 0)

        # Hız ve yön dizilerini Python listesine çevir (km/h → m/s)
        raw_speeds = row.get("speeds_arr") or []
        raw_dirs   = row.get("dirs_arr") or []
        speeds = [float(s) / 3.6 for s in raw_speeds if s is not None]
        dirs   = [float(d) for d in raw_dirs   if d is not None]

        k = _weibull_k(speeds) if speeds else 1.0
        lam = _weibull_lambda(speeds, k) if speeds else 1.0
        category = _wind_category(avg_wind, k, std_wind)
        solar_cat = _solar_category(avg_rad)

        # Rüzgar gülü: yalnızca hem hız hem yön veri varsa
        wind_rose = None
        paired = [(s, d) for s, d in zip(speeds, dirs) if d is not None]
        if len(paired) >= 8:
            ps, pd = zip(*paired)
            wind_rose = _compute_wind_rose(list(ps), list(pd))

        # Skor: rüzgar + güneş bileşeni
        wind_score  = min(avg_wind / 12.0 * 60, 60) + min(k / 4.0 * 20, 20)
        solar_score = min(avg_rad / 600.0 * 20, 20)
        score = round(wind_score + solar_score, 1)

        cities.append(RecommendedCity(
            name=row["city_name"],
            lat=float(row["lat"]),
            lon=float(row["lon"]),
            avg_wind_speed=round(avg_wind, 2),
            max_wind_speed=round(max_wind, 2),
            wind_category=category,
            weibull_k=round(k, 3),
            weibull_lambda=round(lam, 3),
            wind_std=round(std_wind, 2),
            wind_rose=wind_rose,
            avg_radiation=round(avg_rad, 1),
            total_radiation_kwh=round(total_rad_kwh, 2),
            solar_category=solar_cat,
            record_count=count,
            score=score,
        ))

    # Kategorilere ayır
    wind_strong      = sorted(
        [c for c in cities if c.avg_wind_speed and c.avg_wind_speed > 7],
        key=lambda c: c.score, reverse=True,
    )[:top_n]

    wind_stable      = sorted(
        [c for c in cities if c.weibull_k and c.weibull_k > 2.5 and c.avg_wind_speed and c.avg_wind_speed >= 5.0],
        key=lambda c: (c.weibull_k or 0), reverse=True,
    )[:top_n]

    wind_circulation = sorted(
        [c for c in cities if c.wind_std and c.wind_std > 3.0 and c.avg_wind_speed and c.avg_wind_speed >= 5.0],
        key=lambda c: (c.wind_std or 0), reverse=True,
    )[:top_n]

    wind_weak        = sorted(
        [c for c in cities if c.avg_wind_speed and 2.0 <= c.avg_wind_speed <= 5.5],
        key=lambda c: c.avg_wind_speed or 0, reverse=True,
    )[:top_n]

    solar_top        = sorted(
        [c for c in cities if c.avg_radiation and c.avg_radiation > 0],
        key=lambda c: c.avg_radiation or 0, reverse=True,
    )[:top_n]

    # En yüksek anlık ışınım — peak W/m² değerine göre sıralı
    solar_irradiance_top = sorted(
        [c for c in cities if c.avg_radiation and c.avg_radiation > 200],
        key=lambda c: c.avg_radiation or 0, reverse=True,
    )[:top_n]

    # Yıllık rüzgar verimliliği — hem güçlü hem tutarlı rüzgar (k × avg_wind)
    wind_annual_efficiency = sorted(
        [c for c in cities if c.avg_wind_speed and c.avg_wind_speed >= 3.0
         and c.weibull_k and c.weibull_k >= 1.5],
        key=lambda c: (c.weibull_k or 1.0) * (c.avg_wind_speed or 0), reverse=True,
    )[:top_n]

    # Yıllık güneş verimliliği — birikimli toplam ışınım (kWh/m²)
    solar_annual_efficiency = sorted(
        [c for c in cities if c.total_radiation_kwh and c.total_radiation_kwh > 0],
        key=lambda c: c.total_radiation_kwh or 0, reverse=True,
    )[:top_n]

    return RecommendationsResponse(
        wind_strong=wind_strong,
        wind_stable=wind_stable,
        wind_circulation=wind_circulation,
        wind_weak=wind_weak,
        solar_top=solar_top,
        solar_irradiance_top=solar_irradiance_top,
        wind_annual_efficiency=wind_annual_efficiency,
        solar_annual_efficiency=solar_annual_efficiency,
        generated_at=datetime.now(timezone.utc),
        hours_analyzed=hours,
    )

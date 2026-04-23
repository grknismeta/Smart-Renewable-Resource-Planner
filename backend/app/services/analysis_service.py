"""province_analysis skor hesaplama servisi (Faz 1 — Tek Kaynak).

Saatlik scheduler tetiklemesi sonrası çağrılır. `HourlyWeatherData` tablosundan
4 pencere (30/90/180/365 gün) için il × kaynak (wind/solar/hydro) skorlarını
hesaplayıp `province_analysis` tablosuna UPSERT eder.

Skor fonksiyonları:
  - Wind: Cube-law (P ∝ v³). v_cutin=3, v_rated=12 m/s. Cap=100.
  - Solar: Lineer, üst sınır 400 W/m² (TR 24h ortalaması 150-300 aralığında).
  - Hydro: Yağış + sıcaklık proxy'si (HES havza verisi gelince revize).

Tüm ham metrikler (avg_wind_speed, avg_solar_radiation, avg_temperature,
capacity_factor, sample_count) `province_analysis` satırına yazılır.
"""

from __future__ import annotations

import logging
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Dict, Iterable, List, Optional

from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from ..core.constants import TURKEY_CITIES
from ..db.database import SystemSessionLocal
from ..db.models import HourlyWeatherData, ProvinceAnalysis

logger = logging.getLogger(__name__)

# ───────────────────── Yapılandırma ─────────────────────

# Pencereler: horizon anahtarı → geri bakılacak gün sayısı
WINDOWS: Dict[str, int] = {
    "1m": 30,
    "3m": 90,
    "6m": 180,
    "yearly": 365,
}

RESOURCE_TYPES = ("wind", "solar", "hydro")

# Rüzgar skoru — türbin güç eğrisi referansı
WIND_CUT_IN_MS = 3.0          # rüzgar türbini devreye giriş
WIND_RATED_MS = 12.0          # nominal üretim hızı (skor cap)
WIND_SCORE_MODE = "cube"      # "cube" (default) | "linear"

# Güneş — TR 24h ortalaması 150-300 W/m², 400 W/m² üst sınır (kullanıcı kararı)
SOLAR_MAX_WM2 = 400.0

# Hidro proxy — yağış mm/gün referansı (Karadeniz ~5 mm/gün)
HYDRO_PRECIP_MAX_MM_PER_DAY = 5.0
HYDRO_TEMP_PEAK_C = 12.0       # ılıman-serin bölgelerde HES potansiyeli tepe yapar
HYDRO_TEMP_TOLERANCE_C = 20.0  # skor ±20 °C'de 0'a iner
HYDRO_PRECIP_WEIGHT = 0.7      # precipitation baskın bileşen
HYDRO_TEMP_WEIGHT = 0.3


# ───────────────────── İl ↔ city_name mapping ─────────────────────

@dataclass(frozen=True)
class ProvinceMap:
    provinces: List[str]                       # benzersiz il adları (TURKEY_CITIES sırasıyla)
    city_to_province: Dict[str, str]           # HourlyWeatherData.city_name → province


def _build_province_map() -> ProvinceMap:
    provinces: List[str] = []
    seen: set[str] = set()
    c2p: Dict[str, str] = {}
    for entry in TURKEY_CITIES:
        prov = entry["province"]
        if prov not in seen:
            seen.add(prov)
            provinces.append(prov)
        # HourlyWeatherData.city_name = TURKEY_CITIES[*]["name"]
        c2p[entry["name"]] = prov
    return ProvinceMap(provinces=provinces, city_to_province=c2p)


# ───────────────────── Skor fonksiyonları ─────────────────────

def wind_score(avg_wind_ms: Optional[float], mode: str = WIND_SCORE_MODE) -> float:
    """
    Rüzgar skoru [0, 100].

    mode == "cube":  P ∝ v³  (türbin güç eğrisiyle uyumlu)
    mode == "linear": v ile lineer (opsiyonel/debug).

    cut_in altı = 0, rated üstü = 100.
    """
    if avg_wind_ms is None:
        return 0.0
    v = max(0.0, float(avg_wind_ms))
    if v <= WIND_CUT_IN_MS:
        return 0.0
    if v >= WIND_RATED_MS:
        return 100.0

    if mode == "cube":
        span = WIND_RATED_MS**3 - WIND_CUT_IN_MS**3
        norm = (v**3 - WIND_CUT_IN_MS**3) / span
    else:  # linear
        norm = (v - WIND_CUT_IN_MS) / (WIND_RATED_MS - WIND_CUT_IN_MS)

    return max(0.0, min(100.0, norm * 100.0))


def solar_score(avg_radiation_wm2: Optional[float]) -> float:
    """Güneş skoru [0, 100]. Lineer, üst sınır 400 W/m²."""
    if avg_radiation_wm2 is None:
        return 0.0
    v = max(0.0, float(avg_radiation_wm2))
    return max(0.0, min(100.0, v / SOLAR_MAX_WM2 * 100.0))


def hydro_score(
    avg_precip_mm_per_day: Optional[float],
    avg_temp_c: Optional[float],
) -> float:
    """
    Hidro skoru [0, 100] — proxy.

    Bileşenler:
      - precip_score: yağış mm/gün → 0-100 (5 mm/gün = 100 cap)
      - temp_score:   ılıman bölge tercihi (12°C tepe, ±20°C tolerans)

    TODO: HES havza verisi (debi, düşü yüksekliği, drenaj alanı) entegre edilince
          bu proxy yerine fiziksel model kullanılacak.
    """
    if avg_precip_mm_per_day is None:
        return 0.0
    precip_score = max(
        0.0, min(100.0, float(avg_precip_mm_per_day) / HYDRO_PRECIP_MAX_MM_PER_DAY * 100.0)
    )

    if avg_temp_c is None:
        temp_score = 50.0  # nötr
    else:
        delta = abs(float(avg_temp_c) - HYDRO_TEMP_PEAK_C)
        temp_score = max(0.0, 100.0 - delta / HYDRO_TEMP_TOLERANCE_C * 100.0)

    combined = precip_score * HYDRO_PRECIP_WEIGHT + temp_score * HYDRO_TEMP_WEIGHT
    return max(0.0, min(100.0, combined))


# ───────────────────── Pencere aggregasyonu ─────────────────────

@dataclass
class ProvinceWindowAgg:
    """Bir pencere için bir ilin ağırlıklı ortalamaları (tüm city_name'ler üzerinden)."""
    province: str
    avg_wind_ms: Optional[float]
    avg_solar_wm2: Optional[float]
    avg_temp_c: Optional[float]
    avg_precip_mm_per_day: Optional[float]
    sample_count: int


def _weighted(values_counts: List[tuple[float, int]]) -> Optional[float]:
    num = 0.0
    den = 0
    for v, n in values_counts:
        if v is None or n is None or n <= 0:
            continue
        num += float(v) * int(n)
        den += int(n)
    return (num / den) if den > 0 else None


def _aggregate_window(db: Session, cutoff: datetime) -> Dict[str, ProvinceWindowAgg]:
    """
    HourlyWeatherData'yı city_name bazında aggregate eder (SQL),
    sonra TURKEY_CITIES mapping'i ile province bazına katlar (Python).

    Precipitation: hour başına mm → günlük ortalamaya (mm/gün) dönüştürür.
    """
    pm = _build_province_map()

    # NOT: SQLAlchemy 2.0.19+ Row objesinde tek-harf label'lar (`.t`, `.w` gibi) Row
    # dahili method'larıyla çakışabiliyor (SADeprecationWarning + yanlış tip dönüşü).
    # `._mapping[...]` ile erişim bu çakışmadan bağımsız ve sürüm-güvenli.
    rows = (
        db.query(
            HourlyWeatherData.city_name.label("city"),
            func.avg(HourlyWeatherData.wind_speed_100m).label("avg_wind"),
            func.avg(HourlyWeatherData.shortwave_radiation).label("avg_solar"),
            func.avg(HourlyWeatherData.temperature_2m).label("avg_temp"),
            func.avg(HourlyWeatherData.precipitation).label("avg_precip_hourly_mm"),
            func.count(HourlyWeatherData.id).label("sample_n"),
        )
        .filter(HourlyWeatherData.timestamp >= cutoff)
        .group_by(HourlyWeatherData.city_name)
        .all()
    )

    # province bazında buckets
    buckets: Dict[str, Dict[str, List[tuple]]] = defaultdict(
        lambda: {"w": [], "s": [], "t": [], "p": [], "n": 0}
    )
    for r in rows:
        m = r._mapping  # sürüm-güvenli label erişimi
        prov = pm.city_to_province.get(m["city"])
        if prov is None:
            continue
        n = int(m["sample_n"] or 0)
        if n <= 0:
            continue
        b = buckets[prov]
        b["w"].append((m["avg_wind"], n))
        b["s"].append((m["avg_solar"], n))
        b["t"].append((m["avg_temp"], n))
        # saatlik ortalama mm × 24 = günlük toplam mm
        p_hourly = m["avg_precip_hourly_mm"]
        p_daily = (float(p_hourly) * 24.0) if p_hourly is not None else None
        b["p"].append((p_daily, n))
        b["n"] += n

    out: Dict[str, ProvinceWindowAgg] = {}
    for prov in pm.provinces:
        b = buckets.get(prov)
        if not b or b["n"] == 0:
            out[prov] = ProvinceWindowAgg(
                province=prov,
                avg_wind_ms=None,
                avg_solar_wm2=None,
                avg_temp_c=None,
                avg_precip_mm_per_day=None,
                sample_count=0,
            )
            continue
        out[prov] = ProvinceWindowAgg(
            province=prov,
            avg_wind_ms=_weighted(b["w"]),
            avg_solar_wm2=_weighted(b["s"]),
            avg_temp_c=_weighted(b["t"]),
            avg_precip_mm_per_day=_weighted(b["p"]),
            sample_count=b["n"],
        )
    return out


# ───────────────────── Capacity factor (wind) ─────────────────────

def _wind_capacity_factor(avg_wind_ms: Optional[float]) -> Optional[float]:
    """Basit yaklaşım: cube-law skor / 100 ≈ CF (debug/bilgi amaçlı)."""
    if avg_wind_ms is None:
        return None
    return wind_score(avg_wind_ms, mode="cube") / 100.0


# ───────────────────── UPSERT ─────────────────────

def _upsert_row(
    db: Session,
    *,
    province: str,
    resource: str,
    scores: Dict[str, Optional[float]],
    raw: Dict[str, Optional[float]],
    sample_count: int,
) -> None:
    """PostgreSQL ON CONFLICT upsert (uq_province_resource constraint'i üzerinden)."""
    now = datetime.now(timezone.utc)
    values = {
        "province_name": province,
        "resource_type": resource,
        "score_1m": scores.get("1m"),
        "score_3m": scores.get("3m"),
        "score_6m": scores.get("6m"),
        "score_yearly": scores.get("yearly"),
        "avg_wind_speed": raw.get("avg_wind_speed"),
        "avg_solar_radiation": raw.get("avg_solar_radiation"),
        "avg_temperature": raw.get("avg_temperature"),
        "capacity_factor": raw.get("capacity_factor"),
        "sample_count": sample_count,
        "computed_at": now,
    }
    stmt = pg_insert(ProvinceAnalysis).values(**values)
    stmt = stmt.on_conflict_do_update(
        constraint="uq_province_resource",
        set_={k: stmt.excluded[k] for k in values.keys() if k not in ("province_name", "resource_type")},
    )
    db.execute(stmt)


# ───────────────────── Ana Giriş ─────────────────────

def recompute_all_provinces(db: Optional[Session] = None) -> Dict[str, int]:
    """
    81 il × 3 kaynak × 4 pencere skor hesaplama ve upsert.

    Args:
        db: Mevcut session (opsiyonel). Verilmezse yeni SystemSessionLocal açar.

    Returns:
        {"provinces": N, "rows_written": N*3, "windows": 4}
    """
    own_session = db is None
    if own_session:
        db = SystemSessionLocal()

    try:
        now = datetime.now(timezone.utc)
        cutoffs = {
            horizon: now - timedelta(days=days)
            for horizon, days in WINDOWS.items()
        }

        # Her pencere için bir aggregate — 4 DB query
        aggs_by_horizon: Dict[str, Dict[str, ProvinceWindowAgg]] = {
            h: _aggregate_window(db, c) for h, c in cutoffs.items()
        }

        pm = _build_province_map()
        rows_written = 0

        for prov in pm.provinces:
            # Her kaynak için 4 skor + ham metrik
            for resource in RESOURCE_TYPES:
                scores: Dict[str, Optional[float]] = {}
                for horizon in WINDOWS.keys():
                    agg = aggs_by_horizon[horizon].get(prov)
                    if agg is None or agg.sample_count == 0:
                        scores[horizon] = None
                        continue
                    if resource == "wind":
                        scores[horizon] = wind_score(agg.avg_wind_ms)
                    elif resource == "solar":
                        scores[horizon] = solar_score(agg.avg_solar_wm2)
                    else:  # hydro
                        scores[horizon] = hydro_score(
                            agg.avg_precip_mm_per_day, agg.avg_temp_c
                        )

                # Ham metrikleri yıllık penceredeki agg'dan al (en geniş örneklem)
                base_agg = aggs_by_horizon["yearly"].get(prov)
                if base_agg is None:
                    base_agg = ProvinceWindowAgg(prov, None, None, None, None, 0)

                raw = {
                    "avg_wind_speed": base_agg.avg_wind_ms,
                    "avg_solar_radiation": base_agg.avg_solar_wm2,
                    "avg_temperature": base_agg.avg_temp_c,
                    "capacity_factor": (
                        _wind_capacity_factor(base_agg.avg_wind_ms)
                        if resource == "wind"
                        else None
                    ),
                }

                _upsert_row(
                    db,
                    province=prov,
                    resource=resource,
                    scores=scores,
                    raw=raw,
                    sample_count=base_agg.sample_count,
                )
                rows_written += 1

        db.commit()
        logger.info(
            "province_analysis recompute tamamlandi: %d il, %d satir, 4 pencere.",
            len(pm.provinces),
            rows_written,
        )
        return {
            "provinces": len(pm.provinces),
            "rows_written": rows_written,
            "windows": len(WINDOWS),
        }
    except Exception:
        db.rollback()
        logger.exception("province_analysis recompute FAIL")
        raise
    finally:
        if own_session:
            db.close()


def compute_single_province(
    province_name: str, db: Optional[Session] = None
) -> List[ProvinceAnalysis]:
    """
    Tek il için güncel satırları döner (endpoint'ler için yardımcı).
    Veri üretmez; recompute'tan sonra oluşmuş kayıtları okur.
    """
    own_session = db is None
    if own_session:
        db = SystemSessionLocal()
    try:
        return (
            db.query(ProvinceAnalysis)
            .filter(ProvinceAnalysis.province_name == province_name)
            .all()
        )
    finally:
        if own_session:
            db.close()


# Scheduler için export
__all__ = [
    "WINDOWS",
    "RESOURCE_TYPES",
    "wind_score",
    "solar_score",
    "hydro_score",
    "recompute_all_provinces",
    "compute_single_province",
]

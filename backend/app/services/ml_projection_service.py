"""
SRRP — ML Projeksiyon Servisi (Aşama 3.D)
=========================================

Geçmiş hava verisinden gelecek 1/3/6 ay tahmini. Hibrit pragmatik yaklaşım:

* **Uzun trend**: 10+ yıllık günlük veri (`WeatherData`) — yıllık ortalamaların
  lineer fit'i, mevsimsel bileşen çıkarılır.
* **Mevsimsel naive**: Geçmiş 5+ yılın **aynı gün**lerinin ortalaması temel
  alınır (yıllık döngüselliği yakalar).
* **Belirsizlik aralığı**: Geçmiş yıl-içi std_dev × 1.96 → yaklaşık 95% CI.

Dış bağımlılık **yok** (Prophet / statsmodels gerek yok) — tüm pipeline pure
NumPy + SQL. Demo amaçlı yeterince doğru, açıklanabilir, hızlı.

Bilimsel doğruluk uyarısı: Bu demo bir model, **iklim değişimi senaryolarını
kapsamaz**. Gerçek projeksiyon için CMIP6 / ERA5 reanalizleri ile beslenen
SARIMAX/Prophet entegrasyonu (3.D.2 sonrası iterasyon) önerilir.

Endpoint: ``GET /analysis/projection``.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Optional

logger = logging.getLogger(__name__)

try:
    import numpy as np  # type: ignore
    _NUMPY_OK = True
except Exception:  # pragma: no cover
    np = None  # type: ignore
    _NUMPY_OK = False


# ─── API tipi ───────────────────────────────────────────────────────────────

@dataclass
class ProjectionPoint:
    """Tek bir tarih için tahmin."""
    date: str            # ISO "YYYY-MM-DD"
    value: float         # ortalama tahmin
    lower: float         # 95% CI alt sınır
    upper: float         # 95% CI üst sınır


@dataclass
class ProvinceProjection:
    province: str
    metric: str          # "wind_speed" | "shortwave_radiation" | "temperature"
    horizon_days: int    # kaç günlük projeksiyon
    history_days: int    # kaç günlük geçmiş kullanıldı
    history_years: int   # kaç farklı yıl
    method: str          # "seasonal_naive_with_trend"
    points: list[ProjectionPoint] = field(default_factory=list)
    historical_avg: Optional[float] = None
    annual_trend_pct: Optional[float] = None  # yıllık ortalamanın % değişimi


# ─── Metric mapping ─────────────────────────────────────────────────────────
# WeatherData (günlük) tablosundaki kolonlar
_DAILY_COL_MAP = {
    "wind_speed": "wind_speed_mean",
    "shortwave_radiation": "shortwave_radiation_sum",
    "temperature": "temperature_mean",
}

VALID_METRICS = tuple(_DAILY_COL_MAP.keys())
VALID_HORIZONS = (30, 90, 180, 365)


def _resolve_metric_col(metric: str) -> str:
    if metric not in _DAILY_COL_MAP:
        raise ValueError(
            f"Geçersiz metric '{metric}'. İzinli: {sorted(VALID_METRICS)}"
        )
    return _DAILY_COL_MAP[metric]


def project_province(
    province: str,
    metric: str,
    horizon_days: int = 90,
) -> ProvinceProjection:
    """Belirli bir il için seçilen metriğin gelecek tahmini.

    Args:
        province: İl adı (büyük-küçük harf duyarsız, ilk eşleşme alınır)
        metric: "wind_speed" | "shortwave_radiation" | "temperature"
        horizon_days: 30 | 90 | 180 | 365

    Returns:
        `ProvinceProjection` — günlük tahmin listesi + meta.
    """
    if not _NUMPY_OK:
        raise RuntimeError(
            "numpy yüklü değil — backend ortamında 'pip install numpy' çalıştırın"
        )
    if not province or not province.strip():
        raise ValueError("province parametresi zorunlu")
    if horizon_days not in VALID_HORIZONS:
        raise ValueError(
            f"horizon_days {VALID_HORIZONS} arasında olmalı (30/90/180/365)"
        )

    col_name = _resolve_metric_col(metric)
    province_q = province.strip()

    # ── 1) Geçmiş veriyi çek ────────────────────────────────────────────────
    from app.db.database import SystemSessionLocal
    from app.db.models import WeatherData
    from sqlalchemy import func as sa_func

    today = date.today()

    with SystemSessionLocal() as db:
        rows = (
            db.query(
                WeatherData.date,
                getattr(WeatherData, col_name).label("val"),
            )
            .filter(
                WeatherData.province_name.ilike(f"%{province_q}%"),
                WeatherData.date <= today,
                getattr(WeatherData, col_name).isnot(None),
            )
            .order_by(WeatherData.date.asc())
            .all()
        )

    if not rows:
        raise ValueError(
            f"'{province}' için '{metric}' metriği üzerinde geçmiş veri yok"
        )

    # numpy arrays
    dates_np = np.array([r.date.toordinal() for r in rows])
    vals_np = np.array([float(r.val) for r in rows], dtype=float)
    raw_dates = [r.date for r in rows]

    history_days = len(rows)
    years_set = sorted({d.year for d in raw_dates})
    history_years = len(years_set)

    # ── 2) Yıllık ortalama → lineer trend ──────────────────────────────────
    yearly_means: dict[int, float] = {}
    for i, d in enumerate(raw_dates):
        yearly_means.setdefault(d.year, [])
        yearly_means[d.year].append(vals_np[i])  # type: ignore
    yearly_avg = {y: float(np.mean(vs)) for y, vs in yearly_means.items()}

    annual_trend_pct: Optional[float] = None
    if len(yearly_avg) >= 3:
        yrs = np.array(sorted(yearly_avg.keys()), dtype=float)
        ymeans = np.array([yearly_avg[int(y)] for y in yrs], dtype=float)
        # Lineer fit: y = a*x + b
        slope, intercept = np.polyfit(yrs, ymeans, 1)
        baseline = float(np.mean(ymeans))
        if baseline > 0:
            annual_trend_pct = float(slope / baseline * 100.0)

    # ── 3) Mevsimsel naive: gün-of-year (1-366) için yıllar arası ortalama ──
    # day_of_year → [val1, val2, ...] (farklı yıllardan)
    doy_buckets: dict[int, list[float]] = {}
    for i, d in enumerate(raw_dates):
        doy = d.timetuple().tm_yday
        doy_buckets.setdefault(doy, []).append(float(vals_np[i]))  # type: ignore

    doy_mean: dict[int, float] = {}
    doy_std: dict[int, float] = {}
    for doy, vs in doy_buckets.items():
        if not vs:
            continue
        doy_mean[doy] = float(np.mean(vs))
        # std en az 2 veriyle anlamlı
        doy_std[doy] = float(np.std(vs)) if len(vs) >= 2 else 0.0

    # Ortalama std (eksik DoY'lar için fallback)
    valid_stds = [s for s in doy_std.values() if s > 0]
    fallback_std = float(np.mean(valid_stds)) if valid_stds else 0.0

    overall_mean = float(np.mean(vals_np))

    # ── 4) Trend uygulanmış mevsimsel forecast ─────────────────────────────
    # Trend faktörü: kaç yıl ileri gidiyoruz × yıllık değişim
    points: list[ProjectionPoint] = []
    last_year = max(years_set)

    # Mevsimsel naive yıl olarak en son yılı temel alır;
    # forecast tarihi son yıl + ofset ile DoY'a düşer.
    for offset in range(1, horizon_days + 1):
        d_target = today + timedelta(days=offset)
        doy = d_target.timetuple().tm_yday
        # 366 → 365'e (29 Şubat) düşmesi için fallback
        base = doy_mean.get(doy)
        if base is None:
            # Eksikse en yakın doy ortalaması ya da overall mean
            nearby = [doy_mean[k] for k in (doy - 1, doy + 1, doy - 2, doy + 2)
                      if k in doy_mean]
            base = nearby[0] if nearby else overall_mean
        sigma = doy_std.get(doy, fallback_std)

        # Trend ekleme: target_year - last_year × yıllık_trend_yüzde
        if annual_trend_pct is not None:
            yrs_ahead = d_target.year - last_year
            trend_factor = 1.0 + (annual_trend_pct / 100.0) * yrs_ahead
            forecast = base * trend_factor
        else:
            forecast = base

        # 95% CI (yaklaşık, normal dağılım varsayımı)
        margin = 1.96 * sigma if sigma > 0 else max(abs(forecast) * 0.10, 0.01)
        points.append(ProjectionPoint(
            date=d_target.isoformat(),
            value=round(forecast, 3),
            lower=round(forecast - margin, 3),
            upper=round(forecast + margin, 3),
        ))

    return ProvinceProjection(
        province=province_q,
        metric=metric,
        horizon_days=horizon_days,
        history_days=history_days,
        history_years=history_years,
        method="seasonal_naive_with_trend",
        points=points,
        historical_avg=round(overall_mean, 3),
        annual_trend_pct=round(annual_trend_pct, 3) if annual_trend_pct is not None else None,
    )


def project_to_dict(p: ProvinceProjection) -> dict:
    """JSON serializable form (FastAPI response)."""
    return {
        "province": p.province,
        "metric": p.metric,
        "horizon_days": p.horizon_days,
        "history_days": p.history_days,
        "history_years": p.history_years,
        "method": p.method,
        "historical_avg": p.historical_avg,
        "annual_trend_pct": p.annual_trend_pct,
        "points": [
            {
                "date": pt.date,
                "value": pt.value,
                "lower": pt.lower,
                "upper": pt.upper,
            }
            for pt in p.points
        ],
        "disclaimer": (
            "Mevsimsel naive + lineer trend modeli. İklim değişimi "
            "senaryolarını kapsamaz; demo amaçlıdır."
        ),
    }

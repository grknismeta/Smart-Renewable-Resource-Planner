"""Sprint M-A — ML batch precompute yardımcıları (2026-05-28).

İl + ilçe aylık seri builder + çoklu-model (multi-family) en iyi seçim. Batch
script (`build_ml_forecasts.py`) bunu kullanarak `ml_forecast` tablosunu doldurur.

**Model aileleri (en düşük holdout MAPE seçilir):**
  1. SARIMAX (auto_arima order veya default) — mevcut SARIMAXForecaster
  2. Holt-Winters (statsmodels ExponentialSmoothing, additive seasonal)
  3. Linear + seasonal (numpy polyfit trend + aylık ortalama)

Climatology serisi çoğunlukla 12-ay ortalaması (×tekrar) olduğundan modeller
benzer çıkar; framework gerçek çok-yıllık veri geldiğinde anlamlı ayrışır.
"""
from __future__ import annotations

import logging
from datetime import date
from typing import List, Optional, Tuple

logger = logging.getLogger(__name__)

# metric → climatology kolon adı
_FIELD_MAP = {
    "sunshine": "monthly_sunshine_hours",
    "irradiance": "monthly_sunshine_hours",  # proxy
    "precipitation": "monthly_precipitation",
    "cloud": "monthly_cloud_cover",
    "discharge": "monthly_river_discharge",
}


def get_monthly_series(
    province: str,
    district: Optional[str],
    resource: str,
    metric: str,
) -> Optional[List[float]]:
    """Climatology'den 12-aylık seri. İlçe yoksa il'e fallback.

    river_discharge JSON'u [{"mean":..}, ...] formatında → mean alınır.
    Diğerleri düz [float×12].

    Returns: 12 değerli liste veya None (veri yok).
    """
    from app.db.database import SystemSessionLocal
    from app.db.models import Climatology
    from app.services.province_aliases import province_aliases

    field = _FIELD_MAP.get(metric)
    if field is None:
        return None

    def _extract(monthly) -> Optional[List[float]]:
        if not monthly or len(monthly) != 12:
            return None
        out: List[float] = []
        for m in monthly:
            if isinstance(m, dict):
                out.append(float(m.get("mean", 0.0)))
            elif isinstance(m, (int, float)):
                out.append(float(m))
            else:
                return None
        return out

    with SystemSessionLocal() as db:
        variants = province_aliases(province)
        # 1) İlçe spesifik
        if district:
            row = (
                db.query(Climatology)
                .filter(
                    Climatology.province_name.in_(variants),
                    Climatology.district_name == district,
                    Climatology.resource_type == resource,
                )
                .first()
            )
            if row:
                s = _extract(getattr(row, field, None))
                if s:
                    return s
        # 2) İl bazlı (district_name NULL)
        row = (
            db.query(Climatology)
            .filter(
                Climatology.province_name.in_(variants),
                Climatology.district_name.is_(None),
                Climatology.resource_type == resource,
            )
            .first()
        )
        if row:
            return _extract(getattr(row, field, None))
    return None


# ─── Daily aggregate path (M-F.1, ilçe ML için) ──────────────────────────────

# Daily metric → weather_data kolonu
_DAILY_METRIC_COLS = {
    "wind": "wind_speed_mean",
    "irradiance": "shortwave_radiation_sum",
    "sunshine": "shortwave_radiation_sum",  # proxy (radiation → sunshine)
    "temperature": "temperature_mean",
    "temp": "temperature_mean",
    "precipitation": "precipitation_sum",   # M-E sonrası dolacak
    "cloud": "cloud_cover_mean",            # M-E sonrası dolacak
}


def get_monthly_series_from_daily(
    province: str,
    district: Optional[str],
    metric: str,
) -> tuple[List[float], Optional["date"]]:  # type: ignore[name-defined]
    """`weather_data` günlük tablosundan ilçe (veya il) için aylık seri.

    İlçe climatology'si yok; bu fonksiyon raw 10 yıllık daily veriyi
    `date_trunc('month')` ile aylıklaştırır (gerçek aylık varyasyon + uzun
    vade trend → ML için zengin sinyal).

    Returns: (values, start_date). start_date None = veri yok.
    """
    from datetime import date as _d
    from app.db.database import SystemSessionLocal
    from sqlalchemy import text
    from app.services.province_aliases import province_aliases

    col = _DAILY_METRIC_COLS.get(metric)
    if not col:
        return [], None

    variants = province_aliases(province)
    where = ["province_name = ANY(:provs)", f"{col} IS NOT NULL"]
    params: dict = {"provs": list(variants)}
    if district:
        where.append("district_name = :dist")
        params["dist"] = district
    # district=None → il bazlı: tüm ilçelerin AVG (district filtresi YOK).
    # weather_data'da il-seviyesi satır yok (district_name hep dolu); o yüzden
    # IS NULL filtre koymak boş döndürürdü.
    where_sql = " AND ".join(where)

    sql = text(f"""
        SELECT date_trunc('month', date)::date AS m, AVG({col}) AS v
        FROM weather_data
        WHERE {where_sql}
        GROUP BY 1
        HAVING COUNT(*) >= 10
        ORDER BY 1
    """)
    with SystemSessionLocal() as db:
        rows = db.execute(sql, params).fetchall()
    if not rows:
        return [], None
    values = [float(v) for _, v in rows if v is not None]
    start = rows[0][0]
    if isinstance(start, str):
        start = _d.fromisoformat(start)
    return values, start


# ─── Model aileleri ───────────────────────────────────────────────────────────


def _mape(actual: List[float], pred: List[float]) -> Optional[float]:
    errs = []
    for a, p in zip(actual, pred):
        if abs(a) < 1e-6:
            continue
        errs.append(abs(a - p) / abs(a))
    return sum(errs) / len(errs) if errs else None


def _forecast_holt_winters(
    series: List[float], horizon: int
) -> Optional[List[float]]:
    """Holt-Winters additive seasonal forecast."""
    try:
        from statsmodels.tsa.holtwinters import ExponentialSmoothing  # type: ignore
        import numpy as np  # type: ignore
        if len(series) < 24:
            return None
        model = ExponentialSmoothing(
            np.asarray(series, dtype=float),
            seasonal="add",
            seasonal_periods=12,
            trend="add",
            initialization_method="estimated",
        )
        fit = model.fit()
        fc = fit.forecast(horizon)
        return [float(x) for x in fc]
    except Exception as e:
        logger.debug("holt_winters fail: %s", e)
        return None


def _forecast_linear_seasonal(
    series: List[float], horizon: int
) -> Optional[List[float]]:
    """Lineer trend (numpy polyfit) + aylık mevsim sapması."""
    try:
        import numpy as np  # type: ignore
        n = len(series)
        if n < 12:
            return None
        arr = np.asarray(series, dtype=float)
        x = np.arange(n)
        # Lineer trend
        slope, intercept = np.polyfit(x, arr, 1)
        trend = slope * x + intercept
        resid = arr - trend
        # Aylık ortalama mevsim bileşeni (index % 12)
        seasonal = np.zeros(12)
        for m in range(12):
            vals = resid[m::12]
            seasonal[m] = vals.mean() if len(vals) else 0.0
        out = []
        for h in range(horizon):
            idx = n + h
            out.append(float(slope * idx + intercept + seasonal[idx % 12]))
        return out
    except Exception as e:
        logger.debug("linear_seasonal fail: %s", e)
        return None


def select_best_monthly_forecast(
    series: List[float],
    start_date: date,
    horizon_months: int,
    label: str,
) -> Tuple[List[float], List[Optional[float]], List[Optional[float]], str, Optional[float]]:
    """En iyi modeli holdout MAPE ile seç, tam horizon forecast döndür.

    Returns: (values, lowers, uppers, method, holdout_mape)
    """
    from app.services.ml_sarimax_service import SARIMAXForecaster

    # Holdout: son 12 ay (yeterliyse)
    has_holdout = len(series) >= 24
    train = series[:-12] if has_holdout else series
    test = series[-12:] if has_holdout else []

    candidates: List[Tuple[str, Optional[float]]] = []

    # 1) SARIMAX (holdout değerlendirme)
    sarimax_holdout_mape: Optional[float] = None
    if has_holdout:
        try:
            f = SARIMAXForecaster().forecast(
                series=train, start_date=start_date,
                horizon_months=12, target_label=label,
            )
            preds = [p.value for p in f.points]
            sarimax_holdout_mape = _mape(test, preds)
        except Exception as e:
            logger.debug("sarimax holdout fail %s: %s", label, e)
    candidates.append(("sarimax", sarimax_holdout_mape))

    # 2) Holt-Winters
    hw_mape: Optional[float] = None
    if has_holdout:
        hw_pred = _forecast_holt_winters(train, 12)
        if hw_pred:
            hw_mape = _mape(test, hw_pred)
    candidates.append(("holt_winters", hw_mape))

    # 3) Linear+seasonal
    lin_mape: Optional[float] = None
    if has_holdout:
        lin_pred = _forecast_linear_seasonal(train, 12)
        if lin_pred:
            lin_mape = _mape(test, lin_pred)
    candidates.append(("linear_seasonal", lin_mape))

    # En düşük MAPE'li (None'lar en sona)
    valid = [(m, e) for m, e in candidates if e is not None]
    best_method = "sarimax"
    best_mape: Optional[float] = sarimax_holdout_mape
    if valid:
        valid.sort(key=lambda t: t[1])
        best_method, best_mape = valid[0]

    # Kazanan modeli TÜM seri üzerinde eğitip tam horizon forecast üret
    values: List[float] = []
    lowers: List[Optional[float]] = []
    uppers: List[Optional[float]] = []

    if best_method == "sarimax":
        try:
            f = SARIMAXForecaster().forecast(
                series=series, start_date=start_date,
                horizon_months=horizon_months, target_label=label,
            )
            values = [p.value for p in f.points]
            lowers = [p.lower for p in f.points]
            uppers = [p.upper for p in f.points]
            method_detail = f.method  # sarimax_auto | sarimax_default
        except Exception as e:
            logger.warning("sarimax full fail %s: %s", label, e)
            best_method = "linear_seasonal"
            method_detail = "linear_seasonal"
    else:
        method_detail = best_method

    if not values:
        # SARIMAX dışı veya SARIMAX patladı → seçilen alternatif
        if best_method == "holt_winters":
            pred = _forecast_holt_winters(series, horizon_months)
        else:
            pred = _forecast_linear_seasonal(series, horizon_months)
        if pred is None:
            # son çare: seasonal naive (son 12 ayı tekrarla)
            pred = [series[-(12 - (h % 12))] if len(series) >= 12
                    else series[-1] for h in range(horizon_months)]
            method_detail = "fallback_naive"
        values = pred
        # CI yok → ±%10 kaba bant
        lowers = [v * 0.9 for v in values]
        uppers = [v * 1.1 for v in values]

    return values, lowers, uppers, method_detail, best_mape

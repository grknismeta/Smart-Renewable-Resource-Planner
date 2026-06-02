"""SRRP — SARIMAX Forecast Servisi (P1, 2026-05-27).

statsmodels SARIMAX + pmdarima auto_arima ile **aylık** zaman serisi
forecast'ı. Prophet'in %85-90 kalitesi, %15 boyutu (~30 MB ek dep vs
~250 MB).

**Kullanım yerleri:**
  • Pin generation forecast (pin_id, years_ahead) → /ml/project/pin/{id}
  • Climatology forecast (province, resource, years_ahead) → /ml/project/province/{name}

**ÖNEMLI** — Sadece **aylık** seri kullanılır. Saatlik veri ML için:
  - 2 yıl × 8760 = 17,520 datapoint çok büyük, train yavaş
  - Yüksek gürültü → overfit
  - Aylık 10-yıl seri daha temiz, climate trend için ideal
Detay: docs/knowledge/srrp-knowledge/GRANULARITY-FORMULAS.md § 6

**MAPE hedefi:** %20 altında (P1.8 validation kabul kriteri).
"""
from __future__ import annotations

import logging
import warnings
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import List, Optional, Tuple

logger = logging.getLogger(__name__)

# Lazy import — statsmodels yüklü değilse service çalışmasın, açıkça hata at
try:
    import numpy as np  # type: ignore
    import pandas as pd  # type: ignore
    from statsmodels.tsa.statespace.sarimax import SARIMAX  # type: ignore
    _SARIMAX_OK = True
except Exception as e:  # pragma: no cover
    _SARIMAX_OK = False
    _SARIMAX_IMPORT_ERROR = str(e)

try:
    from pmdarima import auto_arima  # type: ignore
    _PMDARIMA_OK = True
except Exception:  # pragma: no cover
    _PMDARIMA_OK = False


# ─── API Tipi ───────────────────────────────────────────────────────────────

@dataclass
class ForecastPoint:
    """Tek aylık forecast point."""
    date: str        # ISO "YYYY-MM-01"
    value: float     # Mean forecast (kWh veya metric birimi)
    lower: float     # 95% CI alt sınır
    upper: float     # 95% CI üst sınır


@dataclass
class SarimaxForecast:
    """Tam forecast paketi — meta + points + validation."""
    target: str                      # "pin_X_kwh" | "province_solar_irradiance"
    horizon_months: int              # Kaç ay forecast (1-120)
    history_months: int              # Kullanılan geçmiş ay sayısı
    order: Tuple[int, int, int]      # (p, d, q)
    seasonal_order: Tuple[int, int, int, int]  # (P, D, Q, s=12)
    method: str                      # "sarimax_auto" | "sarimax_default"
    mape: Optional[float] = None     # In-sample MAPE (validation skoru)
    confidence_level: float = 0.95
    points: List[ForecastPoint] = field(default_factory=list)
    historical: List[ForecastPoint] = field(default_factory=list)  # geçmiş seri
    annual_trend_pct: Optional[float] = None  # yıllık % değişim
    notes: List[str] = field(default_factory=list)


# ─── Wrapper ────────────────────────────────────────────────────────────────


class SARIMAXForecaster:
    """SARIMAX + auto_arima wrapper — aylık zaman serisi forecast.

    Kullanım:
        forecaster = SARIMAXForecaster()
        result = forecaster.forecast(
            series=monthly_values,
            start_date=date(2015, 1, 1),
            horizon_months=60,
            target_label="pin_42_kwh",
        )
    """

    # Auto-ARIMA arama sınırları — kombinatoryal patlamayı önle
    AUTO_MAX_P = 2
    AUTO_MAX_Q = 2
    AUTO_MAX_D = 2

    def __init__(self, seasonal_period: int = 12, use_auto_arima: bool = True):
        if not _SARIMAX_OK:
            raise RuntimeError(
                f"statsmodels yüklü değil: {_SARIMAX_IMPORT_ERROR}. "
                "Çalıştır: pip install statsmodels pmdarima"
            )
        self.seasonal_period = seasonal_period
        # 2026-06-02: auto_arima (pmdarima stepwise) tek seri için ~saniyeler;
        # BATCH'te (binlerce seri) saatlerce sürüyordu. use_auto_arima=False →
        # sabit (1,1,1)(1,1,1,12) order kullan (~100× hızlı, climate serisi için
        # makul). Canlı tek-istek (project_climatology) True bırakır.
        self.use_auto_arima = use_auto_arima

    # ── Public API ──────────────────────────────────────────────────────────

    @staticmethod
    def _build_exog(idx, base_year: int):
        """Exogenous matrix (M-G.1 + M-G.3, 5 kolon):
          0. month_sin   — Fourier mevsim
          1. month_cos   — Fourier mevsim
          2. year_trend  — lineer (yıl - base_year)
          3. year_sq     — quadratic (year_trend² / 100, climate change ivmesi)
          4. co2_norm    — CO₂ ppm proxy (Mauna Loa fit, deterministik signal)

        D=1 seasonal differencing trend'i siler; exog drift'i geri kazandırır.
        CO₂ + year² ile hızlanan iklim sinyali (yatırımcı için anlamlı projeksiyon).
        Returns: np.ndarray shape (n, 5)
        """
        from app.services.ml_batch_service import get_co2_ppm
        months = np.array([d.month for d in idx])
        years = np.array([d.year - base_year for d in idx], dtype=float)
        co2 = np.array([get_co2_ppm(d.year, d.month) - 410.0 for d in idx])
        return np.column_stack([
            np.sin(2 * np.pi * months / 12),
            np.cos(2 * np.pi * months / 12),
            years,
            (years * years) / 100.0,
            co2 / 50.0,
        ])

    def forecast(
        self,
        series: List[float],
        start_date: date,
        horizon_months: int,
        target_label: str = "series",
        confidence_level: float = 0.95,
        with_exog: bool = True,
    ) -> SarimaxForecast:
        """Aylık zaman serisi forecast.

        Args:
            series: Aylık değerler (ilk eleman = `start_date`'den başlar)
            start_date: İlk ayın tarihi (gün 1)
            horizon_months: Kaç ay tahmin (1-120)
            target_label: Çıktıda 'target' alanına yazılır
            confidence_level: 0.95 default (1.96 σ)
            with_exog: True (M-G.1) — Fourier mevsim + year_trend exog ekler.
                       Default açık; baz forecast yıllar arasında trend gösterir.

        Returns:
            `SarimaxForecast` — points + historical + MAPE + trend
        """
        if not series or len(series) < 12:
            raise ValueError(
                f"En az 12 ay veri gerekli (verilen: {len(series)}). "
                "Daha az veri için fallback kullan."
            )
        if horizon_months < 1 or horizon_months > 120:
            raise ValueError("horizon_months 1-120 aralığında olmalı")

        n = len(series)
        # NaN'leri lineer interpolasyonla doldur (kısa boşluklar için)
        arr = np.array(series, dtype=float)
        if np.isnan(arr).any():
            mask = np.isnan(arr)
            arr[mask] = np.interp(
                np.flatnonzero(mask), np.flatnonzero(~mask), arr[~mask]
            )

        # Pandas Series için DatetimeIndex (aylık freq)
        idx = pd.date_range(
            start=pd.Timestamp(start_date), periods=n, freq="MS"
        )
        ts = pd.Series(arr, index=idx)

        # Order seçimi
        order, seasonal_order, method = self._select_order(ts)
        logger.info(
            "SARIMAX %s: order=%s seasonal=%s n=%d horizon=%d exog=%s",
            target_label, order, seasonal_order, n, horizon_months, with_exog,
        )

        # M-G.1: Exog matrix (Fourier + year_trend) — fit + forecast'ı zenginleştir
        base_year = idx[0].year
        exog_fit = self._build_exog(idx, base_year) if with_exog else None
        future_idx = pd.date_range(
            start=idx[-1] + pd.offsets.MonthBegin(1),
            periods=horizon_months, freq="MS",
        )
        exog_fc = self._build_exog(future_idx, base_year) if with_exog else None

        # Model fit
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            try:
                model = SARIMAX(
                    ts,
                    exog=exog_fit,
                    order=order,
                    seasonal_order=seasonal_order,
                    enforce_stationarity=False,
                    enforce_invertibility=False,
                )
                fitted = model.fit(disp=False, maxiter=200)
            except Exception as e:
                logger.warning(
                    "SARIMAX fit hatası (%s), naive seasonal'a düşülüyor: %s",
                    target_label, e,
                )
                return self._fallback_seasonal_naive(
                    ts, horizon_months, target_label, confidence_level,
                )

        # Forecast (exog ile drift)
        try:
            fc = fitted.get_forecast(steps=horizon_months, exog=exog_fc)
            mean = fc.predicted_mean
            conf_int = fc.conf_int(alpha=1 - confidence_level)
            lower = conf_int.iloc[:, 0]
            upper = conf_int.iloc[:, 1]
        except Exception as e:
            logger.warning(
                "SARIMAX forecast hatası (%s): %s", target_label, e,
            )
            return self._fallback_seasonal_naive(
                ts, horizon_months, target_label, confidence_level,
            )

        # In-sample MAPE — son 12 ay holdout
        mape = self._compute_mape(ts, fitted)

        # Yıllık trend — son 12 ay forecast / son 12 ay gerçek
        trend_pct = None
        if len(mean) >= 12 and len(ts) >= 12:
            recent_avg = ts.iloc[-12:].mean()
            future_avg = mean.iloc[:12].mean()
            if recent_avg > 0:
                trend_pct = (future_avg - recent_avg) / recent_avg * 100

        return SarimaxForecast(
            target=target_label,
            horizon_months=horizon_months,
            history_months=n,
            order=order,
            seasonal_order=seasonal_order,
            method=(method + "_exog") if with_exog else method,
            mape=mape,
            confidence_level=confidence_level,
            points=[
                ForecastPoint(
                    date=str(d.date()),
                    value=float(v),
                    lower=float(lo),
                    upper=float(up),
                )
                for d, v, lo, up in zip(mean.index, mean, lower, upper)
            ],
            historical=[
                ForecastPoint(
                    date=str(d.date()),
                    value=float(v),
                    lower=float(v),
                    upper=float(v),
                )
                for d, v in zip(ts.index, ts)
            ],
            annual_trend_pct=round(trend_pct, 2) if trend_pct is not None else None,
            notes=[],
        )

    # ── Order selection ─────────────────────────────────────────────────────

    def _select_order(
        self, ts: "pd.Series",
    ) -> Tuple[Tuple[int, int, int], Tuple[int, int, int, int], str]:
        """auto_arima yüklüyse onunla, yoksa makul default ile order seç."""
        if _PMDARIMA_OK and self.use_auto_arima:
            try:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore")
                    model = auto_arima(
                        ts,
                        start_p=0, start_q=0,
                        max_p=self.AUTO_MAX_P,
                        max_q=self.AUTO_MAX_Q,
                        max_d=self.AUTO_MAX_D,
                        seasonal=True,
                        m=self.seasonal_period,
                        start_P=0, start_Q=0,
                        max_P=1, max_Q=1, max_D=1,
                        stepwise=True,
                        suppress_warnings=True,
                        error_action="ignore",
                        n_jobs=1,
                    )
                return (
                    tuple(model.order),  # type: ignore
                    tuple(model.seasonal_order),  # type: ignore
                    "sarimax_auto",
                )
            except Exception as e:
                logger.debug("auto_arima fail, default order: %s", e)

        # Default: SARIMAX(1,1,1)(1,1,1,12) — climate seriler için iyi başlangıç
        return (1, 1, 1), (1, 1, 1, self.seasonal_period), "sarimax_default"

    # ── In-sample MAPE ──────────────────────────────────────────────────────

    def _compute_mape(self, ts: "pd.Series", fitted) -> Optional[float]:
        """In-sample Mean Absolute Percentage Error — son 12 ay üzerinden."""
        try:
            preds = fitted.fittedvalues
            # Son 12 ay holdout MAPE — ilk burn-in'i (seasonal_period) atla
            burn_in = self.seasonal_period
            if len(ts) <= burn_in + 12:
                return None
            actual = ts.iloc[-12:]
            forecast = preds.iloc[-12:]
            mask = actual != 0
            if not mask.any():
                return None
            mape = float(
                (np.abs(actual[mask] - forecast[mask]) / np.abs(actual[mask])).mean()
            )
            return round(mape, 4)
        except Exception as e:
            logger.debug("MAPE hesabı fail: %s", e)
            return None

    # ── Fallback: Seasonal naive ────────────────────────────────────────────

    def _fallback_seasonal_naive(
        self,
        ts: "pd.Series",
        horizon: int,
        target: str,
        confidence: float,
    ) -> SarimaxForecast:
        """SARIMAX fit/forecast hata atarsa: son 12 ay mean'i tekrarla,
        std'den ±1.96σ ile CI üret. Demo amaçlı yedek."""
        last_year = ts.iloc[-12:].values if len(ts) >= 12 else ts.values
        std = float(np.std(last_year)) if len(last_year) > 1 else 0.0
        z = 1.96  # ~95% CI

        last_date = ts.index[-1]
        points: List[ForecastPoint] = []
        for i in range(horizon):
            next_date = last_date + pd.DateOffset(months=i + 1)
            month_idx = (next_date.month - 1) % 12
            base = float(last_year[month_idx])
            points.append(ForecastPoint(
                date=str(next_date.date()),
                value=base,
                lower=max(0.0, base - z * std),
                upper=base + z * std,
            ))

        return SarimaxForecast(
            target=target,
            horizon_months=horizon,
            history_months=len(ts),
            order=(0, 0, 0),
            seasonal_order=(0, 0, 0, 12),
            method="seasonal_naive_fallback",
            mape=None,
            confidence_level=confidence,
            points=points,
            historical=[
                ForecastPoint(
                    date=str(d.date()),
                    value=float(v),
                    lower=float(v),
                    upper=float(v),
                )
                for d, v in zip(ts.index, ts)
            ],
            annual_trend_pct=None,
            notes=["SARIMAX fit fail — seasonal naive fallback kullanıldı"],
        )


# ─── Pin & Climatology Forecast ──────────────────────────────────────────────


def project_pin_generation(
    pin_id: int,
    years_ahead: int = 5,
) -> SarimaxForecast:
    """Pin üretim history'sinden gelecek aylık tahmin.

    P1.3: Pin'in saatlik üretim history → aylık aggregate → SARIMAX.
    Eğer pin geçmişi <12 ay ise il climatology trend fallback (gelecekte).

    Args:
        pin_id: Pin ID (DB'de var olmalı)
        years_ahead: 1-10 yıl forecast (60-120 ay)

    Returns:
        SarimaxForecast — target="pin_<id>_kwh"
    """
    if years_ahead < 1 or years_ahead > 10:
        raise ValueError("years_ahead 1-10 aralığında olmalı")

    from app.db.database import SystemSessionLocal
    from app.db.models import Pin
    from app.services.pin_generation_service import compute_pin_generation

    with SystemSessionLocal() as db:
        pin = db.query(Pin).filter(Pin.id == pin_id).first()
        if not pin:
            raise ValueError(f"Pin {pin_id} bulunamadı")

        # Pin'in install_date'inden bugüne kadar aylık aggregate.
        install_dt = pin.installation_date or pin.created_at or datetime.utcnow()  # type: ignore
        if isinstance(install_dt, datetime):
            install_date = install_dt.date()
        else:
            install_date = install_dt

        # Aylık history: install_date → bugün
        today = date.today()
        months_back = (today.year - install_date.year) * 12 + \
            (today.month - install_date.month)

        if months_back < 12:
            # Geçmiş yetersiz — climatology fallback
            logger.info(
                "Pin %d geçmişi yetersiz (%d ay), climatology fallback",
                pin_id, months_back,
            )
            return _climatology_fallback(pin, years_ahead)

        # Aylık compute_pin_generation series
        series = []
        cur = install_date.replace(day=1)
        while cur <= today:
            try:
                gen = compute_pin_generation(
                    pin,  # type: ignore
                    period_start=cur,
                    period_end=_month_end(cur),
                )
                kwh = gen.get("total_kwh") if isinstance(gen, dict) else None
                series.append(float(kwh) if kwh else 0.0)
            except Exception as e:
                logger.debug("compute_pin_generation fail %s %s: %s",
                             pin_id, cur, e)
                series.append(0.0)
            cur = _next_month(cur)

        if all(v == 0 for v in series):
            return _climatology_fallback(pin, years_ahead)

        forecaster = SARIMAXForecaster()
        return forecaster.forecast(
            series=series,
            start_date=install_date.replace(day=1),
            horizon_months=years_ahead * 12,
            target_label=f"pin_{pin_id}_kwh",
        )


def project_climatology(
    province: str,
    resource: str,
    years_ahead: int = 5,
    metric: str = "irradiance",
) -> SarimaxForecast:
    """İl climatology monthly serisinden trend forecast.

    P1.4: climatology.monthly_* (10 yıl × 12 ay = 120 datapoint) → SARIMAX.

    Args:
        province: İl adı (province_aliases ile esnek match)
        resource: "solar" | "wind" | "hydro"
        years_ahead: 1-10 yıl
        metric: "irradiance" | "sunshine" | "precipitation" | "discharge"

    Returns:
        SarimaxForecast — target="<province>_<resource>_<metric>"
    """
    if resource not in ("solar", "wind", "hydro"):
        raise ValueError("resource 'solar'/'wind'/'hydro' olmalı")
    if years_ahead < 1 or years_ahead > 10:
        raise ValueError("years_ahead 1-10 aralığında olmalı")

    from app.db.database import SystemSessionLocal
    from app.db.models import Climatology
    from app.services.province_aliases import province_aliases

    field_map = {
        "irradiance": "monthly_sunshine_hours",  # proxy
        "sunshine": "monthly_sunshine_hours",
        "precipitation": "monthly_precipitation",
        "cloud": "monthly_cloud_cover",
        "discharge": "monthly_river_discharge",
    }
    target_field = field_map.get(metric)
    # 2026-06-02 (B/#1): "wind" climatology JSON'unda yok; monthly_climate
    # (wind_speed_mean) + daily aggregate'ten get_monthly_series_best ile gelir.
    # Bu yüzden wind için climatology fallback ATLANIR (raise etme).
    if target_field is None and metric != "wind":
        raise ValueError(f"metric geçersiz: {metric}")

    # Climatology — yalnızca son-çare fallback (zorunlu değil; uzun seri varsa
    # hiç kullanılmaz). Eskiden bulunamayınca raise ediyordu → kaldırıldı.
    monthly_fallback: Optional[list] = None
    if target_field:
      with SystemSessionLocal() as db:
        variants = province_aliases(province)
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
            mlist = getattr(row, target_field, None)
            if mlist and len(mlist) == 12:
                # river_discharge dict formatı [{mean,min,max}, …] → mean.
                if isinstance(mlist[0], dict):
                    monthly_fallback = [float(m.get("mean", 0) or 0) for m in mlist]
                else:
                    monthly_fallback = [
                        float(v) if v is not None else 0.0 for v in mlist
                    ]

    # M-E.2: Kaynak önceliği — monthly_climate (20y, ~257 ay) → daily aggregate
    # (~109 ay) → climatology 12-ay × 5 (son çare). get_monthly_series_best
    # ilk ikisini yönetir.
    forecaster = SARIMAXForecaster()
    series: Optional[list] = None
    start_date: Optional[date] = None
    try:
        from app.services.ml_batch_service import get_monthly_series_best
        best_series, best_start = get_monthly_series_best(province, None, metric)
        if best_series and len(best_series) >= 24 and best_start is not None:
            series = best_series
            start_date = date(best_start.year, best_start.month, 1)
    except Exception:
        series = None

    if series is None:
        if not monthly_fallback:
            raise ValueError(
                f"ML serisi bulunamadı: {province} / {resource} / {metric}"
            )
        series = list(monthly_fallback) * 5
        start_date = date.today().replace(day=1).replace(
            year=date.today().year - 5)

    fc = forecaster.forecast(
        series=series,
        start_date=start_date,
        horizon_months=years_ahead * 12,
        target_label=f"{province}_{resource}_{metric}",
    )
    # 2026-06-02: Bu metriklerin (sunshine/precipitation/cloud/discharge/wind)
    # hepsi fiziksel olarak NEGATİF OLAMAZ. SARIMAX ekstrapolasyonu nadiren
    # negatif üretebiliyor (ör. düşük yağış aylarında −13 mm) → grafik yanlış
    # görünüyor. Tahmin noktalarını [0, ∞) aralığına kıstır.
    for p in fc.points:
        if p.value is not None:
            p.value = max(0.0, p.value)
        if getattr(p, "lower", None) is not None:
            p.lower = max(0.0, p.lower)
        if getattr(p, "upper", None) is not None:
            p.upper = max(0.0, p.upper)
    return fc


# ─── Pin Finansal Projeksiyon (M-C) ──────────────────────────────────────────


def _normalize_pin_type(raw: Optional[str]) -> str:
    """Pin type → finance_constants anahtarı."""
    if not raw:
        return "Güneş Paneli"
    t = str(raw).lower()
    if "rüzgar" in t or "wind" in t or "res" in t:
        return "Rüzgar Türbini"
    if "hidro" in t or "hydro" in t or "hes" in t:
        return "Hidroelektrik"
    return "Güneş Paneli"


def project_pin_financial(pin_id: int, years_ahead: int = 10) -> dict:
    """Pin üretim forecast'ı → yıllık finansal projeksiyon (M-C).

    Üretim tahmini (project_pin_generation) × elektrik fiyatı → gelir; CAPEX/
    OPEX ile net nakit akışı + geri ödeme (payback) + CO₂ tasarrufu.

    Para birimi USD (finance_constants). Frontend USD_TO_TRY ile çevirir.
    """
    from app.db.database import SystemSessionLocal
    from app.db.models import Pin
    from app.core import finance_constants as fc

    forecast = project_pin_generation(pin_id, years_ahead=years_ahead)

    with SystemSessionLocal() as db:
        pin = db.query(Pin).filter(Pin.id == pin_id).first()
        capacity_mw = float(getattr(pin, "capacity_mw", 0) or 0) if pin else 0.0
        ptype = _normalize_pin_type(getattr(pin, "type", None) if pin else None)
        pin_name = getattr(pin, "name", None) if pin else None

    price = fc.DEFAULT_ELECTRICITY_PRICE_USD_PER_KWH
    capex = capacity_mw * fc.DEFAULT_CAPEX_PER_MW.get(ptype, 600_000)
    opex_yearly = capex * fc.DEFAULT_OPEX_PCT_YEARLY.get(ptype, 0.015)
    co2_factor = fc.DEFAULT_CO2_INTENSITY_G_PER_KWH / 1000.0  # kg/kWh

    # Forecast point'lerini yıllık kWh'a topla
    yearly_kwh: dict = {}
    for p in forecast.points:
        try:
            yr = int(p.date[:4])
        except Exception:
            continue
        yearly_kwh[yr] = yearly_kwh.get(yr, 0.0) + max(0.0, p.value)

    years_sorted = sorted(yearly_kwh.keys())
    rows = []
    cumulative_net = -capex  # yatırım t=0
    payback_year = None
    for yr in years_sorted:
        kwh = yearly_kwh[yr]
        revenue = kwh * price
        net = revenue - opex_yearly
        cumulative_net += net
        if payback_year is None and cumulative_net >= 0:
            payback_year = yr
        rows.append({
            "year": yr,
            "kwh": round(kwh, 1),
            "revenue_usd": round(revenue, 2),
            "opex_usd": round(opex_yearly, 2),
            "net_usd": round(net, 2),
            "cumulative_net_usd": round(cumulative_net, 2),
            "co2_avoided_tons": round(kwh * co2_factor / 1000.0, 2),
        })

    total_revenue = sum(r["revenue_usd"] for r in rows)
    total_net = sum(r["net_usd"] for r in rows)

    return {
        "pin_id": pin_id,
        "pin_name": pin_name,
        "pin_type": ptype,
        "capacity_mw": capacity_mw,
        "method": forecast.method,
        "currency": "USD",
        "usd_to_try": fc.USD_TO_TRY,
        "price_usd_per_kwh": price,
        "capex_usd": round(capex, 2),
        "opex_usd_yearly": round(opex_yearly, 2),
        "payback_year": payback_year,
        "total_revenue_usd": round(total_revenue, 2),
        "total_net_usd": round(total_net, 2),
        "yearly": rows,
        "disclaimer": (
            "Üretim tahmini SARIMAX/iklim projeksiyonu; fiyat ve maliyetler "
            "sektör ortalaması varsayımıdır (finance_constants). Yatırım kararı "
            "için profesyonel finansal analiz gerekir."
        ),
    }


# ─── Helpers ─────────────────────────────────────────────────────────────────


def _month_end(d: date) -> date:
    next_m = _next_month(d)
    return next_m - timedelta(days=1)


def _next_month(d: date) -> date:
    if d.month == 12:
        return d.replace(year=d.year + 1, month=1, day=1)
    return d.replace(month=d.month + 1, day=1)


_HOURS_PER_YEAR = 8760.0
_RESOURCE_TO_PIN_TYPE = {
    "solar": "Güneş Paneli",
    "wind": "Rüzgar Türbini",
    "hydro": "Hidroelektrik",
}


def _expected_annual_kwh(capacity_mw: float, resource: str) -> float:
    """Kapasite × capacity_factor tabanlı yıllık enerji (kWh).

    Climatology fallback yalnızca tek-yıl iklim profiline sahip; üretim
    büyüklüğü için fiziksel taban: kurulu güç × yıllık saat × CF.
    1 MW solar @ CF 0.18 → ~1.58M kWh/yıl.
    """
    from app.core import finance_constants as fc

    ptype = _RESOURCE_TO_PIN_TYPE.get(resource, "Güneş Paneli")
    cf = fc.DEFAULT_CAPACITY_FACTOR_FALLBACK.get(ptype, 0.18)
    return capacity_mw * 1000.0 * _HOURS_PER_YEAR * cf


def _rescale_climatology_to_energy(
    forecast: SarimaxForecast,
    capacity_mw: float,
    resource: str,
) -> None:
    """Climatology metriğini (güneşlenme saati / debi m³/s) kWh'a ölçekle.

    Climatology forecast'ı **birimsiz mevsimsel şekil** verir; bunu yıllık
    `kapasite × CF` enerjisine ölçekleyerek birim tutarlılığı sağlanır.
    Aylık dağılım korunur (yaz/kış farkı), toplam fizikselleşir.
    Rüzgar için aylık iklim metriği yok → düz (1/12) dağılım.
    `forecast.points` ve `historical` yerinde güncellenir.
    """
    annual_kwh = _expected_annual_kwh(capacity_mw, resource)

    def _flat(points: List[ForecastPoint]) -> None:
        monthly = annual_kwh / 12.0
        for p in points:
            p.value = monthly
            p.lower = monthly
            p.upper = monthly

    def _scaled(points: List[ForecastPoint], scale: float) -> None:
        for p in points:
            p.value = max(0.0, p.value) * scale
            p.lower = max(0.0, p.lower) * scale
            p.upper = max(0.0, p.upper) * scale

    # Rüzgar: aylık wind metriği yok → düz dağılım
    if resource == "wind":
        _flat(forecast.points)
        _flat(forecast.historical)
        return

    pts = forecast.points
    total_metric = sum(max(0.0, p.value) for p in pts)
    if not pts or total_metric <= 0:
        _flat(forecast.points)
        _flat(forecast.historical)
        return

    # Yıllık metrik toplamı → ölçek: her ay kWh = ay_metrik × scale,
    # 12 ay toplamı = annual_kwh.
    n_years = len(pts) / 12.0
    annual_metric = total_metric / n_years
    scale = annual_kwh / annual_metric if annual_metric > 0 else 0.0
    _scaled(forecast.points, scale)
    _scaled(forecast.historical, scale)


def _climatology_fallback(pin, years_ahead: int) -> SarimaxForecast:
    """Pin geçmişi yetersizse il climatology profilini kullan.

    Climatology metriği (güneşlenme saati / debi) yalnızca **mevsimsel şekil**
    verir; enerji büyüklüğü kapasite × capacity_factor'dan ölçeklenir
    (`_rescale_climatology_to_energy`) — birim tutarlılığı için kritik.
    """
    if not pin.city:
        # İl yok — boş forecast
        return SarimaxForecast(
            target=f"pin_{pin.id}_kwh",
            horizon_months=years_ahead * 12,
            history_months=0,
            order=(0, 0, 0),
            seasonal_order=(0, 0, 0, 12),
            method="no_data",
            mape=None,
            points=[],
            historical=[],
            notes=["Pin city bilgisi eksik, climatology fallback yapılamadı"],
        )

    resource = "solar"
    if pin.type:
        t = str(pin.type).lower()
        if "rüzgar" in t or "wind" in t:
            resource = "wind"
        elif "hidro" in t or "hydro" in t or "hes" in t:
            resource = "hydro"

    capacity_mw = float(getattr(pin, "capacity_mw", 0) or 0)

    # 2026-05-28 FIX: wind için 'discharge' YANLIŞ idi (dict format → float()
    # hata). Doğru eşleme: solar→sunshine, wind→sunshine (shape proxy; rescale
    # _flat ezecek), hydro→discharge.
    metric_by_resource = {
        "solar": "sunshine",
        "wind": "sunshine",   # shape için; _rescale_climatology_to_energy
                              # wind'i flat 1/12'ye ezecek
        "hydro": "discharge",
    }
    primary_metric = metric_by_resource.get(resource, "sunshine")
    try:
        forecast = project_climatology(
            province=pin.city,
            resource=resource,
            years_ahead=years_ahead,
            metric=primary_metric,
        )
    except ValueError as ve:
        # 2026-05-28: Bazı iller için hydro/wind climatology satırı yok
        # (örn. HES potansiyeli olmayan iller). Solar shape proxy'sine düş —
        # _rescale_climatology_to_energy yine kapasite×CF ile doğru kWh ölçekler.
        logger.info(
            "Climatology eksik (%s/%s): solar shape proxy'e düşülüyor — %s",
            pin.city, resource, ve,
        )
        try:
            forecast = project_climatology(
                province=pin.city,
                resource="solar",
                years_ahead=years_ahead,
                metric="sunshine",
            )
        except Exception as e2:
            logger.warning("Solar proxy de fail (%s): %s", pin.city, e2)
            return SarimaxForecast(
                target=f"pin_{pin.id}_kwh",
                horizon_months=years_ahead * 12,
                history_months=0,
                order=(0, 0, 0),
                seasonal_order=(0, 0, 0, 12),
                method="no_data",
                mape=None,
                points=[],
                historical=[],
                notes=[f"Climatology fallback fail: {ve} → {e2}"],
            )
    except Exception as e:
        logger.warning("Climatology fallback fail (%s): %s", pin.city, e)
        return SarimaxForecast(
            target=f"pin_{pin.id}_kwh",
            horizon_months=years_ahead * 12,
            history_months=0,
            order=(0, 0, 0),
            seasonal_order=(0, 0, 0, 12),
            method="no_data",
            mape=None,
            points=[],
            historical=[],
            notes=[f"Climatology fallback hata: {e}"],
        )

    # Metrik (saat / m³s) → kWh ölçekle (birim tutarlılığı)
    _rescale_climatology_to_energy(forecast, capacity_mw, resource)
    forecast.target = f"pin_{pin.id}_kwh"
    forecast.method = f"climatology_fallback_{forecast.method}"
    forecast.notes.append(
        f"Climatology fallback — enerji kapasite×CF'den ölçeklendi "
        f"({resource}, {capacity_mw:g} MW)"
    )
    return forecast


# ─── Serialization ───────────────────────────────────────────────────────────


def forecast_to_dict(f: SarimaxForecast) -> dict:
    """JSON-uyumlu dict (FastAPI response için)."""
    return {
        "target": f.target,
        "horizon_months": f.horizon_months,
        "history_months": f.history_months,
        "order": list(f.order),
        "seasonal_order": list(f.seasonal_order),
        "method": f.method,
        "mape": f.mape,
        "confidence_level": f.confidence_level,
        "annual_trend_pct": f.annual_trend_pct,
        "notes": f.notes,
        "points": [
            {"date": p.date, "value": p.value, "lower": p.lower, "upper": p.upper}
            for p in f.points
        ],
        "historical": [
            {"date": p.date, "value": p.value}
            for p in f.historical
        ],
    }

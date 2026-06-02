"""SRRP — ML Forecast Router (P1.6 + P1.7, 2026-05-27).

SARIMAX-bazlı pin ve il bazlı zaman serisi forecast endpoint'leri.

  GET /ml/project/pin/{id}?years=N         — pin generation forecast
  GET /ml/project/province/{name}?years=N  — il climatology forecast

Mevcut /analysis/projection (günlük seasonal naive) korunur, başka yerlerde
kullanılıyor. Bu yeni endpoint **aylık** + **SARIMAX** + **MAPE validation**
ile gelir.

Redis cache (P1.9): pin forecast 24 saat, province forecast 7 gün.
"""
from __future__ import annotations

import json
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

logger = logging.getLogger(__name__)

# P3 (2026-05-28): scenario endpoint eklendi + statsmodels .venv'e kuruldu.
router = APIRouter(prefix="/ml", tags=["🧠 ML Forecast"])


# ── Cache helpers ────────────────────────────────────────────────────────────

def _cache_get(key: str) -> Optional[dict]:
    """Redis cache get — yoksa None."""
    try:
        from app.services.redis_cache import cache_get
        return cache_get(key)
    except Exception:
        return None


def _cache_set(key: str, value: dict, ttl_seconds: int) -> None:
    try:
        from app.services.redis_cache import cache_set
        cache_set(key, value, ttl_seconds=ttl_seconds)
    except Exception as e:
        logger.debug("cache_set fail: %s", e)


# ── Pin Forecast ─────────────────────────────────────────────────────────────


@router.get("/project/pin/{pin_id}", summary="Pin için SARIMAX forecast")
def project_pin(
    pin_id: int,
    years: int = Query(5, ge=1, le=10, description="1-10 yıl forecast"),
):
    """Pin üretim geçmişinden SARIMAX ile aylık forecast (1-10 yıl).

    Yöntem:
      - Pin install_date → bugün aylık aggregate
      - <12 ay geçmiş → il climatology trend fallback
      - statsmodels SARIMAX(p,d,q)(P,D,Q,12) + auto_arima order seçimi
      - 95% confidence interval (alt/üst bant)
      - In-sample MAPE (son 12 ay holdout) — kabul kriteri %20 altı

    Yanıt: `{target, horizon_months, history_months, order, seasonal_order,
    method, mape, points: [{date, value, lower, upper}], historical}`.

    Redis cache: 24 saat (pin verisi sık değişmez).
    """
    cache_key = f"ml:pin:{pin_id}:y{years}"
    cached = _cache_get(cache_key)
    if cached:
        return cached

    try:
        from app.services.ml_sarimax_service import (
            project_pin_generation,
            forecast_to_dict,
        )
        forecast = project_pin_generation(pin_id, years_ahead=years)
        result = forecast_to_dict(forecast)
        _cache_set(cache_key, result, ttl_seconds=24 * 3600)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except RuntimeError as re:
        # statsmodels yüklü değil vs.
        raise HTTPException(status_code=503, detail=str(re))
    except Exception as e:
        logger.exception("Pin %d forecast hatası", pin_id)
        raise HTTPException(status_code=500, detail=f"Forecast hatası: {e}")


# ── Pin Financial Projection (M-C) ───────────────────────────────────────────


@router.get("/project/pin/{pin_id}/financial", summary="Pin finansal projeksiyon")
def project_pin_financial_endpoint(
    pin_id: int,
    years: int = Query(10, ge=1, le=10),
):
    """Pin üretim tahmini → yıllık gelir/gider/net + geri ödeme + CO₂ (M-C).

    Üretim forecast'ı (SARIMAX/iklim) × elektrik fiyatı; CAPEX/OPEX ile net
    nakit akışı + payback yılı. Para birimi USD (frontend USD_TO_TRY çevirir).

    Redis cache: 24 saat.
    """
    cache_key = f"ml:pinfin:{pin_id}:y{years}"
    cached = _cache_get(cache_key)
    if cached:
        return cached
    try:
        from app.services.ml_sarimax_service import project_pin_financial
        result = project_pin_financial(pin_id, years_ahead=years)
        _cache_set(cache_key, result, ttl_seconds=24 * 3600)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except RuntimeError as re:
        raise HTTPException(status_code=503, detail=str(re))
    except Exception as e:
        logger.exception("Pin %d financial hatası", pin_id)
        raise HTTPException(status_code=500, detail=f"Finansal hata: {e}")


# ── Province Forecast ────────────────────────────────────────────────────────


@router.get("/project/province/{province}", summary="İl climatology forecast")
def project_province_endpoint(
    province: str,
    years: int = Query(5, ge=1, le=10),
    resource: str = Query(
        "solar",
        regex="^(solar|wind|hydro)$",
        description="solar | wind | hydro",
    ),
    metric: str = Query(
        "sunshine",
        regex="^(sunshine|precipitation|cloud|discharge|wind)$",
        description="Climatology aylık metriği",
    ),
):
    """İl climatology serisinden SARIMAX trend forecast.

    Kaynak: `climatology.monthly_*` JSON kolonları (R0 CSV import sonrası
    81 il × 2 kaynak = 162 satır dolu). 10-yıllık ortalama → 1-10 yıl ileri
    seasonal pattern continuation.

    Redis cache: 7 gün (climatology yarı-statik, R0 refresh 6 ayda bir).
    """
    cache_key = f"ml:prov:{province}:{resource}:{metric}:y{years}"
    cached = _cache_get(cache_key)
    if cached:
        return cached

    try:
        from app.services.ml_sarimax_service import (
            project_climatology,
            forecast_to_dict,
        )
        forecast = project_climatology(
            province=province,
            resource=resource,
            years_ahead=years,
            metric=metric,
        )
        result = forecast_to_dict(forecast)
        _cache_set(cache_key, result, ttl_seconds=7 * 24 * 3600)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except RuntimeError as re:
        raise HTTPException(status_code=503, detail=str(re))
    except Exception as e:
        logger.exception("Province %s forecast hatası", province)
        raise HTTPException(status_code=500, detail=f"Forecast hatası: {e}")


# ── Climate Scenario Forecast (P3) ───────────────────────────────────────────


@router.get(
    "/scenario/province/{province}",
    summary="İklim senaryosu projeksiyonu (RCP4.5/8.5)",
)
def scenario_province_endpoint(
    province: str,
    years: int = Query(10, ge=1, le=10, description="1-10 yıl ufuk"),
    resource: str = Query(
        "solar",
        regex="^(solar|wind|hydro)$",
    ),
    metric: str = Query(
        "sunshine",
        regex="^(sunshine|precipitation|cloud|discharge|wind)$",
    ),
):
    """İl climatology SARIMAX baseline'ı + RCP4.5 + RCP8.5 senaryoları.

    SARIMAX baz forecast'ın üstüne IPCC bölgesel iklim deltaları uygulanır
    (Akdeniz/Türkiye). Üç seri döner: baseline (sadece geçmiş trend),
    RCP4.5 (orta emisyon), RCP8.5 (yüksek emisyon).

    Yanıt: `{province, resource, metric, horizon_months, baseline_meta,
    scenarios: [{scenario, label, description, color, end_delta_pct,
    points:[{date, value}]}]}`.

    Redis cache: 7 gün (climatology + sabit deltalar → deterministik).
    """
    cache_key = f"ml:scenario:{province}:{resource}:{metric}:y{years}"
    cached = _cache_get(cache_key)
    if cached:
        return cached

    try:
        from app.services.ml_sarimax_service import project_climatology
        from app.services.climate_scenarios import (
            build_scenarios,
            scenarios_to_dict,
        )
        from datetime import date as _date

        baseline = project_climatology(
            province=province,
            resource=resource,
            years_ahead=years,
            metric=metric,
        )
        # Forecast point'lerini (date_obj, value) tuple'a çevir
        baseline_tuples = []
        for p in baseline.points:
            try:
                d = _date.fromisoformat(p.date)
            except Exception:
                continue
            baseline_tuples.append((d, p.value))

        series_map = build_scenarios(baseline_tuples, metric=metric)
        result = {
            "province": province,
            "resource": resource,
            "metric": metric,
            "horizon_months": baseline.horizon_months,
            "baseline_meta": {
                "order": list(baseline.order),
                "seasonal_order": list(baseline.seasonal_order),
                "method": baseline.method,
                "mape": baseline.mape,
                "annual_trend_pct": baseline.annual_trend_pct,
            },
            **scenarios_to_dict(series_map),
        }
        _cache_set(cache_key, result, ttl_seconds=7 * 24 * 3600)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except RuntimeError as re:
        raise HTTPException(status_code=503, detail=str(re))
    except Exception as e:
        logger.exception("Scenario %s forecast hatası", province)
        raise HTTPException(status_code=500, detail=f"Senaryo hatası: {e}")


# ── Thematic Map: Precomputed Choropleth (M-B.1) ─────────────────────────────


@router.get(
    "/choropleth/{metric}",
    summary="Tematik harita: yıl+senaryo bazlı il/ilçe değerleri",
)
def ml_choropleth(
    metric: str,
    year: int = Query(..., ge=2024, le=2040, description="Hedef yıl"),
    month: Optional[int] = Query(
        None, ge=1, le=12,
        description="Opsiyonel ay (1-12); verilmezse yıllık ortalama (M-H.4)"),
    resource: str = Query("solar", regex="^(solar|wind|hydro)$"),
    scenario: str = Query("baseline", regex="^(baseline|rcp45|rcp85)$"),
    level: str = Query("province", regex="^(province|district)$"),
):
    """`ml_forecast` precompute tablosundan tematik harita verisi.

    Belirli **yıl + senaryo + metrik** için tüm illerin (veya ilçelerin) yıllık
    ortalama değeri → `{il_adı: değer}`. Frontend choropleth bunu renklendirir;
    yıl slider'ı ile zaman içinde animasyon yapılır.

    `level=district` istenirse ve ilçe verisi yoksa **ilin değeri** her ilçeye
    atanır (downscaling yok — bkz. plan kısıtı).

    Redis cache: 24 saat (precompute deterministik).
    """
    month_key = month if month else "y"
    cache_key = (f"ml:choro:{metric}:{resource}:{scenario}:{level}:{year}"
                 f":m{month_key}")
    cached = _cache_get(cache_key)
    if cached:
        return cached

    valid_metrics = {"sunshine", "precipitation", "cloud", "discharge", "wind"}
    if metric not in valid_metrics:
        raise HTTPException(status_code=400, detail=f"metric geçersiz: {metric}")

    try:
        from app.db.database import SystemSessionLocal
        from app.db.models import MlForecast
        from sqlalchemy import func

        with SystemSessionLocal() as db:
            # M-H.4: ay verilirse tek değer, yoksa 12-ay AVG (önceki davranış)
            prov_q = db.query(
                MlForecast.province_name,
                func.avg(MlForecast.value).label("avg_val"),
            ).filter(
                MlForecast.scope == "province",
                MlForecast.resource == resource,
                MlForecast.metric == metric,
                MlForecast.scenario == scenario,
                MlForecast.year == year,
            )
            if month is not None:
                prov_q = prov_q.filter(MlForecast.month == month)
            prov_rows = prov_q.group_by(MlForecast.province_name).all()

            # M-F: ilçe bazlı (varsa) — "İl|İlçe" anahtarı
            dist_rows = []
            if level == "district":
                dist_q = db.query(
                    MlForecast.province_name,
                    MlForecast.district_name,
                    func.avg(MlForecast.value).label("avg_val"),
                ).filter(
                    MlForecast.scope == "district",
                    MlForecast.resource == resource,
                    MlForecast.metric == metric,
                    MlForecast.scenario == scenario,
                    MlForecast.year == year,
                    MlForecast.district_name.isnot(None),
                )
                if month is not None:
                    dist_q = dist_q.filter(MlForecast.month == month)
                dist_rows = dist_q.group_by(
                    MlForecast.province_name, MlForecast.district_name).all()

        scores: dict = {}
        # İlçe verisi (varsa) önce — "İl|İlçe" anahtarı
        for prov, dist, v in dist_rows:
            if v is not None:
                scores[f"{prov}|{dist}"] = round(float(v), 2)
        # İl verisi — düz "İl" anahtarı (frontend district key tutmazsa fallback)
        for prov, v in prov_rows:
            if v is not None:
                scores[prov] = round(float(v), 2)
        # İl adlarını GADM ile eşleştir: 'Afyon'→'Afyonkarahisar',
        # 'K. Maras'→'Kahramanmaraş'. Frontend choropleth NAME_1 ile eşleştirir;
        # canonical + alias varyantları ekle ki polygon tutsun (siyah delik önleme).
        try:
            from app.services.province_aliases import province_aliases, to_canonical
            expanded = dict(scores)
            for prov, val in scores.items():
                keys = {to_canonical(prov)}
                keys.update(province_aliases(prov))
                keys.update(province_aliases(to_canonical(prov)))
                for k in keys:
                    expanded.setdefault(k, val)
            scores = expanded
        except Exception as e:
            logger.debug("ml_choropleth alias expand fail: %s", e)
        vals = list(scores.values())
        result = {
            "metric": metric,
            "resource": resource,
            "scenario": scenario,
            "level": level,
            "year": year,
            "count": len(scores),
            "min": min(vals) if vals else None,
            "max": max(vals) if vals else None,
            "scores": scores,
            "note": (
                "İlçe verisi yok; il değerleri kullanılıyor"
                if level == "district" else None
            ),
        }
        _cache_set(cache_key, result, ttl_seconds=24 * 3600)
        return result
    except Exception as e:
        logger.exception("Choropleth hatası %s/%s", metric, year)
        raise HTTPException(status_code=500, detail=f"Choropleth hatası: {e}")


@router.get("/choropleth/{metric}/years", summary="Mevcut forecast yılları")
def ml_choropleth_years(
    metric: str,
    resource: str = Query("solar", regex="^(solar|wind|hydro)$"),
):
    """Precompute tablosunda bu metrik için mevcut yıl aralığı (slider için)."""
    try:
        from app.db.database import SystemSessionLocal
        from app.db.models import MlForecast
        from sqlalchemy import func

        with SystemSessionLocal() as db:
            mn, mx = (
                db.query(func.min(MlForecast.year), func.max(MlForecast.year))
                .filter(
                    MlForecast.scope == "province",
                    MlForecast.resource == resource,
                    MlForecast.metric == metric,
                )
                .first()
            )
        return {"metric": metric, "resource": resource,
                "min_year": mn, "max_year": mx}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ── Birleşik Seri: Historical + Forecast (M-H.1) ─────────────────────────────


@router.get(
    "/series/{province}",
    summary="10 yıl geçmiş + 10 yıl projeksiyon birleşik aylık seri",
)
def ml_series(
    province: str,
    district: Optional[str] = Query(None, description="Opsiyonel ilçe"),
    metric: str = Query("sunshine", regex="^(sunshine|wind|temperature)$"),
    history_years: int = Query(10, ge=1, le=10),
    horizon_years: int = Query(10, ge=1, le=10),
    scenario: str = Query("baseline", regex="^(baseline|rcp45|rcp85)$"),
):
    """Tek ilin/ilçenin gerçek aylık geçmişi + ML projeksiyonu (Reports için).

    - **historical**: `weather_data` günlüğünden son N yıl ay-bazlı ortalama
      (gerçek varyasyon, climatology değil)
    - **forecast**: `ml_forecast` precompute tablosundan (M-A/M-F batch)

    Aynı seri olarak iki bölüm — Reports/Projeksiyon "10 yıl + 10 yıl" trend
    grafiği için.
    """
    cache_key = (f"ml:series:{province}:{district or '-'}:{metric}:"
                 f"{history_years}:{horizon_years}:{scenario}")
    cached = _cache_get(cache_key)
    if cached:
        return cached

    try:
        from app.services.ml_batch_service import get_monthly_series_from_daily
        from app.db.database import SystemSessionLocal
        from app.db.models import MlForecast
        from sqlalchemy import asc

        # Geçmiş (gerçek daily aggregate)
        hist_values, hist_start = get_monthly_series_from_daily(
            province, district, metric,
        )
        # Son history_years aya kadar kırp
        if hist_values:
            max_points = history_years * 12
            if len(hist_values) > max_points:
                hist_values = hist_values[-max_points:]
                # start_date'i ileri kaydır
                from datetime import date as _d
                offset_months = len(hist_values) - max_points
                # Actually simpler: re-derive start by shifting
                y, m = hist_start.year, hist_start.month
                m_new = m + offset_months
                hist_start = _d(y + (m_new - 1) // 12, ((m_new - 1) % 12) + 1, 1)

        historical = []
        if hist_values and hist_start:
            y, m = hist_start.year, hist_start.month
            for v in hist_values:
                historical.append({
                    "date": f"{y:04d}-{m:02d}-01",
                    "value": round(v, 3),
                })
                m += 1
                if m > 12:
                    m = 1
                    y += 1

        # Forecast (ml_forecast tablosundan)
        # Resource mapping (sunshine→solar, wind→wind, temperature→solar)
        resource_map = {"sunshine": "solar", "wind": "wind", "temperature": "solar"}
        resource = resource_map.get(metric, "solar")
        scope = "district" if district else "province"

        with SystemSessionLocal() as db:
            q = (db.query(MlForecast.year, MlForecast.month,
                          MlForecast.value, MlForecast.lower, MlForecast.upper)
                 .filter(
                    MlForecast.scope == scope,
                    MlForecast.province_name == province,
                    MlForecast.metric == metric,
                    MlForecast.resource == resource,
                    MlForecast.scenario == scenario,
                 ))
            if district:
                q = q.filter(MlForecast.district_name == district)
            else:
                q = q.filter(MlForecast.district_name.is_(None))
            q = q.order_by(asc(MlForecast.year), asc(MlForecast.month))
            fc_rows = q.limit(horizon_years * 12).all()

        forecast = [
            {
                "date": f"{y:04d}-{m:02d}-01",
                "value": round(float(v), 3),
                "lower": round(float(lo), 3) if lo is not None else None,
                "upper": round(float(up), 3) if up is not None else None,
            }
            for y, m, v, lo, up in fc_rows
        ]

        result = {
            "province": province,
            "district": district,
            "metric": metric,
            "scenario": scenario,
            "history_months": len(historical),
            "forecast_months": len(forecast),
            "historical": historical,
            "forecast": forecast,
        }
        _cache_set(cache_key, result, ttl_seconds=24 * 3600)
        return result
    except Exception as e:
        logger.exception("ml_series hatası %s/%s", province, district)
        raise HTTPException(status_code=500, detail=f"Seri hatası: {e}")


# ── Health check ─────────────────────────────────────────────────────────────


@router.get("/health", summary="ML servis durumu")
def ml_health():
    """SARIMAX servisi yüklü mü? Dependency check."""
    deps = {}
    try:
        import statsmodels  # type: ignore
        deps["statsmodels"] = statsmodels.__version__
    except Exception as e:
        deps["statsmodels"] = f"NOT INSTALLED ({e})"
    try:
        import pmdarima  # type: ignore
        deps["pmdarima"] = pmdarima.__version__
    except Exception as e:
        deps["pmdarima"] = f"NOT INSTALLED ({e})"
    try:
        import numpy  # type: ignore
        deps["numpy"] = numpy.__version__
    except Exception as e:
        deps["numpy"] = f"NOT INSTALLED ({e})"
    try:
        import pandas  # type: ignore
        deps["pandas"] = pandas.__version__
    except Exception as e:
        deps["pandas"] = f"NOT INSTALLED ({e})"

    ready = "NOT INSTALLED" not in (
        deps["statsmodels"] + deps["numpy"] + deps["pandas"]
    )
    return {
        "ready": ready,
        "auto_arima": "NOT INSTALLED" not in deps["pmdarima"],
        "dependencies": deps,
        "endpoints": [
            "GET /ml/project/pin/{id}?years=N",
            "GET /ml/project/province/{name}?years=N&resource=solar&metric=sunshine",
        ],
    }

"""
SRRP — Chatbot Tool Implementasyonları (Aşama 3.C.2)
====================================================

Gemini function calling ile chatbot'un çağırabileceği güvenli (sandboxed)
fonksiyonlar. Text-to-SQL **yok** — saldırı yüzeyi azaltmak ve
öngörülebilir davranış için sadece pre-defined tool'lar.

Eklenen tool'lar:
  * ``get_province_score(province, resource, horizon)``
  * ``get_recommendations(resource, horizon, top_n)``
  * ``compare_provinces(provinces, resource)``
  * ``get_scenario_financials(scenario_id)``
  * ``get_weather_summary(province, mode, season)``
  * ``compute_what_if(pin_specs)``  — "Manisa'ya 10 türbin koysak?" tarzı

Her fonksiyon JSON-serializable dict döner; bilinmeyen veri için
``{"error": "...", "hint": "..."}`` formatı kullanır.

Gemini SDK ``GEMINI_TOOL_DECLARATIONS`` listesini okur ve modele tool
şemalarını verir. Model bir tool çağırmaya karar verirse
``chatbot_service._execute_tool`` dispatcher buradaki fonksiyonu çağırır.
"""
from __future__ import annotations

import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)

# ─── Lazy import: Gemini protos sadece SDK varsa ─────────────────────────────
try:
    import google.generativeai as genai  # type: ignore
    _SDK_OK = True
except Exception:
    genai = None  # type: ignore
    _SDK_OK = False


# ─── Tool fonksiyonları ─────────────────────────────────────────────────────

def get_province_score(args: dict, current_user_id: Optional[int]) -> dict:
    """`province_analysis` tablosundan il skoru.

    Args dict:
        province (str): "Manisa", "İzmir" vb.
        resource (str): "wind" | "solar" | "hydro"
        horizon (str): "1m" | "3m" | "6m" | "yearly"
    """
    province = (args.get("province") or "").strip()
    resource = (args.get("resource") or "").strip().lower()
    horizon = (args.get("horizon") or "yearly").strip().lower()

    if not province:
        return {"error": "province parametresi zorunlu"}
    if resource not in ("wind", "solar", "hydro"):
        return {"error": "resource 'wind', 'solar' veya 'hydro' olmalı"}
    if horizon not in ("1m", "3m", "6m", "yearly"):
        return {"error": "horizon '1m', '3m', '6m' veya 'yearly' olmalı"}

    try:
        from app.db.database import UserSessionLocal
        from app.db import models

        col_map = {
            "1m": "score_1m",
            "3m": "score_3m",
            "6m": "score_6m",
            "yearly": "score_yearly",
        }
        col_name = col_map[horizon]

        with UserSessionLocal() as db:
            row = (
                db.query(models.ProvinceAnalysis)
                .filter(
                    models.ProvinceAnalysis.province_name.ilike(f"%{province}%"),
                    models.ProvinceAnalysis.resource_type == resource,
                )
                .first()
            )
        if not row:
            return {
                "error": f"{province} için {resource} verisi bulunamadı",
                "hint": "İl adını kontrol edin (ör. 'Manisa'). Resource: wind/solar/hydro.",
            }
        score = getattr(row, col_name, None)
        return {
            "province": row.province_name,
            "resource": resource,
            "horizon": horizon,
            "score": round(float(score), 2) if score is not None else None,
            "capacity_factor": float(row.capacity_factor) if row.capacity_factor else None,
            "sample_count": int(row.sample_count or 0),
            "updated_at": row.computed_at.isoformat() if row.computed_at else None,
        }
    except Exception as e:
        logger.exception("[chatbot] get_province_score hatası")
        return {"error": str(e)}


def get_recommendations(args: dict, current_user_id: Optional[int]) -> dict:
    """Top-N illeri (rüzgar/güneş/hidro) skor sırasıyla getirir."""
    resource = (args.get("resource") or "").strip().lower()
    horizon = (args.get("horizon") or "yearly").strip().lower()
    top_n = int(args.get("top_n") or 10)

    if resource not in ("wind", "solar", "hydro"):
        return {"error": "resource 'wind'|'solar'|'hydro' olmalı"}
    if horizon not in ("1m", "3m", "6m", "yearly"):
        return {"error": "horizon '1m'|'3m'|'6m'|'yearly' olmalı"}
    top_n = max(1, min(top_n, 30))

    try:
        from app.db.database import UserSessionLocal
        from app.db import models

        col_map = {
            "1m": models.ProvinceAnalysis.score_1m,
            "3m": models.ProvinceAnalysis.score_3m,
            "6m": models.ProvinceAnalysis.score_6m,
            "yearly": models.ProvinceAnalysis.score_yearly,
        }
        col = col_map[horizon]

        with UserSessionLocal() as db:
            rows = (
                db.query(models.ProvinceAnalysis)
                .filter(
                    models.ProvinceAnalysis.resource_type == resource,
                    col.isnot(None),
                )
                .order_by(col.desc())
                .limit(top_n)
                .all()
            )

        items = []
        for r in rows:
            score = getattr(r, f"score_{horizon}" if horizon != "yearly" else "score_yearly")
            items.append({
                "rank": len(items) + 1,
                "province": r.province_name,
                "score": round(float(score), 2) if score else None,
                "capacity_factor": float(r.capacity_factor) if r.capacity_factor else None,
            })
        return {
            "resource": resource,
            "horizon": horizon,
            "items": items,
            "count": len(items),
        }
    except Exception as e:
        logger.exception("[chatbot] get_recommendations hatası")
        return {"error": str(e)}


def compare_provinces(args: dict, current_user_id: Optional[int]) -> dict:
    """İki veya daha fazla ili yan yana karşılaştır.

    Args:
        provinces (list[str]): ["Manisa", "İzmir"]
        resource (str): "wind"|"solar"|"hydro"
    """
    provinces = args.get("provinces") or []
    if not isinstance(provinces, list):
        # Gemini bazen tek string yollar
        provinces = [str(provinces)]
    provinces = [str(p).strip() for p in provinces if str(p).strip()]
    if not provinces:
        return {"error": "En az 1 il adı verin"}
    if len(provinces) > 10:
        return {"error": "En fazla 10 il karşılaştırılabilir"}
    resource = (args.get("resource") or "wind").strip().lower()
    if resource not in ("wind", "solar", "hydro"):
        return {"error": "resource 'wind'|'solar'|'hydro' olmalı"}

    results = []
    for p in provinces:
        r = get_province_score({"province": p, "resource": resource, "horizon": "yearly"}, current_user_id)
        results.append(r)
    return {"resource": resource, "comparison": results}


def get_scenario_financials(args: dict, current_user_id: Optional[int]) -> dict:
    """Senaryonun finansal projeksiyonu (CAPEX, LCOE, payback, NPV, IRR, CO₂).

    Args:
        scenario_id (int): Senaryo id'si — current_user'a ait olmalı.
    """
    sid = args.get("scenario_id")
    try:
        sid = int(sid)
    except (TypeError, ValueError):
        return {"error": "scenario_id integer olmalı"}
    if current_user_id is None:
        return {"error": "Kullanıcı oturumu yok"}

    try:
        from app.db.database import UserSessionLocal, UserPinsSessionLocal
        from app.db import models
        from app.services.finance_service import (
            compute_scenario_financials,
            PinFinanceInput,
        )
        import json

        with UserSessionLocal() as db:
            sc = db.query(models.Scenario).filter(models.Scenario.id == sid).first()
            if not sc:
                return {"error": f"Senaryo {sid} bulunamadı"}
            if sc.owner_id != current_user_id:
                return {"error": "Bu senaryoya erişim yetkiniz yok"}

            raw_pin_ids = sc.pin_ids
            if isinstance(raw_pin_ids, str):
                try:
                    raw_pin_ids = json.loads(raw_pin_ids)
                except Exception:
                    raw_pin_ids = []
            pin_ids = list(raw_pin_ids or [])

            pin_inputs: list[PinFinanceInput] = []
            for pid in pin_ids:
                p = db.query(models.Pin).filter(models.Pin.id == pid).first()
                if not p:
                    continue
                cf = None
                with UserPinsSessionLocal() as up:
                    latest = (
                        up.query(models.PinCalculationResult)
                        .filter(models.PinCalculationResult.pin_id == pid)
                        .order_by(models.PinCalculationResult.created_at.desc())
                        .first()
                    )
                    if latest and latest.capacity_factor:
                        cf = float(latest.capacity_factor)
                pin_inputs.append(PinFinanceInput(
                    pin_id=int(p.id),
                    pin_type=str(p.type),
                    capacity_mw=float(p.capacity_mw or 1.0),
                    capacity_factor=cf,
                ))

        m = compute_scenario_financials(pin_inputs)
        return {
            "scenario_id": sid,
            "scenario_name": sc.name,
            "capex_total_usd": m.capex_total,
            "annual_kwh": m.annual_production_kwh,
            "annual_revenue_usd": m.annual_revenue,
            "lcoe_usd_per_kwh": m.lcoe_usd_per_kwh,
            "payback_years": m.payback_period_years if m.payback_period_years > 0 else None,
            "npv_usd": m.npv_usd,
            "irr_pct": m.irr_pct,
            "co2_avoided_tons_per_year": m.annual_co2_avoided_tons,
            "project_lifetime_years": m.project_lifetime_years,
        }
    except Exception as e:
        logger.exception("[chatbot] get_scenario_financials hatası")
        return {"error": str(e)}


def get_weather_summary(args: dict, current_user_id: Optional[int]) -> dict:
    """Bir il için hava durumu özeti (rüzgar/güneş/sıcaklık ortalamaları).

    Args:
        province (str): İl adı
        mode (str, opsiyonel): "current"|"week"|"month"|"yearly"|"season"
        season (str, opsiyonel): mode=season için "winter"|"spring"|"summer"|"autumn"
    """
    province = (args.get("province") or "").strip()
    mode = (args.get("mode") or "yearly").strip().lower()
    season = args.get("season")

    if not province:
        return {"error": "province parametresi zorunlu"}

    try:
        from app.services.redis_cache import cache_get
        # Önce cache'e bak (province-summary endpoint'i de bu key'i kullanıyor)
        key_window = f"mode={mode}:season={season or '-'}"
        cache_key = f"weather:province-summary:{key_window}"
        cached = cache_get(cache_key)
        if cached and isinstance(cached, list):
            for item in cached:
                if str(item.get("province_name", "")).lower() == province.lower():
                    return {
                        "province": item.get("province_name"),
                        "mode": mode,
                        "season": season,
                        "avg_wind_speed_mps": item.get("avg_wind_speed"),
                        "avg_radiation_wm2": item.get("avg_radiation"),
                        "avg_temperature_c": item.get("avg_temperature"),
                        "record_count": item.get("record_count"),
                    }
        # Cache'de yoksa anlık DB sorgusu
        from app.db.database import SystemSessionLocal
        from app.db.models import HourlyWeatherData
        from app.core.time_window import resolve_time_window
        from sqlalchemy import func, or_, extract
        from datetime import datetime, timedelta

        if mode == "current":
            cutoff = datetime.now() - timedelta(hours=168)
            end_ts = None
            months = None
        else:
            try:
                tw = resolve_time_window(mode, season)
                cutoff = tw.start
                end_ts = tw.end
                months = tw.months
            except Exception as ex:
                return {"error": f"Geçersiz mode/season: {ex}"}

        with SystemSessionLocal() as db:
            q = db.query(
                func.avg(HourlyWeatherData.wind_speed_100m).label("avg_wind"),
                func.avg(HourlyWeatherData.shortwave_radiation).label("avg_rad"),
                func.avg(HourlyWeatherData.temperature_2m).label("avg_temp"),
                func.count(HourlyWeatherData.id).label("count"),
            ).filter(
                HourlyWeatherData.timestamp >= cutoff,
                HourlyWeatherData.city_name.ilike(f"%{province}%"),
                or_(
                    HourlyWeatherData.district_name.is_(None),
                    HourlyWeatherData.district_name == "Merkez",
                ),
            )
            if end_ts is not None:
                q = q.filter(HourlyWeatherData.timestamp <= end_ts)
            if months:
                q = q.filter(extract("month", HourlyWeatherData.timestamp).in_(months))
            r = q.first()

        if not r or not r.count:
            return {"error": f"{province} için veri bulunamadı"}
        return {
            "province": province,
            "mode": mode,
            "season": season,
            "avg_wind_speed_mps": round(float(r.avg_wind), 2) if r.avg_wind else None,
            "avg_radiation_wm2": round(float(r.avg_rad), 1) if r.avg_rad else None,
            "avg_temperature_c": round(float(r.avg_temp), 2) if r.avg_temp else None,
            "record_count": int(r.count or 0),
        }
    except Exception as e:
        logger.exception("[chatbot] get_weather_summary hatası")
        return {"error": str(e)}


def compute_what_if(args: dict, current_user_id: Optional[int]) -> dict:
    """Hipotetik yatırım hesabı — "X ile Y MW Z kursak ne olur?".

    Args:
        pin_specs (list[dict]): [{"type": "Rüzgar Türbini", "capacity_mw": 10},
                                  {"type": "Güneş Paneli", "capacity_mw": 5}]
    """
    specs = args.get("pin_specs") or []
    if not isinstance(specs, list) or not specs:
        return {"error": "pin_specs liste içinde en az bir öğe içermeli"}

    try:
        from app.services.finance_service import (
            compute_scenario_financials,
            PinFinanceInput,
        )
        VALID_TYPES = {"Güneş Paneli", "Rüzgar Türbini", "Hidroelektrik"}
        pin_inputs: list[PinFinanceInput] = []
        for i, s in enumerate(specs):
            ptype = str(s.get("type") or "").strip()
            cap = float(s.get("capacity_mw") or 0)
            if ptype not in VALID_TYPES:
                return {
                    "error": (
                        f"Geçersiz pin tipi '{ptype}'. "
                        f"Kabul edilenler: {sorted(VALID_TYPES)}"
                    )
                }
            if cap <= 0:
                return {"error": f"capacity_mw pozitif olmalı (item {i})"}
            pin_inputs.append(PinFinanceInput(
                pin_id=-(i + 1),  # negatif → hipotetik
                pin_type=ptype,
                capacity_mw=cap,
                capacity_factor=s.get("capacity_factor"),
            ))

        m = compute_scenario_financials(pin_inputs)
        return {
            "hypothetical": True,
            "pin_count": len(pin_inputs),
            "capex_total_usd": m.capex_total,
            "annual_kwh": m.annual_production_kwh,
            "annual_revenue_usd": m.annual_revenue,
            "lcoe_usd_per_kwh": m.lcoe_usd_per_kwh,
            "payback_years": m.payback_period_years if m.payback_period_years > 0 else None,
            "npv_usd": m.npv_usd,
            "irr_pct": m.irr_pct,
            "co2_avoided_tons_per_year": m.annual_co2_avoided_tons,
            "project_lifetime_years": m.project_lifetime_years,
        }
    except Exception as e:
        logger.exception("[chatbot] compute_what_if hatası")
        return {"error": str(e)}


# ─── Gemini Tool Declarations ───────────────────────────────────────────────
# Gemini'nin function calling formatı — `Tool(function_declarations=[...])`.

if _SDK_OK:
    GEMINI_TOOL_DECLARATIONS = [
        genai.protos.Tool(  # type: ignore
            function_declarations=[
                genai.protos.FunctionDeclaration(  # type: ignore
                    name="get_province_score",
                    description=(
                        "Bir ilin enerji potansiyel skorunu getirir "
                        "(rüzgar/güneş/hidro × 1 ay/3 ay/6 ay/yıllık)."
                    ),
                    parameters=genai.protos.Schema(  # type: ignore
                        type=genai.protos.Type.OBJECT,  # type: ignore
                        properties={
                            "province": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.STRING,  # type: ignore
                                description="İl adı (Manisa, İzmir, Konya vb.)",
                            ),
                            "resource": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.STRING,  # type: ignore
                                description="wind | solar | hydro",
                            ),
                            "horizon": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.STRING,  # type: ignore
                                description="1m | 3m | 6m | yearly",
                            ),
                        },
                        required=["province", "resource"],
                    ),
                ),
                genai.protos.FunctionDeclaration(  # type: ignore
                    name="get_recommendations",
                    description="Top-N ili (rüzgar/güneş/hidro) skor sırasıyla listeler.",
                    parameters=genai.protos.Schema(  # type: ignore
                        type=genai.protos.Type.OBJECT,  # type: ignore
                        properties={
                            "resource": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.STRING,
                                description="wind | solar | hydro",
                            ),
                            "horizon": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.STRING,
                                description="1m | 3m | 6m | yearly",
                            ),
                            "top_n": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.INTEGER,
                                description="Kaç il listelensin (1-30)",
                            ),
                        },
                        required=["resource"],
                    ),
                ),
                genai.protos.FunctionDeclaration(  # type: ignore
                    name="compare_provinces",
                    description="Birden fazla ili yan yana karşılaştırır.",
                    parameters=genai.protos.Schema(  # type: ignore
                        type=genai.protos.Type.OBJECT,
                        properties={
                            "provinces": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.ARRAY,
                                items=genai.protos.Schema(type=genai.protos.Type.STRING),  # type: ignore
                                description="['Manisa', 'İzmir']",
                            ),
                            "resource": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.STRING,
                                description="wind | solar | hydro",
                            ),
                        },
                        required=["provinces", "resource"],
                    ),
                ),
                genai.protos.FunctionDeclaration(  # type: ignore
                    name="get_scenario_financials",
                    description=(
                        "Mevcut bir senaryonun CAPEX, LCOE, payback period, "
                        "NPV, IRR ve yıllık CO₂ avoidance değerlerini hesaplar."
                    ),
                    parameters=genai.protos.Schema(  # type: ignore
                        type=genai.protos.Type.OBJECT,
                        properties={
                            "scenario_id": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.INTEGER,
                                description="Kullanıcının senaryosunun id'si",
                            ),
                        },
                        required=["scenario_id"],
                    ),
                ),
                genai.protos.FunctionDeclaration(  # type: ignore
                    name="get_weather_summary",
                    description=(
                        "Bir il için hava özeti (ortalama rüzgar hızı, ışınım, "
                        "sıcaklık) — seçilen zaman penceresinde."
                    ),
                    parameters=genai.protos.Schema(  # type: ignore
                        type=genai.protos.Type.OBJECT,
                        properties={
                            "province": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.STRING,
                                description="İl adı",
                            ),
                            "mode": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.STRING,
                                description="current|week|month|threeMonth|sixMonth|yearly|season",
                            ),
                            "season": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.STRING,
                                description="mode=season için: winter|spring|summer|autumn",
                            ),
                        },
                        required=["province"],
                    ),
                ),
                genai.protos.FunctionDeclaration(  # type: ignore
                    name="compute_what_if",
                    description=(
                        "Hipotetik bir yatırım için finansal projeksiyon. "
                        "Örn: 'Manisa'ya 10 MW rüzgar + 5 MW güneş kursak'."
                    ),
                    parameters=genai.protos.Schema(  # type: ignore
                        type=genai.protos.Type.OBJECT,
                        properties={
                            "pin_specs": genai.protos.Schema(  # type: ignore
                                type=genai.protos.Type.ARRAY,
                                items=genai.protos.Schema(  # type: ignore
                                    type=genai.protos.Type.OBJECT,
                                    properties={
                                        "type": genai.protos.Schema(  # type: ignore
                                            type=genai.protos.Type.STRING,
                                            description="'Güneş Paneli' | 'Rüzgar Türbini' | 'Hidroelektrik'",
                                        ),
                                        "capacity_mw": genai.protos.Schema(  # type: ignore
                                            type=genai.protos.Type.NUMBER,
                                        ),
                                    },
                                ),
                            ),
                        },
                        required=["pin_specs"],
                    ),
                ),
            ],
        ),
    ]
else:
    GEMINI_TOOL_DECLARATIONS: list[Any] = []  # type: ignore

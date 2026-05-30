"""
SRRP — Pin Generation History Service (Sprint S1, 2026-05-17)
=============================================================

Kullanıcının pininin **kurulduğu tarihten itibaren** ne kadar elektrik
üretmiş olduğunu hesaplar. Climatology mimarisinin **dinamik** tarafı —
statik climatology (skor) vs. dinamik pin generation (gerçek üretim).

**Hesap mantığı (Manisa örneği):**
- Pin Manisa'da, capacity_mw=2.0, installation_date=2023-01-01
- Climatology'de Manisa wind: capacity_factor=0.19, hourly_typical_profile
- Hesap: her saatte üretim = cf(month, hour) × capacity × 1h
- Aggregate: today / month / year / total / custom range

**Veri kaynakları:**
- Saatlik veri var (`hourly_weather_data`, son 2 yıl) → gerçek üretim
- Eski tarihler için → climatology `hourly_typical_profile` × pin specs

**Return formatı (frontend Üretim Geçmişi sekmesi):**
```json
{
    "pin_id": 42,
    "period": "month",
    "start_date": "2024-04-01",
    "end_date": "2024-05-01",
    "total_kwh": 1456.7,
    "daily_breakdown": [{"date": "2024-04-01", "kwh": 48.2}, ...],
    "comparison_prev_period": 1320.5,
    "comparison_pct_change": 10.3
}
```

Plan: BACKEND-PLAN-2026-05-17.md S1.7
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, date
from typing import Literal, Optional

from sqlalchemy import and_, or_, func

from app.db.database import SystemSessionLocal, UserSessionLocal
from app.db.models import Climatology, HourlyWeatherData, Pin
from app.services.climatology_service import (
    _tr_ascii_fold,
    _wind_power_curve,
    GHI_STC_WM2,
)

logger = logging.getLogger(__name__)

Period = Literal["today", "week", "month", "year", "total", "range"]

# Backend pin tipi → climatology resource_type
_TYPE_TO_RESOURCE = {
    "Güneş Paneli": "solar",
    "Rüzgar Türbini": "wind",
    "Hidroelektrik": "hydro",
}


@dataclass
class GenerationResult:
    pin_id: int
    period: str
    start_date: datetime
    end_date: datetime
    total_kwh: float
    daily_breakdown: list[dict]
    comparison_prev_period_kwh: Optional[float] = None
    comparison_pct_change: Optional[float] = None
    data_source: str = "unknown"  # "hourly_actual" | "climatology_interpolated" | "hybrid"
    pin_meta: Optional[dict] = None


def _resolve_period(
    period: Period,
    custom_start: Optional[datetime] = None,
    custom_end: Optional[datetime] = None,
) -> tuple[datetime, datetime]:
    """period string → (start, end) datetime."""
    now = datetime.utcnow()
    today_start = datetime(now.year, now.month, now.day)

    if period == "today":
        return today_start, today_start + timedelta(days=1)
    if period == "week":
        return today_start - timedelta(days=7), today_start + timedelta(days=1)
    if period == "month":
        return today_start - timedelta(days=30), today_start + timedelta(days=1)
    if period == "year":
        return today_start - timedelta(days=365), today_start + timedelta(days=1)
    if period == "total":
        # caller installation_date'i geçecek
        return datetime(2000, 1, 1), today_start + timedelta(days=1)
    if period == "range":
        if not custom_start or not custom_end:
            raise ValueError("period='range' için start ve end zorunlu")
        return custom_start, custom_end
    raise ValueError(f"Geçersiz period: {period}")


def _compute_wind_hourly_kwh(
    wind_speed_mps: float,
    capacity_mw: float,
) -> float:
    """Saatlik rüzgar üretimi (kWh).

    power_curve [0..1] × capacity_mw × 1 saat × 1000 (MW→kW)
    """
    cf = _wind_power_curve(wind_speed_mps)
    return cf * capacity_mw * 1000.0  # 1 saat


def _compute_solar_hourly_kwh(
    ghi_wm2: float,
    capacity_mw: float,
    panel_area_m2: Optional[float] = None,
) -> float:
    """Saatlik güneş üretimi (kWh).

    capacity_mw direkt verilmişse: cf × capacity × 1h
    panel_area verilmişse: GHI × area × verim × 1h (gerçekçi)

    Pilot fazda capacity-based — basit.
    """
    pr = 0.80  # performance ratio
    cf = min(ghi_wm2, GHI_STC_WM2) / GHI_STC_WM2 * pr
    return cf * capacity_mw * 1000.0


def _get_climatology_for_pin(pin: Pin) -> Optional[Climatology]:
    """Pin'in tipine + konumuna en uygun climatology row'u bul.

    Pin'in city / district bilgisi varsa exact match. Yoksa lat/lon'dan
    en yakın il (S3'te PostGIS-aware olur).
    """
    resource = _TYPE_TO_RESOURCE.get(pin.type)
    if not resource:
        return None
    if not pin.city:
        return None

    from app.services.province_aliases import canonical_match_filter
    city_filter = canonical_match_filter(Climatology.province_name, pin.city)
    if city_filter is None:
        return None

    with SystemSessionLocal() as db:
        # Önce ilçe seviyesi (varsa daha doğru)
        if pin.district:
            dist_orig = pin.district
            dist_fold = _tr_ascii_fold(pin.district)
            row = db.query(Climatology).filter(
                city_filter,
                or_(
                    Climatology.district_name == dist_orig,
                    Climatology.district_name == dist_fold,
                ),
                Climatology.resource_type == resource,
            ).first()
            if row:
                return row
        # İl bazlı fallback
        return db.query(Climatology).filter(
            city_filter,
            Climatology.district_name.is_(None),
            Climatology.resource_type == resource,
        ).first()


def _generation_from_hourly_actual(
    pin: Pin,
    start: datetime,
    end: datetime,
) -> tuple[float, list[dict], int]:
    """Saatlik gerçek veriden üretim hesabı (son 2 yıl içindeki tarihler).

    2026-05-19 bug fix: lat/lon grid exact match yerine city_name+district_name
    eşleşmesi (hourly_weather_data primary index zaten bu). Önceki davranış
    `round(lat*2)/2` ile 0.5 grid match istiyordu — `hourly_weather_data`
    farklı precision'da toplandığı için her zaman 0 dönüyordu.

    Returns: (total_kwh, daily_breakdown, sample_count)
    """
    resource = _TYPE_TO_RESOURCE.get(pin.type)
    capacity = float(pin.capacity_mw or 1.0)

    # 2026-05-19 Bug A — pin.city None ise erken çık. Önceki davranış:
    # city filter atlanıyor → tüm Türkiye'nin hourly_weather'i toplanıyor →
    # 7.5M kWh gibi imkânsız değerler. Doğrusu: city olmayan pin için
    # generation hesaplanamaz, no_data.
    if not pin.city:
        return 0.0, [], 0

    if resource == "wind":
        metric_col = HourlyWeatherData.wind_speed_100m
    elif resource == "solar":
        metric_col = HourlyWeatherData.shortwave_radiation
    else:
        return 0.0, [], 0

    with SystemSessionLocal() as db:
        # 2026-05-19 — city/district match. lat/lon round eski mantık iptal.
        # province_aliases ile hem ASCII fold (Balıkesir↔Balikesir) hem
        # kısaltmalı varyasyonları (Kahramanmaraş↔K. Maras) tolere et.
        from app.services.province_aliases import canonical_match_filter
        city_filter = canonical_match_filter(HourlyWeatherData.city_name, pin.city)
        if city_filter is None:
            return 0.0, [], 0
        loc_filter = [
            HourlyWeatherData.timestamp >= start,
            HourlyWeatherData.timestamp < end,
            metric_col.isnot(None),
            city_filter,
        ]
        if pin.district:
            dist_orig = pin.district
            dist_fold = _tr_ascii_fold(dist_orig)
            loc_filter.append(
                or_(
                    HourlyWeatherData.district_name == dist_orig,
                    HourlyWeatherData.district_name == dist_fold,
                )
            )

        # 2026-05-19 Bug B — district None durumunda her timestamp için
        # ilçeler arası AVG (eski davranış: tüm ilçeler toplanıyor → 12×
        # yanlış sayım, 66700 kWh gibi imkânsız değerler). Doğrusu: il
        # geneli pin için her saat tek değer (ilçe ortalaması).
        if pin.district:
            # District match var: zaten unique timestamp döner
            rows = db.query(
                HourlyWeatherData.timestamp,
                metric_col.label("val"),
            ).filter(and_(*loc_filter)).all()
        else:
            # District yok: her saat için il-bazlı ortalama
            rows = db.query(
                HourlyWeatherData.timestamp,
                func.avg(metric_col).label("val"),
            ).filter(and_(*loc_filter)).group_by(
                HourlyWeatherData.timestamp
            ).all()

        if not rows:
            return 0.0, [], 0

        daily_kwh: dict[date, float] = {}
        total = 0.0
        for ts, val in rows:
            if val is None:
                continue
            if resource == "wind":
                kwh = _compute_wind_hourly_kwh(float(val), capacity)
            else:
                kwh = _compute_solar_hourly_kwh(float(val), capacity)
            total += kwh
            d = ts.date() if hasattr(ts, "date") else ts
            daily_kwh[d] = daily_kwh.get(d, 0.0) + kwh

        breakdown = [
            {"date": d.isoformat(), "kwh": round(v, 2)}
            for d, v in sorted(daily_kwh.items())
        ]
        return round(total, 2), breakdown, len(rows)


def _generation_hydro_physical(
    pin: Pin,
    start: datetime,
    end: datetime,
) -> tuple[float, list[dict], int]:
    """HES yıllık üretim — climatology monthly_river_discharge × pin.head × 8.5.

    Climatology hidro için hourly_typical_profile yok (sadece GES/RES için).
    HES için fiziksel formül kullanılır:
        P_kW = 8.5 × Q (m³/s) × H (m)    # η≈0.85 dahil
    Aylık debi (climatology.monthly_river_discharge[ay].mean) × pin'in
    head_height'ı + capacity_mw cap'i ile saatlik üretim.
    """
    if not pin.head_height:
        return 0.0, [], 0
    head = float(pin.head_height)
    cap_kw = float(pin.capacity_mw or 0) * 1000.0  # cap için

    # Climatology'de "hydro" resource_type satırı YOK (sadece wind+solar).
    # monthly_river_discharge wind/solar satırlarına yazılı — herhangi
    # birinden okumak yeterli. _get_climatology_for_pin resource filter
    # uyguladığı için HES'te None döner; özel sorgu yapıyoruz.
    from app.db.database import SystemSessionLocal
    from app.db.models import Climatology
    from app.services.province_aliases import province_aliases

    monthly = None
    if pin.city:
        try:
            with SystemSessionLocal() as sdb:
                variants = province_aliases(str(pin.city))
                q = sdb.query(Climatology.monthly_river_discharge).filter(
                    Climatology.province_name.in_(variants),
                    Climatology.district_name.is_(None),
                    Climatology.monthly_river_discharge.isnot(None),
                )
                row = q.first()
                if row:
                    monthly = row[0]
        except Exception:
            monthly = None
    if not monthly:
        return 0.0, [], 0
    daily_kwh: dict[date, float] = {}
    total = 0.0
    cur = start
    sample = 0
    EFFICIENCY = 8.5  # 9.81 × η_typical → kW = 8.5 × Q × H

    while cur < end:
        month_idx = cur.month - 1
        if month_idx < len(monthly) and monthly[month_idx]:
            m_data = monthly[month_idx]
            q_mean = float(m_data.get("mean", 0)) if isinstance(m_data, dict) else 0
            # Pin kullanıcı override → pin.flow_rate, yoksa climatology
            q = float(pin.flow_rate) if pin.flow_rate else q_mean
            if q > 0:
                power_kw = EFFICIENCY * q * head
                # Kurulu güç cap'i
                if cap_kw > 0:
                    power_kw = min(power_kw, cap_kw)
                # 1 saat × kW = kWh
                kwh = power_kw
                total += kwh
                d = cur.date()
                daily_kwh[d] = daily_kwh.get(d, 0.0) + kwh
                sample += 1
        cur += timedelta(hours=1)

    breakdown = [
        {"date": d.isoformat(), "kwh": round(v, 2)}
        for d, v in sorted(daily_kwh.items())
    ]
    return round(total, 2), breakdown, sample


def _generation_from_climatology(
    pin: Pin,
    start: datetime,
    end: datetime,
) -> tuple[float, list[dict], int]:
    """Climatology hourly_typical_profile × kapasite ile interpolation.

    Eski tarihler (saatlik veri 2 yıldan eski) için kullanılır.
    Tahmin doğruluğu ~%85 — kabul edilebilir.

    HES için hourly_typical_profile yok — fiziksel formül (debi × düşü) ile
    `_generation_hydro_physical`'e yönlendirilir.
    """
    resource = _TYPE_TO_RESOURCE.get(pin.type)
    capacity = float(pin.capacity_mw or 1.0)

    # HES özel branch — climatology hidro hourly_typical_profile değil,
    # monthly_river_discharge + pin.head_height kullanılır.
    if resource == "hydro":
        return _generation_hydro_physical(pin, start, end)

    climatology = _get_climatology_for_pin(pin)
    if not climatology or not climatology.hourly_typical_profile:
        return 0.0, [], 0

    profile = climatology.hourly_typical_profile  # {"1": {"0": v, ...}}
    daily_kwh: dict[date, float] = {}
    total = 0.0
    cur = start
    sample = 0
    while cur < end:
        month_key = str(cur.month)
        hour_key = str(cur.hour)
        val = (profile.get(month_key) or {}).get(hour_key)
        if val is not None:
            if resource == "wind":
                kwh = _compute_wind_hourly_kwh(float(val), capacity)
            else:
                kwh = _compute_solar_hourly_kwh(float(val), capacity)
            total += kwh
            d = cur.date()
            daily_kwh[d] = daily_kwh.get(d, 0.0) + kwh
            sample += 1
        cur += timedelta(hours=1)

    breakdown = [
        {"date": d.isoformat(), "kwh": round(v, 2)}
        for d, v in sorted(daily_kwh.items())
    ]
    return round(total, 2), breakdown, sample


def compute_pin_generation(
    pin: Pin,
    period: Period = "month",
    custom_start: Optional[datetime] = None,
    custom_end: Optional[datetime] = None,
) -> GenerationResult:
    """Ana fonksiyon — pin'in üretim geçmişini hesaplar.

    Saatlik veri varsa onu kullanır, eski tarihlere climatology interpolation
    uygular. installation_date öncesi tarih varsa start = installation_date
    ile clamp edilir.
    """
    # installation_date veya created_at fallback
    install = pin.installation_date or pin.created_at
    if install is None:
        install = datetime(2024, 1, 1)
    # Naive datetime'a çevir (DB UTC, timezone-aware/naive karışmasın)
    if install.tzinfo is not None:
        install = install.replace(tzinfo=None)

    start, end = _resolve_period(period, custom_start, custom_end)
    if period == "total":
        start = install
    # installation_date öncesini hesaba katma
    if start < install:
        start = install

    if start >= end:
        return GenerationResult(
            pin_id=int(pin.id),
            period=period,
            start_date=start,
            end_date=end,
            total_kwh=0.0,
            daily_breakdown=[],
            data_source="empty_range",
            pin_meta={"installation_date": install.isoformat()},
        )

    # Saatlik veri ne kadar eski olabilir? hourly_weather_data son 2 yıl.
    two_years_ago = datetime.utcnow() - timedelta(days=730)
    has_old_part = start < two_years_ago
    has_new_part = end > two_years_ago

    total_kwh = 0.0
    breakdown: list[dict] = []
    samples = 0
    source = "unknown"

    if has_new_part:
        new_start = max(start, two_years_ago)
        new_end = end
        kwh_new, bd_new, n_new = _generation_from_hourly_actual(pin, new_start, new_end)
        # 2026-05-19 — Eğer hourly_actual veri bulamadıysa (city/district
        # eşleşmedi veya hourly_weather_data eksik) climatology fallback'e
        # geç. Önceki davranış: total_kwh=0 dönüyordu — bug.
        if n_new == 0:
            kwh_new, bd_new, n_new = _generation_from_climatology(
                pin, new_start, new_end,
            )
            if n_new > 0:
                source = "climatology_interpolated"
            else:
                source = "no_data"
        else:
            source = "hourly_actual"
        total_kwh += kwh_new
        breakdown.extend(bd_new)
        samples += n_new

    if has_old_part:
        old_start = start
        old_end = min(end, two_years_ago)
        kwh_old, bd_old, n_old = _generation_from_climatology(pin, old_start, old_end)
        total_kwh += kwh_old
        breakdown.extend(bd_old)
        samples += n_old
        if has_new_part and source == "hourly_actual" and n_old > 0:
            source = "hybrid"
        elif not has_new_part and n_old > 0:
            source = "climatology_interpolated"

    breakdown.sort(key=lambda x: x["date"])

    # Önceki periyot karşılaştırması (sadece today/week/month/year için)
    comparison_prev_kwh = None
    comparison_pct = None
    if period in ("today", "week", "month", "year"):
        delta = end - start
        prev_end = start
        prev_start = prev_end - delta
        if prev_start >= install:
            try:
                if prev_start >= two_years_ago:
                    prev_kwh, _, _ = _generation_from_hourly_actual(pin, prev_start, prev_end)
                else:
                    prev_kwh, _, _ = _generation_from_climatology(pin, prev_start, prev_end)
                comparison_prev_kwh = prev_kwh
                if prev_kwh > 0:
                    comparison_pct = round((total_kwh - prev_kwh) / prev_kwh * 100, 1)
            except Exception as e:
                logger.warning("[pin_gen] prev period error: %s", e)

    return GenerationResult(
        pin_id=int(pin.id),
        period=period,
        start_date=start,
        end_date=end,
        total_kwh=round(total_kwh, 2),
        daily_breakdown=breakdown,
        comparison_prev_period_kwh=comparison_prev_kwh,
        comparison_pct_change=comparison_pct,
        data_source=source,
        pin_meta={
            "installation_date": install.isoformat(),
            "capacity_mw": float(pin.capacity_mw or 0),
            "type": pin.type,
            "city": pin.city,
            "district": pin.district,
            "sample_count": samples,
        },
    )


def generation_to_dict(result: GenerationResult) -> dict:
    """Endpoint response için JSON-friendly dict."""
    return {
        "pin_id": result.pin_id,
        "period": result.period,
        "start_date": result.start_date.isoformat(),
        "end_date": result.end_date.isoformat(),
        "total_kwh": result.total_kwh,
        "daily_breakdown": result.daily_breakdown,
        "comparison_prev_period_kwh": result.comparison_prev_period_kwh,
        "comparison_pct_change": result.comparison_pct_change,
        "data_source": result.data_source,
        "pin": result.pin_meta,
    }

"""
SRRP — Finansal Hesap Servisi (Aşama 3.A)
=========================================

Senaryo bazlı yatırım metrikleri:
  * **CAPEX**           — toplam yatırım (USD)
  * **OPEX yıllık**     — yıllık işletme gideri (USD/yıl)
  * **Yıllık üretim**   — kWh/yıl (capacity_factor × kapasite × 8760)
  * **Yıllık gelir**    — üretim × elektrik fiyatı (USD/yıl)
  * **LCOE**            — Levelized Cost of Energy (USD/kWh)
  * **Payback period**  — geri ödeme süresi (yıl)
  * **NPV**             — Net Bugünkü Değer (USD)
  * **IRR**             — İç Verim Oranı (%)
  * **CO₂ avoidance**   — yıllık emisyon önleme (ton/yıl)

Saf fonksiyonlar — DB veya HTTP yan-etkisi yok. Endpoint
(`/scenarios/{id}/financials`) bunları çağırıp pin listesinden
agregate eder.

NPV/IRR formülleri kütüphane bağımlılığı olmadan manuel:
  NPV = Σ CF_t / (1+r)^t
  IRR = NPV(r*)=0 olan r* (Newton-Raphson)
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from app.core.finance_constants import (
    DEFAULT_CAPEX_PER_MW,
    DEFAULT_OPEX_PCT_YEARLY,
    DEFAULT_LIFETIME_YEARS,
    DEFAULT_CAPACITY_FACTOR_FALLBACK,
    DEFAULT_ELECTRICITY_PRICE_USD_PER_KWH,
    DEFAULT_DISCOUNT_RATE,
    DEFAULT_CO2_INTENSITY_G_PER_KWH,
    USD_TO_TRY,
)


@dataclass(frozen=True)
class FinanceAssumptions:
    """Hesap parametreleri — admin Settings'ten override eder.

    DB'deki ``FinanceAssumptions`` tablosu okunup bu sınıfa map edilir;
    yoksa ``finance_constants.py`` default'ları kullanılır.
    """
    capex_per_mw: dict[str, float] = field(default_factory=lambda: dict(DEFAULT_CAPEX_PER_MW))
    opex_pct_yearly: dict[str, float] = field(default_factory=lambda: dict(DEFAULT_OPEX_PCT_YEARLY))
    lifetime_years: dict[str, int] = field(default_factory=lambda: dict(DEFAULT_LIFETIME_YEARS))
    capacity_factor_fallback: dict[str, float] = field(default_factory=lambda: dict(DEFAULT_CAPACITY_FACTOR_FALLBACK))
    electricity_price_usd_per_kwh: float = DEFAULT_ELECTRICITY_PRICE_USD_PER_KWH
    discount_rate: float = DEFAULT_DISCOUNT_RATE
    co2_intensity_g_per_kwh: float = DEFAULT_CO2_INTENSITY_G_PER_KWH
    usd_to_try: float = USD_TO_TRY


@dataclass(frozen=True)
class PinFinanceInput:
    """Tek pin için finansal input — endpoint pin listesini buna çevirir."""
    pin_id: int
    pin_type: str          # "Güneş Paneli" | "Rüzgar Türbini" | "Hidroelektrik"
    capacity_mw: float
    capacity_factor: Optional[float] = None  # 0-1; None ise fallback


@dataclass(frozen=True)
class FinancialMetrics:
    """Senaryo finansal projeksiyon sonucu."""
    # Toplamlar (USD)
    capex_total: float
    opex_yearly: float
    annual_revenue: float
    annual_production_kwh: float
    annual_co2_avoided_tons: float

    # Performans
    lcoe_usd_per_kwh: float
    payback_period_years: float       # ∞ ise -1.0 (üretim < OPEX)
    npv_usd: float
    irr_pct: Optional[float]          # convergence olmadıysa None
    project_lifetime_years: int

    # 25 yıllık nakit akışı (UI grafik için)
    yearly_cashflows: list[float]     # cashflows[0] = -CAPEX, [1..N] = net revenue
    cumulative_cashflows: list[float]

    # Pin bazlı detaylar
    per_pin: list[dict]               # {pin_id, type, capex, annual_kwh, lcoe}

    # Varsayım snapshot (kullanıcı denetim için)
    assumptions_used: dict


# ── Hesap Fonksiyonları ─────────────────────────────────────────────────────

def _capex_for_pin(pin: PinFinanceInput, a: FinanceAssumptions) -> float:
    """Tek pin'in CAPEX'i (USD) = capacity_mw × $/MW."""
    rate = a.capex_per_mw.get(pin.pin_type, 1_000_000.0)
    return pin.capacity_mw * rate


def _annual_kwh_for_pin(pin: PinFinanceInput, a: FinanceAssumptions) -> float:
    """Yıllık üretim (kWh) = capacity_mw × cap_factor × 8760 × 1000."""
    cf = pin.capacity_factor or a.capacity_factor_fallback.get(pin.pin_type, 0.25)
    cf = max(0.0, min(1.0, cf))
    return pin.capacity_mw * cf * 8760.0 * 1000.0


def _opex_for_pin(pin: PinFinanceInput, a: FinanceAssumptions) -> float:
    """Tek pin'in yıllık OPEX'i (USD)."""
    capex = _capex_for_pin(pin, a)
    pct = a.opex_pct_yearly.get(pin.pin_type, 0.020)
    return capex * pct


def _lifetime_for_scenario(pins: list[PinFinanceInput], a: FinanceAssumptions) -> int:
    """Senaryo proje ömrü = pin'lerin minimum ömrü (en kısa zayıf halka)."""
    if not pins:
        return 25
    lifetimes = [a.lifetime_years.get(p.pin_type, 25) for p in pins]
    return min(lifetimes) if lifetimes else 25


def compute_lcoe(
    capex: float,
    opex_yearly: float,
    annual_kwh: float,
    lifetime_years: int,
    discount_rate: float,
) -> float:
    """LCOE — Levelized Cost of Energy (USD/kWh).

    LCOE = (CAPEX + Σ OPEX_t / (1+r)^t) / Σ kWh_t / (1+r)^t

    Üretim ve OPEX yıllar arası sabit varsayılır (lineer model).
    """
    if annual_kwh <= 0 or lifetime_years <= 0:
        return 0.0
    # Annuity factor: PV(1) for n years at rate r
    if discount_rate == 0:
        af = float(lifetime_years)
    else:
        af = (1 - (1 + discount_rate) ** -lifetime_years) / discount_rate
    npv_costs = capex + opex_yearly * af
    npv_kwh = annual_kwh * af
    return npv_costs / npv_kwh if npv_kwh > 0 else 0.0


def compute_payback(capex: float, annual_net_revenue: float) -> float:
    """Basit payback (iskontosuz): CAPEX / yıllık net gelir.

    Net gelir ≤ 0 ise -1.0 döner (geri ödenmez işaretçi).
    """
    if annual_net_revenue <= 0:
        return -1.0
    return capex / annual_net_revenue


def compute_npv(
    capex: float,
    annual_net_revenue: float,
    lifetime_years: int,
    discount_rate: float,
) -> float:
    """NPV = -CAPEX + Σ_t=1..N net_revenue / (1+r)^t."""
    if discount_rate == 0:
        pv_revenues = annual_net_revenue * lifetime_years
    else:
        af = (1 - (1 + discount_rate) ** -lifetime_years) / discount_rate
        pv_revenues = annual_net_revenue * af
    return -capex + pv_revenues


def compute_irr(cashflows: list[float], max_iter: int = 100, tol: float = 1e-6) -> Optional[float]:
    """IRR — Newton-Raphson ile (`numpy-financial` bağımlılığı yok).

    cashflows[0] negatif (yatırım), kalanlar pozitif/negatif net akış.
    Convergence olmazsa None döner.
    """
    if not cashflows or len(cashflows) < 2:
        return None
    # En az bir negatif + bir pozitif olmadan IRR tanımsız
    if not any(c < 0 for c in cashflows) or not any(c > 0 for c in cashflows):
        return None

    def npv_at(r: float) -> float:
        return sum(cf / ((1 + r) ** t) for t, cf in enumerate(cashflows))

    def dnpv_at(r: float) -> float:
        return sum(-t * cf / ((1 + r) ** (t + 1)) for t, cf in enumerate(cashflows))

    # Başlangıç tahmini: 0.10 (%10)
    r = 0.10
    for _ in range(max_iter):
        v = npv_at(r)
        if abs(v) < tol:
            return r
        d = dnpv_at(r)
        if d == 0:
            return None
        r_new = r - v / d
        if r_new <= -0.99:  # ürkütücü uçurum, durduralım
            r_new = -0.99
        if abs(r_new - r) < tol:
            return r_new
        r = r_new
    return None


def compute_co2_avoided_tons(annual_kwh: float, intensity_g_per_kwh: float) -> float:
    """Yıllık önlenen CO₂ (ton) = kWh × g/kWh / 1e6."""
    return annual_kwh * intensity_g_per_kwh / 1_000_000.0


# ── Ana entry point ─────────────────────────────────────────────────────────

def compute_scenario_financials(
    pins: list[PinFinanceInput],
    assumptions: Optional[FinanceAssumptions] = None,
) -> FinancialMetrics:
    """Senaryo için tüm finansal metrikleri hesapla.

    Pin listesi boş olabilir — boş senaryoda tüm metrikler 0/None döner
    (UI "veri yok" gösterir).
    """
    a = assumptions or FinanceAssumptions()

    if not pins:
        return FinancialMetrics(
            capex_total=0.0,
            opex_yearly=0.0,
            annual_revenue=0.0,
            annual_production_kwh=0.0,
            annual_co2_avoided_tons=0.0,
            lcoe_usd_per_kwh=0.0,
            payback_period_years=-1.0,
            npv_usd=0.0,
            irr_pct=None,
            project_lifetime_years=0,
            yearly_cashflows=[],
            cumulative_cashflows=[],
            per_pin=[],
            assumptions_used=_assumptions_to_dict(a),
        )

    # Pin bazlı detaylar + toplamlar
    capex_total = 0.0
    opex_yearly = 0.0
    annual_kwh = 0.0
    per_pin: list[dict] = []

    for p in pins:
        pin_capex = _capex_for_pin(p, a)
        pin_opex = _opex_for_pin(p, a)
        pin_kwh = _annual_kwh_for_pin(p, a)
        capex_total += pin_capex
        opex_yearly += pin_opex
        annual_kwh += pin_kwh

        # Pin bazlı LCOE (yıl bazında bireysel kontrol için)
        pin_lifetime = a.lifetime_years.get(p.pin_type, 25)
        pin_lcoe = compute_lcoe(pin_capex, pin_opex, pin_kwh, pin_lifetime, a.discount_rate)
        per_pin.append({
            "pin_id": p.pin_id,
            "type": p.pin_type,
            "capacity_mw": p.capacity_mw,
            "capacity_factor": p.capacity_factor or a.capacity_factor_fallback.get(p.pin_type),
            "capex_usd": round(pin_capex, 2),
            "opex_usd_yearly": round(pin_opex, 2),
            "annual_kwh": round(pin_kwh, 2),
            "lcoe_usd_per_kwh": round(pin_lcoe, 5),
        })

    annual_revenue = annual_kwh * a.electricity_price_usd_per_kwh
    annual_net_revenue = annual_revenue - opex_yearly
    annual_co2 = compute_co2_avoided_tons(annual_kwh, a.co2_intensity_g_per_kwh)

    lifetime = _lifetime_for_scenario(pins, a)
    lcoe = compute_lcoe(capex_total, opex_yearly, annual_kwh, lifetime, a.discount_rate)
    payback = compute_payback(capex_total, annual_net_revenue)
    npv = compute_npv(capex_total, annual_net_revenue, lifetime, a.discount_rate)

    # Cashflow vektörü: t=0 -CAPEX, t=1..N net revenue (sabit)
    cashflows = [-capex_total] + [annual_net_revenue] * lifetime
    irr = compute_irr(cashflows)

    cumulative = []
    running = 0.0
    for cf in cashflows:
        running += cf
        cumulative.append(round(running, 2))

    return FinancialMetrics(
        capex_total=round(capex_total, 2),
        opex_yearly=round(opex_yearly, 2),
        annual_revenue=round(annual_revenue, 2),
        annual_production_kwh=round(annual_kwh, 2),
        annual_co2_avoided_tons=round(annual_co2, 3),
        lcoe_usd_per_kwh=round(lcoe, 5),
        payback_period_years=round(payback, 2) if payback >= 0 else -1.0,
        npv_usd=round(npv, 2),
        irr_pct=round(irr * 100, 3) if irr is not None else None,
        project_lifetime_years=lifetime,
        yearly_cashflows=[round(cf, 2) for cf in cashflows],
        cumulative_cashflows=cumulative,
        per_pin=per_pin,
        assumptions_used=_assumptions_to_dict(a),
    )


def _assumptions_to_dict(a: FinanceAssumptions) -> dict:
    """Audit trail için varsayım snapshot'ı."""
    return {
        "capex_per_mw": a.capex_per_mw,
        "opex_pct_yearly": a.opex_pct_yearly,
        "lifetime_years": a.lifetime_years,
        "capacity_factor_fallback": a.capacity_factor_fallback,
        "electricity_price_usd_per_kwh": a.electricity_price_usd_per_kwh,
        "discount_rate": a.discount_rate,
        "co2_intensity_g_per_kwh": a.co2_intensity_g_per_kwh,
        "usd_to_try": a.usd_to_try,
    }

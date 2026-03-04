from typing import Dict, Any

# Varsayılan Finansal/Operasyonel Parametreler
# type: (capex_per_kw, opex_pct, lifetime_years, degradation_pct)
RESOURCE_PARAMS = {
    "Güneş Paneli": {"capex": 800.0, "opex": 0.015, "lifetime": 25, "degradation": 0.005},
    "Rüzgar Türbini": {"capex": 1200.0, "opex": 0.020, "lifetime": 20, "degradation": 0.002},
    "Hidroelektrik": {"capex": 2500.0, "opex": 0.025, "lifetime": 40, "degradation": 0.001},
}

# Çevresel ve Ekonomik Sabitler
DISCOUNT_RATE = 0.08  # İskonto oranı (%8)
ELECTRICITY_PRICE_USD = 0.12  # Şebeke satış / tasarruf fiyatı ($/kWh)
GRID_EMISSION_FACTOR = 0.45  # kg CO2 / kWh (Türkiye şebeke ortalaması)
CARBON_PRICE_USD = 15.0  # 1 Ton CO2 fiyatı ($)


def calculate_advanced_financials(annual_kwh: float, capacity_kw: float, resource_type: str) -> Dict[str, Any]:
    """
    Kapasite ve üretime dayalı LCOE ve Karbon Kredisi dahil gelişmiş finansal analiz yapar.
    """
    params = RESOURCE_PARAMS.get(resource_type, RESOURCE_PARAMS["Güneş Paneli"])
    
    # Özel durum: HES için eğer capacity çok düşük gelirse minimum maliyet tabanı belirle
    initial_cost = params["capex"] * capacity_kw
    if resource_type == "Hidroelektrik" and initial_cost < 5000:
        initial_cost = max(5000.0, annual_kwh * 0.01)

    opex_annual = initial_cost * params["opex"]
    lifetime = params["lifetime"]
    degradation = params["degradation"]

    # 1. LCOE Hesabı (Levelized Cost of Energy)
    # LCOE = Toplam İndirgenmiş Maliyetler / Toplam İndirgenmiş Üretim
    total_discounted_cost = initial_cost
    total_discounted_production = 0.0

    for year in range(1, lifetime + 1):
        # Maliyetin bugünkü değeri
        discounted_opex = opex_annual / ((1 + DISCOUNT_RATE) ** year)
        total_discounted_cost += discounted_opex
        
        # Üretimin bugünkü değeri (Degradasyon düşülerek)
        production_year = annual_kwh * ((1 - degradation) ** (year - 1))
        discounted_production = production_year / ((1 + DISCOUNT_RATE) ** year)
        total_discounted_production += discounted_production

    lcoe = total_discounted_cost / total_discounted_production if total_discounted_production > 0 else 0.0

    # 2. Standart Finansal Metrikler
    first_year_earning = annual_kwh * ELECTRICITY_PRICE_USD
    payback_years = initial_cost / first_year_earning if first_year_earning > 0 else 99.0
    roi = (first_year_earning / initial_cost) * 100 if initial_cost > 0 else 0.0
    
    # 3. Çevresel Etki (Karbon Kredisi)
    # 1 kWh = 0.45 kg CO2 tasarrufu. Ton için 1000'e bölüyoruz.
    carbon_savings_tons = (annual_kwh * GRID_EMISSION_FACTOR) / 1000.0
    carbon_income = carbon_savings_tons * CARBON_PRICE_USD

    return {
        "initial_investment_usd": round(initial_cost, 2),
        "annual_earnings_usd": round(first_year_earning, 2),
        "payback_period_years": round(payback_years, 1),
        "roi_percentage": round(roi, 1),
        "lcoe_usd_kwh": round(lcoe, 4),
        "carbon_savings_tons_annual": round(carbon_savings_tons, 2),
        "carbon_credit_income_usd_annual": round(carbon_income, 2)
    }

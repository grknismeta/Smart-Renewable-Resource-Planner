/// Finansal projeksiyon metrikleri (Aşama 3.A).
///
/// Backend ``GET /scenarios/{id}/financials`` yanıtının Dart karşılığı.
/// Tüm para birimi USD; UI tarafında `usdToTry` (assumptions_used) ile çevrilir.
class FinancialMetrics {
  final int scenarioId;
  final String scenarioName;

  // Toplamlar (USD)
  final double capexTotal;
  final double opexYearly;
  final double annualRevenue;
  final double annualProductionKwh;
  final double annualCo2AvoidedTons;

  // Performans
  final double lcoeUsdPerKwh;
  /// `-1.0` ise geri ödenmez (üretim < OPEX). UI bunu özel işaretle göster.
  final double paybackPeriodYears;
  final double npvUsd;
  /// Convergence olmadıysa `null`.
  final double? irrPct;
  final int projectLifetimeYears;

  // Nakit akışı (UI grafik için)
  final List<double> yearlyCashflows;        // [0]=-CAPEX, [1..N]=net revenue
  final List<double> cumulativeCashflows;

  // Pin bazlı detaylar (audit + tablo)
  final List<PinFinanceDetail> perPin;

  // Varsayım snapshot (denetim için)
  final FinanceAssumptionsUsed assumptionsUsed;

  const FinancialMetrics({
    required this.scenarioId,
    required this.scenarioName,
    required this.capexTotal,
    required this.opexYearly,
    required this.annualRevenue,
    required this.annualProductionKwh,
    required this.annualCo2AvoidedTons,
    required this.lcoeUsdPerKwh,
    required this.paybackPeriodYears,
    required this.npvUsd,
    required this.irrPct,
    required this.projectLifetimeYears,
    required this.yearlyCashflows,
    required this.cumulativeCashflows,
    required this.perPin,
    required this.assumptionsUsed,
  });

  factory FinancialMetrics.fromJson(Map<String, dynamic> json) {
    return FinancialMetrics(
      scenarioId: (json['scenario_id'] as num).toInt(),
      scenarioName: json['scenario_name'] as String? ?? '',
      capexTotal: (json['capex_total'] as num?)?.toDouble() ?? 0.0,
      opexYearly: (json['opex_yearly'] as num?)?.toDouble() ?? 0.0,
      annualRevenue: (json['annual_revenue'] as num?)?.toDouble() ?? 0.0,
      annualProductionKwh: (json['annual_production_kwh'] as num?)?.toDouble() ?? 0.0,
      annualCo2AvoidedTons: (json['annual_co2_avoided_tons'] as num?)?.toDouble() ?? 0.0,
      lcoeUsdPerKwh: (json['lcoe_usd_per_kwh'] as num?)?.toDouble() ?? 0.0,
      paybackPeriodYears: (json['payback_period_years'] as num?)?.toDouble() ?? -1.0,
      npvUsd: (json['npv_usd'] as num?)?.toDouble() ?? 0.0,
      irrPct: (json['irr_pct'] as num?)?.toDouble(),
      projectLifetimeYears: (json['project_lifetime_years'] as num?)?.toInt() ?? 0,
      yearlyCashflows: (json['yearly_cashflows'] as List? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      cumulativeCashflows: (json['cumulative_cashflows'] as List? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      perPin: (json['per_pin'] as List? ?? const [])
          .map((e) => PinFinanceDetail.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      assumptionsUsed: FinanceAssumptionsUsed.fromJson(
        Map<String, dynamic>.from(json['assumptions_used'] ?? const {}),
      ),
    );
  }

  /// Geri ödenmez senaryolar için kullanım kolaylığı.
  bool get isPaybackInfinite => paybackPeriodYears < 0;
}

/// Pin başına finansal detay — UI'da expandable tablo gösterimi için.
class PinFinanceDetail {
  final int pinId;
  final String type;
  final double capacityMw;
  final double? capacityFactor;
  final double capexUsd;
  final double opexUsdYearly;
  final double annualKwh;
  final double lcoeUsdPerKwh;

  const PinFinanceDetail({
    required this.pinId,
    required this.type,
    required this.capacityMw,
    required this.capacityFactor,
    required this.capexUsd,
    required this.opexUsdYearly,
    required this.annualKwh,
    required this.lcoeUsdPerKwh,
  });

  factory PinFinanceDetail.fromJson(Map<String, dynamic> json) {
    return PinFinanceDetail(
      pinId: (json['pin_id'] as num).toInt(),
      type: json['type'] as String? ?? '',
      capacityMw: (json['capacity_mw'] as num?)?.toDouble() ?? 0.0,
      capacityFactor: (json['capacity_factor'] as num?)?.toDouble(),
      capexUsd: (json['capex_usd'] as num?)?.toDouble() ?? 0.0,
      opexUsdYearly: (json['opex_usd_yearly'] as num?)?.toDouble() ?? 0.0,
      annualKwh: (json['annual_kwh'] as num?)?.toDouble() ?? 0.0,
      lcoeUsdPerKwh: (json['lcoe_usd_per_kwh'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Hesapta kullanılan varsayımlar (audit trail).
class FinanceAssumptionsUsed {
  final Map<String, double> capexPerMw;
  final Map<String, double> opexPctYearly;
  final Map<String, int> lifetimeYears;
  final Map<String, double> capacityFactorFallback;
  final double electricityPriceUsdPerKwh;
  final double discountRate;
  final double co2IntensityGPerKwh;
  final double usdToTry;

  const FinanceAssumptionsUsed({
    required this.capexPerMw,
    required this.opexPctYearly,
    required this.lifetimeYears,
    required this.capacityFactorFallback,
    required this.electricityPriceUsdPerKwh,
    required this.discountRate,
    required this.co2IntensityGPerKwh,
    required this.usdToTry,
  });

  factory FinanceAssumptionsUsed.fromJson(Map<String, dynamic> json) {
    Map<String, double> doubleMap(dynamic v) {
      if (v is! Map) return const {};
      return v.map((k, val) => MapEntry(k.toString(), (val as num).toDouble()));
    }

    Map<String, int> intMap(dynamic v) {
      if (v is! Map) return const {};
      return v.map((k, val) => MapEntry(k.toString(), (val as num).toInt()));
    }

    return FinanceAssumptionsUsed(
      capexPerMw: doubleMap(json['capex_per_mw']),
      opexPctYearly: doubleMap(json['opex_pct_yearly']),
      lifetimeYears: intMap(json['lifetime_years']),
      capacityFactorFallback: doubleMap(json['capacity_factor_fallback']),
      electricityPriceUsdPerKwh:
          (json['electricity_price_usd_per_kwh'] as num?)?.toDouble() ?? 0.085,
      discountRate: (json['discount_rate'] as num?)?.toDouble() ?? 0.08,
      co2IntensityGPerKwh: (json['co2_intensity_g_per_kwh'] as num?)?.toDouble() ?? 480.0,
      usdToTry: (json['usd_to_try'] as num?)?.toDouble() ?? 33.0,
    );
  }
}

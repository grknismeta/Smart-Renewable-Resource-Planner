// lib/data/models/pin_model.dart

// --- 1. ANA PIN MODELİ (GÜNCELLENDİ) ---
// Bu sınıfın, backend'deki PinBase ve PinResponse'a uyması gerekir.
class Pin {
  final int id;
  final double latitude;
  final double longitude;
  final String name;
  final String type;
  final double capacityMw;
  final int ownerId;

  // Güneş potansiyeli (GET /pins/ listesinden gelir)
  final double? avgSolarIrradiance;

  // Opsiyonel alanlar (Hesaplama veya Pin ekleme için)
  final double? panelArea;
  final double? panelTilt;
  final double? panelAzimuth;
  final int? turbineModelId;
  final int? panelModelId;
  final int? equipmentId;
  final String? equipmentName;
  final PinCalculationResponse? analysis;

  // HES (Hidroelektrik) spesifik alanlar
  final double? flowRate;       // Debi (m³/s)
  final double? headHeight;     // Düşü yüksekliği (m)
  final double? basinAreaKm2;   // Havza alanı (km²)

  Pin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.type,
    required this.capacityMw,
    required this.ownerId,
    this.avgSolarIrradiance,
    this.panelArea,
    this.panelTilt,
    this.panelAzimuth,
    this.turbineModelId,
    this.panelModelId,
    this.equipmentId,
    this.equipmentName,
    this.analysis,
    this.flowRate,
    this.headHeight,
    this.basinAreaKm2,
  });

  // Backend'e (PUT /pins/{id}) göndermek için — backend PinBase schema ile eşleşir
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'title': name,          // backend PinBase.title kullanır, 'name' değil!
      'type': type,
      'capacity_mw': capacityMw,
      'panel_area': panelArea,
      if (equipmentId != null) 'equipment_id': equipmentId,
      // HES alanları — null ise gönderilmez
      if (flowRate != null) 'flow_rate': flowRate,
      if (headHeight != null) 'head_height': headHeight,
      if (basinAreaKm2 != null) 'basin_area_km2': basinAreaKm2,
    };
  }

  // Backend'den (GET /pins/) gelen veriyi okumak için
  factory Pin.fromJson(Map<String, dynamic> json) {
    return Pin(
      id: json['id'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      name:
          (json['name'] ?? json['title'] ?? 'Yeni Kaynak')
              as String, // 'name' or 'title' with fallback
      type: json['type'] as String,
      capacityMw: (json['capacity_mw'] as num).toDouble(),
      ownerId: json['owner_id'] as int,
      avgSolarIrradiance: (json['avg_solar_irradiance'] as num?)?.toDouble(),
      panelArea: (json['panel_area'] as num?)?.toDouble(),
      panelTilt: (json['panel_tilt'] as num?)?.toDouble(),
      panelAzimuth: (json['panel_azimuth'] as num?)?.toDouble(),
      turbineModelId: json['turbine_model_id'] as int?,
      panelModelId: json['panel_model_id'] as int?,
      equipmentId: json['equipment_id'] as int?,
      equipmentName: json['equipment_name'] as String?,
      analysis: json['analysis'] != null
          ? PinCalculationResponse.fromJson(json['analysis'])
          : null,
      // HES alanları
      flowRate: (json['flow_rate'] as num?)?.toDouble(),
      headHeight: (json['head_height'] as num?)?.toDouble(),
      basinAreaKm2: (json['basin_area_km2'] as num?)?.toDouble(),
    );
  }
}

// --- FINANSAL MODEL ---
// Backend schemas.py FinancialAnalysis ile eşleştirilmiş.
// Türkiye 2024-2025 YEKDEM/Piyasa değerleriyle NPV, LCOE, IRR destekli.
class FinancialAnalysis {
  final double initialInvestmentUsd;    // Toplam kurulum maliyeti ($)
  final double annualEarningsUsd;       // İlk yıl net kazanç (O&M düşülmüş, $)
  final double paybackPeriodYears;      // Geri ödeme süresi (yıl)
  final double roiPercentage;           // Basit ROI (%)
  // Gelişmiş metrikler
  final double lcoeUsdKwh;             // Normalleştirilmiş Enerji Maliyeti ($/kWh)
  final double npvUsd;                  // Net Bugünkü Değer — %8 iskonto ($)
  final double irrPercentage;           // İç Verim Oranı (%)
  final double lifetimeRevenueUsd;      // Ömür boyu brüt gelir ($)
  final String pricingMode;             // "yekdem" | "market"
  final double pricePerKwhUsd;          // İlk yıl birim fiyat ($/kWh)
  final int lifetimeYears;              // Sistem ömrü (yıl)

  FinancialAnalysis({
    required this.initialInvestmentUsd,
    required this.annualEarningsUsd,
    required this.paybackPeriodYears,
    required this.roiPercentage,
    this.lcoeUsdKwh = 0.0,
    this.npvUsd = 0.0,
    this.irrPercentage = 0.0,
    this.lifetimeRevenueUsd = 0.0,
    this.pricingMode = 'yekdem',
    this.pricePerKwhUsd = 0.07,
    this.lifetimeYears = 25,
  });

  factory FinancialAnalysis.fromJson(Map<String, dynamic> json) {
    return FinancialAnalysis(
      initialInvestmentUsd: (json['initial_investment_usd'] as num?)?.toDouble() ?? 0.0,
      annualEarningsUsd:    (json['annual_earnings_usd']    as num?)?.toDouble() ?? 0.0,
      paybackPeriodYears:   (json['payback_period_years']   as num?)?.toDouble() ?? 0.0,
      roiPercentage:        (json['roi_percentage']          as num?)?.toDouble() ?? 0.0,
      lcoeUsdKwh:           (json['lcoe_usd_kwh']           as num?)?.toDouble() ?? 0.0,
      npvUsd:               (json['npv_usd']                as num?)?.toDouble() ?? 0.0,
      irrPercentage:        (json['irr_percentage']          as num?)?.toDouble() ?? 0.0,
      lifetimeRevenueUsd:   (json['lifetime_revenue_usd']   as num?)?.toDouble() ?? 0.0,
      pricingMode:          (json['pricing_mode']            as String?) ?? 'yekdem',
      pricePerKwhUsd:       (json['price_per_kwh_usd']      as num?)?.toDouble() ?? 0.07,
      lifetimeYears:        (json['lifetime_years']          as num?)?.toInt()    ?? 25,
    );
  }
}

// --- 2. HESAPLAMA MODELLERİ ---

class SolarCalculationResponse {
  final double solarIrradianceKwM2;
  final double temperatureCelsius;
  final double panelEfficiency;
  final double powerOutputKw;
  final String panelModel;
  final double potentialKwhAnnual;
  final double performanceRatio;
  final Map<String, double>? monthlyProduction;
  final FinancialAnalysis? financials;

  SolarCalculationResponse({
    required this.solarIrradianceKwM2,
    required this.temperatureCelsius,
    required this.panelEfficiency,
    required this.powerOutputKw,
    required this.panelModel,
    required this.potentialKwhAnnual,
    required this.performanceRatio,
    this.monthlyProduction,
    this.financials,
  });

  // Haftalık üretim (yıllık / 52)
  double get potentialKwhWeekly => potentialKwhAnnual / 52;

  // Aylık ortalama üretim (yıllık / 12)
  double get potentialKwhMonthly => potentialKwhAnnual / 12;

  factory SolarCalculationResponse.fromJson(Map<String, dynamic> json) {
    return SolarCalculationResponse(
      solarIrradianceKwM2: (json['solar_irradiance_kw_m2'] as num).toDouble(),
      temperatureCelsius: (json['temperature_celsius'] as num).toDouble(),
      panelEfficiency: (json['panel_efficiency'] as num).toDouble(),
      powerOutputKw: (json['power_output_kw'] as num).toDouble(),
      panelModel: json['panel_model'] as String,
      potentialKwhAnnual: (json['potential_kwh_annual'] as num).toDouble(),
      performanceRatio: (json['performance_ratio'] as num).toDouble(),
      monthlyProduction: json['monthly_production'] != null
          ? Map<String, double>.from(
              (json['monthly_production'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      financials: json['financials'] != null
          ? FinancialAnalysis.fromJson(json['financials'] as Map<String, dynamic>)
          : null,
    );
  }
}

class WindCalculationResponse {
  final double windSpeedMS;
  final double powerOutputKw;
  final String turbineModel;
  final double potentialKwhAnnual;
  final double capacityFactor;
  final Map<String, double>? monthlyProduction;
  final FinancialAnalysis? financials;

  WindCalculationResponse({
    required this.windSpeedMS,
    required this.powerOutputKw,
    required this.turbineModel,
    required this.potentialKwhAnnual,
    required this.capacityFactor,
    this.monthlyProduction,
    this.financials,
  });

  // Haftalık üretim (yıllık / 52)
  double get potentialKwhWeekly => potentialKwhAnnual / 52;

  // Aylık ortalama üretim (yıllık / 12)
  double get potentialKwhMonthly => potentialKwhAnnual / 12;

  factory WindCalculationResponse.fromJson(Map<String, dynamic> json) {
    return WindCalculationResponse(
      windSpeedMS: (json['wind_speed_m_s'] as num).toDouble(),
      powerOutputKw: (json['power_output_kw'] as num).toDouble(),
      turbineModel: json['turbine_model'] as String,
      potentialKwhAnnual: (json['potential_kwh_annual'] as num).toDouble(),
      capacityFactor: (json['capacity_factor'] as num).toDouble(),
      monthlyProduction: json['monthly_production'] != null
          ? Map<String, double>.from(
              (json['monthly_production'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      financials: json['financials'] != null
          ? FinancialAnalysis.fromJson(json['financials'] as Map<String, dynamic>)
          : null,
    );
  }
}

// --- 3. HYDRO HESAPLAMA MODİ

class HydroCalculationResponse {
  final double predictedAnnualProductionKwh;
  final double ratedPowerKw;
  final double avgFlowRateM3s;
  final double? grossFlowRateM3s;       // Brüt debi (can suyu kesintisi öncesi)
  final bool environmentalFlowDeducted; // Can suyu kesintisi uygulandı mı?
  final double headHeightM;
  final String turbineType;
  final double turbineEfficiency;
  final String turbineDescription;
  final String suggestedTurbine;
  final double capacityFactor;
  final Map<String, double>? monthlyProduction;
  final Map<String, double>? monthlyFlowRates;
  final FinancialAnalysis? financials;             // HES finansal analizi
  final String? plantType;                         // "Nehir Tipi HES" | "Barajlı" vb.
  final String? economicViabilityWarning;          // Min debi eşiği uyarısı

  HydroCalculationResponse({
    required this.predictedAnnualProductionKwh,
    required this.ratedPowerKw,
    required this.avgFlowRateM3s,
    this.grossFlowRateM3s,
    this.environmentalFlowDeducted = false,
    required this.headHeightM,
    required this.turbineType,
    required this.turbineEfficiency,
    required this.turbineDescription,
    required this.suggestedTurbine,
    required this.capacityFactor,
    this.monthlyProduction,
    this.monthlyFlowRates,
    this.financials,
    this.plantType,
    this.economicViabilityWarning,
  });

  // Calculate derived values
  double get potentialKwhMonthly => predictedAnnualProductionKwh / 12;
  double get potentialKwhWeekly => predictedAnnualProductionKwh / 52;

  factory HydroCalculationResponse.fromJson(Map<String, dynamic> json) {
    return HydroCalculationResponse(
      predictedAnnualProductionKwh:
          (json['predicted_annual_production_kwh'] as num).toDouble(),
      ratedPowerKw: (json['rated_power_kw'] as num).toDouble(),
      avgFlowRateM3s: (json['avg_flow_rate_m3s'] as num).toDouble(),
      grossFlowRateM3s: (json['gross_flow_rate_m3s'] as num?)?.toDouble(),
      environmentalFlowDeducted: json['environmental_flow_deducted'] as bool? ?? false,
      headHeightM: (json['head_height_m'] as num).toDouble(),
      turbineType: json['turbine_type'] as String,
      turbineEfficiency: (json['turbine_efficiency'] as num).toDouble(),
      turbineDescription: json['turbine_description'] as String,
      suggestedTurbine: json['suggested_turbine'] as String,
      capacityFactor: (json['capacity_factor'] as num).toDouble(),
      monthlyProduction: json['monthly_production'] != null
          ? Map<String, double>.from(
              (json['monthly_production'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      monthlyFlowRates: json['monthly_flow_rates'] != null
          ? Map<String, double>.from(
              (json['monthly_flow_rates'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      financials: json['financials'] != null
          ? FinancialAnalysis.fromJson(json['financials'] as Map<String, dynamic>)
          : null,
      plantType:                 json['plant_type']                  as String?,
      economicViabilityWarning:  json['economic_viability_warning']  as String?,
    );
  }
}

// Bu sınıf, 'PinResult'ın yerini almalıdır.
class PinCalculationResponse {
  final String resourceType;
  final WindCalculationResponse? windCalculation;
  final SolarCalculationResponse? solarCalculation;
  final HydroCalculationResponse? hydroCalculation;

  PinCalculationResponse({
    required this.resourceType,
    this.windCalculation,
    this.solarCalculation,
    this.hydroCalculation,
  });

  factory PinCalculationResponse.fromJson(Map<String, dynamic> json) {
    return PinCalculationResponse(
      resourceType: json['resource_type'] as String,
      windCalculation: json['wind_calculation'] != null
          ? WindCalculationResponse.fromJson(json['wind_calculation'])
          : null,
      solarCalculation: json['solar_calculation'] != null
          ? SolarCalculationResponse.fromJson(json['solar_calculation'])
          : null,
      hydroCalculation: json['hydro_calculation'] != null
          ? HydroCalculationResponse.fromJson(json['hydro_calculation'])
          : null,
    );
  }
}

// 'PinResult' sınıfı artık kullanılmamalıdır, ancak
// projenin başka yerlerinde kullanılıyorsa geçiş tamamlanana kadar
// tutabilirsin.
class PinResult {
  final double potentialKwhAnnual;
  final double estimatedCost;
  final double roiYears;

  PinResult({
    required this.potentialKwhAnnual,
    required this.estimatedCost,
    required this.roiYears,
  });

  factory PinResult.fromJson(Map<String, dynamic> json) {
    // BU SADECE BİR ÖRNEK! Backend'in böyle bir şey döndürmüyor.
    // Gerçekte PinCalculationResponse.fromJson kullanılmalı.
    return PinResult(
      potentialKwhAnnual:
          (json['potential_kwh_annual'] as num?)?.toDouble() ?? 0.0,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      roiYears: (json['roi_years'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

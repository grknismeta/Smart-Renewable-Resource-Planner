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
  });

  // Backend'e (POST /pins/ veya POST /pins/calculate) göndermek için
  Map<String, dynamic> toJson() {
    return {
      // Not: id ve ownerId backend'e gönderilmez (genellikle)
      // ancak PinBase şemana göre (schemas.py) backend bunları ayıklar.
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'type': type,
      'capacity_mw': capacityMw,
      'panel_area': panelArea,
      'panel_tilt': panelTilt,
      'panel_azimuth': panelAzimuth,
      'turbine_model_id': turbineModelId,
      'panel_model_id': panelModelId,
      'equipment_id': equipmentId,
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
    );
  }
}

// --- 2. HESAPLAMA MODELLERİ (YENİ EKLENDİ) ---
// Bu sınıflar, backend'deki (schemas.py) PinCalculationResponse vb.
// şemalarına tam olarak uymalıdır.

class SolarCalculationResponse {
  final double solarIrradianceKwM2;
  final double temperatureCelsius;
  final double panelEfficiency;
  final double powerOutputKw;
  final String panelModel;
  final double potentialKwhAnnual;
  final double performanceRatio;
  final Map<String, double>? monthlyProduction;

  SolarCalculationResponse({
    required this.solarIrradianceKwM2,
    required this.temperatureCelsius,
    required this.panelEfficiency,
    required this.powerOutputKw,
    required this.panelModel,
    required this.potentialKwhAnnual,
    required this.performanceRatio,
    this.monthlyProduction,
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

  WindCalculationResponse({
    required this.windSpeedMS,
    required this.powerOutputKw,
    required this.turbineModel,
    required this.potentialKwhAnnual,
    required this.capacityFactor,
    this.monthlyProduction,
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
    );
  }
}

// Bu sınıf, 'PinResult'ın yerini almalıdır.
class PinCalculationResponse {
  final String resourceType;
  final WindCalculationResponse? windCalculation;
  final SolarCalculationResponse? solarCalculation;

  PinCalculationResponse({
    required this.resourceType,
    this.windCalculation,
    this.solarCalculation,
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

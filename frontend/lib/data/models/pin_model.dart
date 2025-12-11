// lib/data/models/pin_model.dart

class Pin {
  final int id;
  final double latitude;
  final double longitude;
  final String name;
  final String type;
  final double capacityMw;
  final int ownerId;

  // Backend'den gelen yeni analiz verileri (Nullable olabilir)
  final double? avgSolarIrradiance;
  final double? avgWindSpeed;
  final double? panelArea;

  // Ekipman bilgisi (İleride kullanılacak)
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
    this.avgWindSpeed,
    this.panelArea,
    this.equipmentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'type': type,
      'capacity_mw': capacityMw,
      'panel_area': panelArea,
      'equipment_id': equipmentId,
    };
  }

  factory Pin.fromJson(Map<String, dynamic> json) {
    // Güvenli sayı dönüştürme yardımcısı
    double? toDouble(dynamic val) {
      if (val == null) return null;
      if (val is int) return val.toDouble();
      if (val is double) return val;
      if (val is String) return double.tryParse(val);
      return null;
    }

    return Pin(
      id: json['id'] as int,
      // Koordinatları güvenli çevir
      latitude: toDouble(json['latitude']) ?? 0.0,
      longitude: toDouble(json['longitude']) ?? 0.0,

      name: json['name'] as String? ?? "İsimsiz Kaynak",
      type: json['type'] as String? ?? "Bilinmiyor",

      capacityMw: toDouble(json['capacity_mw']) ?? 1.0,
      ownerId: json['owner_id'] as int? ?? 0,

      // Analiz verileri (Backend'deki isimlerle birebir aynı olmalı)
      avgSolarIrradiance: toDouble(json['avg_solar_irradiance']),
      avgWindSpeed: toDouble(json['avg_wind_speed']),
      panelArea: toDouble(json['panel_area']),
      equipmentId: json['equipment_id'] as int?,
    );
  }
}

// --- HESAPLAMA MODELLERİ (AYNI KALIYOR) ---

class SolarCalculationResponse {
  final double solarIrradianceKwM2;
  final double temperatureCelsius;
  final double panelEfficiency;
  final double powerOutputKw;
  final String panelModel;

  SolarCalculationResponse({
    required this.solarIrradianceKwM2,
    required this.temperatureCelsius,
    required this.panelEfficiency,
    required this.powerOutputKw,
    required this.panelModel,
  });

  factory SolarCalculationResponse.fromJson(Map<String, dynamic> json) {
    return SolarCalculationResponse(
      solarIrradianceKwM2: (json['solar_irradiance_kw_m2'] as num).toDouble(),
      temperatureCelsius: (json['temperature_celsius'] as num).toDouble(),
      panelEfficiency: (json['panel_efficiency'] as num).toDouble(),
      powerOutputKw: (json['power_output_kw'] as num).toDouble(),
      panelModel: json['panel_model'] as String,
    );
  }
}

class WindCalculationResponse {
  final double windSpeedMS;
  final double powerOutputKw;
  final String turbineModel;

  WindCalculationResponse({
    required this.windSpeedMS,
    required this.powerOutputKw,
    required this.turbineModel,
  });

  factory WindCalculationResponse.fromJson(Map<String, dynamic> json) {
    return WindCalculationResponse(
      windSpeedMS: (json['wind_speed_m_s'] as num).toDouble(),
      powerOutputKw: (json['power_output_kw'] as num).toDouble(),
      turbineModel: json['turbine_model'] as String,
    );
  }
}

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

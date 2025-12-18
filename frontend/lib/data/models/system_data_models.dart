// --- HARİTA GRID VERİSİ ---
class GridData {
  final int id;
  final double latitude;
  final double longitude;
  final String type; // 'Solar' veya 'Wind'
  final double overallScore;

  GridData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.overallScore,
  });

  factory GridData.fromJson(Map<String, dynamic> json) {
    return GridData(
      id: json['id'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: json['type'],
      overallScore: (json['overall_score'] as num).toDouble(),
    );
  }
}

// --- EKİPMAN (TÜRBİN/PANEL) ---
class Equipment {
  final int id;
  final String name;
  final String type; // 'Solar' veya 'Wind'
  final double ratedPowerKw;
  final double? efficiency;
  final double? costPerUnit;
  final Map<String, dynamic>? specs;

  Equipment({
    required this.id,
    required this.name,
    required this.type,
    required this.ratedPowerKw,
    this.efficiency,
    this.costPerUnit,
    this.specs,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      ratedPowerKw: (json['rated_power_kw'] as num).toDouble(),
      efficiency: json['efficiency'] != null
          ? (json['efficiency'] as num).toDouble()
          : null,
      costPerUnit: json['cost_per_unit'] != null
          ? (json['cost_per_unit'] as num).toDouble()
          : null,
      specs: json['specs'],
    );
  }
}

// --- BÖLGESEL RAPOR VERİLERİ ---

class RegionalSite {
  final String city;
  final String? district;
  final String type;
  final double latitude;
  final double longitude;
  final double overallScore;
  final double? annualPotentialKwhM2;
  final double? avgWindSpeedMs;
  final double? annualSolarIrradianceKwhM2;
  final int rank;

  RegionalSite({
    required this.city,
    required this.district,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.overallScore,
    this.annualPotentialKwhM2,
    this.avgWindSpeedMs,
    this.annualSolarIrradianceKwhM2,
    required this.rank,
  });

  factory RegionalSite.fromJson(Map<String, dynamic> json) {
    return RegionalSite(
      city: json['city'] ?? '-',
      district: json['district'],
      type: json['type'] ?? 'Wind',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      overallScore: (json['overall_score'] as num).toDouble(),
      annualPotentialKwhM2: json['annual_potential_kwh_m2'] != null
          ? (json['annual_potential_kwh_m2'] as num).toDouble()
          : null,
      avgWindSpeedMs: json['avg_wind_speed_ms'] != null
          ? (json['avg_wind_speed_ms'] as num).toDouble()
          : null,
      annualSolarIrradianceKwhM2: json['annual_solar_irradiance_kwh_m2'] != null
          ? (json['annual_solar_irradiance_kwh_m2'] as num).toDouble()
          : null,
      rank: json['rank'] ?? 0,
    );
  }
}

class RegionalStats {
  final double maxScore;
  final double minScore;
  final double avgScore;
  final int siteCount;

  RegionalStats({
    required this.maxScore,
    required this.minScore,
    required this.avgScore,
    required this.siteCount,
  });

  factory RegionalStats.fromJson(Map<String, dynamic> json) {
    return RegionalStats(
      maxScore: (json['max_score'] as num).toDouble(),
      minScore: (json['min_score'] as num).toDouble(),
      avgScore: (json['avg_score'] as num).toDouble(),
      siteCount: json['site_count'] ?? 0,
    );
  }
}

class RegionalReport {
  final String region;
  final String type;
  final DateTime generatedAt;
  final int periodDays;
  final List<RegionalSite> items;
  final RegionalStats? stats;

  RegionalReport({
    required this.region,
    required this.type,
    required this.generatedAt,
    required this.periodDays,
    required this.items,
    this.stats,
  });

  factory RegionalReport.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List)
        .map((e) => RegionalSite.fromJson(e))
        .toList();

    return RegionalReport(
      region: json['region'] ?? 'Tümü',
      type: json['type'] ?? 'Wind',
      generatedAt: DateTime.parse(json['generated_at']),
      periodDays: json['period_days'] ?? 365,
      items: items,
      stats: json['stats'] != null
          ? RegionalStats.fromJson(json['stats'])
          : null,
    );
  }
}

// --- OPTİMİZASYON SONUCU ---
class OptimizedPoint {
  final double latitude;
  final double longitude;
  final double windSpeedMs;
  final double annualProductionKwh;
  final double score;

  OptimizedPoint({
    required this.latitude,
    required this.longitude,
    required this.windSpeedMs,
    required this.annualProductionKwh,
    required this.score,
  });

  factory OptimizedPoint.fromJson(Map<String, dynamic> json) {
    return OptimizedPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      windSpeedMs: (json['wind_speed_ms'] as num).toDouble(),
      annualProductionKwh: (json['annual_production_kwh'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
    );
  }
}

class OptimizationResponse {
  final double totalCapacityMw;
  final double totalAnnualProductionKwh;
  final int turbineCount;
  final List<OptimizedPoint> points;

  OptimizationResponse({
    required this.totalCapacityMw,
    required this.totalAnnualProductionKwh,
    required this.turbineCount,
    required this.points,
  });

  factory OptimizationResponse.fromJson(Map<String, dynamic> json) {
    var list = json['points'] as List;
    List<OptimizedPoint> pointsList = list
        .map((i) => OptimizedPoint.fromJson(i))
        .toList();

    return OptimizationResponse(
      totalCapacityMw: (json['total_capacity_mw'] as num).toDouble(),
      totalAnnualProductionKwh: (json['total_annual_production_kwh'] as num)
          .toDouble(),
      turbineCount: json['turbine_count'],
      points: pointsList,
    );
  }
}

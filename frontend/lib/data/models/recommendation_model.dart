// Weibull analizi tabanlı akıllı bölge öneri modelleri.

class WindRoseData {
  /// 16 yön diliminin merkez açıları (derece)
  final List<double> directions;

  /// Her yöndeki frekans (%)
  final List<double> frequencies;

  /// Her yöndeki ortalama rüzgar hızı (m/s)
  final List<double> avgSpeeds;

  const WindRoseData({
    required this.directions,
    required this.frequencies,
    required this.avgSpeeds,
  });

  factory WindRoseData.fromJson(Map<String, dynamic> json) {
    return WindRoseData(
      directions: List<double>.from(
          (json['directions'] as List).map((e) => (e as num).toDouble())),
      frequencies: List<double>.from(
          (json['frequencies'] as List).map((e) => (e as num).toDouble())),
      avgSpeeds: List<double>.from(
          (json['avg_speeds'] as List).map((e) => (e as num).toDouble())),
    );
  }
}

class RecommendedCity {
  final String name;
  final double lat;
  final double lon;

  // Rüzgar
  final double? avgWindSpeed;
  final double? maxWindSpeed;
  final String? windCategory;
  final double? weibullK;
  final double? weibullLambda;
  final double? windStd;
  final WindRoseData? windRose;

  // Güneş
  final double? avgRadiation;
  final double? totalRadiationKwh;
  final String? solarCategory;

  final int recordCount;
  final double score;

  const RecommendedCity({
    required this.name,
    required this.lat,
    required this.lon,
    this.avgWindSpeed,
    this.maxWindSpeed,
    this.windCategory,
    this.weibullK,
    this.weibullLambda,
    this.windStd,
    this.windRose,
    this.avgRadiation,
    this.totalRadiationKwh,
    this.solarCategory,
    required this.recordCount,
    required this.score,
  });

  factory RecommendedCity.fromJson(Map<String, dynamic> json) {
    return RecommendedCity(
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      avgWindSpeed: (json['avg_wind_speed'] as num?)?.toDouble(),
      maxWindSpeed: (json['max_wind_speed'] as num?)?.toDouble(),
      windCategory: json['wind_category'] as String?,
      weibullK: (json['weibull_k'] as num?)?.toDouble(),
      weibullLambda: (json['weibull_lambda'] as num?)?.toDouble(),
      windStd: (json['wind_std'] as num?)?.toDouble(),
      windRose: json['wind_rose'] != null
          ? WindRoseData.fromJson(
              Map<String, dynamic>.from(json['wind_rose'] as Map))
          : null,
      avgRadiation: (json['avg_radiation'] as num?)?.toDouble(),
      totalRadiationKwh: (json['total_radiation_kwh'] as num?)?.toDouble(),
      solarCategory: json['solar_category'] as String?,
      recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RecommendationsData {
  final List<RecommendedCity> windStrong;
  final List<RecommendedCity> windStable;
  final List<RecommendedCity> windCirculation;
  final List<RecommendedCity> windWeak;
  final List<RecommendedCity> solarTop;
  final List<RecommendedCity> solarIrradianceTop;
  final List<RecommendedCity> windAnnualEfficiency;
  final List<RecommendedCity> solarAnnualEfficiency;
  final DateTime generatedAt;
  final int hoursAnalyzed;

  const RecommendationsData({
    required this.windStrong,
    required this.windStable,
    required this.windCirculation,
    required this.windWeak,
    required this.solarTop,
    required this.solarIrradianceTop,
    required this.windAnnualEfficiency,
    required this.solarAnnualEfficiency,
    required this.generatedAt,
    required this.hoursAnalyzed,
  });

  factory RecommendationsData.fromJson(Map<String, dynamic> json) {
    List<RecommendedCity> parseList(String key) => json[key] is List
        ? (json[key] as List)
            .map((e) => RecommendedCity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : [];

    return RecommendationsData(
      windStrong: parseList('wind_strong'),
      windStable: parseList('wind_stable'),
      windCirculation: parseList('wind_circulation'),
      windWeak: parseList('wind_weak'),
      solarTop: parseList('solar_top'),
      solarIrradianceTop: parseList('solar_irradiance_top'),
      windAnnualEfficiency: parseList('wind_annual_efficiency'),
      solarAnnualEfficiency: parseList('solar_annual_efficiency'),
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ??
          DateTime.now(),
      hoursAnalyzed: (json['hours_analyzed'] as num?)?.toInt() ?? 168,
    );
  }

  bool get isEmpty =>
      windStrong.isEmpty &&
      windStable.isEmpty &&
      windCirculation.isEmpty &&
      windWeak.isEmpty &&
      solarTop.isEmpty &&
      solarIrradianceTop.isEmpty &&
      windAnnualEfficiency.isEmpty &&
      solarAnnualEfficiency.isEmpty;
}

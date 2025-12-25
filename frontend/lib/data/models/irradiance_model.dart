// lib/data/models/irradiance_model.dart

/// Işınım (Irradiance) Veri Modeli
/// Backend'den gelen güneş ışınım verilerini temsil eder
class IrradianceData {
  final String cityName;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  // Radyasyon değerleri (W/m²)
  final double? shortwaveRadiation; // Toplam kısa dalga radyasyonu
  final double? directRadiation; // Direkt radyasyon
  final double? diffuseRadiation; // Dağınık radyasyon
  final double? directNormalIrradiance; // DNI - Direkt normal ışınım

  // Ek bilgiler
  final double? cloudCover; // Bulut örtüsü (%)
  final double? temperature; // Sıcaklık (°C)

  IrradianceData({
    required this.cityName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.shortwaveRadiation,
    this.directRadiation,
    this.diffuseRadiation,
    this.directNormalIrradiance,
    this.cloudCover,
    this.temperature,
  });

  /// Backend JSON'dan model oluştur
  factory IrradianceData.fromJson(Map<String, dynamic> json) {
    return IrradianceData(
      cityName: json['city_name'] ?? '',
      latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? json['lon'] ?? 0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      shortwaveRadiation: json['shortwave_radiation']?.toDouble(),
      directRadiation: json['direct_radiation']?.toDouble(),
      diffuseRadiation: json['diffuse_radiation']?.toDouble(),
      directNormalIrradiance: json['direct_normal_irradiance']?.toDouble(),
      cloudCover: json['cloud_cover']?.toDouble(),
      temperature: json['temperature_2m']?.toDouble(),
    );
  }

  /// Model'i JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'city_name': cityName,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'shortwave_radiation': shortwaveRadiation,
      'direct_radiation': directRadiation,
      'diffuse_radiation': diffuseRadiation,
      'direct_normal_irradiance': directNormalIrradiance,
      'cloud_cover': cloudCover,
      'temperature_2m': temperature,
    };
  }

  /// Günlük toplam ışınım (kWh/m²)
  /// shortwaveRadiation W/m² cinsinden saatlik veridir
  /// Günlük toplam için tüm saatlerin toplamını alıp 1000'e bölmek gerekir
  double? get dailyIrradianceKwhM2 {
    if (shortwaveRadiation == null) return null;
    // Tek saatlik veri için kWh/m² dönüşümü
    return shortwaveRadiation! / 1000.0;
  }

  /// Işınım kalitesi skoru (0-100)
  /// Direct radiation'ın total radiation'a oranına göre
  double? get irradianceQualityScore {
    if (shortwaveRadiation == null || shortwaveRadiation! == 0) return null;
    if (directRadiation == null) return null;

    final ratio = directRadiation! / shortwaveRadiation!;
    return (ratio * 100).clamp(0, 100);
  }

  @override
  String toString() {
    return 'IrradianceData(city: $cityName, sw: $shortwaveRadiation W/m², '
        'direct: $directRadiation W/m², timestamp: $timestamp)';
  }
}

/// Şehir bazlı ışınım özet verisi
class CitySolarSummary {
  final String cityName;
  final double latitude;
  final double longitude;
  final DateTime? lastUpdate;
  final int recordCount;

  // Ortalama ve toplam değerler
  final double? avgShortwaveRadiation;
  final double? avgDirectRadiation;
  final double? avgDiffuseRadiation;
  final double? totalDailyIrradianceKwhM2;
  final double? avgCloudCover;
  final double? avgTemperature;

  CitySolarSummary({
    required this.cityName,
    required this.latitude,
    required this.longitude,
    this.lastUpdate,
    required this.recordCount,
    this.avgShortwaveRadiation,
    this.avgDirectRadiation,
    this.avgDiffuseRadiation,
    this.totalDailyIrradianceKwhM2,
    this.avgCloudCover,
    this.avgTemperature,
  });

  factory CitySolarSummary.fromJson(Map<String, dynamic> json) {
    return CitySolarSummary(
      cityName: json['city_name'] ?? '',
      latitude: (json['lat'] ?? 0).toDouble(),
      longitude: (json['lon'] ?? 0).toDouble(),
      lastUpdate: json['last_update'] != null
          ? DateTime.parse(json['last_update'])
          : null,
      recordCount: json['record_count'] ?? 0,
      avgShortwaveRadiation: json['avg_shortwave_radiation']?.toDouble(),
      avgDirectRadiation: json['avg_direct_radiation']?.toDouble(),
      avgDiffuseRadiation: json['avg_diffuse_radiation']?.toDouble(),
      totalDailyIrradianceKwhM2: json['total_daily_irradiance_kwh_m2']
          ?.toDouble(),
      avgCloudCover: json['avg_cloud_cover']?.toDouble(),
      avgTemperature: json['avg_temperature']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city_name': cityName,
      'lat': latitude,
      'lon': longitude,
      'last_update': lastUpdate?.toIso8601String(),
      'record_count': recordCount,
      'avg_shortwave_radiation': avgShortwaveRadiation,
      'avg_direct_radiation': avgDirectRadiation,
      'avg_diffuse_radiation': avgDiffuseRadiation,
      'total_daily_irradiance_kwh_m2': totalDailyIrradianceKwhM2,
      'avg_cloud_cover': avgCloudCover,
      'avg_temperature': avgTemperature,
    };
  }

  /// Güneş potansiyeli skoru (0-100)
  num? get solarPotentialScore {
    if (avgShortwaveRadiation == null) return null;
    // 1000 W/m² ideal kabul ediliyor
    final score = (avgShortwaveRadiation! / 1000.0 * 100).clamp(0, 100);
    return score;
  }

  @override
  String toString() {
    return 'CitySolarSummary(city: $cityName, '
        'avgRadiation: $avgShortwaveRadiation W/m², records: $recordCount)';
  }
}

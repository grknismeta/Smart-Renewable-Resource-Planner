/// Şehir bazlı anlık hava durumu verisi
class CityWeatherData {
  final String cityName;
  final double lat;
  final double lon;
  final double temperature;
  final double windSpeed;
  final double? radiation;
  final DateTime timestamp;

  // Genişletilmiş ışınım verileri
  final double? shortwaveRadiation;
  final double? directRadiation;
  final double? diffuseRadiation;
  final double? directNormalIrradiance;
  final double? cloudCover;
  final double? windSpeed10m;
  final double? relativeHumidity;
  final double? windDirection;
  final IrradianceData? solarData;

  CityWeatherData({
    required this.cityName,
    required this.lat,
    required this.lon,
    required this.temperature,
    required this.windSpeed,
    this.radiation,
    required this.timestamp,
    this.shortwaveRadiation,
    this.directRadiation,
    this.diffuseRadiation,
    this.directNormalIrradiance,
    this.cloudCover,
    this.windSpeed10m,
    this.relativeHumidity,
    this.windDirection,
    this.solarData,
  });

  factory CityWeatherData.fromJson(Map<String, dynamic> json) {
    return CityWeatherData(
      cityName: json['city_name'] ?? '',
      lat: (json['lat'] ?? json['latitude'] ?? 0).toDouble(),
      lon: (json['lon'] ?? json['longitude'] ?? 0).toDouble(),
      temperature: (json['temperature_2m'] ?? json['temperature'] ?? 0)
          .toDouble(),
      windSpeed: (json['wind_speed_100m'] ?? json['wind_speed'] ?? 0)
          .toDouble(),
      radiation: json['shortwave_radiation']?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      // Genişletilmiş alanlar
      shortwaveRadiation: json['shortwave_radiation']?.toDouble(),
      directRadiation: json['direct_radiation']?.toDouble(),
      diffuseRadiation: json['diffuse_radiation']?.toDouble(),
      directNormalIrradiance: json['direct_normal_irradiance']?.toDouble(),
      cloudCover: json['cloud_cover']?.toDouble(),
      windSpeed10m: json['wind_speed_10m']?.toDouble(),
      relativeHumidity: json['relative_humidity_2m']?.toDouble(),
      windDirection: json['wind_direction_10m']?.toDouble(),
      solarData: json['solar_data'] != null ? IrradianceData.fromJson(json['solar_data']) : null,
    );
  }

  /// Anlık ışınım gücü (kW/m²) — saatlik veri noktası.
  /// Gece (shortwaveRadiation == 0) için null döner → göstergede 0 gösterilmez.
  double? get dailyIrradianceKwhM2 {
    if (shortwaveRadiation == null || shortwaveRadiation! <= 0) return null;
    return shortwaveRadiation! / 1000.0;
  }

  /// Işınım kalitesi (0-100)
  double? get irradianceQuality {
    if (shortwaveRadiation == null || shortwaveRadiation! == 0) return null;
    if (directRadiation == null) return null;
    final ratio = directRadiation! / shortwaveRadiation!;
    return (ratio * 100).clamp(0, 100);
  }
}

/// Şehir özet hava durumu verisi
class CityWeatherSummary {
  final String cityName;
  final String? districtName;
  final double lat;
  final double lon;
  final double? avgTemperature;
  final double? avgWindSpeed10m;
  final double? avgWindSpeed100m;
  final double? totalRadiation;
  final DateTime? lastUpdate;
  final int recordCount;

  CityWeatherSummary({
    required this.cityName,
    this.districtName,
    required this.lat,
    required this.lon,
    this.avgTemperature,
    this.avgWindSpeed10m,
    this.avgWindSpeed100m,
    this.totalRadiation,
    this.lastUpdate,
    required this.recordCount,
  });

  factory CityWeatherSummary.fromJson(Map<String, dynamic> json) {
    return CityWeatherSummary(
      cityName: json['city_name'] ?? '',
      districtName: json['district_name'],
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
      avgTemperature: json['avg_temperature']?.toDouble(),
      avgWindSpeed10m: json['avg_wind_speed_10m']?.toDouble(),
      avgWindSpeed100m: json['avg_wind_speed_100m']?.toDouble(),
      totalRadiation: json['total_radiation']?.toDouble(),
      lastUpdate: json['last_update'] != null
          ? DateTime.parse(json['last_update'])
          : null,
      recordCount: json['record_count'] ?? 0,
    );
  }
}

/// İl (province) bazlı özet hava durumu verisi
class ProvinceSummary {
  final String provinceName;
  final double? avgWindSpeed;
  final double? avgRadiation;
  final double? avgTemperature;
  final int recordCount;

  const ProvinceSummary({
    required this.provinceName,
    this.avgWindSpeed,
    this.avgRadiation,
    this.avgTemperature,
    required this.recordCount,
  });

  factory ProvinceSummary.fromJson(Map<String, dynamic> json) {
    return ProvinceSummary(
      provinceName: json['province_name'] as String,
      avgWindSpeed: (json['avg_wind_speed'] as num?)?.toDouble(),
      avgRadiation: (json['avg_radiation'] as num?)?.toDouble(),
      avgTemperature: (json['avg_temperature'] as num?)?.toDouble(),
      recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// İlçe bazlı hava durumu özeti (7 gün ortalaması)
class DistrictSummary {
  final String districtName;
  final String provinceName;
  final double? lat;
  final double? lon;
  final double? avgWindSpeed;
  final double? avgRadiation;
  final double? avgTemperature;
  final int recordCount;

  const DistrictSummary({
    required this.districtName,
    required this.provinceName,
    this.lat,
    this.lon,
    this.avgWindSpeed,
    this.avgRadiation,
    this.avgTemperature,
    required this.recordCount,
  });

  factory DistrictSummary.fromJson(Map<String, dynamic> json) {
    return DistrictSummary(
      districtName: json['district_name'] as String,
      provinceName: json['province_name'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      avgWindSpeed: (json['avg_wind_speed'] as num?)?.toDouble(),
      avgRadiation: (json['avg_radiation'] as num?)?.toDouble(),
      avgTemperature: (json['avg_temperature'] as num?)?.toDouble(),
      recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 7 coğrafi bölge bazlı hava durumu özeti
class RegionSummary {
  final String regionName;
  final int provinceCount;
  final double? avgWindSpeed;
  final double? avgRadiation;
  final double? avgTemperature;

  const RegionSummary({
    required this.regionName,
    required this.provinceCount,
    this.avgWindSpeed,
    this.avgRadiation,
    this.avgTemperature,
  });

  factory RegionSummary.fromJson(Map<String, dynamic> json) {
    return RegionSummary(
      regionName: json['region_name'] as String,
      provinceCount: (json['province_count'] as num?)?.toInt() ?? 0,
      avgWindSpeed: (json['avg_wind_speed'] as num?)?.toDouble(),
      avgRadiation: (json['avg_radiation'] as num?)?.toDouble(),
      avgTemperature: (json['avg_temperature'] as num?)?.toDouble(),
    );
  }
}

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

  /// Anlık ışınım gücü (kW/m²) — saatlik veri noktası.
  /// Gece (shortwaveRadiation == 0) için null döner → göstergede 0 gösterilmez.
  double? get dailyIrradianceKwhM2 {
    if (shortwaveRadiation == null || shortwaveRadiation! <= 0) return null;
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

/// Trend grafik veri noktası (Aylık / Günlük trend)
class TrendPoint {
  final String label; // "Oca".."Ara" veya "1".."31"
  final double value;

  const TrendPoint({required this.label, required this.value});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

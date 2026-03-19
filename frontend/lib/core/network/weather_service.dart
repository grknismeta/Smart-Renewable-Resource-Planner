import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/core/network/api_client.dart';

class WeatherService extends BaseService {
  WeatherService(super.storageService);

  Future<List<CityWeatherSummary>> fetchWeatherSummary({
    int hours = 168,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/weather/summary',
    ).replace(queryParameters: {'hours': '$hours'});
    final response = await http.get(uri);
    
    final data = processResponse(response);
    if (data is List) {
       return data.map((json) => CityWeatherSummary.fromJson(json)).toList();
    }
    throw Exception('Hava durumu verisi alınamadı');
  }

  Future<List<CityWeatherData>> fetchWeatherForTime(DateTime time) async {
    final timestamp = time.toIso8601String();
    final response = await http.get(
      Uri.parse('$baseUrl/weather/at-time?timestamp=$timestamp'),
    );
    
    final data = processResponse(response);
    if (data is List) {
        return data.map((json) => CityWeatherData.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<CityWeatherData>> fetchCityHourly(
    String cityName, {
    int hours = 168,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/weather/cities/$cityName/hourly',
    ).replace(queryParameters: {'hours': '$hours'});
    final response = await http.get(uri);
    
    final data = processResponse(response);
    if (data is List) {
       return data.map((e) => CityWeatherData.fromJson(e)).toList();
    }
    throw Exception(
      'Şehir saatlik verisi alınamadı (status: ${response.statusCode})',
    );
  }

  Future<List<IrradianceData>> fetchCityIrradiance(
    String cityName, {
    int hours = 168,
  }) async {
    debugPrint(
      '[WeatherService.fetchCityIrradiance] Çağrıldı: city=$cityName, hours=$hours',
    );
    final uri = Uri.parse(
      '$baseUrl/weather/cities/$cityName/hourly',
    ).replace(queryParameters: {'hours': '$hours'});

    final response = await http.get(uri);
    debugPrint(
      '[WeatherService.fetchCityIrradiance] Response status: ${response.statusCode}',
    );

    final data = processResponse(response);
    if (data is List) {
      debugPrint(
        '[WeatherService.fetchCityIrradiance] ${data.length} kayıt alındı',
      );
      return data.map((e) => IrradianceData.fromJson(e)).toList();
    }
    throw Exception(
      'Işınım verisi alınamadı (status: ${response.statusCode})',
    );
  }

  Future<List<ProvinceSummary>> fetchProvinceSummary({int hours = 168}) async {
    final uri = Uri.parse(
      '$baseUrl/weather/province-summary',
    ).replace(queryParameters: {'hours': '$hours'});
    final response = await http.get(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => ProvinceSummary.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<DistrictSummary>> fetchDistrictSummary({
    required String province,
    int hours = 168,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/weather/district-summary',
    ).replace(queryParameters: {'province': province, 'hours': '$hours'});
    final response = await http.get(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => DistrictSummary.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<RegionSummary>> fetchRegionSummary({int hours = 168}) async {
    final uri = Uri.parse(
      '$baseUrl/weather/region-summary',
    ).replace(queryParameters: {'hours': '$hours'});
    final response = await http.get(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => RegionSummary.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchBestSolarCities({
    int limit = 400,
  }) async {
    debugPrint('[WeatherService.fetchBestSolarCities] Çağrıldı: limit=$limit');
    final uri = Uri.parse(
      '$baseUrl/weather/best-solar',
    ).replace(queryParameters: {'limit': '$limit'});

    final response = await http.get(uri);
    
    final data = processResponse(response);
     if (data is List) {
      debugPrint(
        '[WeatherService.fetchBestSolarCities] ${data.length} şehir alındı',
      );
      return data.cast<Map<String, dynamic>>();
    }
     throw Exception(
      'En iyi güneş şehirleri alınamadı (status: ${response.statusCode})',
    );
  }

  /// Animasyon için kullanılabilir veri tarih aralığını döndürür.
  /// { daily_min, daily_max, hourly_min, hourly_max }
  Future<Map<String, dynamic>> fetchAnimationRange() async {
    final response = await http.get(
      Uri.parse('$baseUrl/weather/animation/range'),
    );
    final data = processResponse(response);
    if (data is Map<String, dynamic>) return data;
    throw Exception('Animasyon aralığı alınamadı');
  }

  /// Animasyon frame verisi döndürür.
  ///
  /// [start] / [end]: "YYYY-MM-DD"
  /// [metric]: "wind" | "temperature" | "radiation"
  /// [interval]: "daily" | "hourly"
  Future<Map<String, dynamic>> fetchAnimationData({
    required String start,
    required String end,
    required String metric,
    required String interval,
  }) async {
    final uri = Uri.parse('$baseUrl/weather/animation').replace(
      queryParameters: {
        'start': start,
        'end': end,
        'metric': metric,
        'interval': interval,
      },
    );
    final response = await http.get(uri);
    final data = processResponse(response);
    if (data is Map<String, dynamic>) return data;
    throw Exception('Animasyon verisi alınamadı');
  }

  // ── Rapor Dashboard metodları ──────────────────────────────────────────────

  /// DB'de kayıtlı yıllar listesi (zaman aralığı seçici için).
  Future<List<int>> fetchAvailableYears() async {
    final response =
        await http.get(Uri.parse('$baseUrl/weather/available-years'));
    final data = processResponse(response);
    if (data is List) return data.cast<int>();
    return [];
  }

  /// Aylık veya günlük trend verisi.
  ///
  /// [metric]: "solar" | "wind" | "temperature"
  /// [month]: null → 12 aylık özet; 1-12 → o ayın günlük özeti
  Future<List<TrendPoint>> fetchMonthlyTrend(
    String city,
    String metric,
    int year, {
    int? month,
  }) async {
    final params = <String, String>{
      'city': city,
      'metric': metric,
      'year': '$year',
    };
    if (month != null) params['month'] = '$month';

    final uri = Uri.parse(
      '$baseUrl/weather/monthly-trend',
    ).replace(queryParameters: params);
    final response = await http.get(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => TrendPoint.fromJson(e)).toList();
    }
    return [];
  }

  /// Tarih aralığı bazlı il özeti (Yıllık / Özel aralık modları için).
  Future<List<ProvinceSummary>> fetchProvinceSummaryByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    String fmtDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(
      '$baseUrl/weather/province-summary-range',
    ).replace(queryParameters: {'start': fmtDate(start), 'end': fmtDate(end)});
    final response = await http.get(uri);
    final data = processResponse(response);
    if (data is List) {
      return data.map((e) => ProvinceSummary.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<CitySolarSummary>> fetchSolarSummary({int hours = 168}) async {
    debugPrint('[WeatherService.fetchSolarSummary] Çağrıldı: hours=$hours');

    final summaries = await fetchWeatherSummary(hours: hours);

    return summaries.map((weather) {
      final avgRadiationWm2 =
          weather.totalRadiation != null && weather.recordCount > 0
          ? weather.totalRadiation! / weather.recordCount
          : null;

      final dailyKwhM2 = avgRadiationWm2 != null
          ? (avgRadiationWm2 * 24 * 365) / 1000.0
          : null;

      return CitySolarSummary(
        cityName: weather.cityName,
        latitude: weather.lat,
        longitude: weather.lon,
        lastUpdate: weather.lastUpdate,
        recordCount: weather.recordCount,
        avgShortwaveRadiation: avgRadiationWm2,
        avgDirectRadiation: null, 
        avgDiffuseRadiation: null,
        totalDailyIrradianceKwhM2: dailyKwhM2,
        avgCloudCover: null,
        avgTemperature: weather.avgTemperature,
      );
    }).toList();
  }
}

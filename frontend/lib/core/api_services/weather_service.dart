import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/models/weather_model.dart';
import 'base_service.dart';

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

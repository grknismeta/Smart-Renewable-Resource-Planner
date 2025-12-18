// lib/core/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../data/models/pin_model.dart'; // Bu dosya PinCalculationResponse'u içeriyor
import '../data/models/system_data_models.dart'; // OptimizationResponse için
import '../data/models/scenario_model.dart'; // Scenario modelleri
import 'secure_storage_service.dart';

//
import 'dart:io' show Platform; // Platform tespiti için eklendi
import 'package:flutter/foundation.dart'
    show kIsWeb; // Web tespiti için eklendi

String get _apiBaseUrl {
  if (kIsWeb) {
    // Web'de çalışıyorsa
    return 'http://127.0.0.1:8000';
  } else if (Platform.isAndroid) {
    // Android emülatörde çalışıyorsa
    return 'http://10.0.2.2:8000';
  } else {
    // iOS simülatörü veya diğer platformlar (macOS, Windows vb.)
    return 'http://127.0.0.1:8000';
  }
}
//

class ApiService {
  final SecureStorageService _storageService;

  ApiService(this._storageService);

  // --- Genel HTTP İstek Yardımcısı ---
  Future<Map<String, String>> _getHeaders({String? token}) async {
    final t = token ?? await _storageService.readToken();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  // --- Ekipman Kataloğu ---

  Future<List<Equipment>> fetchEquipments({String? type}) async {
    print('[ApiService.fetchEquipments] Çağrıldı: type=$type');
    final query = type != null ? '?type=$type' : '';
    print('[ApiService.fetchEquipments] URL: $_apiBaseUrl/equipments$query');
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/equipments$query'),
      headers: await _getHeaders(),
    );

    print(
      '[ApiService.fetchEquipments] Response status: ${response.statusCode}',
    );
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as List;
      print('[ApiService.fetchEquipments] ${data.length} ekipman alındı');
      return data.map((e) => Equipment.fromJson(e)).toList();
    }

    throw Exception(
      'Ekipman listesi alınamadı (status: ${response.statusCode})',
    );
  }

  // --- Kimlik Doğrulama İşlemleri ---
  // ... (login ve register fonksiyonları - değişiklik yok) ...
  Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/users/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final token = jsonResponse['access_token'] as String;
      await _storageService.saveToken(token);
      return token;
    } else {
      throw Exception('Giriş başarısız. Hatalı e-posta veya parola.');
    }
  }

  Future<void> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/users/register'),
      headers: await _getHeaders(token: null),
      body: json.encode({'email': email, 'password': password}),
    );
    if (response.statusCode != 201) {
      final errorJson = json.decode(response.body);
      String detail = errorJson['detail'] ?? 'Kayıt başarısız.';
      throw Exception(detail);
    }
  }

  // --- Pin (Kaynak) Yönetimi İşlemleri ---

  Future<List<Pin>> fetchPins() async {
    // ... (değişiklik yok) ...
    print('[ApiService.fetchPins] API çağrısı yapılıyor: $_apiBaseUrl/pins/');
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/pins/'),
      headers: await _getHeaders(),
    );
    print('[ApiService.fetchPins] Response status: ${response.statusCode}');
    if (response.statusCode == 200) {
      List<dynamic> pinsJson = json.decode(utf8.decode(response.bodyBytes));
      print(
        '[ApiService.fetchPins] ${pinsJson.length} pin JSON den parse edildi',
      );
      return pinsJson.map((json) => Pin.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Yetki hatası. Lütfen tekrar giriş yapın.');
    } else {
      throw Exception(
        'Kaynaklar yüklenemedi (Status code: ${response.statusCode})',
      );
    }
  }

  // --- 1. GÜNCELLEME: 'addPin' fonksiyonu artık tüm verileri alıyor ---
  Future<void> addPin(
    LatLng point,
    String name,
    String type,
    double capacityMw,
    int? equipmentId, // Ekipman ID'si eklendi
  ) async {
    // 'Pin' constructor'ı yerine 'Map' oluştur
    final Map<String, dynamic> pinData = {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'name': name, // <-- Artık dinamik
      'type': type, // <-- Artık dinamik
      'capacity_mw': capacityMw, // <-- Artık dinamik
      if (equipmentId != null) 'equipment_id': equipmentId, // Ekipman ID'si
    };

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/pins/'),
      headers: await _getHeaders(),
      body: json.encode(pinData),
    );
    if (response.statusCode != 201) {
      throw Exception('Pin eklenemedi (Status code: ${response.statusCode})');
    }
  }

  Future<void> deletePin(int pinId) async {
    // ... (değişiklik yok) ...
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/pins/$pinId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Pin silinemedi (Status code: ${response.statusCode})');
    }
  }

  // --- Enerji Hesaplama İşlemi ---
  Future<PinCalculationResponse> calculateEnergyPotential({
    // ... (değişiklik yok) ...
    required double lat,
    required double lon,
    required String type,
    required double capacityMw,
    required double panelArea,
  }) async {
    final Map<String, dynamic> pinData = {
      'latitude': lat,
      'longitude': lon,
      'name': "Hesaplanacak",
      'type': type,
      'capacity_mw': capacityMw,
      'panel_area': panelArea,
    };

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/pins/calculate'),
      headers: await _getHeaders(),
      body: json.encode(pinData),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return PinCalculationResponse.fromJson(jsonResponse);
    } else {
      throw Exception(
        'Hesaplama başarısız (Status code: ${response.statusCode})',
      );
    }
  }

  // --- Hava Durumu İşlemleri ---

  /// Tüm şehirler için özet hava durumu verisi getir
  Future<List<CityWeatherSummary>> fetchWeatherSummary({
    int hours = 168,
  }) async {
    final uri = Uri.parse(
      '$_apiBaseUrl/weather/summary',
    ).replace(queryParameters: {'hours': '$hours'});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => CityWeatherSummary.fromJson(json)).toList();
    } else {
      throw Exception('Hava durumu verisi alınamadı');
    }
  }

  /// Belirli bir zaman için şehirlerin hava durumu verisi
  Future<List<CityWeatherData>> fetchWeatherForTime(DateTime time) async {
    // Backend'de bu endpoint'i oluşturacağız
    final timestamp = time.toIso8601String();
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/weather/at-time?timestamp=$timestamp'),
    );
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => CityWeatherData.fromJson(json)).toList();
    } else {
      // Hata durumunda boş liste döndür
      return [];
    }
  }

  /// Belirli bir şehir için son N saatlik (varsayılan 7 gün) veri
  Future<List<CityWeatherData>> fetchCityHourly(
    String cityName, {
    int hours = 168,
  }) async {
    final uri = Uri.parse(
      '$_apiBaseUrl/weather/cities/$cityName/hourly',
    ).replace(queryParameters: {'hours': '$hours'});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((e) => CityWeatherData.fromJson(e)).toList();
    } else {
      throw Exception(
        'Şehir saatlik verisi alınamadı (status: ${response.statusCode})',
      );
    }
  }

  // --- Optimizasyon İşlemleri ---

  /// Seçilen bölge için rüzgar türbini yerleşim optimizasyonu
  Future<OptimizationResponse> optimizeWindPlacement({
    required double topLeftLat,
    required double topLeftLon,
    required double bottomRightLat,
    required double bottomRightLon,
    required int equipmentId,
    double minDistanceM = 0.0,
  }) async {
    final Map<String, dynamic> requestData = {
      'top_left_lat': topLeftLat,
      'top_left_lon': topLeftLon,
      'bottom_right_lat': bottomRightLat,
      'bottom_right_lon': bottomRightLon,
      'equipment_id': equipmentId,
      'min_distance_m': minDistanceM,
    };

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/optimization/wind-placement'),
      headers: await _getHeaders(),
      body: json.encode(requestData),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return OptimizationResponse.fromJson(jsonResponse);
    } else {
      throw Exception(
        'Optimizasyon hesaplaması başarısız (Status code: ${response.statusCode})',
      );
    }
  }

  // --- Raporlama ---

  Future<RegionalReport> fetchRegionalReport({
    required String region,
    required String type,
    int limit = 80,
  }) async {
    final uri = Uri.parse('$_apiBaseUrl/reports/regional').replace(
      queryParameters: {'region': region, 'type': type, 'limit': '$limit'},
    );

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return RegionalReport.fromJson(data);
    }

    throw Exception('Rapor verisi alınamadı (status: ${response.statusCode})');
  }

  // --- Senaryolar ---

  Future<List<Scenario>> fetchScenarios() async {
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/scenarios/'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as List;
      return data.map((e) => Scenario.fromJson(e)).toList();
    }

    throw Exception('Senaryolar yüklenemedi (status: ${response.statusCode})');
  }

  Future<Scenario> createScenario(ScenarioCreate scenario) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/scenarios/'),
      headers: await _getHeaders(),
      body: json.encode(scenario.toJson()),
    );

    if (response.statusCode == 201) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return Scenario.fromJson(data);
    }

    throw Exception('Senaryo oluşturulamadı (status: ${response.statusCode})');
  }

  Future<Scenario> calculateScenario(int scenarioId) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/scenarios/$scenarioId/calculate'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return Scenario.fromJson(data);
    }

    throw Exception('Senaryo hesaplanamadı (status: ${response.statusCode})');
  }
}

/// Şehir bazlı anlık hava durumu verisi
class CityWeatherData {
  final String cityName;
  final double lat;
  final double lon;
  final double temperature;
  final double windSpeed;
  final double? radiation;
  final DateTime timestamp;

  CityWeatherData({
    required this.cityName,
    required this.lat,
    required this.lon,
    required this.temperature,
    required this.windSpeed,
    this.radiation,
    required this.timestamp,
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
    );
  }
}

/// Şehir özet hava durumu verisi
class CityWeatherSummary {
  final String cityName;
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

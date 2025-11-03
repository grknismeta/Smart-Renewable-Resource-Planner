// lib/core/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../data/models/pin_model.dart'; // Bu dosya PinCalculationResponse'u içeriyor
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

  // --- Kimlik Doğrulama İşlemleri ---

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
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/pins/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      List<dynamic> pinsJson = json.decode(utf8.decode(response.bodyBytes));
      return pinsJson.map((json) => Pin.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Yetki hatası. Lütfen tekrar giriş yapın.');
    } else {
      throw Exception(
        'Kaynaklar yüklenemedi (Status code: ${response.statusCode})',
      );
    }
  }

  // --- BU FONKSİYON DÜZELTİLDİ ---
  Future<void> addPin(LatLng point) async {
    // Hatanın nedeni 'Pin' constructor'ını çağırmaktı.
    // 'PinCreate' şeması 'id' veya 'ownerId' beklemez.
    // Bu yüzden backend'in beklediği Map'i manuel olarak oluşturuyoruz:
    final Map<String, dynamic> pinData = {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'name': 'Yeni Kaynak', // Varsayılan değer
      'type': 'Güneş Paneli', // Varsayılan değer
      'capacity_mw': 1.0, // Varsayılan değer
      // Backend'deki PinBase'de olan diğer tüm alanlar (panel_area vb.)
      // 'null' veya varsayılan değerlerini alacak.
    };

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/pins/'),
      headers: await _getHeaders(),
      // 'pinData.toJson()' yerine doğrudan 'pinData' Map'ini encode ediyoruz
      body: json.encode(pinData),
    );
    if (response.statusCode != 201) {
      // 422 hatası alırsanız, bu Map'in backend'deki
      // PinCreate şemasıyla eşleşmediği anlamına gelir.
      throw Exception('Pin eklenemedi (Status code: ${response.statusCode})');
    }
  }

  Future<void> deletePin(int pinId) async {
    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/pins/$pinId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Pin silinemedi (Status code: ${response.statusCode})');
    }
  }

  // --- Enerji Hesaplama İşlemi ---

  // --- 1. DÜZELTME: Fonksiyonun dönüş tipini 'PinResult'tan 'PinCalculationResponse'a değiştir
  Future<PinCalculationResponse> calculateEnergyPotential({
    required double lat,
    required double lon,
    required String type,
    required double capacityMw,
    required double panelArea,
  }) async {
    // --- 3. DÜZELTME: 'Pin' constructor'ı yerine 'Map' oluştur ---
    // Bu, 'missing ownerId' hatasını çözer.
    // Backend'in /pins/calculate endpoint'i PinBase şemasını bekler.
    final Map<String, dynamic> pinData = {
      'latitude': lat,
      'longitude': lon,
      'name': "Hesaplanacak", // Bu alan PinBase'de var, gönderilmeli
      'type': type,
      'capacity_mw': capacityMw,
      'panel_area': panelArea, // Backend'e gönderilecek
      // PinBase'deki diğer alanlar (tilt, azimuth vb.) varsayılan değerlerini alacak
    };

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/pins/calculate'),
      headers: await _getHeaders(),
      // 'pinForCalculation.toJson()' yerine 'pinData' Map'ini encode et
      body: json.encode(pinData),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));

      // --- 2. DÜZELTME: Dönen JSON'ı 'PinResult' yerine 'PinCalculationResponse' ile parse et
      return PinCalculationResponse.fromJson(jsonResponse);
    } else {
      throw Exception(
        'Hesaplama başarısız (Status code: ${response.statusCode})',
      );
    }
  }
}

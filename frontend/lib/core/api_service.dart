// lib/core/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../data/models/pin_model.dart';
import 'secure_storage_service.dart';

// Yerel makinede çalışan back-end adresi
// Android emülatör için: '[http://10.0.2.2:8000](http://10.0.2.2:8000)'
// Web ve iOS simülatör için: '[http://127.0.0.1:8000](http://127.0.0.1:8000)'
const String _apiBaseUrl = 'http://10.0.2.2:8000'; // Web ve iOS simülatör
// const String _apiBaseUrlEmulator = 'http://10.0.2.2:8000'; // Android emülatör

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
      throw Exception('Kaynaklar yüklenemedi (Status code: ${response.statusCode})');
    }
  }

  Future<void> addPin(LatLng point) async {
    final pinData = Pin(
      id: 0, 
      name: 'Yeni Kaynak', 
      type: 'Güneş Paneli', // Varsayılan değer
      capacityMw: 1.0,      // Varsayılan değer
      latitude: point.latitude,
      longitude: point.longitude,
    );
    
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/pins/'),
      headers: await _getHeaders(),
      body: json.encode(pinData.toJson()),
    );
    if (response.statusCode != 201) {
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
  Future<PinResult> calculateEnergyPotential({
    required double lat,
    required double lon,
    required String type,
    required double capacityMw,
  }) async {
    final Pin pinForCalculation = Pin(
      id: 0,
      name: "Hesaplanacak",
      type: type,
      capacityMw: capacityMw,
      latitude: lat,
      longitude: lon,
    );
    
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/pins/calculate'),
      headers: await _getHeaders(),
      body: json.encode(pinForCalculation.toJson()),
    );
    
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      return PinResult.fromJson(jsonResponse);
    } else {
      throw Exception('Hesaplama başarısız (Status code: ${response.statusCode})');
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';

class AuthService extends BaseService {
  AuthService(super.storageService);

  Future<String> login(String email, String password) async {
    final uri = Uri.parse('$baseUrl/users/token');

    late final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );
    } catch (e) {
      debugPrint('[Auth] Network hatası: $e');
      throw Exception(
          'Sunucuya bağlanılamadı. Backend çalıştığından emin olun.');
    }

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final token = jsonResponse['access_token'] as String;
      await storageService.saveToken(token);
      return token;
    } else {
      // Backend'in döndürdüğü hata mesajını kullan
      String detail = 'Giriş başarısız. Hatalı e-posta veya parola.';
      try {
        final body = json.decode(response.body);
        if (body is Map && body['detail'] != null) {
          detail = body['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }
  }

  /// AUTH-3 (2026-06-01): Google ID token'ını backend'e gönderir, JWT alır+saklar.
  Future<String> googleLogin(String idToken) async {
    final uri = Uri.parse('$baseUrl/users/auth/google');
    late final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_token': idToken}),
      );
    } catch (e) {
      debugPrint('[Auth] Google network hatası: $e');
      throw Exception('Sunucuya bağlanılamadı.');
    }
    if (response.statusCode == 200) {
      final token = (json.decode(response.body))['access_token'] as String;
      await storageService.saveToken(token);
      return token;
    }
    String detail = 'Google girişi başarısız.';
    try {
      final body = json.decode(response.body);
      if (body is Map && body['detail'] != null) detail = body['detail'].toString();
    } catch (_) {}
    throw Exception(detail);
  }

  Future<void> register(String email, String password, {String? fullName}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/register'),
      headers: await getHeaders(token: null),
      body: json.encode({
        'email': email,
        'password': password,
        // AUTH-1: ad soyad (opsiyonel)
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      }),
    );
    if (response.statusCode != 201) {
      final errorJson = json.decode(response.body);
      // 422 (validasyon) → detail bir liste olabilir; string'e indir.
      final dynamic d = errorJson is Map ? errorJson['detail'] : null;
      String detail;
      if (d is String) {
        detail = d;
      } else if (d is List && d.isNotEmpty) {
        detail = (d.first is Map && d.first['msg'] != null)
            ? d.first['msg'].toString()
            : d.first.toString();
      } else {
        detail = 'Kayıt başarısız.';
      }
      throw Exception(detail);
    }
  }

  /// Token'ın hâlâ geçerli olup olmadığını /users/me endpoint'i ile doğrular.
  /// 200 → true, diğer tüm durumlar (401, network hatası vb.) → false.
  Future<bool> validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// HESABIM (2026-06-02): Geçerli kullanıcının profil bilgilerini getirir
  /// (id, email, full_name, is_active, created_at).
  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: await getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Profil bilgisi alınamadı (${response.statusCode}).');
  }

  /// HESABIM: ad-soyad günceller (PATCH /users/me). Güncellenmiş profili döndürür.
  Future<Map<String, dynamic>> updateProfile({String? fullName}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: await getHeaders(),
      body: json.encode({'full_name': fullName}),
    );
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception(_extractDetail(response, 'Profil güncellenemedi.'));
  }

  /// HESABIM (2026-06-03): OAuth kullanıcısı için İLK parola belirleme
  /// (mevcut parola istemez). POST /users/me/set-password.
  Future<void> setPassword(String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/me/set-password'),
      headers: await getHeaders(),
      body: json.encode({'new_password': newPassword}),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_extractDetail(response, 'Parola belirlenemedi.'));
    }
  }

  /// HESABIM: parola değiştirir. Başarı → 204. Hata → backend detail mesajı.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/me/change-password'),
      headers: await getHeaders(),
      body: json.encode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_extractDetail(response, 'Parola değiştirilemedi.'));
    }
  }

  /// FastAPI hata gövdesinden ({"detail": ...}) okunabilir mesaj çıkarır.
  /// detail bir liste (422 validasyon) ise ilk msg alınır.
  String _extractDetail(http.Response response, String fallback) {
    try {
      final body = json.decode(utf8.decode(response.bodyBytes));
      final dynamic d = body is Map ? body['detail'] : null;
      if (d is String) return d;
      if (d is List && d.isNotEmpty) {
        return (d.first is Map && d.first['msg'] != null)
            ? d.first['msg'].toString()
            : d.first.toString();
      }
    } catch (_) {}
    return fallback;
  }
}

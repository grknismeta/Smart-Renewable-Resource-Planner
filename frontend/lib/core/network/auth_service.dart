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

  Future<void> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/register'),
      headers: await getHeaders(token: null),
      body: json.encode({'email': email, 'password': password}),
    );
    if (response.statusCode != 201) {
      final errorJson = json.decode(response.body);
      String detail = errorJson['detail'] ?? 'Kayıt başarısız.';
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
}

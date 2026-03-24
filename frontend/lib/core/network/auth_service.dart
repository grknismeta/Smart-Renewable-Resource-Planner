import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';

class AuthService extends BaseService {
  AuthService(super.storageService);

  Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final token = jsonResponse['access_token'] as String;
      await storageService.saveToken(token);
      return token;
    } else {
      throw Exception('Giriş başarısız. Hatalı e-posta veya parola.');
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

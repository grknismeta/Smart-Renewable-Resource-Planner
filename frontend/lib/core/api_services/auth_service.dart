import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_service.dart';

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
}

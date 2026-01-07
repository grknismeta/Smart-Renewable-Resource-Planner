import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../secure_storage_service.dart';

class BaseService {
  final SecureStorageService storageService;

  BaseService(this.storageService);

  String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  Future<Map<String, String>> getHeaders({String? token}) async {
    final t = token ?? await storageService.readToken();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  // Common response handling
  dynamic processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return null;
    } else {
      debugPrint('API Error: ${response.statusCode} - ${response.body}');
       // Throw specific exceptions based on status code if needed
      if (response.statusCode == 401) {
        throw Exception('Yetki hatası. Lütfen tekrar giriş yapın.');
      }
      throw Exception('API isteği başarısız: ${response.statusCode}');
    }
  }
}

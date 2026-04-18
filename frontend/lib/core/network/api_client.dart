import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/storage/secure_storage.dart';

class BaseService {
  final SecureStorageService storageService;

  BaseService(this.storageService);

  /// Web ortamında tarayıcının bağlandığı hostname'i döndürür.
  /// Telefon 192.168.x.x üzerinden erişiyorsa o IP'yi kullanır.
  /// PC localhost ise 127.0.0.1 döner.
  static String get webApiBase {
    if (kIsWeb) {
      try {
        final host = Uri.base.host; // window.location.hostname
        if (host.isNotEmpty) return 'http://$host:8000';
      } catch (_) {}
    }
    return 'http://127.0.0.1:8000';
  }

  String get baseUrl {
    if (kIsWeb) {
      return webApiBase;
    } else if (Platform.isAndroid) {
      // LAN üzerinden PC'ye erişim (backend 0.0.0.0:8000'de dinliyor)
      // Not: PC IP değişirse burayı güncelle veya .env ile yapılandır
      return 'http://192.168.1.7:8000';
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
      // FastAPI'nin {"detail": "..."} mesajını kullanıcıya göster
      if (response.body.isNotEmpty) {
        try {
          final body = json.decode(utf8.decode(response.bodyBytes));
          if (body is Map && body['detail'] != null) {
            throw Exception('${body['detail']}');
          }
        } catch (e) {
          if (e is Exception) rethrow;
        }
      }
      throw Exception('API isteği başarısız: ${response.statusCode}');
    }
  }
}

// lib/core/storage/secure_storage.dart
//
// Katmanlı token saklama:
//   1. flutter_secure_storage → Windows Credential Manager / iOS Keychain / Android Keystore
//   2. SharedPreferences fallback → SecureStorage hata verirse (özellikle Windows desktop)
//
// Her iki katman da write/delete sırasında güncellenir.
// read() önce SecureStorage, başarısız olursa SharedPreferences'ı dener.

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _tokenKey = 'srrp_auth_token';

  // Windows'ta backward compat kapalı tutulur (varsayılan zaten false).
  static const _secure = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    lOptions: LinuxOptions(),
  );

  /// Token'ı hem SecureStorage hem de SharedPreferences'a yaz.
  Future<void> saveToken(String token) async {
    // SharedPreferences'a her zaman yaz (güvenilir fallback)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      debugPrint('[Storage] SharedPreferences write error: $e');
    }

    // SecureStorage'a da yazmayı dene (mobil/web için)
    try {
      await _secure.write(key: _tokenKey, value: token);
    } catch (e) {
      debugPrint('[Storage] SecureStorage write error (ignored, SP fallback active): $e');
    }
  }

  /// Token'ı oku — önce SecureStorage, başarısız olursa SharedPreferences.
  Future<String?> readToken() async {
    // 1. SecureStorage dene
    try {
      final token = await _secure.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('[Storage] SecureStorage read error, falling back to SharedPreferences: $e');
    }

    // 2. SharedPreferences fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('[Storage] SharedPreferences read error: $e');
    }

    return null;
  }

  /// Her iki depolamadan da token'ı sil.
  Future<void> deleteToken() async {
    try {
      await _secure.delete(key: _tokenKey);
    } catch (e) {
      debugPrint('[Storage] SecureStorage delete error: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (e) {
      debugPrint('[Storage] SharedPreferences delete error: $e');
    }
  }
}

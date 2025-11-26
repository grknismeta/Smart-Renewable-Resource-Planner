// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/secure_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final SecureStorageService _storageService;

  // Giriş durumunu tutar (null: loading, true: logged in, false: logged out)
  bool? _isLoggedIn;

  bool? get isLoggedIn => _isLoggedIn;

  AuthProvider(this._apiService, this._storageService) {
    _checkLoginStatus(); // Uygulama başladığında durumu kontrol et
  }

  // Güvenli depolamadan token'ı okuyarak giriş durumunu kontrol eder
  Future<void> _checkLoginStatus() async {
    try {
      final token = await _storageService.readToken();
      _isLoggedIn = token != null;
    } catch (e) {
      _isLoggedIn = false;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      await _apiService.login(email, password);
      _isLoggedIn = true;
      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      notifyListeners();
      rethrow; // Hatayı UI'a ilet
    }
  }

  Future<void> register(String email, String password) async {
    // YENİ EKLENDİ: API'ye gitmeden önce son güvenlik ağı
    if (password.length > 72) {
      throw Exception('Parola en fazla 72 karakter olabilir.');
    }

    try {
      await _apiService.register(email, password);
    } catch (e) {
      rethrow; // Hatayı UI'a ilet
    }
  }

  Future<void> logout() async {
    await _storageService.deleteToken();
    _isLoggedIn = false;
    notifyListeners();
  }
}

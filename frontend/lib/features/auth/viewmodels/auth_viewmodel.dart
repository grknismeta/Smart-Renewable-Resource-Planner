import 'package:flutter/foundation.dart' show debugPrint;
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/base/base_view_model.dart';

class AuthViewModel extends BaseViewModel {
  final ApiService _apiService;
  final SecureStorageService _storageService;

  /// null  → henüz kontrol edilmedi (splash göster)
  /// true  → giriş yapılmış
  /// false → giriş yapılmamış
  bool? _isLoggedIn;

  bool? get isLoggedIn => _isLoggedIn;

  AuthViewModel(this._apiService, this._storageService) {
    _checkLoginStatus();
  }

  // ── Başlangıç token kontrolü ────────────────────────────────────────────────
  //
  // 1. setBusy(true) → SplashScreen spinner gösterir
  // 2. Token storage'dan okunur
  // 3. Token varsa backend /users/me ile doğrulanır
  // 4. Token yoksa veya geçersizse temizlenir
  Future<void> _checkLoginStatus() async {
    setBusy(true);
    try {
      final token = await _storageService.readToken();
      if (token == null) {
        _isLoggedIn = false;
      } else {
        // Token var — backend'e karşı doğrula (süresi dolmuş mu?)
        final valid = await _apiService.auth.validateToken(token);
        if (valid) {
          _isLoggedIn = true;
        } else {
          debugPrint('[Auth] Token geçersiz/süresi dolmuş, siliniyor.');
          await _storageService.deleteToken();
          _isLoggedIn = false;
        }
      }
    } catch (e) {
      debugPrint('[Auth] Giriş durumu kontrol hatası: $e');
      _isLoggedIn = false;
    } finally {
      setBusy(false); // notifyListeners içeride çağrılır
    }
  }

  // ── Giriş ──────────────────────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    setBusy(true);
    try {
      await _apiService.auth.login(email, password);
      _isLoggedIn = true;
      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      setError(e.toString());
      notifyListeners();
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  // ── Kayıt ──────────────────────────────────────────────────────────────────
  Future<void> register(String email, String password) async {
    if (password.length > 72) {
      setError('Parola en fazla 72 karakter olabilir.');
      throw Exception('Parola en fazla 72 karakter olabilir.');
    }
    setBusy(true);
    try {
      await _apiService.auth.register(email, password);
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  // ── Çıkış ──────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    setBusy(true);
    await _storageService.deleteToken();
    _isLoggedIn = false;
    setBusy(false);
  }
}

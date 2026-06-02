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

  // ── HESABIM (2026-06-02): mevcut kullanıcı profili ──────────────────────────
  String? _email;
  String? _fullName;
  bool _hasPassword = true; // 2026-06-03: OAuth kullanıcısı false → "Şifre Belirle"
  String? get email => _email;
  String? get fullName => _fullName;
  bool get hasPassword => _hasPassword;
  /// Görüntülenecek ad: full_name varsa o, yoksa e-postanın @ öncesi.
  String get displayName {
    if (_fullName != null && _fullName!.trim().isNotEmpty) return _fullName!.trim();
    final e = _email ?? '';
    final at = e.indexOf('@');
    return at > 0 ? e.substring(0, at) : (e.isEmpty ? 'Kullanıcı' : e);
  }

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

  // ── Google ile giriş (AUTH-3) ───────────────────────────────────────────────
  Future<void> googleLogin(String idToken) async {
    setBusy(true);
    try {
      await _apiService.auth.googleLogin(idToken);
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
  Future<void> register(String email, String password, {String? fullName}) async {
    if (password.length < 8) {
      setError('Parola en az 8 karakter olmalı.');
      throw Exception('Parola en az 8 karakter olmalı.');
    }
    if (password.length > 72) {
      setError('Parola en fazla 72 karakter olabilir.');
      throw Exception('Parola en fazla 72 karakter olabilir.');
    }
    setBusy(true);
    try {
      await _apiService.auth.register(email, password, fullName: fullName);
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  // ── HESABIM (2026-06-02) ────────────────────────────────────────────────────

  /// Backend /users/me'den profil bilgilerini çeker ve state'e yazar.
  Future<void> fetchMe() async {
    try {
      final me = await _apiService.auth.getMe();
      _email = me['email'] as String?;
      _fullName = me['full_name'] as String?;
      _hasPassword = (me['has_password'] as bool?) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] fetchMe hatası: $e');
    }
  }

  /// OAuth kullanıcısı için ilk parola belirleme (mevcut parola istenmez).
  Future<void> setPassword(String newPassword) async {
    if (newPassword.length < 8) {
      setError('Parola en az 8 karakter olmalı.');
      throw Exception('Parola en az 8 karakter olmalı.');
    }
    setBusy(true);
    try {
      await _apiService.auth.setPassword(newPassword);
      _hasPassword = true; // artık parolası var
      notifyListeners();
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  /// Ad-soyad günceller (PATCH /users/me).
  Future<void> updateName(String? fullName) async {
    setBusy(true);
    try {
      final me = await _apiService.auth.updateProfile(fullName: fullName);
      _email = me['email'] as String?;
      _fullName = me['full_name'] as String?;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  /// Parola değiştirir. Min-8 ön kontrolü + backend doğrulaması.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (newPassword.length < 8) {
      setError('Yeni parola en az 8 karakter olmalı.');
      throw Exception('Yeni parola en az 8 karakter olmalı.');
    }
    setBusy(true);
    try {
      await _apiService.auth.changePassword(currentPassword, newPassword);
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setBusy(false);
    }
  }

  // ── Çıkış ──────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _storageService.deleteToken();
    _isLoggedIn = false;
    _email = null;
    _fullName = null;
    notifyListeners();
  }
}

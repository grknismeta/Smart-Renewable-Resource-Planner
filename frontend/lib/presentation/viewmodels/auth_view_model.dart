import '../../core/api_service.dart';
import '../../core/secure_storage_service.dart';
import '../../core/base/base_view_model.dart';

class AuthViewModel extends BaseViewModel {
  final ApiService _apiService;
  final SecureStorageService _storageService;

  // Giriş durumunu tutar (null: loading, true: logged in, false: logged out)
  bool? _isLoggedIn;

  bool? get isLoggedIn => _isLoggedIn;

  AuthViewModel(this._apiService, this._storageService) {
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
    setBusy(true);
    try {
      await _apiService.login(email, password);
      _isLoggedIn = true;
      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      setError(e.toString());
      notifyListeners();
      rethrow; // Hatayı UI'a ilet
    } finally {
      setBusy(false);
    }
  }

  Future<void> register(String email, String password) async {
    // YENİ EKLENDİ: API'ye gitmeden önce son güvenlik ağı
    if (password.length > 72) {
      setError('Parola en fazla 72 karakter olabilir.');
      throw Exception('Parola en fazla 72 karakter olabilir.');
    }

    setBusy(true);
    try {
      await _apiService.register(email, password);
    } catch (e) {
      setError(e.toString());
      rethrow; // Hatayı UI'a ilet
    } finally {
      setBusy(false);
    }
  }

  Future<void> logout() async {
    setBusy(true);
    await _storageService.deleteToken();
    _isLoggedIn = false;
    setBusy(false);
  }
}

// lib/core/config/backend_config.dart
//
// Backend URL'sini yönetir.
// - Web: tarayıcı hostname'i kullanılır (sunucu + frontend aynı host).
// - Android / iOS / Desktop: SharedPreferences'ten override okunur,
//   yoksa derleme zamanı varsayılanı (AppConstants.defaultMobileBackendUrl).
//
// Mobilde PC IP'si LAN'da değişebileceği için kullanıcı Ayarlar dialoğundan
// URL'yi girebilir; değer kalıcıdır ve tüm `BaseService.baseUrl` çağrıları
// bu cache'i okur.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackendConfig {
  BackendConfig._();
  static final BackendConfig instance = BackendConfig._();

  static const String _kPrefKey = 'srrp_backend_url';

  /// Android/iOS/desktop için varsayılan.
  ///
  /// 2026-05-20: `localhost`'a çevrildi. Geliştirme akışı `adb reverse
  /// tcp:8000 tcp:8000` (USB tüneli) — telefon localhost:8000'i PC'ye
  /// yönlendirir. LAN IP (192.168.x.x) DHCP'de değişir + adb tüneli LAN
  /// IP'sini taşımaz; localhost IP değişiminden bağımsız ve daha sağlam.
  /// LAN üzerinden bağlanmak istenirse Ayarlar → Veri Kaynağı'ndan
  /// `http://<PC-IP>:8000` girilir.
  static const String defaultMobileBackendUrl = 'http://localhost:8000';

  /// Web fallback (Uri.base.host kullanılamadığı durumlar için).
  static const String defaultWebBackendUrl = 'http://127.0.0.1:8000';

  /// Hafıza cache — her servis çağrısında disk I/O olmasın diye.
  /// null = henüz okunmadı.
  String? _cachedUrl;

  /// Uygulama başlatılırken çağrılır. SharedPreferences'ten değer okur.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kPrefKey);
      if (stored != null && stored.trim().isNotEmpty) {
        _cachedUrl = _normalize(stored);
      }
    } catch (e) {
      debugPrint('[BackendConfig.init] $e');
    }
  }

  /// Senkron okuma — `BaseService.baseUrl` getter'ı tarafından kullanılır.
  /// Eğer init çağrılmadıysa varsayılana düşer.
  String get mobileUrl => _cachedUrl ?? defaultMobileBackendUrl;

  /// Kullanıcının override edip etmediği (UI'da farklı renk göstermek için).
  bool get hasOverride => _cachedUrl != null;

  /// Yeni URL'yi kaydet + cache'i güncelle.
  /// Format: `http(s)://host:port` — son '/' temizlenir.
  Future<void> setMobileUrl(String url) async {
    final normalized = _normalize(url);
    _cachedUrl = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefKey, normalized);
    } catch (e) {
      debugPrint('[BackendConfig.setMobileUrl] $e');
    }
  }

  /// Override'ı temizler → varsayılana döner.
  Future<void> reset() async {
    _cachedUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefKey);
    } catch (e) {
      debugPrint('[BackendConfig.reset] $e');
    }
  }

  /// Trailing slash temizler, scheme yoksa http:// ekler.
  String _normalize(String url) {
    var s = url.trim();
    if (s.isEmpty) return defaultMobileBackendUrl;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}

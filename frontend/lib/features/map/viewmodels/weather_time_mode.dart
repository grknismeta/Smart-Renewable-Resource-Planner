import 'package:flutter/foundation.dart';

/// Tematik harita katmanlarının zaman penceresi modu.
///
/// Tüm hava-türevi katmanlar (ilçe choropleth, wind partikülleri, animasyon,
/// summary endpoint'leri) bu tek global state'ten beslenir. Kullanıcı paneldeki
/// seçiciyi değiştirdiğinde tüm katmanlar aynı pencereye uyum sağlar.
///
/// 8 değer var → tek vokabüler:
/// - [current]    : son 1 saat (anlık snapshot)
/// - [week]       : son 7 gün (varsayılan; eski hours=168 ile birebir)
/// - [month]      : son 30 gün
/// - [threeMonth] : son 90 gün
/// - [sixMonth]   : son 180 gün
/// - [yearly]     : son 365 gün (iklimsel)
/// - [season]     : son 365 gün + mevsim ay filtresi
/// - [custom]     : sadece animasyon için manuel start/end
enum WeatherTimeWindow {
  current,
  week,
  month,
  threeMonth,
  sixMonth,
  yearly,
  season,
  custom,
}

/// Meteorolojik mevsim (WMO tanımı).
enum WeatherSeason { winter, spring, summer, autumn }

extension WeatherSeasonX on WeatherSeason {
  /// Backend query parametresi değeri — küçük İngilizce isim.
  String get apiValue {
    switch (this) {
      case WeatherSeason.winter:
        return 'winter';
      case WeatherSeason.spring:
        return 'spring';
      case WeatherSeason.summer:
        return 'summer';
      case WeatherSeason.autumn:
        return 'autumn';
    }
  }

  /// UI'da gösterilecek Türkçe ad.
  String get displayName {
    switch (this) {
      case WeatherSeason.winter:
        return 'Kış';
      case WeatherSeason.spring:
        return 'İlkbahar';
      case WeatherSeason.summer:
        return 'Yaz';
      case WeatherSeason.autumn:
        return 'Sonbahar';
    }
  }
}

extension WeatherTimeWindowX on WeatherTimeWindow {
  /// Backend query param değeri.
  /// custom: backend'e gönderilmez (manuel start/end alır).
  String get apiValue {
    switch (this) {
      case WeatherTimeWindow.current:
        return 'current';
      case WeatherTimeWindow.week:
        return 'week';
      case WeatherTimeWindow.month:
        return 'month';
      case WeatherTimeWindow.threeMonth:
        return 'threeMonth';
      case WeatherTimeWindow.sixMonth:
        return 'sixMonth';
      case WeatherTimeWindow.yearly:
        return 'yearly';
      case WeatherTimeWindow.season:
        return 'season';
      case WeatherTimeWindow.custom:
        return 'custom';
    }
  }

  /// Dropdown / chip etiketi.
  String get displayName {
    switch (this) {
      case WeatherTimeWindow.current:
        return 'Anlık';
      case WeatherTimeWindow.week:
        return 'Hafta';
      case WeatherTimeWindow.month:
        return 'Ay';
      case WeatherTimeWindow.threeMonth:
        return '3 Ay';
      case WeatherTimeWindow.sixMonth:
        return '6 Ay';
      case WeatherTimeWindow.yearly:
        return 'Yıllık';
      case WeatherTimeWindow.season:
        return 'Mevsim';
      case WeatherTimeWindow.custom:
        return 'Özel';
    }
  }

  /// Pencere uzunluğu — gün cinsinden.
  /// current: 0 (snapshot), custom: -1 (kullanıcı tanımlı).
  int get days {
    switch (this) {
      case WeatherTimeWindow.current:
        return 0;
      case WeatherTimeWindow.week:
        return 7;
      case WeatherTimeWindow.month:
        return 30;
      case WeatherTimeWindow.threeMonth:
        return 90;
      case WeatherTimeWindow.sixMonth:
        return 180;
      case WeatherTimeWindow.yearly:
      case WeatherTimeWindow.season:
        return 365;
      case WeatherTimeWindow.custom:
        return -1;
    }
  }

  /// Tematik panel dropdown'unda gösterilecek modlar (custom ayrı).
  bool get showInThematicPanel => this != WeatherTimeWindow.custom;
}

/// Tematik katman zaman modu — global Provider.
///
/// Değişiklik her olduğunda `notifyListeners()` → dinleyen katmanlar kendi
/// fetcher'larını yeniden tetikler. `MapViewModel.setWeatherTimeMode()` çoklu
/// fetcher'ı invalidate eder (choropleth + wind + summary + animation).
class WeatherTimeModeProvider extends ChangeNotifier {
  // Varsayılan: hafta. Mevcut hours=168 davranışıyla 1:1 uyuşur, kullanıcı
  // alışkanlığı bozulmaz.
  WeatherTimeWindow _window = WeatherTimeWindow.week;
  WeatherSeason? _season;

  WeatherTimeWindow get window => _window;
  WeatherSeason? get season => _season;

  /// Backend query param'ı — `custom` için null döner (caller manuel handle).
  String? get apiMode {
    if (_window == WeatherTimeWindow.custom) return null;
    return _window.apiValue;
  }

  /// Season moduysa 'winter'... değilse null.
  String? get apiSeason =>
      _window == WeatherTimeWindow.season ? _season?.apiValue : null;

  /// UI için kısa etiket (ör. "Anlık", "3 Ay", "Kış").
  String get displayLabel {
    if (_window == WeatherTimeWindow.season) {
      return _season?.displayName ?? 'Mevsim';
    }
    return _window.displayName;
  }

  void setWindow(WeatherTimeWindow w) {
    if (_window == w) return;
    _window = w;
    if (w != WeatherTimeWindow.season) {
      _season = null;
    } else {
      _season ??= WeatherSeason.summer;
    }
    notifyListeners();
  }

  void setSeason(WeatherSeason s) {
    if (_season == s && _window == WeatherTimeWindow.season) return;
    _season = s;
    _window = WeatherTimeWindow.season;
    notifyListeners();
  }
}

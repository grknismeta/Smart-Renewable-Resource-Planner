import 'package:flutter/material.dart';

/// Harita için sabit değerler ve renkler
class MapConstants {
  MapConstants._();

  // --- TILE URL'leri ---
  static const String arcGisSatelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const String arcGisDarkUrl =
      'https://services.arcgisonline.com/arcgis/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  static const String arcGisStreetUrl =
      'https://services.arcgisonline.com/arcgis/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';

  // --- RÜZGAR TEMA RENKLERİ (Florasan Turkuaz) ---
  static const Color windBgColor = Color(0xFF006064); // Koyu Gece Turkuazı
  static const Color windFgColor = Color(0xFF18FFFF); // Neon Cam Göbeği

  // --- GÜNEŞ TEMA RENKLERİ (Sıcak Kehribar) ---
  static const Color solarBgColor = Color.fromARGB(255, 0, 0, 0); // Koyu Kor Turuncu
  static const Color solarFgColor = Color.fromARGB(197, 255, 188, 30); // Parlak Kehribar (Amber)

  // --- HES TEMA RENKLERİ (Elektrik Yeşili) ---
  static const Color hesBgColor = Color(0xFF1B5E20); // Yosun/Orman Yeşili
  static const Color hesFgColor = Color(0xFF00E676); // Parlak Neon Zümrüt Yeşili

  // --- HARİTA SINIRLARI (TÜRKİYE) ---
  static const double turkeyMinLat = 34.0;
  static const double turkeyMaxLat = 44.0;
  static const double turkeyMinLon = 24.0;
  static const double turkeyMaxLon = 46.0;
  static const double turkeyCenterLat = 39.0;
  static const double turkeyCenterLon = 35.5;

  // --- VARSAYILAN ZOOM ---
  static const double initialZoom = 6.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.0;
  static const double maxNativeZoom = 12.0; // Tiles beyond this will be scaled

  /// Verilen tip için arka plan rengini döndürür
  static Color getBackgroundColor(String type) {
    if (type == 'Güneş Paneli') return solarBgColor;
    if (type == 'HES' || type == 'Hidroelektrik') return hesBgColor;
    return windBgColor;
  }

  /// Verilen tip için ön plan rengini döndürür
  static Color getForegroundColor(String type) {
    if (type == 'Güneş Paneli') return solarFgColor;
    if (type == 'HES' || type == 'Hidroelektrik') return hesFgColor;
    return windFgColor;
  }

  /// Verilen tip için ikonu döndürür
  static IconData getIcon(String type) {
    if (type == 'Güneş Paneli') return Icons.wb_sunny;
    if (type == 'HES' || type == 'Hidroelektrik') return Icons.water_drop;
    return Icons.wind_power;
  }

  /// Harita stili için URL döndürür
  static String getTileUrl(String style) {
    switch (style) {
      case 'satellite':
        return arcGisSatelliteUrl;
      case 'street':
        return arcGisStreetUrl;
      default:
        return arcGisDarkUrl;
    }
  }
}

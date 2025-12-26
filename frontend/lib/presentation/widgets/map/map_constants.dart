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

  // --- RÜZGAR TEMA RENKLERİ (Mavi) ---
  static const Color windBgColor = Color(0xFF1F3A58);
  static const Color windFgColor = Color(0xFF2196F3);

  // --- GÜNEŞ TEMA RENKLERİ (Sarı) ---
  static const Color solarBgColor = Color(0xFF413819);
  static const Color solarFgColor = Color(0xFFFFCA28);

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

  /// Verilen tip için arka plan rengini döndürür
  static Color getBackgroundColor(String type) {
    return type == 'Güneş Paneli' ? solarBgColor : windBgColor;
  }

  /// Verilen tip için ön plan rengini döndürür
  static Color getForegroundColor(String type) {
    return type == 'Güneş Paneli' ? solarFgColor : windFgColor;
  }

  /// Verilen tip için ikonu döndürür
  static IconData getIcon(String type) {
    return type == 'Güneş Paneli' ? Icons.wb_sunny : Icons.wind_power;
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

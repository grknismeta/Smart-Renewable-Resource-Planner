/// Uygulama genelinde kullanılan sabit değerler
class AppConstants {
  AppConstants._();

  // --- UYGULAMA BİLGİLERİ ---
  static const String appName = 'SRRP';
  static const String appFullName = 'Smart Renewable Resource Planner';
  static const String appVersion = '1.0.0';

  // --- API URL'LERİ ---
  // Not: Gerçek API URL'leri api_service.dart içinde platform bazlı belirleniyor
  static const String defaultApiPort = '8000';

  // --- ANİMASYON SÜRELERİ ---
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // --- UI BOYUTLARI ---
  static const double sidebarWidth = 300.0;
  static const double sidebarCollapsedWidth = 70.0;
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;

  // --- BORDER RADIUS ---
  static const double smallRadius = 8.0;
  static const double mediumRadius = 12.0;
  static const double largeRadius = 16.0;
  static const double roundedRadius = 30.0;

  // --- SPACING ---
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
}

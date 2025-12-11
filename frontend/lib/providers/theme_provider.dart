import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // Varsayılan olarak Dark Mode başlasın

  bool get isDarkMode => _isDarkMode;

  // Tema değiştirme fonksiyonu
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // --- RENK PALETİ ---
  
  // Arkaplan Rengi
  Color get backgroundColor => _isDarkMode ? const Color(0xFF1E232F) : const Color(0xFFF5F5F5);
  
  // Kart/Panel Rengi
  Color get cardColor => _isDarkMode ? const Color(0xFF2A3040) : Colors.white;
  
  // Metin Rengi
  Color get textColor => _isDarkMode ? Colors.white : const Color(0xFF333333);
  
  // İkincil Metin Rengi
  Color get secondaryTextColor => _isDarkMode ? Colors.white70 : const Color(0xFF666666);

  // Harita Stili (Mapbox URL ID'si)
  String get mapStyleId => _isDarkMode ? 'mapbox/dark-v10' : 'mapbox/streets-v11';
  
  // Harita Arkaplan Rengi (Yüklenirken gözüken renk)
  Color get mapBackgroundColor => _isDarkMode ? const Color(0xFF191A1A) : const Color(0xFFEFEFEF);
}
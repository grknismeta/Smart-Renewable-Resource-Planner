// presentation/features/map/viewmodels/map_screen_viewmodel.dart
//
// Sorumluluk: Map screen için helper logic
// Color calculations, formatters, etc.

import 'package:flutter/material.dart';

/// Map screen için helper ViewModel
class MapScreenViewModel {
  MapScreenViewModel._();

  /// Temperature color mapping
  static Color getTemperatureColor(double temp) {
    if (temp < 0) return Colors.blue.shade900;
    if (temp < 10) return Colors.blue.shade400;
    if (temp < 20) return Colors.green;
    if (temp < 30) return Colors.orange;
    return Colors.red;
  }

  /// Wind speed color mapping
  static Color getWindColor(double speed) {
    if (speed < 3) return Colors.green.shade300;
    if (speed < 6) return Colors.green;
    if (speed < 10) return Colors.yellow;
    if (speed < 15) return Colors.orange;
    return Colors.red;
  }

  /// Date formatter (DD/MM)
  static String formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  /// Datetime formatter with relative time
  static String formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);

    String prefix;
    if (diff.inHours.abs() < 1) {
      prefix = 'Şimdi';
    } else if (diff.isNegative) {
      prefix = '${diff.inHours.abs()} saat önce';
    } else {
      prefix = '${diff.inHours} saat sonra';
    }

    return '$prefix - ${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:00';
  }
}

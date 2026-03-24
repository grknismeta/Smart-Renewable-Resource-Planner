import 'package:flutter/material.dart';

// ─── MapLibre — Isı Haritası Modu ────────────────────────────────────────────

enum MlHeatmapMode { none, solar, wind, temperature }

// ─── MapLibre 3D — Isı Haritası Palet ────────────────────────────────────────

enum HeatmapPalette { classic, thermal, viridis }

extension HeatmapPaletteExt on HeatmapPalette {
  String get displayName {
    switch (this) {
      case HeatmapPalette.classic: return 'Klasik';
      case HeatmapPalette.thermal: return 'Termal';
      case HeatmapPalette.viridis: return 'Viridis';
    }
  }

  IconData get icon {
    switch (this) {
      case HeatmapPalette.classic: return Icons.gradient_rounded;
      case HeatmapPalette.thermal: return Icons.thermostat_rounded;
      case HeatmapPalette.viridis: return Icons.science_outlined;
    }
  }
}

// ─── MapLibre 3D — Temel Harita Stilleri ─────────────────────────────────────

enum MlBaseStyle { darkMatter, positron, voyager, liberty }

extension MlBaseStyleExt on MlBaseStyle {
  String get styleUrl {
    switch (this) {
      case MlBaseStyle.darkMatter:
        return 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';
      case MlBaseStyle.positron:
        return 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';
      case MlBaseStyle.voyager:
        return 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';
      case MlBaseStyle.liberty:
        return 'https://tiles.openfreemap.org/styles/liberty';
    }
  }

  String get displayName {
    switch (this) {
      case MlBaseStyle.darkMatter: return 'Koyu (Dark Matter)';
      case MlBaseStyle.positron:   return 'Açık (Positron)';
      case MlBaseStyle.voyager:    return 'Sokak (Voyager)';
      case MlBaseStyle.liberty:    return 'Detaylı (Liberty)';
    }
  }

  IconData get icon {
    switch (this) {
      case MlBaseStyle.darkMatter: return Icons.dark_mode_outlined;
      case MlBaseStyle.positron:   return Icons.light_mode_outlined;
      case MlBaseStyle.voyager:    return Icons.map_outlined;
      case MlBaseStyle.liberty:    return Icons.terrain_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Isı haritası için veri noktası
class HeatmapPoint {
  final double latitude;
  final double longitude;
  final double value; // Ham değer

  HeatmapPoint({
    required this.latitude,
    required this.longitude,
    required this.value,
  });
}

enum ResourceType { solar, wind, temp }

// ─── Rüzgar Parçacık Sistemi ────────────────────────────────────────────────

enum WindParticleQuality {
  light,    // 800 parçacık, 20fps, trail=6
  balanced, // 2000 parçacık, 30fps, trail=8
  heavy,    // 5000 parçacık, 60fps, trail=12
}

class WindVector {
  final String city;
  final double lat;
  final double lon;
  final double u;
  final double v;
  final double speed;

  WindVector({
    required this.city,
    required this.lat,
    required this.lon,
    required this.u,
    required this.v,
    required this.speed,
  });

  factory WindVector.fromJson(Map<String, dynamic> json) {
    return WindVector(
      city: json['city'] ?? '',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      u: (json['u'] as num).toDouble(),
      v: (json['v'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
    );
  }
}

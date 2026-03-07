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

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

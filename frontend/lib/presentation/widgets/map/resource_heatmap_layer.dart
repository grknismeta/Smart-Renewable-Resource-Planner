import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Isı haritası için veri noktası
class HeatmapPoint {
  final double latitude;
  final double longitude;
  final double value; // Ham değer (örn: 5.4 m/s veya 24°C)

  HeatmapPoint({
    required this.latitude,
    required this.longitude,
    required this.value,
  });
}

/// Kaynak türü (Güneş, Rüzgar, Sıcaklık)
enum ResourceType { solar, wind, temp }

/// Merkezi Isı Haritası Katmanı
class ResourceHeatmapLayer extends StatefulWidget {
  final List<HeatmapPoint> data;
  final ResourceType type;
  final double opacity;
  final double radius;

  const ResourceHeatmapLayer({
    super.key,
    required this.data,
    required this.type,
    this.opacity = 0.5,
    this.radius = 25.0,
  });

  @override
  State<ResourceHeatmapLayer> createState() => _ResourceHeatmapLayerState();
}

class _ResourceHeatmapLayerState extends State<ResourceHeatmapLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // Nefes alma efekti için controller
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // Yarıçap değişimi (Hafif büyüme/küçülme)
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    // Opaklık değişimi (Hafif parlayıp sönme)
    _opacityAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    // 1. Veri setinin min/max değerlerini bul
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (var point in widget.data) {
      if (point.value < minVal) minVal = point.value;
      if (point.value > maxVal) maxVal = point.value;
    }

    if (minVal == maxVal) {
      if (minVal == 0) {
        maxVal = 1.0;
      } else {
        minVal = maxVal * 0.9;
      }
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CircleLayer(
          circles: widget.data.map((point) {
            // 2. Değeri normalize et
            final normalized = _normalize(point.value, minVal, maxVal);

            // 3. Rengi al ve animasyonlu opaklığı uygula
            final baseColor = _getColor(normalized, widget.type);
            final animatedOpacity = (widget.opacity * _opacityAnimation.value)
                .clamp(0.0, 1.0);

            return CircleMarker(
              point: LatLng(point.latitude, point.longitude),
              radius:
                  widget.radius * _scaleAnimation.value, // Animasyonlu yarıçap
              color: baseColor.withOpacity(animatedOpacity),
              borderStrokeWidth: 0,
              useRadiusInMeter: false,
            );
          }).toList(),
        );
      },
    );
  }

  /// Değeri 0.0 ile 1.0 arasına oranlar
  double _normalize(double val, double min, double max) {
    return ((val - min) / (max - min)).clamp(0.0, 1.0);
  }

  /// Normalize edilmiş değere (0-1) ve türe göre renk döndürür
  Color _getColor(double t, ResourceType type) {
    switch (type) {
      case ResourceType.solar:
        return _getSolarGradient(t);
      case ResourceType.wind:
        return _getWindGradient(t);
      case ResourceType.temp:
        return _getTempGradient(t);
    }
  }

  // ☀️ GÜNEŞ: Siyah/KoyuKırmızı -> Turuncu -> Parlak Sarı
  Color _getSolarGradient(double t) {
    if (t < 0.3) {
      // Düşük: Siyah'tan Koyu Kırmızı'ya
      return Color.lerp(Colors.black87, Colors.red.shade900, t / 0.3)!;
    } else if (t < 0.6) {
      // Orta: Koyu Kırmızı'dan Turuncu'ya
      return Color.lerp(Colors.red.shade900, Colors.orange, (t - 0.3) / 0.3)!;
    } else {
      // Yüksek: Turuncu'dan Sarı'ya (Maksimum Parlaklık)
      return Color.lerp(Colors.orange, Colors.yellowAccent, (t - 0.6) / 0.4)!;
    }
  }

  // 💨 RÜZGAR: Gri/Beyaz -> Mavi -> Mor/Lacivert
  Color _getWindGradient(double t) {
    if (t < 0.3) {
      // Düşük: Gri (Durgun)
      return Color.lerp(Colors.grey.shade300, Colors.blue.shade200, t / 0.3)!;
    } else if (t < 0.7) {
      // Orta: Açık Mavi -> Normal Mavi
      return Color.lerp(
        Colors.blue.shade200,
        Colors.blue.shade700,
        (t - 0.3) / 0.4,
      )!;
    } else {
      // Yüksek: Koyu Mavi -> Mor/Lacivert (Fırtına)
      return Color.lerp(
        Colors.blue.shade800,
        Colors.deepPurple.shade900,
        (t - 0.7) / 0.3,
      )!;
    }
  }

  // 🌡️ SICAKLIK: Mavi -> Yeşil -> Kırmızı (Klasik Isı Haritası)
  Color _getTempGradient(double t) {
    if (t < 0.33) {
      // Soğuk: Koyu Mavi -> Açık Mavi
      return Color.lerp(Colors.indigo, Colors.cyan, t / 0.33)!;
    } else if (t < 0.66) {
      // Ilıman: Açık Mavi -> Yeşil -> Sarı
      return Color.lerp(Colors.cyan, Colors.yellow, (t - 0.33) / 0.33)!;
    } else {
      // Sıcak: Sarı -> Turuncu -> Kırmızı
      return Color.lerp(Colors.yellow, Colors.red.shade900, (t - 0.66) / 0.34)!;
    }
  }
}

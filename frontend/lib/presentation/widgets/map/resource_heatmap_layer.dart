import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

/// Backend'den gelen düzenli grid verisini "Boyanmış" bir katman olarak çizer.
class ResourceHeatmapLayer extends StatelessWidget {
  final List<HeatmapPoint> data;
  final ResourceType type;
  final double opacity;

  const ResourceHeatmapLayer({
    super.key,
    required this.data,
    required this.type,
    this.opacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    // Min/Max hesapla
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (var point in data) {
      if (point.value < minVal) minVal = point.value;
      if (point.value > maxVal) maxVal = point.value;
    }
    
    // Sıfır aralığı koruma
    if (minVal == maxVal) maxVal += 0.1;

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _HeatmapPainter(
              data: data,
              type: type,
              minVal: minVal,
              maxVal: maxVal,
              mapCamera: MapCamera.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<HeatmapPoint> data;
  final ResourceType type;
  final double minVal;
  final double maxVal;
  final MapCamera mapCamera;

  _HeatmapPainter({
    required this.data,
    required this.type,
    required this.minVal,
    required this.maxVal,
    required this.mapCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Grid çözünürlüğü (Derece) - Backend 0.1 gönderiyor
    // Bunu piksel cinsinden hesaplayıp her noktayı bir kare olarak çizeceğiz.
    // Yumuşak geçiş için "MaskFilter.blur" kullanacağız.

    final paint = Paint()
      ..style = PaintingStyle.fill;
      // maskFilter kaldırıldı: Performans sorununa yol açıyor (12k nokta için çok ağır)
      // Bunun yerine alpha blending (transparanlık) ile yumuşaklık sağlıyoruz.

    // Yaklaşık grid boyutu (piksel) hesapla
    // 0.1 derece enlem ~ 11km.
    // Zoom seviyesine göre bu kaç piksel?
    // Yaklaşık grid boyutu (piksel) hesapla
    // 0.1 derece enlem ~ 11km.
    // Zoom seviyesine göre bu kaç piksel?
    final p1 = mapCamera.getOffsetFromOrigin(const LatLng(38, 35));
    final p2 = mapCamera.getOffsetFromOrigin(const LatLng(38.1, 35.1));
    final pointSize = (p2.dx - p1.dx).abs() * 1.5; 
    
    // debugPrint('HeatmapPainter: pointSize=$pointSize, Zoom=${mapCamera.zoom}');

    int drawnCount = 0;
    for (var i = 0; i < data.length; i++) {
        final point = data[i];

      // Ekran dışındakileri çizme optimizasyon
      final offset = mapCamera.getOffsetFromOrigin(LatLng(point.latitude, point.longitude));
      
      // if (i < 3) debugPrint('Heatmap Point $i: $offset (Bounds: ${size.width}x${size.height})');
      
      // Çok uzaktakileri çizme
      if (offset.dx < -pointSize || offset.dx > size.width + pointSize || 
          offset.dy < -pointSize || offset.dy > size.height + pointSize) {
        continue;
      }

      final normalized = _normalize(point.value, minVal, maxVal);
      paint.color = _getColor(normalized, type);

      canvas.drawCircle(offset, pointSize, paint);
      drawnCount++;
    }
    // debugPrint('HeatmapPainter: Drawn $drawnCount / ${data.length} points');
  }

  double _normalize(double val, double min, double max) {
    return ((val - min) / (max - min)).clamp(0.0, 1.0);
  }

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

  Color _getSolarGradient(double t) {
    if (t < 0.3) return Color.lerp(Colors.red.shade900, Colors.orange.shade800, t/0.3)!;
    if (t < 0.6) return Color.lerp(Colors.orange.shade800, Colors.orangeAccent, (t-0.3)/0.3)!;
    return Color.lerp(Colors.orangeAccent, Colors.yellowAccent, (t-0.6)/0.4)!;
  }

  Color _getWindGradient(double t) {
    if (t < 0.3) return Color.lerp(Colors.white54, Colors.blue.shade200, t/0.3)!;
    if (t < 0.7) return Color.lerp(Colors.blue.shade200, Colors.blue.shade900, (t-0.3)/0.4)!;
    return Color.lerp(Colors.blue.shade900, Colors.deepPurple, (t-0.7)/0.3)!;
  }

  Color _getTempGradient(double t) {
    if (t < 0.33) return Color.lerp(Colors.blue, Colors.green, t/0.33)!;
    if (t < 0.66) return Color.lerp(Colors.green, Colors.yellow, (t-0.33)/0.33)!;
    return Color.lerp(Colors.yellow, Colors.red, (t-0.66)/0.34)!;
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.mapCamera.zoom != mapCamera.zoom || 
           oldDelegate.data != data ||
           oldDelegate.type != type;
  }
}

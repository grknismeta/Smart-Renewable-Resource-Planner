import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'map_constants.dart';
import '../models/map_models.dart';

/// Katman türleri tek bir enum altında toplandı
enum MapLayerType {
  none,
  wind,
  temp, // Temperature
  irradiance; // Solar

  /// API tarafındaki karşılıkları
  String? get apiName {
    switch (this) {
      case MapLayerType.wind:
        return "Wind";
      case MapLayerType.temp:
        return "Temperature";
      case MapLayerType.irradiance:
        return "Solar";
      case MapLayerType.none:
        return null;
    }
  }

  /// UI gösterim adları (İstenirse kullanılabilir)
  String get displayName {
    switch (this) {
      case MapLayerType.wind:
        return "Rüzgar";
      case MapLayerType.temp:
        return "Sıcaklık";
      case MapLayerType.irradiance:
        return "Güneş (Işınım)";
      case MapLayerType.none:
        return "Yok";
    }
  }
}

/// Tüm katman mantığını (logic + rendering) içeren ana widget.
/// Eski `ResourceHeatmapLayer` yerine kullanılır.
class MapLayerWidget extends StatefulWidget {
  final List<HeatmapPoint> data;
  final MapLayerType layerType;
  final double opacity;

  const MapLayerWidget({
    super.key,
    required this.data,
    required this.layerType,
    this.opacity = 0.5,
  });

  @override
  State<MapLayerWidget> createState() => _MapLayerWidgetState();
}

class _MapLayerWidgetState extends State<MapLayerWidget> {
  ui.Picture? _cachedPicture;
  LatLngBounds? _bounds;
  double _imgWidth = 0;
  double _imgHeight = 0;

  @override
  void initState() {
    super.initState();
    _generateLayerPicture();
  }

  @override
  void didUpdateWidget(covariant MapLayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data || widget.layerType != oldWidget.layerType) {
      _generateLayerPicture();
    }
  }

  void _generateLayerPicture() {
    if (widget.data.isEmpty || widget.layerType == MapLayerType.none) {
      _cachedPicture = null;
      return;
    }

    // 1. Veri sınırlarını (Bounding Box) bul
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLon = double.infinity;
    double maxLon = double.negativeInfinity;
    
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (var point in widget.data) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;

      if (point.value < minVal) minVal = point.value;
      if (point.value > maxVal) maxVal = point.value;
    }

    if (minLat == double.infinity) return;
    if (minVal == maxVal) maxVal += 0.1;

    // Grid çözünürlüğü (Backend 0.1 derece gönderiyor)
    const double resolution = 0.1;

    final lonDiff = maxLon - minLon;
    final latDiff = maxLat - minLat;
    
    _bounds = LatLngBounds(
      LatLng(minLat - resolution/2, minLon - resolution/2),
      LatLng(maxLat + resolution/2, maxLon + resolution/2),
    );

    _imgWidth = (lonDiff / resolution).ceil().toDouble() + 1;
    _imgHeight = (latDiff / resolution).ceil().toDouble() + 1;

    // 2. Picture Recorder ile çizim yap
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder); 
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (var point in widget.data) {
      // TÜRKİYE SINIRLARI KONTROLÜ
      if (point.latitude < MapConstants.turkeyMinLat || 
          point.latitude > MapConstants.turkeyMaxLat ||
          point.longitude < MapConstants.turkeyMinLon || 
          point.longitude > MapConstants.turkeyMaxLon) {
        continue;
      }

      final normalized = _normalize(point.value, minVal, maxVal);
      paint.color = _getColor(normalized, widget.layerType);

      // Grid koordinatını hesapla
      // Y ekseni aşağı doğru artar Canvas'ta. Haritada enlem yukarı doğru artar.
      final x = (point.longitude - minLon) / resolution; 
      final y = (maxLat - point.latitude) / resolution; 
      
      canvas.drawRect(
        Rect.fromLTWH(x, y, 1.0, 1.0), 
        paint
      );
    }
    
    _cachedPicture = recorder.endRecording();
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedPicture == null || _bounds == null) return const SizedBox.shrink();

    return Opacity(
      opacity: widget.opacity,
      child: Stack(
        children: [
          CustomPaint(
            painter: _CachedLayerPainter(
              picture: _cachedPicture!,
              bounds: _bounds!,
              imgWidth: _imgWidth,
              imgHeight: _imgHeight,
              mapCamera: MapCamera.of(context),
            ),
          ),
        ],
      ),
    );
  }

  double _normalize(double val, double min, double max) {
    return ((val - min) / (max - min)).clamp(0.0, 1.0);
  }

  Color _getColor(double t, MapLayerType type) {
    switch (type) {
      case MapLayerType.irradiance:
        return _getSolarGradient(t);
      case MapLayerType.wind:
        return _getWindGradient(t);
      case MapLayerType.temp:
        return _getTempGradient(t);
      case MapLayerType.none:
        return Colors.transparent;
    }
  }

  // --- Renk Paletleri ---
  
  Color _getSolarGradient(double t) {
    if (t < 0.3) return Color.lerp(Colors.red.shade900, Colors.orange.shade800, t/0.3)!;
    if (t < 0.6) return Color.lerp(Colors.orange.shade800, Colors.orangeAccent, (t-0.3)/0.3)!;
    return Color.lerp(Colors.orangeAccent, Colors.yellowAccent, (t-0.6)/0.4)!;
  }

  Color _getWindGradient(double t) {
    if (t < 0.3) return Color.lerp(Colors.grey.withAlpha(100), Colors.blue.shade300, t/0.3)!;
    if (t < 0.7) return Color.lerp(Colors.blue.shade300, Colors.blue.shade900, (t-0.3)/0.4)!;
    return Color.lerp(Colors.blue.shade900, Colors.deepPurpleAccent, (t-0.7)/0.3)!;
  }

  Color _getTempGradient(double t) {
    if (t < 0.33) return Color.lerp(Colors.blue, Colors.green, t/0.33)!;
    if (t < 0.66) return Color.lerp(Colors.green, Colors.yellow, (t-0.33)/0.33)!;
    return Color.lerp(Colors.yellow, Colors.red, (t-0.66)/0.34)!;
  }
}

/// Resmi haritaya ölçekleyerek çizen Painter
class _CachedLayerPainter extends CustomPainter {
  final ui.Picture picture;
  final LatLngBounds bounds;
  final double imgWidth;
  final double imgHeight;
  final MapCamera mapCamera;

  _CachedLayerPainter({
    required this.picture,
    required this.bounds,
    required this.imgWidth,
    required this.imgHeight,
    required this.mapCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final northWest = mapCamera.getOffsetFromOrigin(bounds.northWest);
    final southEast = mapCamera.getOffsetFromOrigin(bounds.southEast);

    final dstRect = Rect.fromLTRB(
      northWest.dx, 
      northWest.dy, 
      southEast.dx, 
      southEast.dy
    );

    canvas.save();
    canvas.translate(dstRect.left, dstRect.top);
    
    final scaleX = dstRect.width / imgWidth;
    final scaleY = dstRect.height / imgHeight;
    
    canvas.scale(scaleX, scaleY);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CachedLayerPainter oldDelegate) {
    return oldDelegate.mapCamera.zoom != mapCamera.zoom ||
           oldDelegate.mapCamera.center != mapCamera.center ||
           oldDelegate.picture != picture;
  }
}

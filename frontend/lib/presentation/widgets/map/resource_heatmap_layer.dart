import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'map_constants.dart';

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
/// Performans için "Cached Picture" yöntemini kullanır.
/// Veri değişmediği sürece (zoom/pan sırasında) resmi tekrar oluşturmaz, sadece ölçekler.
class ResourceHeatmapLayer extends StatefulWidget {
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
  State<ResourceHeatmapLayer> createState() => _ResourceHeatmapLayerState();
}

class _ResourceHeatmapLayerState extends State<ResourceHeatmapLayer> {
  ui.Picture? _cachedPicture;
  
  // Resmin kapsadığı coğrafi alan (Bounding Box)
  LatLngBounds? _bounds;
  
  // Resmin oluşturulduğu sanal boyutlar (Data Grid boyutları)
  // 0.1 derece çözünürlük için enlem/boylam farkından hesaplanır
  double _imgWidth = 0;
  double _imgHeight = 0;

  @override
  void initState() {
    super.initState();
    _generateHeatmapPicture();
  }

  @override
  void didUpdateWidget(covariant ResourceHeatmapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sadece veri veya tip değişirse resmi yeniden oluştur
    if (widget.data != oldWidget.data || widget.type != oldWidget.type) {
      _generateHeatmapPicture();
    }
  }

  void _generateHeatmapPicture() {
    if (widget.data.isEmpty) {
      _cachedPicture = null;
      return;
    }

    // 1. Veri sınırlarını (Bounding Box) bul
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLon = double.infinity;
    double maxLon = double.negativeInfinity;
    
    // Min/Max Value hesapla (Renk skalası için)
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

    // Tek nokta veya hatalı veri koruması
    if (minLat == double.infinity) return;
    if (minVal == maxVal) maxVal += 0.1;

    // Grid çözünürlüğü (Backend 0.1 derece gönderiyor)
    const double resolution = 0.1;

    // Resim boyutlarını hesapla (Her 0.1 derece 1 piksel/birim olsun)
    // Yatayda (Boylam farkı)
    final lonDiff = maxLon - minLon;
    final latDiff = maxLat - minLat;
    
    // Kenarlarda yarım birim boşluk bırak (0.05 deg)
    _bounds = LatLngBounds(
      LatLng(minLat - resolution/2, minLon - resolution/2),
      LatLng(maxLat + resolution/2, maxLon + resolution/2),
    );

    // Sanal canvas boyutları (Piksel cinsinden grid sayısı)
    // +1 ekliyoruz çünkü inclusive range
    _imgWidth = (lonDiff / resolution).ceil().toDouble() + 1;
    _imgHeight = (latDiff / resolution).ceil().toDouble() + 1;

    // 2. Picture Recorder ile çizim yap
    final recorder = ui.PictureRecorder();
    // Gridleri kare olarak çizeceğiz, her biri 1x1 birim
    // Bu resmi daha sonra haritaya oturtacağız
    final canvas = Canvas(recorder); 
    
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Grid boyutu (Sanal koordinat sisteminde 1 birim)
    // Fakat çizim yaparken nokta merkezli değil, sol-alt köşe mantığıyla dizelim
    // Y ekseni aşağı doğru artar Canvas'ta.
    // Haritada enlem yukarı doğru artar.
    // Bu yüzden Y eksenini ters çevirmek veya koordinatı dönüştürmek gerekir.
    // Basit yöntem: 
    // x = (lon - minLon) / resolution
    // y = (maxLat - lat) / resolution  <-- MaxLat en üstte (Canvas 0), MinLat en altta (Canvas H)
    
    for (var point in widget.data) {
      // TÜRKİYE SINIRLARI KONTROLÜ
      if (point.latitude < MapConstants.turkeyMinLat || 
          point.latitude > MapConstants.turkeyMaxLat ||
          point.longitude < MapConstants.turkeyMinLon || 
          point.longitude > MapConstants.turkeyMaxLon) {
        continue;
      }

      final normalized = _normalize(point.value, minVal, maxVal);
      paint.color = _getColor(normalized, widget.type);

      // Grid koordinatını hesapla
      final x = (point.longitude - minLon) / resolution; 
      final y = (maxLat - point.latitude) / resolution; 
      
      // Rect çiz (Her nokta 1x1'lik bir kare kaplasın)
      // x,y sol üst köşe olsun.
      // 0.1 derece çözünürlük için tam oturtmak adına Rect.fromLTWH kullanıyoruz
      // Örtüşmeyi engellemek için biraz 'bleed' yapılabilir (örn 1.05) ama 1.0 yeterli
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

    // Opacity dışarıdan kontrol ediliyor
    return Opacity(
      opacity: widget.opacity,
      child: Stack(
        children: [
          CustomPaint(
            painter: _CachedHeatmapPainter(
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
    // Daha canlı rüzgar renkleri
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

class _CachedHeatmapPainter extends CustomPainter {
  final ui.Picture picture;
  final LatLngBounds bounds;
  final double imgWidth;
  final double imgHeight;
  final MapCamera mapCamera;

  _CachedHeatmapPainter({
    required this.picture,
    required this.bounds,
    required this.imgWidth,
    required this.imgHeight,
    required this.mapCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Resmin köşe noktalarının ekrandaki konumunu bul
    // Sol-Üst (Map Coords) -> Screen Pixel
    final northWest = mapCamera.getOffsetFromOrigin(bounds.northWest);
    final southEast = mapCamera.getOffsetFromOrigin(bounds.southEast);

    // 2. Ekrandaki hedef dikdörtgen
    // Width ve Height pozitif olmalı
    final dstRect = Rect.fromLTRB(
      northWest.dx, 
      northWest.dy, 
      southEast.dx, 
      southEast.dy
    );

    // 3. Resmi bu dikdörtgene sığacak şekilde ölçekle (DrawPicture normalde scale almaz, scale/translate yapmalıyız)
    canvas.save();
    
    // Hedef konuma git
    canvas.translate(dstRect.left, dstRect.top);
    
    // Ölçekleme faktörü: (Hedef Genişlik / Resim Genişliği)
    // imgWidth bizim sanal birimimizdi (grid sayısı)
    // dstRect.width ise ekrandaki piksel genişliği
    final scaleX = dstRect.width / imgWidth;
    final scaleY = dstRect.height / imgHeight;
    
    canvas.scale(scaleX, scaleY);
    
    // Çiz
    canvas.drawPicture(picture);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CachedHeatmapPainter oldDelegate) {
    // Map hareket ettiyse (zoom/pan) veya resim değiştiyse tekrar çiz
    return oldDelegate.mapCamera.zoom != mapCamera.zoom ||
           oldDelegate.mapCamera.center != mapCamera.center ||
           oldDelegate.picture != picture;
  }
}

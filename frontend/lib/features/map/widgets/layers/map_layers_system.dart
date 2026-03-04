import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/data/models/map_models.dart';

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

    // Grid boyutlarını hesapla
    // +1 ekleyerek kenar durumlarını kapsıyoruz (inclusive)
    // floating point hatasından kaçınmak için round kullanıyoruz
    final int cols = ((maxLon - minLon) / resolution).round() + 1;
    final int rows = ((maxLat - minLat) / resolution).round() + 1;
    
    _bounds = LatLngBounds(
      LatLng(minLat, minLon), 
      LatLng(maxLat, maxLon), 
    );

    // Image boyutu grid boyutu kadar (her piksel bir vertex gibi düşünülebilir ama biz vertex çizeceğiz)
    _imgWidth = cols.toDouble();
    _imgHeight = rows.toDouble();

    // 2. Vertex'leri oluştur
    // Veriyi hızlı erişim için 2D Array'e atalım
    final grid = List.generate(rows, (_) => List<double?>.filled(cols, null));
    
    for (var point in widget.data) {
       final r = ((point.latitude - minLat) / resolution).round();
       final c = ((point.longitude - minLon) / resolution).round();
       if (r >= 0 && r < rows && c >= 0 && c < cols) {
         grid[r][c] = point.value;
       }
    }

    // GAP FILLING (Boşlukları Doldurma - Diffusion)
    // 5 geçişe çıkararak daha geniş boşlukları dolduruyoruz.
    for (int pass = 0; pass < 5; pass++) {
       final newGrid = List.generate(rows, (i) => List<double?>.from(grid[i]));
       bool changed = false;
       
       for (int r = 0; r < rows; r++) {
         for (int c = 0; c < cols; c++) {
           if (grid[r][c] == null) {
              double sum = 0;
              int count = 0;
              
              // 3x3 Tam Komşuluk (Diagonaller dahil)
              for (int dr = -1; dr <= 1; dr++) {
                for (int dc = -1; dc <= 1; dc++) {
                  if (dr == 0 && dc == 0) continue;
                  final nr = r + dr;
                  final nc = c + dc;
                  if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] != null) {
                    sum += grid[nr][nc]!;
                    count++;
                  }
                }
              }
              
              if (count >= 2) { // En az 2 komşu yeterli (daha agresif dolum)
                 newGrid[r][c] = sum / count;
                 changed = true;
              }
           }
         }
       }
       
       for(int r=0; r<rows; r++) {
         for(int c=0; c<cols; c++) {
            grid[r][c] = newGrid[r][c];
         }
       }
       if (!changed) break;
    }

    // SMOOTHING (Gaussian-like Blur)
    // 3 Geçişli Blur ile "Glow" etkisi yaratıyoruz
    List<List<double?>> currentGrid = grid;
    
    for (int pass = 0; pass < 3; pass++) {
        final nextGrid = List.generate(rows, (_) => List<double?>.filled(cols, null));
        
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
             if (currentGrid[r][c] != null) {
                 double sum = currentGrid[r][c]! * 2; // Merkez ağırlıklı (2x)
                 double weightTotal = 2.0;
                 
                 // 3x3 Box Blur
                 for (int dr = -1; dr <= 1; dr++) {
                    for (int dc = -1; dc <= 1; dc++) {
                       if (dr == 0 && dc == 0) continue;
                       final nr = r + dr;
                       final nc = c + dc;
                       if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && currentGrid[nr][nc] != null) {
                          sum += currentGrid[nr][nc]!;
                          weightTotal += 1.0;
                       }
                    }
                 }
                 nextGrid[r][c] = sum / weightTotal;
             }
          }
        }
        currentGrid = nextGrid;
    }

    final List<Offset> positions = [];
    final List<Color> colors = [];
    final List<int> indices = [];

    // Vertexleri oluştur (Smoothed Grid kullanarak)
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Pozisyon: (c, rows - 1 - r) -> Y ekseni ters (Canvas vs Geo)
        
        positions.add(Offset(c.toDouble(), (rows - 1 - r).toDouble()));
        
        final val = currentGrid[r][c];
        if (val != null) {
          final normalized = _normalize(val, minVal, maxVal);
          colors.add(_getColor(normalized, widget.layerType));
        } else {
          colors.add(Colors.transparent); 
        }
      }
    }

    // Üçgen indekslerini oluştur (Mesh)
    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < cols - 1; c++) {
        // 4 köşe indeksi
        final tl = r * cols + c;       // Top-Left (bizim loop sırasında r artıyor ama Y ters, neyse array sırası önemli)
        final tr = r * cols + (c + 1);
        final bl = (r + 1) * cols + c;
        final br = (r + 1) * cols + (c + 1);
        
        // Aslında 'r' grid satırı.
        // positions arrayine ekleme sırası: r=0 (minLat) .. r=rows-1 (maxLat).
        // Y koordinatı: (rows - 1 - r).
        // Yani r=0 -> Y=max (Bottom render), r=max -> Y=0 (Top render).
        // Görsel olarak mesh doğru bağlansın yeter.
        
        // Triangle 1: tl - tr - bl
        indices.add(tl);
        indices.add(tr);
        indices.add(bl);
        
        // Triangle 2: tr - br - bl
        indices.add(tr);
        indices.add(br);
        indices.add(bl);
      }
    }

    // 3. Picture Kaydet
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder); 
    
    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
      indices: indices,
    );
    
    final paint = Paint(); // BlendMode varsayılan
    canvas.drawVertices(vertices, BlendMode.dst, paint);
    
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
    // 0.0 - 0.2: Transparent Black -> Deep Neon Orange (Cyber Base)
    if (t < 0.2) return Color.lerp(Colors.black.withValues(alpha: 0.0), Colors.deepOrangeAccent.shade400.withValues(alpha: 0.8), t/0.2)!;
    
    // 0.2 - 0.5: Neon Orange -> Intense Red (Mid Range)
    if (t < 0.5) return Color.lerp(Colors.deepOrangeAccent.shade400.withValues(alpha: 0.8), Colors.redAccent.shade700, (t-0.2)/0.3)!;
    
    // 0.5 - 0.8: Red -> Bright Neon Yellow (High Energy)
    if (t < 0.8) return Color.lerp(Colors.redAccent.shade700, Colors.orangeAccent, (t-0.5)/0.3)!;
    
    // 0.8 - 1.0: Yellow -> White Hot Core (Peak)
    return Color.lerp(Colors.orangeAccent, Colors.white, (t-0.8)/0.2)!;
  }

  Color _getWindGradient(double t) {
    // 0.0 - 0.2: Transparent -> Neon Blue (Start)
    if (t < 0.2) return Color.lerp(Colors.black.withValues(alpha: 0.0), Colors.blueAccent.shade700.withValues(alpha: 0.8), t/0.2)!;
    
    // 0.2 - 0.6: Neon Blue -> Cyan (Mid Range)
    if (t < 0.6) return Color.lerp(Colors.blueAccent.shade700.withValues(alpha: 0.8), Colors.cyanAccent, (t-0.2)/0.4)!;
    
    // 0.6 - 1.0: Cyan -> White (High Velocity)
    return Color.lerp(Colors.cyanAccent, Colors.white, (t-0.6)/0.4)!;
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

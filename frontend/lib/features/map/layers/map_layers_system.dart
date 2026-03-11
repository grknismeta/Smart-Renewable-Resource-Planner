import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/features/map/models/map_models.dart';

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

  /// UI gösterim adları
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

// ─── Isolate Input / Output ────────────────────────────────────────────────────

/// [compute()] fonksiyonuna gönderilen düz veri.
/// Tüm değerler Float32List içinde interleaved olarak taşınır:
/// [lat0, lon0, val0, lat1, lon1, val1, ...]
class _LayerComputeInput {
  final Float32List data;
  final int layerTypeIndex;
  _LayerComputeInput(this.data, this.layerTypeIndex);
}

/// [compute()] sonucu — saf typed arrays.
/// ui.Vertices.raw() direkt bu verileri tüketir.
class _LayerComputeResult {
  final Float32List positions; // [x, y, x, y, ...]
  final Int32List colors;      // 0xAARRGGBB
  final Uint16List indices;    // üçgen indeksleri
  final double minLat, maxLat, minLon, maxLon;
  final int cols, rows;

  _LayerComputeResult({
    required this.positions,
    required this.colors,
    required this.indices,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    required this.cols,
    required this.rows,
  });

  bool get isEmpty => positions.isEmpty;
}

_LayerComputeResult _emptyResult() => _LayerComputeResult(
  positions: Float32List(0), colors: Int32List(0), indices: Uint16List(0),
  minLat: 0, maxLat: 0, minLon: 0, maxLon: 0, cols: 0, rows: 0,
);

// ─── Renk yardımcıları — izolat uyumlu, saf int aritmetiği ───────────────────

int _lerpByte(int a, int b, double t) =>
    (a + (b - a) * t).round().clamp(0, 255);

/// c1 / c2: 0xAARRGGBB
int _lerpInt(int c1, int c2, double t) =>
    (_lerpByte((c1 >> 24) & 0xFF, (c2 >> 24) & 0xFF, t) << 24) |
    (_lerpByte((c1 >> 16) & 0xFF, (c2 >> 16) & 0xFF, t) << 16) |
    (_lerpByte((c1 >> 8)  & 0xFF, (c2 >> 8)  & 0xFF, t) << 8)  |
     _lerpByte( c1        & 0xFF,  c2        & 0xFF,  t);

// Mevcut paleti int sabitlere dönüştürdük → Flutter framework gerektirmiyor
int _getSolarColorInt(double t) {
  if (t < 0.2) return _lerpInt(0x00000000, 0xCCFF6D00, t / 0.2);
  if (t < 0.5) return _lerpInt(0xCCFF6D00, 0xFFD50000, (t - 0.2) / 0.3);
  if (t < 0.8) return _lerpInt(0xFFD50000, 0xFFFFAB40, (t - 0.5) / 0.3);
  return _lerpInt(0xFFFFAB40, 0xFFFFFFFF, (t - 0.8) / 0.2);
}

int _getWindColorInt(double t) {
  if (t < 0.2) return _lerpInt(0x00000000, 0xCC2962FF, t / 0.2);
  if (t < 0.6) return _lerpInt(0xCC2962FF, 0xFF64FFDA, (t - 0.2) / 0.4);
  return _lerpInt(0xFF64FFDA, 0xFFFFFFFF, (t - 0.6) / 0.4);
}

int _getTempColorInt(double t) {
  if (t < 0.33) return _lerpInt(0xFF2196F3, 0xFF4CAF50, t / 0.33);
  if (t < 0.66) return _lerpInt(0xFF4CAF50, 0xFFFFEB3B, (t - 0.33) / 0.33);
  return _lerpInt(0xFFFFEB3B, 0xFFF44336, (t - 0.66) / 0.34);
}

int _colorInt(double normalized, int layerTypeIndex) {
  switch (layerTypeIndex) {
    case 2: return _getSolarColorInt(normalized);
    case 0: return _getWindColorInt(normalized);
    case 1: return _getTempColorInt(normalized);
    default: return 0x00000000;
  }
}

// ─── Ağır hesaplama — izolat'te çalışır, UI thread'ini bloklamaz ──────────────

/// Bu fonksiyon [compute()] aracılığıyla ayrı bir Dart izolatında çalışır.
/// Gap-filling, Gaussian smoothing, vertex + index inşası burada yapılır.
_LayerComputeResult _computeLayerData(_LayerComputeInput input) {
  final int count = input.data.length ~/ 3;
  if (count == 0) return _emptyResult();

  // 1. Sınırları ve değer aralığını bul
  double minLat = double.infinity, maxLat = double.negativeInfinity;
  double minLon = double.infinity, maxLon = double.negativeInfinity;
  double minVal = double.infinity, maxVal = double.negativeInfinity;

  for (int i = 0; i < count; i++) {
    final lat = input.data[i * 3];
    final lon = input.data[i * 3 + 1];
    final val = input.data[i * 3 + 2];
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lon < minLon) minLon = lon;
    if (lon > maxLon) maxLon = lon;
    if (val < minVal) minVal = val;
    if (val > maxVal) maxVal = val;
  }

  if (minLat == double.infinity) return _emptyResult();
  if (minVal == maxVal) maxVal += 0.1;

  const double resolution = 0.1;
  final int cols = ((maxLon - minLon) / resolution).round() + 1;
  final int rows = ((maxLat - minLat) / resolution).round() + 1;
  final int total = rows * cols;

  // Uint16List maksimum indeks sınırı (65535 vertex)
  if (total > 65535 || rows < 2 || cols < 2) return _emptyResult();

  // 2. Veriyi düz grid listesine yerleştir
  final grid = List<double?>.filled(total, null);
  for (int i = 0; i < count; i++) {
    final r = ((input.data[i * 3] - minLat) / resolution).round();
    final c = ((input.data[i * 3 + 1] - minLon) / resolution).round();
    if (r >= 0 && r < rows && c >= 0 && c < cols) {
      grid[r * cols + c] = input.data[i * 3 + 2];
    }
  }

  // 3. Gap filling — 5 geçiş diffusion
  for (int pass = 0; pass < 5; pass++) {
    final newGrid = List<double?>.from(grid);
    bool changed = false;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r * cols + c] != null) continue;
        double sum = 0;
        int cnt = 0;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
              final v = grid[nr * cols + nc];
              if (v != null) { sum += v; cnt++; }
            }
          }
        }
        if (cnt >= 2) { newGrid[r * cols + c] = sum / cnt; changed = true; }
      }
    }
    for (int i = 0; i < total; i++) { grid[i] = newGrid[i]; }
    if (!changed) break;
  }

  // 4. Gaussian-like smoothing — 3 geçiş
  List<double?> currentGrid = grid;
  for (int pass = 0; pass < 3; pass++) {
    final nextGrid = List<double?>.filled(total, null);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final center = currentGrid[r * cols + c];
        if (center == null) continue;
        double sum = center * 2; // merkez ağırlıklı
        double w = 2.0;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
              final v = currentGrid[nr * cols + nc];
              if (v != null) { sum += v; w += 1; }
            }
          }
        }
        nextGrid[r * cols + c] = sum / w;
      }
    }
    currentGrid = nextGrid;
  }

  // 5. Vertex verisi — Float32List + Int32List (Vertices.raw için)
  final positions = Float32List(total * 2);
  final colors = Int32List(total);

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final idx = r * cols + c;
      positions[idx * 2] = c.toDouble();
      positions[idx * 2 + 1] = (rows - 1 - r).toDouble();
      final v = currentGrid[idx];
      if (v != null) {
        final norm = ((v - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
        colors[idx] = _colorInt(norm, input.layerTypeIndex);
      }
      // null → 0x00000000 (transparan — Int32List default)
    }
  }

  // 6. Üçgen indeksleri
  final triCount = (rows - 1) * (cols - 1) * 6;
  final indices = Uint16List(triCount);
  int ii = 0;
  for (int r = 0; r < rows - 1; r++) {
    for (int c = 0; c < cols - 1; c++) {
      final tl = r * cols + c;
      final tr = r * cols + (c + 1);
      final bl = (r + 1) * cols + c;
      final br = (r + 1) * cols + (c + 1);
      indices[ii++] = tl;
      indices[ii++] = tr;
      indices[ii++] = bl;
      indices[ii++] = tr;
      indices[ii++] = br;
      indices[ii++] = bl;
    }
  }

  return _LayerComputeResult(
    positions: positions,
    colors: colors,
    indices: indices,
    minLat: minLat, maxLat: maxLat,
    minLon: minLon, maxLon: maxLon,
    cols: cols, rows: rows,
  );
}

// ─── Widget ────────────────────────────────────────────────────────────────────

/// Tüm katman mantığını (logic + rendering) içeren ana widget.
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

  /// Stale check: widget güncellenirse eski compute sonucu görmezden gelinir.
  int _computeVersion = 0;

  @override
  void initState() {
    super.initState();
    _scheduleCompute();
  }

  @override
  void didUpdateWidget(covariant MapLayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cache fix: aynı List referansı ise hesaplama yapma
    if (widget.data != oldWidget.data || widget.layerType != oldWidget.layerType) {
      _scheduleCompute();
    }
  }

  void _scheduleCompute() {
    final version = ++_computeVersion;
    _runCompute(version);
  }

  Future<void> _runCompute(int version) async {
    if (widget.data.isEmpty || widget.layerType == MapLayerType.none) {
      if (mounted && _computeVersion == version) {
        setState(() { _cachedPicture = null; _bounds = null; });
      }
      return;
    }

    // Flat Float32List oluştur — izolata gönderilir
    final inputData = Float32List(widget.data.length * 3);
    for (int i = 0; i < widget.data.length; i++) {
      inputData[i * 3]     = widget.data[i].latitude;
      inputData[i * 3 + 1] = widget.data[i].longitude;
      inputData[i * 3 + 2] = widget.data[i].value;
    }

    // Ağır hesaplama ayrı izolatta — UI thread serbest kalır
    final result = await compute(
      _computeLayerData,
      _LayerComputeInput(inputData, widget.layerType.index),
    );

    // Widget unmount olmuş veya daha yeni bir hesaplama başlamış
    if (!mounted || _computeVersion != version) return;

    if (result.isEmpty) {
      setState(() { _cachedPicture = null; _bounds = null; });
      return;
    }

    // Ana thread'de: Vertices + Picture kaydı — < 2ms
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      result.positions,
      colors: result.colors,
      indices: result.indices,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawVertices(vertices, BlendMode.srcOver, Paint());
    final picture = recorder.endRecording();

    setState(() {
      _cachedPicture = picture;
      _bounds = LatLngBounds(
        LatLng(result.minLat, result.minLon),
        LatLng(result.maxLat, result.maxLon),
      );
      _imgWidth = result.cols.toDouble();
      _imgHeight = result.rows.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedPicture == null || _bounds == null) return const SizedBox.shrink();

    return Opacity(
      opacity: widget.opacity,
      child: CustomPaint(
        painter: _CachedLayerPainter(
          picture: _cachedPicture!,
          bounds: _bounds!,
          imgWidth: _imgWidth,
          imgHeight: _imgHeight,
          mapCamera: MapCamera.of(context),
        ),
      ),
    );
  }
}

// ─── Painter — haritaya ölçekleyerek çizer ────────────────────────────────────

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
      northWest.dx, northWest.dy,
      southEast.dx, southEast.dy,
    );

    if (dstRect.width <= 0 || dstRect.height <= 0) return;

    canvas.save();
    canvas.translate(dstRect.left, dstRect.top);
    canvas.scale(dstRect.width / imgWidth, dstRect.height / imgHeight);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CachedLayerPainter oldDelegate) =>
      oldDelegate.mapCamera.zoom != mapCamera.zoom ||
      oldDelegate.mapCamera.center != mapCamera.center ||
      oldDelegate.picture != picture;
}

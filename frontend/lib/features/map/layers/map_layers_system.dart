import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
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

  /// Karşılık gelen ChoroplethMode — tematik harita köprüsü.
  ///
  /// 1.A2 itibarıyla görsel dil tek: ilçe choropleth. Heatmap fetcher zinciri
  /// devre dışı. setLayer() çağrıldığında bu getter ile choropleth tetiklenir.
  ChoroplethMode get toChoropleth {
    switch (this) {
      case MapLayerType.wind:
        return ChoroplethMode.wind;
      case MapLayerType.temp:
        return ChoroplethMode.temperature;
      case MapLayerType.irradiance:
        return ChoroplethMode.solar;
      case MapLayerType.none:
        return ChoroplethMode.none;
    }
  }
}

// ─── Isolate Input / Output ────────────────────────────────────────────────────

class _LayerComputeInput {
  final Float32List data;
  final int layerTypeIndex;
  final bool fastMode;
  _LayerComputeInput(this.data, this.layerTypeIndex, {this.fastMode = false});
}

class _LayerComputeResult {
  final Float32List positions;
  final Int32List colors;
  final Uint16List indices;
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

// ─── Renk yardımcıları ────────────────────────────────────────────────────────

int _lerpByte(int a, int b, double t) =>
    (a + (b - a) * t).round().clamp(0, 255);

int _lerpInt(int c1, int c2, double t) =>
    (_lerpByte((c1 >> 24) & 0xFF, (c2 >> 24) & 0xFF, t) << 24) |
    (_lerpByte((c1 >> 16) & 0xFF, (c2 >> 16) & 0xFF, t) << 16) |
    (_lerpByte((c1 >> 8)  & 0xFF, (c2 >> 8)  & 0xFF, t) << 8)  |
     _lerpByte( c1        & 0xFF,  c2        & 0xFF,  t);

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
    case 1: return _getWindColorInt(normalized);
    case 2: return _getTempColorInt(normalized);
    case 3: return _getSolarColorInt(normalized);
    default: return 0x00000000;
  }
}

// ─── Compute — izolat'te çalışır ─────────────────────────────────────────────

_LayerComputeResult _computeLayerData(_LayerComputeInput input) {
  final int count = input.data.length ~/ 3;
  if (count == 0) return _emptyResult();

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

  final double resolution = input.fastMode ? 0.25 : 0.1;
  final int cols = ((maxLon - minLon) / resolution).round() + 1;
  final int rows = ((maxLat - minLat) / resolution).round() + 1;
  final int total = rows * cols;

  if (total > 65535 || rows < 2 || cols < 2) return _emptyResult();

  final grid = List<double?>.filled(total, null);
  for (int i = 0; i < count; i++) {
    final r = ((input.data[i * 3] - minLat) / resolution).round();
    final c = ((input.data[i * 3 + 1] - minLon) / resolution).round();
    if (r >= 0 && r < rows && c >= 0 && c < cols) {
      grid[r * cols + c] = input.data[i * 3 + 2];
    }
  }

  final int gapPasses = input.fastMode ? 2 : 5;
  for (int pass = 0; pass < gapPasses; pass++) {
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

  final int smoothPasses = input.fastMode ? 1 : 3;
  List<double?> currentGrid = grid;
  for (int pass = 0; pass < smoothPasses; pass++) {
    final nextGrid = List<double?>.filled(total, null);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final center = currentGrid[r * cols + c];
        if (center == null) continue;
        double sum = center * 2;
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
    }
  }

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

// ─── Raster PNG Export (MapLibre overlay için) ────────────────────────────────

class MapLayerRasterResult {
  final String base64Png;
  final double minLon, minLat, maxLon, maxLat;
  const MapLayerRasterResult({
    required this.base64Png,
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  });
}

Future<MapLayerRasterResult?> computeLayerPng(
  List<HeatmapPoint> data,
  MapLayerType layerType, {
  bool fastMode = false,
}) async {
  if (data.isEmpty || layerType == MapLayerType.none) return null;

  final inputData = Float32List(data.length * 3);
  for (int i = 0; i < data.length; i++) {
    inputData[i * 3]     = data[i].latitude;
    inputData[i * 3 + 1] = data[i].longitude;
    inputData[i * 3 + 2] = data[i].value;
  }

  final result = await compute(
    _computeLayerData,
    _LayerComputeInput(inputData, layerType.index, fastMode: fastMode),
  );
  if (result.isEmpty) return null;

  final vertices = ui.Vertices.raw(
    ui.VertexMode.triangles,
    result.positions,
    colors: result.colors,
    indices: result.indices,
  );

  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawVertices(vertices, ui.BlendMode.srcOver, ui.Paint());
  final picture = recorder.endRecording();

  final image = await picture.toImage(result.cols, result.rows);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return null;

  final base64Png = base64Encode(byteData.buffer.asUint8List());
  return MapLayerRasterResult(
    base64Png: base64Png,
    minLon: result.minLon,
    minLat: result.minLat,
    maxLon: result.maxLon,
    maxLat: result.maxLat,
  );
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:provider/provider.dart';

import 'package:frontend/core/constants/map_constants.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/weather_model.dart';

// ─── Layer / Source ID'leri ───────────────────────────────────────────────────

const _pinsSourceId       = 'srrp-pins';
const _pinsShadowLayerId  = 'srrp-pins-shadow';
const _pinsLayerId        = 'srrp-pins-circles';
const _pinsLabelLayerId   = 'srrp-pins-labels';

const _heatmapSourceId    = 'srrp-heatmap';
const _heatmapSolarId     = 'srrp-heatmap-solar';
const _heatmapWindId      = 'srrp-heatmap-wind';

const _hillshadeSourceId  = 'srrp-hillshade-dem';
const _hillshadeLayerId   = 'srrp-hillshade';

// ─── Heatmap Paint Tanımları ──────────────────────────────────────────────────

const _solarHeatmapPaint = <String, Object>{
  'heatmap-weight':    ['interpolate', ['linear'], ['get', 'solar_weight'], 0, 0, 1, 1],
  'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 0, 1, 10, 3],
  'heatmap-color': [
    'interpolate', ['linear'], ['heatmap-density'],
    0,    'rgba(255,255,178,0)',
    0.25, 'rgba(254,204,92,0.6)',
    0.5,  'rgba(253,141,60,0.8)',
    0.75, 'rgba(240,59,32,0.9)',
    1,    'rgba(189,0,38,1)',
  ],
  'heatmap-radius':  ['interpolate', ['linear'], ['zoom'], 0, 40, 10, 80],
  'heatmap-opacity': 0.75,
};

const _windHeatmapPaint = <String, Object>{
  'heatmap-weight':    ['interpolate', ['linear'], ['get', 'wind_weight'], 0, 0, 1, 1],
  'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 0, 1, 10, 3],
  'heatmap-color': [
    'interpolate', ['linear'], ['heatmap-density'],
    0,    'rgba(230,240,255,0)',
    0.25, 'rgba(116,169,207,0.6)',
    0.5,  'rgba(43,140,190,0.8)',
    0.75, 'rgba(4,90,141,0.9)',
    1,    'rgba(2,56,88,1)',
  ],
  'heatmap-radius':  ['interpolate', ['linear'], ['zoom'], 0, 40, 10, 80],
  'heatmap-opacity': 0.75,
};

// ─── Renk / GeoJSON Yardımcıları ─────────────────────────────────────────────

String _pinColorHex(String type) {
  switch (type.toLowerCase()) {
    case 'güneş paneli': case 'solar':  return '#FFA726';
    case 'rüzgar türbini': case 'wind': return '#29B6F6';
    case 'hidroelektrik': case 'hes': case 'hydro': return '#42A5F5';
    default:                            return '#66BB6A';
  }
}

String _pinsToGeoJson(List<Pin> pins) => jsonEncode({
  'type': 'FeatureCollection',
  'features': pins.map((p) => {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': [p.longitude, p.latitude]},
    'properties': {'id': p.id, 'name': p.name, 'type': p.type, 'color': _pinColorHex(p.type)},
  }).toList(),
});

String _heatmapToGeoJson(List<CityWeatherSummary> summaries) {
  if (summaries.isEmpty) return '{"type":"FeatureCollection","features":[]}';
  double maxRad  = summaries.fold(0.0, (m, s) => (s.totalRadiation ?? 0) > m ? (s.totalRadiation ?? 0).toDouble() : m);
  double maxWind = summaries.fold(0.0, (m, s) => (s.avgWindSpeed100m ?? 0) > m ? (s.avgWindSpeed100m ?? 0).toDouble() : m);
  if (maxRad  == 0) maxRad  = 1;
  if (maxWind == 0) maxWind = 1;
  return jsonEncode({'type': 'FeatureCollection', 'features': summaries.map((s) => {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': [s.lon, s.lat]},
    'properties': {
      'solar_weight': ((s.totalRadiation ?? 0) / maxRad).clamp(0.0, 1.0),
      'wind_weight':  ((s.avgWindSpeed100m ?? 0) / maxWind).clamp(0.0, 1.0),
    },
  }).toList()});
}

// ─── MapViewMapLibre (Native) ─────────────────────────────────────────────────

class MapViewMapLibre extends StatefulWidget {
  final Function(ml.Position)? onMapTap;
  final Function(Pin)? onPinTap;

  const MapViewMapLibre({super.key, this.onMapTap, this.onPinTap});

  /// Native: MapLibre SDK'da animasyonlu geçiş (şimdilik stub; ml.MapController ile entegre edilebilir).
  static void flyTo(double lat, double lon, {double zoom = 10.0}) {
    // TODO: native MapLibre controller üzerinden flyTo çağrısı ekle
  }

  /// Native: web-only özellik, no-op.
  static void setupProvinceSelect(bool enable) {}
  static void setupRegionMode() {}
  static void setupProvinceMode({String? regionFilter}) {}
  static void setupDistrictMode(String provinceName) {}
  static void clearSelectionMode() {}

  @override
  State<MapViewMapLibre> createState() => _MapViewMapLibreState();
}

class _MapViewMapLibreState extends State<MapViewMapLibre> {
  ml.StyleController? _style;
  bool _styleLoaded = false;
  bool _syncing = false;

  List<Pin>                _lastPins    = [];
  List<CityWeatherSummary> _lastSummary = [];
  MlHeatmapMode            _lastHeatmap = MlHeatmapMode.none;
  bool                     _last3D      = false;

  bool _solarActive     = false;
  bool _windActive      = false;
  bool _hillshadeActive = false;
  bool _lastTerrain     = false;

  MapViewModel? _vmRef;

  // ─── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vmRef = Provider.of<MapViewModel>(context, listen: false);
      _vmRef!.addListener(_onVmChanged);
    });
  }

  @override
  void dispose() {
    _vmRef?.removeListener(_onVmChanged);
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted || !_styleLoaded || _syncing || _vmRef == null) return;
    _syncAll(_vmRef!);
  }

  Future<void> _syncAll(MapViewModel vm) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _syncPins(vm.pins, vm.show3DTurbines);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncPins hata: $e');
    }
    try {
      await _syncHeatmapData(vm.weatherSummary);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncHeatmapData hata: $e');
    }
    try {
      await _syncHeatmapMode(vm.mlHeatmapMode);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncHeatmapMode hata: $e');
    }
    try {
      await _syncTerrain(vm.show3DTerrain);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncTerrain hata: $e');
    }
    // Globe ve 3D buildings native'de JS shim olmadan desteklenmiyor — atla
    _syncing = false;
  }

  // ─── Event Handler ────────────────────────────────────────────────

  Future<void> _onEvent(ml.MapEvent event) async {
    switch (event) {
      case ml.MapEventStyleLoaded(:final style):
        _style = style;
        _styleLoaded = false;
        _syncing = false;

        _solarActive = _windActive = _hillshadeActive = false;
        _lastHeatmap  = MlHeatmapMode.none;
        _last3D       = false;
        _lastTerrain  = false;
        _lastPins    = [];
        _lastSummary = [];

        await _initLayers();

        if (mounted) setState(() => _styleLoaded = true);

        if (mounted) {
          final vm = Provider.of<MapViewModel>(context, listen: false);
          await _syncAll(vm);
        }

      case ml.MapEventClick(:final point):
        await _onMapClick(point);

      default:
        break;
    }
  }

  // ─── Pin Etkileşimi ───────────────────────────────────────────────

  Future<void> _onMapClick(ml.Position point) async {
    final vm = Provider.of<MapViewModel>(context, listen: false);

    if (widget.onPinTap != null && vm.pins.isNotEmpty) {
      final pin = _nearestPin(vm.pins, point);
      if (pin != null) {
        widget.onPinTap!(pin);
        return;
      }
    }

    widget.onMapTap?.call(point);
  }

  Pin? _nearestPin(List<Pin> pins, ml.Position point) {
    if (pins.isEmpty) return null;
    const double fixedThreshold = 0.08;

    Pin? nearest;
    double minDist = double.infinity;
    for (final p in pins) {
      final dLat = p.latitude  - point.lat.toDouble();
      final dLon = p.longitude - point.lng.toDouble();
      final dist = dLat * dLat + dLon * dLon;
      if (dist < minDist) {
        minDist = dist;
        nearest = p;
      }
    }
    return minDist < (fixedThreshold * fixedThreshold) ? nearest : null;
  }

  // ─── Katman Kurulumu ──────────────────────────────────────────────

  Future<void> _initLayers() async {
    final style = _style;
    if (style == null) return;

    try {
      await style.addSource(ml.GeoJsonSource(id: _heatmapSourceId, data: _heatmapToGeoJson([])));
    } catch (e) {
      debugPrint('[MapLibre-Native] heatmap source eklenemedi: $e');
    }

    try {
      await style.addSource(ml.GeoJsonSource(id: _pinsSourceId, data: _pinsToGeoJson([])));
    } catch (e) {
      debugPrint('[MapLibre-Native] pin source eklenemedi: $e');
    }

    try {
      await style.addLayer(ml.CircleStyleLayer(
        id: _pinsShadowLayerId, sourceId: _pinsSourceId,
        paint: <String, Object>{
          'circle-radius': 12, 'circle-color': '#000000',
          'circle-opacity': 0.0, 'circle-blur': 0.8,
          'circle-translate': [0, 4], 'circle-pitch-alignment': 'map',
        },
      ));
    } catch (e) {
      debugPrint('[MapLibre-Native] shadow layer eklenemedi: $e');
    }

    try {
      await style.addLayer(ml.CircleStyleLayer(
        id: _pinsLayerId, sourceId: _pinsSourceId,
        paint: <String, Object>{
          'circle-radius': ['interpolate', ['linear'], ['zoom'], 4, 6, 10, 10],
          'circle-color': ['get', 'color'],
          'circle-stroke-width': 2, 'circle-stroke-color': '#FFFFFF',
          'circle-opacity': 0.9,
          'circle-pitch-alignment': 'map', 'circle-pitch-scale': 'map',
        },
      ));
    } catch (e) {
      debugPrint('[MapLibre-Native] pins layer eklenemedi: $e');
    }

    try {
      await style.addLayer(ml.SymbolStyleLayer(
        id: _pinsLabelLayerId, sourceId: _pinsSourceId,
        layout: <String, Object>{
          'text-field': ['get', 'name'], 'text-size': 10,
          'text-offset': [0, 1.5], 'text-anchor': 'top',
          'text-allow-overlap': false,
        },
        paint: <String, Object>{
          'text-color': '#FFFFFF', 'text-halo-color': '#000000', 'text-halo-width': 1,
        },
      ));
    } catch (e) {
      debugPrint('[MapLibre-Native] labels layer eklenemedi: $e');
    }

  }

  // ─── Pin Sync ─────────────────────────────────────────────────────

  Future<void> _syncPins(List<Pin> pins, bool is3D) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    if (!_pinsEqual(pins, _lastPins)) {
      _lastPins = List.from(pins);
      try {
        await style.updateGeoJsonSource(id: _pinsSourceId, data: _pinsToGeoJson(pins));
      } catch (e) {
        debugPrint('[MapLibre-Native] pin source güncelleme hatası: $e');
        return;
      }
    }

    if (is3D == _last3D) return;
    _last3D = is3D;

    try {
      await style.removeLayer(_pinsShadowLayerId);
    } catch (_) {}
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _pinsShadowLayerId, sourceId: _pinsSourceId,
          paint: <String, Object>{
            'circle-radius': is3D ? 14 : 12,
            'circle-color': '#000000',
            'circle-opacity': is3D ? 0.28 : 0.0,
            'circle-blur': is3D ? 0.6 : 0.8,
            'circle-translate': is3D ? [0, 5] : [0, 4],
            'circle-pitch-alignment': 'map',
          },
        ),
        belowLayerId: _pinsLayerId,
      );
    } catch (e) {
      debugPrint('[MapLibre-Native] shadow layer güncelleme hatası: $e');
    }

    try {
      await style.removeLayer(_pinsLayerId);
    } catch (_) {}
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _pinsLayerId, sourceId: _pinsSourceId,
          paint: <String, Object>{
            'circle-radius': ['interpolate', ['linear'], ['zoom'],
              4, is3D ? 8 : 6,
              10, is3D ? 13 : 10,
            ],
            'circle-color': ['get', 'color'],
            'circle-stroke-width': is3D ? 3 : 2,
            'circle-stroke-color': '#FFFFFF',
            'circle-opacity': 0.9,
            'circle-pitch-alignment': 'map',
            'circle-pitch-scale': 'map',
          },
        ),
        belowLayerId: _pinsLabelLayerId,
      );
    } catch (e) {
      debugPrint('[MapLibre-Native] pins layer güncelleme hatası: $e');
    }
  }

  bool _pinsEqual(List<Pin> a, List<Pin> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  // ─── Heatmap Sync ─────────────────────────────────────────────────

  Future<void> _syncHeatmapData(List<CityWeatherSummary> summaries) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;
    if (summaries.length == _lastSummary.length && _lastSummary.isNotEmpty) return;
    _lastSummary = List.from(summaries);
    try {
      await style.updateGeoJsonSource(
        id: _heatmapSourceId,
        data: _heatmapToGeoJson(summaries),
      );
    } catch (e) {
      debugPrint('[MapLibre-Native] heatmap source güncelleme hatası: $e');
    }
  }

  Future<void> _syncHeatmapMode(MlHeatmapMode mode) async {
    final style = _style;
    if (style == null || !_styleLoaded || mode == _lastHeatmap) return;
    _lastHeatmap = mode;

    if (_solarActive) {
      try { await style.removeLayer(_heatmapSolarId); } catch (_) {}
      _solarActive = false;
    }
    if (_windActive) {
      try { await style.removeLayer(_heatmapWindId); } catch (_) {}
      _windActive = false;
    }

    if (mode == MlHeatmapMode.none) return;

    final layerId  = mode == MlHeatmapMode.solar ? _heatmapSolarId : _heatmapWindId;
    final paintDef = mode == MlHeatmapMode.solar ? _solarHeatmapPaint : _windHeatmapPaint;

    bool added = false;

    try {
      await style.addLayer(
        ml.HeatmapStyleLayer(id: layerId, sourceId: _heatmapSourceId, paint: paintDef),
        belowLayerId: _pinsShadowLayerId,
      );
      added = true;
    } catch (_) {}

    if (!added) {
      try {
        await style.addLayer(
          ml.HeatmapStyleLayer(id: layerId, sourceId: _heatmapSourceId, paint: paintDef),
        );
        added = true;
      } catch (e) {
        debugPrint('[MapLibre-Native] heatmap layer eklenemedi: $e');
      }
    }

    if (added) {
      if (mode == MlHeatmapMode.solar) _solarActive = true;
      if (mode == MlHeatmapMode.wind)  _windActive  = true;
    }
  }

  // ─── Terrain Sync (native: yalnızca hillshade görsel efekti) ──────

  Future<void> _syncTerrain(bool show) async {
    final style = _style;
    if (style == null || !_styleLoaded || show == _lastTerrain) return;
    _lastTerrain = show;

    if (show) {
      try {
        await style.addSource(ml.RasterDemSource(
          id: _hillshadeSourceId,
          url: 'https://demotiles.maplibre.org/terrain-tiles/tiles.json',
          tileSize: 256,
        ));
      } catch (_) {}

      if (!_hillshadeActive) {
        try {
          await style.addLayer(
            ml.HillshadeStyleLayer(
              id: _hillshadeLayerId,
              sourceId: _hillshadeSourceId,
              paint: <String, Object>{
                'hillshade-illumination-direction': 335,
                'hillshade-illumination-anchor': 'viewport',
                'hillshade-exaggeration': 0.45,
                'hillshade-shadow-color': '#000000',
                'hillshade-highlight-color': '#ffffff',
              },
            ),
            belowLayerId: _pinsShadowLayerId,
          );
          _hillshadeActive = true;
        } catch (e) {
          debugPrint('[MapLibre-Native] hillshade layer hatası: $e');
        }
      }
    } else {
      if (_hillshadeActive) {
        try { await style.removeLayer(_hillshadeLayerId); } catch (_) {}
        _hillshadeActive = false;
      }
      try { await style.removeSource(_hillshadeSourceId); } catch (_) {}
    }
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm       = Provider.of<MapViewModel>(context, listen: false);
    final styleUrl = vm.mlBaseStyle.styleUrl;

    return Stack(
      children: [
        KeyedSubtree(
          key: ValueKey(styleUrl),
          child: ml.MapLibreMap(
            options: ml.MapOptions(
              initStyle: styleUrl,
              initZoom: MapConstants.initialZoom,
              initCenter: ml.Position(
                MapConstants.turkeyCenterLon,
                MapConstants.turkeyCenterLat,
              ),
            ),
            onEvent: _onEvent,
          ),
        ),

        // Etiket
        Positioned(
          top: 8, left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.map_outlined, color: Colors.white, size: 13),
              SizedBox(width: 4),
              Text('MapLibre', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),

        // Yükleniyor
        if (!_styleLoaded)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 12),
                Text('MapLibre yükleniyor...', style: TextStyle(color: Colors.white70)),
              ]),
            ),
          ),
      ],
    );
  }
}

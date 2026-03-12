import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:provider/provider.dart';

import 'package:frontend/core/constants/map_constants.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/data/models/pin_model.dart';

// ─── Stil URL'leri ─────────────────────────────────────────────────────────

const _darkStyle =
    'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';
const _lightStyle =
    'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

const _pinsSourceId = 'srrp-pins';
const _pinsLayerId  = 'srrp-pins-circles';

// ─── Pin Renk Kodu ────────────────────────────────────────────────────────

String _pinColorHex(String type) {
  switch (type.toLowerCase()) {
    case 'güneş paneli':
    case 'solar':
      return '#FFA726'; // turuncu
    case 'rüzgar türbini':
    case 'wind':
      return '#29B6F6'; // açık mavi
    case 'hes':
    case 'hydro':
      return '#42A5F5'; // mavi
    default:
      return '#66BB6A'; // yeşil
  }
}

// ─── GeoJSON Üretici ──────────────────────────────────────────────────────

/// Pin listesini MapLibre GeoJSON FeatureCollection string'ine çevirir.
String _pinsToGeoJson(List<Pin> pins) {
  final features = pins.map((p) => {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [p.longitude, p.latitude],
    },
    'properties': {
      'id':    p.id,
      'name':  p.name,
      'type':  p.type,
      'color': _pinColorHex(p.type),
    },
  }).toList();

  return jsonEncode({
    'type': 'FeatureCollection',
    'features': features,
  });
}

// ─── MapViewMapLibre ─────────────────────────────────────────────────────

/// flutter_map'e paralel MapLibre GL tabanlı harita widget'ı.
/// Aynı [MapViewModel]'i kullanır — business logic'e sıfır dokunuş.
/// Web / Android / iOS desteklidir. Windows desteği yok.
class MapViewMapLibre extends StatefulWidget {
  final Function(ml.Position)? onMapTap;

  const MapViewMapLibre({
    super.key,
    this.onMapTap,
  });

  @override
  State<MapViewMapLibre> createState() => _MapViewMapLibreState();
}

class _MapViewMapLibreState extends State<MapViewMapLibre> {
  ml.MapController? _controller;
  bool _styleLoaded = false;
  List<Pin> _lastPins = [];

  // ─── Event Handler ────────────────────────────────────────────────────

  Future<void> _onEvent(ml.MapEvent event) async {
    switch (event) {
      case ml.MapEventMapCreated(:final mapController):
        _controller = mapController;

      case ml.MapEventStyleLoaded():
        await _initPinLayer();
        setState(() => _styleLoaded = true);
        // İlk sync
        if (mounted) {
          final vm = Provider.of<MapViewModel>(context, listen: false);
          await _syncPins(vm.pins);
        }

      case ml.MapEventClick(:final point):
        widget.onMapTap?.call(point);

      default:
        break;
    }
  }

  // ─── Pin Katmanı Kurulumu ─────────────────────────────────────────────

  Future<void> _initPinLayer() async {
    final style = _controller?.style;
    if (style == null) return;

    // Boş GeoJSON source ekle
    await style.addSource(
      ml.GeoJsonSource(
        id: _pinsSourceId,
        data: _pinsToGeoJson([]),
      ),
    );

    // Circle layer — renk GeoJSON property'den alınır
    await style.addLayer(
      ml.CircleStyleLayer(
        id: _pinsLayerId,
        sourceId: _pinsSourceId,
        paint: {
          'circle-radius': 8,
          'circle-color': ['get', 'color'],
          'circle-stroke-width': 2,
          'circle-stroke-color': '#FFFFFF',
          'circle-opacity': 0.9,
        },
      ),
    );
  }

  // ─── Pin Senkronizasyonu ─────────────────────────────────────────────

  Future<void> _syncPins(List<Pin> pins) async {
    final style = _controller?.style;
    if (style == null || !_styleLoaded) return;
    if (_pinsEqual(pins, _lastPins)) return;
    _lastPins = List.from(pins);

    await style.updateGeoJsonSource(
      id: _pinsSourceId,
      data: _pinsToGeoJson(pins),
    );
  }

  // ─── Yardımcılar ─────────────────────────────────────────────────────

  bool _pinsEqual(List<Pin> a, List<Pin> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].latitude != b[i].latitude ||
          a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Provider.of<ThemeViewModel>(context);
    final mapVM   = Provider.of<MapViewModel>(context);

    // Pin değişince güncelle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_styleLoaded) _syncPins(mapVM.pins);
    });

    final styleUrl = theme.isDarkMode ? _darkStyle : _lightStyle;

    return Stack(
      children: [
        // ── 1. MapLibre GL Harita ────────────────────────────────────────
        ml.MapLibreMap(
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

        // ── 2. Beta Bandı ────────────────────────────────────────────────
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'MapLibre Beta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 3. Yükleniyor göstergesi ────────────────────────────────────
        if (!_styleLoaded)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'MapLibre GL yükleniyor...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';

/// Rapor sayfası Harita sekmesi — MapLibre ile bölge puanlarını görselleştirir.
class ReportMapView extends StatefulWidget {
  final ValueChanged<RegionalSite>? onSiteFocused;

  const ReportMapView({super.key, this.onSiteFocused});

  @override
  State<ReportMapView> createState() => _ReportMapViewState();
}

class _ReportMapViewState extends State<ReportMapView> {
  ml.StyleController? _styleController;
  bool _mapReady = false;

  String _styleUrl(bool isDark) => isDark
      ? 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json'
      : 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeViewModel>();
    final reportVM = context.watch<ReportViewModel>();
    final report = reportVM.report;
    final items = report?.items ?? [];

    return Stack(
      children: [
        ml.MapLibreMap(
          options: ml.MapOptions(
            initCenter: ml.Position(35.2433, 38.9637),
            initZoom: 5.5,
            initStyle: _styleUrl(theme.isDarkMode),
            maxZoom: 12,
            minZoom: 4,
          ),
          onMapCreated: (_) {},
          onStyleLoaded: (style) {
            _styleController = style;
            setState(() => _mapReady = true);
            _addMarkerSource(style, items);
          },
        ),
        // Veri yoksa bilgi
        if (items.isEmpty && !reportVM.isBusy)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Rapor verisi yükleyin — haritada bölge puanları görünecek',
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
              ),
            ),
          ),
        if (reportVM.isBusy)
          const Center(child: CircularProgressIndicator()),
        // Lejant
        if (items.isNotEmpty)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Puan', style: TextStyle(
                      color: theme.textColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  _legendRow(Colors.green, 'Yüksek (≥70)', theme),
                  _legendRow(Colors.orange, 'Orta (40-70)', theme),
                  _legendRow(Colors.red, 'Düşük (<40)', theme),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _legendRow(Color color, String label, ThemeViewModel theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(
            shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: theme.secondaryTextColor, fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _addMarkerSource(ml.StyleController style, List<RegionalSite> items) async {
    if (items.isEmpty) return;

    final features = items.map((site) {
      final color = site.overallScore >= 70
          ? '#4CAF50'
          : site.overallScore >= 40
              ? '#FF9800'
              : '#F44336';
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [site.longitude, site.latitude],
        },
        'properties': {
          'score': site.overallScore,
          'color': color,
          'name': '${site.city}${site.district != null ? ' / ${site.district}' : ''}',
          'radius': (site.overallScore / 10).clamp(4.0, 10.0),
        },
      };
    }).toList();

    final geojson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    try {
      await style.addSource(
        ml.GeoJsonSource(id: 'report-sites', data: geojson),
      );
      await style.addLayer(
        ml.CircleStyleLayer(
          id: 'report-sites-circles',
          sourceId: 'report-sites',
          paint: {
            'circle-radius': ['get', 'radius'],
            'circle-color': ['get', 'color'],
            'circle-opacity': 0.8,
            'circle-stroke-width': 1.5,
            'circle-stroke-color': '#ffffff',
          },
        ),
      );
    } catch (e) {
      debugPrint('[ReportMapView] Marker source hatası: $e');
    }
  }

  @override
  void didUpdateWidget(covariant ReportMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady && _styleController != null) {
      _refreshMarkers();
    }
  }

  Future<void> _refreshMarkers() async {
    final reportVM = context.read<ReportViewModel>();
    final items = reportVM.report?.items ?? [];
    final style = _styleController;
    if (style == null) return;

    try {
      await style.removeLayer('report-sites-circles');
      await style.removeSource('report-sites');
    } catch (_) {}
    await _addMarkerSource(style, items);
  }
}

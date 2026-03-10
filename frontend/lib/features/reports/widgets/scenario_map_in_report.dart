import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:frontend/features/map/viewmodels/map_view_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/features/map/widgets/map_constants.dart';

class ScenarioMapInReport extends StatelessWidget {
  final MapController mapController;
  final int scenarioId;

  const ScenarioMapInReport({
    super.key,
    required this.mapController,
    required this.scenarioId,
  });

  @override
  Widget build(BuildContext context) {
    final scenarioViewModel = Provider.of<ScenarioViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);
    final scenario = scenarioViewModel.scenarios.firstWhere(
      (s) => s.id == scenarioId,
      orElse: () => scenarioViewModel.scenarios.first,
    );

    // Senaryodaki pinleri bul
    final scenarioPins = mapViewModel.pins
        .where((p) => scenario.pinIds.contains(p.id))
        .toList();

    final markers = <Marker>[];
    for (var pin in scenarioPins) {
      final color = pin.type == 'Güneş Paneli'
          ? Colors.orangeAccent
          : pin.type == 'HES'
              ? Colors.cyanAccent
              : Colors.blueAccent;
      markers.add(
        Marker(
          point: LatLng(pin.latitude, pin.longitude),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Tooltip(
            message: '${pin.name} (${pin.type})',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.9),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                pin.type == 'Güneş Paneli'
                    ? Icons.wb_sunny
                    : pin.type == 'HES'
                        ? Icons.waves
                        : Icons.wind_power,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      );
    }

    // Harita merkezi hesapla
    LatLng center = const LatLng(39.0, 35.0);
    double zoom = 6.0;
    if (scenarioPins.isNotEmpty) {
      double avgLat =
          scenarioPins.map((p) => p.latitude).reduce((a, b) => a + b) /
          scenarioPins.length;
      double avgLon =
          scenarioPins.map((p) => p.longitude).reduce((a, b) => a + b) /
          scenarioPins.length;
      center = LatLng(avgLat, avgLon);
      zoom = scenarioPins.length == 1 ? 9.0 : 7.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text(
                '${scenario.name} - Harita',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '${scenarioPins.length} kaynak',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                maxZoom: MapConstants.maxZoom,
                minZoom: 5.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConstants.getTileUrl('dark'),
                  tileProvider: NetworkTileProvider(),
                  userAgentPackageName: 'frontend',
                ),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/map_utils.dart';
import '../../../data/models/system_data_models.dart';
import '../../../presentation/viewmodels/report_view_model.dart';
import '../map/map_constants.dart';

class ReportMap extends StatelessWidget {
  final MapController mapController;
  final String type;
  final ValueChanged<RegionalSite> onSiteFocused;

  const ReportMap({
    super.key,
    required this.mapController,
    required this.type,
    required this.onSiteFocused,
  });

  Color _colorForRank(int index, int total) {
    if (total <= 1) return Colors.greenAccent;
    final t = index / (total - 1);
    return Color.lerp(Colors.greenAccent, Colors.redAccent, t) ??
        Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final reportViewModel = Provider.of<ReportViewModel>(context);
    final report = reportViewModel.report;

    final markers = <Marker>[];
    if (report != null) {
      for (var i = 0; i < report.items.length; i++) {
        final site = report.items[i];
        final color = _colorForRank(i, report.items.length);
        markers.add(
          Marker(
            point: LatLng(site.latitude, site.longitude),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => onSiteFocused(site),
              child: Tooltip(
                message:
                    '${site.city}${site.district != null ? ' / ${site.district}' : ''}\nSkor: ${site.overallScore.toStringAsFixed(1)}',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.8),
                    border: Border.all(color: Colors.white70, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text(
                report != null
                    ? '${report.region} • ${report.type}'
                    : 'Yükleniyor...',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (reportViewModel.isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds(
                    const LatLng(
                      MapConstants.turkeyMinLat,
                      MapConstants.turkeyMinLon,
                    ),
                    const LatLng(
                      MapConstants.turkeyMaxLat,
                      MapConstants.turkeyMaxLon,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                maxZoom: MapConstants.maxZoom,
                minZoom: 5.5,
                onPositionChanged: (pos, hasGesture) {
                  if (!hasGesture) return;
                  _constrainToTurkey(pos.center);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConstants.getTileUrl('dark'),
                  tileProvider: CancellableNetworkTileProvider(),
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

  void _constrainToTurkey(LatLng? center) {
    if (center == null) return;
    MapUtils.constrainMapCamera(mapController);
  }
}

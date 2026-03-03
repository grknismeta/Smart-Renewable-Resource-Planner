import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/utils/geo_utils.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/core/constants/map_constants.dart';
import 'package:frontend/features/map/layers/map_layers_system.dart';
import 'package:frontend/features/map/layers/data_points_layer.dart';
import 'package:frontend/features/map/dialogs/map_dialogs.dart';
import 'package:frontend/features/map/widgets/map_markers.dart';

/// The core map engine widget using FlutterMap
class MapView extends StatefulWidget {
  final MapController mapController;
  final String selectedBaseMap;
  final Function(TapPosition, LatLng)? onMapTap;
  final Function(LatLng)? onHover;
  final VoidCallback? onExitRange;

  const MapView({
    super.key,
    required this.mapController,
    required this.selectedBaseMap,
    this.onMapTap,
    this.onHover,
    this.onExitRange,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final GlobalKey _mapKey = GlobalKey();

  void _constrainToTurkey(LatLng center) {
    MapUtils.constrainMapCamera(widget.mapController);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);

    // Prepare data
    final pins = mapViewModel.pins;
    final markers = pins.map((pin) {
      return Marker(
        width: 50.0,
        height: 50.0,
        point: LatLng(pin.latitude, pin.longitude),
        child: GestureDetector(
          onTap: () => MapDialogs.showPinActionsDialog(context, pin),
          child: MapMarkerIcon(type: pin.type),
        ),
      );
    }).toList();

    // Add Optimized Placement Markers
    if (mapViewModel.optimizationResult != null) {
       final optimizedMarkers = mapViewModel.optimizationResult!.points.map((point) {
          final windSpeed = point.windSpeedMs;
          final production = point.annualProductionKwh;
          return Marker(
            width: 40.0,
            height: 40.0,
            point: LatLng(point.latitude, point.longitude),
            child: Tooltip(
              message: 'Rüzgar: ${windSpeed.toStringAsFixed(1)} m/s\nÜretim: ${production.toStringAsFixed(0)} kWh',
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.lightBlueAccent, width: 2),
                ),
                child: const Icon(Icons.wind_power, color: Colors.white, size: 24),
              ),
            ),
          );
       }).toList();
       markers.addAll(optimizedMarkers);
    }

    return MouseRegion(
      onHover: (event) {
        try {
          final camera = widget.mapController.camera;
          final point = camera.offsetToCrs(event.localPosition);
          widget.onHover?.call(point);
        } catch (_) {}
      },
      onExit: (_) => widget.onExitRange?.call(),
      child: FlutterMap(
        key: _mapKey,
        mapController: widget.mapController,
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds(
              const LatLng(MapConstants.turkeyMinLat, MapConstants.turkeyMinLon),
              const LatLng(MapConstants.turkeyMaxLat, MapConstants.turkeyMaxLon),
            ),
            padding: const EdgeInsets.all(12),
          ),
          minZoom: 5.8,
          maxZoom: MapConstants.maxZoom,
          onPositionChanged: (position, hasGesture) {
            if (hasGesture) {
              _constrainToTurkey(position.center);
            }
          },
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: widget.onMapTap,
          backgroundColor: theme.mapBackgroundColor,
        ),
        children: [
          // 1. Tile Layer
          TileLayer(
            tileProvider: CancellableNetworkTileProvider(),
            urlTemplate: MapConstants.getTileUrl(widget.selectedBaseMap),
            keepBuffer: 10,
            panBuffer: 1,
          ),

          // 2. Heatmap Layer
          if (mapViewModel.currentLayer != MapLayerType.none)
            Stack(
              children: [
                MapLayerWidget(
                  data: mapViewModel.heatmapPoints,
                  layerType: mapViewModel.currentLayer,
                  opacity: mapViewModel.isHeatmapLoading ? 0.4 : 0.6,
                ),
                 if (mapViewModel.isHeatmapLoading)
                  const Positioned(
                    top: 20,
                    right: 20,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

          // 2.1. Data Points Layer (Above Heatmap, Below Markers)
          if (mapViewModel.currentLayer != MapLayerType.none)
             DataPointsLayer(mapViewModel: mapViewModel),

          // 3. User Selection & Restricted Areas
          // TODO: Implement Restricted Areas drawing if needed locally or via VM
          // For now handling selection polygons
          if (mapViewModel.selectionPoints.isNotEmpty)
             PolygonLayer(
               polygons: [
                 Polygon(
                    points: mapViewModel.selectionPoints,
                    color: Colors.blue.withValues(alpha: 0.3),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                 ),
               ],
             ),

          // 4. Markers
          MarkerLayer(markers: markers),

          // 5. Selection Drag Handles
          if (mapViewModel.selectionPoints.isNotEmpty)
            MarkerLayer(markers: _buildSelectionPointMarkers(mapViewModel)),
        ],
      ),
    );
  }

  List<Marker> _buildSelectionPointMarkers(MapViewModel mapViewModel) {
    if (mapViewModel.selectionPoints.isEmpty) return [];

    return List.generate(mapViewModel.selectionPoints.length, (index) {
      final point = mapViewModel.selectionPoints[index];
      final isDragging = mapViewModel.draggingPointIndex == index;

      return Marker(
        width: isDragging ? 56 : 48,
        height: isDragging ? 56 : 48,
        point: point,
        child: Tooltip(
          message: 'Sürükle | Uzun basıp tut: Sil',
          child: GestureDetector(
            onPanStart: (_) => mapViewModel.startDraggingPoint(index),
            onPanUpdate: (details) {
              try {
                final renderBox = _mapKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final localPosition = renderBox.globalToLocal(details.globalPosition);
                final camera = widget.mapController.camera;
                var newPoint = camera.offsetToCrs(localPosition);
                newPoint = LatLng(
                  newPoint.latitude.clamp(MapConstants.turkeyMinLat, MapConstants.turkeyMaxLat),
                  newPoint.longitude.clamp(MapConstants.turkeyMinLon, MapConstants.turkeyMaxLon),
                );
                mapViewModel.dragPoint(newPoint);
              } catch (e) {
                // Ignore
              }
            },
            onPanEnd: (_) => mapViewModel.endDraggingPoint(),
            onLongPress: () => mapViewModel.removePointAt(index),
            child: Container(
              decoration: BoxDecoration(
                color: isDragging ? Colors.orange : Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDragging ? Colors.orangeAccent : Colors.lightBlue,
                  width: isDragging ? 4 : 3,
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isDragging ? 14 : 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

// presentation/widgets/map/flutter_map_view.dart
//
// Sorumluluk: FlutterMap widget'ı - map rendering logic
// Markers, polygons, circles burada

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../providers/map_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../features/map/viewmodels/map_screen_viewmodel.dart';
import 'map_constants.dart';
import 'map_widgets.dart';
import 'map_dialogs.dart';

/// Flutter Map rendering widget - separated for clarity
class FlutterMapView extends StatefulWidget {
  final MapController mapController;
  final String selectedBaseMap;

  const FlutterMapView({
    super.key,
    required this.mapController,
    required this.selectedBaseMap,
  });

  @override
  State<FlutterMapView> createState() => _FlutterMapViewState();
}

class _FlutterMapViewState extends State<FlutterMapView> {
  final GlobalKey<State> _mapKey = GlobalKey<State>();
  LatLng? _hoverPosition;

  // Turkey bounds
  static const double _minLat = 35.5;
  static const double _maxLat = 42.5;
  static const double _minLon = 25.5;
  static const double _maxLon = 45.0;

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // Region selection mode
    if (mapProvider.isSelectingRegion) {
      final clamped = LatLng(
        point.latitude.clamp(_minLat, _maxLat),
        point.longitude.clamp(_minLon, _maxLon),
      );
      mapProvider.recordSelectionPoint(clamped);
      return;
    }

    // Pin placement mode
    if (mapProvider.placingPinType != null) {
      MapDialogs.showAddPinDialog(context, point, mapProvider.placingPinType!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);

    return Stack(
      children: [
        _buildMap(mapProvider, theme),
        if (_hoverPosition != null && mapProvider.currentLayer != MapLayer.none)
          _buildHoverInfo(mapProvider, theme),
      ],
    );
  }

  Widget _buildMap(MapProvider mapProvider, ThemeProvider theme) {
    final markers = _buildMarkers(mapProvider);
    final weatherCircles = _buildWeatherCircles(mapProvider);
    final polygons = _buildSelectionPolygons(mapProvider);

    return MouseRegion(
      onHover: (event) {
        try {
          final camera = widget.mapController.camera;
          final point = camera.offsetToCrs(event.localPosition);
          setState(() => _hoverPosition = point);
        } catch (_) {}
      },
      onExit: (_) => setState(() => _hoverPosition = null),
      child: FlutterMap(
        key: _mapKey,
        mapController: widget.mapController,
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds(
              const LatLng(_minLat, _minLon),
              const LatLng(_maxLat, _maxLon),
            ),
            padding: const EdgeInsets.all(12),
          ),
          minZoom: 5.8,
          maxZoom: MapConstants.maxZoom,
          onPositionChanged: (position, hasGesture) {
            if (hasGesture) _constrainToTurkey(position.center);
          },
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: _handleMapTap,
          backgroundColor: theme.mapBackgroundColor,
        ),
        children: [
          TileLayer(
            tileProvider: CancellableNetworkTileProvider(),
            urlTemplate: MapConstants.getTileUrl(widget.selectedBaseMap),
            keepBuffer: 10,
            panBuffer: 1,
          ),
          if (weatherCircles.isNotEmpty) CircleLayer(circles: weatherCircles),
          if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
          MarkerLayer(markers: _buildSelectionPointMarkers(mapProvider)),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(MapProvider mapProvider) {
    final markers = mapProvider.pins.map((pin) {
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

    // Add optimization markers
    if (mapProvider.optimizationResult != null) {
      final optimizedMarkers = mapProvider.optimizationResult!.points.map((
        point,
      ) {
        return Marker(
          width: 40.0,
          height: 40.0,
          point: LatLng(point.latitude, point.longitude),
          child: Tooltip(
            message:
                'Rüzgar: ${point.windSpeedMs.toStringAsFixed(1)} m/s\\nÜretim: ${point.annualProductionKwh.toStringAsFixed(0)} kWh',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.lightBlueAccent, width: 2),
              ),
              child: const Icon(
                Icons.wind_power,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      }).toList();
      markers.addAll(optimizedMarkers);
    }

    return markers;
  }

  List<CircleMarker> _buildWeatherCircles(MapProvider mapProvider) {
    if (mapProvider.currentLayer == MapLayer.none) return [];
    if (mapProvider.weatherData.isEmpty) return [];

    return mapProvider.weatherData.map((city) {
      final value = mapProvider.currentLayer == MapLayer.temp
          ? city.temperature
          : city.windSpeed;
      final color = mapProvider.currentLayer == MapLayer.temp
          ? MapScreenViewModel.getTemperatureColor(value)
          : MapScreenViewModel.getWindColor(value);

      return CircleMarker(
        point: LatLng(city.lat, city.lon),
        radius: 15,
        color: color.withValues(alpha: 0.6),
        borderColor: color,
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  List<Polygon> _buildSelectionPolygons(MapProvider mapProvider) {
    if (mapProvider.selectionPoints.isEmpty) return [];

    return [
      Polygon(
        points: mapProvider.selectionPoints,
        color: Colors.blue.withValues(alpha: 0.3),
        borderColor: Colors.blue,
        borderStrokeWidth: 2,
      ),
    ];
  }

  List<Marker> _buildSelectionPointMarkers(MapProvider mapProvider) {
    if (mapProvider.selectionPoints.isEmpty) return [];

    return List.generate(mapProvider.selectionPoints.length, (index) {
      final point = mapProvider.selectionPoints[index];
      final isDragging = mapProvider.draggingPointIndex == index;

      return Marker(
        width: isDragging ? 56 : 48,
        height: isDragging ? 56 : 48,
        point: point,
        child: GestureDetector(
          onPanStart: (_) => mapProvider.startDraggingPoint(index),
          onPanUpdate: (details) => _handlePointDrag(details, mapProvider),
          onPanEnd: (_) => mapProvider.endDraggingPoint(),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            mapProvider.removePointAt(index);
          },
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
      );
    });
  }

  void _handlePointDrag(DragUpdateDetails details, MapProvider mapProvider) {
    try {
      final renderBox =
          _mapKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final localPosition = renderBox.globalToLocal(details.globalPosition);
      final camera = widget.mapController.camera;
      var newPoint = camera.offsetToCrs(localPosition);

      newPoint = LatLng(
        newPoint.latitude.clamp(_minLat, _maxLat),
        newPoint.longitude.clamp(_minLon, _maxLon),
      );

      mapProvider.dragPoint(newPoint);
    } catch (e) {
      print('Drag error: $e');
    }
  }

  Widget _buildHoverInfo(MapProvider mapProvider, ThemeProvider theme) {
    final nearestCity = mapProvider.findNearestCity(_hoverPosition!);
    if (nearestCity == null) return const SizedBox.shrink();

    final isTemp = mapProvider.currentLayer == MapLayer.temp;
    final value = isTemp ? nearestCity.temperature : nearestCity.windSpeed;
    final unit = isTemp ? '°C' : 'm/s';
    final icon = isTemp ? Icons.thermostat : Icons.air;
    final color = isTemp
        ? MapScreenViewModel.getTemperatureColor(value)
        : MapScreenViewModel.getWindColor(value);

    return Positioned(
      top: 100,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nearestCity.cityName,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(1)} $unit',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _constrainToTurkey(LatLng? center) {
    if (center == null) return;

    double newLat = center.latitude.clamp(_minLat, _maxLat);
    double newLon = center.longitude.clamp(_minLon, _maxLon);

    if (newLat != center.latitude || newLon != center.longitude) {
      Future.microtask(() {
        widget.mapController.move(
          LatLng(newLat, newLon),
          widget.mapController.camera.zoom,
        );
      });
    }
  }
}

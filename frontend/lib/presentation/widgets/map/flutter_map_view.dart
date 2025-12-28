// presentation/widgets/map/flutter_map_view.dart
//
// Sorumluluk: FlutterMap widget'ı - map rendering logic
// Markers, polygons, circles burada

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../presentation/viewmodels/map_view_model.dart';
import '../../../presentation/viewmodels/theme_view_model.dart';
import '../../features/map/viewmodels/map_screen_viewmodel.dart';
import 'map_widgets.dart';

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

  Future<void> _handleMapTap(TapPosition tapPosition, LatLng point) async {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);

    // Region selection mode
    if (mapViewModel.isSelectingRegion) {
      final clamped = LatLng(
        point.latitude.clamp(
          MapConstants.turkeyMinLat,
          MapConstants.turkeyMaxLat,
        ),
        point.longitude.clamp(
          MapConstants.turkeyMinLon,
          MapConstants.turkeyMaxLon,
        ),
      );
      mapViewModel.recordSelectionPoint(clamped);
      return;
    }

    // Pin placement mode
    if (mapViewModel.placingPinType != null) {
      // 1. Analizi Başlat
      await mapViewModel.analyzeLocation(point);

      if (!mounted) return;

      final result = mapViewModel.latestGeoAnalysis;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analiz yapılamadı, lütfen tekrar deneyin.'),
          ),
        );
        return;
      }

      final bool isSuitable = result['suitable'] ?? false;
      final String recommendation = result['recommendation'] ?? '';

      // 2. Sonucu Göster
      if (!isSuitable) {
        // UYGUN DEĞİL - EKRANA BAS
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⛔ Kurulum Yapılamaz'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bu bölge coğrafi kısıtlamalar nedeniyle (Deniz, Göl, Yol, Bina, Eğim vb.) uygun değildir.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  mapViewModel.clearGeoAnalysis(); // Kırmızı alanı temizle
                  Navigator.pop(ctx);
                },
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      } else {
        // UYGUN - RİSK KONTROLÜ
        final bool isSolar = mapViewModel.placingPinType == 'Güneş Paneli';
        final details = isSolar
            ? result['solar_details']
            : result['wind_details'];
        final bool specificSuitable = details != null
            ? details['suitable']
            : true;

        if (!specificSuitable) {
          // Genel uygun ama bu tür için riskli
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('⚠️ Uyarı'),
              content: Text(
                'Bu bölge genel olarak uygun olsa da, seçtiğiniz tür ($isSolar) için riskli olabilir.\n\nSebep: ${recommendation}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    MapDialogs.showAddPinDialog(
                      context,
                      point,
                      mapViewModel.placingPinType!,
                    );
                  },
                  child: const Text('Yine de Ekle'),
                ),
              ],
            ),
          );
        } else {
          // HER ŞEY MÜKEMMEL
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(recommendation),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          MapDialogs.showAddPinDialog(
            context,
            point,
            mapViewModel.placingPinType!,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapViewModel = Provider.of<MapViewModel>(context);
    final themeViewModel = Provider.of<ThemeViewModel>(context);

    return Stack(
      children: [
        _buildMap(mapViewModel, themeViewModel),
        if (_hoverPosition != null &&
            mapViewModel.currentLayer != MapLayer.none)
          _buildHoverInfo(mapViewModel, themeViewModel),
      ],
    );
  }

  Widget _buildMap(MapViewModel mapViewModel, ThemeViewModel theme) {
    final markers = _buildMarkers(mapViewModel);
    final weatherCircles = _buildWeatherCircles(mapViewModel);
    final polygons = _buildSelectionPolygons(mapViewModel);

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
          initialCenter: const LatLng(
            MapConstants.turkeyCenterLat,
            MapConstants.turkeyCenterLon,
          ),
          initialZoom: MapConstants.initialZoom,
          cameraConstraint: CameraConstraint.contain(
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
          ),
          minZoom: MapConstants.minZoom,
          maxZoom: MapConstants.maxZoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: _handleMapTap,
          backgroundColor: theme.mapBackgroundColor,
        ),
        children: [
          TileLayer(
            tileProvider: NetworkTileProvider(),
            urlTemplate: MapConstants.getTileUrl(widget.selectedBaseMap),
            maxNativeZoom: MapConstants.maxNativeZoom.ceil(),
            userAgentPackageName: 'com.srrp.frontend',
            keepBuffer: 10,
            panBuffer: 1,
          ),
          if (weatherCircles.isNotEmpty) CircleLayer(circles: weatherCircles),
          if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
          // Restricted Area Layer (Hatch Pattern Simulation - Red semi-transparent)
          if (mapViewModel.restrictedArea.isNotEmpty)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: mapViewModel.restrictedArea,
                  color: Colors.red.withValues(alpha: 0.4),
                  borderColor: Colors.red,
                  borderStrokeWidth: 3,
                ),
              ],
            ),
          MarkerLayer(markers: _buildSelectionPointMarkers(mapViewModel)),
          MarkerLayer(markers: markers),
          if (mapViewModel.isAnalyzingGeo)
            const Center(
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text("Arazi Analiz Ediliyor..."),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(MapViewModel mapViewModel) {
    final markers = mapViewModel.pins.map((pin) {
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
    if (mapViewModel.optimizationResult != null) {
      final optimizedMarkers = mapViewModel.optimizationResult!.points.map((
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

  List<CircleMarker> _buildWeatherCircles(MapViewModel mapViewModel) {
    if (mapViewModel.currentLayer == MapLayer.none) return [];
    if (mapViewModel.weatherData.isEmpty) return [];

    return mapViewModel.weatherData.map((city) {
      final value = mapViewModel.currentLayer == MapLayer.temp
          ? city.temperature
          : city.windSpeed;
      final color = mapViewModel.currentLayer == MapLayer.temp
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

  List<Polygon> _buildSelectionPolygons(MapViewModel mapViewModel) {
    if (mapViewModel.selectionPoints.isEmpty) return [];

    return [
      Polygon(
        points: mapViewModel.selectionPoints,
        color: Colors.blue.withValues(alpha: 0.3),
        borderColor: Colors.blue,
        borderStrokeWidth: 2,
      ),
    ];
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
        child: GestureDetector(
          onPanStart: (_) => mapViewModel.startDraggingPoint(index),
          onPanUpdate: (details) => _handlePointDrag(details, mapViewModel),
          onPanEnd: (_) => mapViewModel.endDraggingPoint(),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            mapViewModel.removePointAt(index);
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

  void _handlePointDrag(DragUpdateDetails details, MapViewModel mapViewModel) {
    try {
      final renderBox =
          _mapKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final localPosition = renderBox.globalToLocal(details.globalPosition);
      final camera = widget.mapController.camera;
      var newPoint = camera.offsetToCrs(localPosition);

      newPoint = LatLng(
        newPoint.latitude.clamp(
          MapConstants.turkeyMinLat,
          MapConstants.turkeyMaxLat,
        ),
        newPoint.longitude.clamp(
          MapConstants.turkeyMinLon,
          MapConstants.turkeyMaxLon,
        ),
      );

      mapViewModel.dragPoint(newPoint);
    } catch (e) {
      debugPrint('Drag error: $e');
    }
  }

  Widget _buildHoverInfo(MapViewModel mapViewModel, ThemeViewModel theme) {
    final nearestCity = mapViewModel.findNearestCity(_hoverPosition!);
    if (nearestCity == null) return const SizedBox.shrink();

    final isTemp = mapViewModel.currentLayer == MapLayer.temp;
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
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../presentation/viewmodels/map_view_model.dart';
import '../../presentation/viewmodels/theme_view_model.dart';
import '../widgets/sidebar/sidebar_widgets.dart';
import '../widgets/map/map_widgets.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<State> _mapKey = GlobalKey<State>();

  bool _showLayersPanel = false;
  String _selectedBaseMap = 'dark';
  // Zaman slider penceresinin üst sınırı (sabit referans)
  // Mouse hover için
  LatLng? _hoverPosition;

  // Türkiye sınırları
  static const double _minLat = 35.5;
  static const double _maxLat = 42.5;
  static const double _minLon = 25.5;
  static const double _maxLon = 45.0;

  @override
  void initState() {
    super.initState();
    // MapViewModel constructor zaten AuthViewModel'ı kontrol ediyor ve pins'i yüklemek için dinlemeyi ayarladı
    // İlk yüklemede hava durumu verilerini çek
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
      mapViewModel.loadWeatherForTime(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
    });
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) async {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);

    // Bölge seçim modundaysa
    if (mapViewModel.isSelectingRegion) {
      final clamped = LatLng(
        point.latitude.clamp(_minLat, _maxLat),
        point.longitude.clamp(_minLon, _maxLon),
      );
      mapViewModel.recordSelectionPoint(clamped);
      return;
    }

    // Pin yerleştirme modundaysa
    if (mapViewModel.placingPinType != null) {
      MapDialogs.showAddPinDialog(context, point, mapViewModel.placingPinType!);
    }
  }

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  void _constrainToTurkey(LatLng center) {
    final clampedLat = center.latitude.clamp(_minLat, _maxLat);
    final clampedLon = center.longitude.clamp(_minLon, _maxLon);

    if (clampedLat != center.latitude || clampedLon != center.longitude) {
      _mapController.move(
        LatLng(clampedLat, clampedLon),
        _mapController.camera.zoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // MapViewModel Provider.of changes to Consumer or direct usage
    // Selector is good for performance
    final theme = Provider.of<ThemeViewModel>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Selector<MapViewModel, List<dynamic>>(
      selector: (_, viewModel) => [
        viewModel.pins,
        viewModel.optimizationResult,
      ],
      shouldRebuild: (previous, next) {
        return previous[0] != next[0] || previous[1] != next[1];
      },
      builder: (context, data, _) {
        final pins = data[0] as List;
        final optimizationResult = data[1];

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

        if (optimizationResult != null) {
          final optimizedMarkers = optimizationResult.points.map((point) {
            return Marker(
              width: 40.0,
              height: 40.0,
              point: LatLng(point.latitude, point.longitude),
              child: Tooltip(
                message:
                    'Rüzgar: ${point.windSpeedMs.toStringAsFixed(1)} m/s\nÜretim: ${point.annualProductionKwh.toStringAsFixed(0)} kWh',
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

        // We need MapViewModel available for children
        final mapViewModel = Provider.of<MapViewModel>(context);

        return _buildScaffold(
          context,
          isWideScreen,
          theme,
          markers,
          mapViewModel,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    bool isWideScreen,
    ThemeViewModel theme,
    List<Marker> markers,
    MapViewModel mapViewModel,
  ) {
    return Scaffold(
      appBar: isWideScreen
          ? null
          : AppBar(
              title: const Text('SRRP'),
              backgroundColor: theme.backgroundColor,
              foregroundColor: theme.textColor,
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                // --- HARITA ---
                _buildFlutterMap(theme, markers, mapViewModel),

                // --- DASHBOARD (SOL ÜST) ---
                Positioned(
                  top: 20,
                  left: 20,
                  child: MapDashboard(theme: theme),
                ),

                // --- KONTROLLER (SAĞ ÜST) ---
                Positioned(
                  top: 20,
                  right: 20,
                  child: _buildControlsColumn(mapViewModel, theme),
                ),

                // --- IŞINIM HARITASI RENK ÖLÇEĞI (SAĞ ALT) ---
                if (mapViewModel.currentLayer == MapLayer.irradiance)
                  Positioned(
                    bottom: 40,
                    right: 20,
                    child: LegendWidget(
                      theme: theme,
                      title: 'Işınım Yoğunluğu',
                      titleFontSize: 11,
                      unit: 'kWh/m²/yıl',
                      gradientColors: [
                        Colors.blue.shade900,
                        Colors.blue.shade500,
                        Colors.green.shade500,
                        Colors.orange.shade500,
                        Colors.red.shade500,
                      ],
                      minLabel: '0',
                      maxLabel: '2200',
                    ),
                  ),

                // --- RÜZGAR HARITASI RENK ÖLÇEĞI (SAĞ ALT) ---
                if (mapViewModel.currentLayer == MapLayer.wind)
                  Positioned(
                    bottom: 40,
                    right: 20,
                    child: LegendWidget(
                      theme: theme,
                      title: 'Rüzgar Hızı',
                      unit: 'm/s',
                      gradientColors: [
                        Colors.green.shade300,
                        Colors.green,
                        Colors.yellow,
                        Colors.orange,
                        Colors.red,
                      ],
                      minLabel: '0',
                      maxLabel: '15+',
                    ),
                  ),

                // --- SICAKLIK HARITASI RENK ÖLÇEĞI (SAĞ ALT) ---
                if (mapViewModel.currentLayer == MapLayer.temp)
                  Positioned(
                    bottom: 40,
                    right: 20,
                    child: LegendWidget(
                      theme: theme,
                      title: 'Sıcaklık',
                      unit: '°C',
                      gradientColors: [
                        Colors.blue.shade900,
                        Colors.blue.shade400,
                        Colors.green,
                        Colors.orange,
                        Colors.red,
                      ],
                      minLabel: '-10',
                      maxLabel: '40+',
                    ),
                  ),
                // --- MOUSE HOVER BİLGİSİ ---
                if (_hoverPosition != null &&
                    mapViewModel.currentLayer != MapLayer.none)
                  Positioned(
                    top: 100,
                    left: 20,
                    child: _buildHoverInfo(theme, mapViewModel),
                  ),

                //

                // --- PIN YERLEŞTIRME UYARISI ---
                if (mapViewModel.placingPinType != null)
                  Positioned(
                    bottom: 180,
                    left: 0,
                    right: 0,
                    child: PlacementIndicator(
                      placingPinType: mapViewModel.placingPinType,
                      onCancel: mapViewModel.stopPlacingMarker,
                    ),
                  ),

                // --- BÖLGE SEÇİM UYARISI ---
                if (mapViewModel.isSelectingRegion)
                  Positioned(
                    bottom: mapViewModel.placingPinType != null ? 280 : 180,
                    left: 0,
                    right: 0,
                    child: RegionSelectionIndicator(
                      points: mapViewModel.selectionPoints,
                      onCancel: mapViewModel.clearRegionSelection,
                    ),
                  ),

                // --- ZOOM KONTROLLERI ---
                Positioned(
                  bottom: 80, // Ölçeğin üstünde
                  left: 20,
                  child: ZoomControls(
                    theme: theme,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                  ),
                ),
                // Sidebar launcher
                Positioned(top: 80, left: 20, child: SidebarLauncher()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlutterMap(
    ThemeViewModel theme,
    List<Marker> markers,
    MapViewModel mapViewModel,
  ) {
    // Hava durumu katman circle'larını sadece gerektiğinde oluştur
    final weatherCircles =
        (mapViewModel.currentLayer == MapLayer.wind ||
            mapViewModel.currentLayer == MapLayer.temp)
        ? _buildWeatherCircles(mapViewModel)
        : <CircleMarker>[];

    // Işınım harita grid'ini sadece gerektiğinde oluştur
    final irradianceLayer = mapViewModel.currentLayer == MapLayer.irradiance
        ? _buildIrradianceLayer(mapViewModel)
        : null;

    // Seçim dikdörtgeni oluştur
    final polygons = _buildSelectionPolygons(mapViewModel);

    return MouseRegion(
      onHover: (event) {
        // Mouse pozisyonunu LatLng'e çevir
        try {
          // flutter_map için doğru yöntem
          final camera = _mapController.camera;
          final point = camera.offsetToCrs(event.localPosition);
          setState(() => _hoverPosition = point);
        } catch (_) {}
      },
      onExit: (_) => setState(() => _hoverPosition = null),
      child: FlutterMap(
        key: _mapKey,
        mapController: _mapController,
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
          // Türkiye sınırları dışına çıkılmasını engelle
          onPositionChanged: (position, hasGesture) {
            if (hasGesture) {
              _constrainToTurkey(position.center);
            }
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
            urlTemplate: MapConstants.getTileUrl(_selectedBaseMap),
            keepBuffer: 10,
            panBuffer: 1,
          ),
          // Işınım katmanı
          if (mapViewModel.currentLayer == MapLayer.irradiance &&
              irradianceLayer != null)
            irradianceLayer,
          // Hava durumu katmanı (Rüzgar ve Sıcaklık)
          if ((mapViewModel.currentLayer == MapLayer.wind ||
                  mapViewModel.currentLayer == MapLayer.temp) &&
              weatherCircles.isNotEmpty)
            CircleLayer(circles: weatherCircles),
          // Bölge seçim polygon'u
          if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
          // Bölge seçim köşe noktaları (sürüklenebilir)
          MarkerLayer(markers: _buildSelectionPointMarkers(mapViewModel)),
          // Pinler
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  /// Bölge seçimi için çokgen polygon'u oluştur (sürüklenebilir köşelerle)
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

  /// Seçim köşe noktaları için marker'ları oluştur (sürüklenebilir)
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
                // Haritanın render box'ını al
                final renderBox =
                    _mapKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox == null) return;

                // Global pozisyonu harita local'ine çevir
                final localPosition = renderBox.globalToLocal(
                  details.globalPosition,
                );

                // Harita kamerasından çevir
                final camera = _mapController.camera;
                var newPoint = camera.offsetToCrs(localPosition);
                // Sınırlar içinde tut
                newPoint = LatLng(
                  newPoint.latitude.clamp(_minLat, _maxLat),
                  newPoint.longitude.clamp(_minLon, _maxLon),
                );

                mapViewModel.dragPoint(newPoint);
              } catch (e) {
                debugPrint('Drag hatası: $e');
              }
            },
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: isDragging ? 12 : 8,
                    spreadRadius: isDragging ? 2 : 0,
                  ),
                ],
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

  /// Hava durumu verilerine göre circle marker'ları oluştur
  List<CircleMarker> _buildWeatherCircles(MapViewModel mapViewModel) {
    // Işınım katmanında hava durumu gösterme
    if (mapViewModel.currentLayer == MapLayer.none ||
        mapViewModel.currentLayer == MapLayer.irradiance) {
      return [];
    }

    final weatherData = mapViewModel.weatherData;
    if (weatherData.isEmpty) return [];

    return weatherData.map((city) {
      final value = mapViewModel.currentLayer == MapLayer.temp
          ? city.temperature
          : city.windSpeed;

      final color = mapViewModel.currentLayer == MapLayer.temp
          ? _getTemperatureColor(value)
          : _getWindColor(value);

      return CircleMarker(
        point: LatLng(city.lat, city.lon),
        radius: 15,
        color: color.withValues(alpha: 0.6),
        borderColor: color,
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  /// Sıcaklık değerine göre renk
  Color _getTemperatureColor(double temp) {
    if (temp < 0) return Colors.blue.shade900;
    if (temp < 10) return Colors.blue.shade400;
    if (temp < 20) return Colors.green;
    if (temp < 30) return Colors.orange;
    return Colors.red;
  }

  /// Rüzgar hızına göre renk
  Color _getWindColor(double speed) {
    if (speed < 3) return Colors.green.shade300;
    if (speed < 6) return Colors.green;
    if (speed < 10) return Colors.yellow;
    if (speed < 15) return Colors.orange;
    return Colors.red;
  }

  /// Işınım değerine göre renk (mavi -> kırmızı)
  Color _getIrradianceColor(double irradiance) {
    // 0-2200 kWh/m²/yıl aralığında renk (Türkiye için daha gerçekçi)
    final normalized = (irradiance / 2200).clamp(0.0, 1.0);

    if (normalized < 0.2) return Colors.blue.shade900;
    if (normalized < 0.4) return Colors.blue.shade500;
    if (normalized < 0.6) return Colors.green.shade500;
    if (normalized < 0.8) return Colors.orange.shade500;
    return Colors.red.shade500;
  }

  /// Işınım harita katmanını oluştur
  PolygonLayer? _buildIrradianceLayer(MapViewModel mapViewModel) {
    if (mapViewModel.solarSummary.isEmpty) {
      return null;
    }

    // Harita üzerine grid olarak ışınım verilerini göster
    final polygons = mapViewModel.solarSummary.map((city) {
      final irradiance = city.totalDailyIrradianceKwhM2 ?? 0;
      final color = _getIrradianceColor(irradiance); // Zaten yıllık kWh/m²

      return Polygon(
        points: _getGridCellPoints(city.latitude, city.longitude),
        color: color.withValues(alpha: 0.6),
        borderColor: color,
        borderStrokeWidth: 1,
      );
    }).toList();

    return PolygonLayer(polygons: polygons);
  }

  /// Grid hücresi için nokta listesi oluştur
  List<LatLng> _getGridCellPoints(double lat, double lon) {
    const cellSize = 0.5; // 0.5 derece grid hücresi
    return [
      LatLng(lat - cellSize / 2, lon - cellSize / 2),
      LatLng(lat + cellSize / 2, lon - cellSize / 2),
      LatLng(lat + cellSize / 2, lon + cellSize / 2),
      LatLng(lat - cellSize / 2, lon + cellSize / 2),
    ];
  }

  Widget _buildControlsColumn(MapViewModel mapViewModel, ThemeViewModel theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Tek 'Ekle' butonu: tip seçimi bottom sheet ile
        Row(
          children: [
            GestureDetector(
              onTap: () {
                // Varsayılan olarak Güneş Paneli ile başlat, dialog içinde değiştirilebilir
                mapViewModel.startPlacingMarker('Güneş Paneli');
              },
              child: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.secondaryTextColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(Icons.add, color: theme.textColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (mapViewModel.isSelectingRegion)
          FloatingActionButton.extended(
            heroTag: 'optimization_run',
            backgroundColor: Colors.green,
            onPressed: () async {
              // CHANGE: Pass themeViewModel
              final themeProv = Provider.of<ThemeViewModel>(
                context,
                listen: false,
              );
              await mapViewModel.loadEquipments();
              if (!mounted) return;
              OptimizationDialog.show(context, mapViewModel, themeProv);
            },
            icon: const Icon(Icons.calculate),
            label: const Text('Hesapla'),
          )
        else
          FloatingActionButton.extended(
            heroTag: 'optimization_select',
            backgroundColor: Colors.blue,
            onPressed: () {
              mapViewModel.startSelectingRegion();
            },
            icon: const Icon(Icons.select_all),
            label: const Text('Bölge Seç'),
          ),
        const SizedBox(height: 10),

        // Katman paneli toggle
        FloatingActionButton.small(
          heroTag: 'layer_toggle',
          backgroundColor: theme.cardColor,
          child: Icon(Icons.layers, color: theme.textColor),
          onPressed: () => setState(() => _showLayersPanel = !_showLayersPanel),
        ),

        // Katman paneli
        if (_showLayersPanel) ...[
          const SizedBox(height: 10),
          LayersPanel(
            theme: theme,
            mapViewModel: mapViewModel, // CHANGED param name
            selectedBaseMap: _selectedBaseMap,
            onBaseMapChanged: (value) =>
                setState(() => _selectedBaseMap = value),
          ),
        ],
      ],
    );
  }

  /// Mouse hover bilgisi
  Widget _buildHoverInfo(ThemeViewModel theme, MapViewModel mapViewModel) {
    if (_hoverPosition == null) return const SizedBox.shrink();

    final nearestCity = mapViewModel.findNearestCity(_hoverPosition!);
    if (nearestCity == null) return const SizedBox.shrink();

    final isTemp = mapViewModel.currentLayer == MapLayer.temp;
    final value = isTemp ? nearestCity.temperature : nearestCity.windSpeed;
    final unit = isTemp ? '°C' : 'm/s';
    final icon = isTemp ? Icons.thermostat : Icons.air;
    final color = isTemp ? _getTemperatureColor(value) : _getWindColor(value);

    return Container(
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
                  // fontFamily: 'Roboto' (Optional)
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
    );
  }
}

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../presentation/viewmodels/map_view_model.dart';
import '../../presentation/viewmodels/theme_view_model.dart';
import '../widgets/sidebar/sidebar_widgets.dart';
import '../widgets/map/map_widgets.dart';
import '../widgets/map/resource_heatmap_layer.dart';

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

  // Restricted areas polygons to draw
  final List<List<LatLng>> _restrictedAreas = [];

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

    // Normal modda tıklandığında SADECE pin yerleştirme modu açıksa analiz yap
    if (mapViewModel.placingPinType != null) {
      _checkGeoSuitability(point);
    }
  }

  Future<void> _checkGeoSuitability(LatLng point) async {
    final theme = Provider.of<ThemeViewModel>(context, listen: false);

    // 1. Loading göster (Daha kompakt)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Text(
                "Analiz ediliyor...",
                style: TextStyle(color: theme.textColor, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 2. Backend'e sor
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.checkGeoSuitability(
        point.latitude,
        point.longitude,
      );

      // Loading kapat
      if (mounted) Navigator.pop(context);

      _handleGeoResult(point, result);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Hata durumunda da kapat
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analiz hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleGeoResult(LatLng point, Map<String, dynamic> result) {
    final bool suitable = result['suitable'] ?? false;
    final String rec = result['recommendation'] ?? '';
    final Map<String, dynamic> solar = result['solar_details'] ?? {};
    final Map<String, dynamic> wind = result['wind_details'] ?? {};

    // Yasaklı alan varsa çiz, ama referansını tutalım ki kapatınca silebilelim
    List<LatLng>? currentPolygon;
    final List<dynamic>? restrictedAreaJson = result['restricted_area'];

    if (restrictedAreaJson != null && restrictedAreaJson.isNotEmpty) {
      currentPolygon = restrictedAreaJson
          .map((p) => LatLng(p['lat'], p['lng']))
          .toList();
      setState(() {
        _restrictedAreas.add(currentPolygon!);
      });

      // Sadece yasaklıysa uyarı ver ve çık
      if (!suitable) {
        _showResultDialog(
          title: "⚠️ Kurulum Yapılamaz",
          content:
              "$rec\n\nNedenler:\n${(solar['reasons'] as List?)?.join('\n')}\n${(wind['reasons'] as List?)?.join('\n')}",
          isSuccess: false,
          onClose: () {
            // Dialog kapanınca kırmızı alanı da kaldır
            if (currentPolygon != null) {
              setState(() {
                _restrictedAreas.remove(currentPolygon);
              });
            }
          },
        );
        return;
      }
    }

    if (!suitable) {
      _showResultDialog(
        title: "⛔ Uygun Değil",
        content:
            "$rec\n\nNedenler:\n${(solar['reasons'] as List?)?.join('\n')}\n${(wind['reasons'] as List?)?.join('\n')}",
        isSuccess: false,
      );
      return;
    }

    // Uygunsa hangi tip için uygun olduğunu göster ve ekleme opsiyonu sun
    String suitableType = "Güneş Paneli"; // Varsayılan
    if (wind['suitable'] == true && solar['suitable'] == false) {
      suitableType = "Rüzgar Türbini";
    }
    if (solar['suitable'] == true && wind['suitable'] == false) {
      suitableType = "Güneş Paneli";
    }
    // İkisi de uygunsa kullanıcıya bırakabiliriz ama varsayılan Güneş

    _showResultDialog(
      title: "✅ Yerleşim Uygun",
      content:
          "$rec\n\nEğim: ${(result['slope'] ?? 0).toStringAsFixed(1)}°\nYükseklik: ${(result['elevation'] ?? 0).toStringAsFixed(0)}m",
      isSuccess: true,
      onConfirm: () {
        // Pin ekleme dialogunu aç
        MapDialogs.showAddPinDialog(context, point, suitableType);
      },
    );
  }

  void _showResultDialog({
    required String title,
    required String content,
    required bool isSuccess,
    VoidCallback? onConfirm,
    VoidCallback? onClose,
  }) {
    final theme = Provider.of<ThemeViewModel>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: theme.textColor, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: TextStyle(
            color: theme.textColor.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (onClose != null) onClose();
            },
            child: const Text("Kapat"),
          ),
          if (onConfirm != null) ...[
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Sisteme Ekle"),
            ),
          ],
        ],
      ),
    ).then((_) {
      // Dialog dışına basılıp kapanırsa da temizlik yap
      if (onClose != null) onClose();
    });
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
        viewModel.currentLayer, // Added
        viewModel.isHeatmapLoading, // Added
        viewModel.heatmapPoints, // Added
      ],
      shouldRebuild: (previous, next) {
        // Simple equality check for list elements is enough if references change
        // deep collection equality is expensive, but here heatmapPoints reference changes on update
        const listEquals = ListEquality();
        return !listEquals.equals(previous, next);
      },
      builder: (context, data, _) {
        final pins = data[0] as List;
        final optimizationResult = data[1];
        // We don't need to extract others locally as we access via mapViewModel provider below

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
          try {
            final optimizedMarkers = optimizationResult.points.map((point) {
              final windSpeed = point.windSpeedMs;
              final production = point.annualProductionKwh;

              return Marker(
                width: 40.0,
                height: 40.0,
                point: LatLng(point.latitude, point.longitude),
                child: Tooltip(
                  message:
                      'Rüzgar: ${windSpeed.toStringAsFixed(1)} m/s\nÜretim: ${production.toStringAsFixed(0)} kWh',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.lightBlueAccent,
                        width: 2,
                      ),
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
          } catch (e) {
            debugPrint('Marker oluşturma hatası: $e');
          }
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

                // --- DASHBOARD (SOL ÜSTTE EN TEPEYE) ---
                Positioned(
                  top: 20,
                  left: 20,
                  child: MapDashboard(theme: theme),
                ), // --- KONTROLLER (SAĞ ÜST) ---
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
                        Colors.black87,
                        Colors.red.shade900,
                        Colors.orange,
                        Colors.yellow,
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
                        Colors.grey.shade300,
                        Colors.blue.shade200,
                        Colors.blue.shade700,
                        Colors.deepPurple.shade900,
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
                        Colors.indigo,
                        Colors.cyan,
                        Colors.yellow,
                        Colors.red.shade900,
                      ],
                      minLabel: '-10',
                      maxLabel: '40+',
                    ),
                  ),
                // --- MOUSE HOVER BİLGİSİ (SOL ALTTA DASHBOARD'IN ALTINDA) ---
                if (_hoverPosition != null &&
                    mapViewModel.currentLayer != MapLayer.none)
                  Positioned(
                    top: 180, // Dashboard (80) + Height (~80) + Gap
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
                // Sidebar launcher (DASHBOARD'IN ALTINDA)
                Positioned(top: 110, left: 20, child: SidebarLauncher()),
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

          // YENİ MERKEZİ ISI HARİTASI KATMANI
          if (mapViewModel.currentLayer != MapLayer.none)
            Stack(
              children: [
                ResourceHeatmapLayer(
                  data: mapViewModel.heatmapPoints,
                  type: mapViewModel.heatmapType,
                  opacity: mapViewModel.isHeatmapLoading ? 0.4 : 0.6,
                ),
                if (mapViewModel.isHeatmapLoading)
                  const Positioned(
                    top: 20,
                    right: 20, // Kontrollerin altında
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

          // Yasaklı Alanlar Katmanı
          if (_restrictedAreas.isNotEmpty)
            PolygonLayer(
              polygons: _restrictedAreas
                  .map(
                    (points) => Polygon(
                      points: points,
                      color: Colors.red.withOpacity(0.3),
                      borderColor: Colors.red,
                      borderStrokeWidth: 2,
                    ),
                  )
                  .toList(),
            ),

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

  Widget _buildControlsColumn(MapViewModel mapViewModel, ThemeViewModel theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Tek 'Ekle' butonu: tip seçimi bottom sheet ile
        // Main controls using FAB style
        MainMapControls(
          theme: theme,
          onAddPin: () {
            mapViewModel.startPlacingMarker('Güneş Paneli');
          },
          onSelectRegion: () async {
            if (mapViewModel.isSelectingRegion) {
              // Zaten seçim yapılıyorsa kapat (toggle)
              mapViewModel.clearRegionSelection();
            } else {
              // Seçimi başlat
              mapViewModel.startSelectingRegion();
            }
          },
        ),
        const SizedBox(height: 10),

        // Calculate Button (only visible when selecting region) ->
        // Actually MainMapControls handles the main actions, but we might want a separate
        // "Run" button if region selection is active, OR we can make the region button toggle.
        // Let's check MainMapControls implementation...
        // It has onSelectRegion.
        // User asked for "region select button AND add pin button" to be like the layer button.
        // So I'll stick to MainMapControls for the main entry points.

        // If selecting region, we might want to change the icon of the region button in MainMapControls?
        // But MainMapControls is stateless.
        // Let's keep it simple:
        // If selecting region, show a separate "Calculate" FAB like before, OR rely on the user tapping "Region" again?
        // The previous code had a "Calculate" FAB when selecting.
        const SizedBox(height: 10),

        // Katman paneli toggle
        MapControlButton(
          icon: Icons.layers_outlined,
          tooltip: "Katmanlar",
          color: theme.textColor,
          theme: theme,
          onTap: () => setState(() => _showLayersPanel = !_showLayersPanel),
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
    // Basit renk seçimi
    final color = isTemp ? Colors.blue : Colors.green;

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

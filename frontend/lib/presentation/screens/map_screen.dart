import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/map_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/map/map_widgets.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  bool _showLayersPanel = false;
  String _selectedBaseMap = 'dark';

  // Mouse hover için
  LatLng? _hoverPosition;

  // Zaman çizelgesi için
  DateTime _selectedTime = DateTime.now();

  // Türkiye sınırları
  static const double _minLat = 35.5;
  static const double _maxLat = 42.5;
  static const double _minLon = 25.5;
  static const double _maxLon = 45.0;

  @override
  void initState() {
    super.initState();
    // İlk yüklemede hava durumu verilerini çek
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      mapProvider.loadWeatherForTime(DateTime.now());
    });
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) async {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    if (mapProvider.placingPinType != null) {
      MapDialogs.showAddPinDialog(context, point, mapProvider.placingPinType!);
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

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    // Marker listesi oluştur
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
          if (isWideScreen) const SidebarMenu(),
          Expanded(
            child: Stack(
              children: [
                // --- HARITA ---
                _buildFlutterMap(theme, markers, mapProvider),

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
                  child: _buildControlsColumn(mapProvider, theme),
                ),

                // --- MOUSE HOVER BİLGİSİ ---
                if (_hoverPosition != null &&
                    mapProvider.currentLayer != MapLayer.none)
                  Positioned(
                    top: 100,
                    left: 20,
                    child: _buildHoverInfo(theme, mapProvider),
                  ),

                // --- ZAMAN ÇİZELGESİ (ALT) ---
                Positioned(
                  bottom: 100,
                  left: 20,
                  right: 20,
                  child: _buildTimeSlider(theme, mapProvider),
                ),

                // --- PIN YERLEŞTIRME UYARISI ---
                if (mapProvider.placingPinType != null)
                  Positioned(
                    bottom: 180,
                    left: 0,
                    right: 0,
                    child: PlacementIndicator(
                      placingPinType: mapProvider.placingPinType,
                      onCancel: mapProvider.stopPlacingMarker,
                    ),
                  ),

                // --- ZOOM KONTROLLERI ---
                Positioned(
                  bottom: 40,
                  right: 20,
                  child: ZoomControls(
                    theme: theme,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlutterMap(
    ThemeProvider theme,
    List<Marker> markers,
    MapProvider mapProvider,
  ) {
    // Hava durumu katman circle'larını oluştur
    final weatherCircles = _buildWeatherCircles(mapProvider);

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
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(
            MapConstants.turkeyCenterLat,
            MapConstants.turkeyCenterLon,
          ),
          initialZoom: 6.5, // Biraz daha yakın başla
          minZoom: 6.0, // Daha az uzaklaşabilsin
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
          // Hava durumu katmanı
          if (weatherCircles.isNotEmpty) CircleLayer(circles: weatherCircles),
          // Pinler
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  /// Hava durumu verilerine göre circle marker'ları oluştur
  List<CircleMarker> _buildWeatherCircles(MapProvider mapProvider) {
    if (mapProvider.currentLayer == MapLayer.none) return [];

    final weatherData = mapProvider.weatherData;
    if (weatherData.isEmpty) return [];

    return weatherData.map((city) {
      final value = mapProvider.currentLayer == MapLayer.temp
          ? city.temperature
          : city.windSpeed;

      final color = mapProvider.currentLayer == MapLayer.temp
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

  Widget _buildControlsColumn(MapProvider mapProvider, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Kaynak ekleme butonları
        Row(
          children: [
            ResourceActionButton(
              type: 'Rüzgar Türbini',
              onTap: () => mapProvider.startPlacingMarker('Rüzgar Türbini'),
            ),
            const SizedBox(width: 12),
            ResourceActionButton(
              type: 'Güneş Paneli',
              onTap: () => mapProvider.startPlacingMarker('Güneş Paneli'),
            ),
          ],
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
            mapProvider: mapProvider,
            selectedBaseMap: _selectedBaseMap,
            onBaseMapChanged: (value) =>
                setState(() => _selectedBaseMap = value),
          ),
        ],
      ],
    );
  }

  /// Mouse hover bilgisi
  Widget _buildHoverInfo(ThemeProvider theme, MapProvider mapProvider) {
    if (_hoverPosition == null) return const SizedBox.shrink();

    // En yakın şehri bul
    final nearestCity = mapProvider.findNearestCity(_hoverPosition!);
    if (nearestCity == null) return const SizedBox.shrink();

    final isTemp = mapProvider.currentLayer == MapLayer.temp;
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

  /// Zaman çizelgesi slider'ı
  Widget _buildTimeSlider(ThemeProvider theme, MapProvider mapProvider) {
    final now = DateTime.now();
    final minTime = now.subtract(const Duration(hours: 72));
    final maxTime = now.add(const Duration(hours: 72));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Zaman Çizelgesi',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatDateTime(_selectedTime),
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blueAccent,
              inactiveTrackColor: theme.secondaryTextColor.withValues(
                alpha: 0.3,
              ),
              thumbColor: Colors.blueAccent,
              overlayColor: Colors.blueAccent.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _selectedTime.millisecondsSinceEpoch.toDouble(),
              min: minTime.millisecondsSinceEpoch.toDouble(),
              max: maxTime.millisecondsSinceEpoch.toDouble(),
              divisions: 144, // Her 1 saat için bir bölüm
              onChanged: (value) {
                setState(() {
                  _selectedTime = DateTime.fromMillisecondsSinceEpoch(
                    value.toInt(),
                  );
                });
                // Seçilen zamana göre verileri güncelle
                mapProvider.loadWeatherForTime(_selectedTime);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '-72 saat',
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedTime = DateTime.now());
                  mapProvider.loadWeatherForTime(DateTime.now());
                },
                child: const Text('Şimdi', style: TextStyle(fontSize: 12)),
              ),
              Text(
                '+72 saat',
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);

    String prefix = '';
    if (diff.inHours.abs() < 1) {
      prefix = 'Şimdi';
    } else if (diff.isNegative) {
      prefix = '${diff.inHours.abs()} saat önce';
    } else {
      prefix = '${diff.inHours} saat sonra';
    }

    return '$prefix - ${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:00';
  }

  /// Haritayı Türkiye sınırları içinde tut
  void _constrainToTurkey(LatLng? center) {
    if (center == null) return;

    double newLat = center.latitude;
    double newLon = center.longitude;
    bool needsUpdate = false;

    // Enlem sınırları
    if (newLat < _minLat) {
      newLat = _minLat;
      needsUpdate = true;
    } else if (newLat > _maxLat) {
      newLat = _maxLat;
      needsUpdate = true;
    }

    // Boylam sınırları
    if (newLon < _minLon) {
      newLon = _minLon;
      needsUpdate = true;
    } else if (newLon > _maxLon) {
      newLon = _maxLon;
      needsUpdate = true;
    }

    // Sınır dışına çıkıldıysa geri çek
    if (needsUpdate) {
      Future.microtask(() {
        _mapController.move(LatLng(newLat, newLon), _mapController.camera.zoom);
      });
    }
  }
}

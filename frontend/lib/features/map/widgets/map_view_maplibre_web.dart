import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:provider/provider.dart';

import 'package:frontend/core/constants/map_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/features/map/layers/map_layers_system.dart'
    show computeLayerPng;
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/core/theme/app_theme.dart';

// ─── JS interop (web/index.html shim fonksiyonları) ──────────────────────────
// kIsWeb olmayan derlemelerde hiçbiri çağrılmaz.

@JS('window.srrpSetTerrain')
external void _jsSetTerrain(bool enable);

@JS('window.srrpSetCloudLayer')
external void _jsSetCloudLayer(bool enable, double opacity);

@JS('window.srrpSetCloudOpacity')
external void _jsSetCloudOpacity(double opacity);

@JS('window.srrpSetSky')
external void _jsSetSky(bool enable);

@JS('window.srrpSetGlobe')
external void _jsSetGlobe(bool enable);

@JS('window.srrpSetPitch')
external void _jsSetPitch(double pitch);

@JS('window.srrpAddBuildings')
external bool _jsAddBuildings(String? beforeId);

@JS('window.srrpRemoveBuildings')
external void _jsRemoveBuildings();

// Aşama I: PostGIS MVT vektör katman toggle'ları (hidro/yasaklı/iletim)
@JS('window.srrpToggleHydroLayer')
external void _jsToggleHydroLayer(bool visible);

@JS('window.srrpToggleRestrictedLayer')
external void _jsToggleRestrictedLayer(bool visible);

@JS('window.srrpToggleEnergyCorridorLayer')
external void _jsToggleEnergyCorridorLayer(bool visible);

@JS('window.srrpStartWindParticles')
external void _jsStartWindParticles(String geojsonStr);

@JS('window.srrpStopWindParticles')
external void _jsStopWindParticles();

@JS('window.srrpFlyTo')
external void _jsFlyTo(double lat, double lon, double zoom);

@JS('window.srrpZoomIn')
external void _jsZoomIn();

@JS('window.srrpZoomOut')
external void _jsZoomOut();

@JS('window.srrpSetPinHoverFn')
external void _jsSetPinHoverFn(JSFunction fn);

@JS('window.srrpSetupPinHover')
external void _jsSetupPinHover();

@JS('window.srrpSetPinClickFn')
external void _jsSetPinClickFn(JSFunction fn);

@JS('window.srrpSetupPinClick')
external void _jsSetupPinClick();

@JS('window.srrpLoadBorderLayers')
external void _jsLoadBorderLayers(
  String provUrl,
  String distUrl,
  String regUrl,
);

@JS('window.srrpSetupProvinceSelect')
external void _jsSetupProvinceSelect(bool enable);

@JS('window.srrpSetupRegionMode')
external void _jsSetupRegionMode();

@JS('window.srrpSetupProvinceMode')
external void _jsSetupProvinceMode(String? regionFilter);

@JS('window.srrpSetupDistrictMode')
external void _jsSetupDistrictMode(String? provinceName);

@JS('window.srrpClearSelectionMode')
external void _jsClearSelectionMode();

@JS('window.srrpHighlightProvince')
external void _jsHighlightProvince(String? provinceName);

@JS('window.srrpHighlightDistrict')
external void _jsHighlightDistrict(String? provinceName, String? districtName);

@JS('window.srrpSetProvinceClickFn')
external void _jsSetProvinceClickFn(JSFunction fn);

@JS('window.srrpSetRegionClickFn')
external void _jsSetRegionClickFn(JSFunction fn);

@JS('window.srrpSetDistrictClickFn')
external void _jsSetDistrictClickFn(JSFunction fn);

@JS('window.srrpQueryClick')
external String _jsQueryClick(double lng, double lat);

@JS('window.srrpSetMapInteractive')
external void _jsSetMapInteractive(bool enable);

@JS('window.srrpSetClickGuard')
external void _jsSetClickGuard(bool active);

@JS('window.srrpSetMaxBounds')
external void _jsSetMaxBounds(
    double swLng, double swLat, double neLng, double neLat);

@JS('window.srrpClearMaxBounds')
external void _jsClearMaxBounds();

@JS('window.srrpSetShowcasePins')
external void _jsSetShowcasePins(String geojsonStr);

@JS('window.srrpSetChoropleth')
external void _jsSetChoropleth(String mode, String? dataJson);

// ─── Lazy Loader JS Interop ───────────────────────────────────────────────────

@JS('window.srrpEnsureMapLibre')
external void _jsEnsureMapLibre(JSFunction callback);

// ─── Raster Overlay JS Interop (standart haritayla aynı render) ──────────────

@JS('window.srrpSetRasterOverlay')
external void _jsSetRasterOverlay(
  String base64,
  double minLon,
  double minLat,
  double maxLon,
  double maxLat,
  double opacity,
);

@JS('window.srrpRemoveRasterOverlay')
external void _jsRemoveRasterOverlay();

// ─── Cluster JS Interop ────────────────────────────────────────────────────

@JS('window.srrpUpdateClusterPins')
external void _jsUpdateClusterPins(String geojsonStr);

@JS('window.srrpClearClusterPins')
external void _jsClusterPinsClear();

// ─── Animasyon JS Interop ──────────────────────────────────────────────────

@JS('window.srrpLoadAnimationData')
external void _jsLoadAnimationData(String json);

@JS('window.srrpAnimPlay')
external void _jsAnimPlayRaw(double intervalMs);

@JS('window.srrpAnimStop')
external void _jsAnimStopRaw();

@JS('window.srrpAnimSeek')
external void _jsAnimSeekRaw(int index);

@JS('window.srrpSetAnimFrameCallback')
external void _jsSetAnimFrameCallback(JSFunction fn);

// ─── Layer / Source ID'leri ───────────────────────────────────────────────────

const _pinsSourceId = 'srrp-pins';
const _pinsShadowLayerId = 'srrp-pins-shadow';
const _pinsLayerId = 'srrp-pins-circles';
const _pinsLabelLayerId = 'srrp-pins-labels';
const _pinsCityLabelLayerId = 'srrp-pins-city-labels';

const _heatmapSourceId = 'srrp-heatmap';
const _heatmapGridSourceId = 'srrp-heatmap-grid';
const _heatmapSolarId = 'srrp-heatmap-solar';
const _heatmapWindId = 'srrp-heatmap-wind';
const _heatmapTempId = 'srrp-heatmap-temp';

const _martinSourceId = 'srrp-martin';
// Martin tile URL - dinamik host kullanır (telefon/PC uyumlu)
String get _martinTileJsonUrl {
  final host = kIsWeb ? Uri.base.host : 'localhost';
  return 'http://$host:3000/public.weather_tiles';
}

const _hillshadeSourceId = 'srrp-hillshade-dem';
const _hillshadeLayerId = 'srrp-hillshade';

// Neon veri noktası katmanları (heatmap source üzerinde)
const _dataGlowLayerId = 'srrp-data-glow';
const _dataDotsLayerId = 'srrp-data-dots';

// ─── Heatmap Paint Builder ────────────────────────────────────────────────────

/// Heatmap renk rampını palet + mod'a göre döndürür.
List<Object> _heatmapColorRamp(MlHeatmapMode mode, HeatmapPalette palette) {
  switch (palette) {
    case HeatmapPalette.thermal:
      return [
        'interpolate',
        ['linear'],
        ['heatmap-density'],
        0,
        'rgba(0,0,0,0)',
        0.2,
        'rgba(60,0,80,0.6)',
        0.4,
        'rgba(180,0,0,0.75)',
        0.6,
        'rgba(255,100,0,0.85)',
        0.8,
        'rgba(255,220,0,0.92)',
        1,
        'rgba(255,255,255,1)',
      ];
    case HeatmapPalette.viridis:
      return [
        'interpolate',
        ['linear'],
        ['heatmap-density'],
        0,
        'rgba(68,1,84,0)',
        0.25,
        'rgba(58,82,139,0.6)',
        0.5,
        'rgba(32,144,140,0.75)',
        0.75,
        'rgba(94,201,98,0.9)',
        1,
        'rgba(253,231,37,1)',
      ];
    case HeatmapPalette.classic:
      switch (mode) {
        case MlHeatmapMode.solar:
          return [
            'interpolate',
            ['linear'],
            ['heatmap-density'],
            0,
            'rgba(255,255,178,0)',
            0.25,
            'rgba(254,204,92,0.6)',
            0.5,
            'rgba(253,141,60,0.8)',
            0.75,
            'rgba(240,59,32,0.9)',
            1,
            'rgba(189,0,38,1)',
          ];
        case MlHeatmapMode.wind:
          return [
            'interpolate',
            ['linear'],
            ['heatmap-density'],
            0,
            'rgba(230,240,255,0)',
            0.25,
            'rgba(116,169,207,0.6)',
            0.5,
            'rgba(43,140,190,0.8)',
            0.75,
            'rgba(4,90,141,0.9)',
            1,
            'rgba(2,56,88,1)',
          ];
        case MlHeatmapMode.temperature:
          return [
            'interpolate',
            ['linear'],
            ['heatmap-density'],
            0,
            'rgba(49,54,149,0)',
            0.2,
            'rgba(69,117,180,0.6)',
            0.4,
            'rgba(171,217,233,0.75)',
            0.6,
            'rgba(254,224,144,0.85)',
            0.8,
            'rgba(244,109,67,0.92)',
            1,
            'rgba(165,0,38,1)',
          ];
        default:
          return [];
      }
  }
}

/// Isı haritası paint tanımını dinamik parametrelerle oluşturur.
Map<String, Object> _buildHeatmapPaint(
  MlHeatmapMode mode,
  double radius,
  double intensity,
  HeatmapPalette palette,
) {
  return <String, Object>{
    'heatmap-weight': [
      'interpolate',
      ['linear'],
      ['get', 'value'],
      0,
      0,
      1,
      1,
    ],
    'heatmap-intensity': [
      'interpolate',
      ['linear'],
      ['zoom'],
      0,
      intensity,
      10,
      intensity * 3,
    ],
    'heatmap-color': _heatmapColorRamp(mode, palette),
    'heatmap-radius': [
      'interpolate',
      ['linear'],
      ['zoom'],
      0,
      radius,
      10,
      radius * 2,
    ],
    'heatmap-opacity': 0.75,
  };
}

// ─── Renk / GeoJSON Yardımcıları ─────────────────────────────────────────────

// Pin renkleri:
//   Güneş Paneli   → turuncu (#FFA726)
//   Rüzgar Türbini → rüzgar mavisi (#42A5F5)
//   HES            → Spotify yeşili (#1DB954)
String _pinColorHex(String type, {bool isDark = true}) {
  switch (type.toLowerCase()) {
    case 'güneş paneli':
    case 'solar':
      return '#FFA726';
    case 'rüzgar türbini':
    case 'wind':
      return '#42A5F5'; // Rüzgar mavisi
    case 'hidroelektrik':
    case 'hes':
    case 'hydro':
      return '#1DB954'; // Spotify yeşili
    default:
      return '#66BB6A';
  }
}

String _pinsToGeoJson(List<Pin> pins, {bool isDark = true}) => jsonEncode({
  'type': 'FeatureCollection',
  'features': pins
      .map(
        (p) => {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [p.longitude, p.latitude],
          },
          'properties': {
            'id': p.id,
            'name': p.name,
            'type': p.type,
            'color': _pinColorHex(p.type, isDark: isDark),
            'city': p.city ?? '',
            'district': p.district ?? '',
            'locationLabel': p.locationLabel,
          },
        },
      )
      .toList(),
});

String _heatmapToGeoJson(List<CityWeatherSummary> summaries) {
  if (summaries.isEmpty) return '{"type":"FeatureCollection","features":[]}';
  double maxRad = summaries.fold(
    0.0,
    (m, s) =>
        (s.totalRadiation ?? 0) > m ? (s.totalRadiation ?? 0).toDouble() : m,
  );
  double maxWind = summaries.fold(
    0.0,
    (m, s) => (s.avgWindSpeed100m ?? 0) > m
        ? (s.avgWindSpeed100m ?? 0).toDouble()
        : m,
  );
  // Sıcaklık: Türkiye için tipik aralık -20°C..50°C → normalize et
  const double minTemp = -20.0, maxTemp = 50.0;
  if (maxRad == 0) maxRad = 1;
  if (maxWind == 0) maxWind = 1;
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': summaries.map((s) {
      final temp = s.avgTemperature ?? 20.0;
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [s.lon, s.lat],
        },
        'properties': {
          'solar_weight': ((s.totalRadiation ?? 0) / maxRad).clamp(0.0, 1.0),
          'wind_weight': ((s.avgWindSpeed100m ?? 0) / maxWind).clamp(0.0, 1.0),
          'temp_weight': ((temp - minTemp) / (maxTemp - minTemp)).clamp(
            0.0,
            1.0,
          ),
          'temp_celsius': temp,
        },
      };
    }).toList(),
  });
}

String _heatmapGridToGeoJson(List<HeatmapPoint> points) {
  if (points.isEmpty) return '{"type":"FeatureCollection","features":[]}';
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': points
        .map(
          (p) => {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [p.longitude, p.latitude],
            },
            'properties': {'value': p.value},
          },
        )
        .toList(),
  });
}

String _windVectorsToGeoJson(List<WindVector> vectors) {
  if (vectors.isEmpty) return '{"type":"FeatureCollection","features":[]}';
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': vectors.map((v) {
      final bearing =
          (90.0 - math.atan2(v.v, v.u) * 180.0 / math.pi + 360.0) % 360.0;
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [v.lon, v.lat],
        },
        'properties': {'bearing': bearing, 'speed': v.speed},
      };
    }).toList(),
  });
}

// ─── MapViewMapLibre ──────────────────────────────────────────────────────────

class MapViewMapLibre extends StatefulWidget {
  final Function(ml.Position)? onMapTap;
  final Function(Pin)? onPinTap;

  const MapViewMapLibre({super.key, this.onMapTap, this.onPinTap});

  /// MapLibre haritasını belirtilen konuma uçurur (JS shim üzerinden).
  static void flyTo(double lat, double lon, {double zoom = 10.0}) {
    if (kIsWeb) _jsFlyTo(lat, lon, zoom);
  }

  /// Haritayı bir adım yakınlaştır.
  static void zoomIn() {
    if (kIsWeb) _jsZoomIn();
  }

  /// Haritayı bir adım uzaklaştır.
  static void zoomOut() {
    if (kIsWeb) _jsZoomOut();
  }

  /// İl seçim modunu JS katmanları ile aç/kapat (geriye dönük uyumluluk).
  static void setupProvinceSelect(bool enable) {
    if (kIsWeb) _jsSetupProvinceSelect(enable);
  }

  /// Harita etkileşimini aç/kapat (drag, scroll, zoom).
  static void setInteractive(bool enable) {
    if (kIsWeb) _jsSetMapInteractive(enable);
  }

  /// Harita sınırlarını ayarla (Türkiye dışına çıkılamaz).
  static void setMaxBounds(
      double swLng, double swLat, double neLng, double neLat) {
    if (kIsWeb) _jsSetMaxBounds(swLng, swLat, neLng, neLat);
  }

  /// Harita sınırlarını kaldır.
  static void clearMaxBounds() {
    if (kIsWeb) _jsClearMaxBounds();
  }

  /// Vitrin pinlerini GeoJSON olarak yükle (landing showcase).
  static void setShowcasePins(String geojsonStr) {
    if (kIsWeb) _jsSetShowcasePins(geojsonStr);
  }

  /// Web'de wind overlay kullanılmaz (JS canvas kullanılır), null döner.
  static dynamic get activeControllerForOverlay => null;

  /// Dialog açıkken harita tıklamalarını bastırmak için kullanılır.
  /// `_onMapClick` bu bayrak aktifken hiçbir şey yapmaz.
  /// JS tarafındaki seçim katmanı tıklamaları da bastırılır.
  static bool _clickGuardActive = false;
  static void setClickGuard(bool active) {
    _clickGuardActive = active;
    if (kIsWeb) _jsSetClickGuard(active);
  }

  /// Bölge seçim modunu başlat.
  static void setupRegionMode() {
    if (kIsWeb) _jsSetupRegionMode();
  }

  /// İl seçim modunu başlat. [regionFilter] verilirse yalnızca o bölgenin illeri gösterilir.
  static void setupProvinceMode({String? regionFilter}) {
    if (kIsWeb) _jsSetupProvinceMode(regionFilter);
  }

  /// İlçe seçim modunu başlat. [provinceName] il adı (GADM NAME_1).
  static void setupDistrictMode(String provinceName) {
    if (kIsWeb) _jsSetupDistrictMode(provinceName);
  }

  /// Tüm seçim katmanlarını kaldır ve kamerayı sıfırla.
  static void clearSelectionMode() {
    if (kIsWeb) _jsClearSelectionMode();
  }

  // ─── Animasyon static metodları ────────────────────────────────────
  static void loadAnimationData(String json) {
    if (kIsWeb) _jsLoadAnimationData(json);
  }

  static void animPlay(double fps) {
    if (kIsWeb) _jsAnimPlayRaw(1000.0 / fps.clamp(1, 60));
  }

  static void animStop() {
    if (kIsWeb) _jsAnimStopRaw();
  }

  static void animSeek(int frame) {
    if (kIsWeb) _jsAnimSeekRaw(frame);
  }

  @override
  State<MapViewMapLibre> createState() => _MapViewMapLibreState();
}

class _MapViewMapLibreState extends State<MapViewMapLibre> {
  ml.StyleController? _style;
  bool _styleLoaded = false;

  /// Safety timer: _styleLoaded hâlâ false ise zorla true yap
  Timer? _styleLoadTimeout;

  /// Eşzamanlı _syncAll çağrılarını engeller (race condition koruması)
  bool _syncing = false;

  // ─── "Son senkronizasyon" cache ───────────────────────────────────
  List<Pin> _lastPins = [];
  List<CityWeatherSummary> _lastSummary = [];
  MlHeatmapMode _lastHeatmap = MlHeatmapMode.none;
  double _lastRadius = 40.0;
  double _lastIntensity = 1.0;
  HeatmapPalette _lastPalette = HeatmapPalette.classic;
  bool _last3D = false;

  bool _solarActive = false;
  bool _windActive = false;
  bool _tempActive = false;

  // MapLibre GL JS script yükleme durumu (lazy-load)
  bool _mapLibreScriptReady = false;

  // Raster overlay durumu
  bool _rasterActive = false;
  bool _rasterRendering = false;
  MlHeatmapMode _lastRasterMode = MlHeatmapMode.none;
  int _lastRasterPtLen = -1;
  bool _hillshadeActive = false;
  bool _lastGlobe = false;
  bool _lastBuildings = false;
  bool _lastTerrain = false;
  bool _lastCloud = false;
  double _lastCloudOpacity = 0.70;

  // Aşama I: MVT vektör katman state'leri (visibility cache)
  bool _lastHydroLayer = false;
  bool _lastRestrictedLayer = false;
  bool _lastEnergyCorridorLayer = false;

  // Neon veri noktaları
  bool _dataGlowActive = false;
  bool _dataDotsActive = false;
  MlHeatmapMode _lastDataMode = MlHeatmapMode.none;

  // Rüzgar parçacıkları
  bool _lastParticles = false;
  int _lastParticleVectorsLen = 0;

  // Choropleth (ilçe tematik harita)
  ChoroplethMode _lastChoropleth = ChoroplethMode.none;
  String? _lastChoroplethDataJson;

  // Kümeleme
  bool _lastClustering = false;

  // Tema (pin renkleri tema-duyarlı)
  bool _lastDarkMode = true;

  // ─── Pin hover (JS → Dart callback) ───────────────────────────────
  Pin? _hoveredPin;
  JSFunction? _pinHoverJsCallback;
  bool _hoverCallbackRegistered = false;

  // ─── Pin click (JS → Dart callback) — bilgi kartı gösterimi ─────
  Map<String, dynamic>? _selectedPinProps; // Tıklanan pin özellikleri (GeoJSON properties)
  JSFunction? _pinClickJsCallback;
  bool _clickCallbackRegistered = false;

  // ─── Selection callbacks (JS → Dart) ─────────────────────────────
  JSFunction? _provinceClickJsCallback;
  JSFunction? _regionClickJsCallback;
  JSFunction? _districtClickJsCallback;
  bool _selectionCallbacksRegistered = false;
  SelectionLevel _lastSelectionLevel = SelectionLevel.none;
  String? _lastRegionName;
  String? _lastProvinceName;
  String? _lastDistrictName;

  // 1.B (yeniden): _animFrameJsCallback emekliye ayrıldı.
  // _animBridgeRegistered yalnızca initialization guard olarak kullanılıyor.
  bool _animBridgeRegistered = false;

  // ─── VM referansı — dispose'da context geçersiz olduğu için önceden saklanır ──
  MapViewModel? _vmRef;

  // ─── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // MapLibre GL JS lazy-load: script hazır olana kadar ml.MapLibreMap render edilmez
    if (kIsWeb) {
      _jsEnsureMapLibre(
        (() {
          if (mounted) {
            setState(() => _mapLibreScriptReady = true);
            // Safety timeout: 10sn içinde style load olmadıysa spinner'ı kaldır
            _styleLoadTimeout = Timer(const Duration(seconds: 10), () {
              if (mounted && !_styleLoaded) {
                setState(() => _styleLoaded = true);
              }
            });
          }
        }).toJS,
      );
    } else {
      _mapLibreScriptReady = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vmRef = Provider.of<MapViewModel>(context, listen: false);
      _vmRef!.addListener(_onVmChanged);
      // JS → Dart pin hover callback'i bir kez kaydet
      if (kIsWeb && !_hoverCallbackRegistered) {
        _pinHoverJsCallback = _handlePinHoverJs.toJS;
        _jsSetPinHoverFn(_pinHoverJsCallback!);
        _hoverCallbackRegistered = true;
      }
      // JS → Dart pin click callback'i bir kez kaydet
      if (kIsWeb && !_clickCallbackRegistered) {
        _pinClickJsCallback = _handlePinClickJs.toJS;
        _jsSetPinClickFn(_pinClickJsCallback!);
        _clickCallbackRegistered = true;
      }
      // JS → Dart seçim callback'leri (bölge / il / ilçe) bir kez kaydet
      if (kIsWeb && !_selectionCallbacksRegistered) {
        _regionClickJsCallback = _handleRegionClickJs.toJS;
        _provinceClickJsCallback = _handleProvinceClickJs.toJS;
        _districtClickJsCallback = _handleDistrictClickJs.toJS;
        _jsSetRegionClickFn(_regionClickJsCallback!);
        _jsSetProvinceClickFn(_provinceClickJsCallback!);
        _jsSetDistrictClickFn(_districtClickJsCallback!);
        _selectionCallbacksRegistered = true;
      }
      // 1.B (yeniden): Animation JS bridge emekliye ayrıldı —
      // TimeSimulationController pure Dart Timer ile çalışır, choropleth
      // bridge her frame'de polygon'ları yeniler. JS frame callback ve
      // playRaw/seekRaw shim'leri kullanılmıyor.
      _animBridgeRegistered = true;
    });
  }

  @override
  void dispose() {
    _styleLoadTimeout?.cancel();
    _vmRef?.removeListener(_onVmChanged);
    // JS callback'lerini temizle — dispose sonrası çağrılmasını engelle
    if (kIsWeb) {
      final noop = (() {}).toJS;
      if (_hoverCallbackRegistered) {
        _jsSetPinHoverFn(noop);
      }
      if (_clickCallbackRegistered) {
        _jsSetPinClickFn(noop);
      }
      if (_selectionCallbacksRegistered) {
        _jsSetRegionClickFn(noop);
        _jsSetProvinceClickFn(noop);
        _jsSetDistrictClickFn(noop);
        _jsClearSelectionMode();
      }
      if (_animBridgeRegistered) {
        _jsSetAnimFrameCallback(noop);
      }
    }
    super.dispose();
  }

  /// JS mousemove/mouseleave eventi → Dart pin hover state
  void _handlePinHoverJs(JSAny? idArg) {
    if (!mounted) return;
    final idStr = idArg?.dartify()?.toString() ?? '';
    final id = int.tryParse(idStr);
    Pin? pin;
    if (id != null && _vmRef != null) {
      pin = _vmRef!.filteredPins.cast<Pin?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
    }
    // VM'de bulunamadıysa showcase pin olabilir — hoveredPin'i null bırak
    if (_hoveredPin?.id != pin?.id) {
      setState(() => _hoveredPin = pin);
    }
  }

  /// JS click eventi → Pin bilgi kartı göster
  void _handlePinClickJs(JSAny? propsArg) {
    if (!mounted) return;
    final jsonStr = propsArg?.dartify()?.toString() ?? '';
    if (jsonStr.isEmpty) return;

    // queryRenderedFeatures yaklaşımı kullanıldığı için ek guard gerekmez

    try {
      final props = jsonDecode(jsonStr) as Map<String, dynamic>;
      final pinId = (props['id'] is num) ? (props['id'] as num).toInt() : int.tryParse(props['id']?.toString() ?? '');

      // Ana haritada gerçek Pin objesini bul (düzenleme, analiz vb. için)
      if (pinId != null && _vmRef != null) {
        final realPin = _vmRef!.filteredPins.cast<Pin?>().firstWhere(
          (p) => p?.id == pinId,
          orElse: () => null,
        );
        if (realPin != null) {
          if (widget.onPinTap != null) {
            widget.onPinTap!(realPin);
            return;
          }
        }
      }

      // Showcase pin veya onPinTap yok — bilgi kartını göster
      setState(() => _selectedPinProps = props);
    } catch (e) {
      debugPrint('[MapLibre] pin click parse hatası: $e');
    }
  }

  /// Bilgi kartını kapat
  void _dismissInfoCard() {
    if (_selectedPinProps != null) {
      setState(() => _selectedPinProps = null);
    }
  }

  /// JS bölge tıklama → mod-farkındalıklı işleme
  void _handleRegionClickJs(JSAny? nameArg) {
    if (!mounted || _vmRef == null) return;
    final name = nameArg?.dartify()?.toString() ?? '';
    if (name.isEmpty) return;
    debugPrint('[GEO-WEB] Bölge click → $name');
    _vmRef!.selectRegion(name);
  }

  /// JS il tıklama → mod-farkındalıklı işleme
  /// [regionArg] JS tarafından feature.REGION property'sinden aktarılır.
  /// Bölge modunda farklı bölgenin iline tıklandığında region güncellenir.
  void _handleProvinceClickJs(JSAny? nameArg, JSAny? regionArg) {
    if (!mounted || _vmRef == null) return;
    final name = nameArg?.dartify()?.toString() ?? '';
    if (name.isEmpty) return;
    final region = regionArg?.dartify()?.toString() ?? '';
    final vm = _vmRef!;
    final initial = vm.initialSelectionMode;
    debugPrint('[GEO-WEB] İl click → $name (region=$region) '
        '(initial=$initial lvl=${vm.selectionLevel} '
        'curRegion=${vm.selectedRegionName} curProv=${vm.selectedProvinceName})');

    // Bölge modunda tıklanan il farklı bir bölgedeyse, önce bölgeyi güncelle.
    // Bu kullanıcı spec'i: "Hala tıklama ile Diğer bölgelere geçebilirim".
    // İl modunda region'a DOKUNMA — initial==province iken region hep null kalır.
    if (initial == SelectionLevel.region &&
        region.isNotEmpty &&
        region != vm.selectedRegionName) {
      vm.selectRegion(region);
    }
    // Ardından ile drill-down et (her mod için geçerli).
    vm.selectProvince(name);
  }

  /// JS ilçe tıklama → mod-farkındalıklı işleme
  /// Gelen değer "province|district" formatındadır (composite hover'dan gelir).
  void _handleDistrictClickJs(JSAny? nameArg) {
    if (!mounted || _vmRef == null) return;
    final raw = nameArg?.dartify()?.toString() ?? '';
    if (raw.isEmpty) return;

    final vm = _vmRef!;
    final initial = vm.initialSelectionMode;
    debugPrint('[GEO-WEB] İlçe click → $raw '
        '(initial=$initial lvl=${vm.selectionLevel} '
        'curProv=${vm.selectedProvinceName} curDist=${vm.selectedDistrictName})');

    // "İstanbul|Kadıköy" → province=İstanbul, district=Kadıköy
    String province = '';
    String district = '';
    final sep = raw.indexOf('|');
    if (sep > 0) {
      province = raw.substring(0, sep);
      district = raw.substring(sep + 1);
    } else {
      district = raw;
    }

    if (initial == SelectionLevel.province) {
      // İL MODU: başka ile tıklanırsa o ile geç, aynı ildeyse ilçe seç
      if (province.isNotEmpty && province != vm.selectedProvinceName) {
        // Farklı il → o ilin ilçelerine geç
        vm.selectProvince(province);
      } else if (district.isNotEmpty) {
        // Aynı il → ilçe seç
        vm.selectDistrict(district, province: province);
      }
    } else if (initial == SelectionLevel.region) {
      // BÖLGE MODU: ilçe seviyesinde, aynı il veya başka ile geçiş
      if (province.isNotEmpty && province != vm.selectedProvinceName) {
        vm.selectProvince(province);
      } else if (district.isNotEmpty) {
        vm.selectDistrict(district, province: province);
      }
    } else if (initial == SelectionLevel.district) {
      // İLÇE MODU: sadece bilgi göster, renk değiştirme
      if (district.isNotEmpty) {
        vm.selectDistrict(district, province: province);
      }
    } else {
      // Fallback
      if (district.isNotEmpty) {
        vm.selectDistrict(district, province: province);
      }
    }
  }

  // 1.B (yeniden): _handleAnimFrameJs JS callback'i emekliye ayrıldı —
  // TimeSimulationController kendi Dart Timer'ında frame ilerletir.

  // _syncAll devam ederken gelen VM değişiklikleri için "dirty" bayrağı.
  // _syncAll tamamlanınca bir kez daha çalıştırılır.
  bool _syncPending = false;

  void _onVmChanged() {
    if (!mounted || !_styleLoaded || _vmRef == null) return;
    final vm = _vmRef!;

    // ── Hızlı JS çağrıları — _syncing'den bağımsız olarak her zaman çalışır ──

    // 1. Seçim modu (il/ilçe/bölge) — hızlı, senkron JS güncellemesi
    if (kIsWeb) {
      final levelChanged = vm.selectionLevel != _lastSelectionLevel;
      final regionChanged = vm.selectedRegionName != _lastRegionName;
      final provinceChanged = vm.selectedProvinceName != _lastProvinceName;
      final districtChanged = vm.selectedDistrictName != _lastDistrictName;
      // İlçe seçildiğinde (selectedDistrictName != null) harita katmanlarını
      // yeniden kurma — sadece veri kartı + ilçe highlight güncellenir. Harita
      // katmanları yalnızca seviye değiştiğinde veya il→ilçe geçişinde
      // (districtName null) güncellenir.
      final isDistrictDataOnly = provinceChanged &&
          vm.selectionLevel == SelectionLevel.district &&
          vm.selectedDistrictName != null;
      if (levelChanged ||
          (regionChanged && vm.selectionLevel == SelectionLevel.province) ||
          (provinceChanged && vm.selectionLevel == SelectionLevel.district && !isDistrictDataOnly)) {
        _syncSelectionMode(vm);
        _lastSelectionLevel = vm.selectionLevel;
        _lastRegionName = vm.selectedRegionName;
        _lastProvinceName = vm.selectedProvinceName;
        _lastDistrictName = vm.selectedDistrictName;
      } else if (districtChanged && vm.selectionLevel == SelectionLevel.district) {
        // Hafif güncelleme: sadece seçili ilçenin mavi çerçevesini değiştir
        try {
          _jsHighlightDistrict(
            vm.selectedProvinceName,
            vm.selectedDistrictName,
          );
        } catch (_) {}
        _lastDistrictName = vm.selectedDistrictName;
      }
    }

    // 2. Bulut katmanı — senkron JS güncellemesi
    try { _syncCloud(vm.showCloudLayer, vm.cloudOpacity); } catch (_) {}

    // 2b. Choropleth katmanı — senkron JS güncellemesi
    try { _syncChoropleth(vm); } catch (_) {}

    // 3. Rüzgar parçacıkları — hızlı async (sadece GeoJSON string gönderir)
    _syncWindParticles(vm.showWindParticles, vm.windVectors);

    // ── Ağır async sync — yalnızca harita verisi değiştiğinde çalıştır ──
    // UI-only değişiklikler (panel açık/kapalı, yükleme göstergesi vb.)
    // _syncAll'ı tetiklememelidir; bu erken çıkış o gereksiz çağrıları önler.
    if (!_anyMapDataChanged(vm)) return;

    if (_syncing) {
      _syncPending = true;
      return;
    }
    _syncAll(vm);
  }

  /// Haritanın yeniden senkronize edilmesini gerektiren herhangi bir VM alanı
  /// değiştiyse true döner; yalnızca UI state (panel açık/kapalı, yükleme
  /// spinner'ı vb.) değişmişse false döner ve _syncAll atlanır.
  bool _anyMapDataChanged(MapViewModel vm) {
    // Pinler
    if (vm.show3DTurbines != _last3D) return true;
    if (vm.showPinClusters != _lastClustering) return true;
    if (!_pinsEqual(vm.filteredPins, _lastPins)) return true;
    // Heatmap veri ve parametreler
    if (vm.weatherSummary.length != _lastSummary.length) return true;
    if (vm.mlHeatmapMode != _lastHeatmap) return true;
    if (vm.heatmapRadius != _lastRadius) return true;
    if (vm.heatmapIntensity != _lastIntensity) return true;
    if (vm.heatmapPalette != _lastPalette) return true;
    // 1.B (yeniden): animasyon state'i artık MapViewModel'da değil —
    // TimeSimulationController choropleth bridge üzerinden polygon'ları
    // direkt günceller, _syncAll re-trigger'a gerek yok.
    // Harita görsel özellikleri
    if (vm.showGlobe != _lastGlobe) return true;
    if (vm.show3DTerrain != _lastTerrain) return true;
    if (vm.show3DBuildings != _lastBuildings) return true;
    // Aşama I: MVT vektör katman toggle değişimleri
    if (vm.showHydroLayer != _lastHydroLayer) return true;
    if (vm.showRestrictedZoneLayer != _lastRestrictedLayer) return true;
    if (vm.showEnergyCorridorLayer != _lastEnergyCorridorLayer) return true;
    // Neon veri noktaları (mode zaten _lastHeatmap ile kapsanıyor,
    // ama _lastDataMode ayrı tutulduğu için)
    if (vm.mlHeatmapMode != _lastDataMode) return true;
    // Rüzgar parçacıkları (hızlı yol zaten handle eder, ama _syncAll
    // içindeki ikinci çağrı için de tutarlılık sağlanır)
    if (vm.showWindParticles != _lastParticles) return true;
    if (vm.windVectors.length != _lastParticleVectorsLen) return true;
    return false;
  }

  /// ViewModel selection level → uygun JS katmanı kur
  void _syncSelectionMode(MapViewModel vm) {
    if (!kIsWeb) return;
    if (!_styleLoaded) return; // Stil henüz yüklenmemişse işlem yapma
    debugPrint('[GEO-WEB] _syncSelectionMode — initial=${vm.initialSelectionMode} '
        'lvl=${vm.selectionLevel} region=${vm.selectedRegionName} '
        'prov=${vm.selectedProvinceName} dist=${vm.selectedDistrictName}');
    switch (vm.selectionLevel) {
      case SelectionLevel.none:
        _jsClearSelectionMode();
      case SelectionLevel.region:
        _jsSetupRegionMode();
      case SelectionLevel.province:
        _jsSetupProvinceMode(vm.selectedRegionName);
      case SelectionLevel.district:
        // İl modu: city→district drill-down — SADECE seçili ilin ilçeleri renklenir.
        //   Diğer iller sınır olarak görünür. Tüm Türkiye ilçelerinin üstüne tıklama
        //   kaydı düşebilir (cross-province navigation için); JS tarafında
        //   hit=tüm-Türkiye, color=seçili-il ayrımı yapılır.
        // İlçe modu: tüm Türkiye ilçeleri renklenir + tıklanabilir (filtre yok).
        // Bölge modu drill-down: sadece seçili ilin ilçeleri (klasik drill-down).
        final initial = vm.initialSelectionMode;
        if (initial == SelectionLevel.province) {
          _jsSetupDistrictMode(vm.selectedProvinceName); // YALNIZ seçili ilin ilçeleri
          try { _jsHighlightProvince(vm.selectedProvinceName); } catch (_) {}
        } else if (initial == SelectionLevel.district) {
          _jsSetupDistrictMode(null); // İlçe modu: tüm Türkiye
        } else {
          _jsSetupDistrictMode(vm.selectedProvinceName); // Bölge drill-down
        }
        // Seçili ilçe varsa mavi çerçeve ile vurgula (tüm modlar için geçerli)
        try {
          _jsHighlightDistrict(
            vm.selectedProvinceName,
            vm.selectedDistrictName,
          );
        } catch (_) {}
    }
  }

  Future<void> _syncAll(MapViewModel vm) async {
    if (_syncing) return;
    _syncing = true;

    // Tema durumunu oku (pin renkleri tema-duyarlı)
    if (mounted) {
      try {
        _lastDarkMode = Provider.of<ThemeViewModel>(context, listen: false).isDarkMode;
      } catch (_) {}
    }

    try {
      await _syncPins(vm.filteredPins, vm.show3DTurbines, vm.showPinClusters);
    } catch (e) {
      debugPrint('[MapLibre] _syncPins hata: $e');
    }
    try {
      await _syncHeatmapData(vm.weatherSummary);
    } catch (e) {
      debugPrint('[MapLibre] _syncHeatmapData hata: $e');
    }
    // 1.B (yeniden): animasyon path'i artık choropleth bridge üzerinden
    // (TimeSimulationController), JS heatmap consumer çağrılmıyor.
    {
      // Statik görünüm
      if (vm.mlHeatmapMode != MlHeatmapMode.none) {
        // Kullanıcı bir heatmap modu seçmiş → density layer kullan
        // (radius/intensity/palette ayarları bu modda etkilidir)
        try {
          await _syncHeatmapGridData(vm.heatmapPoints);
          await _syncHeatmapMode(
            vm.mlHeatmapMode,
            vm.heatmapRadius,
            vm.heatmapIntensity,
            vm.heatmapPalette,
          );
        } catch (e) {
          debugPrint('[MapLibre] _syncHeatmapMode (static) hata: $e');
        }
        // Raster overlay'i kaldır (density layer onun yerine geçti)
        if (_rasterActive && kIsWeb) {
          try { _jsRemoveRasterOverlay(); } catch (_) {}
          _rasterActive = false;
          _lastRasterMode = MlHeatmapMode.none;
          _lastRasterPtLen = -1;
        }
      } else {
        // Heatmap modu kapalı → density layer'ları temizle, raster PNG kullan
        try {
          await _syncHeatmapMode(
            MlHeatmapMode.none,
            vm.heatmapRadius,
            vm.heatmapIntensity,
            vm.heatmapPalette,
          );
          await _syncRasterOverlay(vm);
        } catch (e) {
          debugPrint('[MapLibre] _syncRasterOverlay hata: $e');
        }
      }
    }
    try {
      await _syncGlobe(vm.showGlobe);
    } catch (e) {
      debugPrint('[MapLibre] _syncGlobe hata: $e');
    }
    try {
      await _syncTerrain(vm.show3DTerrain);
    } catch (e) {
      debugPrint('[MapLibre] _syncTerrain hata: $e');
    }
    try {
      await _syncBuildings(vm.show3DBuildings);
    } catch (e) {
      debugPrint('[MapLibre] _syncBuildings hata: $e');
    }
    // Aşama I: MVT vektör katman sync (lightweight — JS toggle çağrısı)
    try {
      _syncMvtLayers(vm);
    } catch (e) {
      debugPrint('[MapLibre] _syncMvtLayers hata: $e');
    }
    try {
      await _syncDataPoints(vm.mlHeatmapMode, vm.weatherSummary);
    } catch (e) {
      debugPrint('[MapLibre] _syncDataPoints hata: $e');
    }
    try {
      await _syncWindParticles(vm.showWindParticles, vm.windVectors);
    } catch (e) {
      debugPrint('[MapLibre] _syncWindParticles hata: $e');
    }
    try {
      _syncCloud(vm.showCloudLayer, vm.cloudOpacity);
    } catch (e) {
      debugPrint('[MapLibre] _syncCloud hata: $e');
    }
    _syncing = false;

    // _syncing devam ederken gelen değişiklik varsa bir kez daha çalıştır
    if (_syncPending && mounted && _styleLoaded && _vmRef != null) {
      _syncPending = false;
      // Micro-task'ta çalıştır — dispose sırasında çakışmayı önle
      Future.microtask(() {
        if (mounted && _vmRef != null) {
          _syncAll(_vmRef!);
        }
      });
    }
  }

  // ─── Event Handler ────────────────────────────────────────────────

  Future<void> _onEvent(ml.MapEvent event) async {
    switch (event) {
      case ml.MapEventStyleLoaded(:final style):
        _style = style;
        _styleLoaded = false;
        _syncing = false;

        // Tüm durum ve cache'leri sıfırla
        _solarActive = _windActive = _tempActive = _hillshadeActive = false;
        _lastHeatmap = MlHeatmapMode.none;
        _lastRadius = 40.0;
        _lastIntensity = 1.0;
        _lastPalette = HeatmapPalette.classic;
        _rasterActive = false;
        _lastRasterMode = MlHeatmapMode.none;
        _lastRasterPtLen = -1;
        _last3D = false;
        _lastClustering = false;
        _lastGlobe = false;
        _lastBuildings = false;
        _lastTerrain = false;
        _lastCloud = false;
        _lastCloudOpacity = 0.70;
        _lastChoropleth = ChoroplethMode.none;
        _lastChoroplethDataJson = null;
        _lastPins = [];
        _lastSummary = [];

        // Neon veri noktaları ve parçacık cache sıfırla
        _dataGlowActive = false;
        _dataDotsActive = false;
        _lastDataMode = MlHeatmapMode.none;
        _lastParticles = false;
        _lastParticleVectorsLen = 0;
        if (kIsWeb) _jsStopWindParticles();

        // _initLayers hata verse bile spinner'ı kaldır
        try {
          await _initLayers();
        } catch (e) {
          debugPrint('[MapLibre] _initLayers hatası (spinner yine kaldırılacak): $e');
        }

        _styleLoadTimeout?.cancel();
        if (mounted) setState(() => _styleLoaded = true);

        if (mounted) {
          final vm = Provider.of<MapViewModel>(context, listen: false);
          await _syncAll(vm);
        }

      case ml.MapEventClick(:final point):
        await _onMapClick(point);

      default:
        break;
    }
  }

  // ─── Pin / Seçim Etkileşimi ──────────────────────────────────────
  //
  // Flutter Web'de MapLibre'nin layer-specific click handler'ları çalışmaz
  // (platform view event routing sorunu). Bunun yerine Dart MapEventClick'ten
  // koordinat alınır ve JS srrpQueryClick() ile queryRenderedFeatures yapılır.
  // Bu tek mekanizma pin, il, ilçe ve cluster tıklamalarını handle eder.
  // 3D/eğimli görünümde de doğru çalışır çünkü ekran koordinatı kullanır.

  Future<void> _onMapClick(ml.Position point) async {
    // Dialog açıkken harita tıklamalarını yoksay
    if (MapViewMapLibre._clickGuardActive) return;

    if (!kIsWeb) {
      widget.onMapTap?.call(point);
      return;
    }

    // JS queryRenderedFeatures ile hangi feature'a tıklandığını sorgula
    try {
      final resultJson = _jsQueryClick(point.lng.toDouble(), point.lat.toDouble());
      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      final type = result['type'] as String? ?? 'none';
      debugPrint('[GEO-WEB] 🎯 _onMapClick tip=$type lat=${point.lat.toStringAsFixed(4)} '
          'lng=${point.lng.toStringAsFixed(4)}');

      if (type == 'pin') {
        // ── Pin tıklaması ──
        final props = result['properties'] as Map<String, dynamic>? ?? {};
        final pinId = (props['id'] is num)
            ? (props['id'] as num).toInt()
            : int.tryParse(props['id']?.toString() ?? '');

        // Ana haritada gerçek Pin objesini bul
        if (pinId != null && _vmRef != null && widget.onPinTap != null) {
          final realPin = _vmRef!.filteredPins.cast<Pin?>().firstWhere(
            (p) => p?.id == pinId,
            orElse: () => null,
          );
          if (realPin != null) {
            widget.onPinTap!(realPin);
            return;
          }
        }
        // Showcase veya bilinmeyen pin → bilgi kartı göster
        _dismissInfoCard();
        setState(() => _selectedPinProps = props);
        return;
      }

      if (type == 'selection') {
        // ── İl / İlçe / Bölge seçim tıklaması ──
        final props = result['properties'] as Map<String, dynamic>? ?? {};
        _dismissInfoCard();
        _handleSelectionClick(props);
        return;
      }

      if (type == 'cluster') {
        // ── Cluster zoom — JS tarafında handle edildi ──
        return;
      }

      if (type == 'choropleth') {
        // ── Choropleth ilçe tıklaması → tooltip göster ──
        final props = result['properties'] as Map<String, dynamic>? ?? {};
        final name1 = props['NAME_1']?.toString() ?? '';
        final name2 = props['NAME_2']?.toString() ?? '';
        if (name1.isNotEmpty && name2.isNotEmpty && _vmRef != null) {
          _vmRef!.setChoroplethTap(name1, name2);
        }
        _dismissInfoCard();
        return;
      }
    } catch (e) {
      debugPrint('[MapLibre] queryClick hatası: $e');
    }

    // ── Boş alan tıklaması ──
    _dismissInfoCard();
    _vmRef?.clearChoroplethTap();
    widget.onMapTap?.call(point);
  }

  /// Seçim katmanı tıklaması — il/ilçe/bölge
  ///
  /// ⚠️ Bu, JS hit layer click handler'ının paralel bir yoludur (`_onMapClick`
  /// → `_jsQueryClick("selection")` → bu fonksiyon). Her iki yol da aynı
  /// `selectX` çağrısını yapmalı; aksi takdirde state tutarsızlığı olur.
  ///
  /// Kullanıcı spec'ine göre davranış `_initialSelectionMode` tarafından
  /// belirlenir:
  /// - **region (Bölge modu):** 3-seviye drill-down (region → province → district).
  ///   İlçe seviyesinde başka ile tıklanırsa doğrudan o ile drill-down.
  /// - **province (İl modu):** 2-seviye drill-down (province → district).
  ///   Bölge seçilmez, state'e hiç dokunulmaz.
  /// - **district (İlçe modu):** Tek seviye — sadece `selectDistrict`.
  void _handleSelectionClick(Map<String, dynamic> props) {
    if (_vmRef == null) return;
    final vm = _vmRef!;
    final initial = vm.initialSelectionMode;

    final name1 = props['NAME_1']?.toString() ?? '';
    final name2 = props['NAME_2']?.toString() ?? '';
    final region = props['REGION']?.toString() ?? '';

    debugPrint('[GEO-WEB] _handleSelectionClick — initial=$initial '
        'lvl=${vm.selectionLevel} name1=$name1 name2=$name2 region=$region '
        'curRegion=${vm.selectedRegionName} curProv=${vm.selectedProvinceName}');

    switch (initial) {
      case SelectionLevel.region:
        // Bölge modu: region → province → district
        switch (vm.selectionLevel) {
          case SelectionLevel.region:
            if (region.isNotEmpty) vm.selectRegion(region);
          case SelectionLevel.province:
            // Bölge seçili, il bekleniyor.
            // Kullanıcı spec: "Hala tıklama ile diğer bölgelere geçebilirim".
            // Farklı bölgenin iline tıklama → o bölgeye geç + il seç (tek adımda).
            if (region.isNotEmpty && region != vm.selectedRegionName) {
              vm.selectRegion(region);
              if (name1.isNotEmpty) vm.selectProvince(name1);
            } else if (name1.isNotEmpty) {
              vm.selectProvince(name1);
            }
          case SelectionLevel.district:
            // İlçe seviyesinde: aynı ildeki ilçe → selectDistrict.
            // Başka ildeki nokta → o ile drill-down; farklı bölgedeyse region'ı da güncelle.
            if (name1.isNotEmpty && name1 == vm.selectedProvinceName &&
                name2.isNotEmpty) {
              vm.selectDistrict(name2, province: name1);
            } else if (name1.isNotEmpty && name1 != vm.selectedProvinceName) {
              if (region.isNotEmpty && region != vm.selectedRegionName) {
                vm.selectRegion(region);
              }
              vm.selectProvince(name1);
            }
          case SelectionLevel.none:
            break;
        }
      case SelectionLevel.province:
        // İl modu: province → district (bölge YOK, region'a dokunma)
        if (vm.selectionLevel == SelectionLevel.province) {
          // İlk il seçimi
          if (name1.isNotEmpty) vm.selectProvince(name1);
        } else if (vm.selectionLevel == SelectionLevel.district) {
          if (name1.isNotEmpty && name1 == vm.selectedProvinceName &&
              name2.isNotEmpty) {
            // Seçili ilin ilçesine tıklama
            vm.selectDistrict(name2, province: name1);
          } else if (name1.isNotEmpty && name1 != vm.selectedProvinceName) {
            // Seçili il dışı nokta → o ile drill-down (yeni il)
            vm.selectProvince(name1);
          }
        }
      case SelectionLevel.district:
        // İlçe modu: tek seviye
        if (name1.isNotEmpty && name2.isNotEmpty) {
          vm.selectDistrict(name2, province: name1);
        }
      case SelectionLevel.none:
        break;
    }
  }

  // ─── Pin Hover Tooltip ────────────────────────────────────────────

  static Color _pinColor(String type, {bool isDark = true}) {
    switch (type.toLowerCase()) {
      case 'güneş paneli':
      case 'solar':
        return const Color(0xFFFFA726);
      case 'rüzgar türbini':
      case 'wind':
        return const Color(0xFF42A5F5); // Rüzgar mavisi
      case 'hidroelektrik':
      case 'hes':
      case 'hydro':
        return const Color(0xFF1DB954); // Spotify yeşili
      default:
        return const Color(0xFF66BB6A);
    }
  }

  static IconData _pinIcon(String type) {
    switch (type.toLowerCase()) {
      case 'güneş paneli':
      case 'solar':
        return Icons.wb_sunny_rounded;
      case 'rüzgar türbini':
      case 'wind':
        return Icons.air_rounded;
      case 'hidroelektrik':
      case 'hes':
      case 'hydro':
        return Icons.water_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Widget _buildPinHoverCard(Pin pin, {bool isDark = true}) {
    final color = _pinColor(pin.type, isDark: isDark);
    final icon = _pinIcon(pin.type);
    final city = pin.city?.isNotEmpty == true ? pin.city! : null;
    final dist = pin.district?.isNotEmpty == true ? pin.district! : null;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF12122A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tip ikonu
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pin adı
                  Text(
                    pin.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Konum
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, color: color, size: 12),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          [
                            if (dist != null) dist,
                            if (city != null) city,
                          ].join(' / '),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Kapasite
                  if (pin.capacityMw > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${pin.capacityMw.toStringAsFixed(1)} MW',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pin Bilgi Kartı (Showcase + Ana Harita) ─────────────────────

  Widget _buildPinInfoCard(Map<String, dynamic> props, {bool isDark = true}) {
    final type = props['type']?.toString() ?? '';
    final name = props['name']?.toString() ?? 'Bilinmeyen';
    final city = props['city']?.toString() ?? '';
    final district = props['district']?.toString() ?? '';
    final location = props['locationLabel']?.toString() ??
        [if (district.isNotEmpty) district, if (city.isNotEmpty) city].join(' / ');
    final color = _pinColor(type, isDark: isDark);
    final icon = _pinIcon(type);

    // Kapasite: GeoJSON'dan "capacityMw" veya showcase'dan "mw"
    double? mw;
    if (props['capacityMw'] != null) {
      mw = (props['capacityMw'] is num) ? (props['capacityMw'] as num).toDouble() : double.tryParse(props['capacityMw'].toString());
    }

    final cardBg = isDark ? const Color(0xFF12122A) : const Color(0xFFF8F9FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF666666);

    String typeLabel;
    switch (type.toLowerCase()) {
      case 'güneş paneli':
      case 'solar':
        typeLabel = 'Güneş Enerjisi Santrali';
      case 'rüzgar türbini':
      case 'wind':
        typeLabel = 'Rüzgar Enerjisi Santrali';
      case 'hes':
      case 'hidroelektrik':
      case 'hydro':
        typeLabel = 'Hidroelektrik Santrali';
      default:
        typeLabel = 'Enerji Santrali';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: cardBg.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst renkli şerit
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık satırı: ikon + isim + kapat butonu
                  Row(
                    children: [
                      // Tip ikonu
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      // İsim ve tip
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              typeLabel,
                              style: TextStyle(
                                color: color.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Kapat butonu
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _dismissInfoCard,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.close, size: 18, color: textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bilgi satırları
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        // Konum
                        if (location.isNotEmpty)
                          _infoRow(Icons.location_on_outlined, 'Konum', location, color, textPrimary, textSecondary),
                        // Kapasite
                        if (mw != null && mw > 0) ...[
                          const SizedBox(height: 8),
                          _infoRow(Icons.bolt, 'Kapasite', '${mw.toStringAsFixed(1)} MW', color, textPrimary, textSecondary),
                        ],
                        // Koordinat
                        if (props['lat'] != null && props['lon'] != null) ...[
                          const SizedBox(height: 8),
                          _infoRow(
                            Icons.my_location_outlined, 'Koordinat',
                            '${(props['lat'] as num).toStringAsFixed(4)}, ${(props['lon'] as num).toStringAsFixed(4)}',
                            color, textPrimary, textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Ana haritada: "Detaylar" butonu
                  if (widget.onPinTap != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: color.withValues(alpha: 0.12),
                          foregroundColor: color,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Detayları Görüntüle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          final pinId = (props['id'] is num) ? (props['id'] as num).toInt() : int.tryParse(props['id']?.toString() ?? '');
                          if (pinId != null && _vmRef != null) {
                            final pin = _vmRef!.filteredPins.cast<Pin?>().firstWhere(
                              (p) => p?.id == pinId, orElse: () => null,
                            );
                            if (pin != null) {
                              _dismissInfoCard();
                              widget.onPinTap!(pin);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color accent, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, size: 14, color: accent.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─── Katman Kurulumu ──────────────────────────────────────────────

  Future<void> _initLayers() async {
    final style = _style;
    if (style == null) return;

    // Her stil yenilemesinde haritanın interaktif olduğundan emin ol.
    // srrpSetMapInteractive(false) bir önceki oturumdan kalıyorsa sıfırlar.
    if (kIsWeb) _jsSetMapInteractive(true);

    // Türkiye sınırları — harita dışına kaydırılamaz.
    if (kIsWeb) _jsSetMaxBounds(24.0, 34.0, 46.0, 44.0);

    // 1. Heatmap source
    try {
      await style.addSource(
        ml.GeoJsonSource(id: _heatmapSourceId, data: _heatmapToGeoJson([])),
      );
    } catch (e) {
      debugPrint('[MapLibre] heatmap source eklenemedi: $e');
    }

    // 1.b Heatmap Grid source
    try {
      await style.addSource(
        ml.GeoJsonSource(
          id: _heatmapGridSourceId,
          data: _heatmapGridToGeoJson([]),
        ),
      );
    } catch (e) {
      debugPrint('[MapLibre] heatmap grid source eklenemedi: $e');
    }

    // 2. Pin source
    try {
      await style.addSource(
        ml.GeoJsonSource(id: _pinsSourceId, data: _pinsToGeoJson([])),
      );
    } catch (e) {
      debugPrint('[MapLibre] pin source eklenemedi: $e');
    }

    // Gölge layer — 3D efekti için, başlangıçta şeffaf
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _pinsShadowLayerId,
          sourceId: _pinsSourceId,
          paint: <String, Object>{
            'circle-radius': 17,
            'circle-color': '#000000',
            'circle-opacity': 0.0,
            'circle-blur': 0.8,
            'circle-translate': [0, 4],
            'circle-pitch-alignment': 'map',
          },
        ),
      );
    } catch (e) {
      debugPrint('[MapLibre] shadow layer eklenemedi: $e');
    }

    // Ana pin layer
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _pinsLayerId,
          sourceId: _pinsSourceId,
          paint: <String, Object>{
            'circle-radius': [
              'interpolate',
              ['linear'],
              ['zoom'],
              4,
              9,
              10,
              14,
            ],
            'circle-color': ['get', 'color'],
            'circle-stroke-width': 2,
            'circle-stroke-color': '#FFFFFF',
            'circle-opacity': 0.9,
            'circle-pitch-alignment': 'map',
            'circle-pitch-scale': 'map',
          },
        ),
      );
    } catch (e) {
      debugPrint('[MapLibre] pins layer eklenemedi: $e');
    }

    // Pin isim etiketi (pin üstünde, beyaz)
    try {
      await style.addLayer(
        ml.SymbolStyleLayer(
          id: _pinsLabelLayerId,
          sourceId: _pinsSourceId,
          layout: <String, Object>{
            'text-field': ['get', 'name'],
            'text-size': 11,
            'text-offset': [0, -2.2],
            'text-anchor': 'bottom',
            'text-allow-overlap': false,
            'text-font': ['Open Sans Bold', 'Arial Unicode MS Bold'],
          },
          paint: <String, Object>{
            'text-color': '#FFFFFF',
            'text-halo-color': '#000000',
            'text-halo-width': 1.5,
          },
        ),
      );
    } catch (e) {
      debugPrint('[MapLibre] labels layer eklenemedi: $e');
    }

    // Şehir/ilçe etiketi (pin altında, soluk renk)
    try {
      await style.addLayer(
        ml.SymbolStyleLayer(
          id: _pinsCityLabelLayerId,
          sourceId: _pinsSourceId,
          layout: <String, Object>{
            'text-field': ['get', 'locationLabel'],
            'text-size': 10,
            'text-offset': [0, 1.8],
            'text-anchor': 'top',
            'text-allow-overlap': false,
            'text-font': ['Open Sans Regular', 'Arial Unicode MS Regular'],
          },
          paint: <String, Object>{
            'text-color': ['get', 'color'],
            'text-halo-color': '#000000',
            'text-halo-width': 1.2,
            'text-opacity': 0.9,
          },
        ),
      );
    } catch (e) {
      debugPrint('[MapLibre] city labels layer eklenemedi: $e');
    }

    // Pin hover (mousemove) ve click JS handler'larını kur
    if (kIsWeb) {
      _jsSetupPinHover();
      _jsSetupPinClick();
    }

    // GADM il/ilçe/bölge sınır katmanları
    // Dinamik URL: telefon veya PC fark etmez, doğru host'a bağlanır
    if (kIsWeb) {
      final base = BaseService.webApiBase;
      _jsLoadBorderLayers(
        '$base/geo/borders/provinces',
        '$base/geo/borders/districts',
        '$base/geo/borders/regions',
      );
    }

    // 3. Martin MVT source (opsiyonel)
    try {
      await style.addSource(
        ml.VectorSource(
          id: _martinSourceId,
          url: _martinTileJsonUrl,
          minZoom: 0,
          maxZoom: 14,
        ),
      );
    } catch (_) {}
  }

  // ─── Pin Sync ─────────────────────────────────────────────────────

  Future<void> _syncPins(List<Pin> pins, bool is3D, bool cluster) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    final pinsChanged = !_pinsEqual(pins, _lastPins);
    final clusterChanged = cluster != _lastClustering;

    if (!pinsChanged && !clusterChanged) return;

    _lastPins = List.from(pins);
    _lastClustering = cluster;

    if (cluster && kIsWeb) {
      // Kümeleme aktif: JS cluster source'u güncelle
      _jsUpdateClusterPins(_pinsToGeoJson(pins, isDark: _lastDarkMode));
      return; // Flutter pin source güncelleme atla
    }

    // Kümeleme kapatıldıysa temizle
    if (!cluster && clusterChanged && kIsWeb) {
      _jsClusterPinsClear();
    }

    // Normal Flutter pin source güncelleme
    if (pinsChanged) {
      try {
        await style.updateGeoJsonSource(
          id: _pinsSourceId,
          data: _pinsToGeoJson(pins, isDark: _lastDarkMode),
        );
      } catch (e) {
        debugPrint('[MapLibre] pin source güncelleme hatası: $e');
        return;
      }
    }

    if (is3D == _last3D) return;
    _last3D = is3D;

    // Gölge layer güncelle
    try {
      await style.removeLayer(_pinsShadowLayerId);
    } catch (_) {}
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _pinsShadowLayerId,
          sourceId: _pinsSourceId,
          paint: <String, Object>{
            'circle-radius': is3D ? 14 : 12,
            'circle-color': '#000000',
            'circle-opacity': is3D ? 0.28 : 0.0,
            'circle-blur': is3D ? 0.6 : 0.8,
            'circle-translate': is3D ? [0, 5] : [0, 4],
            'circle-pitch-alignment': 'map',
          },
        ),
        belowLayerId: _pinsLayerId,
      );
    } catch (e) {
      debugPrint('[MapLibre] shadow layer güncelleme hatası: $e');
    }

    // Ana pin layer güncelle
    try {
      await style.removeLayer(_pinsLayerId);
    } catch (_) {}
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _pinsLayerId,
          sourceId: _pinsSourceId,
          paint: <String, Object>{
            'circle-radius': [
              'interpolate',
              ['linear'],
              ['zoom'],
              4,
              is3D ? 8 : 6,
              10,
              is3D ? 13 : 10,
            ],
            'circle-color': ['get', 'color'],
            'circle-stroke-width': is3D ? 3 : 2,
            'circle-stroke-color': '#FFFFFF',
            'circle-opacity': 0.9,
            'circle-pitch-alignment': 'map',
            'circle-pitch-scale': 'map',
          },
        ),
        belowLayerId: _pinsLabelLayerId,
      );
    } catch (e) {
      debugPrint('[MapLibre] pins layer güncelleme hatası: $e');
    }

    // Circle layer yeniden oluşturuldu — hover ve click handler'larını yeniden bağla
    if (kIsWeb) {
      _jsSetupPinHover();
      _jsSetupPinClick();
    }
  }

  bool _pinsEqual(List<Pin> a, List<Pin> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  // ─── Raster Overlay Sync (statik heatmap) ─────────────────────────

  /// Standart haritayla birebir aynı render: compute pipeline → PNG → raster layer.
  Future<void> _syncRasterOverlay(MapViewModel vm) async {
    if (!_styleLoaded || !kIsWeb) return;

    final mode = vm.mlHeatmapMode;
    final points = vm.heatmapPoints;
    final layer = vm.currentLayer;

    // Gösterilecek katman yoksa kaldır
    if (mode == MlHeatmapMode.none ||
        points.isEmpty ||
        layer == MapLayerType.none) {
      if (_rasterActive) {
        try {
          _jsRemoveRasterOverlay();
        } catch (_) {}
        _rasterActive = false;
        _lastRasterMode = MlHeatmapMode.none;
        _lastRasterPtLen = -1;
      }
      return;
    }

    // Aynı veri tekrar geldiyse atla
    if (_rasterActive &&
        mode == _lastRasterMode &&
        points.length == _lastRasterPtLen) {
      return;
    }

    // Concurrent render koruması
    if (_rasterRendering) return;
    _rasterRendering = true;

    try {
      final result = await computeLayerPng(points, layer);
      if (result == null) return;

      if (!mounted) return;
      _jsSetRasterOverlay(
        result.base64Png,
        result.minLon,
        result.minLat,
        result.maxLon,
        result.maxLat,
        0.75,
      );
      _rasterActive = true;
      _lastRasterMode = mode;
      _lastRasterPtLen = points.length;
    } finally {
      _rasterRendering = false;
    }
  }

  // ─── Heatmap Sync ─────────────────────────────────────────────────

  Future<void> _syncHeatmapData(List<CityWeatherSummary> summaries) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;
    if (summaries.length == _lastSummary.length && _lastSummary.isNotEmpty) {
      return;
    }
    _lastSummary = List.from(summaries);
    try {
      await style.updateGeoJsonSource(
        id: _heatmapSourceId,
        data: _heatmapToGeoJson(summaries),
      );
    } catch (e) {
      debugPrint('[MapLibre] heatmap source güncelleme hatası: $e');
    }
  }

  Future<void> _syncHeatmapGridData(List<HeatmapPoint> points) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;
    try {
      await style.updateGeoJsonSource(
        id: _heatmapGridSourceId,
        data: _heatmapGridToGeoJson(points),
      );
    } catch (e) {
      debugPrint('[MapLibre] heatmap grid source güncelleme hatası: $e');
    }
  }

  Future<void> _syncHeatmapMode(
    MlHeatmapMode mode,
    double radius,
    double intensity,
    HeatmapPalette palette,
  ) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    final paramsChanged =
        radius != _lastRadius ||
        intensity != _lastIntensity ||
        palette != _lastPalette;
    if (mode == _lastHeatmap && !paramsChanged) return;

    _lastHeatmap = mode;
    _lastRadius = radius;
    _lastIntensity = intensity;
    _lastPalette = palette;

    // Mevcut heatmap layer'larını kaldır
    if (_solarActive) {
      try {
        await style.removeLayer(_heatmapSolarId);
      } catch (_) {}
      _solarActive = false;
    }
    if (_windActive) {
      try {
        await style.removeLayer(_heatmapWindId);
      } catch (_) {}
      _windActive = false;
    }
    if (_tempActive) {
      try {
        await style.removeLayer(_heatmapTempId);
      } catch (_) {}
      _tempActive = false;
    }

    if (mode == MlHeatmapMode.none) return;

    // Heatmap layer'ını ekle.
    final layerId = mode == MlHeatmapMode.solar
        ? _heatmapSolarId
        : mode == MlHeatmapMode.wind
        ? _heatmapWindId
        : _heatmapTempId;
    final paintDef = _buildHeatmapPaint(mode, radius, intensity, palette);

    bool added = false;

    // Önce shadow layer'ın altına yerleştirmeyi dene
    try {
      await style.addLayer(
        ml.HeatmapStyleLayer(
          id: layerId,
          sourceId: _heatmapGridSourceId,
          paint: paintDef,
        ),
        belowLayerId: _pinsShadowLayerId,
      );
      added = true;
    } catch (_) {}

    // Başarısızsa shadow olmadan (en üste) ekle
    if (!added) {
      try {
        await style.addLayer(
          ml.HeatmapStyleLayer(
            id: layerId,
            sourceId: _heatmapGridSourceId,
            paint: paintDef,
          ),
        );
        added = true;
      } catch (e) {
        debugPrint('[MapLibre] heatmap layer eklenemedi: $e');
      }
    }

    if (added) {
      if (mode == MlHeatmapMode.solar) _solarActive = true;
      if (mode == MlHeatmapMode.wind) _windActive = true;
      if (mode == MlHeatmapMode.temperature) _tempActive = true;
    }
  }

  // ─── Globe Sync ───────────────────────────────────────────────────

  Future<void> _syncGlobe(bool show) async {
    if (!_styleLoaded || show == _lastGlobe) return;
    final wasGlobe = _lastGlobe;
    _lastGlobe = show;
    // Flutter maplibre ^0.2.2'de style.setProjection() MapLibre GL JS 4.x ile
    // uyumsuz — JS shim üzerinden çağrılıyor.
    if (kIsWeb) _jsSetGlobe(show);

    // Globe kapatılınca Türkiye merkezine uç
    if (wasGlobe && !show && kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 200));
      _jsFlyTo(39.0, 35.5, 6.0); // Türkiye merkezi
    }
  }

  void _syncCloud(bool show, double opacity) {
    if (!_styleLoaded || !kIsWeb) return;
    final opacityChanged = (opacity - _lastCloudOpacity).abs() > 0.01;
    if (show == _lastCloud && !opacityChanged) return;

    if (show != _lastCloud) {
      _lastCloud = show;
      _lastCloudOpacity = opacity;
      _jsSetCloudLayer(show, opacity);
    } else if (show && opacityChanged) {
      // Sadece opacity değişti — layer yeniden yükleme olmadan güncelle
      _lastCloudOpacity = opacity;
      _jsSetCloudOpacity(opacity);
    }
  }

  // ─── Choropleth Sync ──────────────────────────────────────────────

  void _syncChoropleth(MapViewModel vm) {
    if (!_styleLoaded || !kIsWeb) return;
    final mode = vm.choroplethMode;
    final data = vm.choroplethData;

    // Mod değişmediyse ve veri aynıysa atla
    if (mode == _lastChoropleth && data == null) return;

    if (mode == ChoroplethMode.none) {
      if (_lastChoropleth != ChoroplethMode.none) {
        _jsSetChoropleth('none', null);
        _lastChoropleth = ChoroplethMode.none;
        _lastChoroplethDataJson = null;
      }
      return;
    }

    if (data == null || data.isEmpty) return;

    // Veriyi JSON'a çevir ve cache'le
    final dataJson = jsonEncode(data);
    if (mode == _lastChoropleth && dataJson == _lastChoroplethDataJson) return;

    _jsSetChoropleth(mode.dataKey, dataJson);
    _lastChoropleth = mode;
    _lastChoroplethDataJson = dataJson;
  }

  // ─── Terrain Sync ─────────────────────────────────────────────────
  //
  // İki yol:
  //   (a) HillshadeStyleLayer — native Flutter maplibre paketi ile (görsel gölgeleme)
  //   (b) setTerrain — JS shim üzerinden (gerçek 3D yükseklik)
  // Her ikisi de etkinleştirilir; terrain+sky kombinasyonu en iyi 3D görünümü verir.

  // ─── MVT Layer Sync (Aşama I) ─────────────────────────────────────
  // Hidro / Yasaklı / İletim katmanlarını state cache ile diff'leyip
  // değişen toggle'ları JS shim'lere iletir. Idempotent.
  void _syncMvtLayers(MapViewModel vm) {
    if (!kIsWeb || !_styleLoaded) return;
    if (vm.showHydroLayer != _lastHydroLayer) {
      _jsToggleHydroLayer(vm.showHydroLayer);
      _lastHydroLayer = vm.showHydroLayer;
    }
    if (vm.showRestrictedZoneLayer != _lastRestrictedLayer) {
      _jsToggleRestrictedLayer(vm.showRestrictedZoneLayer);
      _lastRestrictedLayer = vm.showRestrictedZoneLayer;
    }
    if (vm.showEnergyCorridorLayer != _lastEnergyCorridorLayer) {
      _jsToggleEnergyCorridorLayer(vm.showEnergyCorridorLayer);
      _lastEnergyCorridorLayer = vm.showEnergyCorridorLayer;
    }
  }

  Future<void> _syncTerrain(bool show) async {
    final style = _style;
    if (style == null || !_styleLoaded || show == _lastTerrain) return;
    _lastTerrain = show;

    if (show) {
      // Hillshade source
      try {
        await style.addSource(
          ml.RasterDemSource(
            id: _hillshadeSourceId,
            url: 'https://demotiles.maplibre.org/terrain-tiles/tiles.json',
            tileSize: 256,
          ),
        );
      } catch (_) {} // Zaten varsa hata verir — yoksay

      // Hillshade görsel katmanı (native pakette desteklenir)
      if (!_hillshadeActive) {
        try {
          await style.addLayer(
            ml.HillshadeStyleLayer(
              id: _hillshadeLayerId,
              sourceId: _hillshadeSourceId,
              paint: <String, Object>{
                'hillshade-illumination-direction': 335,
                'hillshade-illumination-anchor': 'viewport',
                'hillshade-exaggeration': 0.45,
                'hillshade-shadow-color': '#000000',
                'hillshade-highlight-color': '#ffffff',
              },
            ),
            belowLayerId: _pinsShadowLayerId,
          );
          _hillshadeActive = true;
        } catch (e) {
          debugPrint('[MapLibre] hillshade layer hatası: $e');
        }
      }

      // Gerçek 3D terrain + gökyüzü + kamera eğimi (JS shim)
      if (kIsWeb) {
        _jsSetTerrain(true);
        _jsSetSky(true);
        _jsSetPitch(55.0); // fill-extrusion için pitch şart
      }
    } else {
      // Kaldır
      if (_hillshadeActive) {
        try {
          await style.removeLayer(_hillshadeLayerId);
        } catch (_) {}
        _hillshadeActive = false;
      }
      try {
        await style.removeSource(_hillshadeSourceId);
      } catch (_) {}

      if (kIsWeb) {
        _jsSetTerrain(false);
        _jsSetSky(false);
        // Binalar da açıksa pitch koru, değilse sıfırla
        final vm = mounted
            ? Provider.of<MapViewModel>(context, listen: false)
            : null;
        if (vm != null && !vm.show3DBuildings) _jsSetPitch(0.0);
      }
    }
  }

  // ─── 3D Buildings Sync ────────────────────────────────────────────
  //
  // Flutter maplibre ^0.2.2 "source-layer" parametresini desteklemiyor.
  // index.html'deki srrpAddLayer JS yardımcısı kullanılır.

  Future<void> _syncBuildings(bool show) async {
    if (!kIsWeb || !_styleLoaded || show == _lastBuildings) return;
    _lastBuildings = show;

    if (show) {
      // srrpAddBuildings: source-layer auto-detect + render_height/height fallback
      _jsAddBuildings(_pinsShadowLayerId);
      // fill-extrusion yalnızca pitch > 0'da görünür
      _jsSetPitch(55.0);
    } else {
      _jsRemoveBuildings();
      // Arazi da açık değilse pitch sıfırla
      final vm = mounted
          ? Provider.of<MapViewModel>(context, listen: false)
          : null;
      if (vm != null && !vm.show3DTerrain) _jsSetPitch(0.0);
    }
  }

  // ─── Neon Veri Noktaları Sync ─────────────────────────────────────
  //
  // Heatmap source üzerinde iki circle layer:
  //   1. Glow (dış halka) — büyük yarıçap + yüksek blur → ışıma efekti
  //   2. Dot  (iç nokta)  — küçük, keskin, parlak merkez
  //
  // Renk aktif heatmap moduna göre seçilir:
  //   solar → sarı (#FFD54F),  wind → cyan (#4fc3f7)
  //
  // Layer sırası (alttan üste): heatmap → glow → dot → shadow → pins

  Future<void> _syncDataPoints(
    MlHeatmapMode mode,
    List<CityWeatherSummary> summaries,
  ) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;
    if (mode == _lastDataMode) return;
    _lastDataMode = mode;

    // Mevcut layer'ları kaldır
    if (_dataGlowActive) {
      try {
        await style.removeLayer(_dataGlowLayerId);
      } catch (_) {}
      _dataGlowActive = false;
    }
    if (_dataDotsActive) {
      try {
        await style.removeLayer(_dataDotsLayerId);
      } catch (_) {}
      _dataDotsActive = false;
    }

    if (mode == MlHeatmapMode.none || summaries.isEmpty) return;

    final bool isSolar = mode == MlHeatmapMode.solar;
    final bool isTemp = mode == MlHeatmapMode.temperature;
    final String glowColor = isSolar
        ? '#FFD54F'
        : isTemp
        ? '#ff7043'
        : '#4fc3f7';
    final String dotColor = isSolar
        ? '#FFF9C4'
        : isTemp
        ? '#ffccbc'
        : '#b3e5fc';
    final String weightProp = isSolar
        ? 'solar_weight'
        : isTemp
        ? 'temp_weight'
        : 'wind_weight';

    // Glow ring
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _dataGlowLayerId,
          sourceId: _heatmapSourceId,
          paint: <String, Object>{
            'circle-radius': [
              'interpolate',
              ['linear'],
              ['zoom'],
              3,
              7,
              10,
              15,
            ],
            'circle-color': glowColor,
            'circle-opacity': [
              'interpolate',
              ['linear'],
              ['get', weightProp],
              0.0,
              0.0,
              0.2,
              0.12,
              1.0,
              0.38,
            ],
            'circle-blur': 1.2,
          },
        ),
        belowLayerId: _pinsShadowLayerId,
      );
      _dataGlowActive = true;
    } catch (e) {
      debugPrint('[MapLibre] data glow layer hatası: $e');
    }

    // Inner dot
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _dataDotsLayerId,
          sourceId: _heatmapSourceId,
          paint: <String, Object>{
            'circle-radius': [
              'interpolate',
              ['linear'],
              ['zoom'],
              3,
              2,
              10,
              4,
            ],
            'circle-color': dotColor,
            'circle-opacity': [
              'interpolate',
              ['linear'],
              ['get', weightProp],
              0.0,
              0.0,
              0.15,
              0.35,
              1.0,
              0.88,
            ],
            'circle-blur': 0.15,
          },
        ),
        belowLayerId: _pinsShadowLayerId,
      );
      _dataDotsActive = true;
    } catch (e) {
      debugPrint('[MapLibre] data dots layer hatası: $e');
    }
  }

  // ─── Rüzgar Parçacıkları Sync ──────────────────────────────────────
  //
  // showWindArrows aktifken canvas tabanlı parçacık animasyonu başlatır.
  // JS shim (index.html → srrpStartWindParticles) haritanın container'ına
  // saydam bir <canvas> ekler ve requestAnimationFrame döngüsü çalıştırır.

  Future<void> _syncWindParticles(bool show, List<WindVector> vectors) async {
    if (!kIsWeb || !_styleLoaded) return;

    final changed =
        show != _lastParticles || vectors.length != _lastParticleVectorsLen;
    if (!changed) return;

    _lastParticles = show;
    _lastParticleVectorsLen = vectors.length;

    if (show && vectors.isNotEmpty) {
      _jsStartWindParticles(_windVectorsToGeoJson(vectors));
    } else {
      _jsStopWindParticles();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // MapLibre GL JS henüz yüklenmediyse yükleniyor ekranı göster
    if (!_mapLibreScriptReady) {
      return ColoredBox(
        color: const Color(0xFF0D0D0D).withValues(alpha: 0.6),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF00BCD4),
                strokeWidth: 2,
              ),
              SizedBox(height: 12),
              Text(
                'MapLibre yükleniyor…',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final vm = Provider.of<MapViewModel>(context, listen: false);
    final styleUrl = vm.mlBaseStyle.styleUrl;

    return Stack(
      children: [
        KeyedSubtree(
          key: ValueKey(styleUrl),
          child: ml.MapLibreMap(
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
        ),

        // Beta bandı kaldırıldı

        // Pin hover tooltip (sol alt köşe)
        if (_hoveredPin != null && _selectedPinProps == null)
          Positioned(
            bottom: 80,
            left: 20,
            child: _buildPinHoverCard(_hoveredPin!, isDark: _lastDarkMode),
          ),

        // Pin bilgi kartı (tıklanan pin — showcase veya gerçek)
        if (_selectedPinProps != null)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Center(
              child: _buildPinInfoCard(_selectedPinProps!, isDark: _lastDarkMode),
            ),
          ),

        // Style yükleniyor overlay
        if (!_styleLoaded)
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
                  SizedBox(height: 12),
                  Text(
                    'Harita yükleniyor...',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

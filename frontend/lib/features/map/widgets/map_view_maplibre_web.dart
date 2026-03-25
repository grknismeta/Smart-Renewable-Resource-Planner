import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:provider/provider.dart';

import 'package:frontend/core/constants/map_constants.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/features/map/layers/map_layers_system.dart'
    show computeLayerPng;
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/weather_model.dart';

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

@JS('window.srrpSetProvinceClickFn')
external void _jsSetProvinceClickFn(JSFunction fn);

@JS('window.srrpSetRegionClickFn')
external void _jsSetRegionClickFn(JSFunction fn);

@JS('window.srrpSetDistrictClickFn')
external void _jsSetDistrictClickFn(JSFunction fn);

@JS('window.srrpSetMapInteractive')
external void _jsSetMapInteractive(bool enable);

@JS('window.srrpSetClickGuard')
external void _jsSetClickGuard(bool active);

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
const _martinTileJsonUrl = 'http://localhost:3000/public.weather_tiles';

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

String _pinColorHex(String type) {
  switch (type.toLowerCase()) {
    case 'güneş paneli':
    case 'solar':
      return '#FFA726';
    case 'rüzgar türbini':
    case 'wind':
      return '#29B6F6';
    case 'hidroelektrik':
    case 'hes':
    case 'hydro':
      return '#42A5F5';
    default:
      return '#66BB6A';
  }
}

String _pinsToGeoJson(List<Pin> pins) => jsonEncode({
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
            'color': _pinColorHex(p.type),
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

  // Neon veri noktaları
  bool _dataGlowActive = false;
  bool _dataDotsActive = false;
  MlHeatmapMode _lastDataMode = MlHeatmapMode.none;

  // Rüzgar parçacıkları
  bool _lastParticles = false;
  int _lastParticleVectorsLen = 0;

  // Kümeleme
  bool _lastClustering = false;

  // ─── Pin hover (JS → Dart callback) ───────────────────────────────
  Pin? _hoveredPin;
  JSFunction? _pinHoverJsCallback;
  bool _hoverCallbackRegistered = false;

  // ─── Selection callbacks (JS → Dart) ─────────────────────────────
  JSFunction? _provinceClickJsCallback;
  JSFunction? _regionClickJsCallback;
  JSFunction? _districtClickJsCallback;
  bool _selectionCallbacksRegistered = false;
  SelectionLevel _lastSelectionLevel = SelectionLevel.none;
  String? _lastRegionName;
  String? _lastProvinceName;

  // ─── Animasyon frame callback ──────────────────────────────────────
  JSFunction? _animFrameJsCallback;
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
                debugPrint('[MapLibre] Style load timeout — spinner zorla kaldırılıyor');
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
      // Animasyon JS bridge'i ViewModel'e kaydet (bir kez)
      if (!_animBridgeRegistered) {
        _vmRef!.registerJsBridge(
          loadFn: (json) {
            if (kIsWeb) _jsLoadAnimationData(json);
          },
          playFn: (fps) {
            if (kIsWeb) _jsAnimPlayRaw(1000.0 / fps.clamp(1, 60));
          },
          stopFn: () {
            if (kIsWeb) _jsAnimStopRaw();
          },
          seekFn: (idx) {
            if (kIsWeb) _jsAnimSeekRaw(idx);
          },
        );
        // JS → Flutter frame değişim callback'i
        if (kIsWeb) {
          _animFrameJsCallback = _handleAnimFrameJs.toJS;
          _jsSetAnimFrameCallback(_animFrameJsCallback!);
        }
        _animBridgeRegistered = true;
      }
    });
  }

  @override
  void dispose() {
    _styleLoadTimeout?.cancel();
    _vmRef?.removeListener(_onVmChanged);
    if (kIsWeb && _hoverCallbackRegistered) {
      _jsSetPinHoverFn((() {}).toJS);
    }
    super.dispose();
  }

  /// JS mousemove/mouseleave eventi → Dart pin hover state
  void _handlePinHoverJs(JSAny? idArg) {
    if (!mounted || _vmRef == null) return;
    final idStr = idArg?.dartify()?.toString() ?? '';
    final id = int.tryParse(idStr);
    final pin = id != null
        ? _vmRef!.filteredPins.cast<Pin?>().firstWhere(
            (p) => p?.id == id,
            orElse: () => null,
          )
        : null;
    if (_hoveredPin?.id != pin?.id) {
      setState(() => _hoveredPin = pin);
    }
  }

  /// JS bölge tıklama → ViewModel.selectRegion
  void _handleRegionClickJs(JSAny? nameArg) {
    if (!mounted || _vmRef == null) return;
    final name = nameArg?.dartify()?.toString() ?? '';
    if (name.isNotEmpty) _vmRef!.selectRegion(name);
  }

  /// JS il tıklama → ViewModel.selectProvince
  void _handleProvinceClickJs(JSAny? nameArg) {
    if (!mounted || _vmRef == null) return;
    final name = nameArg?.dartify()?.toString() ?? '';
    if (name.isNotEmpty) _vmRef!.selectProvince(name);
  }

  /// JS ilçe tıklama → ViewModel.selectDistrict
  /// Gelen değer "province|district" formatındadır (composite hover'dan gelir).
  void _handleDistrictClickJs(JSAny? nameArg) {
    if (!mounted || _vmRef == null) return;
    final raw = nameArg?.dartify()?.toString() ?? '';
    if (raw.isEmpty) return;
    // "İstanbul|Kadıköy" → province=İstanbul, district=Kadıköy
    final sep = raw.indexOf('|');
    if (sep > 0) {
      final province = raw.substring(0, sep);
      final district = raw.substring(sep + 1);
      if (district.isNotEmpty) {
        _vmRef!.selectDistrict(district, province: province);
      }
    } else {
      // Fallback: province bağlamı yok (eski format)
      _vmRef!.selectDistrict(raw);
    }
  }

  /// JS animasyon frame callback → ViewModel.onAnimFrameChanged
  void _handleAnimFrameJs(JSAny? indexArg, JSAny? tsArg) {
    if (!mounted || _vmRef == null) return;
    final index = (indexArg?.dartify() as num?)?.toInt() ?? 0;
    final ts = tsArg?.dartify()?.toString() ?? '';
    _vmRef!.onAnimFrameChanged(index, ts);
  }

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
      // İlçe seçildiğinde (selectedDistrictName != null) harita katmanlarını
      // yeniden kurma — sadece veri kartı güncellenir. Harita katmanları
      // yalnızca seviye değiştiğinde veya il→ilçe geçişinde (districtName null) güncellenir.
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
      }
    }

    // 2. Bulut katmanı — senkron JS güncellemesi
    try { _syncCloud(vm.showCloudLayer, vm.cloudOpacity); } catch (_) {}

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
    // Animasyon modu aktifken her frame güncel veri gerekir
    if (vm.isAnimationMode) return true;
    // Harita görsel özellikleri
    if (vm.showGlobe != _lastGlobe) return true;
    if (vm.show3DTerrain != _lastTerrain) return true;
    if (vm.show3DBuildings != _lastBuildings) return true;
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
    switch (vm.selectionLevel) {
      case SelectionLevel.none:
        _jsClearSelectionMode();
      case SelectionLevel.region:
        _jsSetupRegionMode();
      case SelectionLevel.province:
        _jsSetupProvinceMode(vm.selectedRegionName);
      case SelectionLevel.district:
        _jsSetupDistrictMode(vm.selectedProvinceName); // null = tüm ilçeler
    }
  }

  Future<void> _syncAll(MapViewModel vm) async {
    if (_syncing) return;
    _syncing = true;
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
    if (vm.isAnimationMode) {
      // Animasyon: JS tabanlı heatmap layer kullan
      try {
        await _syncHeatmapGridData(vm.heatmapPoints);
        await _syncHeatmapMode(
          vm.mlHeatmapMode,
          vm.heatmapRadius,
          vm.heatmapIntensity,
          vm.heatmapPalette,
        );
      } catch (e) {
        debugPrint('[MapLibre] _syncHeatmapMode/Grid hata: $e');
      }
      // Varsa raster overlay'i kaldır
      if (_rasterActive && kIsWeb) {
        try {
          _jsRemoveRasterOverlay();
        } catch (_) {}
        _rasterActive = false;
        _lastRasterMode = MlHeatmapMode.none;
        _lastRasterPtLen = -1;
      }
    } else {
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
    if (_syncPending && mounted && _vmRef != null) {
      _syncPending = false;
      _syncAll(_vmRef!);
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

  // ─── Pin Etkileşimi ───────────────────────────────────────────────
  //
  // queryLayers yerine konum tabanlı yakınlık tespiti kullanılıyor.
  // Sebep: queryLayers'da base-map feature'larında e.layer null olabiliyor →
  // exception yutulup onPinTap hiç çağrılmıyordu.

  Future<void> _onMapClick(ml.Position point) async {
    // Dialog açıkken harita tıklamalarını yoksay
    if (MapViewMapLibre._clickGuardActive) return;

    final vm = Provider.of<MapViewModel>(context, listen: false);

    // 1. Pin yakınlık kontrolü
    if (widget.onPinTap != null && vm.filteredPins.isNotEmpty) {
      final pin = _nearestPin(vm.filteredPins, point);
      if (pin != null) {
        widget.onPinTap!(pin);
        return;
      }
    }

    // 2. Harita tıklaması
    widget.onMapTap?.call(point);
  }

  /// Tıklanan konuma en yakın pin — zoom'a göre ölçeklenen eşik kullanır.
  Pin? _nearestPin(List<Pin> pins, ml.Position point) {
    if (pins.isEmpty) return null;

    // Zoom ne kadar yüksekse, eşik o kadar sıkı olmalı.
    // Yaklaşık formül: threshold = 0.5 / 2^(zoom - 5)
    // Zoom 6'da ≈ 0.25°, Zoom 10'da ≈ 0.016°, Zoom 14'de ≈ 0.001°
    // Controller erişilemezse eskiden 0.08° (≈8km) sabitti. İlçe tıklamalarını bozduğu için 0.015° seviyesine düşürüldü.
    const double fixedThreshold = 0.015;

    Pin? nearest;
    double minDist = double.infinity;
    for (final p in pins) {
      final dLat = p.latitude - point.lat.toDouble();
      final dLon = p.longitude - point.lng.toDouble();
      final dist = dLat * dLat + dLon * dLon;
      if (dist < minDist) {
        minDist = dist;
        nearest = p;
      }
    }
    return minDist < (fixedThreshold * fixedThreshold) ? nearest : null;
  }

  // ─── Pin Hover Tooltip ────────────────────────────────────────────

  static Color _pinColor(String type) {
    switch (type.toLowerCase()) {
      case 'güneş paneli':
      case 'solar':
        return const Color(0xFFFFA726);
      case 'rüzgar türbini':
      case 'wind':
        return const Color(0xFF29B6F6);
      case 'hidroelektrik':
      case 'hes':
      case 'hydro':
        return const Color(0xFF42A5F5);
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

  Widget _buildPinHoverCard(Pin pin) {
    final color = _pinColor(pin.type);
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

  // ─── Katman Kurulumu ──────────────────────────────────────────────

  Future<void> _initLayers() async {
    final style = _style;
    if (style == null) return;

    // Her stil yenilemesinde haritanın interaktif olduğundan emin ol.
    // srrpSetMapInteractive(false) bir önceki oturumdan kalıyorsa sıfırlar.
    if (kIsWeb) _jsSetMapInteractive(true);

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

    // Pin hover (mousemove) JS handler'ını kur
    if (kIsWeb) _jsSetupPinHover();

    // GADM il/ilçe/bölge sınır katmanları
    if (kIsWeb) {
      const base = 'http://127.0.0.1:8000';
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
      _jsUpdateClusterPins(_pinsToGeoJson(pins));
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
          data: _pinsToGeoJson(pins),
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

    // Circle layer yeniden oluşturuldu — hover handler'ı yeniden bağla
    if (kIsWeb) _jsSetupPinHover();
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
    _lastGlobe = show;
    // Flutter maplibre ^0.2.2'de style.setProjection() MapLibre GL JS 4.x ile
    // uyumsuz — JS shim üzerinden çağrılıyor.
    if (kIsWeb) _jsSetGlobe(show);
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

  // ─── Terrain Sync ─────────────────────────────────────────────────
  //
  // İki yol:
  //   (a) HillshadeStyleLayer — native Flutter maplibre paketi ile (görsel gölgeleme)
  //   (b) setTerrain — JS shim üzerinden (gerçek 3D yükseklik)
  // Her ikisi de etkinleştirilir; terrain+sky kombinasyonu en iyi 3D görünümü verir.

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
      return const ColoredBox(
        color: Color(0xFF0D0D0D),
        child: Center(
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

        // Beta bandı
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text(
                  'MapLibre 3D',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Pin hover tooltip (sağ alt köşe)
        if (_hoveredPin != null)
          Positioned(
            bottom: 80,
            left: 20,
            child: _buildPinHoverCard(_hoveredPin!),
          ),

        // Yükleniyor
        if (!_styleLoaded)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'MapLibre GL yükleniyor...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

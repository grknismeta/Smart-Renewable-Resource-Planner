import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:provider/provider.dart';
// http import kaldırıldı — il/ilçe seçimi artık tamamen client-side (asset GeoJSON)
import 'package:frontend/core/constants/map_constants.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/weather_model.dart';

// ─── Layer / Source ID'leri ───────────────────────────────────────────────────

const _pinsSourceId       = 'srrp-pins';
const _pinsShadowLayerId  = 'srrp-pins-shadow';
const _pinsLayerId        = 'srrp-pins-circles';
const _pinsLabelLayerId   = 'srrp-pins-labels';

const _heatmapSourceId    = 'srrp-heatmap';
const _heatmapGridSourceId = 'srrp-heatmap-grid';
const _heatmapSolarId     = 'srrp-heatmap-solar';
const _heatmapWindId      = 'srrp-heatmap-wind';

const _clusterSourceId    = 'srrp-clusters';
const _clusterCircleId    = 'srrp-cluster-circles';
const _clusterCountId     = 'srrp-cluster-counts';

const _cloudSourceId      = 'srrp-cloud-tiles';
const _cloudLayerId       = 'srrp-cloud-layer';

const _bordersSourceId    = 'srrp-borders';
const _bordersFillLayerId = 'srrp-borders-fill';
const _bordersLineLayerId = 'srrp-borders-line';

// B5 (2026-06-01): PostGIS MVT vektör katmanları. Paket source-layer'ı SOURCE
// üzerinde tanımlıyor (VectorSource.sourceLayer) → her source-layer için ayrı
// VectorSource (aynı tile URL). Web tek source + layer-level source-layer.
const _mvtHydroSrc       = 'srrp-mvt-hydro-src';
const _mvtRestrictedSrc  = 'srrp-mvt-restricted-src';
const _mvtEnergySrc      = 'srrp-mvt-energy-src';
const _mvtHydroFillId    = 'srrp-mvt-hydro-fill';
const _mvtHydroLineId    = 'srrp-mvt-hydro-line';
const _mvtRestrictedId   = 'srrp-mvt-restricted-fill';
const _mvtEnergyId       = 'srrp-mvt-energy-line';

// İl modu overlay: seçili ilin ilçeleri + mavi sınır (ana borders'ın üstünde)
const _overlaySourceId    = 'srrp-overlay-borders';
const _overlayFillLayerId = 'srrp-overlay-fill';
const _overlayLineLayerId = 'srrp-overlay-line';
const _overlayProvLineId  = 'srrp-overlay-prov-line';

// Seçili ilçe mavi çerçeve (tüm modlarda kullanılır — ilçe seçildiğinde belirginleşir)
const _districtHighlightSourceId = 'srrp-district-highlight';
const _districtHighlightLayerId  = 'srrp-district-highlight-line';

const _hillshadeSourceId  = 'srrp-hillshade-dem';
const _hillshadeLayerId   = 'srrp-hillshade';

// 2026-05-27 (O1.4): İzohips contour overlay — OpenTopoMap raster.
// CC-BY-SA attribution UI tarafında (layers_panel) gösteriliyor.
const _contourSourceId    = 'srrp-contour-tiles';
const _contourLayerId     = 'srrp-contour-layer';

// 1.B (yeniden): animation province overlay constant'ları emekliye ayrıldı
// — animasyon artık choropleth bridge'ten beslenir (`_syncChoropleth`).

// ─── Heatmap Paint Tanımları ──────────────────────────────────────────────────

const _solarHeatmapPaint = <String, Object>{
  'heatmap-weight':    ['interpolate', ['linear'], ['get', 'value'], 0, 0, 1, 1],
  'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 0, 1, 10, 3],
  'heatmap-color': [
    'interpolate', ['linear'], ['heatmap-density'],
    0,    'rgba(255,255,178,0)',
    0.25, 'rgba(254,204,92,0.6)',
    0.5,  'rgba(253,141,60,0.8)',
    0.75, 'rgba(240,59,32,0.9)',
    1,    'rgba(189,0,38,1)',
  ],
  'heatmap-radius':  ['interpolate', ['linear'], ['zoom'], 0, 40, 10, 80],
  'heatmap-opacity': 0.75,
};

const _windHeatmapPaint = <String, Object>{
  'heatmap-weight':    ['interpolate', ['linear'], ['get', 'value'], 0, 0, 1, 1],
  'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 0, 1, 10, 3],
  'heatmap-color': [
    'interpolate', ['linear'], ['heatmap-density'],
    0,    'rgba(230,240,255,0)',
    0.25, 'rgba(116,169,207,0.6)',
    0.5,  'rgba(43,140,190,0.8)',
    0.75, 'rgba(4,90,141,0.9)',
    1,    'rgba(2,56,88,1)',
  ],
  'heatmap-radius':  ['interpolate', ['linear'], ['zoom'], 0, 40, 10, 80],
  'heatmap-opacity': 0.75,
};

// ─── Renk / GeoJSON Yardımcıları ─────────────────────────────────────────────

String _pinColorHex(String type) {
  switch (type.toLowerCase()) {
    case 'güneş paneli': case 'solar':  return '#FFA726';
    case 'rüzgar türbini': case 'wind': return '#29B6F6';
    case 'hidroelektrik': case 'hes': case 'hydro': return '#1DB954';
    default:                            return '#66BB6A';
  }
}

String _pinsToGeoJson(List<Pin> pins) => jsonEncode({
  'type': 'FeatureCollection',
  'features': pins.map((p) => {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': [p.longitude, p.latitude]},
    'properties': {'id': p.id, 'name': p.name, 'type': p.type, 'color': _pinColorHex(p.type)},
  }).toList(),
});

String _heatmapToGeoJson(List<CityWeatherSummary> summaries) {
  if (summaries.isEmpty) return '{"type":"FeatureCollection","features":[]}';
  double maxRad  = summaries.fold(0.0, (m, s) => (s.totalRadiation ?? 0) > m ? (s.totalRadiation ?? 0).toDouble() : m);
  double maxWind = summaries.fold(0.0, (m, s) => (s.avgWindSpeed100m ?? 0) > m ? (s.avgWindSpeed100m ?? 0).toDouble() : m);
  if (maxRad  == 0) maxRad  = 1;
  if (maxWind == 0) maxWind = 1;
  return jsonEncode({'type': 'FeatureCollection', 'features': summaries.map((s) => {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': [s.lon, s.lat]},
    'properties': {
      'solar_weight': ((s.totalRadiation ?? 0) / maxRad).clamp(0.0, 1.0),
      'wind_weight':  ((s.avgWindSpeed100m ?? 0) / maxWind).clamp(0.0, 1.0),
    },
  }).toList()});
}

String _heatmapGridToGeoJson(List<HeatmapPoint> points) {
  if (points.isEmpty) return '{"type":"FeatureCollection","features":[]}';
  return jsonEncode({'type': 'FeatureCollection', 'features': points.map((p) => {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': [p.longitude, p.latitude]},
    'properties': {'value': p.value},
  }).toList()});
}

// ─── Flutter-level Pin Kümeleme ──────────────────────────────────────────────

/// Zoom seviyesine göre grid-based pin kümeleme.
/// Her grid hücresindeki pinleri tek bir cluster noktasına toplar.
class _PinCluster {
  final double centerLat;
  final double centerLon;
  final List<Pin> pins;
  _PinCluster(this.centerLat, this.centerLon, this.pins);
}

List<_PinCluster> _clusterPins(List<Pin> pins, double zoom) {
  if (pins.isEmpty) return [];
  // Zoom arttıkça grid küçülür → daha az kümeleme
  // zoom 4 → gridSize ~2.0°, zoom 8 → ~0.125°, zoom 12 → ~0.008°
  final gridSize = 32.0 / math.pow(2, zoom.clamp(1, 18));
  final Map<String, List<Pin>> grid = {};
  for (final p in pins) {
    final gx = (p.longitude / gridSize).floor();
    final gy = (p.latitude / gridSize).floor();
    final key = '$gx,$gy';
    (grid[key] ??= []).add(p);
  }
  return grid.values.map((group) {
    final lat = group.fold(0.0, (s, p) => s + p.latitude) / group.length;
    final lon = group.fold(0.0, (s, p) => s + p.longitude) / group.length;
    return _PinCluster(lat, lon, group);
  }).toList();
}

String _clustersToGeoJson(List<_PinCluster> clusters) {
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': clusters
        .where((c) => c.pins.length > 1)
        .map((c) => {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [c.centerLon, c.centerLat],
              },
              'properties': {
                'count': c.pins.length,
                'label': '${c.pins.length}',
              },
            })
        .toList(),
  });
}

/// Kümelenmiş pinlerden tekil (kümelenmemiş) pinleri döndürür.
String _unclusteredPinsToGeoJson(List<_PinCluster> clusters) {
  final singles = clusters.where((c) => c.pins.length == 1).expand((c) => c.pins).toList();
  return _pinsToGeoJson(singles);
}

// ─── MapViewMapLibre (Native) ─────────────────────────────────────────────────

class MapViewMapLibre extends StatefulWidget {
  final Function(ml.Position)? onMapTap;
  final Function(Pin)? onPinTap;

  const MapViewMapLibre({super.key, this.onMapTap, this.onPinTap});

  /// Aktif native MapController referansı (state tarafından atanır).
  static ml.MapController? _activeController;

  /// 2026-06-01 (B4): Aktif State referansı — static ML choropleth metodlarının
  /// canlı haritaya (style + render) erişebilmesi için. StyleLoaded'da atanır,
  /// dispose'da temizlenir.
  static _MapViewMapLibreState? _activeState;

  /// Wind overlay gibi dış widget'ların kamera dönüşümü yapabilmesi için.
  static ml.MapController? get activeControllerForOverlay => _activeController;

  /// Native: MapLibre SDK animasyonlu kamera geçişi.
  static void flyTo(double lat, double lon, {double zoom = 10.0}) {
    _activeController?.animateCamera(
      center: ml.Position(lon, lat),
      zoom: zoom,
      nativeDuration: const Duration(milliseconds: 800),
    );
  }

  /// Haritayı bir adım yakınlaştır.
  static Future<void> zoomIn() async {
    final curZoom = _activeController?.camera?.zoom;
    if (curZoom != null) {
      _activeController?.animateCamera(
        zoom: curZoom + 1.0,
        nativeDuration: const Duration(milliseconds: 300),
      );
    }
  }

  /// Haritayı bir adım uzaklaştır.
  static Future<void> zoomOut() async {
    final curZoom = _activeController?.camera?.zoom;
    if (curZoom != null) {
      _activeController?.animateCamera(
        zoom: curZoom - 1.0,
        nativeDuration: const Duration(milliseconds: 300),
      );
    }
  }

  /// Native: web-only özellik, no-op.
  static void setupProvinceSelect(bool enable) {}
  static void setupRegionMode() {}
  static void setupProvinceMode({String? regionFilter}) {}
  static void setupDistrictMode(String provinceName) {}
  static void clearSelectionMode() {}
  static void setInteractive(bool enable) {}
  static void setClickGuard(bool active) {}
  static void setPinPlacementActive(bool active) {}
  static void setTerrainExaggeration(double exaggeration) {}
  static void setHillshadeIntensity(double intensity) {}
  // 2026-05-27 (O1.4): İzohips contour native'de VM-watch ile senkronize
  // edilir (_syncContourLayer). Static metodlar no-op — web JS interop için var.
  static void toggleContour(bool enabled, double opacity,
      {String source = 'opentopo'}) {}
  static void setContourOpacity(double opacity) {}
  // M-B.2/3 — ML projeksiyon choropleth. 2026-06-01 (B4): native'e port edildi.
  // Aktif State'e köprülenir; State yoksa (harita kapalı) no-op.
  static void setMlChoropleth(String dataJson) {
    _activeState?._applyMlChoropleth(dataJson);
  }

  static void clearMlChoropleth() {
    _activeState?._clearMlChoropleth();
  }
  // 2026-05-08 Madde 1: Pin preview marker (native polish Sprint 2).
  static void showPreviewPin(LatLng? point) {}
  // Madde 5+6+7: Coğrafi anchor — native polish Sprint 2.
  static Offset? projectLngLatToScreen(LatLng point) => null;
  static void registerAnchorListener(VoidCallback? callback) {}
  static void setMaxBounds(
      double swLng, double swLat, double neLng, double neLat) {
    // Native'de maxBounds MapOptions ile init-time'da ayarlanıyor.
    // Runtime değişikliği globe toggle ile widget rebuild üzerinden yapılır.
  }
  static void clearMaxBounds() {}
  static void setShowcasePins(String geojsonStr) {}

  @override
  State<MapViewMapLibre> createState() => _MapViewMapLibreState();
}

class _MapViewMapLibreState extends State<MapViewMapLibre> {
  ml.StyleController? _style;
  bool _styleLoaded = false;
  bool _syncing = false;
  // 2026-06-01: widget dispose edildi mi — async style callback'leri (özellikle
  // ML choropleth) teardown sonrası native source'a dokunup SIGSEGV yaratmasın.
  bool _disposed = false;
  // B8: globe durumu (build'de güncellenir) — move event'inde Provider okumamak
  // için cache. + constrain re-entrancy kilidi.
  bool _globeForConstrain = false;
  bool _constraining = false;

  List<Pin>                _lastPins    = [];
  List<CityWeatherSummary> _lastSummary = [];
  MlHeatmapMode            _lastHeatmap = MlHeatmapMode.none;
  bool                     _last3D      = false;

  bool _solarActive     = false;
  bool _windActive      = false;
  bool _hillshadeActive = false;
  bool _lastTerrain     = false;

  // B5 (2026-06-01): MVT vektör katmanları — VectorSource ile NATIVE destek.
  bool _lastHydroLayer = false;
  bool _lastRestrictedLayer = false;
  bool _lastEnergyCorridorLayer = false;
  bool _mvtHydroActive = false;
  bool _mvtRestrictedActive = false;
  bool _mvtEnergyActive = false;
  bool _lastClustering  = false;
  bool _clusterLayersActive = false;
  bool _lastCloud       = false;
  bool _cloudActive     = false;

  // 2026-05-27 (O1.4): İzohips contour state.
  bool   _lastContour        = false;
  double _lastContourOpacity = 0.55;
  bool   _contourActive      = false;
  bool _bordersActive   = false;
  // 2026-06-01: Yüklü sınır KATMANININ türü/içeriği. `_bordersActive` (tek bool)
  // province/district ayrımı yapamadığı için mod geçişinde (ör. Bölge→İlçe) yeni
  // sınırlar yüklenmiyordu. Bu key ile guard "doğru tür yüklü mü" diye bakar.
  // Format: 'none' | 'prov:<regionFilter|all>:<region|unique>' | 'dist:<prov|all>:<highlight>'
  String _borderKind = 'none';
  // 2026-06-01 (B3): Tematik harita (choropleth) aktifken seçim FILL'i çizilmez
  // (sadece sınır çizgisi) → tematik renk gizlenmez. Toggle olunca sınırların
  // yeniden çizilmesi için son durum izlenir.
  bool _lastThematicActive = false;
  bool _overlayActive   = false;
  bool _lastProvincesMode = false;
  SelectionLevel _lastSelectionLevel = SelectionLevel.none;
  String? _lastSelectedProvince;
  String? _lastSelectedRegion;
  String? _lastSelectedDistrict;

  // Choropleth
  ChoroplethMode _lastChoropleth = ChoroplethMode.none;
  // 2026-06-01 (B6): son render edilen choropleth data referansı. Zaman
  // simülasyonunda metrik sabit ama her frame YENİ data map'i geliyor →
  // identity değişimiyle "frame değişti, yeniden çiz" tespiti.
  Map<String, dynamic>? _lastChoroData;
  bool _choroplethSourceAdded = false;
  bool _choroplethLayerActive = false;

  // 2026-06-01 (B4): ML projeksiyon choropleth (ayrı katman — weather
  // choropleth'ten bağımsız). `_lastMlChoroJson` style reload sonrası
  // yeniden uygulamak için saklanır.
  bool _mlChoroSourceAdded = false;
  bool _mlChoroLayerActive = false;
  String? _lastMlChoroJson;
  // 2026-06-01: ML animasyonunda (yıl/ay slider) hızlı setMlChoropleth çağrıları
  // → yalnız EN SON isteği render et (backlog/churn önler). Kilit beklerken
  // eskiyen istekler `seq != _mlSeq` ile atlanır.
  int _mlSeq = 0;

  // Animation province polygon layer
  // 1.B (yeniden): _animProvActive / _lastAnimFrame state'i emekliye ayrıldı.

  MapViewModel? _vmRef;

  /// GeoJSON önbelleği — her seferinde backend'den indirmemek için.
  static String? _cachedProvincesGeoJson;
  static String? _cachedDistrictsGeoJson;

  /// Geo sorgusu sırasında yükleniyor göstergesi.
  bool _geoLoading = false;

  // ─── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vmRef = Provider.of<MapViewModel>(context, listen: false);
      _vmRef!.addListener(_onVmChanged);
    });
  }

  @override
  void dispose() {
    // 2026-06-01: önce dispose bayrağı + style geçersiz — uçuşan async style
    // op'ları (ML choropleth, sync) teardown'dan sonra native'e dokunmasın.
    _disposed = true;
    _styleLoaded = false;
    _vmRef?.removeListener(_onVmChanged);
    // Bu widget kapanırken aktif controller + state referanslarını temizle
    if (MapViewMapLibre._activeController != null) {
      MapViewMapLibre._activeController = null;
    }
    if (identical(MapViewMapLibre._activeState, this)) {
      MapViewMapLibre._activeState = null;
    }
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted || !_styleLoaded || _syncing || _vmRef == null) return;
    _syncAll(_vmRef!);
  }

  Future<void> _syncAll(MapViewModel vm) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _syncPins(vm.filteredPins, vm.show3DTurbines, vm.showPinClusters);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncPins hata: $e');
    }
    try {
      await _syncHeatmapData(vm.weatherSummary);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncHeatmapData hata: $e');
    }
    try {
      await _syncHeatmapGridData(vm.heatmapPoints);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncHeatmapGridData hata: $e');
    }
    try {
      await _syncHeatmapMode(vm.mlHeatmapMode);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncHeatmapMode hata: $e');
    }
    try {
      await _syncTerrain(vm.show3DTerrain);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncTerrain hata: $e');
    }
    // Aşama I: MVT vektör katmanları (hidro/yasaklı/iletim)
    try {
      await _syncMvtLayers(vm);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncMvtLayers hata: $e');
    }
    // Choropleth
    try {
      await _syncChoropleth(vm);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncChoropleth hata: $e');
    }
    // Bulut katmanı
    try {
      await _syncCloudLayer(vm.showCloudLayer);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncCloudLayer hata: $e');
    }
    // 2026-05-27 (O1.4): İzohips contour overlay
    try {
      await _syncContourLayer(vm.showContour, vm.contourOpacity);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncContourLayer hata: $e');
    }
    // 1.B (yeniden): _syncAnimationProvinces emekliye ayrıldı —
    // animasyon ilçe choropleth path'inden beslenir (yukarıda _syncChoropleth).
    // İl/İlçe sınırları
    try {
      await _syncBorders(vm);
    } catch (e) {
      debugPrint('[MapLibre-Native] _syncBorders hata: $e');
    }
    _syncing = false;
  }

  // ─── Event Handler ────────────────────────────────────────────────

  Future<void> _onEvent(ml.MapEvent event) async {
    switch (event) {
      case ml.MapEventStyleLoaded(:final style):
        _style = style;
        _styleLoaded = false;
        _syncing = false;

        _solarActive = _windActive = _hillshadeActive = false;
        _lastHeatmap  = MlHeatmapMode.none;
        _last3D       = false;
        _lastTerrain  = false;
        // Aşama I: style reload — MVT toggle'ları stub (native MVT henüz desteksiz)
        _lastHydroLayer = false;
        _lastRestrictedLayer = false;
        _lastEnergyCorridorLayer = false;
        _mvtHydroActive = false;
        _mvtRestrictedActive = false;
        _mvtEnergyActive = false;
        _lastClustering = false;
        _clusterLayersActive = false;
        _lastCloud = false;
        _cloudActive = false;
        _lastContour = false;
        _contourActive = false;
        _bordersActive = false;
        _lastProvincesMode = false;
        _lastSelectionLevel = SelectionLevel.none;
        _lastSelectedProvince = null;
        _lastSelectedRegion = null;
        _lastSelectedDistrict = null;
        _lastChoropleth = ChoroplethMode.none;
        _lastChoroData = null;
        _choroplethSourceAdded = false;
        _choroplethLayerActive = false;
        // B4: yeni style → ML choropleth katmanı da gitti; flag'leri sıfırla.
        _mlChoroSourceAdded = false;
        _mlChoroLayerActive = false;
        _lastPins    = [];
        _lastSummary = [];

        // B4: static ML choropleth metodları bu canlı State'e köprülensin.
        MapViewMapLibre._activeState = this;

        await _initLayers();

        if (mounted) setState(() => _styleLoaded = true);

        if (mounted) {
          final vm = Provider.of<MapViewModel>(context, listen: false);
          await _syncAll(vm);
        }

        // B4: style reload öncesi ML choropleth açıktıysa yeniden uygula
        // (seq'li giriş — _applyMlChoropleth kilit + coalesce yönetir).
        if (mounted && !_disposed && _lastMlChoroJson != null) {
          _applyMlChoropleth(_lastMlChoroJson!);
        }

      case ml.MapEventClick(:final point):
        await _onMapClick(point);

      case ml.MapEventLongClick(:final point):
        await _onMapLongPress(point);

      case ml.MapEventCameraIdle():
        // Zoom değişiminde cluster'ları güncelle
        if (_lastClustering && mounted) {
          final vm = Provider.of<MapViewModel>(context, listen: false);
          await _updateClusterData(vm.filteredPins);
        }
        // B8 (2026-06-01): maplibre 0.2.2 native MapOptions.maxBounds'ı zorlamıyor.
        // SADECE pan/zoom BİTİNCE (CameraIdle) kontrol et — pan sırasında SÜREKLİ
        // clamp ekranı titretip kaydırmayı engelliyordu. "Çıkarsan geri gönder"
        // mantığı: serbest pan, bırakınca Türkiye dışındaysa yumuşakça geri dön.
        if (mounted && !_globeForConstrain) _constrainToTurkey();

      default:
        break;
    }
  }

  // B8: Türkiye pan-sınırı bbox'u (küçük deniz marjı). Görünür bölge bunun
  // dışına taşarsa kamera anında içeri itilir.
  static const _panMargin = 0.3;

  /// B8 (2026-06-01): Globe kapalıyken GÖRÜNÜR bölge Türkiye bbox dışına taşarsa
  /// kamerayı anında (moveCamera) içeri iter — web'deki maxBounds duvarı gibi.
  /// Merkez değil KENAR bazlı: dikey ekranda komşu ülke (İran/İlam vb.) kenardan
  /// görünmesin. Re-entrancy kilidi (moveCamera yeni move event tetikler).
  void _constrainToTurkey() {
    if (_constraining) return;
    final ctrl = MapViewMapLibre._activeController;
    if (ctrl == null) return;
    ml.LngLatBounds vis;
    ml.MapCamera? cam;
    try {
      vis = ctrl.getVisibleRegionSync();
      cam = ctrl.camera;
    } catch (_) {
      return;
    }
    if (cam == null) return;

    final tw = MapConstants.turkeyMinLon - _panMargin;
    final te = MapConstants.turkeyMaxLon + _panMargin;
    final ts = MapConstants.turkeyMinLat - _panMargin;
    final tn = MapConstants.turkeyMaxLat + _panMargin;

    final vw = vis.longitudeWest.toDouble();
    final ve = vis.longitudeEast.toDouble();
    final vs = vis.latitudeSouth.toDouble();
    final vn = vis.latitudeNorth.toDouble();

    double dLon = 0, dLat = 0;
    // Yatay: görünür genişlik sınırdan büyükse ortala, değilse taşan kenarı it.
    if ((ve - vw) >= (te - tw)) {
      dLon = ((tw + te) / 2) - ((vw + ve) / 2);
    } else if (vw < tw) {
      dLon = tw - vw;
    } else if (ve > te) {
      dLon = te - ve;
    }
    if ((vn - vs) >= (tn - ts)) {
      dLat = ((ts + tn) / 2) - ((vs + vn) / 2);
    } else if (vs < ts) {
      dLat = ts - vs;
    } else if (vn > tn) {
      dLat = tn - vn;
    }

    if (dLon.abs() < 1e-5 && dLat.abs() < 1e-5) return; // tamamen içeride
    _constraining = true;
    final c = cam.center;
    // Idle'da tek sefer → yumuşak animasyon ("geri gönderildin" hissi),
    // pan sırasında titreme yok.
    ctrl
        .animateCamera(
          center: ml.Position(c.lng.toDouble() + dLon, c.lat.toDouble() + dLat),
          zoom: cam.zoom,
          nativeDuration: const Duration(milliseconds: 350),
        )
        .whenComplete(() => _constraining = false);
  }

  // ─── Pin Etkileşimi ───────────────────────────────────────────────

  Future<void> _onMapClick(ml.Position point) async {
    final vm = Provider.of<MapViewModel>(context, listen: false);

    // 0) Pin yerleştirme modu aktifse — selection/choropleth match'leri atla,
    //    direkt pin akışına git. Aksi halde tematik harita veya il modu açıkken
    //    pin koymak imkânsız oluyor (selection match önceliği yutuyor).
    if (vm.placingPinType != null) {
      widget.onMapTap?.call(point);
      return;
    }

    // 1) Pin tıklaması: her zaman en yüksek öncelik
    if (widget.onPinTap != null && vm.filteredPins.isNotEmpty) {
      final pin = _nearestPin(vm.filteredPins, point);
      if (pin != null) {
        widget.onPinTap!(pin);
        return;
      }
    }

    // 2) İl/İlçe modu aktifse (master switch) → tek tıklama ile seç
    //    isProvinceModeActive = master switch (tüm seviyeler)
    //    isProvincesModeActive = sadece province seviyesi (district'te false olur!)
    if (vm.isProvinceModeActive) {
      await _selectGeoAtPoint(point);
      return;
    }

    // 3) Choropleth aktifse → tıklanan ilçeyi tespit et, tooltip göster
    if (vm.choroplethMode != ChoroplethMode.none) {
      await _queryChoroplethAtPoint(point, vm);
      return;
    }

    // 4) Normal harita tıklaması (pin ekleme vs.)
    widget.onMapTap?.call(point);
  }

  /// Ekran pikseli bazlı en yakın pin tespiti.
  /// Sabit derece eşiği yerine, dokunma noktasını ekran koordinatına dönüştürüp
  /// pin'in ekran konumuyla karşılaştırır. Böylece her zoom seviyesinde
  /// tutarlı ~40px dokunma alanı sağlanır.
  Pin? _nearestPin(List<Pin> pins, ml.Position point) {
    if (pins.isEmpty) return null;
    final controller = MapViewMapLibre._activeController;
    if (controller == null) return null;

    // Dokunma toleransı: 40px (parmak ucu genişliği ~7mm ≈ 40px @2.5dpi)
    const double tapRadiusPx = 40.0;

    try {
      final tapScreen = controller.toScreenLocationSync(point);
      Pin? nearest;
      double minDistSq = double.infinity;

      for (final p in pins) {
        final pinScreen = controller.toScreenLocationSync(
          ml.Position(p.longitude, p.latitude),
        );
        final dx = tapScreen.dx - pinScreen.dx;
        final dy = tapScreen.dy - pinScreen.dy;
        final distSq = dx * dx + dy * dy;
        if (distSq < minDistSq) {
          minDistSq = distSq;
          nearest = p;
        }
      }

      return minDistSq < (tapRadiusPx * tapRadiusPx) ? nearest : null;
    } catch (_) {
      // toScreenLocationSync henüz hazır değilse fallback
      return null;
    }
  }

  // ─── İl/İlçe Seçimi (3 seviyeli navigasyon) ───────────────────

  bool _geoSelectBusy = false;

  /// Parsed GeoJSON feature cache (parse bir kez yapılsın diye).
  static List<Map<String, dynamic>>? _parsedProvinceFeatures;
  static List<Map<String, dynamic>>? _parsedDistrictFeatures;

  /// Asset GeoJSON'ından feature listesini parse eder (lazy, tek sefer).
  Future<List<Map<String, dynamic>>> _getProvinceFeatures() async {
    if (_parsedProvinceFeatures != null) return _parsedProvinceFeatures!;
    final raw = await _fetchProvincesGeoJson();
    if (raw == null) return [];
    final geojson = jsonDecode(raw) as Map<String, dynamic>;
    final allFeatures = List<Map<String, dynamic>>.from(geojson['features'] ?? []);
    // Türkiye sınırları dışındaki feature'ları filtrele
    _parsedProvinceFeatures = allFeatures.where(_isFeatureInTurkey).toList();
    return _parsedProvinceFeatures!;
  }

  Future<List<Map<String, dynamic>>> _getDistrictFeatures() async {
    if (_parsedDistrictFeatures != null) return _parsedDistrictFeatures!;
    final raw = await _fetchDistrictsGeoJson();
    if (raw == null) return [];
    final geojson = jsonDecode(raw) as Map<String, dynamic>;
    final allFeatures = List<Map<String, dynamic>>.from(geojson['features'] ?? []);
    // Türkiye sınırları dışındaki feature'ları filtrele (Yunan adaları vb.)
    _parsedDistrictFeatures = allFeatures.where(_isFeatureInTurkey).toList();
    return _parsedDistrictFeatures!;
  }

  /// Türkçe harfler Latin Extended-A içinde (≤U+024F). Üzerindeki kod noktası
  /// (Yunan, Kiril, Arap vs.) varsa NAME_* Türkiye'ye ait değildir.
  static bool _hasNonTurkishChar(String? s) {
    if (s == null || s.isEmpty) return false;
    for (final cp in s.runes) {
      if (cp > 0x024F) return true;
    }
    return false;
  }

  /// 2026-06-01 (B2): turkey_provinces.json'da 81 il dışında bir de NAME_1="Ege"
  /// adlı bogus feature var (bölge adı, il değil — Ege adaları/dissolve artığı).
  /// İl/Bölge modunda ada gibi görünüyordu. Gerçek illerde NAME_1 asla bir
  /// bölge adı olmaz → bölge-adlı feature'ları ele. (district'lerde NAME_1 = il
  /// olduğundan bu kontrol onları etkilemez.)
  static final Set<String> _regionNamesNorm = <String>{
    'Marmara', 'Ege', 'Akdeniz', 'İç Anadolu', 'Karadeniz',
    'Doğu Anadolu', 'Güneydoğu Anadolu',
  }.map(_normalizeForMatch).toSet();

  static bool _isRegionName(String? s) {
    if (s == null || s.isEmpty) return false;
    return _regionNamesNorm.contains(_normalizeForMatch(s));
  }

  /// Feature'ın centroid'inin Türkiye sınırları içinde olup olmadığını kontrol eder.
  /// Web tarafındaki _filterDistrictGeoJson() ile aynı mantık.
  static bool _isFeatureInTurkey(Map<String, dynamic> feature) {
    const minLon = 25.0, maxLon = 46.0, minLat = 35.0, maxLat = 43.0;
    try {
      // Yunan adaları gibi yanlış etiketli feature'lar: NAME_2 Yunanca/Kiril
      final props = feature['properties'] as Map<String, dynamic>? ?? const {};
      if (_hasNonTurkishChar(props['NAME_2'] as String?) ||
          _hasNonTurkishChar(props['NAME_1'] as String?)) {
        return false;
      }
      // B2: "Ege" gibi bölge-adlı bogus feature (il değil) → ele.
      if (_isRegionName(props['NAME_1'] as String?)) return false;
      final geom = feature['geometry'] as Map<String, dynamic>?;
      if (geom == null) return false;
      final type = geom['type'] as String?;
      List<dynamic>? ring;
      if (type == 'Polygon') {
        ring = (geom['coordinates'] as List)[0] as List;
      } else if (type == 'MultiPolygon') {
        ring = ((geom['coordinates'] as List)[0] as List)[0] as List;
      }
      if (ring == null || ring.isEmpty) return false;
      double sumLon = 0, sumLat = 0;
      for (final c in ring) {
        sumLon += (c[0] as num).toDouble();
        sumLat += (c[1] as num).toDouble();
      }
      final cLon = sumLon / ring.length;
      final cLat = sumLat / ring.length;
      return cLon >= minLon && cLon <= maxLon && cLat >= minLat && cLat <= maxLat;
    } catch (_) {
      return false;
    }
  }

  /// Ray-casting point-in-polygon testi.
  /// Tamamen client-side — backend'e gerek yok.
  static bool _pointInPolygon(double lat, double lon, List<dynamic> ring) {
    bool inside = false;
    int j = ring.length - 1;
    for (int i = 0; i < ring.length; i++) {
      final xi = (ring[i][0] as num).toDouble(); // lon
      final yi = (ring[i][1] as num).toDouble(); // lat
      final xj = (ring[j][0] as num).toDouble();
      final yj = (ring[j][1] as num).toDouble();

      if (((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// GeoJSON geometry içinde nokta kontrolü (Polygon + MultiPolygon).
  static bool _pointInGeometry(double lat, double lon, Map<String, dynamic> geometry) {
    final type = geometry['type'] as String? ?? '';
    final coords = geometry['coordinates'];
    if (coords == null) return false;

    if (type == 'Polygon') {
      // İlk ring = dış sınır
      return _pointInPolygon(lat, lon, coords[0]);
    } else if (type == 'MultiPolygon') {
      for (final polygon in coords) {
        if (_pointInPolygon(lat, lon, polygon[0])) return true;
      }
    }
    return false;
  }

  /// Dokunulan noktadaki il/ilçeyi gömülü GeoJSON'dan bulur.
  /// Tamamen offline — backend bağımsız.
  Future<void> _selectGeoAtPoint(ml.Position point) async {
    if (!mounted || _geoSelectBusy) return;
    _geoSelectBusy = true;
    setState(() => _geoLoading = true);

    final vm = Provider.of<MapViewModel>(context, listen: false);
    final lat = point.lat.toDouble();
    final lon = point.lng.toDouble();

    try {
      String province = '';
      String district = '';

      // Her zaman ilçe GeoJSON'ından ara — hem il hem ilçe bilgisini verir
      final districts = await _getDistrictFeatures();
      for (final f in districts) {
        final geom = f['geometry'] as Map<String, dynamic>?;
        if (geom == null) continue;
        if (_pointInGeometry(lat, lon, geom)) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          province = (props['NAME_1'] ?? '').toString();
          district = (props['NAME_2'] ?? '').toString();
          break;
        }
      }

      // İlçe GeoJSON'da bulunamadıysa il GeoJSON'da dene
      if (province.isEmpty) {
        final provinces = await _getProvinceFeatures();
        for (final f in provinces) {
          final geom = f['geometry'] as Map<String, dynamic>?;
          if (geom == null) continue;
          if (_pointInGeometry(lat, lon, geom)) {
            final props = f['properties'] as Map<String, dynamic>? ?? {};
            province = (props['NAME_1'] ?? '').toString();
            break;
          }
        }
      }

      if (!mounted || province.isEmpty) return;

      final initialMode = vm.initialSelectionMode;

      // ────────────────────────────────────────────────────────
      // BÖLGE MODU
      // ────────────────────────────────────────────────────────
      if (initialMode == SelectionLevel.region) {
        final tappedRegion = _findRegionForProvince(province);
        final levelNow = vm.selectionLevel;

        if (vm.selectedRegionName == null) {
          // Henüz bölge seçilmemiş → bölge seç
          if (tappedRegion != null && tappedRegion.isNotEmpty) {
            vm.selectRegion(tappedRegion);
            _flyToRegionBounds(tappedRegion);
          }
        } else if (tappedRegion != vm.selectedRegionName &&
                   tappedRegion != null && tappedRegion.isNotEmpty) {
          // Başka bölgeye tıklandı — level'a göre davranış:
          if (levelNow == SelectionLevel.region) {
            // Bölge seviyesinde: sadece bölgeyi değiştir
            vm.selectRegion(tappedRegion);
            _flyToRegionBounds(tappedRegion);
          } else {
            // Province/district seviyesinde: tek tıkla hem bölge hem il geç
            // (Kullanıcı spec: "Hala tıklama ile diğer bölgelere geçebilirim" + ile)
            vm.selectRegion(tappedRegion);
            vm.selectProvince(province);
            await _loadDistrictBorders(province);
            _flyToProvinceCentroid(province);
          }
        } else if (levelNow == SelectionLevel.province) {
          // Aynı bölgede il tıklandı → ilçeleri göster
          vm.selectProvince(province);
          await _loadDistrictBorders(province);
          _flyToProvinceCentroid(province);
        } else if (levelNow == SelectionLevel.district) {
          // İlçe seviyesinde: ilçe veya başka il (aynı bölge)
          if (district.isNotEmpty && province == vm.selectedProvinceName) {
            vm.selectDistrict(district, province: province);
            await _loadDistrictBorders(province, highlightDistrict: district);
            await _showDistrictHighlight(province, district);
          } else {
            // Başka il (aynı bölgede) → o ilin ilçelerine geç
            vm.selectProvince(province);
            await _loadDistrictBorders(province);
            _flyToProvinceCentroid(province);
          }
        }
      }
      // ────────────────────────────────────────────────────────
      // İL MODU
      // ────────────────────────────────────────────────────────
      else if (initialMode == SelectionLevel.province) {
        // İl modu = city → district drill-down
        debugPrint('[GEO] İl modu tıklama — clicked=$province tappedDist=$district '
            'curProv=${vm.selectedProvinceName} lvl=${vm.selectionLevel}');
        if (vm.selectionLevel == SelectionLevel.province ||
            province != vm.selectedProvinceName) {
          // Yeni il seçimi veya başka ile geçiş
          // Ana il sınırları korunur, üstüne seçili ilin ilçeleri overlay olarak eklenir
          vm.selectProvince(province);
          await _showProvinceOverlay(province);
          _flyToProvinceCentroid(province);
        } else if (vm.selectionLevel == SelectionLevel.district &&
                   district.isNotEmpty &&
                   province == vm.selectedProvinceName) {
          // Aynı ildeyken ilçe seçimi — mavi çerçeve ile vurgula
          vm.selectDistrict(district, province: province);
          await _showDistrictHighlight(province, district);
        }
      }
      // ────────────────────────────────────────────────────────
      // İLÇE MODU
      // ────────────────────────────────────────────────────────
      else if (initialMode == SelectionLevel.district) {
        if (district.isNotEmpty) {
          vm.selectDistrict(district, province: province);
          // İlçe modunda renkleri değiştirme — sadece mavi çerçeve
          await _showDistrictHighlight(province, district);
        }
      }
      // ────────────────────────────────────────────────────────
      // DİĞER (none, beklenmedik)
      // ────────────────────────────────────────────────────────
      else {
        vm.selectProvince(province);
        await _loadDistrictBorders(province);
        _flyToProvinceCentroid(province);
      }
    } catch (e) {
      debugPrint('[GEO] Seçim hatası: $e');
    } finally {
      _geoSelectBusy = false;
      if (mounted) setState(() => _geoLoading = false);
    }
  }

  /// Choropleth aktifken tıklanan ilçeyi tespit edip tooltip verisini ViewModel'e iletir.
  Future<void> _queryChoroplethAtPoint(ml.Position point, MapViewModel vm) async {
    final lat = point.lat.toDouble();
    final lon = point.lng.toDouble();
    try {
      final districts = await _getDistrictFeatures();
      for (final f in districts) {
        final geom = f['geometry'] as Map<String, dynamic>?;
        if (geom == null) continue;
        if (_pointInGeometry(lat, lon, geom)) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final province = (props['NAME_1'] ?? '').toString();
          final district = (props['NAME_2'] ?? '').toString();
          if (province.isNotEmpty && district.isNotEmpty) {
            vm.setChoroplethTap(province, district);
          }
          return;
        }
      }
      // Türkiye dışına tıklandıysa tooltip'i kapat
      vm.clearChoroplethTap();
    } catch (e) {
      debugPrint('[MapLibre-Native] Choropleth sorgu hatası: $e');
    }
  }

  /// Seçilen ilin centroidine kamerayı uçurur.
  /// Cache'lenmiş ilçe GeoJSON'ından ilin bounding box'ını hesaplar.
  void _flyToProvinceCentroid(String provinceName) {
    final cached = _cachedDistrictsGeoJson;
    if (cached == null) {
      // Cache yoksa sadece zoom yap
      final curZoom = MapViewMapLibre._activeController?.camera?.zoom ?? 6.0;
      if (curZoom < 8.0) {
        MapViewMapLibre._activeController?.animateCamera(
          zoom: 8.0,
          nativeDuration: const Duration(milliseconds: 600),
        );
      }
      return;
    }

    try {
      final geojson = jsonDecode(cached) as Map<String, dynamic>;
      final features = geojson['features'] as List? ?? [];
      final normTarget = _normalizeForMatch(provinceName);

      double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
      bool found = false;

      for (final f in features) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final name1 = (props['NAME_1'] ?? '').toString();
        if (_normalizeForMatch(name1) != normTarget) continue;
        found = true;

        // Geometry koordinatlarından bbox hesapla
        _extractCoordsFromGeometry(f['geometry'], (lon, lat) {
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lon < minLon) minLon = lon;
          if (lon > maxLon) maxLon = lon;
        });
      }

      if (!found) return;

      final centerLat = (minLat + maxLat) / 2;
      final centerLon = (minLon + maxLon) / 2;
      // Bbox genişliğine göre zoom hesapla
      final latSpan = maxLat - minLat;
      final lonSpan = maxLon - minLon;
      final span = math.max(latSpan, lonSpan);
      // span 0.5° → zoom ~10, span 2° → zoom ~8, span 5° → zoom ~6
      final zoom = (10.0 - (math.log(span.clamp(0.1, 20)) / math.ln2) * 1.2).clamp(6.0, 12.0);

      MapViewMapLibre._activeController?.animateCamera(
        center: ml.Position(centerLon, centerLat),
        zoom: zoom,
        nativeDuration: const Duration(milliseconds: 700),
      );
    } catch (e) {
      debugPrint('[MapLibre-Native] flyToProvinceCentroid hata: $e');
    }
  }

  /// GeoJSON geometry'sinden tüm koordinatları çıkarır (Polygon, MultiPolygon).
  static void _extractCoordsFromGeometry(
    dynamic geometry,
    void Function(double lon, double lat) callback,
  ) {
    if (geometry == null) return;
    final type = geometry['type'] as String? ?? '';
    final coords = geometry['coordinates'];
    if (coords == null) return;

    if (type == 'Polygon') {
      for (final ring in coords) {
        for (final pt in ring) {
          callback((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
        }
      }
    } else if (type == 'MultiPolygon') {
      for (final polygon in coords) {
        for (final ring in polygon) {
          for (final pt in ring) {
            callback((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
          }
        }
      }
    }
  }

  /// İlçe GeoJSON'ını gömülü asset'ten yükler (tek sefer, sonra cache).
  /// Backend bağımsız — offline çalışır.
  Future<String?> _fetchDistrictsGeoJson() async {
    if (_cachedDistrictsGeoJson != null) return _cachedDistrictsGeoJson;
    try {
      final raw = await rootBundle.loadString('assets/geo/turkey_districts.json');
      _cachedDistrictsGeoJson = raw;
      return raw;
    } catch (e) {
      debugPrint('[MapLibre-Native] İlçe GeoJSON asset yükleme hatası: $e');
    }
    return null;
  }

  /// İl GeoJSON'ını gömülü asset'ten yükler (tek sefer, sonra cache).
  /// Backend bağımsız — offline çalışır.
  Future<String?> _fetchProvincesGeoJson() async {
    if (_cachedProvincesGeoJson != null) return _cachedProvincesGeoJson;
    try {
      final raw = await rootBundle.loadString('assets/geo/turkey_provinces.json');
      _cachedProvincesGeoJson = raw;
      return raw;
    } catch (e) {
      debugPrint('[MapLibre-Native] İl GeoJSON asset yükleme hatası: $e');
    }
    return null;
  }

  /// Web benzeri 10 renkli palet — komşu bölgelerin farklı renk alması için.
  static const _regionPalette = [
    'rgba(231,76,60,0.35)',   // kırmızı
    'rgba(88,214,141,0.35)',  // yeşil
    'rgba(244,208,63,0.35)',  // sarı
    'rgba(52,152,219,0.35)',  // mavi
    'rgba(155,89,182,0.35)',  // mor
    'rgba(230,126,34,0.35)',  // turuncu
    'rgba(26,188,156,0.35)',  // turkuaz
    'rgba(241,196,15,0.35)',  // altın
    'rgba(46,134,193,0.35)',  // koyu mavi
    'rgba(243,156,18,0.35)',  // amber
  ];

  /// 7 bölge için sabit renk haritası — haritada bölgeleri görsel olarak ayırır.
  static const _regionColorMap = <String, String>{
    'marmara':             'rgba(52,152,219,0.35)',   // mavi
    'ege':                 'rgba(88,214,141,0.35)',   // yeşil
    'akdeniz':             'rgba(244,208,63,0.35)',   // sarı
    'ic anadolu':          'rgba(155,89,182,0.35)',   // mor
    'karadeniz':           'rgba(26,188,156,0.35)',   // turkuaz
    'dogu anadolu':        'rgba(231,76,60,0.35)',    // kırmızı
    'guneydogu anadolu':   'rgba(230,126,34,0.35)',   // turuncu
  };

  /// Graph coloring ile komşu feature'ların aynı/benzer renkleri almamasını sağlar.
  /// Vertex-paylaşım bazlı komşuluk tespiti: ~0.001° hassasiyet (~100m).
  /// Web'deki _addUniqueColorLayer() ile aynı mantık.
  static String _colorizeFeatures(List<dynamic> features, {bool useRegionColors = false}) {
    if (features.isEmpty) return jsonEncode({'type': 'FeatureCollection', 'features': features});

    // 1) Her feature için vertex key → feature indeks haritası oluştur
    final vertexToFeatures = <String, Set<int>>{};
    for (int i = 0; i < features.length; i++) {
      final geom = (features[i] as Map)['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;
      final coords = _extractAllCoords(geom);
      for (final c in coords) {
        // ~100m hassasiyet: koordinatı 1000'e çarp, yuvarla
        final key = '${(c[0] * 1000).round()},${(c[1] * 1000).round()}';
        vertexToFeatures.putIfAbsent(key, () => <int>{}).add(i);
      }
    }

    // 2) Komşuluk grafiği oluştur
    final adj = List<Set<int>>.generate(features.length, (_) => <int>{});
    for (final group in vertexToFeatures.values) {
      if (group.length < 2) continue;
      final indices = group.toList();
      for (int a = 0; a < indices.length; a++) {
        for (int b = a + 1; b < indices.length; b++) {
          adj[indices[a]].add(indices[b]);
          adj[indices[b]].add(indices[a]);
        }
      }
    }

    // 3) Greedy graph coloring — komşu sayısına göre sıralı
    final order = List<int>.generate(features.length, (i) => i);
    order.sort((a, b) => adj[b].length.compareTo(adj[a].length));
    final colors = List<int>.filled(features.length, -1);
    for (final idx in order) {
      final usedColors = <int>{};
      for (final neighbor in adj[idx]) {
        if (colors[neighbor] >= 0) usedColors.add(colors[neighbor]);
      }
      int c = 0;
      while (usedColors.contains(c)) { c++; }
      colors[idx] = c;
    }

    // 4) Renk ata
    for (int i = 0; i < features.length; i++) {
      final props = (features[i]['properties'] as Map<String, dynamic>?) ?? {};
      if (useRegionColors) {
        final region = (props['REGION'] ?? '').toString();
        final normRegion = region.toLowerCase()
            .replaceAll('ı', 'i').replaceAll('ş', 's').replaceAll('ğ', 'g')
            .replaceAll('ü', 'u').replaceAll('ö', 'o').replaceAll('ç', 'c')
            .replaceAll('â', 'a').trim();
        props['_color'] = _regionColorMap[normRegion]
            ?? _regionPalette[colors[i] % _regionPalette.length];
      } else {
        props['_color'] = _regionPalette[colors[i] % _regionPalette.length];
      }
      features[i]['properties'] = props;
    }
    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  /// Geometry'den tüm koordinatları düz liste olarak çıkarır.
  static List<List<double>> _extractAllCoords(Map<String, dynamic> geom) {
    final result = <List<double>>[];
    final type = geom['type'] as String? ?? '';
    final coords = geom['coordinates'];
    if (coords == null) return result;

    if (type == 'Polygon') {
      for (final ring in coords as List) {
        for (final pt in ring as List) {
          result.add([(pt[0] as num).toDouble(), (pt[1] as num).toDouble()]);
        }
      }
    } else if (type == 'MultiPolygon') {
      for (final polygon in coords as List) {
        for (final ring in polygon as List) {
          for (final pt in ring as List) {
            result.add([(pt[0] as num).toDouble(), (pt[1] as num).toDouble()]);
          }
        }
      }
    }
    return result;
  }

  /// İlçe sınırlarını yükler ve haritada gösterir.
  /// [provinceName] null ise tüm Türkiye ilçeleri gösterilir (İlçe modu).
  Future<void> _loadDistrictBorders(String? provinceName,
      {String? highlightDistrict, bool suppressFill = false}) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    _bordersSyncing = true;
    await _removeBorderLayers();

    try {
      final features = await _getDistrictFeatures();
      final List<Map<String, dynamic>> filtered;
      if (provinceName != null && provinceName.isNotEmpty) {
        // Belirli ilin ilçeleri
        final normTarget = _normalizeForMatch(provinceName);
        filtered = features.where((f) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final name1 = (props['NAME_1'] ?? '').toString();
          return _normalizeForMatch(name1) == normTarget;
        }).toList();
      } else {
        // Tüm ilçeler (İlçe modu)
        filtered = features;
      }

      if (filtered.isEmpty) return;

      // Deep copy + graph coloring (komşu ilçeler farklı renk alır)
      final deepCopy = filtered.map((f) => jsonDecode(jsonEncode(f))).toList();
      var colorizedJson = _colorizeFeatures(deepCopy);

      // Seçili ilçeyi vurgula (graph coloring sonrası override)
      if (highlightDistrict != null) {
        final normDistrict = _normalizeForMatch(highlightDistrict);
        final parsed = jsonDecode(colorizedJson) as Map<String, dynamic>;
        for (final f in (parsed['features'] as List)) {
          final props = f['properties'] as Map<String, dynamic>;
          final name2 = (props['NAME_2'] ?? '').toString();
          if (_normalizeForMatch(name2) == normDistrict) {
            props['_color'] = 'rgba(52,152,219,0.6)';
          }
        }
        colorizedJson = jsonEncode(parsed);
      }

      // Güvenlik: stale source/layer kalmış olabilir — yeniden temizle
      try { await style.removeLayer(_bordersLineLayerId); } catch (_) {}
      try { await style.removeLayer(_bordersFillLayerId); } catch (_) {}
      try { await style.removeSource(_bordersSourceId); } catch (_) {}

      await style.addSource(ml.GeoJsonSource(
        id: _bordersSourceId,
        data: colorizedJson,
      ));

      // B3: Tematik harita aktifken FILL çizme → choropleth rengi gizlenmesin.
      // (Seçili ilçe vurgusu ayrıca _showDistrictHighlight mavi çerçevesiyle.)
      if (!suppressFill) {
        await style.addLayer(
          ml.FillStyleLayer(
            id: _bordersFillLayerId,
            sourceId: _bordersSourceId,
            paint: <String, Object>{
              'fill-color': ['get', '_color'],
              'fill-opacity': 1.0,
            },
          ),
          belowLayerId: _pinsShadowLayerId,
        );
      }

      // Sınır çizgileri
      await style.addLayer(
        ml.LineStyleLayer(
          id: _bordersLineLayerId,
          sourceId: _bordersSourceId,
          paint: <String, Object>{
            'line-color': 'rgba(44,62,80,0.6)',
            'line-width': 1.5,
            'line-opacity': 0.8,
          },
        ),
        belowLayerId: _pinsShadowLayerId,
      );

      _bordersActive = true;
      _borderKind = 'dist:${provinceName ?? "all"}:${highlightDistrict ?? ""}:'
          '${suppressFill ? "nofill" : "fill"}';
    } catch (e) {
      debugPrint('[MapLibre-Native] İlçe sınırları yükleme hatası: $e');
    } finally {
      _bordersSyncing = false;
    }
  }

  /// İl sınırlarını yükler — bölge filtresi varsa sadece o bölgenin illeri.
  /// [useRegionColors]: true → iller bölge rengiyle (Bölge modu). false → her il
  /// kendi unique (graph) rengiyle (İl modu). 2026-06-01 (B1): eskiden hep true
  /// idi → İl modu da Bölge modu gibi bölge renkli görünüyordu. Web'de İl modu
  /// `_addUniqueColorLayer` (unique), Bölge modu region-dissolve → ona hizalandı.
  Future<void> _loadProvinceBorders({
    String? regionFilter,
    bool useRegionColors = true,
    bool suppressFill = false,
  }) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    _bordersSyncing = true;
    await _removeBorderLayers();

    try {
      final allFeatures = await _getProvinceFeatures();
      if (allFeatures.isEmpty) return;

      // Bölge filtresi uygula
      final features = regionFilter != null
          ? allFeatures.where((f) {
              final props = f['properties'] as Map<String, dynamic>? ?? {};
              final region = (props['REGION'] ?? '').toString();
              return _normalizeForMatch(region) == _normalizeForMatch(regionFilter);
            }).toList()
          : allFeatures;

      if (features.isEmpty) return;

      // Deep copy + graph coloring (komşu iller farklı renk alır)
      final colorized = _colorizeFeatures(
        features.map((f) => jsonDecode(jsonEncode(f))).toList(),
        useRegionColors: useRegionColors,
      );

      // Güvenlik: stale source/layer kalmış olabilir
      try { await style.removeLayer(_bordersLineLayerId); } catch (_) {}
      try { await style.removeLayer(_bordersFillLayerId); } catch (_) {}
      try { await style.removeSource(_bordersSourceId); } catch (_) {}

      await style.addSource(ml.GeoJsonSource(
        id: _bordersSourceId,
        data: colorized,
      ));

      // B3: Tematik harita aktifken FILL çizme → choropleth rengi gizlenmesin.
      // Sadece sınır çizgisi üstte kalır.
      if (!suppressFill) {
        await style.addLayer(
          ml.FillStyleLayer(
            id: _bordersFillLayerId,
            sourceId: _bordersSourceId,
            paint: <String, Object>{
              'fill-color': ['get', '_color'],
              'fill-opacity': 1.0,
            },
          ),
          belowLayerId: _pinsShadowLayerId,
        );
      }

      // Sınır çizgileri
      await style.addLayer(
        ml.LineStyleLayer(
          id: _bordersLineLayerId,
          sourceId: _bordersSourceId,
          paint: <String, Object>{
            'line-color': 'rgba(160,181,200,0.65)',
            'line-width': ['interpolate', ['linear'], ['zoom'], 3, 0.6, 6, 1.0, 10, 1.5],
            'line-opacity': 0.7,
          },
        ),
        belowLayerId: _pinsShadowLayerId,
      );

      _bordersActive = true;
      _borderKind = 'prov:${regionFilter ?? "all"}:'
          '${useRegionColors ? "region" : "unique"}:${suppressFill ? "nofill" : "fill"}';
    } catch (e) {
      debugPrint('[MapLibre-Native] İl sınırları yükleme hatası: $e');
    } finally {
      _bordersSyncing = false;
    }
  }

  Future<void> _removeBorderLayers() async {
    final style = _style;
    if (style == null) return;
    // Katmanlar ve source varsa kaldır — _bordersActive false olsa bile temizle
    // (race condition'larda stale layer kalmasını önler)
    try { await style.removeLayer(_bordersLineLayerId); } catch (_) {}
    try { await style.removeLayer(_bordersFillLayerId); } catch (_) {}
    try { await style.removeSource(_bordersSourceId); } catch (_) {}
    _bordersActive = false;
    _borderKind = 'none';
    // Overlay + ilçe highlight katmanlarını da temizle
    await _removeOverlayLayers();
    await _removeDistrictHighlight();
  }

  /// İl modu overlay katmanlarını kaldır (seçili ilin ilçeleri + mavi sınır).
  Future<void> _removeOverlayLayers() async {
    final style = _style;
    if (style == null) return;
    try { await style.removeLayer(_overlayProvLineId); } catch (_) {}
    try { await style.removeLayer(_overlayLineLayerId); } catch (_) {}
    try { await style.removeLayer(_overlayFillLayerId); } catch (_) {}
    try { await style.removeSource(_overlaySourceId); } catch (_) {}
    try { await style.removeSource('srrp-overlay-prov'); } catch (_) {}
    _overlayActive = false;
  }

  /// Seçili ilçenin mavi çerçeve katmanını kaldır.
  Future<void> _removeDistrictHighlight() async {
    final style = _style;
    if (style == null) return;
    try { await style.removeLayer(_districtHighlightLayerId); } catch (_) {}
    try { await style.removeSource(_districtHighlightSourceId); } catch (_) {}
  }

  /// Seçili ilçeyi mavi çerçeve ile vurgula. Her mod için çalışır.
  Future<void> _showDistrictHighlight(String provinceName, String districtName) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    await _removeDistrictHighlight();

    try {
      final features = await _getDistrictFeatures();
      final normProv = _normalizeForMatch(provinceName);
      final normDist = _normalizeForMatch(districtName);
      final match = features.where((f) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final p = (props['NAME_1'] ?? '').toString();
        final d = (props['NAME_2'] ?? '').toString();
        return _normalizeForMatch(p) == normProv && _normalizeForMatch(d) == normDist;
      }).toList();

      if (match.isEmpty) return;

      final fc = {'type': 'FeatureCollection', 'features': match};
      await style.addSource(ml.GeoJsonSource(
        id: _districtHighlightSourceId,
        data: jsonEncode(fc),
      ));

      await style.addLayer(
        ml.LineStyleLayer(
          id: _districtHighlightLayerId,
          sourceId: _districtHighlightSourceId,
          paint: <String, Object>{
            'line-color': '#2196F3',
            'line-width': 3.0,
            'line-opacity': 0.95,
          },
        ),
        belowLayerId: _pinsShadowLayerId,
      );
    } catch (e) {
      debugPrint('[MapLibre-Native] İlçe vurgulama hatası: $e');
    }
  }

  /// İl modunda seçili ilin ilçelerini overlay olarak göster + mavi sınır.
  /// Ana _borders katmanları (tüm iller) korunur, üstüne eklenir.
  Future<void> _showProvinceOverlay(String provinceName) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    await _removeOverlayLayers();

    try {
      final features = await _getDistrictFeatures();
      final normTarget = _normalizeForMatch(provinceName);
      final filtered = features.where((f) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final name1 = (props['NAME_1'] ?? '').toString();
        return _normalizeForMatch(name1) == normTarget;
      }).toList();

      if (filtered.isEmpty) return;

      // Deep copy + graph coloring for districts
      final deepCopy = filtered.map((f) => jsonDecode(jsonEncode(f))).toList();
      final colorizedJson = _colorizeFeatures(deepCopy);

      await style.addSource(ml.GeoJsonSource(
        id: _overlaySourceId,
        data: colorizedJson,
      ));

      // İlçe dolguları
      await style.addLayer(
        ml.FillStyleLayer(
          id: _overlayFillLayerId,
          sourceId: _overlaySourceId,
          paint: <String, Object>{
            'fill-color': ['get', '_color'],
            'fill-opacity': 1.0,
          },
        ),
        belowLayerId: _pinsShadowLayerId,
      );

      // İlçe sınır çizgileri — mavi
      await style.addLayer(
        ml.LineStyleLayer(
          id: _overlayLineLayerId,
          sourceId: _overlaySourceId,
          paint: <String, Object>{
            'line-color': '#2196F3',
            'line-width': 1.5,
            'line-opacity': 0.7,
          },
        ),
        belowLayerId: _pinsShadowLayerId,
      );

      // İl dış sınırı — kalın mavi
      // Province GeoJSON'dan seçili ili çek
      final provFeatures = await _getProvinceFeatures();
      final provFiltered = provFeatures.where((f) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final name1 = (props['NAME_1'] ?? '').toString();
        return _normalizeForMatch(name1) == normTarget;
      }).toList();
      if (provFiltered.isNotEmpty) {
        // Province sınırını ayrı bir source olarak eklemek karmaşıklaştırır.
        // Bunun yerine, mevcut _borders source'undaki il sınırını line-width ile vurgularız.
        // Ama zaten ana _borders province layer aktif — sadece mavi sınır _bordersLineLayerId'nin
        // paint'ini güncelleyebiliriz. Ancak bu tüm illere uygulanır.
        // Alternatif: overlay source'a province feature da ekle, farklı _color ile.
        final provDeepCopy = provFiltered.map((f) {
          final copy = jsonDecode(jsonEncode(f)) as Map<String, dynamic>;
          (copy['properties'] as Map<String, dynamic>)['_color'] = '#2196F3';
          return copy;
        }).toList();
        // Overlay source'u güncelle — ilçe + il feature birleştir
        // İl feature type: line olarak ayrı katmana eklenecek
        final provGeojson = jsonEncode({
          'type': 'FeatureCollection',
          'features': provDeepCopy,
        });
        // Ayrı bir source yerine: mevcut borders source'undaki ilin line rengini değiştir
        // En temiz yol: ayrı bir line layer ekle
        try { await style.removeSource('srrp-overlay-prov'); } catch (_) {}
        await style.addSource(ml.GeoJsonSource(
          id: 'srrp-overlay-prov',
          data: provGeojson,
        ));
        await style.addLayer(
          ml.LineStyleLayer(
            id: _overlayProvLineId,
            sourceId: 'srrp-overlay-prov',
            paint: <String, Object>{
              'line-color': '#2196F3',
              'line-width': 3.0,
              'line-opacity': 0.9,
            },
          ),
          belowLayerId: _pinsShadowLayerId,
        );
      }

      _overlayActive = true;
    } catch (e) {
      debugPrint('[MapLibre-Native] Province overlay hatası: $e');
    }
  }

  /// Sınır katmanlarının aktif olup olmadığı (debug / state tracking).
  bool get hasBordersActive => _bordersActive;

  /// Türkçe karakter normalizasyonu — il eşleştirmesi için.
  static String _normalizeForMatch(String s) {
    return s.toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Long-press: il modu aktifken ek seçim, aktif değilken yok sayılır.
  Future<void> _onMapLongPress(ml.Position point) async {
    if (!mounted) return;
    final vm = Provider.of<MapViewModel>(context, listen: false);
    if (vm.isProvinceModeActive) {
      await _selectGeoAtPoint(point);
    }
  }

  // ─── Katman Kurulumu ──────────────────────────────────────────────

  Future<void> _initLayers() async {
    final style = _style;
    if (style == null) return;

    try {
      await style.addSource(ml.GeoJsonSource(id: _heatmapSourceId, data: _heatmapToGeoJson([])));
    } catch (e) {
      debugPrint('[MapLibre-Native] heatmap source eklenemedi: $e');
    }

    try {
      await style.addSource(ml.GeoJsonSource(id: _heatmapGridSourceId, data: _heatmapGridToGeoJson([])));
    } catch (e) {
      debugPrint('[MapLibre-Native] heatmap grid source eklenemedi: $e');
    }

    try {
      await style.addSource(ml.GeoJsonSource(id: _pinsSourceId, data: _pinsToGeoJson([])));
    } catch (e) {
      debugPrint('[MapLibre-Native] pin source eklenemedi: $e');
    }

    // Cluster source & layers
    try {
      await style.addSource(ml.GeoJsonSource(id: _clusterSourceId, data: '{"type":"FeatureCollection","features":[]}'));
    } catch (e) {
      debugPrint('[MapLibre-Native] cluster source eklenemedi: $e');
    }

    try {
      await style.addLayer(ml.CircleStyleLayer(
        id: _pinsShadowLayerId, sourceId: _pinsSourceId,
        paint: <String, Object>{
          'circle-radius': 12, 'circle-color': '#000000',
          'circle-opacity': 0.0, 'circle-blur': 0.8,
          'circle-translate': [0, 4], 'circle-pitch-alignment': 'map',
        },
      ));
    } catch (e) {
      debugPrint('[MapLibre-Native] shadow layer eklenemedi: $e');
    }

    try {
      await style.addLayer(ml.CircleStyleLayer(
        id: _pinsLayerId, sourceId: _pinsSourceId,
        paint: <String, Object>{
          'circle-radius': ['interpolate', ['linear'], ['zoom'], 4, 6, 10, 10],
          'circle-color': ['get', 'color'],
          'circle-stroke-width': 2, 'circle-stroke-color': '#FFFFFF',
          'circle-opacity': 0.9,
          'circle-pitch-alignment': 'map', 'circle-pitch-scale': 'map',
        },
      ));
    } catch (e) {
      debugPrint('[MapLibre-Native] pins layer eklenemedi: $e');
    }

    try {
      await style.addLayer(ml.SymbolStyleLayer(
        id: _pinsLabelLayerId, sourceId: _pinsSourceId,
        layout: <String, Object>{
          'text-field': ['get', 'name'], 'text-size': 10,
          'text-offset': [0, 1.5], 'text-anchor': 'top',
          'text-allow-overlap': false,
        },
        paint: <String, Object>{
          'text-color': '#FFFFFF', 'text-halo-color': '#000000', 'text-halo-width': 1,
        },
      ));
    } catch (e) {
      debugPrint('[MapLibre-Native] labels layer eklenemedi: $e');
    }

  }

  // ─── Pin Sync ─────────────────────────────────────────────────────

  Future<void> _syncPins(List<Pin> pins, bool is3D, bool cluster) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    final pinsChanged = !_pinsEqual(pins, _lastPins);
    final clusterChanged = cluster != _lastClustering;

    if (pinsChanged) {
      _lastPins = List.from(pins);
    }

    if (pinsChanged || clusterChanged) {
      _lastClustering = cluster;
      if (cluster) {
        await _updateClusterData(pins);
        await _ensureClusterLayers();
      } else {
        await _removeClusterLayers();
        try {
          await style.updateGeoJsonSource(id: _pinsSourceId, data: _pinsToGeoJson(pins));
        } catch (e) {
          debugPrint('[MapLibre-Native] pin source güncelleme hatası: $e');
          return;
        }
      }
    }

    if (is3D == _last3D) return;
    _last3D = is3D;

    try {
      await style.removeLayer(_pinsShadowLayerId);
    } catch (_) {}
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _pinsShadowLayerId, sourceId: _pinsSourceId,
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
      debugPrint('[MapLibre-Native] shadow layer güncelleme hatası: $e');
    }

    try {
      await style.removeLayer(_pinsLayerId);
    } catch (_) {}
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _pinsLayerId, sourceId: _pinsSourceId,
          paint: <String, Object>{
            'circle-radius': ['interpolate', ['linear'], ['zoom'],
              4, is3D ? 8 : 6,
              10, is3D ? 13 : 10,
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
      debugPrint('[MapLibre-Native] pins layer güncelleme hatası: $e');
    }
  }

  bool _pinsEqual(List<Pin> a, List<Pin> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  // ─── Cluster Yardımcıları ─────────────────────────────────────────

  Future<void> _updateClusterData(List<Pin> pins) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;
    final zoom = MapViewMapLibre._activeController?.camera?.zoom ?? 6.0;
    final clusters = _clusterPins(pins, zoom);
    try {
      // Tekil pinleri ana source'a, cluster noktalarını cluster source'a yaz
      await style.updateGeoJsonSource(
        id: _pinsSourceId,
        data: _unclusteredPinsToGeoJson(clusters),
      );
      await style.updateGeoJsonSource(
        id: _clusterSourceId,
        data: _clustersToGeoJson(clusters),
      );
    } catch (e) {
      debugPrint('[MapLibre-Native] cluster güncelleme hatası: $e');
    }
  }

  Future<void> _ensureClusterLayers() async {
    if (_clusterLayersActive) return;
    final style = _style;
    if (style == null) return;
    try {
      await style.addLayer(
        ml.CircleStyleLayer(
          id: _clusterCircleId,
          sourceId: _clusterSourceId,
          paint: <String, Object>{
            'circle-radius': [
              'step', ['get', 'count'],
              18,   // count < 10 → 18px
              10, 24, // count < 50 → 24px
              50, 32, // count >= 50 → 32px
            ],
            'circle-color': [
              'step', ['get', 'count'],
              '#51bbd6', // < 10: açık mavi
              10, '#f1f075', // < 50: sarı
              50, '#f28cb1', // >= 50: pembe
            ],
            'circle-opacity': 0.85,
            'circle-stroke-width': 2,
            'circle-stroke-color': '#FFFFFF',
          },
        ),
        belowLayerId: _pinsLayerId,
      );
    } catch (e) {
      debugPrint('[MapLibre-Native] cluster circle layer hatası: $e');
    }
    try {
      await style.addLayer(
        ml.SymbolStyleLayer(
          id: _clusterCountId,
          sourceId: _clusterSourceId,
          layout: <String, Object>{
            'text-field': ['get', 'label'],
            'text-size': 13,
            'text-allow-overlap': true,
          },
          paint: <String, Object>{
            'text-color': '#000000',
            'text-halo-color': '#FFFFFF',
            'text-halo-width': 1,
          },
        ),
      );
    } catch (e) {
      debugPrint('[MapLibre-Native] cluster count layer hatası: $e');
    }
    _clusterLayersActive = true;
  }

  Future<void> _removeClusterLayers() async {
    if (!_clusterLayersActive) return;
    final style = _style;
    if (style == null) return;
    try { await style.removeLayer(_clusterCountId); } catch (_) {}
    try { await style.removeLayer(_clusterCircleId); } catch (_) {}
    _clusterLayersActive = false;
    // Tüm pinleri tekrar göster
    try {
      await style.updateGeoJsonSource(
        id: _clusterSourceId,
        data: '{"type":"FeatureCollection","features":[]}',
      );
    } catch (_) {}
  }

  // ─── Heatmap Sync ─────────────────────────────────────────────────

  Future<void> _syncHeatmapData(List<CityWeatherSummary> summaries) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;
    if (summaries.length == _lastSummary.length && _lastSummary.isNotEmpty) return;
    _lastSummary = List.from(summaries);
    try {
      await style.updateGeoJsonSource(
        id: _heatmapSourceId,
        data: _heatmapToGeoJson(summaries),
      );
    } catch (e) {
      debugPrint('[MapLibre-Native] heatmap source güncelleme hatası: $e');
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
      debugPrint('[MapLibre-Native] heatmap grid source güncelleme hatası: $e');
    }
  }

  Future<void> _syncHeatmapMode(MlHeatmapMode mode) async {
    final style = _style;
    if (style == null || !_styleLoaded || mode == _lastHeatmap) return;
    _lastHeatmap = mode;

    if (_solarActive) {
      try { await style.removeLayer(_heatmapSolarId); } catch (_) {}
      _solarActive = false;
    }
    if (_windActive) {
      try { await style.removeLayer(_heatmapWindId); } catch (_) {}
      _windActive = false;
    }

    if (mode == MlHeatmapMode.none) return;

    final layerId  = mode == MlHeatmapMode.solar ? _heatmapSolarId : _heatmapWindId;
    final paintDef = mode == MlHeatmapMode.solar ? _solarHeatmapPaint : _windHeatmapPaint;

    bool added = false;

    try {
      await style.addLayer(
        ml.HeatmapStyleLayer(id: layerId, sourceId: _heatmapGridSourceId, paint: paintDef),
        belowLayerId: _pinsShadowLayerId,
      );
      added = true;
    } catch (_) {}

    if (!added) {
      try {
        await style.addLayer(
          ml.HeatmapStyleLayer(id: layerId, sourceId: _heatmapGridSourceId, paint: paintDef),
        );
        added = true;
      } catch (e) {
        debugPrint('[MapLibre-Native] heatmap layer eklenemedi: $e');
      }
    }

    if (added) {
      if (mode == MlHeatmapMode.solar) _solarActive = true;
      if (mode == MlHeatmapMode.wind)  _windActive  = true;
    }
  }

  // ─── MVT Vector Layer Sync (B5 — PostGIS overlay'leri) ──────────────
  //
  // 2026-06-01: NATIVE destek eklendi. maplibre 0.2.2 `VectorSource`'ta
  // `sourceLayer` alanını destekliyor (source başına bir source-layer) → her
  // source-layer (hydro/restricted/energy) için aynı tile URL'li ayrı
  // VectorSource. Web tek source + layer-level source-layer kullanır.
  Future<void> _syncMvtLayers(MapViewModel vm) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    final hydro = vm.showHydroLayer;
    final restricted = vm.showRestrictedZoneLayer;
    final energy = vm.showEnergyCorridorLayer;
    if (hydro == _lastHydroLayer &&
        restricted == _lastRestrictedLayer &&
        energy == _lastEnergyCorridorLayer) {
      return;
    }
    _lastHydroLayer = hydro;
    _lastRestrictedLayer = restricted;
    _lastEnergyCorridorLayer = energy;

    // 2026-06-01: maplibre 0.2.2 ANDROID VectorSource SADECE `url` (TileJSON)
    // destekliyor (`tiles[]` → `source.url!` null crash; data-URI de parse
    // edilemiyor "Unable to parse resourceUrl"). Backend'in TileJSON endpoint'ini
    // veriyoruz; o da `tiles` URL'ini isteğin host'undan türetir.
    final base = vm.apiService.analysis.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final tileSrcUrl = '$base/api/v1/tiles/tilejson.json';

    // ── HYDRO (göl/baraj/nehir) — fill + line ──
    if (hydro && !_mvtHydroActive) {
      try {
        await style.addSource(ml.VectorSource(
          id: _mvtHydroSrc, url: '$tileSrcUrl?sl=hydro',
          sourceLayer: 'hydro', minZoom: 6, maxZoom: 18,
        ));
        await style.addLayer(
          ml.FillStyleLayer(
            id: _mvtHydroFillId, sourceId: _mvtHydroSrc,
            // 2026-06-01: native'de iç içe `match` ifadesi parse edilmiyordu
            // (katman hiç çizilmiyordu) → düz tek renk. Su = mavi.
            paint: <String, Object>{
              'fill-color': '#1E5BA8',
              'fill-opacity': 0.55,
              'fill-outline-color': '#0E3A6E',
            },
          ),
          belowLayerId: _pinsShadowLayerId,
        );
        await style.addLayer(
          ml.LineStyleLayer(
            id: _mvtHydroLineId, sourceId: _mvtHydroSrc,
            paint: <String, Object>{
              'line-color': '#9FD8FF', 'line-width': 0.8, 'line-opacity': 0.8,
            },
          ),
          belowLayerId: _pinsShadowLayerId,
        );
        _mvtHydroActive = true;
      } catch (e) {
        debugPrint('[MapLibre-Native] MVT hydro ekleme hatası: $e');
      }
    } else if (!hydro && _mvtHydroActive) {
      try { await style.removeLayer(_mvtHydroLineId); } catch (_) {}
      try { await style.removeLayer(_mvtHydroFillId); } catch (_) {}
      try { await style.removeSource(_mvtHydroSrc); } catch (_) {}
      _mvtHydroActive = false;
    }

    // ── RESTRICTED (askeri/koruma) — fill (kırmızı tonları) ──
    if (restricted && !_mvtRestrictedActive) {
      try {
        await style.addSource(ml.VectorSource(
          id: _mvtRestrictedSrc, url: '$tileSrcUrl?sl=restricted',
          sourceLayer: 'restricted', minZoom: 6, maxZoom: 18,
        ));
        await style.addLayer(
          ml.FillStyleLayer(
            id: _mvtRestrictedId, sourceId: _mvtRestrictedSrc,
            // 2026-06-01: match yerine düz kırmızı (native parse sorunu).
            paint: <String, Object>{
              'fill-color': '#C62828',
              'fill-opacity': 0.42,
              'fill-outline-color': '#7F0000',
            },
          ),
          belowLayerId: _pinsShadowLayerId,
        );
        _mvtRestrictedActive = true;
      } catch (e) {
        debugPrint('[MapLibre-Native] MVT restricted ekleme hatası: $e');
      }
    } else if (!restricted && _mvtRestrictedActive) {
      try { await style.removeLayer(_mvtRestrictedId); } catch (_) {}
      try { await style.removeSource(_mvtRestrictedSrc); } catch (_) {}
      _mvtRestrictedActive = false;
    }

    // ── ENERGY (iletim hatları) — line ──
    if (energy && !_mvtEnergyActive) {
      try {
        await style.addSource(ml.VectorSource(
          id: _mvtEnergySrc, url: '$tileSrcUrl?sl=energy',
          sourceLayer: 'energy', minZoom: 6, maxZoom: 18,
        ));
        await style.addLayer(
          ml.LineStyleLayer(
            id: _mvtEnergyId, sourceId: _mvtEnergySrc,
            paint: <String, Object>{
              'line-color': '#FFD54F', 'line-width': 1.4, 'line-opacity': 0.85,
            },
          ),
          belowLayerId: _pinsShadowLayerId,
        );
        _mvtEnergyActive = true;
      } catch (e) {
        debugPrint('[MapLibre-Native] MVT energy ekleme hatası: $e');
      }
    } else if (!energy && _mvtEnergyActive) {
      try { await style.removeLayer(_mvtEnergyId); } catch (_) {}
      try { await style.removeSource(_mvtEnergySrc); } catch (_) {}
      _mvtEnergyActive = false;
    }
  }

  // ─── Terrain Sync (native: yalnızca hillshade görsel efekti) ──────

  Future<void> _syncTerrain(bool show) async {
    final style = _style;
    if (style == null || !_styleLoaded || show == _lastTerrain) return;
    _lastTerrain = show;

    if (show) {
      try {
        await style.addSource(ml.RasterDemSource(
          id: _hillshadeSourceId,
          url: 'https://demotiles.maplibre.org/terrain-tiles/tiles.json',
          tileSize: 256,
        ));
      } catch (_) {}

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
          debugPrint('[MapLibre-Native] hillshade layer hatası: $e');
        }
      }
    } else {
      if (_hillshadeActive) {
        try { await style.removeLayer(_hillshadeLayerId); } catch (_) {}
        _hillshadeActive = false;
      }
      try { await style.removeSource(_hillshadeSourceId); } catch (_) {}
    }
  }

  // ─── Cloud Layer Sync (native: RasterSource tile overlay) ─────────

  Future<void> _syncCloudLayer(bool show) async {
    final style = _style;
    if (style == null || !_styleLoaded || show == _lastCloud) return;
    _lastCloud = show;

    if (show && !_cloudActive) {
      try {
        // RainViewer ücretsiz bulut/radar tile'ları (API key gerekmez)
        await style.addSource(ml.RasterSource(
          id: _cloudSourceId,
          tiles: ['https://tilecache.rainviewer.com/v2/satellite/nowcast/256/{z}/{x}/{y}/2/1_1.png'],
          tileSize: 256,
          maxZoom: 8,
        ));
      } catch (_) {}

      try {
        await style.addLayer(
          ml.RasterStyleLayer(
            id: _cloudLayerId,
            sourceId: _cloudSourceId,
            paint: <String, Object>{
              'raster-opacity': 0.45,
            },
          ),
          belowLayerId: _pinsShadowLayerId,
        );
        _cloudActive = true;
      } catch (e) {
        debugPrint('[MapLibre-Native] cloud layer eklenemedi: $e');
      }
    } else if (!show && _cloudActive) {
      try { await style.removeLayer(_cloudLayerId); } catch (_) {}
      try { await style.removeSource(_cloudSourceId); } catch (_) {}
      _cloudActive = false;
    }
  }

  // ─── İzohips Contour Sync (O1.4 native parite) ────────────────────
  //
  // OpenTopoMap raster tiles, 3 subdomain rotation + maxZoom 17.
  // Web tarafıyla aynı kaynak/lisans; UI'da attribution chip Layers panel'de.
  // O2 sprint'inde kendi MVT pipeline'ımıza geçince bu URL değişir.
  Future<void> _syncContourLayer(bool show, double opacity) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;
    final opacityChanged =
        (opacity - _lastContourOpacity).abs() > 0.005;
    if (show == _lastContour && !opacityChanged) return;
    _lastContour = show;
    _lastContourOpacity = opacity;

    if (show && !_contourActive) {
      try {
        await style.addSource(ml.RasterSource(
          id: _contourSourceId,
          tiles: const [
            'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
            'https://b.tile.opentopomap.org/{z}/{x}/{y}.png',
            'https://c.tile.opentopomap.org/{z}/{x}/{y}.png',
          ],
          tileSize: 256,
          maxZoom: 17,
        ));
      } catch (_) {}

      try {
        await style.addLayer(
          ml.RasterStyleLayer(
            id: _contourLayerId,
            sourceId: _contourSourceId,
            paint: <String, Object>{
              'raster-opacity': opacity,
            },
          ),
          // Pin/cluster katmanlarının altında, terrain/borders üstünde.
          belowLayerId: _pinsShadowLayerId,
        );
        _contourActive = true;
      } catch (e) {
        debugPrint('[MapLibre-Native] contour layer eklenemedi: $e');
      }
    } else if (show && _contourActive && opacityChanged) {
      // maplibre 0.2.2'de setPaintProperty/updateLayer yok → layer'ı
      // kaldırıp aynı paint ile tekrar ekle. Source aynı kalabilir.
      try {
        await style.removeLayer(_contourLayerId);
        await style.addLayer(
          ml.RasterStyleLayer(
            id: _contourLayerId,
            sourceId: _contourSourceId,
            paint: <String, Object>{'raster-opacity': opacity},
          ),
          belowLayerId: _pinsShadowLayerId,
        );
      } catch (e) {
        debugPrint('[MapLibre-Native] contour opacity update fail: $e');
      }
    } else if (!show && _contourActive) {
      try { await style.removeLayer(_contourLayerId); } catch (_) {}
      try { await style.removeSource(_contourSourceId); } catch (_) {}
      _contourActive = false;
    }
  }

  // ─── İl/İlçe Sınırları Sync (ViewModel değişimine tepki) ──────

  /// Border layer işlemleri için kilit — race condition önler (SIGSEGV fix).
  bool _bordersSyncing = false;

  Future<void> _syncBorders(MapViewModel vm) async {
    if (_style == null || !_styleLoaded || _bordersSyncing) return;

    final show = vm.isProvinceModeActive;
    final level = vm.selectionLevel;
    final province = vm.selectedProvinceName;
    final region = vm.selectedRegionName;
    final district = vm.selectedDistrictName;
    // B3: Tematik harita (choropleth/ML) aktifse seçim FILL'i bastırılır (sadece
    // sınır çizgisi) → tematik renk gizlenmesin. Toggle da değişim sayılır.
    final thematicActive = _choroplethLayerActive || _mlChoroLayerActive;

    // Hiç değişim yoksa çık
    if (show == _lastProvincesMode &&
        level == _lastSelectionLevel &&
        province == _lastSelectedProvince &&
        region == _lastSelectedRegion &&
        district == _lastSelectedDistrict &&
        thematicActive == _lastThematicActive) {
      return;
    }

    final regionChanged = region != _lastSelectedRegion;
    final provinceChanged = province != _lastSelectedProvince;

    _lastProvincesMode = show;
    _lastSelectionLevel = level;
    _lastSelectedProvince = province;
    _lastSelectedRegion = region;
    _lastSelectedDistrict = district;
    _lastThematicActive = thematicActive;

    if (!show) {
      await _removeBorderLayers();
      return;
    }

    // _selectGeoAtPoint zaten border yüklüyorsa tekrar yükleme
    // (state güncellendi yukarıda, _selectGeoAtPoint bitince _syncBorders tekrar çağrılmaz)
    if (_geoSelectBusy) {
      return;
    }

    _bordersSyncing = true;
    try {
      final initial = vm.initialSelectionMode;

      if (level == SelectionLevel.district && initial == SelectionLevel.province) {
        // İL MODU → ilçe seviyesine geçildi: il sınırlarını koru, üstüne overlay ekle
        // 2026-06-01: guard `!_bordersActive` yerine `_borderKind` — başka moddan
        // (Bölge=region renk / İlçe=district) gelince eski sınırlar kalmasın.
        // Zaten province-UNIQUE yüklüyse (region-scoped olsa bile) koru — yeniden
        // yükleyip görünümü tüm illere genişletme.
        final fillTok = thematicActive ? 'nofill' : 'fill';
        final hasProvinceUnique = _borderKind.startsWith('prov:') &&
            _borderKind.contains(':unique') &&
            _borderKind.endsWith(':$fillTok');
        if (!hasProvinceUnique) {
          // B1: İl modu → her il unique (graph) renk; bölge rengi değil.
          await _loadProvinceBorders(
              useRegionColors: false, suppressFill: thematicActive); // Tüm iller
        }
        // Sadece il değiştiğinde overlay'ı güncelle (aynı ilde ilçe seçiminde değiştirme)
        if (province != null && (provinceChanged || !_overlayActive)) {
          await _showProvinceOverlay(province);
        }
      } else if (level == SelectionLevel.district && initial == SelectionLevel.district) {
        // İLÇE MODU: tüm ilçeler, seçim renkleri değişmez
        await _removeOverlayLayers();
        // 2026-06-01: Bölge/İl modundan İlçe moduna geçince `_bordersActive` hâlâ
        // true (eski province sınırları) → eskiden ilçeler yüklenmiyor, renk
        // değişmiyordu. `_borderKind` ile "tüm ilçeler yüklü değilse yükle".
        final desiredDistAll = 'dist:all::${thematicActive ? "nofill" : "fill"}';
        if (_borderKind != desiredDistAll) {
          await _loadDistrictBorders(null, suppressFill: thematicActive);
        }
        // İlçe seçildiğinde borderleri yeniden çizme — sadece mavi çerçeve
      } else if (level == SelectionLevel.district) {
        // Bölge modu → ilçe seviyesi: overlay temizle, klasik ilçe sınırları yükle
        await _removeOverlayLayers();
        await _loadDistrictBorders(province,
            highlightDistrict: district, suppressFill: thematicActive);
      } else if (level == SelectionLevel.region) {
        // BÖLGE modu → iller bölge rengiyle (region color blocks).
        await _removeOverlayLayers();
        await _loadProvinceBorders(
            regionFilter: null, useRegionColors: true, suppressFill: thematicActive);
      } else {
        // Province (İl) modu ve Region → Province geçişi → her il unique renk.
        await _removeOverlayLayers();
        await _loadProvinceBorders(
            regionFilter: region, useRegionColors: false, suppressFill: thematicActive);
        if (regionChanged && region != null) {
          _flyToRegionBounds(region);
        }
      }

      // Seçili ilçe mavi çerçeve — tüm modlarda geçerli (ilçe seçildiğinde belirginlik)
      if (level == SelectionLevel.district &&
          province != null && province.isNotEmpty &&
          district != null && district.isNotEmpty) {
        await _showDistrictHighlight(province, district);
      } else {
        await _removeDistrictHighlight();
      }
    } finally {
      _bordersSyncing = false;
    }
  }

  /// İl adından bölge adını bulur (cache'lenmiş province GeoJSON'ından).
  String? _findRegionForProvince(String provinceName) {
    final features = _parsedProvinceFeatures;
    if (features == null || features.isEmpty) return null;
    final normTarget = _normalizeForMatch(provinceName);
    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final name1 = (props['NAME_1'] ?? '').toString();
      if (_normalizeForMatch(name1) == normTarget) {
        return (props['REGION'] ?? '').toString();
      }
    }
    return null;
  }

  /// Bölge sınırlarına kamerayı uçurur (province GeoJSON'ından bbox hesaplar).
  void _flyToRegionBounds(String regionName) {
    final features = _parsedProvinceFeatures;
    if (features == null || features.isEmpty) return;

    final normRegion = _normalizeForMatch(regionName);
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    bool found = false;

    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>? ?? {};
      final region = (props['REGION'] ?? '').toString();
      if (_normalizeForMatch(region) != normRegion) continue;
      found = true;
      _extractCoordsFromGeometry(f['geometry'], (lon, lat) {
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lon < minLon) minLon = lon;
        if (lon > maxLon) maxLon = lon;
      });
    }

    if (!found) return;

    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    final span = math.max(maxLat - minLat, maxLon - minLon);
    final zoom = (10.0 - (math.log(span.clamp(0.1, 20)) / math.ln2) * 1.2).clamp(5.0, 10.0);

    MapViewMapLibre._activeController?.animateCamera(
      center: ml.Position(centerLon, centerLat),
      zoom: zoom,
      nativeDuration: const Duration(milliseconds: 700),
    );
  }

  // ─── Choropleth Sync (native: GeoJSON fill layer) ─────────────────

  static const _choroplethSourceId = 'srrp-choropleth-src';
  static const _choroplethLayerId  = 'srrp-choropleth-fill';

  Future<void> _syncChoropleth(MapViewModel vm) async {
    final style = _style;
    if (style == null || !_styleLoaded) return;

    final mode = vm.choroplethMode;
    final data = vm.choroplethData;
    final hasData = data != null && data.isNotEmpty;

    // 2026-06-01 (B6): eskiden sadece mode'a bakıyordu → zaman simülasyonunda
    // metrik sabit ama frame data'sı her tikte değişiyordu, native güncellemiyordu
    // ("tek renk, değişmiyor"). Artık data identity değişince yeniden çizilir.
    final dataChanged = !identical(data, _lastChoroData);
    if (mode == _lastChoropleth &&
        !dataChanged &&
        (_choroplethLayerActive || !hasData)) {
      return;
    }
    _lastChoropleth = mode;
    _lastChoroData = data;

    // Önceki katmanı kaldır
    if (_choroplethLayerActive) {
      try { await style.removeLayer(_choroplethLayerId); } catch (_) {}
      _choroplethLayerActive = false;
    }
    if (_choroplethSourceAdded) {
      try { await style.removeSource(_choroplethSourceId); } catch (_) {}
      _choroplethSourceAdded = false;
    }

    if (mode == ChoroplethMode.none || data == null || data.isEmpty) return;

    try {
      // 2026-06-01 (B6 perf): cache'li parsed + Türkiye-filtreli feature listesi
      // — animasyonda her frame ~10MB GeoJSON yeniden decode edilmesin (frame'ler
      // ilerleyemiyordu). Cache MUTATE EDİLMEZ; aşağıda yeni feature objeleri kurulur.
      final src = await _getDistrictFeatures();
      if (_disposed || !_styleLoaded || _style == null) return;
      if (src.isEmpty) return;
      final dataKey = mode.dataKey;

      // ── Sabit fiziksel skala — gerçek değer → renk eşlemesi ──────────
      // Sıcaklık, rüzgar, ışınım için fiziksel anlamlı eşik değerleri.
      // Aynı değer HER ZAMAN aynı renk = tutarlı, okunabilir harita.
      //
      // Ramp: [[gerçek_değer, '#hex'], ...] — interpolate ile ara değerler hesaplanır.
      List<List<dynamic>> physicalRamp;
      if (dataKey == 'solar') {
        // W/m² — 2026-05-19 ters çevrildi (sezgi: gece=koyu, çok güneş=parlak).
        physicalRamp = [
          [0,   '#1a1a2e'], // gece — koyu lacivert
          [50,  '#4D0014'], // çok düşük — koyu bordo
          [150, '#BD0026'],
          [250, '#E31A1C'],
          [350, '#FC4E2A'],
          [450, '#FD8D3C'],
          [550, '#FEB24C'],
          [650, '#FED976'],
          [750, '#FFEDA0'],
          [800, '#FFFFCC'], // maksimum — parlak sarı
        ];
      } else if (dataKey == 'wind') {
        // m/s (100m) — 0=durgun, 25+=fırtına
        physicalRamp = [
          [0,  '#F7FBFF'],  // durgun — beyazımsı
          [2,  '#DEEBF7'],
          [4,  '#C6DBEF'],
          [6,  '#9ECAE1'],
          [8,  '#6BAED6'],
          [10, '#4292C6'],
          [13, '#2171B5'],
          [16, '#08519C'],
          [20, '#083D7F'],
          [25, '#08306B'],  // fırtına — koyu lacivert
        ];
      } else {
        // °C — sabit meteorolojik skala
        physicalRamp = [
          [-15, '#08306B'], // çok soğuk — koyu lacivert
          [-5,  '#2171B5'],
          [0,   '#E0F3F8'], // donma — beyazımsı
          [5,   '#C6DBEF'],
          [10,  '#ABD9E9'],
          [15,  '#74ADD1'],
          [20,  '#66BD63'], // ılık — yeşil
          [25,  '#A6D96A'],
          [30,  '#FEE08B'], // sıcak — sarı
          [33,  '#FDAE61'],
          [36,  '#F46D43'], // çok sıcak — turuncu
          [40,  '#D73027'], // aşırı — kırmızı
          [45,  '#A50026'], // tehlikeli — koyu kırmızı
        ];
      }

      // physicalRamp'tan normalize edilmiş 0..1 ramp oluştur
      final physMin = (physicalRamp.first[0] as num).toDouble();
      final physMax = (physicalRamp.last[0] as num).toDouble();
      final physRange = physMax - physMin;

      List<List<dynamic>> ramp = [];
      for (final stop in physicalRamp) {
        final val = (stop[0] as num).toDouble();
        final t = (val - physMin) / physRange;
        ramp.add([t, stop[1]]);
      }
      // ─── Rengi önceden hesapla (pre-compute) ─────────────────────────
      // MapLibre Native düşük zoom'da interpolate expression'ı bozuyor → rengi
      // feature property'sine string olarak yazıyoruz. Verisi 0/olmayan ilçe
      // atlanır (siyah polygon önlenir). YENİ feature objeleri → cache mutate yok.
      final colored = <Map<String, dynamic>>[];
      for (final f in src) {
        final props = f['properties'] as Map<String, dynamic>? ?? const {};
        final key = '${props['NAME_1'] ?? ''}|${props['NAME_2'] ?? ''}';
        final entry = data[key];
        final v = (entry is Map)
            ? ((entry[dataKey] as num?)?.toDouble() ?? 0.0)
            : 0.0;
        if (v == 0.0) continue;
        final t = ((v - physMin) / physRange).clamp(0.0, 1.0);
        String color = ramp.last[1] as String;
        for (int i = 0; i < ramp.length - 1; i++) {
          final t0 = ramp[i][0] as double;
          final t1 = ramp[i + 1][0] as double;
          if (t >= t0 && t <= t1) {
            color = (t - t0 <= t1 - t) ? ramp[i][1] as String : ramp[i + 1][1] as String;
            break;
          }
        }
        colored.add({
          'type': 'Feature',
          'properties': {'_choro_color': color},
          'geometry': f['geometry'],
        });
      }
      if (colored.isEmpty) return;

      await style.addSource(ml.GeoJsonSource(
        id: _choroplethSourceId,
        data: jsonEncode({'type': 'FeatureCollection', 'features': colored}),
      ));
      _choroplethSourceAdded = true;

      await style.addLayer(ml.FillStyleLayer(
        id: _choroplethLayerId,
        sourceId: _choroplethSourceId,
        paint: {
          'fill-color': ['get', '_choro_color'],
          'fill-opacity': 0.82,
        },
      ), belowLayerId: _pinsShadowLayerId);
      _choroplethLayerActive = true;
    } catch (e) {
      debugPrint('[MapLibre-Native] Choropleth layer hatası: $e');
    }
  }

  // ─── ML Projeksiyon Choropleth (B4) ────────────────────────────────
  // Weather choropleth'ten ayrı katman. Veri: {"İl|İlçe": değer} /
  // {"İl": değer} / {değer nesnesi}. Viridis gradyanı min..max. Renk
  // feature property'sine pre-compute edilir (native interpolate sorunu yok).
  static const _mlChoroSourceId = 'srrp-ml-choro-src';
  static const _mlChoroLayerId  = 'srrp-ml-choro-fill';

  void _applyMlChoropleth(String dataJson) {
    if (_disposed) return;
    _lastMlChoroJson = dataJson;
    final seq = ++_mlSeq;
    _renderMlChoropleth(dataJson, seq);
  }

  void _clearMlChoropleth() {
    _lastMlChoroJson = null;
    _clearMlChoroLocked();
  }

  /// 2026-06-01 (CRASH FIX): ML choropleth op'larını `_syncAll` ile AYNI
  /// `_syncing` kilidinde serialize eder. ML source mutasyonu, `_syncAll`'ın
  /// border removeSource'u ile EŞ ZAMANLI çalışınca maplibre'nin GeoJSON
  /// parse-callback'i serbest bırakılmış source'a dokunup SIGSEGV veriyordu
  /// (reset crash'i). Kilit alınamazsa (dispose/teardown) false döner → no-op.
  Future<bool> _acquireSyncLock() async {
    var tries = 0;
    while (_syncing) {
      if (_disposed) return false;
      await Future.delayed(const Duration(milliseconds: 16));
      if (++tries > 300) return false; // ~5 sn güvenlik tavanı
    }
    if (_disposed || !_styleLoaded || _style == null) return false;
    _syncing = true;
    return true;
  }

  /// Kilit TUTAN çağıran tarafından çağrılır (kendi kilit almaz → deadlock yok).
  Future<void> _removeMlChoroLayersUnlocked() async {
    final style = _style;
    if (style == null) return;
    if (_mlChoroLayerActive) {
      try { await style.removeLayer(_mlChoroLayerId); } catch (_) {}
      _mlChoroLayerActive = false;
    }
    if (_mlChoroSourceAdded) {
      try { await style.removeSource(_mlChoroSourceId); } catch (_) {}
      _mlChoroSourceAdded = false;
    }
  }

  Future<void> _clearMlChoroLocked() async {
    if (!await _acquireSyncLock()) return;
    try {
      await _removeMlChoroLayersUnlocked();
    } finally {
      _syncing = false;
    }
  }

  double? _mlNum(dynamic e) {
    if (e is num) return e.toDouble();
    if (e is Map && e['value'] is num) return (e['value'] as num).toDouble();
    return null;
  }

  Future<void> _renderMlChoropleth(String dataJson, int seq) async {
    // Kilit al — _syncAll/border op'larıyla eşzamanlı GeoJSON mutasyonu yok.
    if (!await _acquireSyncLock()) return;
    try {
      // Kilidi beklerken daha yeni bir istek geldiyse bunu atla (coalesce).
      if (seq != _mlSeq) return;
      final style = _style;
      if (style == null) return;
      final raw = jsonDecode(dataJson);
      if (raw is! Map) return;

      // Değer aralığı (min..max) — viridis gradyanını buna yay.
      final vals = <double>[];
      raw.forEach((k, v) {
        if (k == '_meta') return;
        final n = _mlNum(v);
        if (n != null && n.isFinite) vals.add(n);
      });
      if (vals.isEmpty) {
        _lastMlChoroJson = null;
        await _removeMlChoroLayersUnlocked();
        return;
      }
      var mn = vals.reduce((a, b) => a < b ? a : b);
      var mx = vals.reduce((a, b) => a > b ? a : b);
      if (mx - mn < 1e-9) mx = mn + 1;

      const viridis = [
        '#440154', '#414487', '#2a788e', '#22a884',
        '#7ad151', '#bddf26', '#fde725',
      ];

      // İl-seviyesi normalize index — composite/düz anahtar tutmazsa son çare.
      final provNorm = <String, double>{};
      raw.forEach((k, v) {
        if (k == '_meta' || (k as String).contains('|')) return;
        final n = _mlNum(v);
        if (n != null) provNorm[_normName(k)] = n;
      });

      // Parse edilmiş + Türkiye-filtreli ilçe feature cache'i (tek sefer parse;
      // animasyonda her frame ~10MB GeoJSON yeniden decode edilmesin).
      final features = await _getDistrictFeatures();
      // await sonrası teardown/style reload kontrolü.
      if (_disposed || !_styleLoaded || _style == null) return;
      if (features.isEmpty) return;

      // Her feature → değer (composite → il → normalize il) + viridis rengi.
      final colored = <Map<String, dynamic>>[];
      for (final f in features) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final n1 = (props['NAME_1'] ?? '').toString();
        final n2 = (props['NAME_2'] ?? '').toString();
        final val = _mlNum(raw['$n1|$n2']) ??
            _mlNum(raw[n1]) ??
            provNorm[_normName(n1)];
        if (val == null || !val.isFinite) continue;
        final t = ((val - mn) / (mx - mn)).clamp(0.0, 1.0);
        final idx =
            (t * (viridis.length - 1)).round().clamp(0, viridis.length - 1);
        colored.add({
          'type': 'Feature',
          'properties': {'_ml_color': viridis[idx]},
          'geometry': f['geometry'],
        });
      }
      if (colored.isEmpty) {
        _lastMlChoroJson = null;
        await _removeMlChoroLayersUnlocked();
        return;
      }

      // Eski katmanı temizle (kilidi zaten tutuyoruz → unlocked).
      await _removeMlChoroLayersUnlocked();
      if (_disposed || _style == null) return;

      await style.addSource(ml.GeoJsonSource(
        id: _mlChoroSourceId,
        data: jsonEncode({'type': 'FeatureCollection', 'features': colored}),
      ));
      _mlChoroSourceAdded = true;

      await style.addLayer(ml.FillStyleLayer(
        id: _mlChoroLayerId,
        sourceId: _mlChoroSourceId,
        paint: {
          'fill-color': ['get', '_ml_color'],
          'fill-opacity': 0.82,
        },
      ), belowLayerId: _pinsShadowLayerId);
      _mlChoroLayerActive = true;
      debugPrint('[MapLibre-Native] ML choropleth: ${colored.length} polygon, '
          'aralık $mn..$mx');
    } catch (e) {
      debugPrint('[MapLibre-Native] ML choropleth hatası: $e');
    } finally {
      _syncing = false;
    }
  }

  /// İl adı normalize (diakritik/kısaltma köprüsü) — web `_srrpNormName` ile
  /// aynı amaç. Büyük/küçük Türkçe harfleri açıkça eşler, sonra ASCII lower.
  static String _normName(String s) {
    final r = s
        .replaceAll('â', 'a').replaceAll('Â', 'a')
        .replaceAll('î', 'i').replaceAll('Î', 'i')
        .replaceAll('û', 'u').replaceAll('Û', 'u')
        .replaceAll('ı', 'i').replaceAll('İ', 'i')
        .replaceAll('ş', 's').replaceAll('Ş', 's')
        .replaceAll('ç', 'c').replaceAll('Ç', 'c')
        .replaceAll('ğ', 'g').replaceAll('Ğ', 'g')
        .replaceAll('ö', 'o').replaceAll('Ö', 'o')
        .replaceAll('ü', 'u').replaceAll('Ü', 'u');
    return r.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
  }


  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm       = Provider.of<MapViewModel>(context);
    final styleUrl = vm.mlBaseStyle.styleUrl;
    final isGlobe  = vm.showGlobe;
    _globeForConstrain = isGlobe; // B8: move event'inde Provider okumamak için

    // Dikey/yatay yönelime göre sınır ve zoom ayarı
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    // Globe modunda sınır yok + düşük zoom; normal modda Türkiye sınırları
    // Portrait: enlem ekseninde daha geniş sınır + yüksek minZoom (dar ekranda kayma önlenir)
    final ml.LngLatBounds? bounds = isGlobe
        ? null
        : ml.LngLatBounds(
            longitudeWest: isPortrait ? 22.0 : MapConstants.turkeyMinLon,
            longitudeEast: isPortrait ? 48.0 : MapConstants.turkeyMaxLon,
            latitudeSouth: isPortrait ? 33.0 : MapConstants.turkeyMinLat,
            latitudeNorth: isPortrait ? 45.0 : MapConstants.turkeyMaxLat,
          );

    final effectiveMinZoom = isGlobe ? 1.5
        : isPortrait ? 4.5
        : MapConstants.minZoom;

    return Stack(
      children: [
        KeyedSubtree(
          key: ValueKey('$styleUrl-$isGlobe-$isPortrait'),
          child: ml.MapLibreMap(
            options: ml.MapOptions(
              initStyle: styleUrl,
              initZoom: isGlobe ? 2.0 : MapConstants.initialZoom,
              initPitch: isGlobe ? 45.0 : 0.0,
              minZoom: effectiveMinZoom,
              maxBounds: bounds,
              initCenter: isGlobe
                  ? ml.Position(35.5, 20.0)
                  : ml.Position(
                      MapConstants.turkeyCenterLon,
                      MapConstants.turkeyCenterLat,
                    ),
            ),
            onEvent: _onEvent,
            onMapCreated: (controller) {
              MapViewMapLibre._activeController = controller;
            },
          ),
        ),

        // Yükleniyor (style)
        if (!_styleLoaded)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 12),
                Text('MapLibre yükleniyor...', style: TextStyle(color: Colors.white70)),
              ]),
            ),
          ),

        // Geo sorgusu yükleniyor göstergesi
        if (_geoLoading)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Konum sorgulanıyor...',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

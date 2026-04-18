import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/features/map/layers/map_layers_system.dart';

mixin MapLayerMixin on BaseViewModel {
  // Abstract dependency
  ApiService get apiService;

  /// Aynı frame içindeki tüm safeNotify() çağrılarını tek bir notifyListeners()'a
  /// indirger. Pointer event (tap/hover) sırasında widget tree mutasyonunu önler
  /// (mouse_tracker re-entrant assertion fix).
  bool _notifyScheduled = false;

  void safeNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      // BaseViewModel._disposed kontrolü notifyListeners() içinde yapılır,
      // ama callback schedule edildikten sonra dispose olmuş olabilir.
      notifyListeners();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  MapLayerType _currentLayer = MapLayerType.none;
  List<Map<String, dynamic>> _interpolatedData = [];
  bool _isHeatmapLoading = false;

  // heatmapPoints cache — _interpolatedData değişince yenilenir,
  // aksi hâlde aynı List referansı döner → MapLayerWidget gereksiz
  // yeniden hesaplama yapmaz (didUpdateWidget: data != oldData = false).
  List<HeatmapPoint>? _heatmapPointsCache;

  // Katman verisi önbelleği: her layer türü için {data, fetchTime}
  // 5 dakika içinde aynı layer tekrar açılırsa API'ye gidilmez.
  final Map<MapLayerType, List<Map<String, dynamic>>> _layerDataCache = {};
  final Map<MapLayerType, DateTime> _layerCacheTime = {};
  static const Duration _layerCacheTtl = Duration(minutes: 5);

  // ─── Rüzgar Parçacık + Yükseklik Katmanı State ──────────────────────────
  bool _showWindParticles = false;
  bool _isWindLoading = false;
  bool _windDataEmpty = false;
  bool _showElevation = false;
  WindParticleQuality _windQuality = WindParticleQuality.balanced;
  List<WindVector> _windVectors = [];

  static const _qualityKey = 'wind_particle_quality';

  bool get showWindParticles => _showWindParticles;
  bool get isWindLoading => _isWindLoading;
  bool get windDataEmpty => _windDataEmpty;
  bool get showElevation => _showElevation;
  WindParticleQuality get windQuality => _windQuality;
  List<WindVector> get windVectors => _windVectors;
  // ──────────────────────────────────────────────────────────────────────────

  MapLayerType get currentLayer => _currentLayer;
  bool get isHeatmapLoading => _isHeatmapLoading;

  // --- HEATMAP İÇİN VERİ DÖNÜŞÜMÜ ---
  /// Cache'li getter: _interpolatedData değişmediği sürece
  /// aynı List[HeatmapPoint] referansını döndürür.
  /// Böylece MapLayerWidget.didUpdateWidget her rebuild'de
  /// _generateLayerPicture() tetiklemez.
  List<HeatmapPoint> get heatmapPoints => _heatmapPointsCache ?? [];

  void _rebuildHeatmapCache() {
    if (_interpolatedData.isEmpty) {
      _heatmapPointsCache = [];
      return;
    }
    _heatmapPointsCache = _interpolatedData.map((d) => HeatmapPoint(
      latitude: (d['lat'] as num).toDouble(),
      longitude: (d['lon'] as num).toDouble(),
      value: (d['value'] as num).toDouble(),
    )).toList();
  }

  /// Animasyon motoru tarafından doğrudan çağrılır (standard harita).
  /// [pts] listesi: her eleman [lat, lon, rawValue] triple'ı.
  /// Değerler [min, max] aralığına göre 0–1'e normalize edilir.
  void setAnimFrameData(
    List<dynamic> pts,
    MapLayerType layerType,
    double metricMin,
    double metricMax,
  ) {
    final range = metricMax - metricMin;
    _interpolatedData = pts.map((pt) {
      final lat = (pt[0] as num).toDouble();
      final lon = (pt[1] as num).toDouble();
      final raw = (pt[2] as num).toDouble();
      final normalized = range > 0 ? ((raw - metricMin) / range).clamp(0.0, 1.0) : 0.5;
      return <String, dynamic>{'lat': lat, 'lon': lon, 'value': normalized};
    }).toList();
    _currentLayer = layerType;
    _rebuildHeatmapCache();
    // notifyListeners() caller'ın sorumluluğunda (safeNotify ile çağrılır)
  }

  void setLayer(MapLayerType layer) {
    if (_currentLayer == layer) return;
    _currentLayer = layer;
    fetchHeatmapDataForLayer(layer);
    safeNotify();
  }

  void changeMapLayer() {
    switch (_currentLayer) {
      case MapLayerType.none:
        setLayer(MapLayerType.wind);
        break;
      case MapLayerType.wind:
        setLayer(MapLayerType.temp);
        break;
      case MapLayerType.temp:
        setLayer(MapLayerType.irradiance);
        break;
      case MapLayerType.irradiance:
        setLayer(MapLayerType.none);
        break;
    }
  }

  Future<void> fetchHeatmapDataForLayer(MapLayerType layer, {bool forceRefresh = false}) async {
    if (layer == MapLayerType.none) {
      _interpolatedData = [];
      _rebuildHeatmapCache();
      safeNotify();
      return;
    }

    // Önbellek kontrolü: 5 dakika içinde yüklendiyse API'ye gitme
    final cached = _layerDataCache[layer];
    final cacheTime = _layerCacheTime[layer];
    final cacheValid = cached != null &&
        cacheTime != null &&
        DateTime.now().difference(cacheTime) < _layerCacheTtl;

    if (!forceRefresh && cacheValid) {
      _interpolatedData = cached;
      _rebuildHeatmapCache();
      safeNotify();
      return;
    }

    // Mevcut veriyi koruyoruz (User Experience)
    _isHeatmapLoading = true;
    safeNotify();

    try {
      final apiType = layer.apiName;
      if (apiType != null) {
        final data = await apiService.report.fetchInterpolatedMap(apiType);
        _interpolatedData = data;
        // Önbelleğe kaydet
        _layerDataCache[layer] = data;
        _layerCacheTime[layer] = DateTime.now();
        _rebuildHeatmapCache();
      }
    } catch (e) {
      debugPrint('Heatmap loading error: $e');
    } finally {
      _isHeatmapLoading = false;
      safeNotify();
    }
  }

  // ─── Rüzgar Parçacık Katmanı Metodları ──────────────────────────────────

  Future<void> loadWindPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt(_qualityKey);
      if (idx != null && idx < WindParticleQuality.values.length) {
        _windQuality = WindParticleQuality.values[idx];
      }
    } catch (e) {
      debugPrint('Wind preferences load error: $e');
    }
  }

  Future<void> toggleWindParticles(bool val) async {
    _showWindParticles = val;
    if (val && _windVectors.isEmpty) {
      await _fetchWindVectors();
    } else {
      safeNotify();
    }
  }

  void toggleElevation(bool val) {
    _showElevation = val;
    safeNotify();
  }

  Future<void> setWindQuality(WindParticleQuality q) async {
    _windQuality = q;
    safeNotify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_qualityKey, q.index);
    } catch (e) {
      debugPrint('Wind quality save error: $e');
    }
  }

  /// MapLibre rüzgar okları için de kullanılır.
  Future<void> loadWindVectors() => _fetchWindVectors();

  Future<void> _fetchWindVectors() async {
    _isWindLoading = true;
    _windDataEmpty = false;
    safeNotify();
    try {
      final data = await apiService.windVector.fetchWindVectors();
      _windVectors = data.map((d) => WindVector.fromJson(d)).toList();
      _windDataEmpty = _windVectors.isEmpty;
    } catch (e) {
      debugPrint('Wind vectors fetch error: $e');
      _windDataEmpty = true;
    } finally {
      _isWindLoading = false;
      notifyListeners();
    }
  }

  // ─── Choropleth (İlçe Tematik Harita) Katmanı ────────────────────────────

  ChoroplethMode _choroplethMode = ChoroplethMode.none;
  Map<String, dynamic>? _choroplethData; // {"il|ilçe": {wind, solar, temp}}
  DateTime? _choroplethCacheTime;
  bool _isChoroplethLoading = false;
  static const Duration _choroplethCacheTtl = Duration(minutes: 10);

  ChoroplethMode get choroplethMode => _choroplethMode;
  bool get isChoroplethLoading => _isChoroplethLoading;
  Map<String, dynamic>? get choroplethData => _choroplethData;

  /// Choropleth verisinin hangi zamana ait olduğu (backend'den gelen _meta bilgisi).
  String? get choroplethDataTimestamp {
    final meta = _choroplethData?['_meta'];
    if (meta is Map) {
      return meta['data_timestamp'] as String?;
    }
    return null;
  }

  // ─── Choropleth Tooltip (tıklanan ilçe verisi) ──────────────────────────
  String? _choroplethTapDistrict;   // "İstanbul / Kadıköy"
  Map<String, dynamic>? _choroplethTapData; // {wind, solar, temp}
  Color? _choroplethTapColor;       // Haritadaki dolgu rengi

  String? get choroplethTapDistrict => _choroplethTapDistrict;
  Map<String, dynamic>? get choroplethTapData => _choroplethTapData;
  Color? get choroplethTapColor => _choroplethTapColor;

  /// Haritada bir ilçeye tıklandığında choropleth verisini tooltip olarak gösterir.
  void setChoroplethTap(String province, String district) {
    if (_choroplethMode == ChoroplethMode.none || _choroplethData == null) return;
    final key = '$province|$district';
    final entry = _choroplethData![key];
    if (entry is Map<String, dynamic>) {
      _choroplethTapDistrict = '$province / $district';
      _choroplethTapData = entry;
      _choroplethTapColor = _computeChoroplethColor(
        _choroplethMode, entry, _choroplethData!,
      );
    } else {
      _choroplethTapDistrict = '$province / $district';
      _choroplethTapData = null;
      _choroplethTapColor = null;
    }
    safeNotify();
  }

  /// Tooltip'i kapat.
  void clearChoroplethTap() {
    if (_choroplethTapDistrict == null) return;
    _choroplethTapDistrict = null;
    _choroplethTapData = null;
    _choroplethTapColor = null;
    safeNotify();
  }

  /// Choropleth verisi ve mod bazında hex rengi hesaplar (haritadaki dolgu ile aynı).
  static Color? _computeChoroplethColor(
    ChoroplethMode mode,
    Map<String, dynamic> entry,
    Map<String, dynamic> allData,
  ) {
    final dataKey = mode.dataKey;
    final value = (entry[dataKey] as num?)?.toDouble();
    if (value == null || value == 0.0) return null;

    // ── Sabit fiziksel skala — haritayla birebir aynı ──────────
    List<List<dynamic>> physicalRamp;
    if (dataKey == 'solar') {
      physicalRamp = [
        [0,0x1a1a2e],[50,0xFFFFCC],[150,0xFFEDA0],[250,0xFED976],
        [350,0xFEB24C],[450,0xFD8D3C],[550,0xFC4E2A],[650,0xE31A1C],
        [750,0xBD0026],[800,0x4D0014]];
    } else if (dataKey == 'wind') {
      physicalRamp = [
        [0,0xF7FBFF],[2,0xDEEBF7],[4,0xC6DBEF],[6,0x9ECAE1],
        [8,0x6BAED6],[10,0x4292C6],[13,0x2171B5],[16,0x08519C],
        [20,0x083D7F],[25,0x08306B]];
    } else {
      physicalRamp = [
        [-15,0x08306B],[-5,0x2171B5],[0,0xE0F3F8],[5,0xC6DBEF],
        [10,0xABD9E9],[15,0x74ADD1],[20,0x66BD63],[25,0xA6D96A],
        [30,0xFEE08B],[33,0xFDAE61],[36,0xF46D43],[40,0xD73027],
        [45,0xA50026]];
    }

    final physMin = (physicalRamp.first[0] as num).toDouble();
    final physMax = (physicalRamp.last[0] as num).toDouble();
    final physRange = physMax - physMin;

    final List<List<dynamic>> ramp = [];
    for (final stop in physicalRamp) {
      final v = (stop[0] as num).toDouble();
      ramp.add([(v - physMin) / physRange, stop[1]]);
    }
    final t = ((value - physMin) / physRange).clamp(0.0, 1.0);

    // En yakın stop bul
    int colorHex = ramp.last[1] as int;
    for (int i = 0; i < ramp.length - 1; i++) {
      final t0 = ramp[i][0] as double;
      final t1 = ramp[i + 1][0] as double;
      if (t >= t0 && t <= t1) {
        colorHex = (t - t0 <= t1 - t) ? ramp[i][1] as int : ramp[i + 1][1] as int;
        break;
      }
    }

    return Color(0xFF000000 | colorHex);
  }

  /// Mevcut choropleth modunu cache'i sıfırlayarak yeniden yükler.
  Future<void> forceRefreshChoropleth() async {
    if (_choroplethMode == ChoroplethMode.none) return;
    _choroplethCacheTime = null;
    final prev = _choroplethMode;
    _choroplethMode = ChoroplethMode.none;
    await setChoroplethMode(prev);
  }

  Future<void> setChoroplethMode(ChoroplethMode mode) async {
    if (_choroplethMode == mode) return;
    _choroplethMode = mode;
    // Mod değiştiğinde tooltip'i temizle
    _choroplethTapDistrict = null;
    _choroplethTapData = null;
    safeNotify();

    if (mode == ChoroplethMode.none) return;

    // Veri yüklenmemişse veya cache süresi dolmuşsa fetch et
    final cacheValid = _choroplethData != null &&
        _choroplethCacheTime != null &&
        DateTime.now().difference(_choroplethCacheTime!) < _choroplethCacheTtl;

    if (!cacheValid) {
      await _fetchChoroplethData();
    }
  }

  Future<void> _fetchChoroplethData() async {
    _isChoroplethLoading = true;
    safeNotify();
    try {
      // En güncel saatin verilerini al — anlık sıcaklık/rüzgar doğruluğu.
      // Solar gece=0 sorunu backend daylight fallback ile çözülüyor.
      final data = await apiService.weather.fetchDistrictChoropleth(
        mode: 'latest',
      );
      if (data.isNotEmpty) {
        _choroplethData = data;
        _choroplethCacheTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('[Choropleth] Veri yüklenemedi: $e');
    } finally {
      _isChoroplethLoading = false;
      safeNotify();
    }
  }
}

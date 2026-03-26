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
      try {
        notifyListeners();
      } catch (_) {}
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
      // await sonrası pointer event bağlamından çıkıldı, doğrudan bildirim güvenli
      notifyListeners();
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
      if (_windDataEmpty) {
        debugPrint('[Wind] Backend boş veri döndü — veritabanında rüzgar verisi yok.');
      } else {
        debugPrint('[Wind] ${_windVectors.length} rüzgar vektörü yüklendi.');
      }
    } catch (e) {
      debugPrint('Wind vectors fetch error: $e');
      _windDataEmpty = true;
    } finally {
      _isWindLoading = false;
      notifyListeners();
    }
  }
}

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

  /// notifyListeners() çağrısını mevcut frame sonrasına erteler.
  /// Pointer event (tap/hover) işlenirken çağrılan state değişikliklerinde
  /// widget tree mutasyonunu önler — mouse_tracker re-entrant assertion fix.
  void safeNotify() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // ChangeNotifier dispose edildiyse çağırma
      try {
        notifyListeners();
      } catch (_) {}
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  MapLayerType _currentLayer = MapLayerType.none;
  List<Map<String, dynamic>> _interpolatedData = [];
  bool _isHeatmapLoading = false;

  // ─── Rüzgar Parçacık + Yükseklik Katmanı State ──────────────────────────
  bool _showWindParticles = false;
  bool _isWindLoading = false;
  bool _showElevation = false;
  WindParticleQuality _windQuality = WindParticleQuality.balanced;
  List<WindVector> _windVectors = [];

  static const _qualityKey = 'wind_particle_quality';

  bool get showWindParticles => _showWindParticles;
  bool get isWindLoading => _isWindLoading;
  bool get showElevation => _showElevation;
  WindParticleQuality get windQuality => _windQuality;
  List<WindVector> get windVectors => _windVectors;
  // ──────────────────────────────────────────────────────────────────────────

  MapLayerType get currentLayer => _currentLayer;
  bool get isHeatmapLoading => _isHeatmapLoading;

  // --- HEATMAP İÇİN VERİ DÖNÜŞÜMÜ ---
  List<HeatmapPoint> get heatmapPoints {
    if (_interpolatedData.isNotEmpty) {
       return _interpolatedData.map((d) => HeatmapPoint(
         latitude: d['lat'],
         longitude: d['lon'],
         value: d['value'],
       )).toList();
    }
    return [];
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

  Future<void> fetchHeatmapDataForLayer(MapLayerType layer) async {
    if (layer == MapLayerType.none) {
      _interpolatedData = [];
      safeNotify();
      return;
    }

    // Mevcut veriyi koruyoruz (User Experience)
    _isHeatmapLoading = true;
    safeNotify();

    try {
      final apiType = layer.apiName;
      if (apiType != null) {
        _interpolatedData = await apiService.report.fetchInterpolatedMap(apiType);
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

  Future<void> _fetchWindVectors() async {
    _isWindLoading = true;
    safeNotify();
    try {
      final data = await apiService.windVector.fetchWindVectors();
      _windVectors = data.map((d) => WindVector.fromJson(d)).toList();
    } catch (e) {
      debugPrint('Wind vectors fetch error: $e');
    } finally {
      _isWindLoading = false;
      // await sonrası pointer event bağlamından çıkıldı, doğrudan bildirim güvenli
      notifyListeners();
    }
  }
}

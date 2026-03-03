import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/features/map/layers/map_layers_system.dart';

mixin MapLayerMixin on BaseViewModel {
  // Abstract dependency
  ApiService get apiService;

  MapLayerType _currentLayer = MapLayerType.none;
  List<Map<String, dynamic>> _interpolatedData = [];
  bool _isHeatmapLoading = false;

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
    notifyListeners();
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
      notifyListeners();
      return;
    }

    // Mevcut veriyi koruyoruz (User Experience)
    _isHeatmapLoading = true;
    notifyListeners();

    try {
      final apiType = layer.apiName;
      if (apiType != null) {
        _interpolatedData = await apiService.report.fetchInterpolatedMap(apiType);
      }
    } catch (e) {
      debugPrint('Heatmap loading error: $e');
    } finally {
      _isHeatmapLoading = false;
      notifyListeners();
    }
  }
}

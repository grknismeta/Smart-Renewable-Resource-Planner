import 'package:flutter/material.dart';
import '../../../core/api_service.dart';
import '../../../core/base/base_view_model.dart';
import '../../widgets/map/resource_heatmap_layer.dart';

enum MapLayer { none, wind, temp, irradiance }

mixin MapLayerMixin on BaseViewModel {
  // Abstract dependency
  ApiService get apiService;

  MapLayer _currentLayer = MapLayer.none;
  List<Map<String, dynamic>> _interpolatedData = [];
  bool _isHeatmapLoading = false;

  MapLayer get currentLayer => _currentLayer;
  bool get isHeatmapLoading => _isHeatmapLoading;

  // --- HEATMAP İÇİN VERİ DÖNÜŞÜMÜ ---
  List<HeatmapPoint> get heatmapPoints {
    // Tüm katmanlar artık _interpolatedData kullanıyor (Tek kaynak)
    if (_interpolatedData.isNotEmpty) {
       return _interpolatedData.map((d) => HeatmapPoint(
         latitude: d['lat'],
         longitude: d['lon'],
         value: d['value'],
       )).toList();
    }
    return [];
  }

  // --- HEATMAP TİPİ DÖNÜŞÜMÜ ---
  ResourceType get heatmapType {
    switch (_currentLayer) {
      case MapLayer.wind:
        return ResourceType.wind;
      case MapLayer.temp:
        return ResourceType.temp;
      case MapLayer.irradiance:
        return ResourceType.solar;
      default:
        return ResourceType.temp; // Fallback
    }
  }

  void setLayer(MapLayer layer) {
    _currentLayer = layer;
    fetchHeatmapDataForLayer(layer);
    notifyListeners();
  }

  void changeMapLayer() {
    switch (_currentLayer) {
      case MapLayer.none:
        setLayer(MapLayer.wind);
        break;
      case MapLayer.wind:
        setLayer(MapLayer.temp);
        break;
      case MapLayer.temp:
        setLayer(MapLayer.irradiance);
        break;
      case MapLayer.irradiance:
        setLayer(MapLayer.none);
        break;
    }
  }

  Future<void> fetchHeatmapDataForLayer(MapLayer layer) async {
    if (layer == MapLayer.none) return;

    // _interpolatedData = []; // ESKİ: Veriyi silmiyoruz, kullanıcı deneyimi için koruyoruz.
    _isHeatmapLoading = true;
    notifyListeners();

    try {
      final apiType = _getApiTypeForLayer(layer);
      if (apiType != null) {
        _interpolatedData = await apiService.fetchInterpolatedMap(apiType);
      }
    } catch (e) {
      debugPrint('Heatmap loading error: $e');
    } finally {
      _isHeatmapLoading = false;
      notifyListeners();
    }
  }

  /// MapLayer'ı API tarafındaki string parametresine dönüştürür
  String? _getApiTypeForLayer(MapLayer layer) {
    switch (layer) {
      case MapLayer.wind:
        return "Wind";
      case MapLayer.irradiance:
        return "Solar";
      case MapLayer.temp:
        return "Temperature";
      case MapLayer.none:
        return null;
    }
  }
}

// lib/providers/map_provider.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/core/api_service.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'auth_provider.dart';

enum MapLayer { none, wind, temp }

// --- 1. GÜNCELLEME: Pin ekleme modunu String olarak tanımla ---
// 'isPlacingMarker' boolean'ı yerine, ne eklediğimizi tutan bir String kullanıyoruz.
// null = pin ekleme modu kapalı.
typedef PinType = String;

class MapProvider extends ChangeNotifier {
  final ApiService _apiService;
  final AuthProvider _authProvider;

  List<Pin> _pins = [];
  bool _isLoading = false;
  // bool _isPlacingMarker = false; // <-- ESKİ
  PinType? _placingPinType; // <-- YENİ
  MapLayer _currentLayer = MapLayer.none;
  PinCalculationResponse? _latestCalculationResult;

  List<Pin> get pins => _pins;
  bool get isLoading => _isLoading;
  // bool get isPlacingMarker => _isPlacingMarker; // <-- ESKİ
  PinType? get placingPinType => _placingPinType; // <-- YENİ
  MapLayer get currentLayer => _currentLayer;
  PinCalculationResponse? get latestCalculationResult =>
      _latestCalculationResult;

  MapProvider(this._apiService, this._authProvider) {
    _authProvider.addListener(_handleAuthChange);
  }

  void _handleAuthChange() {
    // ... (değişiklik yok) ...
    if (_authProvider.isLoggedIn == true) {
      fetchPins();
    } else if (_authProvider.isLoggedIn == false) {
      _pins = [];
      notifyListeners();
    }
  }

  // --- UI İşlemleri ---
  // ... (togglePlacingMarkerMode, changeMapLayer, clearCalculationResult - değişiklik yok) ...
  // --- 2. GÜNCELLEME: 'toggle' yerine iki ayrı fonksiyon ---
  void startPlacingMarker(PinType type) {
    // Eğer zaten o tipte ekleme modundaysa, modu kapat
    if (_placingPinType == type) {
      _placingPinType = null;
    } else {
      _placingPinType = type;
    }
    notifyListeners();
  }

  void stopPlacingMarker() {
    _placingPinType = null;
    notifyListeners();
  }
  // --- GÜNCELLEME SONU ---
    void setLayer(MapLayer layer) {
    _currentLayer = layer;
    notifyListeners();
  }
  void changeMapLayer() {
    switch (_currentLayer) {
      case MapLayer.none:
        _currentLayer = MapLayer.wind;
        break;
      case MapLayer.wind:
        _currentLayer = MapLayer.temp;
        break;
      case MapLayer.temp:
        _currentLayer = MapLayer.none;
        break;
    }
    notifyListeners();
  }

  void clearCalculationResult() {
    _latestCalculationResult = null;
    notifyListeners();
  }

  // --- API İşlemleri ---
  Future<void> fetchPins() async {
    // ... (değişiklik yok) ...
    if (_authProvider.isLoggedIn != true) return;
    _isLoading = true;
    notifyListeners();
    try {
      _pins = await _apiService.fetchPins();
    } catch (e) {
      print('Pin yüklenirken hata: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- 2. GÜNCELLEME: 'addPin' fonksiyonu artık tüm verileri alıyor ---
  Future<void> addPin(
    LatLng point,
    String name,
    String type,
    double capacityMw,
  ) async {
    try {
      // Aldığı parametreleri 'api_service'e iletiyor
      await _apiService.addPin(point, name, type, capacityMw);
      await fetchPins(); // Yeni pini çekmek için listeyi yenile
    } catch (e) {
      print('Pin eklenirken hata: $e');
      throw Exception('Pin eklenemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<void> deletePin(int pinId) async {
    // ... (değişiklik yok) ...
    try {
      await _apiService.deletePin(pinId);
      await fetchPins(); // Silme sonrası listeyi yenile
    } catch (e) {
      print('Pin silinirken hata: $e');
      throw Exception('Pin silinemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<void> calculatePotential({
    // ... (değişiklik yok) ...
    required double lat,
    required double lon,
    required String type,
    required double capacityMw,
    double? panelArea,
  }) async {
    _isLoading = true;
    _latestCalculationResult = null;
    notifyListeners();
    try {
      _latestCalculationResult = await _apiService.calculateEnergyPotential(
        lat: lat,
        lon: lon,
        type: type,
        capacityMw: capacityMw,
        panelArea: panelArea ?? 0.0,
      );
    } catch (e) {
      print('Hesaplama hatası: $e');
      throw Exception('Hesaplama yapılamadı.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// lib/providers/map_provider.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/core/api_service.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'auth_provider.dart';

enum MapLayer { none, wind, temp }

class MapProvider extends ChangeNotifier {
  final ApiService _apiService;
  final AuthProvider _authProvider;

  List<Pin> _pins = [];
  bool _isLoading = false;
  bool _isPlacingMarker = false;
  MapLayer _currentLayer = MapLayer.none;

  // --- DÜZELTME 1: YANLIŞ TİP ---
  // PinResult? _latestCalculationResult;
  // --- DOĞRU TİP ---
  // Backend'den (schemas.py) dönen 'PinCalculationResponse' modelini kullanıyoruz.
  // Bu sınıfı 'pin_model.dart' dosyana eklemen gerekecek.
  PinCalculationResponse? _latestCalculationResult;

  List<Pin> get pins => _pins;
  bool get isLoading => _isLoading;
  bool get isPlacingMarker => _isPlacingMarker;
  MapLayer get currentLayer => _currentLayer;

  // --- DÜZELTME 2: DÖNÜŞ TİPİNİ GÜNCELLE ---
  PinCalculationResponse? get latestCalculationResult =>
      _latestCalculationResult;

  MapProvider(this._apiService, this._authProvider) {
    // AuthProvider'ın giriş durumu değiştiğinde pinleri yenile
    _authProvider.addListener(_handleAuthChange);
  }

  void _handleAuthChange() {
    if (_authProvider.isLoggedIn == true) {
      fetchPins();
    } else if (_authProvider.isLoggedIn == false) {
      _pins = [];
      notifyListeners();
    }
  }

  // --- UI İşlemleri ---
  void togglePlacingMarkerMode() {
    _isPlacingMarker = !_isPlacingMarker;
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
    if (_authProvider.isLoggedIn != true) return;
    _isLoading = true;
    notifyListeners();
    try {
      _pins = await _apiService.fetchPins();
    } catch (e) {
      // Hata yönetimi AuthProvider'a bırakılabilir (logout) veya sadece loglanabilir.
      print('Pin yüklenirken hata: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPin(LatLng point) async {
    try {
      await _apiService.addPin(point);
      await fetchPins(); // Yeni pini çekmek için listeyi yenile
    } catch (e) {
      print('Pin eklenirken hata: $e');
      throw Exception('Pin eklenemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<void> deletePin(int pinId) async {
    try {
      await _apiService.deletePin(pinId);
      await fetchPins(); // Silme sonrası listeyi yenile
    } catch (e) {
      print('Pin silinirken hata: $e');
      throw Exception('Pin silinemedi. Lütfen tekrar deneyin.');
    }
  }

  // Bu fonksiyon artık UI'dan 'panelArea' parametresini alıyor
  Future<void> calculatePotential({
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
      // --- DÜZELTME 3: api_service'in doğru tipi döndürdüğünü varsay ---
      // 'api_service.dart' dosyasındaki 'calculateEnergyPotential'
      // fonksiyonunun da 'Future<PinCalculationResponse>' döndürmesi
      // için güncellenmesi GEREKİR.
      _latestCalculationResult = await _apiService.calculateEnergyPotential(
        lat: lat,
        lon: lon,
        type: type,
        capacityMw: capacityMw,
        // Ve 'panelArea'yı api_service'e iletiyor
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

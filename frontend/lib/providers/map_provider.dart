// lib/providers/map_provider.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/core/api_service.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'auth_provider.dart';
import 'dart:math' as math;

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

  // Hava durumu verileri
  List<CityWeatherData> _weatherData = [];
  DateTime _selectedTime = DateTime.now();

  // --- YENİ: BÖLGE SEÇİM MODUNUN STATE'İ (GÜNCELLENDİ - ÇOKLU KÖŞE) ---
  bool _isSelectingRegion = false; // Seçim modu açık mı?
  List<LatLng> _selectionPoints = []; // Seçilen tüm köşe noktaları
  int? _draggingPointIndex; // Sürüklenen nokta indeksi
  OptimizationResponse? _optimizationResult; // Optimizasyon sonuçları
  List<Equipment> _equipments = [];
  bool _equipmentsLoading = false;

  List<Pin> get pins => _pins;
  bool get isLoading => _isLoading;
  // bool get isPlacingMarker => _isPlacingMarker; // <-- ESKİ
  PinType? get placingPinType => _placingPinType; // <-- YENİ
  MapLayer get currentLayer => _currentLayer;
  PinCalculationResponse? get latestCalculationResult =>
      _latestCalculationResult;
  List<CityWeatherData> get weatherData => _weatherData;
  DateTime get selectedTime => _selectedTime;

  // --- YENİ: GETTERS (GÜNCELLENDİ) ---
  bool get isSelectingRegion => _isSelectingRegion;
  List<LatLng> get selectionPoints => _selectionPoints;
  int? get draggingPointIndex => _draggingPointIndex;
  OptimizationResponse? get optimizationResult => _optimizationResult;
  bool get hasValidSelection => _selectionPoints.length >= 3; // Min 3 köşe
  List<Equipment> get equipments => _equipments;
  bool get isEquipmentLoading => _equipmentsLoading;

  MapProvider(this._apiService, this._authProvider) {
    _authProvider.addListener(_handleAuthChange);
    // AuthProvider'ın mevcut durumunu kontrol et (constructor'ın çalışması sırasında notifyListeners yapılmayabilir)
    print(
      '[MapProvider constructor] _authProvider.isLoggedIn: ${_authProvider.isLoggedIn}',
    );
    if (_authProvider.isLoggedIn == true) {
      print(
        '[MapProvider constructor] Kullanıcı zaten logged in, pins yükleniyor...',
      );
      fetchPins();
    }
  }

  void _handleAuthChange() {
    // ... (değişiklik yok) ...
    print(
      '[MapProvider._handleAuthChange] isLoggedIn durumu değişti: ${_authProvider.isLoggedIn}',
    );
    if (_authProvider.isLoggedIn == true) {
      print(
        '[MapProvider._handleAuthChange] Kullanıcı giriş yaptı, fetchPins çağrılıyor...',
      );
      fetchPins();
    } else if (_authProvider.isLoggedIn == false) {
      print(
        '[MapProvider._handleAuthChange] Kullanıcı çıkış yaptı, pins sıfırlanıyor',
      );
      _pins = [];
      notifyListeners();
    }
  }

  Future<void> loadEquipments({String? type, bool forceRefresh = false}) async {
    print(
      '[MapProvider.loadEquipments] Çağrıldı: type=$type, forceRefresh=$forceRefresh',
    );
    if (_equipmentsLoading) {
      print('[MapProvider.loadEquipments] Zaten yükleniyor, atlanıyor');
      return;
    }
    if (!forceRefresh && _equipments.isNotEmpty && type == null) {
      print(
        '[MapProvider.loadEquipments] Zaten yüklü, atlanıyor: ${_equipments.length} ekipman',
      );
      return;
    }

    _equipmentsLoading = true;
    notifyListeners();
    print('[MapProvider.loadEquipments] Loading başladı...');
    try {
      _equipments = await _apiService.fetchEquipments(type: type);
      print(
        '[MapProvider.loadEquipments] Başarılı: ${_equipments.length} ekipman yüklendi',
      );
    } catch (e) {
      print('[MapProvider.loadEquipments] Hata: $e');
    } finally {
      _equipmentsLoading = false;
      notifyListeners();
      print('[MapProvider.loadEquipments] Loading bitti');
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

  // --- YENİ: BÖLGE SEÇİM METODLARI ---
  /// Optimizasyon bölge seçim modunu başlat
  void startSelectingRegion() {
    _isSelectingRegion = true;
    _selectionPoints = [];
    _draggingPointIndex = null;
    _optimizationResult = null;
    notifyListeners();
  }

  /// Harita üstüne tıklama işlemi (Bölge seçim modunda) - Nokta ekle
  void recordSelectionPoint(LatLng point) {
    if (!_isSelectingRegion) return;
    _selectionPoints.add(point);
    notifyListeners();
  }

  /// Seçilen noktaları temizle
  void clearRegionSelection() {
    _isSelectingRegion = false;
    _selectionPoints = [];
    _draggingPointIndex = null;
    _optimizationResult = null;
    notifyListeners();
  }

  /// Son eklenen noktayı sil
  void removeLastPoint() {
    if (_selectionPoints.isNotEmpty) {
      _selectionPoints.removeLast();
      notifyListeners();
    }
  }

  /// Seçimi bitir (hesaplamaya hazır)
  void finishRegionSelection() {
    if (_selectionPoints.length >= 3) {
      _isSelectingRegion = false;
      notifyListeners();
    }
  }

  /// Nokta sürüklemeye başla
  void startDraggingPoint(int index) {
    if (index >= 0 && index < _selectionPoints.length) {
      _draggingPointIndex = index;
      notifyListeners();
    }
  }

  /// Noktayı sürükle
  void dragPoint(LatLng newPosition) {
    if (_draggingPointIndex != null &&
        _draggingPointIndex! >= 0 &&
        _draggingPointIndex! < _selectionPoints.length) {
      _selectionPoints[_draggingPointIndex!] = newPosition;
      notifyListeners();
    }
  }

  /// Nokta sürüklemeyi bitir
  void endDraggingPoint() {
    _draggingPointIndex = null;
    notifyListeners();
  }

  /// Belirli bir indeksteki noktayı kaldır
  void removePointAt(int index) {
    if (index >= 0 && index < _selectionPoints.length) {
      _selectionPoints.removeAt(index);
      if (_draggingPointIndex == index) {
        _draggingPointIndex = null;
      }
      notifyListeners();
    }
  }

  /// Seçilen bölge için optimizasyon hesaplaması yap
  Future<void> calculateOptimization({
    required int equipmentId,
    double minDistanceM = 0.0,
  }) async {
    if (_selectionPoints.length < 3) {
      throw Exception('Lütfen en az 3 köşe seçin.');
    }

    _isLoading = true;
    _optimizationResult = null;
    notifyListeners();

    try {
      // Minimum sınırlayıcı kutu (bounding box) hesapla
      double minLat = _selectionPoints.first.latitude;
      double maxLat = _selectionPoints.first.latitude;
      double minLon = _selectionPoints.first.longitude;
      double maxLon = _selectionPoints.first.longitude;

      for (final point in _selectionPoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLon = math.min(minLon, point.longitude);
        maxLon = math.max(maxLon, point.longitude);
      }

      _optimizationResult = await _apiService.optimizeWindPlacement(
        topLeftLat: maxLat,
        topLeftLon: minLon,
        bottomRightLat: minLat,
        bottomRightLon: maxLon,
        equipmentId: equipmentId,
        minDistanceM: minDistanceM,
      );
    } catch (e) {
      print('Optimizasyon hatası: $e');
      throw Exception('Optimizasyon hesaplaması başarısız oldu.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    print(
      '[MapProvider] fetchPins() çağrıldı, isLoggedIn: ${_authProvider.isLoggedIn}',
    );
    if (_authProvider.isLoggedIn != true) {
      print('[MapProvider] isLoggedIn != true, fetchPins iptal edildi');
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _pins = await _apiService.fetchPins();
      print('[MapProvider] fetchPins başarılı, ${_pins.length} pin yüklendi');
    } catch (e) {
      print('[MapProvider] Pin yüklenirken hata: $e');
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
    int? equipmentId, // Ekipman ID'si eklendi
  ) async {
    try {
      // Aldığı parametreleri 'api_service'e iletiyor
      await _apiService.addPin(point, name, type, capacityMw, equipmentId);
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

  // --- Hava Durumu İşlemleri ---

  /// Belirli bir zaman için hava durumu verilerini yükle
  Future<void> loadWeatherForTime(DateTime time) async {
    _selectedTime = time;
    try {
      _weatherData = await _apiService.fetchWeatherForTime(time);
    } catch (e) {
      print('Hava durumu yüklenirken hata: $e');
    }
    notifyListeners();
  }

  /// En yakın şehri bul (mouse hover için)
  CityWeatherData? findNearestCity(LatLng position) {
    if (_weatherData.isEmpty) return null;

    CityWeatherData? nearest;
    double minDistance = double.infinity;

    for (final city in _weatherData) {
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        city.lat,
        city.lon,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = city;
      }
    }

    // 100km'den uzaksa null döndür
    if (minDistance > 100) return null;
    return nearest;
  }

  /// İki nokta arası mesafe (km)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Dünya yarıçapı (km)
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180;
}

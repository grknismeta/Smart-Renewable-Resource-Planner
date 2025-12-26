// lib/providers/map_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/core/api_service.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/data/models/irradiance_model.dart';
import 'auth_provider.dart';
import 'dart:math' as math;

enum MapLayer { none, wind, temp, irradiance }

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
  // 7 günlük özet ve şehir serileri için durum
  List<CityWeatherSummary> _weatherSummary = [];
  List<CityWeatherData> _cityHourly = [];
  String? _cityHourlyName;

  // Işınım verileri
  List<IrradianceData> _irradianceData = [];
  List<CitySolarSummary> _solarSummary = [];
  String? _selectedCityForIrradiance;
  bool _isLoadingIrradiance = false;

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
  List<CityWeatherSummary> get weatherSummary => _weatherSummary;
  List<CityWeatherData> get cityHourly => _cityHourly;
  String? get cityHourlyName => _cityHourlyName;

  // Işınım verileri getters
  List<IrradianceData> get irradianceData => _irradianceData;
  List<CitySolarSummary> get solarSummary => _solarSummary;
  String? get selectedCityForIrradiance => _selectedCityForIrradiance;
  bool get isLoadingIrradiance => _isLoadingIrradiance;

  // --- YENİ: GETTERS (GÜNCELLENDİ) ---
  bool get isSelectingRegion => _isSelectingRegion;
  List<LatLng> get selectionPoints => _selectionPoints;
  int? get draggingPointIndex => _draggingPointIndex;
  OptimizationResponse? get optimizationResult => _optimizationResult;
  bool get hasValidSelection => _selectionPoints.length >= 3; // Min 3 köşe
  List<Equipment> get equipments => _equipments;
  bool get isEquipmentLoading => _equipmentsLoading;
  bool get equipmentsLoading => _equipmentsLoading;

  MapProvider(this._apiService, this._authProvider) {
    _authProvider.addListener(_handleAuthChange);
    // AuthProvider'ın mevcut durumunu kontrol et (constructor'ın çalışması sırasında notifyListeners yapılmayabilir)
    debugPrint(
      '[MapProvider constructor] _authProvider.isLoggedIn: ${_authProvider.isLoggedIn}',
    );
    if (_authProvider.isLoggedIn == true) {
      debugPrint(
        '[MapProvider constructor] Kullanıcı zaten logged in, pins yükleniyor...',
      );
      fetchPins();
    }
    // Ülke genelinde özet (7 gün) ön yükleme
    _loadWeatherSummarySafe();
  }

  Future<void> _loadWeatherSummarySafe() async {
    try {
      _weatherSummary = await _apiService.fetchWeatherSummary(hours: 168);
      // Işınım verilerini de yükle
      _solarSummary = await _apiService.fetchSolarSummary(hours: 168);
      notifyListeners();
    } catch (e) {
      debugPrint('Weather/Solar summary yüklenirken hata: $e');
    }
  }

  void _handleAuthChange() {
    // ... (değişiklik yok) ...
    debugPrint(
      '[MapProvider._handleAuthChange] isLoggedIn durumu değişti: ${_authProvider.isLoggedIn}',
    );
    if (_authProvider.isLoggedIn == true) {
      debugPrint(
        '[MapProvider._handleAuthChange] Kullanıcı giriş yaptı, fetchPins çağrılıyor...',
      );
      fetchPins();
    } else if (_authProvider.isLoggedIn == false) {
      debugPrint(
        '[MapProvider._handleAuthChange] Kullanıcı çıkış yaptı, pins sıfırlanıyor',
      );
      _pins = [];
      notifyListeners();
    }
  }

  Future<void> loadEquipments({String? type, bool forceRefresh = false}) async {
    debugPrint(
      '[MapProvider.loadEquipments] Çağrıldı: type=$type, forceRefresh=$forceRefresh',
    );
    if (_equipmentsLoading) {
      debugPrint('[MapProvider.loadEquipments] Zaten yükleniyor, atlanıyor');
      return;
    }
    if (!forceRefresh && _equipments.isNotEmpty && type == null) {
      debugPrint(
        '[MapProvider.loadEquipments] Zaten yüklü, atlanıyor: ${_equipments.length} ekipman',
      );
      return;
    }

    _equipmentsLoading = true;
    notifyListeners();
    debugPrint('[MapProvider.loadEquipments] Loading başladı...');
    try {
      _equipments = await _apiService.fetchEquipments(type: type);
      debugPrint(
        '[MapProvider.loadEquipments] Başarılı: ${_equipments.length} ekipman yüklendi',
      );
    } catch (e) {
      debugPrint('[MapProvider.loadEquipments] Hata: $e');
    } finally {
      _equipmentsLoading = false;
      notifyListeners();
      debugPrint('[MapProvider.loadEquipments] Loading bitti');
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
      debugPrint('Optimizasyon hatası: $e');
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
        _currentLayer = MapLayer.irradiance;
        break;
      case MapLayer.irradiance:
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
    debugPrint(
      '[MapProvider] fetchPins() çağrıldı, isLoggedIn: ${_authProvider.isLoggedIn}',
    );
    if (_authProvider.isLoggedIn != true) {
      debugPrint('[MapProvider] isLoggedIn != true, fetchPins iptal edildi');
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _pins = await _apiService.fetchPins();
      debugPrint(
        '[MapProvider] fetchPins başarılı, ${_pins.length} pin yüklendi',
      );
    } catch (e) {
      debugPrint('[MapProvider] Pin yüklenirken hata: $e');
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
      debugPrint('Pin eklenirken hata: $e');
      throw Exception('Pin eklenemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<void> deletePin(int pinId) async {
    // ... (değişiklik yok) ...
    try {
      await _apiService.deletePin(pinId);
      await fetchPins(); // Silme sonrası listeyi yenile
    } catch (e) {
      debugPrint('Pin silinirken hata: $e');
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
      debugPrint('Hesaplama hatası: $e');
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
      debugPrint('Hava durumu yüklenirken hata: $e');
    }
    notifyListeners();
  }

  /// Belirli bir şehir için 7 günlük saatlik verileri yükle
  Future<void> loadCityWeekly(String cityName) async {
    try {
      _cityHourlyName = cityName;
      _cityHourly = await _apiService.fetchCityHourly(cityName, hours: 168);
    } catch (e) {
      _cityHourly = [];
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

  double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  // --- Işınım Veri İşlemleri ---

  /// Belirli bir şehir için ışınım verilerini yükle
  Future<void> loadCityIrradiance(String cityName, {int hours = 168}) async {
    _isLoadingIrradiance = true;
    _selectedCityForIrradiance = cityName;
    notifyListeners();

    try {
      debugPrint('[MapProvider.loadCityIrradiance] Yükleniyor: $cityName');
      _irradianceData = await _apiService.fetchCityIrradiance(
        cityName,
        hours: hours,
      );
      debugPrint(
        '[MapProvider.loadCityIrradiance] ${_irradianceData.length} kayıt yüklendi',
      );
    } catch (e) {
      debugPrint('[MapProvider.loadCityIrradiance] Hata: $e');
      _irradianceData = [];
    } finally {
      _isLoadingIrradiance = false;
      notifyListeners();
    }
  }

  /// Tüm şehirler için güneş ışınım özet verilerini yükle
  Future<void> loadSolarSummary({int hours = 168}) async {
    _isLoadingIrradiance = true;
    notifyListeners();

    try {
      debugPrint('[MapProvider.loadSolarSummary] Yükleniyor...');
      _solarSummary = await _apiService.fetchSolarSummary(hours: hours);
      debugPrint(
        '[MapProvider.loadSolarSummary] ${_solarSummary.length} şehir yüklendi',
      );
    } catch (e) {
      debugPrint('[MapProvider.loadSolarSummary] Hata: $e');
      _solarSummary = [];
    } finally {
      _isLoadingIrradiance = false;
      notifyListeners();
    }
  }

  /// En iyi güneş potansiyeline sahip şehirleri yükle
  Future<List<Map<String, dynamic>>> loadBestSolarCities({
    int limit = 10,
  }) async {
    try {
      debugPrint('[MapProvider.loadBestSolarCities] Yükleniyor...');
      final cities = await _apiService.fetchBestSolarCities(limit: limit);
      debugPrint(
        '[MapProvider.loadBestSolarCities] ${cities.length} şehir yüklendi',
      );
      return cities;
    } catch (e) {
      debugPrint('[MapProvider.loadBestSolarCities] Hata: $e');
      return [];
    }
  }

  /// Seçili şehir için günlük ortalama ışınım (kWh/m²)
  double? get averageDailyIrradiance {
    if (_irradianceData.isEmpty) return null;

    final validData = _irradianceData
        .where((d) => d.shortwaveRadiation != null)
        .toList();

    if (validData.isEmpty) return null;

    final sum = validData.fold<double>(
      0.0,
      (prev, curr) => prev + (curr.shortwaveRadiation! / 1000.0),
    );

    return sum / validData.length;
  }

  /// Seçili şehir için toplam ışınım (kWh/m²)
  double? get totalIrradiance {
    if (_irradianceData.isEmpty) return null;

    return _irradianceData
        .where((d) => d.shortwaveRadiation != null)
        .fold<double>(
          0.0,
          (prev, curr) => prev + (curr.shortwaveRadiation! / 1000.0),
        );
  }

  /// Işınım verilerini temizle
  void clearIrradianceData() {
    _irradianceData = [];
    _selectedCityForIrradiance = null;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../../core/api_service.dart';
import '../../core/base/base_view_model.dart';
import '../../data/models/pin_model.dart';
import '../../data/models/system_data_models.dart';
import '../../data/models/irradiance_model.dart';
import 'auth_view_model.dart';

enum MapLayer { none, wind, temp, irradiance }

// Pin ekleme modunu String olarak tanımla
typedef PinType = String;

class MapViewModel extends BaseViewModel {
  final ApiService _apiService;
  final AuthViewModel _authViewModel;

  List<Pin> _pins = [];
  PinType? _placingPinType;
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

  // BÖLGE SEÇİM MODUNUN STATE'İ
  bool _isSelectingRegion = false; // Seçim modu açık mı?
  List<LatLng> _selectionPoints = []; // Seçilen tüm köşe noktaları
  int? _draggingPointIndex; // Sürüklenen nokta indeksi
  OptimizationResponse? _optimizationResult; // Optimizasyon sonuçları
  List<Equipment> _equipments = [];
  bool _equipmentsLoading = false;

  List<Pin> get pins => _pins;
  PinType? get placingPinType => _placingPinType;
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

  // GETTERS
  bool get isSelectingRegion => _isSelectingRegion;
  List<LatLng> get selectionPoints => _selectionPoints;
  int? get draggingPointIndex => _draggingPointIndex;
  OptimizationResponse? get optimizationResult => _optimizationResult;
  bool get hasValidSelection => _selectionPoints.length >= 3; // Min 3 köşe
  List<Equipment> get equipments => _equipments;
  bool get isEquipmentLoading => _equipmentsLoading;
  bool get equipmentsLoading => _equipmentsLoading;

  MapViewModel(this._apiService, this._authViewModel) {
    _authViewModel.addListener(_handleAuthChange);
    // AuthViewModel'in mevcut durumunu kontrol et
    if (_authViewModel.isLoggedIn == true) {
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

  /// Veri yükleme hatası durumunda tekrar denemek için
  Future<void> reloadWeatherSummary() async {
    await _loadWeatherSummarySafe();
  }

  void _handleAuthChange() {
    if (_authViewModel.isLoggedIn == true) {
      fetchPins();
    } else if (_authViewModel.isLoggedIn == false) {
      _pins = [];
      notifyListeners();
    }
  }

  Future<void> loadEquipments({String? type, bool forceRefresh = false}) async {
    if (_equipmentsLoading) return;

    if (!forceRefresh && _equipments.isNotEmpty && type == null) return;

    _equipmentsLoading = true;
    notifyListeners();
    try {
      _equipments = await _apiService.fetchEquipments(type: type);
    } catch (e) {
      debugPrint('[MapViewModel.loadEquipments] Hata: $e');
    } finally {
      _equipmentsLoading = false;
      notifyListeners();
    }
  }

  // --- UI İşlemleri ---
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

  // --- BÖLGE SEÇİM METODLARI ---
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
      setError('Lütfen en az 3 köşe seçin.');
      return;
    }

    setBusy(true);
    _optimizationResult = null;
    // notifyListeners() is called by setBusy

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
      setError('Optimizasyon hesaplaması başarısız oldu.');
    } finally {
      setBusy(false);
    }
  }

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
    if (_authViewModel.isLoggedIn != true) {
      return;
    }
    setBusy(true);
    try {
      _pins = await _apiService.fetchPins();
    } catch (e) {
      debugPrint('[MapViewModel] Pin yüklenirken hata: $e');
      // setError(e.toString()); // Pin yüklenemezse tüm haritayı bloke etmek istemeyebiliriz
    } finally {
      setBusy(false);
    }
  }

  Future<Pin> addPin(
    LatLng point,
    String name,
    String type,
    double capacityMw,
    int? equipmentId,
  ) async {
    try {
      final newPin = await _apiService.addPin(
        point,
        name,
        type,
        capacityMw,
        equipmentId,
      );
      await fetchPins();
      return newPin;
    } catch (e) {
      debugPrint('Pin eklenirken hata: $e');
      throw Exception('Pin eklenemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<void> deletePin(int pinId) async {
    try {
      await _apiService.deletePin(pinId);
      await fetchPins();
    } catch (e) {
      debugPrint('Pin silinirken hata: $e');
      throw Exception('Pin silinemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<void> calculatePotential({
    required double lat,
    required double lon,
    required String type,
    required double capacityMw,
    double? panelArea,
  }) async {
    setBusy(true);
    _latestCalculationResult = null;
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
      setError('Hesaplama yapılamadı.');
    } finally {
      setBusy(false);
    }
  }

  // --- Hava Durumu İşlemleri ---

  /// Belirli bir zaman için hava durumu verilerini yükle
  Future<void> loadWeatherForTime(DateTime time) async {
    // Dakika, saniye ve milisaniyeyi sıfırla (Backend saatlik veri bekliyor)
    final truncatedTime = DateTime(
      time.year,
      time.month,
      time.day,
      time.hour,
      0,
      0,
      0,
      0,
    );
    _selectedTime = truncatedTime;

    try {
      _weatherData = await _apiService.fetchWeatherForTime(truncatedTime);
    } catch (e) {
      debugPrint('Hava durumu yüklenirken hata: $e');
      _weatherData = [];
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
      _irradianceData = await _apiService.fetchCityIrradiance(
        cityName,
        hours: hours,
      );
    } catch (e) {
      debugPrint('[MapViewModel.loadCityIrradiance] Hata: $e');
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
      _solarSummary = await _apiService.fetchSolarSummary(hours: hours);
    } catch (e) {
      debugPrint('[MapViewModel.loadSolarSummary] Hata: $e');
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
      final cities = await _apiService.fetchBestSolarCities(limit: limit);
      return cities;
    } catch (e) {
      debugPrint('[MapViewModel.loadBestSolarCities] Hata: $e');
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

  // --- Geo Analysis State ---
  Map<String, dynamic>? _latestGeoAnalysis;
  bool _isAnalyzingGeo = false;
  List<LatLng> _restrictedArea = [];

  Map<String, dynamic>? get latestGeoAnalysis => _latestGeoAnalysis;
  bool get isAnalyzingGeo => _isAnalyzingGeo;
  List<LatLng> get restrictedArea => _restrictedArea;

  Future<void> analyzeLocation(LatLng point) async {
    _isAnalyzingGeo = true;
    _latestGeoAnalysis = null;
    _restrictedArea = [];
    notifyListeners();

    try {
      final result = await _apiService.checkGeoSuitability(
        point.latitude,
        point.longitude,
      );
      _latestGeoAnalysis = result;

      // Yasaklı alan varsa parse et
      if (result['restricted_area'] != null) {
        final List<dynamic> points = result['restricted_area'];
        if (points.isNotEmpty) {
          _restrictedArea = points
              .map((p) => LatLng(p['lat'], p['lng']))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Geo analiz hatası: $e');
    } finally {
      _isAnalyzingGeo = false;
      notifyListeners();
    }
  }

  void clearGeoAnalysis() {
    _latestGeoAnalysis = null;
    _restrictedArea = [];
    notifyListeners();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:frontend/features/map/viewmodels/map_layer_mixin.dart';
import 'package:frontend/features/map/layers/map_layers_system.dart';
import 'package:frontend/data/models/recommendation_model.dart';
export 'package:frontend/features/map/layers/map_layers_system.dart'
    show MapLayerType;

// SharedPreferences key prefix — versiyonlu, schema değişirse eski cache invalidate olur
const _kCityPrefix = 'city_v2_';

// Pin ekleme modunu String olarak tanımla
typedef PinType = String;

enum MapTimePeriod { current, monthly, annual }

class MapViewModel extends BaseViewModel with MapLayerMixin {
  final ApiService _apiService;
  final AuthViewModel _authViewModel;

  @override
  ApiService get apiService => _apiService;

  List<Pin> _pins = [];
  PinType? _placingPinType;
  // MapLayer _currentLayer  <- Moved to mixin
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

  // Pin şehir adı cache: {pinId: "İl / İlçe"}
  final Map<int, String> _pinCityNames = {};

  // --- Harita katman zaman dönemi ve neon toggle ---
  bool _showDataPoints = false;
  bool _showPins = true;
  bool _showVectorLayer = false; // MVT katmanı — varsayılan kapalı (render crash önleme)
  MapTimePeriod _selectedPeriod = MapTimePeriod.current;

  List<Pin> get pins => _pins;
  PinType? get placingPinType => _placingPinType;
  PinCalculationResponse? get latestCalculationResult =>
      _latestCalculationResult;

  bool get showDataPoints => _showDataPoints;
  bool get showPins => _showPins;
  bool get showVectorLayer => _showVectorLayer;
  MapTimePeriod get selectedPeriod => _selectedPeriod;

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

  /// Pin için şehir adı (cache'ten)
  String pinCityName(int pinId) => _pinCityNames[pinId] ?? '';

  void toggleDataPoints(bool value) {
    _showDataPoints = value;
    safeNotify();
  }

  void togglePinsVisibility(bool value) {
    _showPins = value;
    safeNotify();
  }

  void toggleVectorLayer(bool value) {
    _showVectorLayer = value;
    safeNotify();
  }

  void setPeriod(MapTimePeriod period) {
    if (_selectedPeriod == period) return;
    _selectedPeriod = period;
    if (currentLayer != MapLayerType.none) {
      fetchHeatmapDataForLayer(currentLayer);
    }
    safeNotify();
  }

  MapViewModel(this._apiService, this._authViewModel) {
    _authViewModel.addListener(_handleAuthChange);
    // AuthViewModel'in mevcut durumunu kontrol et
    if (_authViewModel.isLoggedIn == true) {
      fetchPins();
    }
    // Ülke genelinde özet (7 gün) ön yükleme
    _loadWeatherSummarySafe();
    // Rüzgar kalite tercihini yükle
    loadWindPreferences();
  }

  Future<void> _loadWeatherSummarySafe() async {
    try {
      _weatherSummary = await _apiService.weather.fetchWeatherSummary(
        hours: 168,
      );
      // Işınım verilerini de yükle
      _solarSummary = await _apiService.weather.fetchSolarSummary(hours: 168);
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
      unawaited(fetchPins());
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
      _equipments = await _apiService.equipment.fetchEquipments(type: type);
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

      _optimizationResult = await _apiService.optimization
          .optimizeWindPlacement(
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

  void clearCalculationResult() {
    _latestCalculationResult = null;
    notifyListeners();
  }

  // --- API İşlemleri ---
  Future<void> fetchPins() async {
    if (_authViewModel.isLoggedIn != true) return;
    setBusy(true);
    try {
      _pins = await _apiService.resource.fetchPins();
      // 1. Önce SharedPreferences'tan anlık yükle (API çağrısı yok)
      await _loadCityNamesFromCache();
      // 2. Sonra eksik olanları arka planda API'den çek
      _fetchMissingCityNames();
    } catch (e) {
      debugPrint('[MapViewModel] Pin yüklenirken hata: $e');
    } finally {
      setBusy(false);
    }
  }

  /// SharedPreferences'tan mevcut pin'lerin şehir adlarını yükle.
  /// Senkron değil ama await edilir — UI kilitlenemez, hızlıdır.
  Future<void> _loadCityNamesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool changed = false;
      for (final pin in _pins) {
        if (_pinCityNames.containsKey(pin.id)) continue;
        final cached = prefs.getString('$_kCityPrefix${pin.id}');
        if (cached != null && cached.isNotEmpty) {
          _pinCityNames[pin.id] = cached;
          changed = true;
        }
      }
      if (changed && !_disposed) notifyListeners();
    } catch (_) {
      // SharedPreferences erişim hatası — sessizce atla
    }
  }

  bool _disposed = false;
  bool _cityFetchRunning = false;

  @override
  void dispose() {
    _disposed = true;
    _authViewModel.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _fetchMissingCityNames() {
    if (_cityFetchRunning) return;
    final missing = _pins.where((p) => !_pinCityNames.containsKey(p.id)).toList();
    if (missing.isEmpty) return;
    _cityFetchRunning = true;
    _fetchCityNamesSequential(missing);
  }

  Future<void> _fetchCityNamesSequential(List<dynamic> pins) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    for (final pin in pins) {
      if (_disposed) break;
      try {
        final info = await _apiService.geo.getCityForCoords(
          pin.latitude, pin.longitude,
        ).timeout(const Duration(seconds: 5));
        if (_disposed) break;
        if (info.isNotEmpty) {
          final province = info['province'] ?? '';
          final district = info['district'] ?? '';
          if (province.isNotEmpty || district.isNotEmpty) {
            final cityStr = district.isNotEmpty ? '$district / $province' : province;
            _pinCityNames[pin.id] = cityStr;
            // SharedPreferences'a kalıcı olarak kaydet
            await prefs?.setString('$_kCityPrefix${pin.id}', cityStr);
            if (!_disposed) notifyListeners();
          }
        }
      } catch (_) {
        // Timeout veya hata — bu pin'i atla, uygulamayı dondurma
      }
      // Arka planda yavaş yükle — backend'i boğma
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _cityFetchRunning = false;
  }

  Future<Pin> addPin(
    LatLng point,
    String name,
    String type,
    double capacityMw,
    int? equipmentId,
    double? panelArea, {
    double? flowRate,
    double? headHeight,
    double? basinAreaKm2,
  }) async {
    try {
      final newPin = await _apiService.resource.addPin(
        point,
        name,
        type,
        capacityMw,
        equipmentId,
        panelArea,
        flowRate: flowRate,
        headHeight: headHeight,
        basinAreaKm2: basinAreaKm2,
      );
      await fetchPins();
      return newPin;
    } catch (e) {
      debugPrint('Pin eklenirken hata: $e');
      throw Exception('Pin eklenemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<Pin> updatePin(
    int pinId,
    LatLng point,
    String name,
    String type,
    double capacityMw,
    int? equipmentId,
    double? panelArea, {
    double? flowRate,
    double? headHeight,
    double? basinAreaKm2,
  }) async {
    try {
      final updatedPin = await _apiService.resource.updatePin(
        pinId,
        point,
        name,
        type,
        capacityMw,
        equipmentId,
        panelArea,
        flowRate: flowRate,
        headHeight: headHeight,
        basinAreaKm2: basinAreaKm2,
      );
      await fetchPins(); // Listeyi güncelle
      return updatedPin;
    } catch (e) {
      debugPrint('Pin güncellenirken hata: $e');
      throw Exception('Pin güncellenemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<void> deletePin(int pinId) async {
    try {
      await _apiService.resource.deletePin(pinId);
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
    double? flowRate,
    double? headHeight,
    double? basinAreaKm2,
  }) async {
    setBusy(true);
    _latestCalculationResult = null;
    try {
      _latestCalculationResult = await _apiService.resource
          .calculateEnergyPotential(
            lat: lat,
            lon: lon,
            type: type,
            capacityMw: capacityMw,
            panelArea: panelArea ?? 0.0,
            flowRate: flowRate,
            headHeight: headHeight,
            basinAreaKm2: basinAreaKm2,
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
      _weatherData = await _apiService.weather.fetchWeatherForTime(
        truncatedTime,
      );

      // EĞER HARİTA KATMANI AÇIKSA, ONU DA GÜNCELLE
      if (currentLayer != MapLayerType.none) {
        unawaited(fetchHeatmapDataForLayer(currentLayer));
      }
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
      _cityHourly = await _apiService.weather.fetchCityHourly(
        cityName,
        hours: 168,
      );
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
      _irradianceData = await _apiService.weather.fetchCityIrradiance(
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
      _solarSummary = await _apiService.weather.fetchSolarSummary(hours: hours);
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
      final cities = await _apiService.weather.fetchBestSolarCities(
        limit: limit,
      );
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

  Future<Map<String, dynamic>?> geoCheck(LatLng point) async {
    _isAnalyzingGeo = true;
    _latestGeoAnalysis = null;
    _restrictedArea = [];
    notifyListeners();

    try {
      final result = await _apiService.geo.checkGeoSuitability(
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
      return result;
    } catch (e) {
      // Geo servisi kapalı veya ulaşılamaz (404, network error) - engelleme
      debugPrint('Geo analiz devre dışı veya hata (devam ediliyor): $e');
      return {'suitable': true, 'geo_disabled': true};
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

  // --- Öneri / Weibull State ---
  RecommendationsData? _recommendations;
  bool _isLoadingRecommendations = false;
  String? _recommendationError;

  RecommendationsData? get recommendations => _recommendations;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  String? get recommendationError => _recommendationError;

  /// Weibull analizine dayalı bölge önerilerini backend'den yükler.
  Future<void> loadRecommendations({int hours = 168}) async {
    if (_isLoadingRecommendations) return;
    _isLoadingRecommendations = true;
    _recommendationError = null;
    notifyListeners();

    try {
      _recommendations = await _apiService.recommendation.fetchRecommendations(
        hours: hours,
      );
    } catch (e) {
      debugPrint('[MapViewModel.loadRecommendations] Hata: $e');
      _recommendationError = e.toString();
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  void clearRecommendations() {
    _recommendations = null;
    _recommendationError = null;
    notifyListeners();
  }
}

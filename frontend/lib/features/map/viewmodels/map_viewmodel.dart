import 'dart:async';
import 'dart:convert';

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
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/data/models/recommendation_model.dart';
export 'package:frontend/features/map/layers/map_layers_system.dart'
    show MapLayerType;
export 'package:frontend/features/map/models/map_models.dart'
    show MapMode, MlHeatmapMode, MlBaseStyle, HeatmapPalette;

// SharedPreferences key prefix — versiyonlu, schema değişirse eski cache invalidate olur
const _kCityPrefix = 'city_v2_';

// Pin ekleme modunu String olarak tanımla
typedef PinType = String;

enum MapTimePeriod { current, monthly, annual }

/// 3 seviyeli coğrafi seçim hiyerarşisi
enum SelectionLevel { none, region, province, district }

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

  // Eşzamanlı fetchPins koruması — aynı anda birden fazla çağrıyı engeller
  bool _fetchingPins = false;

  // --- Harita katman zaman dönemi ve neon toggle ---
  bool _showDataPoints = false;
  bool _showPins = true;
  bool _showVectorLayer = false; // MVT katmanı — varsayılan kapalı (render crash önleme)
  MapTimePeriod _selectedPeriod = MapTimePeriod.current;

  // --- MapLibre 3D Modu ---
  MapMode _mapMode = MapMode.standard;
  MlHeatmapMode _mlHeatmapMode = MlHeatmapMode.none;
  MlBaseStyle _mlBaseStyle = MlBaseStyle.darkMatter;
  bool _show3DTurbines = false;
  bool _showGlobe = false;
  bool _show3DBuildings = false;
  bool _show3DTerrain = false;

  // Isı haritası parametreleri
  double _heatmapRadius = 40.0;
  double _heatmapIntensity = 1.0;
  HeatmapPalette _heatmapPalette = HeatmapPalette.classic;

  // Pin kümeleme
  bool _showPinClusters = false;

  // Pin filtresi
  final Set<String> _pinTypeFilter = {};
  double? _pinMinCapacityMw;

  // --- Önerilen Bölgeler Side Panel ---
  bool _isRecommendationsPanelOpen = false;
  RecommendedCity? _selectedRecommendedCity;
  List<CityWeatherData>? _selectedCityHourlyData;
  bool _isLoadingSelectedCityData = false;
  int _cityDataRequestId = 0;

  // --- Coğrafi Seçim Modu (Bölge / İl / İlçe) ---
  bool _isProvinceModeActive = false;
  SelectionLevel _selectionLevel = SelectionLevel.none;
  String? _selectedRegionName;
  String? _selectedProvinceName;
  String? _selectedDistrictName;
  List<ProvinceSummary> _provinceSummaries = [];
  bool _isLoadingProvinceSummaries = false;

  List<DistrictSummary> _districtSummaries = [];
  bool _isLoadingDistrictSummaries = false;

  List<RegionSummary> _regionSummaries = [];
  bool _isLoadingRegionSummaries = false;

  List<Pin> get pins => _pins;

  /// Pin filtresi uygulanmış pin listesi (haritada gösterilecek)
  List<Pin> get filteredPins {
    if (_pinTypeFilter.isEmpty && _pinMinCapacityMw == null) return _pins;
    return _pins.where((p) {
      if (_pinTypeFilter.isNotEmpty && !_pinTypeFilter.contains(p.type)) return false;
      if (_pinMinCapacityMw != null && p.capacityMw < _pinMinCapacityMw!) return false;
      return true;
    }).toList();
  }

  Set<String> get pinTypeFilter => Set.unmodifiable(_pinTypeFilter);
  double? get pinMinCapacity => _pinMinCapacityMw;
  bool get hasPinFilter => _pinTypeFilter.isNotEmpty || _pinMinCapacityMw != null;
  PinType? get placingPinType => _placingPinType;
  PinCalculationResponse? get latestCalculationResult =>
      _latestCalculationResult;

  bool get showDataPoints => _showDataPoints;
  bool get showPins => _showPins;
  bool get showVectorLayer => _showVectorLayer;
  MapTimePeriod get selectedPeriod => _selectedPeriod;

  // MapLibre 3D getters
  MapMode get mapMode => _mapMode;
  MlHeatmapMode get mlHeatmapMode => _mlHeatmapMode;
  MlBaseStyle get mlBaseStyle => _mlBaseStyle;
  bool get show3DTurbines => _show3DTurbines;
  bool get showGlobe => _showGlobe;
  bool get show3DBuildings => _show3DBuildings;
  bool get show3DTerrain => _show3DTerrain;

  // Isı haritası parametreleri getters
  double get heatmapRadius => _heatmapRadius;
  double get heatmapIntensity => _heatmapIntensity;
  HeatmapPalette get heatmapPalette => _heatmapPalette;

  // Pin kümeleme getter
  bool get showPinClusters => _showPinClusters;

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

  // --- Önerilen Bölgeler Getters ---
  bool get isRecommendationsPanelOpen => _isRecommendationsPanelOpen;
  RecommendedCity? get selectedRecommendedCity => _selectedRecommendedCity;
  List<CityWeatherData>? get selectedCityHourlyData => _selectedCityHourlyData;
  bool get isLoadingSelectedCityData => _isLoadingSelectedCityData;

  // --- Coğrafi Seçim Modu Getters ---
  bool get isProvinceModeActive => _isProvinceModeActive;
  SelectionLevel get selectionLevel => _selectionLevel;

  /// İl modu aktif mi? (province seviyesinde + provinceFilter yok)
  bool get isProvincesModeActive =>
      _isProvinceModeActive && _selectionLevel == SelectionLevel.province;

  /// İlçe modu aktif mi? (district seviyesinde + province filtresi yok)
  bool get isDistrictsModeActive =>
      _isProvinceModeActive &&
      _selectionLevel == SelectionLevel.district &&
      _selectedProvinceName == null;
  String? get selectedRegionName => _selectedRegionName;
  String? get selectedProvinceName => _selectedProvinceName;
  String? get selectedDistrictName => _selectedDistrictName;
  List<ProvinceSummary> get provinceSummaries => _provinceSummaries;
  bool get isLoadingProvinceSummaries => _isLoadingProvinceSummaries;
  List<DistrictSummary> get districtSummaries => _districtSummaries;
  bool get isLoadingDistrictSummaries => _isLoadingDistrictSummaries;
  List<RegionSummary> get regionSummaries => _regionSummaries;
  bool get isLoadingRegionSummaries => _isLoadingRegionSummaries;

  /// GADM NAME_1 ("Istanbul") ile DB city_name ("İstanbul") arasındaki
  /// diacritic/case farklarını gidererek karşılaştırma yapar.
  static String _normalizeProvinceName(String name) {
    return name
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('. ', ' '); // "K. Maras" → "k maras"
  }

  ProvinceSummary? get selectedProvinceSummary {
    if (_selectedProvinceName == null || _provinceSummaries.isEmpty) return null;
    final normalizedSelected = _normalizeProvinceName(_selectedProvinceName!);
    try {
      return _provinceSummaries.firstWhere(
        (p) => _normalizeProvinceName(p.provinceName) == normalizedSelected,
      );
    } catch (_) {
      return null;
    }
  }

  /// Seçili ilçenin hava özeti — district-summary listesinden eşleştirme.
  DistrictSummary? get selectedDistrictSummary {
    if (_selectedDistrictName == null || _districtSummaries.isEmpty) return null;
    final nameNorm = _normalizeProvinceName(_selectedDistrictName!);
    try {
      return _districtSummaries.firstWhere(
        (d) => _normalizeProvinceName(d.districtName) == nameNorm,
      );
    } catch (_) {
      return null;
    }
  }

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

  // --- MapLibre 3D Modu Metodları ---

  void setMapMode(MapMode mode) {
    if (_mapMode == mode) return;
    _mapMode = mode;
    safeNotify();
  }

  void setMlHeatmapMode(MlHeatmapMode mode) {
    _mlHeatmapMode = mode;
    // Isı haritası için summary verisi gerekli
    if (mode != MlHeatmapMode.none && _weatherSummary.isEmpty) {
      _loadWeatherSummarySafe();
    }
    safeNotify();
  }

  void setMlBaseStyle(MlBaseStyle style) {
    _mlBaseStyle = style;
    safeNotify();
  }

  // Isı haritası parametre setters
  void setHeatmapRadius(double v) {
    _heatmapRadius = v.clamp(10.0, 100.0);
    safeNotify();
  }

  void setHeatmapIntensity(double v) {
    _heatmapIntensity = v.clamp(0.2, 5.0);
    safeNotify();
  }

  void setHeatmapPalette(HeatmapPalette p) {
    _heatmapPalette = p;
    safeNotify();
  }

  // Pin kümeleme toggle
  void togglePinClustering() {
    _showPinClusters = !_showPinClusters;
    safeNotify();
  }

  // Pin filtre metodları
  void togglePinTypeFilter(String type) {
    if (_pinTypeFilter.contains(type)) {
      _pinTypeFilter.remove(type);
    } else {
      _pinTypeFilter.add(type);
    }
    safeNotify();
  }

  void setPinMinCapacity(double? v) {
    _pinMinCapacityMw = v;
    safeNotify();
  }

  void clearPinFilter() {
    _pinTypeFilter.clear();
    _pinMinCapacityMw = null;
    safeNotify();
  }

  void toggleShow3DTurbines() {
    _show3DTurbines = !_show3DTurbines;
    safeNotify();
  }

  void toggleShowGlobe() {
    _showGlobe = !_showGlobe;
    safeNotify();
  }

  void toggleShow3DBuildings() {
    _show3DBuildings = !_show3DBuildings;
    safeNotify();
  }

  void toggleShow3DTerrain() {
    _show3DTerrain = !_show3DTerrain;
    safeNotify();
  }

  // --- Önerilen Bölgeler Panel Metodları ---

  void toggleRecommendationsPanel() {
    _isRecommendationsPanelOpen = !_isRecommendationsPanelOpen;
    if (_isRecommendationsPanelOpen &&
        _recommendations == null &&
        !_isLoadingRecommendations) {
      loadRecommendations();
    }
    safeNotify();
  }

  void closeRecommendationsPanel() {
    _isRecommendationsPanelOpen = false;
    safeNotify();
  }

  /// Önerilen bir şehri seç — saatlik hava verisini yükler.
  /// _cityDataRequestId ile hızlı tıklama koruması sağlanır.
  Future<void> selectRecommendedCity(RecommendedCity city) async {
    _selectedRecommendedCity = city;
    _isLoadingSelectedCityData = true;
    final requestId = ++_cityDataRequestId;
    notifyListeners();

    try {
      final hourlyData = await _apiService.weather.fetchCityHourly(
        city.name,
        hours: 168,
      );
      if (_cityDataRequestId != requestId || _disposed) return;
      _selectedCityHourlyData = hourlyData;
    } catch (e) {
      if (_cityDataRequestId != requestId || _disposed) return;
      debugPrint('[MapViewModel.selectRecommendedCity] Error: $e');
      _selectedCityHourlyData = null;
    } finally {
      if (_cityDataRequestId == requestId && !_disposed) {
        _isLoadingSelectedCityData = false;
        notifyListeners();
      }
    }
  }

  void clearSelectedCity() {
    _selectedRecommendedCity = null;
    _selectedCityHourlyData = null;
    _isLoadingSelectedCityData = false;
    safeNotify();
  }

  // --- Coğrafi Seçim Modu Metodları ---

  /// Seçim modunu kapat.
  void closeSelectionMode() {
    _isProvinceModeActive = false;
    _selectionLevel       = SelectionLevel.none;
    _selectedRegionName   = null;
    _selectedProvinceName = null;
    _selectedDistrictName = null;
    safeNotify();
  }

  /// İl modunu aç/kapat. Tüm 81 ili doğrudan gösterir; bölge filtresi isteğe bağlıdır.
  void openProvincesMode() {
    if (_isProvinceModeActive && _selectionLevel == SelectionLevel.province) {
      closeSelectionMode();
      return;
    }
    _isProvinceModeActive = true;
    _selectionLevel       = SelectionLevel.province;
    _selectedRegionName   = null;
    _selectedProvinceName = null;
    _selectedDistrictName = null;
    _districtSummaries    = [];
    safeNotify();
    if (_provinceSummaries.isEmpty) loadProvinceSummaries();
    if (_regionSummaries.isEmpty) loadRegionSummaries();
  }

  /// İlçe modunu aç/kapat. Tüm Türkiye ilçelerini doğrudan gösterir (il filtresi yok).
  void openDistrictsMode() {
    if (isDistrictsModeActive) {
      closeSelectionMode();
      return;
    }
    _isProvinceModeActive = true;
    _selectionLevel       = SelectionLevel.district;
    _selectedRegionName   = null;
    _selectedProvinceName = null;
    _selectedDistrictName = null;
    _districtSummaries    = [];
    safeNotify();
    if (_provinceSummaries.isEmpty) loadProvinceSummaries();
    if (_regionSummaries.isEmpty) loadRegionSummaries();
  }

  /// Geriye dönük uyumluluk — İl modunu açar/kapatır.
  void toggleProvinceMode() => openProvincesMode();

  /// Bölge seçildi → il seviyesine geç.
  void selectRegion(String regionName) {
    _selectedRegionName   = regionName;
    _selectedProvinceName = null;
    _selectedDistrictName = null;
    _selectionLevel       = SelectionLevel.province;
    safeNotify();
  }

  /// İl seçildi → ilçe seviyesine geç. İlçe verisini arka planda yükle.
  void selectProvince(String provinceName) {
    _selectedProvinceName = provinceName;
    _selectedDistrictName = null;
    _districtSummaries    = [];   // önceki ilin ilçelerini temizle
    _selectionLevel       = SelectionLevel.district;
    safeNotify();
    loadDistrictSummaries(provinceName); // arka planda yükle
  }

  /// İlçe seçildi.
  void selectDistrict(String districtName) {
    _selectedDistrictName = districtName;
    safeNotify();
  }

  /// İlçe seçimini temizle (il seviyesinde kal, bölge korunur).
  void clearSelectedDistrict() {
    _selectedDistrictName = null;
    // selectionLevel stays at district (showing districts in province)
    safeNotify();
  }

  /// İl seçimini temizle → il listesine geri dön (bölge filtresi korunur).
  void clearSelectedProvince() {
    _selectedProvinceName = null;
    _selectedDistrictName = null;
    _districtSummaries    = [];
    _selectionLevel       = SelectionLevel.province;
    safeNotify();
  }

  /// Bölge filtresini temizle → tüm iller gösterilir.
  void clearRegionFilter() {
    _selectedRegionName   = null;
    _selectedProvinceName = null;
    _selectedDistrictName = null;
    _selectionLevel       = SelectionLevel.province;
    safeNotify();
  }

  /// Bölge seçimini temizle → il listesine geri dön (geriye dönük uyumluluk).
  void clearSelectedRegion() => clearRegionFilter();

  /// Tüm seçimi temizle → il listesine sıfırla.
  void clearAllSelection() {
    _selectedRegionName   = null;
    _selectedProvinceName = null;
    _selectedDistrictName = null;
    _districtSummaries    = [];
    _selectionLevel = _isProvinceModeActive
        ? SelectionLevel.province
        : SelectionLevel.none;
    safeNotify();
  }

  Future<void> loadProvinceSummaries({int hours = 168}) async {
    if (_isLoadingProvinceSummaries) return;
    _isLoadingProvinceSummaries = true;
    safeNotify();
    try {
      _provinceSummaries = await _apiService.weather.fetchProvinceSummary(
        hours: hours,
      );
    } catch (e) {
      debugPrint('[MapViewModel.loadProvinceSummaries] Hata: $e');
      _provinceSummaries = [];
    } finally {
      _isLoadingProvinceSummaries = false;
      safeNotify();
    }
  }

  Future<void> loadDistrictSummaries(String province, {int hours = 168}) async {
    if (_isLoadingDistrictSummaries) return;
    _isLoadingDistrictSummaries = true;
    safeNotify();
    try {
      _districtSummaries = await _apiService.weather.fetchDistrictSummary(
        province: province,
        hours: hours,
      );
    } catch (e) {
      debugPrint('[MapViewModel.loadDistrictSummaries] Hata: $e');
      _districtSummaries = [];
    } finally {
      _isLoadingDistrictSummaries = false;
      safeNotify();
    }
  }

  Future<void> loadRegionSummaries({int hours = 168}) async {
    if (_isLoadingRegionSummaries) return;
    _isLoadingRegionSummaries = true;
    safeNotify();
    try {
      _regionSummaries = await _apiService.weather.fetchRegionSummary(
        hours: hours,
      );
    } catch (e) {
      debugPrint('[MapViewModel.loadRegionSummaries] Hata: $e');
      _regionSummaries = [];
    } finally {
      _isLoadingRegionSummaries = false;
      safeNotify();
    }
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
    if (_fetchingPins) return; // Eşzamanlı çağrıyı engelle
    _fetchingPins = true;
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
      _fetchingPins = false;
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
    // DB'de kayıtlı konum bilgisi olan pinleri atla — sadece eksik olanları çek
    final missing = _pins.where((p) {
      if (_pinCityNames.containsKey(p.id)) return false;
      // Pin'in kendi modelinde şehir bilgisi varsa cache'e yaz, API'ye gitme
      if (p.locationLabel.isNotEmpty) {
        _pinCityNames[p.id] = p.locationLabel;
        return false;
      }
      return true;
    }).toList();
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
      // Pin oluşturulmadan önce şehir/ilçe bilgisini çek (bir kez, DB'ye kaydedilir)
      String? city;
      String? district;
      try {
        final geoInfo = await _apiService.geo.getCityForCoords(
          point.latitude, point.longitude,
        ).timeout(const Duration(seconds: 5));
        city = geoInfo['province'];
        district = geoInfo['district'];
      } catch (_) {
        // Geo servisi kapalıysa devam et — konum bilgisi boş kalır
      }

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
        city: city,
        district: district,
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

  /// En yakın şehir adını bul — katman-bağımsız hover için.
  /// weatherData (at-time) yoksa weatherSummary'den (7-gün) fallback kullanır.
  String? findNearestCityName(LatLng position) {
    // Önce at-time snapshot'a bak
    final city = findNearestCity(position);
    if (city != null) return city.cityName;

    // Fallback: 7-günlük özet verisi
    if (_weatherSummary.isEmpty) return null;

    CityWeatherSummary? nearest;
    double minDistance = double.infinity;

    for (final s in _weatherSummary) {
      final d = _calculateDistance(
        position.latitude,
        position.longitude,
        s.lat,
        s.lon,
      );
      if (d < minDistance) {
        minDistance = d;
        nearest = s;
      }
    }

    if (minDistance > 100) return null;
    return nearest?.cityName;
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

  // ─── Zaman Simülasyonu (Animasyon) State ───────────────────────────────────

  bool _isAnimationMode   = false;
  bool _animIsPlaying     = false;
  bool _animIsLoading     = false;
  int  _animCurrentFrame  = 0;
  int  _animTotalFrames   = 0;
  String _animCurrentTimestamp = '';
  String _animMetric      = 'wind';       // wind | temperature | radiation
  String _animInterval    = 'daily';      // daily | hourly
  double _animSpeedFps    = 5.0;
  DateTime _animStartDate = DateTime(2024, 1, 1);
  DateTime _animEndDate   = DateTime(2024, 12, 31);
  String? _animError;
  String _animRangeInfo   = '';  // "Günlük: 2015–2024 · Saatlik: 2024–2025" gibi

  // Standard harita için frame verisi + timer
  List<dynamic>? _animFrames;       // frames[i] = {"ts": "...", "pts": [[lat,lon,val], ...]}
  double _animMetricMin = 0.0;
  double _animMetricMax = 1.0;
  Timer? _animTimer;

  bool   get isAnimationMode        => _isAnimationMode;
  bool   get animIsPlaying          => _animIsPlaying;
  bool   get animIsLoading          => _animIsLoading;
  int    get animCurrentFrame       => _animCurrentFrame;
  int    get animTotalFrames        => _animTotalFrames;
  String get animCurrentTimestamp   => _animCurrentTimestamp;
  String get animMetric             => _animMetric;
  String get animInterval           => _animInterval;
  double get animSpeedFps           => _animSpeedFps;
  DateTime get animStartDate        => _animStartDate;
  DateTime get animEndDate          => _animEndDate;
  String? get animError             => _animError;
  String get animRangeInfo          => _animRangeInfo;

  /// Animasyon modunu aç/kapat.
  void toggleAnimationMode() {
    if (_isAnimationMode) {
      // Kapat: animasyonu durdur, heatmap'i sıfırla
      _animTimer?.cancel();
      _animTimer = null;
      _jsAnimStop();
      _isAnimationMode  = false;
      _animIsPlaying    = false;
      _animCurrentFrame = 0;
      _animTotalFrames  = 0;
      _animCurrentTimestamp = '';
      _animError        = null;
      _animFrames       = null;
    } else {
      _isAnimationMode = true;
      // Açılışta mevcut veri aralığını arka planda çek
      _fetchAnimationRange();
    }
    safeNotify();
  }

  /// Backend'den kullanılabilir tarih aralığını çekip `_animRangeInfo`'ya yaz.
  Future<void> _fetchAnimationRange() async {
    try {
      final data = await _apiService.weather.fetchAnimationRange();
      final dMin = data['daily_min']  ?? '?';
      final dMax = data['daily_max']  ?? '?';
      final hMin = data['hourly_min'] ?? '?';
      final hMax = data['hourly_max'] ?? '?';
      // Yıl kısmını kısalt: "2015-12-31" → "2015"
      String _yr(String s) => s.length >= 4 ? s.substring(0, 4) : s;
      _animRangeInfo = 'Günlük: ${_yr(dMin)}–${_yr(dMax)}  ·  Saatlik: ${_yr(hMin)}–${_yr(hMax)}';
    } catch (e) {
      _animRangeInfo = '';
    }
    safeNotify();
  }

  /// Frame verisini backend'den çekip standard harita + MapLibre için hazırlar.
  Future<void> loadAnimationData() async {
    if (_animIsLoading) return;
    _animTimer?.cancel();
    _animTimer = null;
    _animIsLoading = true;
    _animError     = null;
    _animIsPlaying = false;
    _animCurrentFrame     = 0;
    _animTotalFrames      = 0;
    _animCurrentTimestamp = '';
    _animFrames           = null;
    _jsAnimStop();
    safeNotify();

    try {
      final start = '${_animStartDate.year.toString().padLeft(4, '0')}'
          '-${_animStartDate.month.toString().padLeft(2, '0')}'
          '-${_animStartDate.day.toString().padLeft(2, '0')}';
      final end = '${_animEndDate.year.toString().padLeft(4, '0')}'
          '-${_animEndDate.month.toString().padLeft(2, '0')}'
          '-${_animEndDate.day.toString().padLeft(2, '0')}';

      final data = await _apiService.weather.fetchAnimationData(
        start: start,
        end: end,
        metric: _animMetric,
        interval: _animInterval,
      );

      _animTotalFrames = (data['total_frames'] as num?)?.toInt() ?? 0;
      if (_animTotalFrames == 0) {
        _animError = 'Seçilen tarih aralığında veri bulunamadı.';
      } else {
        // Metriğe göre MapLibre heatmap modunu ayarla
        final targetMode = _animMetric == 'wind'
            ? MlHeatmapMode.wind
            : _animMetric == 'temperature'
                ? MlHeatmapMode.temperature
                : MlHeatmapMode.solar;
        setMlHeatmapMode(targetMode);

        // MapLibre için JS'e tam JSON gönder (sadece MapLibre modunda)
        if (_mapMode == MapMode.maplibre3d) {
          _jsLoadAnimationData(jsonEncode(data));
        }

        // Standard harita için frame verisini sakla
        _animFrames    = data['frames'] as List?;
        _animMetricMin = (data['metric_min'] as num?)?.toDouble() ?? 0.0;
        _animMetricMax = (data['metric_max'] as num?)?.toDouble() ?? 1.0;

        // İlk frame'i hemen render et (her iki haritada)
        if (_animFrames != null && _animFrames!.isNotEmpty) {
          _animCurrentTimestamp = (_animFrames![0] as Map)['ts'] ?? '';
          _renderStandardMapFrame(0);
        }
      }
    } catch (e) {
      // processResponse zaten FastAPI detail mesajını Exception içine koyuyor
      _animError = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[MapViewModel.loadAnimationData] $e');
    } finally {
      _animIsLoading = false;
      safeNotify();
    }
  }

  /// Standard harita: belirtilen frame'i FlutterMap heatmap'e yazar.
  void _renderStandardMapFrame(int frame) {
    if (_animFrames == null || frame < 0 || frame >= _animFrames!.length) return;
    final frameData = _animFrames![frame] as Map;
    final pts = frameData['pts'] as List? ?? [];
    final layerType = _animMetric == 'wind'
        ? MapLayerType.wind
        : _animMetric == 'temperature'
            ? MapLayerType.temp
            : MapLayerType.irradiance;
    setAnimFrameData(pts, layerType, _animMetricMin, _animMetricMax);
  }

  /// Animasyonu oynat — MapLibre: JS timer; Standard: Dart Timer.
  void playAnimation() {
    if (_animTotalFrames == 0) return;
    _animIsPlaying = true;
    if (_mapMode == MapMode.maplibre3d) {
      // MapLibre: JS setInterval üzerinden animasyon
      _jsAnimPlay(_animSpeedFps);
    } else {
      // Standard harita: Dart Timer ile frame ilerlet
      _animTimer?.cancel();
      final intervalMs = (1000.0 / _animSpeedFps).round();
      _animTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
        final next = (_animCurrentFrame + 1) % _animTotalFrames;
        _animCurrentFrame = next;
        _animCurrentTimestamp = (_animFrames != null && next < _animFrames!.length)
            ? ((_animFrames![next] as Map)['ts'] ?? '')
            : '';
        _renderStandardMapFrame(next);
        // safeNotify() yerine doğrudan çağır — timer zaten main thread dışında değil,
        // post-frame callback pile-up'ı önler
        notifyListeners();
      });
    }
    safeNotify();
  }

  /// Animasyonu durdur.
  void pauseAnimation() {
    _animIsPlaying = false;
    _animTimer?.cancel();
    _animTimer = null;
    if (_mapMode == MapMode.maplibre3d) _jsAnimStop();
    safeNotify();
  }

  /// Belirli frame indeksine atla.
  void seekAnimation(int frame) {
    if (_animTotalFrames == 0) return;
    _animCurrentFrame = frame.clamp(0, _animTotalFrames - 1);
    if (_mapMode == MapMode.maplibre3d) {
      _jsAnimSeek(_animCurrentFrame);
    }
    // Standard harita
    if (_animFrames != null) {
      _animCurrentTimestamp = (_animCurrentFrame < _animFrames!.length)
          ? ((_animFrames![_animCurrentFrame] as Map)['ts'] ?? '')
          : '';
      _renderStandardMapFrame(_animCurrentFrame);
    }
    safeNotify();
  }

  /// Metrik değiştir (wind | temperature | radiation).
  void setAnimMetric(String m) {
    if (_animMetric == m) return;
    _animMetric = m;
    safeNotify();
  }

  /// Aralık değiştir (daily | hourly).
  /// Saatlik moda geçince end date otomatik olarak 30 günle sınırlanır.
  void setAnimInterval(String i) {
    if (_animInterval == i) return;
    _animInterval = i;
    _clampAnimEndDate();
    safeNotify();
  }

  /// FPS hızını değiştir.
  void setAnimSpeed(double fps) {
    _animSpeedFps = fps.clamp(1.0, 20.0);
    if (_animIsPlaying) {
      if (_mapMode == MapMode.maplibre3d) {
        _jsAnimStop();
        _jsAnimPlay(_animSpeedFps);
      } else {
        // Standard harita — timer'ı yeni hızla yeniden başlat
        _animTimer?.cancel();
        final intervalMs = (1000.0 / _animSpeedFps).round();
        _animTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
          final next = (_animCurrentFrame + 1) % _animTotalFrames;
          _animCurrentFrame = next;
          _animCurrentTimestamp = (_animFrames != null && next < _animFrames!.length)
              ? ((_animFrames![next] as Map)['ts'] ?? '')
              : '';
          _renderStandardMapFrame(next);
          notifyListeners();
        });
      }
    }
    safeNotify();
  }

  // ── Validasyon yardımcıları ───────────────────────────────────────────────

  static const int _hourlyMaxDays = 30;
  static const int _dailyMaxDays  = 365;

  int get _animMaxDays => _animInterval == 'hourly' ? _hourlyMaxDays : _dailyMaxDays;

  /// Seçilen aralık geçerliyse null, değilse kullanıcıya gösterilecek mesaj.
  String? get animDateRangeError {
    final diff = _animEndDate.difference(_animStartDate).inDays;
    if (diff < 1) return 'En az 1 gün seçilmeli';
    if (diff > _animMaxDays) {
      return _animInterval == 'hourly'
          ? 'Saatlik modda maksimum $_hourlyMaxDays gün seçilebilir'
          : 'Günlük modda maksimum $_dailyMaxDays gün seçilebilir';
    }
    return null;
  }

  void _clampAnimEndDate() {
    final maxEnd = _animStartDate.add(Duration(days: _animMaxDays));
    if (_animEndDate.isAfter(maxEnd)) _animEndDate = maxEnd;
  }

  /// Tarih aralığını güncelle (end date otomatik kısıtlanır).
  void setAnimDateRange(DateTime start, DateTime end) {
    _animStartDate = start;
    _animEndDate   = end;
    _clampAnimEndDate();
    safeNotify();
  }

  /// JS animasyon callback'inden çağrılır — frame index + timestamp günceller.
  void onAnimFrameChanged(int index, String ts) {
    _animCurrentFrame     = index;
    _animCurrentTimestamp = ts;
    safeNotify();
  }

  // ── JS bridge stub'ları — map_view_maplibre_web.dart set eder ──────────────
  // map_view_maplibre_web.dart initState'de bu closure'ları doldurur.
  // Bu şekilde ViewModel → JS bağımlılığı tersine çevrilmiş olur.
  void Function(String json)? _jsLoadFn;
  void Function(double fps)?  _jsPlayFn;
  void Function()?            _jsStopFn;
  void Function(int frame)?   _jsSeekFn;

  void registerJsBridge({
    required void Function(String json) loadFn,
    required void Function(double fps)  playFn,
    required void Function()            stopFn,
    required void Function(int frame)   seekFn,
  }) {
    _jsLoadFn = loadFn;
    _jsPlayFn = playFn;
    _jsStopFn = stopFn;
    _jsSeekFn = seekFn;
  }

  void _jsLoadAnimationData(String json)  => _jsLoadFn?.call(json);
  void _jsAnimPlay(double fps)            => _jsPlayFn?.call(fps);
  void _jsAnimStop()                      => _jsStopFn?.call();
  void _jsAnimSeek(int frame)             => _jsSeekFn?.call(frame);
}

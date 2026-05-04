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
// ignore: unused_import — export için gerekli (MapLayerType caller'lara)
import 'package:frontend/features/map/layers/map_layers_system.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/data/models/recommendation_model.dart';
export 'package:frontend/features/map/layers/map_layers_system.dart'
    show MapLayerType;
export 'package:frontend/features/map/models/map_models.dart'
    show MlHeatmapMode, MlBaseStyle, HeatmapPalette, ChoroplethMode;

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
  DateTime? _equipmentsLastFetch;
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
  MlHeatmapMode _mlHeatmapMode = MlHeatmapMode.none;
  MlBaseStyle _mlBaseStyle = MlBaseStyle.darkMatter;
  bool _autoMapStyleSync = true; // Tema ile otomatik stil senkronizasyonu
  bool _show3DTurbines = false;
  bool _showGlobe = false;

  /// Globe açılmadan önce Türkiye özelliklerinin durumunu saklar.
  Map<String, dynamic>? _preGlobeState;
  bool _show3DBuildings = false;
  bool _show3DTerrain = false;
  bool _showCloudLayer = false;
  double _cloudOpacity = 0.70;

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
  /// Kullanıcının başlangıçta açtığı mod (region/province/district).
  /// selectProvince() çağrıldığında davranışı belirler.
  SelectionLevel _initialSelectionMode = SelectionLevel.none;
  SelectionLevel get initialSelectionMode => _initialSelectionMode;
  String? _selectedRegionName;
  String? _selectedProvinceName;
  String? _selectedProvinceCode;  // 3 harfli il kodu (ör. "ist")
  String? _selectedDistrictName;
  List<ProvinceSummary> _provinceSummaries = [];
  bool _isLoadingProvinceSummaries = false;

  List<DistrictSummary> _districtSummaries = [];
  bool _isLoadingDistrictSummaries = false;

  List<RegionSummary> _regionSummaries = [];
  bool _isLoadingRegionSummaries = false;

  List<Pin> get pins => _pins;

  // Aşama 2: ScenarioViewModel'in gizli senaryo pin'leri set'inden senkronlanır.
  // MapScreen, Consumer<ScenarioViewModel> içinde `setHiddenPinIds` çağırır;
  // `filteredPins` bu seti pin filtresine ekler — gizli senaryo pin'leri haritada
  // çizilmez.
  Set<int> _hiddenScenarioPinIds = const {};

  /// MapScreen tarafından scenarioVM.hiddenPinIds ile sync edilir.
  void setHiddenScenarioPinIds(Set<int> ids) {
    // Set eşitliği: aynıysa notify atlama (gereksiz rebuild yok)
    if (_hiddenScenarioPinIds.length == ids.length &&
        _hiddenScenarioPinIds.containsAll(ids)) {
      return;
    }
    _hiddenScenarioPinIds = ids;
    safeNotify();
  }

  /// Pin filtresi uygulanmış pin listesi (haritada gösterilecek)
  List<Pin> get filteredPins {
    if (_pinTypeFilter.isEmpty &&
        _pinMinCapacityMw == null &&
        _hiddenScenarioPinIds.isEmpty) {
      return _pins;
    }
    return _pins.where((p) {
      if (_pinTypeFilter.isNotEmpty && !_pinTypeFilter.contains(p.type)) return false;
      if (_pinMinCapacityMw != null && p.capacityMw < _pinMinCapacityMw!) return false;
      if (_hiddenScenarioPinIds.contains(p.id)) return false;
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
  MlHeatmapMode get mlHeatmapMode => _mlHeatmapMode;
  MlBaseStyle get mlBaseStyle => _mlBaseStyle;
  bool get autoMapStyleSync => _autoMapStyleSync;
  bool get show3DTurbines => _show3DTurbines;
  bool get showGlobe => _showGlobe;
  bool get show3DBuildings => _show3DBuildings;
  bool get show3DTerrain => _show3DTerrain;
  bool get showCloudLayer => _showCloudLayer;
  double get cloudOpacity => _cloudOpacity;

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

  /// Bölge modu aktif mi? (region seviyesinde)
  bool get isRegionsModeActive =>
      _isProvinceModeActive && _selectionLevel == SelectionLevel.region;

  /// İl modu aktif mi? (province seviyesinde + bölge filtresi yok)
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
  // GeoJSON ilçe adı → Backend ilçe adı eşleme tablosu
  static const _districtNameMap = <String, String>{
    '19 Mayıs': 'Ondokuz Mayıs',
    '19 MAYIS': 'Ondokuz Mayıs',
  };

  /// GeoJSON'dan gelen adı backend karşılığına çevir
  static String _mapDistrictName(String name) {
    return _districtNameMap[name] ?? name;
  }

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
  /// GeoJSON "Zonguldak Merkez" formatında gelir; API "Merkez" döndürür.
  /// Boşluk/tire farkları ve "Merkez" kısa adıyla da eşleştirme yapılır.

  // Bölünmüş Merkez ilçeleri → "Merkez" verisi ile eşleştirilir
  static const _merkezSplitDistricts = <String>{
    'muratpasa', 'kepez', 'konyaalti', 'dosemealti', 'aksu', // antalya
    'efeler', // aydin
    'karesi', 'altieylul', // balikesir
    'merkezefendi', 'pamukkale', // denizli
    'sur', 'baglar', 'kayapinar', 'yenisehir', // diyarbakir
    'yakutiye', 'aziziye', 'palandoken', // erzurum
    'odunpazari', 'tepebasi', // eskisehir
    'antakya', 'defne', // hatay
    'izmit', 'basiskele', 'kartepe', // kocaeli
    'battalgazi', 'yesilyurt', // malatya
    'sehzadeler', 'yunus emre', // manisa
    'artuklu', 'kiziltepe', // mardin
    'akdeniz', 'mezitli', 'toroslar', // mersin
    'mentese', // mugla
    'altinordu', 'catalpinar', // ordu
    'adapazari', 'serdivan', 'erenler', 'arifiye', // sakarya
    'ilkadim', 'atakum', 'canik', 'tekkekoy', // samsun
    'haliliye', 'eyyubiye', 'karakopru', // sanliurfa
    'suleymanpasa', 'kapakli', 'ergene', // tekirdag
    'ortahisar', // trabzon
    'ipekyolu', 'tusba', 'edremit', // van
  };

  DistrictSummary? get selectedDistrictSummary {
    if (_selectedDistrictName == null || _districtSummaries.isEmpty) return null;
    final nameNorm = _normalizeProvinceName(_selectedDistrictName!);
    // Boşluk-insensitive versiyonu (Yunus Emre ↔ Yunusemre)
    final nameCompact = nameNorm.replaceAll(' ', '');

    // 1. Tam eşleşme
    for (final d in _districtSummaries) {
      final dn = _normalizeProvinceName(d.districtName);
      if (dn == nameNorm || dn.replaceAll(' ', '') == nameCompact) return d;
    }

    // 2. "X Merkez" formatı → API'de "Merkez" olarak döner
    if (_selectedDistrictName!.endsWith(' Merkez')) {
      for (final d in _districtSummaries) {
        if (_normalizeProvinceName(d.districtName) == 'merkez') return d;
      }
    }

    // 3. Bölünmüş Merkez ilçeleri → API'deki "Merkez" verisini kullan
    if (_merkezSplitDistricts.contains(nameNorm) ||
        _merkezSplitDistricts.contains(nameCompact)) {
      for (final d in _districtSummaries) {
        if (_normalizeProvinceName(d.districtName) == 'merkez') return d;
      }
    }

    return null;
  }

  String? get selectedProvinceCode => _selectedProvinceCode;

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
    // 1.A2: heatmap fetcher emekliye ayrıldı — periyot değişimi tematik
    // haritayı (choropleth) etkilemez (choropleth kendi mode/season'ından
    // beslenir; period MapTimePeriod yan-panel saat penceresi içindir).
    safeNotify();
  }

  // --- MapLibre 3D Modu Metodları ---

  void setMlHeatmapMode(MlHeatmapMode mode) {
    _mlHeatmapMode = mode;
    // Isı haritası için summary verisi gerekli
    if (mode != MlHeatmapMode.none && _weatherSummary.isEmpty) {
      _loadWeatherSummarySafe();
    }
    safeNotify();
  }

  void setMlBaseStyle(MlBaseStyle style, {bool fromThemeSync = false}) {
    _mlBaseStyle = style;
    if (!fromThemeSync) _autoMapStyleSync = false;
    safeNotify();
  }

  void setAutoMapStyleSync(bool value) {
    _autoMapStyleSync = value;
    safeNotify();
  }

  /// Tema değiştiğinde harita stilini otomatik güncelle
  void syncBaseStyleWithTheme(bool isDark) {
    if (!_autoMapStyleSync) return;
    final target = isDark ? MlBaseStyle.darkMatter : MlBaseStyle.positron;
    if (_mlBaseStyle != target) {
      _mlBaseStyle = target;
      safeNotify();
    }
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
    if (!_showGlobe) {
      // Globe açılıyor → Türkiye özelliklerini kaydet ve kapat
      _preGlobeState = {
        'heatmapMode': _mlHeatmapMode,
        'windParticles': showWindParticles,
        'cloudLayer': _showCloudLayer,
        'terrain': _show3DTerrain,
        'buildings': _show3DBuildings,
        'selectionLevel': _selectionLevel,
        'provinceModeActive': _isProvinceModeActive,
        'turbines': _show3DTurbines,
        'choroplethMode': choroplethMode,
        // 1.B (yeniden): animation state artık TimeSimulationController'da
        // (MapScreen ömrüne bağlı). Globe state save/restore animation'a
        // dokunmaz; kullanıcı globe'a geçerse ve dönerse animation paneli
        // zaten kapanır (controller close edilir).
        'recommendationsOpen': _isRecommendationsPanelOpen,
      };
      // Türkiye'ye özgü özellikleri kapat
      _mlHeatmapMode = MlHeatmapMode.none;
      if (showWindParticles) toggleWindParticles(false);
      _showCloudLayer = false;
      _show3DTerrain = false;
      _show3DBuildings = false;
      _show3DTurbines = false;
      _selectionLevel = SelectionLevel.none;
      _isProvinceModeActive = false;
      if (choroplethMode != ChoroplethMode.none) {
        setChoroplethMode(ChoroplethMode.none);
      }
      if (_isRecommendationsPanelOpen) {
        _isRecommendationsPanelOpen = false;
      }
      _showGlobe = true;
    } else {
      // Globe kapatılıyor → önceki durumu geri yükle
      _showGlobe = false;
      if (_preGlobeState != null) {
        final s = _preGlobeState!;
        _mlHeatmapMode = s['heatmapMode'] as MlHeatmapMode? ?? MlHeatmapMode.none;
        if (s['windParticles'] == true) toggleWindParticles(true);
        _showCloudLayer = s['cloudLayer'] as bool? ?? false;
        _show3DTerrain = s['terrain'] as bool? ?? false;
        _show3DBuildings = s['buildings'] as bool? ?? false;
        _show3DTurbines = s['turbines'] as bool? ?? false;
        _selectionLevel = s['selectionLevel'] as SelectionLevel? ?? SelectionLevel.none;
        _isProvinceModeActive = s['provinceModeActive'] as bool? ?? false;
        // Choropleth geri yükle
        final savedChoro = s['choroplethMode'] as ChoroplethMode?;
        if (savedChoro != null && savedChoro != ChoroplethMode.none) {
          setChoroplethMode(savedChoro);
        }
        // 1.B (yeniden): animasyon state Globe state'inde tutulmuyor artık.
        // Öneriler panelini geri yükle
        if (s['recommendationsOpen'] == true) {
          _isRecommendationsPanelOpen = true;
        }
        _preGlobeState = null;
      }
    }
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

  void toggleShowCloudLayer() {
    _showCloudLayer = !_showCloudLayer;
    safeNotify();
  }

  void setCloudOpacity(double v) {
    _cloudOpacity = v.clamp(0.0, 1.0);
    safeNotify();
  }

  // --- Önerilen Bölgeler Panel Metodları ---

  void toggleRecommendationsPanel() {
    _isRecommendationsPanelOpen = !_isRecommendationsPanelOpen;
    if (_isRecommendationsPanelOpen) {
      // Faz 1 top-N (garantili veri — province_analysis tablosundan)
      if (_analysisWindTop == null && !_isLoadingAnalysisTop) {
        loadAnalysisTop();
      }
      // Opsiyonel: eski Weibull/ML kategorileri (varsa ek bilgi olarak)
      if (_recommendations == null && !_isLoadingRecommendations) {
        loadRecommendations();
      }
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
    _isProvinceModeActive  = false;
    _selectionLevel        = SelectionLevel.none;
    _initialSelectionMode  = SelectionLevel.none;
    _selectedRegionName    = null;
    _selectedProvinceName  = null;
    _selectedDistrictName  = null;
    safeNotify();
  }

  /// Bölge modunu aç/kapat. 7 bölgeyi doğrudan gösterir.
  void openRegionMode() {
    if (isRegionsModeActive) {
      closeSelectionMode();
      return;
    }
    _isProvinceModeActive  = true;
    _selectionLevel        = SelectionLevel.region;
    _initialSelectionMode  = SelectionLevel.region;
    _selectedRegionName    = null;
    _selectedProvinceName  = null;
    _selectedDistrictName  = null;
    _districtSummaries     = [];
    safeNotify();
    if (_regionSummaries.isEmpty) loadRegionSummaries();
  }

  /// İl modunu aç/kapat. Tüm 81 ili doğrudan gösterir.
  /// İle tıklayınca il bilgisi gösterilir ama harita il seviyesinde kalır →
  /// kullanıcı başka illere de tıklayabilir.
  void openProvincesMode() {
    if (_isProvinceModeActive && _selectionLevel == SelectionLevel.province) {
      closeSelectionMode();
      return;
    }
    _isProvinceModeActive  = true;
    _selectionLevel        = SelectionLevel.province;
    _initialSelectionMode  = SelectionLevel.province;
    _selectedRegionName    = null;
    _selectedProvinceName  = null;
    _selectedDistrictName  = null;
    _districtSummaries     = [];
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
    _isProvinceModeActive  = true;
    _selectionLevel        = SelectionLevel.district;
    _initialSelectionMode  = SelectionLevel.district;
    _selectedRegionName    = null;
    _selectedProvinceName  = null;
    _selectedDistrictName  = null;
    _districtSummaries     = [];
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
  /// Her 3 modda da (Bölge/İl/İlçe) il seçilince ilçeleri gösterir.
  /// `_initialSelectionMode` korunur — geri dönüşte hangi moda döneceğini bilir.
  void selectProvince(String provinceName) {
    _selectedProvinceName = provinceName;
    _selectedProvinceCode = null;
    _selectedDistrictName = null;
    _districtSummaries    = [];
    _selectionLevel       = SelectionLevel.district;
    safeNotify();
    loadDistrictSummaries(provinceName);
  }

  /// İlçe seçildi.
  /// [province]: İlçenin bağlı olduğu il adı (GeoJSON NAME_1 formatında, ör: "Uşak", "İstanbul").
  void selectDistrict(String districtName, {String? province}) {
    _selectedDistrictName = _mapDistrictName(districtName);

    if (province != null && province.isNotEmpty) {
      final needsLoad = _selectedProvinceName != province || _districtSummaries.isEmpty;
      _selectedProvinceName = province;
      if (needsLoad) {
        _districtSummaries = [];
        loadDistrictSummaries(province);
      }
    }

    safeNotify();
  }

  /// İlçe seçimini temizle (il seviyesinde kal, bölge korunur).
  void clearSelectedDistrict() {
    _selectedDistrictName = null;
    // selectionLevel stays at district (showing districts in province)
    safeNotify();
  }

  /// İl seçimini temizle → başlangıç moduna göre doğru seviyeye geri dön.
  void clearSelectedProvince() {
    _selectedProvinceName = null;
    _selectedProvinceCode = null;
    _selectedDistrictName = null;
    _districtSummaries    = [];
    // İl veya İlçe modunda → province seviyesine dön (tüm iller görünür)
    // Bölge modunda → province seviyesine dön (bölge filtresi korunur)
    _selectionLevel = SelectionLevel.province;
    safeNotify();
  }

  /// Bölge filtresini temizle → tüm iller gösterilir.
  void clearRegionFilter() {
    _selectedRegionName   = null;
    _selectedProvinceName = null;
    _selectedProvinceCode = null;
    _selectedDistrictName = null;
    _selectionLevel       = SelectionLevel.province;
    safeNotify();
  }

  /// Bölge seçimini temizle → il listesine geri dön (geriye dönük uyumluluk).
  void clearSelectedRegion() => clearRegionFilter();

  /// Tüm seçimi temizle → başlangıç moduna geri dön.
  void clearAllSelection() {
    _selectedRegionName   = null;
    _selectedProvinceName = null;
    _selectedProvinceCode = null;
    _selectedDistrictName = null;
    _districtSummaries    = [];
    // Başlangıç moduna geri dön
    if (_isProvinceModeActive) {
      _selectionLevel = _initialSelectionMode;
    } else {
      _selectionLevel = SelectionLevel.none;
    }
    safeNotify();
  }

  Future<void> loadProvinceSummaries({int hours = 168}) async {
    if (_isLoadingProvinceSummaries) return;
    _isLoadingProvinceSummaries = true;
    safeNotify();
    try {
      _provinceSummaries = await _apiService.weather.fetchProvinceSummary(
        hours: hours,
        // 1.C: tematik panel zaman seçimini takip et
        mode: apiMode == 'current' ? null : apiMode,
        season: apiSeason,
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
        mode: apiMode == 'current' ? null : apiMode,
        season: apiSeason,
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
        mode: apiMode == 'current' ? null : apiMode,
        season: apiSeason,
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

  /// Tüm hava durumu verilerini sıfırdan yükler.
  /// "Verileri Güncelle" butonu bu metodu çağırır.
  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  Future<void> refreshAllWeatherData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    safeNotify();
    try {
      // 1) Backend cache'ini atla — frontend cache'i temizle
      _apiService.weather.invalidateCache();

      // 2) Özet verileri yeniden yükle
      await _loadWeatherSummarySafe();

      // 3) Aktif choropleth varsa yeniden yükle
      // (1.A2: heatmap layer fetcher emekliye ayrıldı — choropleth tek görsel dil)
      await forceRefreshChoropleth();
    } catch (e) {
      debugPrint('[MapVM] refreshAllWeatherData error: $e');
    } finally {
      _isRefreshing = false;
      safeNotify();
    }
  }

  void _handleAuthChange() {
    if (_authViewModel.isLoggedIn == true) {
      unawaited(fetchPins());
    } else if (_authViewModel.isLoggedIn == false) {
      // Logout: tüm kullanıcıya ait verileri temizle
      _pins = [];
      _pinCityNames.clear();
      _equipments = [];
      _equipmentsLastFetch = null;
      notifyListeners();
    }
  }

  Future<void> loadEquipments({String? type, bool forceRefresh = false}) async {
    if (_equipmentsLoading) return;

    // If we have cached equipment, skip re-fetch unless forceRefresh AND stale (>5 min)
    if (_equipments.isNotEmpty) {
      if (!forceRefresh) return;
      if (_equipmentsLastFetch != null &&
          DateTime.now().difference(_equipmentsLastFetch!).inMinutes < 5) {
        return;
      }
    }

    _equipmentsLoading = true;
    notifyListeners();
    try {
      // Always fetch all equipment (no type filter); client-side filtering handles the rest
      _equipments = await _apiService.equipment.fetchEquipments();
      _equipmentsLastFetch = DateTime.now();
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
      // 2. Sonra eksik olanları API'den çek (await ile isim boş kalmasını önle)
      await _fetchMissingCityNames();
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

  Future<void> _fetchMissingCityNames() async {
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
    await _fetchCityNamesSequential(missing);
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

      // 1.A2: katman aktifse choropleth zaten kendi mode'undan refetch yapar;
      // eski heatmap fetcher (`fetchHeatmapDataForLayer`) emekliye ayrıldı.
    } catch (e) {
      debugPrint('Hava durumu yüklenirken hata: $e');
      _weatherData = [];
    }
    safeNotify();
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

  // ─── Faz 1 — Top-N Analiz (province_analysis tek kaynak) ────────────────────
  //
  // `/analysis/provinces` üzerinden 3 kaynak × konfigüre edilen horizon için
  // top-N il listesi çeker. Önerilen Bölgeler paneli bunu kullanır.

  List<ProvinceAnalysisItem>? _analysisWindTop;
  List<ProvinceAnalysisItem>? _analysisSolarTop;
  List<ProvinceAnalysisItem>? _analysisHydroTop;
  AnalysisHorizon _analysisHorizon = AnalysisHorizon.m6;
  bool _isLoadingAnalysisTop = false;
  String? _analysisTopError;

  List<ProvinceAnalysisItem>? get analysisWindTop => _analysisWindTop;
  List<ProvinceAnalysisItem>? get analysisSolarTop => _analysisSolarTop;
  List<ProvinceAnalysisItem>? get analysisHydroTop => _analysisHydroTop;
  AnalysisHorizon get analysisHorizon => _analysisHorizon;
  bool get isLoadingAnalysisTop => _isLoadingAnalysisTop;
  String? get analysisTopError => _analysisTopError;

  /// Top-N analiz listelerini (rüzgar + güneş + hidro) paralel çeker.
  Future<void> loadAnalysisTop({
    AnalysisHorizon horizon = AnalysisHorizon.m6,
    int limit = 10,
  }) async {
    if (_isLoadingAnalysisTop) return;
    _analysisHorizon = horizon;
    _isLoadingAnalysisTop = true;
    _analysisTopError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.analysis.fetchProvinces(
          type: AnalysisResourceType.wind,
          horizon: horizon,
          limit: limit,
        ),
        _apiService.analysis.fetchProvinces(
          type: AnalysisResourceType.solar,
          horizon: horizon,
          limit: limit,
        ),
        _apiService.analysis.fetchProvinces(
          type: AnalysisResourceType.hydro,
          horizon: horizon,
          limit: limit,
        ),
      ]);
      _analysisWindTop = results[0].items;
      _analysisSolarTop = results[1].items;
      _analysisHydroTop = results[2].items;
    } catch (e) {
      debugPrint('[MapViewModel.loadAnalysisTop] Hata: $e');
      _analysisTopError = e.toString();
    } finally {
      _isLoadingAnalysisTop = false;
      notifyListeners();
    }
  }

  /// Horizon'u değiştirir ve listeleri yeniden çeker.
  Future<void> setAnalysisHorizon(AnalysisHorizon horizon) async {
    if (_analysisHorizon == horizon) return;
    await loadAnalysisTop(horizon: horizon);
  }

  void clearAnalysisTop() {
    _analysisWindTop = null;
    _analysisSolarTop = null;
    _analysisHydroTop = null;
    _analysisTopError = null;
    notifyListeners();
  }
}

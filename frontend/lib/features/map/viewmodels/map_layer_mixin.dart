import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/features/map/layers/map_layers_system.dart';

mixin MapLayerMixin on BaseViewModel {
  // Abstract dependency
  ApiService get apiService;

  /// Aynı frame içindeki tüm safeNotify() çağrılarını tek bir notifyListeners()'a
  /// indirger. Pointer event (tap/hover) sırasında widget tree mutasyonunu önler
  /// (mouse_tracker re-entrant assertion fix).
  bool _notifyScheduled = false;

  void safeNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      // BaseViewModel._disposed kontrolü notifyListeners() içinde yapılır,
      // ama callback schedule edildikten sonra dispose olmuş olabilir.
      notifyListeners();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  MapLayerType _currentLayer = MapLayerType.none;
  List<Map<String, dynamic>> _interpolatedData = [];
  // 1.A2: heatmap loading state silindi (fetcher no-op).

  // heatmapPoints cache — _interpolatedData değişince yenilenir,
  // aksi hâlde aynı List referansı döner → MapLayerWidget gereksiz
  // yeniden hesaplama yapmaz (didUpdateWidget: data != oldData = false).
  List<HeatmapPoint>? _heatmapPointsCache;

  // 1.A2: heatmap layer cache (eski IDW point veri seti) emekliye ayrıldı —
  // tek görsel dil ilçe choropleth (`_choroplethData` + `_choroplethCacheTime`).
  // Cache field'ları (`_layerDataCache`, `_layerCacheTime`, `_layerCacheTtl`)
  // silindi; setWeatherTimeMode bunlara ihtiyaç duymuyor artık.

  // ─── Rüzgar Parçacık + Yükseklik Katmanı State ──────────────────────────
  bool _showWindParticles = false;
  bool _isWindLoading = false;
  bool _windDataEmpty = false;
  bool _showElevation = false;
  WindParticleQuality _windQuality = WindParticleQuality.balanced;
  List<WindVector> _windVectors = [];

  static const _qualityKey = 'wind_particle_quality';

  bool get showWindParticles => _showWindParticles;
  bool get isWindLoading => _isWindLoading;
  bool get windDataEmpty => _windDataEmpty;
  bool get showElevation => _showElevation;
  WindParticleQuality get windQuality => _windQuality;
  List<WindVector> get windVectors => _windVectors;
  // ──────────────────────────────────────────────────────────────────────────

  MapLayerType get currentLayer => _currentLayer;

  // --- HEATMAP İÇİN VERİ DÖNÜŞÜMÜ ---
  /// Cache'li getter: _interpolatedData değişmediği sürece
  /// aynı List[HeatmapPoint] referansını döndürür.
  /// Böylece MapLayerWidget.didUpdateWidget her rebuild'de
  /// _generateLayerPicture() tetiklemez.
  List<HeatmapPoint> get heatmapPoints => _heatmapPointsCache ?? [];

  void _rebuildHeatmapCache() {
    if (_interpolatedData.isEmpty) {
      _heatmapPointsCache = [];
      return;
    }
    _heatmapPointsCache = _interpolatedData.map((d) => HeatmapPoint(
      latitude: (d['lat'] as num).toDouble(),
      longitude: (d['lon'] as num).toDouble(),
      value: (d['value'] as num).toDouble(),
    )).toList();
  }

  /// Animasyon motoru tarafından çağrılır (standard harita).
  ///
  /// **1.A2 itibarıyla davranış:** Heatmap (IDW point) render'ı emekliye
  /// ayrıldı. Bu metot artık `_interpolatedData`'yı doldurmaz — sadece
  /// `_currentLayer` state'ini günceller (legend / overlay'lerin animasyon
  /// metric'inden haberdar olması için). Animasyon görüntüsü il-key'li
  /// choropleth path'inden gelir (`_animProvinceValues` map_viewmodel'da).
  ///
  /// 1.A2.c kapsamında animasyon backend payload'ı ilçe-key'e taşındığında
  /// burası tamamen kaldırılacak.
  void setAnimFrameData(
    List<dynamic> pts,
    MapLayerType layerType,
    double metricMin,
    double metricMax,
  ) {
    if (_interpolatedData.isNotEmpty) {
      _interpolatedData = [];
      _rebuildHeatmapCache();
    }
    _currentLayer = layerType;
    // notifyListeners() caller'ın sorumluluğunda (safeNotify ile çağrılır)
  }

  /// Katman seçimi — 1.A2 itibarıyla **choropleth bridge**.
  ///
  /// Eski heatmap fetch zinciri (IDW noktalı) emekliye ayrıldı; aynı seçim
  /// artık ilçe tematik haritasını tetikler. `MapLayerType` state'i animasyon
  /// engine + legend gibi yerlerin geri uyumluluğu için korunur ama görsel dil
  /// tek: choropleth.
  void setLayer(MapLayerType layer) {
    if (_currentLayer == layer) return;
    _currentLayer = layer;
    // Heatmap fetcher artık no-op (aşağıda açıklamalı). Görsel: choropleth.
    setChoroplethMode(layer.toChoropleth);
    safeNotify();
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

  /// **DEPRECATED (1.A2)** — Heatmap (IDW interpolated point) fetcher artık no-op.
  ///
  /// Tek görsel dil olarak ilçe choropleth seçildi (`setLayer` → `setChoroplethMode`
  /// köprüsü). Bu metot signature geri uyumluluk için korunur; çağrıldığında
  /// sadece state'i temiz tutar (`_interpolatedData = []`) ve heatmap render
  /// path'lerinin boş veri görmesini sağlar.
  ///
  /// 1.A2.b kapsamında kullanan yerler temizlenince bu metot ve ilgili
  /// (`_interpolatedData`, `_layerDataCache`, `MapLayerWidget`) silinecek.
  Future<void> fetchHeatmapDataForLayer(
    MapLayerType layer, {
    bool forceRefresh = false,
  }) async {
    if (_interpolatedData.isNotEmpty) {
      _interpolatedData = [];
      _rebuildHeatmapCache();
      safeNotify();
    }
  }

  // ─── Rüzgar Parçacık Katmanı Metodları ──────────────────────────────────

  Future<void> loadWindPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt(_qualityKey);
      if (idx != null && idx < WindParticleQuality.values.length) {
        _windQuality = WindParticleQuality.values[idx];
      }
    } catch (e) {
      debugPrint('Wind preferences load error: $e');
    }
  }

  Future<void> toggleWindParticles(bool val) async {
    _showWindParticles = val;
    if (val && _windVectors.isEmpty) {
      await _fetchWindVectors();
    } else {
      safeNotify();
    }
  }

  void toggleElevation(bool val) {
    _showElevation = val;
    safeNotify();
  }

  Future<void> setWindQuality(WindParticleQuality q) async {
    _windQuality = q;
    safeNotify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_qualityKey, q.index);
    } catch (e) {
      debugPrint('Wind quality save error: $e');
    }
  }

  /// MapLibre rüzgar okları için de kullanılır.
  Future<void> loadWindVectors() => _fetchWindVectors();

  Future<void> _fetchWindVectors() async {
    _isWindLoading = true;
    _windDataEmpty = false;
    safeNotify();
    try {
      final data = await apiService.windVector.fetchWindVectors(
        mode: _apiMode,
        season: _apiSeason,
      );
      _windVectors = data.map((d) => WindVector.fromJson(d)).toList();
      _windDataEmpty = _windVectors.isEmpty;
    } catch (e) {
      debugPrint('Wind vectors fetch error: $e');
      _windDataEmpty = true;
    } finally {
      _isWindLoading = false;
      notifyListeners();
    }
  }

  // ─── Choropleth (İlçe Tematik Harita) Katmanı ────────────────────────────

  ChoroplethMode _choroplethMode = ChoroplethMode.none;
  Map<String, dynamic>? _choroplethData; // {"il|ilçe": {wind, solar, temp}}
  DateTime? _choroplethCacheTime;
  bool _isChoroplethLoading = false;
  static const Duration _choroplethCacheTtl = Duration(minutes: 10);

  // ─── Animation → Choropleth bridge (1.A2.c) ──────────────────────────────
  // Zaman simülasyonu kullanıcının seçtiği metric için ilçe choropleth'ini
  // her frame'de override eder. Animasyon kapanınca `_animChoroplethBackup`
  // restore edilir (kullanıcı animation öncesi choropleth durumuna döner).
  Map<String, dynamic>? _animChoroplethBackup;
  ChoroplethMode? _animChoroplethModeBackup;
  bool _animationOverridesChoropleth = false;
  bool get isAnimationOverridingChoropleth => _animationOverridesChoropleth;

  // Tematik katmanın zaman penceresi modu — WeatherTimeModeProvider tarafından
  // yönetilir; UI panel seçiciyi değiştirdiğinde `setWeatherTimeMode()` çağrılır
  // ve choropleth verisi yeni mode/season ile refetch edilir.
  // 2026-06-10 (default-period fix): WeatherTimeModeProvider default'u 'week'
  // (chip "Hafta · son 7 gün"). Burası 'current' idi → ilk açılışta chip "Hafta"
  // gösterirken veri son-saat snapshot'ı (gece/eksik saat = boşluklu) geliyordu.
  // 'week' ile hizalandı: ilk fetch 7-gün ortalaması (solar=günlük peak avg).
  String _apiMode = 'week';
  String? _apiSeason;

  String get apiMode => _apiMode;
  String? get apiSeason => _apiSeason;

  ChoroplethMode get choroplethMode => _choroplethMode;
  bool get isChoroplethLoading => _isChoroplethLoading;
  Map<String, dynamic>? get choroplethData => _choroplethData;

  /// Choropleth verisinin hangi zamana ait olduğu (backend'den gelen _meta bilgisi).
  String? get choroplethDataTimestamp {
    final meta = _choroplethData?['_meta'];
    if (meta is Map) {
      return meta['data_timestamp'] as String?;
    }
    return null;
  }

  // ─── Choropleth Tooltip (tıklanan ilçe verisi) ──────────────────────────
  String? _choroplethTapDistrict;   // "İstanbul / Kadıköy"
  Map<String, dynamic>? _choroplethTapData; // {wind, solar, temp}
  Color? _choroplethTapColor;       // Haritadaki dolgu rengi

  String? get choroplethTapDistrict => _choroplethTapDistrict;
  Map<String, dynamic>? get choroplethTapData => _choroplethTapData;
  Color? get choroplethTapColor => _choroplethTapColor;

  /// Haritada bir ilçeye tıklandığında choropleth verisini tooltip olarak gösterir.
  void setChoroplethTap(String province, String district) {
    if (_choroplethMode == ChoroplethMode.none || _choroplethData == null) return;
    final key = '$province|$district';
    final entry = _choroplethData![key];
    if (entry is Map<String, dynamic>) {
      _choroplethTapDistrict = '$province / $district';
      _choroplethTapData = entry;
      _choroplethTapColor = _computeChoroplethColor(
        _choroplethMode, entry, _choroplethData!,
      );
    } else {
      _choroplethTapDistrict = '$province / $district';
      _choroplethTapData = null;
      _choroplethTapColor = null;
    }
    safeNotify();
  }

  /// Tooltip'i kapat.
  void clearChoroplethTap() {
    if (_choroplethTapDistrict == null) return;
    _choroplethTapDistrict = null;
    _choroplethTapData = null;
    _choroplethTapColor = null;
    safeNotify();
  }

  /// Choropleth verisi ve mod bazında hex rengi hesaplar (haritadaki dolgu ile aynı).
  static Color? _computeChoroplethColor(
    ChoroplethMode mode,
    Map<String, dynamic> entry,
    Map<String, dynamic> allData,
  ) {
    final dataKey = mode.dataKey;
    final value = (entry[dataKey] as num?)?.toDouble();
    if (value == null || value == 0.0) return null;

    // ── Sabit fiziksel skala — haritayla birebir aynı ──────────
    List<List<dynamic>> physicalRamp;
    if (dataKey == 'solar') {
      // 2026-05-19 — ters çevrildi: gece=koyu, çok güneş=parlak sarı.
      physicalRamp = [
        [0,0x1a1a2e],[50,0x4D0014],[150,0xBD0026],[250,0xE31A1C],
        [350,0xFC4E2A],[450,0xFD8D3C],[550,0xFEB24C],[650,0xFED976],
        [750,0xFFEDA0],[800,0xFFFFCC]];
    } else if (dataKey == 'wind') {
      physicalRamp = [
        [0,0xF7FBFF],[2,0xDEEBF7],[4,0xC6DBEF],[6,0x9ECAE1],
        [8,0x6BAED6],[10,0x4292C6],[13,0x2171B5],[16,0x08519C],
        [20,0x083D7F],[25,0x08306B]];
    } else {
      physicalRamp = [
        [-15,0x08306B],[-5,0x2171B5],[0,0xE0F3F8],[5,0xC6DBEF],
        [10,0xABD9E9],[15,0x74ADD1],[20,0x66BD63],[25,0xA6D96A],
        [30,0xFEE08B],[33,0xFDAE61],[36,0xF46D43],[40,0xD73027],
        [45,0xA50026]];
    }

    final physMin = (physicalRamp.first[0] as num).toDouble();
    final physMax = (physicalRamp.last[0] as num).toDouble();
    final physRange = physMax - physMin;

    final List<List<dynamic>> ramp = [];
    for (final stop in physicalRamp) {
      final v = (stop[0] as num).toDouble();
      ramp.add([(v - physMin) / physRange, stop[1]]);
    }
    final t = ((value - physMin) / physRange).clamp(0.0, 1.0);

    // En yakın stop bul
    int colorHex = ramp.last[1] as int;
    for (int i = 0; i < ramp.length - 1; i++) {
      final t0 = ramp[i][0] as double;
      final t1 = ramp[i + 1][0] as double;
      if (t >= t0 && t <= t1) {
        colorHex = (t - t0 <= t1 - t) ? ramp[i][1] as int : ramp[i + 1][1] as int;
        break;
      }
    }

    return Color(0xFF000000 | colorHex);
  }

  /// Mevcut choropleth modunu cache'i sıfırlayarak yeniden yükler.
  Future<void> forceRefreshChoropleth() async {
    if (_choroplethMode == ChoroplethMode.none) return;
    _choroplethCacheTime = null;
    final prev = _choroplethMode;
    _choroplethMode = ChoroplethMode.none;
    await setChoroplethMode(prev);
  }

  /// Tematik harita zaman modu değiştiğinde UI tarafından çağrılır.
  /// Aynı mod tekrar gelirse no-op.
  ///
  /// Yeni mode tüm hava-türevi katmanları etkiler:
  /// - Choropleth (ilçe tematik harita) — aktifse otomatik refetch
  /// - Heatmap (Rüzgar/Sıcaklık/Işınım katmanı) — aktifse otomatik refetch
  /// - Rüzgar partikülleri — aktifse otomatik refetch
  ///
  /// Tüm ilgili cache'ler invalidate edilir, çünkü farklı mod farklı veri demek.
  Future<void> setWeatherTimeMode(String mode, String? season) async {
    if (_apiMode == mode && _apiSeason == season) return;
    _apiMode = mode;
    _apiSeason = season;
    // İlgili cache'leri invalidate et — yeni mode yeni veri demek
    _choroplethCacheTime = null;
    safeNotify();

    final futures = <Future<void>>[];
    if (_choroplethMode != ChoroplethMode.none) {
      futures.add(_fetchChoroplethData());
    }
    // Heatmap fetcher (1.A2 itibarıyla no-op) artık çağrılmıyor —
    // `_currentLayer` choropleth bridge ile zaten `_choroplethMode` set etti.
    if (_showWindParticles) {
      futures.add(_fetchWindVectors());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> setChoroplethMode(ChoroplethMode mode) async {
    if (_choroplethMode == mode) return;
    _choroplethMode = mode;
    // Mod değiştiğinde tooltip'i temizle
    _choroplethTapDistrict = null;
    _choroplethTapData = null;
    safeNotify();

    if (mode == ChoroplethMode.none) return;

    // Veri yüklenmemişse veya cache süresi dolmuşsa fetch et
    final cacheValid = _choroplethData != null &&
        _choroplethCacheTime != null &&
        DateTime.now().difference(_choroplethCacheTime!) < _choroplethCacheTtl;

    if (!cacheValid) {
      await _fetchChoroplethData();
    }
  }

  Future<void> _fetchChoroplethData() async {
    _isChoroplethLoading = true;
    safeNotify();
    try {
      // Kullanıcının seçtiği zaman modunu gönder:
      //  - current (default): her ilçenin son saati — anlık
      //  - yearly: 365 gün ortalaması — iklimsel GES potansiyeli
      //  - season: 365 gün + mevsim ay filtresi
      final data = await apiService.weather.fetchDistrictChoropleth(
        mode: _apiMode,
        season: _apiSeason,
      );
      if (data.isNotEmpty) {
        _choroplethData = data;
        _choroplethCacheTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('[Choropleth] Veri yüklenemedi: $e');
    } finally {
      _isChoroplethLoading = false;
      safeNotify();
    }
  }

  // ─── Animation → Choropleth bridge metodları ─────────────────────────────

  /// `wind|temperature|radiation` → ChoroplethMode + data field key.
  static (ChoroplethMode, String) _animMetricToChoropleth(String metric) {
    switch (metric) {
      case 'wind':
        return (ChoroplethMode.wind, 'wind');
      case 'temperature':
        return (ChoroplethMode.temperature, 'temp');
      case 'radiation':
      default:
        return (ChoroplethMode.solar, 'solar');
    }
  }

  /// Animasyon başlatıldığında orijinal choropleth state'i yedekle.
  /// `applyAnimationFrameToChoropleth` ilk çağrıda otomatik tetiklenir.
  void _backupChoroplethForAnimation() {
    if (_animationOverridesChoropleth) return; // zaten yedekli
    _animChoroplethBackup = _choroplethData;
    _animChoroplethModeBackup = _choroplethMode;
    _animationOverridesChoropleth = true;
  }

  /// Animasyonun her frame'inde çağrılır. `vals` map'i (`"İl|İlçe": rawValue`)
  /// choropleth `_choroplethData`'sına metric-key'iyle yazılır; render path'i
  /// (web + native) `_choroplethData` değişimini izleyip polygon renklerini
  /// yeniler.
  void applyAnimationFrameToChoropleth({
    required String metric,
    required Map<String, double> vals,
  }) {
    if (vals.isEmpty) return;
    _backupChoroplethForAnimation();

    final (mode, dataKey) = _animMetricToChoropleth(metric);
    if (_choroplethMode != mode) {
      _choroplethMode = mode;
    }

    // {"İl|İlçe": {"wind": v, "solar": null, "temp": null}}
    final next = <String, dynamic>{};
    vals.forEach((key, v) {
      next[key] = <String, dynamic>{
        'wind': dataKey == 'wind' ? v : null,
        'solar': dataKey == 'solar' ? v : null,
        'temp': dataKey == 'temp' ? v : null,
      };
    });
    // Frame timestamp meta — render path'inin "veri taze" görmesi için
    next['_meta'] = <String, dynamic>{
      'data_timestamp': DateTime.now().toIso8601String(),
      'animation': true,
      'metric': metric,
    };
    _choroplethData = next;
    safeNotify();
  }

  /// Animasyon kapandığında orijinal choropleth state'i geri yükler.
  /// Restore sonrası backup temizlenir.
  void restoreChoroplethFromAnimation() {
    if (!_animationOverridesChoropleth) return;
    _choroplethData = _animChoroplethBackup;
    if (_animChoroplethModeBackup != null) {
      _choroplethMode = _animChoroplethModeBackup!;
    }
    _animChoroplethBackup = null;
    _animChoroplethModeBackup = null;
    _animationOverridesChoropleth = false;
    safeNotify();
  }
}

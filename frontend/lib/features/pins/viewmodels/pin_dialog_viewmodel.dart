// presentation/features/pins/viewmodels/pin_dialog_viewmodel.dart
//
// Sorumluluk: Pin dialog state ve business logic yönetimi
// UI'dan tamamen bağımsız, test edilebilir

import 'package:flutter/foundation.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

/// Pin dialog için ViewModel - UI state ve business logic burada
class PinDialogViewModel extends ChangeNotifier {
  final MapViewModel _mapViewModel;

  // State
  String _selectedType;
  int? _selectedEquipmentId;
  double _panelArea = 10.0; // Default 10 m2
  double _flowRate = 0.0;
  double _headHeight = 0.0;
  double _basinAreaKm2 = 0.0;
  bool _isSubmitting = false;
  String? _errorMessage;

  // 2026-05-17 Sprint B — Gelişmiş Ayarlar manuel parametre alanları.
  // Backend ile uyum: Sprint A migration sonrasında bu field'lar
  // pin payload'una eklenecek (panel_tilt, panel_azimuth, panel_power_w,
  // hub_height, rotor_diameter, rated_power_kw). Şu an stub — backend'siz
  // çalışır, save'de payload'a ek alanlar gönderilir; backend bilmiyorsa
  // sessizce yok sayar.
  // GES (Güneş Paneli)
  double? _panelTilt;          // Panel eğim açısı (°), 0–90
  double? _panelAzimuth;       // Panel azimuth (°), 0–360 (180=güney)
  double? _panelPowerW;        // Tek panel rated power (W)
  // RES (Rüzgar Türbini)
  double? _hubHeight;          // Kule yüksekliği (m)
  double? _rotorDiameter;      // Rotor çapı / kanat uzunluğu × 2 (m)
  double? _ratedPowerKw;       // Türbin nominal güç (kW)

  // Constructor
  // 2026-05-17 fix: MapViewModel.equipments listesi (kullanıcının yeni
  // eklediği ekipman vs.) değiştiğinde dropdown'un rebuild olması için
  // mapViewModel'i listen ediyoruz. Aksi halde availableEquipments getter
  // güncel veri döner ama widget rebuild tetiklenmez.
  PinDialogViewModel(
    this._mapViewModel,
    String initialType, {
    int? initialEquipmentId,
  }) : _selectedType = initialType,
       _selectedEquipmentId = initialEquipmentId {
    _mapViewModel.addListener(_onMapViewModelChanged);
  }

  void _onMapViewModelChanged() {
    if (_isDisposed) return;
    notifyListeners();
  }


  // Getters
  String get selectedType => _selectedType;
  int? get selectedEquipmentId => _selectedEquipmentId;
  double get panelArea => _panelArea;
  double get flowRate => _flowRate;
  double get headHeight => _headHeight;
  double get basinAreaKm2 => _basinAreaKm2;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  // Advanced parametre getter'ları (Sprint B)
  double? get panelTilt => _panelTilt;
  double? get panelAzimuth => _panelAzimuth;
  double? get panelPowerW => _panelPowerW;
  double? get hubHeight => _hubHeight;
  double? get rotorDiameter => _rotorDiameter;
  double? get ratedPowerKw => _ratedPowerKw;

  /// Frontend tip adını backend equipment type'a çevir
  String get _backendEquipmentType {
    switch (_selectedType) {
      case 'Güneş Paneli': return 'Solar';
      case 'Rüzgar Türbini': return 'Wind';
      case 'HES': return 'Hydro';
      default: return 'Solar';
    }
  }

  /// Frontend tip adını backend pin type'a çevir
  /// Backend 'Hidroelektrik' bekler, frontend 'HES' gösterir
  String get backendType {
    if (_selectedType == 'HES') return 'Hidroelektrik';
    return _selectedType; // 'Güneş Paneli' ve 'Rüzgar Türbini' aynı kalır
  }

  /// Backend'den gelen tipi frontend display tipine çevir
  static String toDisplayType(String backendType) {
    if (backendType == 'Hidroelektrik') return 'HES';
    return backendType;
  }

  List<Equipment> get availableEquipments {
    return _mapViewModel.equipments.where((e) => e.type == _backendEquipmentType).toList();
  }

  bool get isLoadingEquipments => _mapViewModel.equipmentsLoading;
  bool get hasEquipments => availableEquipments.isNotEmpty;
  // HES için ekipman seçimi opsiyonel (debi/havza alanı yeterli)
  bool get canSubmit {
    if (_selectedType == 'HES') {
      return !_isSubmitting; // HES için ekipman zorunlu değil
    }
    return _selectedEquipmentId != null && !_isSubmitting;
  }

  // Actions
  void setPanelArea(String val) {
    if (val.isEmpty) return;
    final parsed = double.tryParse(val);
    if (parsed != null && parsed > 0) {
      _panelArea = parsed;
      notifyListeners();
    }
  }

  void setFlowRate(String val) {
    if (val.isEmpty) return;
    final parsed = double.tryParse(val);
    if (parsed != null && parsed >= 0) {
      _flowRate = parsed;
      notifyListeners();
    }
  }

  void setHeadHeight(String val) {
    if (val.isEmpty) return;
    final parsed = double.tryParse(val);
    if (parsed != null && parsed >= 0) {
      _headHeight = parsed;
      notifyListeners();
    }
  }

  void setBasinArea(String val) {
    if (val.isEmpty) return;
    final parsed = double.tryParse(val);
    if (parsed != null && parsed >= 0) {
      _basinAreaKm2 = parsed;
      notifyListeners();
    }
  }

  void changeType(String newType) {
    if (_selectedType != newType) {
      _selectedType = newType;
      _selectedEquipmentId = null; // Reset selection
      _loadEquipments();
      notifyListeners();
    }
  }

  // ─── Advanced parametre setter'ları (Sprint B) ──────────────────────────
  // Hepsi `String` alır (text field onChanged), boş veya geçersiz değerse
  // null'a düşer (= "kullanıcı doldurmadı, hesap default'a düşer").

  double? _parseOptional(String val) {
    if (val.trim().isEmpty) return null;
    return double.tryParse(val.replaceAll(',', '.'));
  }

  void setPanelTilt(String val)     { _panelTilt     = _parseOptional(val); notifyListeners(); }
  void setPanelAzimuth(String val)  { _panelAzimuth  = _parseOptional(val); notifyListeners(); }
  void setPanelPowerW(String val)   { _panelPowerW   = _parseOptional(val); notifyListeners(); }
  void setHubHeight(String val)     { _hubHeight     = _parseOptional(val); notifyListeners(); }
  void setRotorDiameter(String val) { _rotorDiameter = _parseOptional(val); notifyListeners(); }
  void setRatedPowerKw(String val)  { _ratedPowerKw  = _parseOptional(val); notifyListeners(); }

  /// Pin edit modunda mevcut değerleri seed et (PinDetailsDialog._enterEditMode).
  void seedAdvanced({
    double? panelTilt,
    double? panelAzimuth,
    double? panelPowerW,
    double? hubHeight,
    double? rotorDiameter,
    double? ratedPowerKw,
  }) {
    _panelTilt = panelTilt;
    _panelAzimuth = panelAzimuth;
    _panelPowerW = panelPowerW;
    _hubHeight = hubHeight;
    _rotorDiameter = rotorDiameter;
    _ratedPowerKw = ratedPowerKw;
    notifyListeners();
  }

  void selectEquipment(int equipmentId) {
    _selectedEquipmentId = equipmentId;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _mapViewModel.removeListener(_onMapViewModelChanged);
    super.dispose();
  }

  // Business Logic
  Future<void> loadInitialData() async {
    // Load all equipment once; availableEquipments getter filters by type client-side
    await _mapViewModel.loadEquipments(forceRefresh: false);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _loadEquipments() async {
    // No type filter or forceRefresh — use cached equipment, filter client-side
    await _mapViewModel.loadEquipments(forceRefresh: false);
    if (!_isDisposed) notifyListeners();
  }

  /// Validation - Returns error message or null if valid.
  ///
  /// 2026-05-25 (P2/6): "Yeni Kaynak 0.0 MW" pin'lerini engelle. Pinlerim
  /// listesinde "0.0 MW · Ankara" gibi anlamsız kayıtlar görülüyordu —
  /// kullanıcı capacity'i hesaplanabilecek parametreyi girmeden submit
  /// ediyordu. Her tip için minimum eşik:
  ///   - GES: panel_area ≥ 10 m² (≈ 2 kW minimum)
  ///   - RES: equipment seçilmeli (zaten kontrol vardı)
  ///   - HES: flow_rate ve head_height > 0 (önceden tolere ediliyordu →
  ///     1.0 MW fallback giriyor, kullanıcı farkında olmadan sabit değer
  ///     atılıyordu)
  /// Ayrıca calculated capacityMw < 0.001 → reddet.
  String? validate() {
    if (_selectedType == 'HES') {
      if (_flowRate <= 0) {
        return 'HES için debi (m³/s) giriniz';
      }
      if (_headHeight <= 0) {
        return 'HES için düşü yüksekliği (m) giriniz';
      }
      final cap = getSelectedCapacityMw();
      if (cap == null || cap < 0.001) {
        return 'Hesaplanan kapasite çok düşük (< 1 kW). Debi/yüksekliği artırın.';
      }
      return null;
    }
    if (_selectedType == 'Güneş Paneli') {
      if (_panelArea <= 0) {
        return 'GES için panel alanı (m²) giriniz';
      }
      if (_panelArea < 10) {
        return 'Panel alanı en az 10 m² olmalı (~2 kW)';
      }
      if (_selectedEquipmentId == null && !hasEquipments) {
        return 'Model bulunamadı';
      }
      final cap = getSelectedCapacityMw();
      if (cap == null || cap < 0.001) {
        return 'Hesaplanan kapasite çok düşük (< 1 kW)';
      }
      return null;
    }
    // RES (Rüzgar Türbini)
    if (_selectedEquipmentId == null) {
      return 'Lütfen bir türbin modeli seçin';
    }
    if (!hasEquipments) {
      return 'Model bulunamadı';
    }
    final cap = getSelectedCapacityMw();
    if (cap == null || cap < 0.001) {
      return 'Türbin kapasitesi tanımsız (< 1 kW)';
    }
    return null;
  }

  /// 2026-05-19 Bug 3 fix — Pin'in gerçek capacity_mw'si.
  /// **Eski davranış:** GES için de RES için de `equipment.ratedPowerKw / 1000`
  /// yapıyordu — sonuç: GES pin'leri 1 panel (275 W = 0.000275 MW) capacity'li
  /// kayıt olunca generation hesabı 1000× düşük çıkıyordu. Test 7 sonucu:
  /// "Samsun GES 0.45kW capacity, aylık 22 kWh" — yanlış (gerçek tesis MW
  /// seviyesinde olmalıydı).
  ///
  /// **Doğru formüller:**
  /// - **GES:** `panel_area × efficiency × 1 kW/m² (STC)` →
  ///   100 m² × %17 × 1 kW/m² = 17 kW = 0.017 MW.
  ///   Equipment seçiliyse `equipment.efficiency` kullan, yoksa 0.20 default.
  /// - **RES:** Tek türbinin nominal güç (kullanıcı pin başına 1 türbin koyar).
  ///   `equipment.ratedPowerKw / 1000` (aynı).
  /// - **HES:** `P = ρ × g × Q × H × η`. Türkiye için pratik:
  ///   `kW ≈ 8.5 × flow_rate (m³/s) × head_height (m)`.
  ///   Verisi yoksa fallback 1.0 MW.
  double? getSelectedCapacityMw() {
    if (_selectedType == 'HES') {
      // Hidroelektrik fiziksel formül: P = ρgQH × η
      // ρ=1000 kg/m³, g=9.81 m/s², η=0.85 (modern türbin)
      // → kW = 9.81 × 0.85 × Q × H / 1 = 8.34 × Q × H
      // Yuvarlak: kW ≈ 8.5 × Q × H
      // 2026-05-25 (P2/6): Eski "1.0 MW fallback" silindi — validate() artık
      // flowRate + headHeight zorunlu kılıyor, fallback unreachable + kullanıcı
      // farkında olmadan sabit 1.0 MW pin'i oluşmasını engelliyor.
      if (_flowRate > 0 && _headHeight > 0) {
        final kw = 8.5 * _flowRate * _headHeight;
        return kw / 1000;  // MW
      }
      return null;
    }

    if (_selectedType == 'Güneş Paneli') {
      // GES: capacity = panel_area × verim × 1 kW/m² (STC)
      // Equipment seçiliyse onun efficiency'si, yoksa default 0.20
      double efficiency = 0.20;
      if (_selectedEquipmentId != null) {
        try {
          final eq = availableEquipments.firstWhere(
            (e) => e.id == _selectedEquipmentId,
          );
          if (eq.efficiency != null && eq.efficiency! > 0) {
            efficiency = eq.efficiency!;
          }
        } catch (_) {}
      }
      // _panelArea m² × verim × 1 kW/m² = kW
      final kw = _panelArea * efficiency;
      return kw / 1000; // MW
    }

    // Rüzgar Türbini — kullanıcı pin başına 1 türbin koyar.
    if (_selectedEquipmentId == null) return null;
    try {
      final equipment = availableEquipments.firstWhere(
        (e) => e.id == _selectedEquipmentId,
      );
      return equipment.ratedPowerKw / 1000;
    } catch (e) {
      return null;
    }
  }

  /// Submit calculation
  Future<bool> calculatePotential({
    required double lat,
    required double lon,
    required double panelArea,
  }) async {
    final validationError = validate();
    if (validationError != null) {
      _errorMessage = validationError;
      if (!_isDisposed) notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      final capacityMw = getSelectedCapacityMw();
      if (capacityMw == null) {
        throw Exception('Kapasite hesaplanamadı');
      }

      await _mapViewModel.calculatePotential(
        lat: lat,
        lon: lon,
        type: _selectedType,
        capacityMw: capacityMw,
        panelArea: panelArea,
      );

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      if (!_isDisposed) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }
}

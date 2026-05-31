// lib/features/pins/controllers/pin_flow_controller.dart
//
// 2026-05-09 Strategic Reset — Pin Flow State Machine
// ============================================================================
// 6 sprint boyunca pin akışı kümülatif yamalama ile karmaşıklaştı (8+ state
// field, 3 ayrı pop-up, 2 farklı placing API). Bu controller tek source of
// truth — pin lifecycle'ının her aşaması burada yönetilir.
//
// Bkz: [[PinFlowAudit]] vault notu — mevcut karmaşa fotoğrafı + spec.
//
// State Machine:
//   idle ──enterPlacing()──> placing
//   placing ──onMapTap(p)──> typeSelection(p)
//   typeSelection ──selectType(t)──> addForm(p, t)
//   addForm ──savedOrCancelled──> idle
//   idle ──openPinDetail(pin)──> detail(pin)
//   detail ──openPinDetail(pin2)──> detail(pin2)  [pinler arası geçiş]
//   detail ──enterEditMode()──> editForm(pin)
//   editForm ──savedOrCancelled──> detail / idle
//   anyMode ──close()──> idle
//
// Önemli karar: bu controller MapViewModel'i dispatch etmek için DIŞARDA
// kullanılır (caller `setMvtLayers` makro vs çağırır). Controller VM'e
// directly bağımlı değil — sadece anchor recompute için geçici dependency.

import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/widgets/map_view_maplibre.dart';

enum PinFlowMode {
  idle,
  placing,
  typeSelection,
  addForm,
  detail,
  editForm,
}

class PinFlowController extends ChangeNotifier {
  PinFlowController(this._mapVM);

  // VM dependency — sadece reverse geocode + projection için.
  // Controller VM state'ini set ETMEZ, sadece okur.
  final MapViewModel _mapVM;

  // ─── State ──────────────────────────────────────────────────────────────

  PinFlowMode _mode = PinFlowMode.idle;
  LatLng? _point;
  String? _selectedType;
  Pin? _activePin;
  Offset? _screenAnchor;
  String _province = '';
  String _district = '';
  bool _isResolvingLocation = false;
  // 2026-05-31 — Çoklu pin: Güneş/Rüzgar kaydından sonra aynı tiple yerleştirme
  // modunda kal. Null → tekli mod. HES bu modu tetiklemez.
  String? _repeatType;

  // ─── Public getters ─────────────────────────────────────────────────────

  PinFlowMode get mode => _mode;
  LatLng? get point => _point;
  String? get selectedType => _selectedType;
  Pin? get activePin => _activePin;
  Offset? get screenAnchor => _screenAnchor;
  String get province => _province;
  String get district => _district;
  bool get isResolvingLocation => _isResolvingLocation;
  /// Çoklu pin modu aktif mi (aynı tip art arda kuruluyor).
  bool get isMultiPlacing => _repeatType != null;
  String? get repeatType => _repeatType;

  /// True ise pop-up overlay görünür olmalı (mode != idle && != placing).
  bool get hasOverlay =>
      _mode == PinFlowMode.typeSelection ||
      _mode == PinFlowMode.addForm ||
      _mode == PinFlowMode.detail ||
      _mode == PinFlowMode.editForm;

  /// İl/ilçe başlığı string formatlı (PinPanelShell ile uyumlu).
  String get locationLabel {
    if (_province.isEmpty && _district.isEmpty) return 'Türkiye dışı';
    if (_district.isNotEmpty) return '$_district / $_province';
    return _province;
  }

  // ─── Public API — State transitions ─────────────────────────────────────

  /// Santral Kur tuşu → placing mode.
  void enterPlacing() {
    if (_mode == PinFlowMode.placing) return;
    _close(notify: false);
    _mode = PinFlowMode.placing;
    _activateSuitabilityLayers(null);
    _syncMapClickState();
    notifyListeners();
  }

  /// Placing mode'dan çık (kullanıcı tuşa tekrar bastı veya ESC).
  void cancelPlacing() {
    if (_mode != PinFlowMode.placing) return;
    _mode = PinFlowMode.idle;
    _repeatType = null; // çoklu pin modunu bitir
    _deactivateSuitabilityLayers();
    _syncMapClickState();
    notifyListeners();
  }

  /// Haritada bir noktaya tıklandı. Mode-aware davranır.
  /// Return true: tıklama controller tarafından yutuldu (caller başka şey
  /// yapmasın). Return false: controller ilgisiz, caller serbest.
  bool onMapTap(LatLng point) {
    switch (_mode) {
      case PinFlowMode.placing:
        _point = point;
        if (_repeatType != null) {
          // Çoklu pin: tip seçimini atla, aynı tiple doğrudan forma gir.
          _selectedType = _repeatType;
          _mode = PinFlowMode.addForm;
          _activateSuitabilityLayers(_repeatType);
        } else {
          _mode = PinFlowMode.typeSelection;
        }
        _recomputeAnchorFromPoint();
        _fetchReverseGeocode(point);
        _showPreviewPin(point);
        _syncMapClickState();
        notifyListeners();
        return true;
      case PinFlowMode.typeSelection:
      case PinFlowMode.addForm:
        // Pin konumunu değiştir (pop-up aynı kalır, yeni noktaya taşınır)
        _point = point;
        _recomputeAnchorFromPoint();
        _fetchReverseGeocode(point);
        _showPreviewPin(point);
        notifyListeners();
        return true;
      case PinFlowMode.detail:
      case PinFlowMode.editForm:
      case PinFlowMode.idle:
        return false;
    }
  }

  /// V3 popover'da tip seçildi → addForm moduna geç.
  void selectType(String pinType) {
    if (_mode != PinFlowMode.typeSelection) return;
    _selectedType = pinType;
    _mode = PinFlowMode.addForm;
    _activateSuitabilityLayers(pinType);
    _syncMapClickState();
    notifyListeners();
  }

  /// Pin BAŞARIYLA kaydedildi (AddPinDialog → onSaved).
  /// Güneş/Rüzgar ise aynı tiple yerleştirme moduna dön (çoklu kurulum);
  /// HES ise akışı kapat. Kullanıcı "Santral Kur"/ESC ile çoklu modu bitirir.
  void onPinAdded() {
    final t = _selectedType;
    final isSolarWind = t == 'Güneş Paneli' || t == 'Rüzgar Türbini';
    if (isSolarWind) {
      _repeatType = t;
      _showPreviewPin(null);
      _activePin = null;
      _point = null;
      _screenAnchor = null;
      _province = '';
      _district = '';
      _mode = PinFlowMode.placing; // sonraki tık → aynı tiple addForm
      _activateSuitabilityLayers(t);
      _syncMapClickState();
      notifyListeners();
    } else {
      _repeatType = null;
      close();
    }
  }

  /// Pin tıklaması — detail moduna geç (pinler arası geçiş aynı).
  void openPinDetail(Pin pin) {
    if (_activePin?.id == pin.id && _mode == PinFlowMode.detail) return;
    // Eğer placing/typeSelection açıksa kapat (preview pin temizlenir)
    if (_mode == PinFlowMode.placing ||
        _mode == PinFlowMode.typeSelection ||
        _mode == PinFlowMode.addForm) {
      _showPreviewPin(null);
    }
    _activePin = pin;
    _point = LatLng(pin.latitude, pin.longitude);
    _mode = PinFlowMode.detail;
    _selectedType = pin.type; // Edit mode'a giriş için
    _activateSuitabilityLayers(pin.type);
    _recomputeAnchorFromPoint();
    _fetchReverseGeocode(_point!);
    _syncMapClickState();
    notifyListeners();
  }

  /// Detail card'da "Düzenle" → editForm moduna geç.
  void enterEditMode() {
    if (_mode != PinFlowMode.detail || _activePin == null) return;
    _mode = PinFlowMode.editForm;
    _syncMapClickState();
    notifyListeners();
  }

  /// Edit iptal → detail'e dön.
  void cancelEdit() {
    if (_mode != PinFlowMode.editForm) return;
    _mode = PinFlowMode.detail;
    _syncMapClickState();
    notifyListeners();
  }

  /// Tip değiştir (form içi segmented selector).
  void changeType(String newType) {
    if (_selectedType == newType) return;
    _selectedType = newType;
    _activateSuitabilityLayers(newType);
    notifyListeners();
  }

  /// Tüm overlay'i kapat → idle.
  void close() {
    _close(notify: true);
  }

  void _close({required bool notify}) {
    _showPreviewPin(null);
    final wasActive = _mode != PinFlowMode.idle;
    _mode = PinFlowMode.idle;
    _point = null;
    _selectedType = null;
    _activePin = null;
    _screenAnchor = null;
    _province = '';
    _district = '';
    _repeatType = null; // çoklu pin modu da sıfırlanır
    if (wasActive) {
      _deactivateSuitabilityLayers();
    }
    _syncMapClickState();
    if (notify) notifyListeners();
  }

  // ─── Suitability layers (yasaklı bölgeler + tematik harita) ──────────────
  // 2026-05-17 — Pin akışı aktifken kullanıcı bölgenin pin tipi açısından
  // uygunluğunu görsün diye yasaklı bölgeler + tipe uygun tematik harita
  // otomatik açılır. Pin akışı kapanınca her ikisi de kapatılır.
  // Tematik harita → ilçe modu da setChoroplethMode(none) içinde otomatik
  // kapanır (MapViewModel override).

  /// Tipe göre uygun ChoroplethMode'u döndürür. HES için tematik yok.
  ChoroplethMode? _choroplethForType(String? pinType) {
    if (pinType == null) return null;
    if (pinType == 'Güneş Paneli') return ChoroplethMode.solar;
    if (pinType == 'Rüzgar Türbini') return ChoroplethMode.wind;
    // HES / Hidroelektrik için tematik yok
    return null;
  }

  void _activateSuitabilityLayers(String? pinType) {
    // Yasaklı bölgeler — pin akışı boyunca açık
    if (!_mapVM.showRestrictedZoneLayer) {
      _mapVM.toggleRestrictedZoneLayer();
    }
    // Su kaynakları — sadece HES için (akarsu/göl/baraj görünür)
    final isHydro = pinType == 'HES' || pinType == 'Hidroelektrik';
    if (isHydro && !_mapVM.showHydroLayer) {
      _mapVM.toggleHydroLayer();
    } else if (!isHydro && _mapVM.showHydroLayer) {
      // RES/GES'e geçildiyse hydro layer'ı kapat
      _mapVM.toggleHydroLayer();
    }
    // Tematik harita — tipe göre (HES'te yok)
    final target = _choroplethForType(pinType);
    if (target != null && _mapVM.choroplethMode != target) {
      _mapVM.setChoroplethMode(target);
    } else if (target == null &&
        _mapVM.choroplethMode != ChoroplethMode.none) {
      // HES seçildi ve önceden başka tematik açıksa kapat
      _mapVM.setChoroplethMode(ChoroplethMode.none);
    }
  }

  void _deactivateSuitabilityLayers() {
    if (_mapVM.showRestrictedZoneLayer) {
      _mapVM.toggleRestrictedZoneLayer();
    }
    if (_mapVM.showHydroLayer) {
      _mapVM.toggleHydroLayer();
    }
    if (_mapVM.choroplethMode != ChoroplethMode.none) {
      _mapVM.setChoroplethMode(ChoroplethMode.none);
    }
  }

  // ─── Anchor recompute ────────────────────────────────────────────────────

  /// Harita pan/zoom event'inde anchor pixel pos'u güncelle.
  /// Source pin koordinatı (mode-aware): placing'de point yok, idle'da yok.
  void recomputeAnchor() {
    _recomputeAnchorFromPoint();
  }

  void _recomputeAnchorFromPoint() {
    final p = _point;
    if (p == null) {
      if (_screenAnchor != null) {
        _screenAnchor = null;
        notifyListeners();
      }
      return;
    }
    final pos = MapViewMapLibre.projectLngLatToScreen(p);
    if (pos != _screenAnchor) {
      _screenAnchor = pos;
      notifyListeners();
    }
  }

  // ─── Reverse geocode (il/ilçe) ──────────────────────────────────────────

  Future<void> _fetchReverseGeocode(LatLng point) async {
    _isResolvingLocation = true;
    _province = '';
    _district = '';
    notifyListeners();
    try {
      final result = await _mapVM.fetchReverseGeocode(point);
      // Bu sırada başka point gelmiş mi?
      if (_point?.latitude != point.latitude ||
          _point?.longitude != point.longitude) {
        return; // stale, ignore
      }
      if (result != null) {
        _province = result['province'] ?? '';
        _district = result['district'] ?? '';
      }
    } catch (_) {
      // sessiz geç, Türkiye dışı olabilir
    } finally {
      if (_point?.latitude == point.latitude &&
          _point?.longitude == point.longitude) {
        _isResolvingLocation = false;
        notifyListeners();
      }
    }
  }

  // ─── Preview pin (harita üzeri teal halka + nokta) ──────────────────────

  void _showPreviewPin(LatLng? point) {
    MapViewMapLibre.showPreviewPin(point);
  }

  // ─── Click guard sync ────────────────────────────────────────────────────
  // 2026-05-17 — Pin akışı aktifken harita tıklama davranışı:
  //   - placing/typeSelection/addForm: placement=true, guard=FALSE.
  //     queryClick zaten atlanır → tıklama doğrudan _handleMapTap →
  //     PinFlowController.onMapTap → pin yerleşir/taşınır.
  //   - detail/editForm: placement=false, guard=TRUE. queryClick yapılır;
  //     pin tıklamasına izin verilir (pinler arası geçiş), selection/
  //     choropleth/boş alan yutulur.
  //   - idle: ikisi de false.
  //
  // 2026-05-17 — notifyListeners override KALDIRILDI. Override her notify'da
  // `setClickGuard` JS bridge call yapıyordu; eğer JS henüz yüklenmediyse
  // (init race) bridge call hata fırlatabilirdi. Yeni: state-mutating
  // method'ların sonunda explicit `_syncMapClickState()` çağrılır.
  void _syncMapClickState() {
    final placement = _mode == PinFlowMode.placing ||
        _mode == PinFlowMode.typeSelection ||
        _mode == PinFlowMode.addForm;
    final guardOnly = _mode == PinFlowMode.detail ||
        _mode == PinFlowMode.editForm;
    try {
      MapViewMapLibre.setPinPlacementActive(placement);
      MapViewMapLibre.setClickGuard(guardOnly);
    } catch (_) {
      // JS henüz yüklenmediyse sessiz geç — mode geçişlerini bloklamayalım
    }
  }
}

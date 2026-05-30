---
tags: [pitfall, pin, audit, refactor]
updated: 2026-05-09
related: [PinFlowController, PinAddFlow, JustTheTooltipPattern]
---

# Pin Flow Audit (2026-05-09 Reset)

Pin sistemi 6 sprint boyunca kümülatif yamalama ile büyüdü ve **8+ state
field** + **3 ayrı pop-up** + **2 farklı placing API** karmaşasına ulaştı.
Bu doküman: mevcut durumun fotoğrafı + neden bozulduğu + temiz reset.

## Mevcut State Yığını (KARMAŞIK — refactor öncesi)

`map_screen.dart` State (8 field):
```
bool _placingMode                       // tip-agnostic placing mode (yeni)
LatLng? _pinTypePopoverPoint            // V3 popover anchor
String _pinTypePopoverLocation          // reverse geocode il/ilçe
String _pinTypePopoverCoords            // koordinat formatlı
LatLng? _pinFormPoint                   // pin form için lat/lng
String? _pinFormType                    // seçilen tip
ValueNotifier<Offset?> _pinAnchorNotifier  // pixel anchor (3 pop-up paylaşır)
bool _isProcessingGeoCheck              // duplicate dialog koruma
DateTime? _pinModeActivatedAt           // 600ms debounce
```

`MapViewModel` (2 field):
```
PinType? _placingPinType                // ESKİ API — hala bazı yerde
Pin? _activePinDetail                   // pin detail state
```

## Mevcut Akış (KARIŞIK)

```
Santral Kur tuşu
    → _placingMode = !_placingMode  (toggle)
    → Map tap (_handleMapTap):
        1. isSelectingRegion → recordSelectionPoint
        2. _pinFormPoint != null → _movePinFormTo (form taşı)
        3. _pinTypePopoverPoint != null → _openPinTypePopover (popover taşı)
        4. _placingMode (debounce) → _openPinTypePopover (yeni popover)
        5. viewModel.placingPinType != null → _checkGeoSuitability (LEGACY!)
    → V3 popover'da tip seç (_onPinTypePopoverSelect):
        - _pinFormPoint = point
        - _pinFormType = type
        - _pinTypePopoverPoint = null
        - _placingMode = false
        - setMvtLayers(...)
    → Pin tap (_showPinDialog):
        - _pinAnchorNotifier = projectLngLatToScreen(pin)
        - vm.openPinDetail(pin) → _activePinDetail = pin
    → Close (any):
        - state'leri null'la, anchor temizle
```

**3 ayrı pop-up tek anchor notifier paylaşıyor** → biri kapanırsa diğeri etkilenir.

## Sorun Analizi

### 1. State Coordination Yok
- `_pinAnchorNotifier` 3 farklı kaynak için kullanılır (popover, form, detail).
- `_onMapMovedRecomputeAnchor` 3 source'tan birini seçer:
  `_pinFormPoint ?? _pinTypePopoverPoint ?? VM.activePinDetail`
- Eğer form açılırken popover hâlâ kapatılmadıysa pozisyon karışır.

### 2. Duplicate API'ler
- Eski: `VM.placingPinType` (`startPlacingMarker(type)`, `stopPlacingMarker()`)
- Yeni: `_placingMode` (tip-agnostic, V3 popover'da tip seçilir)
- `_handleMapTap` her iki path'i de kontrol ediyor → kafa karışıklığı.

### 3. just_the_tooltip Controller Yarış Koşulu
- `_PinTooltipHost` widget rebuild olduğunda yeni `JustTheController` yaratıyor.
- `addPostFrameCallback` ile `showTooltip()` çağrılıyor.
- ValueListenableBuilder anchor güncellemesinde rebuild → tooltip flicker /
  hızla kayboluyor.
- Çözüm: Controller widget lifecycle'a bağlı değil, **mode değişimine** bağlı.

### 4. Pinler Arası Geçiş Bozuk
- Pin1 detay açık → Pin2'ye tıkla → `_showPinDialog(pin2)` çağrılır.
- `openPinDetail(pin2)` VM state günceller.
- `_pinAnchorNotifier.value = pin2 pixel` set edilir.
- AMA `_PinTooltipHost`'un Key'i `pin-detail-host-${pin.id}` —
  Pin değişince yeni widget oluşur, eski dispose. **Sorun:** dispose
  esnasında tooltip kapanma animasyonu + yeni tooltip showTooltip
  yarışıyor → görünür flicker / hiç açılmama.

### 5. V3 Popover Anında Kayboluyor
- V3 popover açıldığında `_pinAnchorNotifier` set ediliyor.
- ValueListenableBuilder rebuild → `_PinTooltipHost` widget yeniden inşa.
- initState'te `addPostFrameCallback` → `showTooltip()`.
- Ama belki state değişimi sürekli olduğu için (`_pinTypePopoverLocation`
  reverse geocode'dan dönünce setState) tooltip controller "hide" tetikleniyor.

## Reset Spec (Yeni Tasarım)

### State Machine (Tek Source of Truth)

```dart
enum PinFlowMode {
  idle,           // Hiçbir şey açık değil
  placing,        // Santral Kur tıklandı, harita tıklaması bekleniyor
  typeSelection,  // Harita tıklandı, popover açık (tip seçimi)
  addForm,        // Tip seçildi, form açık
  detail,         // Mevcut pin tıklandı, detail card açık
  editForm,       // Detail'de Düzenle tıklandı
}

class PinFlowController extends ChangeNotifier {
  PinFlowMode _mode = PinFlowMode.idle;
  LatLng? _point;          // popover/form için tıklanan koordinat
  String? _selectedType;   // 'Güneş Paneli' | 'Rüzgar Türbini' | 'HES'
  Pin? _activePin;         // detail/editForm için mevcut pin
  Offset? _screenAnchor;   // pin pixel pos (just_the_tooltip için)

  // Reverse geocode
  String _province = '';
  String _district = '';

  // Public API:
  void enterPlacing();
  void cancelPlacing();
  void onMapTap(LatLng point);  // mode-aware
  void selectType(String type);
  void openPinDetail(Pin pin);
  void enterEditMode();
  void close();
  void recomputeAnchor(MapViewModel mapVM);  // pan/zoom'da
}
```

### Akış (Net)

```
idle
  ↓ enterPlacing()
placing
  ↓ onMapTap(point)
typeSelection (popover anchor=point)
  ↓ selectType(type)
addForm (anchor korunur, body grow)
  ↓ saved/cancelled
idle

idle (pin click via map)
  ↓ openPinDetail(pin)
detail (anchor=pinPixelPos)
  ↓ enterEditMode()
editForm
  ↓ saved/cancelled
detail / idle

detail (pin1) → openPinDetail(pin2)
  → mode değişmez (detail kalır), _activePin = pin2, anchor güncel
  → _PinFlowOverlay tek widget; pin değişimi onun içinde — yeni tooltip
    instance YOK, sadece content widget Key ile güncellenir
```

### Tek Overlay Widget

`PinFlowOverlay` (yeni widget):
- Controller'ı dinler (`AnimatedBuilder` veya `Selector` ile sadece gerekli alanları)
- Mode'a göre uygun pop-up content render eder
- `just_the_tooltip` controller **widget tree'ye değil, mode'a bağlı**:
  - `idle/placing` → tooltip hide
  - `typeSelection/addForm/detail/editForm` → tooltip show
- Tek `_PinTooltipHost` instance — Key değişmez (content değişir, anchor değişir)

### Eski API Deprecate

- `VM.placingPinType` deprecate yorumla → yeni kod `PinFlowController` kullanmalı
- `VM.activePinDetail` deprecate → `PinFlowController._activePin`
- `VM.startPlacingMarker/stopPlacingMarker` deprecate → `controller.enterPlacing/cancelPlacing`

Eski API'leri silmiyoruz (geriye uyum: pins_panel.dart, scenario_side_panel.dart
hâlâ kullanıyor), ama yeni geliştirmeler controller'ı kullansın.

## Refactor Adımları (Uygulanacak)

1. **`PinFlowController` yaz** (`features/pins/controllers/pin_flow_controller.dart`)
2. **`PinFlowOverlay` yaz** (`features/pins/widgets/pin_flow_overlay.dart`) — tek
   widget, controller-driven
3. **map_screen'de**: eski 8 state field sil → tek `PinFlowController` instance
4. **map_screen'de**: `_handleMapTap` → `controller.onMapTap(point)` tek satır
5. **map_screen'de**: 3 overlay metodu (`_buildPinFormOverlay`, `_buildPinDetailOverlay`,
   `_buildPinTypePopoverInline`) → tek `PinFlowOverlay`
6. **map_screen'de**: 8 helper (`_openPinTypePopover`, `_onPinTypePopoverSelect`,
   `_movePinFormTo`, `_closePinTypePopover`, `_closePinForm`, `_closePinDetail`,
   `_showPinDialog`, `_checkGeoSuitability`) → controller metotları
7. **`_onMapMovedRecomputeAnchor`** → `controller.recomputeAnchor(vm)`
8. **AddPinDialog + PinDetailsDialog** — controller'dan callback ile beslenir
9. **VM eski API'leri yoruma**: deprecated notu
10. **Test** — tüm akış senaryoları

## Bağlantılar

- [[PinFlowController]] — yeni controller (yazılacak)
- [[PinAddFlow]] — eski akış dokümantasyonu (güncellenecek)
- [[JustTheTooltipPattern]] — tooltip kullanımı
- [[INBOX]] — 2026-05-09 Strategic Reset

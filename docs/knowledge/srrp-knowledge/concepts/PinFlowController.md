---
tags: [concept, pin, state-machine, controller]
updated: 2026-05-09
related: [PinFlowAudit, PinAddFlow, JustTheTooltipPattern]
---

# PinFlowController — Pin Lifecycle State Machine

Pin akışının (placing → typeSelection → addForm → detail → editForm) tek
source of truth'u. ChangeNotifier-based, mode enum ile state geçişleri.

**2026-05-09 Strategic Reset.** Bkz: [[PinFlowAudit]] — 6 sprint boyunca
kümülatif yamalama ile büyüyen state karmaşası bu controller'da
toplandı, ~200 satır eski kod silindi.

## State Machine

```
enum PinFlowMode {
  idle,           // hiçbir overlay yok
  placing,        // Santral Kur tıklandı, harita tıklaması bekleniyor
  typeSelection,  // harita tıklandı, popover açık (RES/GES/HES)
  addForm,        // tip seçildi, form açık
  detail,         // mevcut pin tıklandı, detail card
  editForm,       // detail'de "Düzenle" → form
}
```

```
       idle
         ↓ enterPlacing()
       placing
         ↓ onMapTap(point)
       typeSelection ──onMapTap(p)→ typeSelection (point güncellenir)
         ↓ selectType(t)
       addForm ──onMapTap(p)→ addForm (point güncellenir, tip korunur)
         ↓ close() / saved
       idle

       idle ──openPinDetail(pin)→ detail
       detail ──openPinDetail(pin2)→ detail (yeni pin)
       detail ──enterEditMode()→ editForm
       editForm ──cancelEdit()→ detail
       any ──close()→ idle
```

## API

```dart
class PinFlowController extends ChangeNotifier {
  PinFlowController(MapViewModel mapVM);

  // Readonly getters
  PinFlowMode get mode;
  LatLng? get point;
  String? get selectedType;
  Pin? get activePin;
  Offset? get screenAnchor;
  String get province;
  String get district;
  String get locationLabel;  // "İlçe / İl" formatlı
  bool get isResolvingLocation;
  bool get hasOverlay;  // mode != idle && != placing

  // Public API
  void enterPlacing();
  void cancelPlacing();
  bool onMapTap(LatLng point);   // mode-aware; true = yutuldu
  void selectType(String pinType);
  void openPinDetail(Pin pin);   // pinler arası geçiş
  void enterEditMode();
  void cancelEdit();
  void changeType(String newType);  // form içi tip değiştir
  void close();                  // tüm overlay kapan
  void recomputeAnchor();        // map pan/zoom'da
}
```

## Kullanım

### map_screen.dart (Tek owner)

```dart
class _MapScreenState extends State<MapScreen> {
  PinFlowController? _pinFlow;

  PinFlowController _ensurePinFlow() {
    if (_pinFlow != null) return _pinFlow!;
    final mapVM = Provider.of<MapViewModel>(context, listen: false);
    _pinFlow = PinFlowController(mapVM);
    return _pinFlow!;
  }

  @override
  Widget build(BuildContext context) {
    final pinFlow = _ensurePinFlow();
    return ChangeNotifierProvider<PinFlowController>.value(
      value: pinFlow,
      child: ...  // downstream caller'lar Provider.of'la alır
    );
  }
}
```

### Santral Kur Butonu

```dart
AnimatedBuilder(
  animation: pinFlow,
  builder: (_, __) {
    final placing = pinFlow.mode == PinFlowMode.placing;
    return MapControlButton(
      tooltip: placing ? "Haritada tıklayın" : "Santral Kur",
      onTap: () => placing ? pinFlow.cancelPlacing() : pinFlow.enterPlacing(),
      color: placing ? Colors.greenAccent : Colors.blueAccent,
    );
  },
)
```

### Map Tap

```dart
void _handleMapTap(MapViewModel vm, LatLng point) {
  if (vm.isSelectingRegion) {
    vm.recordSelectionPoint(point);
    return;
  }
  if (_pinFlow?.onMapTap(point) == true) return; // yutuldu
}
```

### Pin Tıklaması (Map içinden)

```dart
void _showPinDialog(Pin pin) {
  _pinFlow?.openPinDetail(pin);
}
```

### Sidebar / Cross-sheet Pin Tıklaması

```dart
// PinsPanel veya ScenarioSidePanel'dan
onTap: () {
  Provider.of<PinFlowController>(context, listen: false).openPinDetail(pin);
}
```

### Map Move (Pan/Zoom)

```dart
MapViewMapLibre.registerAnchorListener(() {
  _pinFlow?.recomputeAnchor();
});
```

## PinFlowOverlay — Render

Controller dinleyen tek widget:

```dart
PinFlowOverlay(
  controller: pinFlow,
  onTypeSelected: (type) {
    // setMvtLayers makro vs
  },
)
```

Mode'a göre içeriği değiştirir:
- `typeSelection` → `PinTypePopoverInline`
- `addForm` → `AddPinDialog`
- `detail` / `editForm` → `PinDetailsDialog`

**Manuel `Positioned` + `_AnchoredBubble`** sohbet balonu pop-up (bkz.
[[JustTheTooltipPattern]] — geriye bakış: `just_the_tooltip` paketi Stack
> Positioned(1x1) anchor pattern'ında sol-üste düştüğü için manuel
implementasyona dönüldü). Controller widget lifecycle'a değil, **mode
değişimine** bağlı `AnimatedBuilder` rebuild → pop-up show/hide.

## Silinen Eski API

`map_screen.dart`'tan kaldırıldı:
- State: `_placingMode`, `_pinTypePopoverPoint`, `_pinTypePopoverLocation`,
  `_pinTypePopoverCoords`, `_pinFormPoint`, `_pinFormType`, `_pinAnchorNotifier`,
  `_isProcessingGeoCheck`, `_pinModeActivatedAt`
- Helper: `_openPinTypePopover`, `_onPinTypePopoverSelect`, `_movePinFormTo`,
  `_closePinTypePopover`, `_closePinForm`, `_closePinDetail`,
  `_buildPinTypePopoverInline`, `_buildPinFormOverlay`, `_buildPinDetailOverlay`,
  `_checkGeoSuitability`, `_isInTurkey`, `_onMapMovedRecomputeAnchor`
- Widget: dosya-içi `_PinTooltipHost`

Toplam **~400 satır azalma** + tek source of truth.

## VM Deprecated API

`MapViewModel` artık deprecate:
- `placingPinType` / `startPlacingMarker` / `stopPlacingMarker`
- `activePinDetail` / `openPinDetail` / `closePinDetail`

Geriye uyum için tutuluyor (eski caller'lar var) ama yeni kod
`PinFlowController` kullanmalı. `PinsPanel` ve `ScenarioSidePanel` zaten
controller'a yönlendirildi (try/catch fallback ile).

## ⚠️ Yaygın Tuzaklar

1. **State değiştirme akıllı yapılmalı**: `onMapTap` mode'a göre 3 farklı
   davranır. Caller her durumda aynı şeyi beklemesin.
2. **`close()` her şeyi temizler** — preview pin, anchor, point, type,
   activePin, mode → idle. Edit'ten detail'e dönmek için `cancelEdit()`
   kullan.
3. **Reverse geocode async** — `_fetchReverseGeocode` arka planda. Point
   değişirse stale guard (`_point` karşılaştırması) atlar.
4. **`screenAnchor` null olabilir** — map henüz hazır değilse veya point
   yok. Overlay null kontrol etmeli.
5. **VM eski API ile çift state riski**: caller hem `vm.openPinDetail`
   hem `controller.openPinDetail` çağırırsa state desync. Caller'lar
   sadece controller kullanmalı (geriye uyum için sadece fallback).

## Bağlantılar

- [[PinFlowAudit]] — refactor öncesi karmaşa
- [[PinAddFlow]] — UI/UX akışı
- [[JustTheTooltipPattern]] — pop-up kabuğu
- [[INBOX]] — 2026-05-09 Strategic Reset
- Dosya: `features/pins/controllers/pin_flow_controller.dart`
- Dosya: `features/pins/widgets/pin_flow_overlay.dart`

---
tags: [pitfall, perf, anchor, pin]
updated: 2026-05-09
related: [PinPanelShell, PinAddFlow, MapScreen]
---

# Pin Anchor Performance — `ValueNotifier` Decoupling

## ⚠️ Tuzak

Pin form / pop-up'ların pin'in ekran piksel konumuna anchor olması için
**her map move event'inde** (60fps'ye kadar) pixel pos hesaplanır. Eğer bu
hesap doğrudan `setState` ile yapılırsa, **tüm `Consumer<MapViewModel>`
overlay'leri rebuild olur** → AddPinDialog, PinDetailsDialog, PinPanelShell,
AnimatedGradientButton'lar tekrar inşa → büyük jank.

## ✅ Çözüm — Decoupling

`ValueNotifier<Offset?>` + `ValueListenableBuilder` + `RepaintBoundary`:

```dart
// State
final ValueNotifier<Offset?> _pinAnchorNotifier = ValueNotifier(null);

// Map move callback — setState YOK
void _onMapMoved() {
  final pos = MapViewMapLibre.projectLngLatToScreen(point);
  if (pos != _pinAnchorNotifier.value) {
    _pinAnchorNotifier.value = pos;  // Sadece bu notifier'ı dinleyen rebuild olur
  }
}

// Overlay — sadece anchor değişince yeniden inşa
RepaintBoundary(
  child: ValueListenableBuilder<Offset?>(
    valueListenable: _pinAnchorNotifier,
    builder: (context, anchor, _) {
      if (anchor == null) return fallbackOverlay;
      return _anchoredPositioned(anchor: anchor, ...);
    },
  ),
)
```

**Etki:**
- Stack rebuild OLMAZ
- Sadece floating overlay'in Positioned'ı + child'ı tekrar build olur (bu
  build maliyeti zaten düşük: ConstrainedBox + ana widget reuse)
- RepaintBoundary paint cycle'ı izole eder — overlay paint dışarı sızmaz
- 60fps map move'da kasma kaybolur

## Neden setState Kötü

`setState(() => _pinAnchorScreenPos = pos)` çağrısı:
1. `_MapScreenState.build()` tetikler
2. `Consumer2<MapViewModel, ScenarioViewModel>` rebuild
3. Stack içindeki tüm `if/else` koşullarındaki widget'lar yeniden inşa
4. Her overlay'in Provider listener'ları çalışır
5. AnimatedGradientButton'lar AnimationController dinleyicilerini günceller

Saniyede 60 kez = saniyede 60 widget tree rebuild. Mid-tier cihazda ~16ms
frame budget'ı patlar.

## Ne Zaman setState Kullan

`_pinFormPoint`, `_pinFormType` gibi **kararlı state** (kullanıcı tıklamasında
1 kez set) için setState OK. Kullanıcı her frame değiştirmez.

## ⚠️ Yaygın Tuzaklar

1. **ValueListenableBuilder dışında `notifier.value` okuma**: rebuild yok.
   Sadece builder içinden okunmalı.
2. **Notifier dispose unutma**: `State.dispose()` içinde `notifier.dispose()`
   çağrılmalı — memory leak önler.
3. **Equality check**: `if (pos != notifier.value) notifier.value = pos`
   yazılmalı; aksi takdirde her frame `notifyListeners()` çağrılır (eski
   değer aynıysa bile).
4. **RepaintBoundary aşırı kullanma**: çok fazla RepaintBoundary GPU layer
   patlatabilir. Sadece bağımsız paint isteyen yerlere.
5. **`AnimatedPositioned` overlay'de KULLANMA**: pin'le pop-up arasında 250ms
   takip lag yaratır + kapanma anında ortaya animate eden glitch. Anchor
   değişimi anlık olmalı (`Positioned`), kapanma için ayrı `AnimatedSwitcher`
   veya `AnimatedOpacity` kullan. **Sprint 5 2026-05-09: kaldırıldı.**
6. **Kapanma anında fallback `Positioned(bottom: 16, ...)` koyma**: anchor
   null olunca pop-up ekrana yeniden konumlanır → görsel glitch. Doğru:
   `if (anchor == null) return SizedBox.shrink()` — widget tree'den çıkar.

## Bağlantılar

- [[PinPanelShell]] — overlay kabuğu
- [[PinAddFlow]] — pop-up akışı
- [[MapScreen]] — overlay parent
- [[INBOX]] — 2026-05-09 Sprint 4 kasma fix

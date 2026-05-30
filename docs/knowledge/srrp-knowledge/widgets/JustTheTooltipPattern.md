---
tags: [widget, ui, tooltip, pin, library, lessons-learned]
updated: 2026-05-09
related: [PinFlowController, PinAddFlow, PinAnchorPerf]
---

# AnchoredBubble Pattern — Pin Pop-up Kabuğu

> ⚠️ **Not adı tarihsel.** Pop-up önce `just_the_tooltip` paketi ile denendi
> (bkz. aşağıda "Geriye Bakış"). Paket bizim Stack-anchored kullanım
> senaryomuza uymadı, **manuel `Positioned` + custom `_TailPainter`**'a geri
> dönüldü. Asıl render yeri: `pin_flow_overlay.dart` → `_AnchoredBubble`.

## 🔑 Mevcut Çözüm — Manuel Positioned + Tail

```dart
class _AnchoredBubble extends StatelessWidget {
  final Offset anchor;        // pin'in ekran pixel pos'u
  final Size screenSize;
  final double cardWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const tailGap = 14.0;
    const tailH = 10.0;
    const tailW = 18.0;
    const edgePad = 8.0;
    const minContent = 240.0;

    // Yer hesabı: üstte mi altta mı dursun
    final spaceAbove = anchor.dy - tailGap - edgePad;
    final spaceBelow = screenSize.height - anchor.dy - tailGap - edgePad;
    final placeAbove = spaceAbove >= minContent || spaceAbove >= spaceBelow;
    final availH = (placeAbove ? spaceAbove : spaceBelow)
        .clamp(160.0, screenSize.height - 16.0);

    // Yatay clamp — ekran kenarında dışarı taşmasın
    final rawLeft = anchor.dx - cardWidth / 2;
    final maxLeft = screenSize.width - cardWidth - edgePad;
    final left = rawLeft.clamp(edgePad, maxLeft < edgePad ? edgePad : maxLeft);

    // Tail tepe pos (popup içinde, anchor pixel'ine doğru)
    final tailCenter = (anchor.dx - left).clamp(
      tailW / 2 + 4, cardWidth - tailW / 2 - 4,
    );

    return Positioned(
      left: left,
      top: placeAbove ? null : (anchor.dy + edgePad),
      bottom: placeAbove ? (screenSize.height - anchor.dy + edgePad) : null,
      child: PointerInterceptor(
        child: SizedBox(
          width: cardWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: placeAbove
                ? [Flexible(child: bubble), tail]
                : [tail, Flexible(child: bubble)],
          ),
        ),
      ),
    );
  }
}
```

### `_TailPainter` — Üçgen kuyruk

```dart
class _TailPainter extends CustomPainter {
  // pointsDown: popup üstte → tail aşağı bakar
  // pointsDown=false: popup altta → tail yukarı bakar
  void paint(Canvas canvas, Size size) {
    final path = ui.Path();
    final half = tailWidth / 2;
    if (pointsDown) {
      path
        ..moveTo(centerX - half, 0)
        ..lineTo(centerX + half, 0)
        ..lineTo(centerX, tailHeight)
        ..close();
    } else {
      path
        ..moveTo(centerX - half, tailHeight)
        ..lineTo(centerX + half, tailHeight)
        ..lineTo(centerX, 0)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }
}
```

## Davranış

| Durum | Davranış |
|---|---|
| Anchor üst yarıda | `placeAbove=false` → pop-up pinin altında, tail yukarı |
| Anchor alt yarıda | `placeAbove=true` → pop-up pinin üstünde, tail aşağı |
| Sol/sağ kenara yakın | `left` clamp; tail anchor'a doğru kayar |
| Yer < 160px | `availH` 160'a clamp; içerik scroll edilir |
| Anchor null (map ready değil) | Ekran ortası fallback (top:110 + Center) |
| Mobile (width < 600) | Bottom sheet — anchor yok, ekran altında sticky |

## Kullanım — `PinFlowOverlay`

```dart
class PinFlowOverlay extends StatelessWidget {
  final PinFlowController controller;

  Widget build(context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        if (!controller.hasOverlay) return const SizedBox.shrink();
        final anchor = controller.screenAnchor;
        if (anchor == null) return _fallbackCentered();
        return _AnchoredBubble(
          anchor: anchor,
          screenSize: MediaQuery.of(context).size,
          cardWidth: _widthForMode(controller.mode),  // 280 popover, 400 form
          child: _modeAwareContent(),
        );
      },
    );
  }
}
```

Mode → content mapping:
- `typeSelection` → `PinTypePopoverInline`
- `addForm` → `AddPinDialog`
- `detail` / `editForm` → `PinDetailsDialog`

## Geriye Bakış — Neden `just_the_tooltip` Çalışmadı

2026-05-09 Sprint 6: `just_the_tooltip` (pub.dev ~600 likes) ile denedik:

```dart
Positioned(
  left: anchor.dx - 0.5, top: anchor.dy - 0.5,
  width: 1, height: 1,
  child: JustTheTooltip(
    preferredDirection: AxisDirection.up,
    content: SizedBox(width: 400, child: AddPinDialog(...)),
    child: const SizedBox(width: 1, height: 1),
  ),
)
```

**Sorun:** Tooltip `Overlay.of(context)` global overlay'a düşüyor, Stack
parent'ının Positioned(1x1) anchor pozisyonuna saygı göstermiyor. Sonuç:

- Pop-up ekran sol-üst köşeye yapışıyor
- İçerik gözükse bile tıklama dismiss tetikliyor (modal davranış paket
  iç default'unda)
- `isModal:false` denendi → davranış değişmedi, paket Overlay route'u
  modal kabul ediyor

→ **Karar:** Paketi bırak, manuel `Positioned` ile çiz. State machine
(`PinFlowController`) zaten temiz, sadece render geri yazıldı.

### Önceki Sprintlerde Bırakılan Diğer Denemeler

| Deneme | Neden bırakıldı |
|---|---|
| Sağ side panel (Sprint 1-3) | Harita yarısını kapatıyordu |
| `_anchoredPositioned` 4-yön + `_Placement` enum | 300+ satır, edge case'lerde glitch |
| `AnimatedPositioned` soft track | 250ms takip lag, kapanma glitch |
| `just_the_tooltip` (Sprint 6) | Stack anchor pattern'ına uymadı |
| **Manuel `_AnchoredBubble`** (mevcut, Sprint 6+1) | ✅ |

## ⚠️ Yaygın Tuzaklar

1. **Pop-up height clamp şart** — `availH` hesabı; ekran küçükse pop-up
   ekran dışına taşar. `ConstrainedBox(maxHeight: availH)`.
2. **Yatay clamp** — anchor ekran kenarındaysa `left` rawLeft'i edgePad
   ile sınırla, aksi halde pop-up sağa/sola taşar.
3. **Tail merkezi clamp** — `tailCenter` cardWidth içinde kalsın; aksi
   halde tail görünmez veya köşeye yaslanır.
4. **`PointerInterceptor` gerekli** — Flutter web platform view (MapLibre
   GL JS canvas) tıklamayı yutar, pop-up içi butonlar çalışmaz.
5. **`Material(color: Colors.transparent)` wrap** — TextField/InkWell
   çocukları için Material ancestor şart, transparent ki gölgeyi
   bubble decoration verir.
6. **`AnimatedBuilder` listen et** — controller mode değişiminde rebuild
   gerekli; `Provider.of(listen:true)` yerine `AnimatedBuilder` daha az
   yan etkiyle.

## Bağlantılar

- [[PinFlowController]] — state machine (controller)
- [[PinAddFlow]] — UX akışı
- [[PinAnchorPerf]] — anchor pixel pos güncelleme perf
- Dosya: `frontend/lib/features/pins/widgets/pin_flow_overlay.dart`
- [[INBOX]] — 2026-05-09 Sprint 6 + Strategic Reset v2

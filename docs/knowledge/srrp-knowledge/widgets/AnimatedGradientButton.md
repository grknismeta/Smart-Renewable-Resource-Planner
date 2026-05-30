---
tags: [widget, ui, animation, button]
updated: 2026-05-09
related: [MapBottomSheet, PinAddFlow]
---

# AnimatedGradientButton

Premium hover/tap reaktif buton — bottom sheet'teki "Kütüphane" ve "Raporlar"
butonlarının kabuğu. Pure Flutter (CustomPainter + Transform), Lottie destekli
(asset gelince).

## Amaç

"Öğrenci projesi" hissi yerine "SaaS ürünü" hissi vermek için iki uygulanan
mikro-detay:

1. **Shimmer sweep** — hover/tap-down anında soldan sağa kayan ışık huzmesi
   (InkWell ripple yerine premium hissi).
2. **Mikro-ikon animasyonları** — buton yanında ikonlar **sadece hover/tap
   anında** canlanır, dışında statik (perf + dikkat dağılmaz).

## 🔑 Davranış Kuralları

| Durum | Shimmer | Mikro-ikonlar |
|---|---|---|
| Statik (default) | yok | statik (paint pos 0) |
| Hover (mouse enter — web) | tek sweep 720ms | loop animasyon başlar |
| Hover-out | dur | loop durur, paint sıfırlanır |
| Tap-down | sweep + hover state aktif | loop |
| Tap-up | callback + reverse | loop reverse |
| Tap-cancel | reverse | loop durur |
| Disabled | yok | yok |

**Önemli:** Mouse iki butondan **birinin üzerine** gelince **sadece o** canlanır,
diğer buton etkilenmez. Her buton kendi `AnimationController`'larıyla.

## API

```dart
AnimatedGradientButton(
  label: 'Kütüphane',
  icon: Icons.collections_bookmark_rounded,  // ana sembol (her zaman görünür)
  accentColor: Colors.blueAccent,
  onPressed: () => ...,
  microIcons: [
    BuiltInMicroIcons.spinningSun(),
    BuiltInMicroIcons.bouncingWaterDrop(),
    BuiltInMicroIcons.spinningWind(),
  ],
  minHeight: 56,
)
```

## Mikro-İkon Kütüphanesi (`BuiltInMicroIcons`)

**Kütüphane butonu:**
- `spinningSun()` — GES, yavaş dönen güneş (4s tam tur, amber)
- `bouncingWaterDrop()` — HES, yukarı-aşağı zıplayan damla (800ms, mavi)
- `spinningWind()` — RES, hızlı dönen türbin (1400ms, yeşil)

**Raporlar butonu:**
- `flippingCoin()` — Y ekseninde dönen sarı para (1600ms, perspective Matrix4)
- `pulsingBars()` — 3 sütun staggered yükselip alçalan (900ms, cyan)
- `bouncingArrow()` — yukarı-sağ diagonal bounce ok (900ms, yeşil)

Genişletmek için: `MicroIconBuilder` abstract — kendi implementasyonunuzu
ekleyin (`build(Animation<double> hover, Color color)`).

## Mimari

### Shimmer Sweep
- `_ShimmerPainter` (CustomPainter) — `progress: 0..1` parametresi
- Buton genişliğinin %55'i kadar diagonal gradient
- `startX = -sweepWidth + (width + 2*sweepWidth) * progress` — soldan sağa
- 5-stop LinearGradient: transparent → accent yarı-saydam → beyaz → ... → transparent

### Mikro-Animasyon Loop
- `_LoopingWhenHovered` widget — hover>0.05 olunca **kendi loop controller**
  `repeat()` başlatır, hover<=0.05 olunca durur+reset
- Her mikro ikon `Animation<double> loop` (0..1) parametresi alır
- Transform/Rotate/Translate ile sinüs/lerp ile pürüzsüz animasyon

### Hover/Tap Detection
- Web: `MouseRegion.onEnter/onExit`
- Mobile: `GestureDetector.onTapDown/onTapUp/onTapCancel`
- İkisi de aynı `_hover` AnimationController'ı tetikler

## Lottie Migrasyon Yolu

`lottie: ^3.1.2` pubspec'e eklendi ama henüz kullanılmıyor. Asset gelince:

```dart
class _LottieMicroIcon implements MicroIconBuilder {
  final String assetPath;
  _LottieMicroIcon(this.assetPath);

  @override
  Widget build(Animation<double> hover, Color color) {
    return _LottieAnimationGate(
      hover: hover,
      assetPath: assetPath,
    );
  }
}
```

`_LottieAnimationGate` hover>0 olunca `LottieController.repeat()`, hover<=0 olunca
`stop+reset`. `BuiltInMicroIcons.lottie('assets/anim/sun.json')` factory eklenir,
mevcut Transform mikrolarıyla yan yana kullanılır.

## ⚠️ Yaygın Tuzaklar

1. **Sürekli animasyon yapmama**: Bütün performans avantajı hover/tap-only
   olmasında. Default state'te tüm controller'lar durur.
2. **Lottie eklerken**: `Lottie.asset` her seferinde JSON parse eder — caller
   `LottieComposition` cache'lemeli (Lottie 3.x default cache yapıyor).
3. **Mobile parite**: Mobil cihazda hover yok → tap-down tetikler. Pulse hissi
   web kadar iyi gelmeyebilir; mobile'da long-press'i de tetikleyici yapmak
   gerekebilir.
4. **Disabled state**: `onPressed: null` → MouseRegion cursor `basic`, hover
   tetiklenmez (manuel check).

## Test Notları

- Web Chrome: mouse butona gel → ikonlar canlansın, sadece o butondaki.
- Tap (mobile/touch): basılı tuttukça canlansın, bırakınca dursun.
- Tema değişimi: accentColor opacity'leri tema-bağımsız (alpha:0.10/0.30).

## Bağlantılar

- [[MapBottomSheet]] — kullanıcı
- [[PinAddFlow]] — bottom sheet aynı sayfada
- [[INBOX]] — 2026-05-09 sprint

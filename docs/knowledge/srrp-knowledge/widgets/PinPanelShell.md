---
tags: [widget, ui, composition, pin]
updated: 2026-05-09
related: [PinAddFlow, AnimatedGradientButton, MapScreen]
---

# PinPanelShell — Pin Pop-up Ortak Kabuğu

`AddPinDialog` ve `PinDetailsDialog` widget'larının paylaştığı kabuk. Header,
gradient arka plan, scroll wrapper, responsive boyut — hepsi tek yerde.

## 🔑 Neden Var

2026-05-09'a kadar iki widget kendi kabuklarını ayrı ayrı tutuyordu. Bunun
sonucu:
1. **Davranış tutarsızlığı:** `AddPinDialog` floating pop-up pattern'a geçti
   ama `PinDetailsDialog` side-panel fallback'inde kaldı → AI FAB ona göre
   yanlış kayıyordu.
2. **Kod tekrarı:** ~80 satır kabuk her widget'ta kopyalı.
3. **Gelecek modlar zor:** "Karşılaştır", "Optimize" gibi yeni pin modları
   eklemek = tekrar 80 satır kabuk kopyalamak.

Composition pattern (Flutter idiomatic) ile çözüldü. Inheritance kullanmadık
— Flutter'da widget tree composition birinci sınıf vatandaş.

## API

```dart
PinPanelShell(
  point: LatLng(...),           // header'da reverse geocode için
  accentColor: Colors.orange,    // tip rengi (gradient + border)
  typeIcon: Icons.wb_sunny,      // header sol başında
  title: 'Yeni Kaynak Ekle',
  onClose: widget.onClose,
  body: Column(...),             // form veya detay içeriği
  // opsiyonel:
  mobileBreakpoint: 600,
  desktopWidth: 400,
  maxHeightRatio: 0.78,
)
```

## Shell Sağladıkları

| Özellik | Açıklama |
|---|---|
| **Header** | Tip ikonu + başlık + close butonu |
| **Lokasyon kartı** | İl/ilçe baskın + koordinat altta (reverse geocode `MapViewModel.fetchReverseGeocode`) |
| **Gradient arka plan** | Tip rengi yarı-saydam → tema kartı (35% stop) |
| **Border** | Tip rengi 40% alpha |
| **Box shadow** | Black54, blur 16 |
| **Responsive** | <600px: bottom anchored full-width + drag handle. ≥600px: 400px floating. |
| **Max height** | %78 ekran (scroll içerikte) |
| **didUpdateWidget** | Point değişimde reverse geocode tekrar tetiklenir |

## Caller Sorumluluğu

Caller (AddPinDialog / PinDetailsDialog) state'ini kendi yönetir:
- Form controllers
- ChangeNotifier viewModel
- Suitability check
- Save/Delete logic

Caller `build()` döner: `PinPanelShell(body: <kendi-içeriği>)`.

## Refactor Sonrası Davranış

- ✅ Pin tıklama → AI FAB doğru pozisyonda (her iki widget aynı pop-up shell)
- ✅ AddPinDialog + PinDetailsDialog kabuk değişimi tek yerde
- ✅ Yeni mod eklemek: yeni dialog widget, aynı shell — body değiştir
- ✅ Lottie animasyonu shell'e eklenirse iki widget aynı anda alır

## ⚠️ Yaygın Tuzaklar

1. **Body'yi `SingleChildScrollView` ile sarma**: shell zaten içerir. Caller
   `Column(mainAxisSize: min)` döner, scroll otomatik.
2. **Kendi gradient/border/maxHeight**: shell'in işi. Caller karıştırmasın.
3. **Reverse geocode caller'da yapma**: shell yapıyor — `MapViewModel.fetchReverseGeocode`
   cache'i paylaşılır. Caller header gözlemi için VM'i `listen: true` Provider'la dinleyebilir
   ama gerek yok (shell halleder).
4. **Tail wrapping**: `_PinPopoverWithTail` shell'in DIŞINDA — map_screen
   pop-up overlay'inde sarmalanır. Shell tail oluşturmaz.

## Bağlantılar

- [[PinAddFlow]] — V3 popover → V2 form akışı, shell bu akışın V2 kısmı
- [[AnimatedGradientButton]] — yan widget örneği (composition pattern)
- [[MapScreen]] — overlay (`_buildPinFormOverlay` + `_buildPinDetailOverlay`) shell'i sarar
- [[INBOX]] — 2026-05-09 sprint

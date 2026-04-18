---
tags: [pitfall, critical, stack, flutter]
updated: 2026-04-18
related: [MapScreen, MapBottomSheet]
---

# ⚠️ Stack'e Positioned Olmayan Widget Eklemek

**En sık yapılan hata.** Bu kuralı ihlal ettiğinde semptom zor anlaşılır: harita görünür ama tıklanamaz, butonlar çalışmaz, özellikle mobilde.

## Kural

> `MapScreen`'deki ana `Stack`'e eklenen **her widget mutlaka `Positioned` (veya `AnimatedPositioned`) ile sarılmalı.**

İstisnalar:
- Platform harita widget'ı (ilk child, tam ekran olması bekleniyor)
- `AnimatedPositioned` — Positioned'ın animasyonlu varyantı, eşdeğer

## Neden?

`Stack` içindeki non-positioned widget'lar **ebeveyn'in maksimum boyutuna** büyür. `MapScreen` ekran kadar olduğundan, non-positioned child tam ekran alır ve:

1. **Görünmez dokunma katmanı** yaratır
2. Haritanın ve diğer butonların **üstünde** durur (Stack içinde sonra geldiği için)
3. Kullanıcı harita veya butona tıkladığında → dokunma bu görünmez widget tarafından yutulur

## Yanlış vs Doğru

### ❌ YANLIŞ
```dart
Stack(
  children: [
    MapViewMaplibreWeb(),  // OK (ilk, tam ekran)

    // ❌ Non-positioned! Tüm ekranı kaplar, invisible overlay olur
    SizedBox.expand(child: MyOverlay()),

    // ❌ Tüm ekranı kaplar
    IgnorePointer(child: MyWidget()),

    // ❌ StackFit.expand default olabilir
    Container(child: MyButton()),

    // ❌ Tüm genişliği kaplar ama Stack içinde Positioned değil
    Column(children: [...]),
  ],
)
```

### ✅ DOĞRU
```dart
Stack(
  children: [
    MapViewMaplibreWeb(),  // Tam ekran, OK

    Positioned(
      top: 20, left: 20,
      child: MyOverlay(),
    ),

    Positioned(
      top: 20, right: 20,
      child: MyButton(),
    ),

    AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      bottom: isExpanded ? 0 : -200,
      left: 0, right: 0,
      child: BottomPanel(),
    ),
  ],
)
```

## Semptomlar

| Semptom | Muhtemel neden |
|---|---|
| Mobilde hiçbir şeye tıklanamıyor | Stack'te non-positioned widget |
| Web'de çalışıyor ama mobilde çalışmıyor | Web'de `PointerInterceptor` + Stack hatası bazen görünmez |
| Belirli bir butona tıklama geçmiyor | O butonun üstünde Positioned olmayan veya başka Positioned var |
| Harita zoom/pan çalışmıyor | Haritanın üstünde görünmez overlay |

## Debug

Şüpheleniyorsan `Stack`'teki tüm child'ları kontrol et:

```dart
// Debug için: geçici olarak her child'ı renkli yap
Positioned(
  top: 20, left: 20,
  child: ColoredBox(color: Colors.red.withOpacity(0.3), child: MyWidget()),
)
```

Kırmızı kaplayan görünmez bir alan çıkıyorsa → sorun orada.

## Tarihte Yapılan Hatalar

1. `SidebarFooter`'ı Positioned olmadan eklemek → mobilde tüm harita kilitlendi
2. Legends için `Column` kullanmak → legend genişliği tüm ekranı kapladı
3. `IgnorePointer` ile sarmak — dokunmayı engeller ama yine de non-positioned tüm alanı kaplar

## "PointerInterceptor" ile İlişkisi

`PointerInterceptor` (pointer_interceptor paketi) **web-only** bir sorunu çözer: HTML iframe'lerine (harita canvas dahil) Flutter widget'ları click'i sızdırır. Her overlay widget'ı `PointerInterceptor` ile sarılır.

Ama `PointerInterceptor` **Stack kuralının yerine geçmez**. Yine de Positioned gerekli:

```dart
Positioned(                   // ← Positioned ilk
  top: 20, right: 20,
  child: PointerInterceptor(  // ← PointerInterceptor içeride
    child: MyButton(),
  ),
)
```

## İnvariant'lar

1. ⚠️ **Stack'in ikinci ve sonraki child'ları her zaman `Positioned`/`AnimatedPositioned`**.
2. ⚠️ **`StackFit.expand`, `SizedBox.expand`, `IgnorePointer(child: ...full-size...)` kullanma** — non-positioned davranırlar.
3. ✅ **İlk child tam ekran olmak isterse** `Positioned.fill(child: ...)` kullan, çıplak widget değil.

## Bağlantılar

- [[MapScreen]] — Stack'i tutan ekran
- [[MapBottomSheet]] — Stack'e eklenen panel
- [[PlatformConsistency]] — bu kural hem web hem mobil için

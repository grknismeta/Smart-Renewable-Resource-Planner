---
tags: [widget, screen, critical]
updated: 2026-04-18
related: [MapViewModel, MapStackPositioned, MapBottomSheet, MapViewMaplibreNative, MapViewMaplibreWeb]
file: frontend/lib/features/map/screens/map_screen.dart
---

# MapScreen

Ana harita ekranı. Root Scaffold + Stack + platform-specific harita widget'ı + tüm overlay UI bileşenlerini içerir.

## Yapı

```
Scaffold
  body: Stack (ana)
    ├─ (platform-specific) MapViewMaplibreNative / MapViewMaplibreWeb
    ├─ Stack (dashboard + choropleth tooltip)
    │    ├─ Positioned: MapDashboard (veya GlobeInfoCard)
    │    └─ Positioned: _ChoroplethTooltip  ← ilçe tıklandığında
    ├─ Positioned: LayersPanel (sağ üst)
    ├─ Positioned: sağ butonlar (zoom, 3D, modları aç)
    ├─ AnimatedPositioned: animation controls (alt orta)
    ├─ Positioned: legends (heatmap, choropleth)
    └─ MapBottomSheet (en üstte, z-index için Stack sonu) ← [[MapBottomSheet]]
```

## 🔴 Stack Kuralı (KRİTİK)

> Ana Stack'e eklenen **her widget `Positioned` ile sarılmalı**. İstisnalar: `AnimatedPositioned`, `PointerInterceptor` (child'ı Positioned), platform harita widget'ı (tam ekran).

Non-positioned bir widget `Stack`'e eklenirse: tam ekran kaplar ve görünmez bir dokunma engelleyici olur → haritaya ve altındaki butonlara **tıklanamaz**.

Detay: [[MapStackPositioned]].

## Z-Index (Stack Sırası)

Stack'te **sonra gelen üstte** gösterilir. Dokunma öncelikli olarak üsttekine gider.

Mevcut sıra (alttan üste):
1. Platform harita widget'ı (tam ekran)
2. Dashboard + choropleth tooltip
3. LayersPanel
4. Sağ üst butonlar
5. Animation controls
6. Legends
7. **MapBottomSheet** (en üst — alt paneli/çekmeceyi her şeyin üstünde göster)

Kural: **`MapBottomSheet` her zaman en sonda** (Stack sonunda). Aksi halde bazı overlay'lerin arkasında kalır.

## `_ChoroplethTooltip` (iç widget)

Choropleth katmanı açıkken bir ilçeye tıklanınca dashboard'un altında küçük bilgi kartı. İçerik:

- İlçe adı
- Ölçüm değeri (sıcaklık/rüzgar/ışınım) + renk kutusu
- Veri zaman damgası ("X dk/saat önce güncellendi")
- Kapat butonu

Veri kaynağı:
- `mapViewModel.choroplethTapDistrict` — tıklanan ilçe
- `mapViewModel.choroplethTapData` — ham değerler
- `mapViewModel.choroplethTapColor` — o ilçenin rengi (tooltip rengine eşle)
- `mapViewModel.choroplethDataTimestamp` — global timestamp ([[ChoroplethScales]])

## `_formatTimestamp(iso)` — Göreli Zaman

`data_timestamp` ISO 8601 string'ini "X dk/saat önce güncellendi" formatına çevirir. Backend `_meta.data_timestamp` alanından gelir ([[WeatherRouter]]).

## Responsive Davranış

```dart
final isMobile = constraints.maxWidth < 700;
final scale = isMobile ? 0.85 : 1.0;  // dashboard ölçeği
final pad = isMobile ? 12.0 : 20.0;
```

Dashboard, tooltip, butonlar `Transform.scale` ile mobilde küçültülür.

## İnvariant'lar

1. ⚠️ **MapBottomSheet Stack'in son elemanı olmalı** — z-index.
2. ⚠️ **Tüm non-platform-harita child'lar Positioned/AnimatedPositioned**. [[MapStackPositioned]].
3. ✅ **`PointerInterceptor`** — web'de harita canvas'ı sticky pointer aldığı için tüm UI overlay'lerini `PointerInterceptor` ile sarmak zorunlu (aksi halde click harita'ya geçer).
4. ✅ **`Selector` / `Consumer`**: Tüm state tüketimi ViewModel provider üzerinden, direkt state referansı yok.

## Bilinen Tuzaklar

- ⚠️ **Web'de harita'ya tıklanmıyor**: muhtemelen Stack'te Positioned olmayan bir widget var. İlk kontrol: `Stack(children: ...)` içindeki her child.
- ⚠️ **PointerInterceptor eksik**: Web'de UI butonuna tıklama haritaya sızar → hem button hem harita aynı anda tetiklenir.
- ⚠️ **Tooltip pozisyonu**: Mobile'da dashboard daha küçük → tooltip y pozisyonu `dashboardBottom` ile hesaplanır, hard-code etme.

## Son Değişimler

- **2026-04-18**:
  - MapBottomSheet Stack sonuna taşındı (z-index)
  - `_ChoroplethTooltip` `dataTimestamp` parametresi alır
  - `_formatTimestamp` göreli zaman metodu eklendi

## Bağlantılar

- [[MapViewModel]] — tüketilen state
- [[MapStackPositioned]] — Stack kuralı
- [[MapBottomSheet]] — alt panel
- [[MapViewMaplibreNative]] / [[MapViewMaplibreWeb]] — harita
- [[ChoroplethScales]] — tooltip veri kaynağı

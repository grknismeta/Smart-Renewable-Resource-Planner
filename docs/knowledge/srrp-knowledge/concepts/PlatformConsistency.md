---
tags: [concept, platform, critical]
updated: 2026-05-08
related: [MapViewModel, MapViewMaplibreNative, MapViewMaplibreWeb, SelectionModes]
---

> **🛑 PRE-FLIGHT CHECK (Claude için):** Harita / state ile ilgili her fix yapmadan önce
> şu üç dosyayı **birlikte** taramalısın:
> 1. `frontend/lib/features/map/viewmodels/map_viewmodel.dart` (VM — paylaşılan)
> 2. `frontend/lib/features/map/widgets/map_view_maplibre_web.dart` (Web)
> 3. `frontend/lib/features/map/widgets/map_view_maplibre_native.dart` (Native/Mobil)
>
> Eğer fix sadece `web.dart` veya sadece `index.html`'de yapılıyorsa **yetersizdir**.
> VM seviyesinde çözülemeyen şey her iki adapter'da paralel uygulanmalı. Aksi halde
> kullanıcı mobilde fark eder ve tekrar bildirir. Bu kuralı yazıya dökmek zorunda
> kalan benim — Claude'un default davranışı **web öncelikli**, bu hatalı.

# Platform Consistency (Web ↔ Mobil)

Uygulama Flutter ile yazılmış tek kod tabanı ama harita katmanı platform-farklı. **Her özellik iki tarafta da çalışmalı ve aynı davranmalı.**

## 🔑 Temel Kural

> Bir özellik **ya her iki platformda birden** çalışır ya da hiçbirinde. "Sadece web'de" veya "sadece mobilde" kabul edilemez.

Kullanıcı talep etti: *"Değişiklikleri yaparken hem mobilde hem de telefonda aynı uygulama / aynı özellikler / aynı veriler olması gerekiyor."*

## Mimari

```
                    ┌─────────────────────┐
                    │    MapViewModel     │  ← Tek state kaynağı
                    │   (platform-free)   │     Hem web hem native tüketir
                    └──────────┬──────────┘
                               │ ChangeNotifier
                    ┌──────────┴──────────┐
                    ▼                     ▼
        ┌─────────────────────┐   ┌──────────────────────┐
        │ MapViewMaplibre     │   │ MapViewMaplibre      │
        │ Native (Dart SDK)   │   │ Web (JS interop)     │
        └─────────────────────┘   └──────────┬───────────┘
                                             │
                                             ▼
                                  ┌──────────────────────┐
                                  │  web/index.html      │
                                  │  srrp* JS functions  │
                                  └──────────────────────┘
```

- **Native**: Dart → `maplibre.dart` SDK → doğrudan harita.
- **Web**: Dart → `@JS('window.srrp*')` interop → JS fonksiyonları → MapLibre GL JS → harita.

## Single Source of Truth

**ViewModel** = tek gerçek. Native ve web widget'lar sadece VM'e bakar, hiçbir state kendi içlerinde tutulmaz.

- ✅ VM'e yeni alan ekle → native ve web ikisi de `_onVmChanged` / `addListener` üzerinden tetiklenir.
- ❌ Sadece native widget'a state ekleme → web senkron değil kalır.

## Senkronizasyon Stratejisi

Her iki widget da **idempotent sync metodları** uygular. Listener tetiklendiğinde son duruma eşitlerler:

| Native | Web | Amaç |
|---|---|---|
| `_syncBorders(vm)` | `_syncSelectionMode(vm)` | Seçim katmanları |
| `_syncChoropleth(vm)` | `_syncChoropleth(vm)` | Choropleth rengi |
| `_syncWindParticles(...)` | `_syncWindParticles(...)` | Rüzgar parçacıkları |
| `_syncCloud(...)` | `_syncCloud(...)` | Bulut katmanı |

**İdempotent demek**: Aynı VM durumunda metodun 10 kez çağrılması 1 kez çağrılmasıyla aynı sonucu verir. Son değerleri cache'leyerek (`_lastXxx` alanları) sadece **gerçek değişimde** iş yap.

## Fark Kaynakları (Kaçınılmaz)

Bazı şeyler inherently farklı:

| Konu | Native | Web |
|---|---|---|
| Tıklama algılama | `onMapTap` → `_selectGeoAtPoint` (point-in-polygon Dart'ta) | JS `map.on('click', layer)` → callback Dart'a |
| Hover | Yok (mobil touch) | JS `mousemove` → rAF throttle |
| 3D arazi | `terrain` style | `srrpSetTerrain` |
| Rüzgar parçacıkları | `maplibre-gl-js-windgl` yok → custom Dart | JS plugin |

## Eklenen Bir Özelliğin Checklist'i

Yeni bir harita özelliği eklerken:

- [ ] VM'e alan/metod ekle ([[MapViewModel]])
- [ ] Native `_syncXxx` metodu yaz/güncelle ([[MapViewMaplibreNative]])
- [ ] Web `_syncXxx` metodu yaz/güncelle ([[MapViewMaplibreWeb]])
- [ ] Web için JS fonksiyonu (`window.srrp*`) gerekirse ekle (`web/index.html`)
- [ ] Dart'tan JS'e interop (`@JS('window.srrp*')`) tanımla
- [ ] Son durum `_lastXxx` alanlarını güncelle (gereksiz sync atla)
- [ ] `flutter analyze` temiz
- [ ] **Her iki platformda** manuel test

## Bilinen Platform Farkları (Güncel)

### İl Modu mavi vurgu
- **Native**: `_showProvinceOverlay()` — ayrı source/layer sistemi ([[MapViewMaplibreNative#Overlay]])
- **Web**: `srrpHighlightProvince()` JS fonksiyonu — sadece line katmanları ekler
- **Davranış aynı**: Seçili il mavi çerçeve, ilçeleri mavi sınırla içerde gösterilir.

### İlçe modu hover throttle
- **Native**: Yok (mobil touch, hover event'i yok)
- **Web**: `requestAnimationFrame` coalescing — hızlı mouse hareketinde ara ilçeler atlanır ([[HoverThrottle]])

### Selection layer mimarisi
- **Native**: Tek borders source/layer, dinamik içerik
- **Web**: `srrp-sel-hit` (invisible hit detection) + `srrp-sel-hover` (visual) + `srrp-sel-extrusion` (3D yükselme) + `srrp-sel-unique` (graph coloring). Çok katmanlı.

## ⚠️ Yaygın Tuzaklar

1. **"Sadece native'de düzeldi"**: Kullanıcı bunu fark eder ("Bunu hem web hem mobil için güncelledin mi?"). VM seviyesinde düzeltme yeterli değilse, hem web hem native adapter'ı güncelle.
2. **Web'de state cache**: `_lastSelectionLevel`, `_lastProvinceName` gibi alanlar — yanlış değerlerde sync atlanır. VM değişimini cache ile karşılaştırırken titiz ol.
3. **Backend farkı**: `_meta.data_timestamp` gibi response alanları her iki platformda da aynı şekilde tüketilmeli. Choropleth global timestamp hem web hem mobilde aynı tooltip'i gösterir.
4. **Test boşlukları**: `flutter test` unit testleri VM'i test eder ama widget testleri platform-specific değil. Gerçek cihaz/web tarayıcı ile manuel doğrula.

## Bağlantılar

- [[MapViewModel]] — single source of truth
- [[MapViewMaplibreNative]] — native adapter
- [[MapViewMaplibreWeb]] — web adapter
- [[SelectionModes]] — platform-bağımsız mod mantığı
- [[HoverThrottle]] — web-only özellik

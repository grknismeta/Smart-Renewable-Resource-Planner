---
tags: [viewmodel, state, critical]
updated: 2026-04-18
related: [SelectionModes, SelectionLevel, MapViewMaplibreNative, MapViewMaplibreWeb]
file: frontend/lib/features/map/viewmodels/map_viewmodel.dart
---

# MapViewModel

Harita state'ini yöneten merkezi sınıf. Platform-bağımsız — web ve native widget'lar **aynı** VM'i tüketir.

## Amaç

- Kullanıcı seçim durumunu (bölge/il/ilçe) tutar.
- Pin, choropleth, hava durumu, ML heatmap, animasyon state'lerini yönetir.
- `ChangeNotifier` — listener'lar değişikliklerde tetiklenir.

## Kritik Alanlar

### Seçim state'i

| Alan | Public mi? | Anlamı |
|---|---|---|
| `_selectionLevel` | `selectionLevel` getter | Şu anki seviye (region/province/district/none) |
| `_initialSelectionMode` | ✅ `initialSelectionMode` getter | Kullanıcının açtığı mod |
| `_selectedRegionName` | ✅ | Seçili bölge |
| `_selectedProvinceName` | ✅ | Seçili il |
| `_selectedProvinceCode` | ✅ | 3 harfli il kodu (örn. "ist") |
| `_selectedDistrictName` | ✅ | Seçili ilçe |

Mod davranışları: [[SelectionModes]].

### Veri state'i

- `_pins` / `filteredPins` — pin listesi (filtreli)
- `_provinceSummaries` / `_districtSummaries` / `_regionSummaries` — backend özet verileri
- `_weatherSummary` — hava durumu özetleri (heatmap için)
- `_windVectors` — rüzgar parçacıkları için
- Choropleth: [[MapLayerMixin]] içinde

### UI state'i

- `showCloudLayer` / `cloudOpacity`
- `show3DTerrain`, `show3DBuildings`, `show3DTurbines`
- `showPinClusters`, `showWindParticles`
- `isAnimationMode`, frame state
- `_isRefreshing` — veri güncelleme spinner'ı

## Kritik Metodlar

### Mod açma
```dart
openRegionMode()      // region modunu açar
openProvincesMode()   // il modunu açar (toggleProvinceMode eski adı)
openDistrictsMode()   // ilçe modunu açar
closeSelectionMode()  // tüm moddan çıkar
```

### Seçim
```dart
selectRegion(name)    // bölge seç → level = province
selectProvince(name)  // il seç → level = district (HER ZAMAN)
selectDistrict(name, {province})  // ilçe seç, level değişmez
clearSelectedDistrict()
clearAllSelection()   // level → _initialSelectionMode'a geri sar
```

### Refresh
```dart
refreshAllWeatherData()  // choropleth cache'i temizler, yeniden çeker
bool get isRefreshing
```

## Invariant'lar

1. ⚠️ **`selectProvince()` HER ZAMAN `_selectionLevel = district`'e geçer**. Aksi deneme yapıldı, sorun çıkardı. Bkz. [[SelectionModes#Click Handler]].
2. ⚠️ **`_initialSelectionMode` asla `selectProvince/selectDistrict` içinde değişmez**. Sadece `openXxxMode()` ve `closeSelectionMode()` değiştirir.
3. ⚠️ **`clearAllSelection()` `_initialSelectionMode`'a geri döner**, `none`'a değil.
4. ✅ **`safeNotify()` kullan**, `notifyListeners()` değil — dispose sonrası crash'i önler.
5. ✅ **Listener tetiklenme sırası önemli değil**: Web/native widget'lar idempotent `_syncXxx` metodlarıyla son duruma eşitlenir.

## Bilinen Tuzaklar

- ⚠️ `selectProvince("Ankara")` çağrısı sonrası `vm.selectionLevel == district` olur — bekleyerek davranış yazma.
- ⚠️ `selectDistrict()` içinde `_selectedProvinceName` güncellenir (province parametresi verilmişse). Bu, **İlçe modunda** da olur — bu yüzden `_syncSelectionMode` dikkatli olmalı, İlçe modunda province filtresi uygulamamalı. Bkz. [[MapViewMaplibreWeb#İlçe modu hatası]].
- ⚠️ **Private alana dışarıdan erişme**: `vm._initialSelectionMode` (eski yanlış) → `vm.initialSelectionMode` (public getter). 2026-04-18'de düzeltildi.

## Bağlı Dosyalar

- `map_layer_mixin.dart` — choropleth + layer management mixin
- `map_view_maplibre_native.dart` — native tüketici ([[MapViewMaplibreNative]])
- `map_view_maplibre_web.dart` — web tüketici ([[MapViewMaplibreWeb]])
- `map_screen.dart` — UI root
- `map_bottom_sheet.dart` — panel tüketicisi

## Son Değişimler

- **2026-04-18**:
  - `initialSelectionMode` public getter eklendi
  - `_initialSelectionMode` alanı eklendi (mod takibi)
  - `clearAllSelection()` artık initialMode'a geri döner
  - `refreshAllWeatherData()` + `isRefreshing` eklendi
  - `selectProvince()` davranışı: her zaman district seviyesine geç (önceki "province-stay" denemesi geri alındı)

## Bağlantılar

- [[SelectionModes]] — mod davranışları
- [[SelectionLevel]] — enum
- [[MapLayerMixin]] — choropleth logic
- [[MapViewMaplibreNative]]
- [[MapViewMaplibreWeb]]

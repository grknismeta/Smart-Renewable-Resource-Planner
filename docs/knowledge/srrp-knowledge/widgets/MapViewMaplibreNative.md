---
tags: [widget, platform-native, mobile]
updated: 2026-04-18
related: [MapViewModel, SelectionModes, MapViewMaplibreWeb, PlatformConsistency]
file: frontend/lib/features/map/widgets/map_view_maplibre_native.dart
---

# MapViewMaplibreNative

Android/iOS için MapLibre Native SDK tabanlı harita widget'ı. Web karşılığı: [[MapViewMaplibreWeb]].

## Amaç

- `MapViewModel`'i dinler, harita katmanlarını Dart tarafından doğrudan MapLibre SDK ile günceller.
- Hiçbir JS interop yok — tamamen Flutter/Dart.
- Büyük geo GeoJSON dosyalarını Dart'ta parse eder, graph coloring uygular, style.addSource/addLayer ile ekler.

## Kritik Sabitler (Source/Layer ID'leri)

```dart
// Ana borders (il veya ilçe sınırları, tek aktif seviye)
_bordersSourceId    = 'srrp-borders'
_bordersFillLayerId = 'srrp-borders-fill'
_bordersLineLayerId = 'srrp-borders-line'

// İl modu overlay (seçili il + ilçeleri üstüne)
_overlaySourceId    = 'srrp-overlay-borders'
_overlayFillLayerId = 'srrp-overlay-fill'
_overlayLineLayerId = 'srrp-overlay-line'       // ilçe sınırları mavi
_overlayProvLineId  = 'srrp-overlay-prov-line'  // il dış sınırı kalın mavi
// + ek source: 'srrp-overlay-prov' (il feature'ı)
```

## Tıklama Akışı: `_selectGeoAtPoint(point, vm)`

Satır ~580-712. Mod-farkındalıklı 4 dal:

```
1. İlçe GeoJSON'dan il+ilçe bul (point-in-polygon)
2. Bulamazsa il GeoJSON'dan il bul
3. initialMode'a göre dallan:
   - region   → bölge drill-down
   - province → overlay yaklaşımı (aşağıda)
   - district → sadece selectDistrict
   - (fallback)
```

Detaylı akış: [[SelectionModes#Click Handler]].

## 🔑 Overlay Sistemi (İl Modu)

**Problem**: İl modunda kullanıcı il seçtiğinde, diğer illerin hala görünmesi ve aynı renkte kalması gerekiyor. Seçili il mavi çerçeve alır, ilçeleri üstüne çizilir.

**Çözüm**: Overlay katmanları. Ana `_borders` (tüm iller) korunur, üstüne `_overlay*` katmanları eklenir.

```
_showProvinceOverlay(provinceName):
  1. Seçili ilin ilçelerini getir (NAME_1 filter)
  2. Graph coloring uygula
  3. Overlay fill + line (mavi) ekle
  4. Seçili ili province GeoJSON'dan çek → kalın mavi dış sınır
```

### Overlay yaşam döngüsü

| Durum | Ne olur |
|---|---|
| İl modu aç | `_loadProvinceBorders()` — tüm iller, graph coloring |
| İl seçimi | `_showProvinceOverlay(province)` — overlay eklenir |
| Başka ile geçiş | `_showProvinceOverlay(newProv)` — overlay yeniden çizilir |
| Aynı ilde ilçe seçimi | Overlay dokunulmaz (sadece bilgi paneli güncellenir) |
| Mod kapat | `_removeBorderLayers()` → cascade `_removeOverlayLayers()` |

## `_syncBorders(vm)` Dal Mantığı

Satır ~1725. ViewModel state → harita katmanları eşleme. Dal sırası **önemli**:

```dart
if (level == district && initial == province) {
  // İL MODU: overlay yaklaşımı
  if (!_bordersActive) await _loadProvinceBorders();  // tüm iller
  if (provinceChanged || !_overlayActive) await _showProvinceOverlay(province);
}
else if (level == district && initial == district) {
  // İLÇE MODU: tüm ilçeler, renkler değişmez
  await _removeOverlayLayers();
  if (!_bordersActive) await _loadDistrictBorders(null);
  // İlçe seçiminde hiçbir şey yeniden çizilmez
}
else if (level == district) {
  // BÖLGE MODU → ilçe seviyesi (drill-down)
  await _removeOverlayLayers();
  await _loadDistrictBorders(province, highlightDistrict: district);
}
else if (level == region) {
  await _loadProvinceBorders(regionFilter: null);
}
else {
  // Bölge seçiliyken il seviyesi
  await _loadProvinceBorders(regionFilter: region);
}
```

## Graph Coloring

Komşu polygon'lar farklı renk alır. Komşuluk = **vertex sharing** (~100m hassasiyet). Bkz. [[GraphColoring]].

Kullanıldığı yerler:
- `_loadProvinceBorders()` → il renklendirme
- `_loadDistrictBorders()` → ilçe renklendirme
- `_showProvinceOverlay()` → seçili ilin ilçeleri

## Ege Adaları Filtresi

Türkiye'ye ait olmayan Yunan adalarını GeoJSON'dan ayıkla: `_isFeatureInTurkey()` statik metodu. Centroid tabanlı bounds kontrolü:
- Longitude: 25–46°
- Latitude: 35–43°

Uygulandığı yerler: `_getDistrictFeatures`, `_getProvinceFeatures`, choropleth path.

## Invariant'lar

1. ⚠️ **`_removeBorderLayers()` cascade `_removeOverlayLayers()` çağırır**. Bunu kaldırma — mod değişiminde stale overlay kalır.
2. ⚠️ **`_bordersSyncing` flag** — reentrancy koruma. `_syncBorders` içinde true'ya set et, finally false.
3. ⚠️ **`_geoSelectBusy` flag** — `_selectGeoAtPoint` çalışırken `_syncBorders` tekrar tetiklenmesin.
4. ✅ **Style load sırası**: `_style == null || !_styleLoaded` kontrolü her public API girişinde yapılmalı.
5. ⚠️ **Private alan erişimi**: `vm._initialSelectionMode` değil, `vm.initialSelectionMode` (getter).

## Bilinen Tuzaklar

- ⚠️ **Overlay + borders aynı anda kaldırılmaz**. `_removeBorderLayers` overlay'i de temizler, ama `_removeOverlayLayers` borders'ı temizlemez. Tersi gerekiyorsa manuel çağır.
- ⚠️ **İlçe modunda `_loadDistrictBorders(null)`**. Province parametresi `null` geçmek = tüm Türkiye. Provinsi verirsen sadece o ilin ilçeleri gelir.
- ⚠️ **`selectProvince()` sonrası `_selectionLevel = district`** → `_syncBorders` district dalına girer. İl modundaysak overlay, değilsek district borders.

## Bağlı Metodlar (ana sınıf içinde)

| Metod | Amaç |
|---|---|
| `_loadProvinceBorders({regionFilter})` | Tüm iller veya bölge filtresiyle |
| `_loadDistrictBorders(provinceName, {highlightDistrict})` | Tüm ilçeler veya bir ilin |
| `_showProvinceOverlay(provinceName)` | İl modu overlay |
| `_removeBorderLayers()` | Tüm borders + overlay |
| `_removeOverlayLayers()` | Sadece overlay |
| `_colorizeFeatures(features, {useRegionColors})` | Graph coloring |
| `_flyToProvinceCentroid(name)` | Kamera animasyonu |
| `_flyToRegionBounds(name)` | Kamera animasyonu (bölge) |
| `_isFeatureInTurkey(feature)` | Ege adaları filtresi |

## Son Değişimler

- **2026-04-18**:
  - Overlay sistemi eklendi (İl modu için)
  - `_initialSelectionMode` okuma + 4-dal click handler
  - Ege adaları filtresi
  - Fixed physical choropleth scales
  - Private field erişim hatası düzeltildi

## Bağlantılar

- [[MapViewModel]] — tüketilen state
- [[SelectionModes]] — mod mantığı
- [[MapViewMaplibreWeb]] — web eşleği
- [[PlatformConsistency]] — iki platform nasıl senkron
- [[GraphColoring]] — renklendirme algoritması

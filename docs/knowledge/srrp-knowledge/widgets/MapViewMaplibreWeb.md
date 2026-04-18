---
tags: [widget, platform-web]
updated: 2026-04-18
related: [MapViewModel, MapViewMaplibreNative, SelectionModes, PlatformConsistency, HoverThrottle]
file: frontend/lib/features/map/widgets/map_view_maplibre_web.dart
---

# MapViewMaplibreWeb

Web için MapLibre GL JS tabanlı harita widget'ı. Native karşılığı: [[MapViewMaplibreNative]].

## Amaç

- `MapViewModel`'i dinler, değişiklikleri **JS interop** üzerinden MapLibre GL JS tarafına iletir.
- Direkt harita API'si yerine `window.srrp*` fonksiyonlarını çağırır (tanımları `frontend/web/index.html`).
- Callback'ler: JS → Dart yönünde interop (`JSFunction.toJS`).

## Mimari

```
MapViewModel (Dart)
     ↓ addListener(_onVmChanged)
MapViewMaplibreWeb (Dart widget)
     ↓ @JS('window.srrp*')
window.srrp*   (JS fonksiyonları)
     ↓
MapLibre GL JS
     ↓
<canvas>
```

## JS Interop Deklarasyonları

`@JS('window.srrpXxx')` ile Dart'tan JS'e köprü. Ana gruplar:

### Setup
- `_jsSetTerrain(enable)`, `_jsSetCloudLayer(enable, opacity)`, `_jsSetSky(enable)`, `_jsSetGlobe(enable)`
- `_jsAddBuildings(beforeId)`, `_jsStartWindParticles(geojson)`, `_jsStopWindParticles()`

### Seçim Modu (Bkz. [[SelectionModes]])
- `_jsSetupRegionMode()`, `_jsSetupProvinceMode(regionFilter)`, `_jsSetupDistrictMode(provinceName)`
- `_jsClearSelectionMode()`
- `_jsHighlightProvince(provinceName)` — İl modu mavi sınır ([[SelectionModes#İl Modu]])

### Callback Kayıt
- `_jsSetRegionClickFn(fn)`, `_jsSetProvinceClickFn(fn)`, `_jsSetDistrictClickFn(fn)`
- `_jsSetPinHoverFn(fn)`, `_jsSetPinClickFn(fn)`
- `_jsSetAnimFrameCallback(fn)`

## Click Callback'leri (JS → Dart)

`_handleRegionClickJs`, `_handleProvinceClickJs`, `_handleDistrictClickJs` — JS'ten gelen tıklamayı işler, **mod-farkındalıklı** olarak VM'i günceller.

### `_handleDistrictClickJs(arg)` — İlçe Callback

Payload format: `"province|district"` (composite). Örn: `"İstanbul|Kadıköy"`.

Mod-farkındalıklı davranış:
```dart
if (initial == SelectionLevel.province) {
  // İL MODU: başka ile tıklanırsa geçiş, aynı ildeyse ilçe seç
  if (province != vm.selectedProvinceName) vm.selectProvince(province);
  else vm.selectDistrict(district, province: province);
}
else if (initial == SelectionLevel.region) {
  // BÖLGE MODU drill-down: benzer mantık
  ...
}
else if (initial == SelectionLevel.district) {
  // İLÇE MODU: sadece bilgi
  vm.selectDistrict(district, province: province);
}
```

Bu mod-farkındalıklı mantık olmadan: İl modunda farklı ile tıklamak `selectDistrict` çağırırdı → geçersiz state.

## `_syncSelectionMode(vm)` — Ana Sync Metodu

ViewModel seviyesine göre uygun JS setup'ı çağırır:

```dart
switch (vm.selectionLevel) {
  case none:     _jsClearSelectionMode();
  case region:   _jsSetupRegionMode();
  case province: _jsSetupProvinceMode(vm.selectedRegionName);
  case district:
    final initial = vm.initialSelectionMode;
    if (initial == province) {
      _jsSetupDistrictMode(null);                    // tüm ilçeler tıklanabilir
      _jsHighlightProvince(vm.selectedProvinceName); // mavi sınır
    } else if (initial == district) {
      _jsSetupDistrictMode(null);                    // İlçe modu: tüm ilçeler
    } else {
      _jsSetupDistrictMode(vm.selectedProvinceName); // Bölge modu drill-down
    }
}
```

**Kritik**: `initial == district` dalı olmadan, İlçe modunda user bir ilçeyi tıklayınca `selectedProvinceName` set edilir → sonraki sync'te filtre uygulanır → sadece o ilin ilçeleri görünür. Bkz. [[SelectionModes#İlçe modu]].

## `_onVmChanged()` — Listener Optimizasyonu

Her VM değişiminde tüm katmanları güncellememek için cache'li karşılaştırma:

```dart
final provinceChanged = vm.selectedProvinceName != _lastProvinceName;
final isDistrictDataOnly = provinceChanged &&
  vm.selectionLevel == district &&
  vm.selectedDistrictName != null;

if (levelChanged || (provinceChanged && !isDistrictDataOnly)) {
  _syncSelectionMode(vm);  // ağır iş
}
```

`isDistrictDataOnly` = "il değişmiş ama sadece ilçe seçimi nedeniyle" → ağır sync skip edilir, sadece veri kartı güncellenir.

## Süreli Sync Pattern

- `_syncing` flag: ağır async sync çalışırken reentrancy önler.
- `_syncPending`: sync çalışırken VM değişirse "dirty" işaretlenir, bitince tekrar çalıştırılır.

## Yaşam Döngüsü

```
initState → map oluştur → _vmRef!.addListener(_onVmChanged)
         → style.onLoad → callback'leri JS'e kaydet
           (_pinHover, _pinClick, _regionClick, ...)
dispose  → removeListener
         → tüm JS callback'leri noop ile override (dispose sonrası çağrılmasın)
         → _jsClearSelectionMode()
```

## İnvariant'lar

1. ⚠️ **`kIsWeb` kontrolü her interop çağrısından önce** — mobilde JS yok.
2. ⚠️ **`_styleLoaded` kontrolü** — stil yüklenmeden önce setup çağırma.
3. ✅ **Callback'leri dispose'da noop'la** — aksi halde async callback widget unmount sonrası VM'e eriştirir → crash.
4. ⚠️ **VM'den private alanlara direkt erişme** — `vm._xxx` değil, public getter. 2026-04-18'de hata vardı: `vm._initialSelectionMode` → düzeltildi.

## Bilinen Tuzaklar

- ⚠️ **JS fonksiyonu `index.html`'de tanımlı değilse** runtime error verir (`window.srrpXxx is not a function`). Yeni JS fn eklerken hem HTML hem Dart tarafını güncelle.
- ⚠️ **`_syncAll` çok ağır**: Heatmap + pin + choropleth + wind particles hepsini sırayla günceller. `_anyMapDataChanged()` guard'ı gereksiz çağrıları önler — kaldırma.
- ⚠️ **Style reload** (tema değişimi vb.): Tüm JS tarafındaki kurulum kaybolur. Stil load sonrası tüm callback'leri yeniden bağla.

## Bağlantılar

- [[MapViewModel]] — tüketilen state
- [[MapViewMaplibreNative]] — native eşleği
- [[SelectionModes]] — mod mantığı
- [[PlatformConsistency]] — web↔mobil senkron
- [[HoverThrottle]] — İlçe modu mouse performansı (JS tarafında)

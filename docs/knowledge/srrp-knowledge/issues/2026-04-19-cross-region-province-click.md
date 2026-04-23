---
tags: [issue, resolved, web, native, selection-modes]
opened: 2026-04-19
resolved: 2026-04-19
severity: high
platform: all
related: [SelectionModes, MapViewMaplibreWeb, MapViewMaplibreNative, "issues/2026-04-18-il-modu-cross-province-click", "issues/2026-04-18-handle-selection-click-initial-mode"]
commit:
---

# Her Seviyede Cross-Region / Cross-Province Tıklama Tek Adımda Olmalı

## Belirti

Kullanıcı spec'i (net):

> - İl modundayken diğer ile tıkladığımızda o ile geçebiliriz.
> - Bölge modundayken başka bölgeye tıkladığımızda o bölgeye geçeriz.
> - Ege seçiliyken Karadeniz'i tıklarsam o bölgeye geçerim.
> - Bölgeyi seçtikten sonra il seçersem ile geçerim. Hala tıklama ile diğer illere geçebilirim. Hala tıklama ile diğer bölgelere geçebilirim.
> - İl seçtikten sonra bir tıklamayla başka ile geçebilirim.

Şu anki durum (fix öncesi):

1. **Bölge modu province seviyesinde:** `srrpSetupProvinceMode(regionFilter)` hit filter `['==', 'REGION', regionFilter]` → farklı bölgenin ili **clickable değildi**. Kullanıcı başka bölgeye geçmek için önce bölgeye dönmek zorunda kalıyordu (2+ tıkla).
2. **Bölge modu district seviyesinde:** Province fallback layer (`srrp-sel-hit-prov-fallback`) seçili il dışı tüm iller için clickable, ama click handler sadece `provinceName` aktarıyordu. Dart `selectProvince(name)` çağrılıyor, `_selectedRegionName` **eski değerde kalıyordu** → tutarsız state (region=Karadeniz, province=İzmir gibi).
3. **Dart `_handleSelectionClick` district branch:** Farklı ile tıklama `vm.selectProvince(name1)` çağırıyor ama region mismatch kontrolü yoktu.

## Kök Sebep

Web'de iki mimari sorun:

1. **Hit filter region'a kilitli**: İyi niyetle "drill-down kapsamını daralt" için konulmuş, ama kullanıcı spec'i aksini istiyor — her seviyede üst seviye navigasyonu aktif olmalı.
2. **Click handler tek parametreli** (`_srrpProvinceClickFn(name)`): REGION property aktarılmıyordu, viewmodel'in il→bölge map'i olmadığı için Dart tarafı region'ı bulamıyordu.

Native'de benzer durum: Bölge modu district lvl'da başka bölgenin iline tıklama sadece `selectRegion(tappedRegion)` çağırıyor, il seçilmiyor → 2-tıkla ile seçim gerekiyordu (web'le inkonsistent).

## Çözüm

### 1. Web — `srrpSetupProvinceMode` hit filter kaldırıldı

```js
// ÖNCEDEN
var hitFilter = regionFilter ? ['==', ['get', 'REGION'], regionFilter] : null;
_setupSelectionLayers('srrp-borders-provinces', 'NAME_1', hitFilter, ...);

// SONRA
var colorFilter = regionFilter ? ['==', ['get', 'REGION'], regionFilter] : null;
_setupSelectionLayers('srrp-borders-provinces', 'NAME_1',
  null,                          // hit = tüm iller clickable
  window._srrpProvinceClickFn,
  'İl (' + regionFilter + ', cross-region aktif)',
  undefined, 0,
  colorFilter                    // color yalnızca seçili bölge illerine
);
```

Artık başka bölgenin ili clickable ama görsel olarak sadece seçili bölge vurgulanır.

### 2. Web — Click handler REGION'ı da aktarır

`_selClickFn` (province modunda): `clickFn(val, props.REGION || null)`.
`_selProvFallbackClickFn`: `window._srrpProvinceClickFn(nm, reg)`.

### 3. Web — `srrpQueryClick` fallback layer'ı da query eder

Flutter web'de layer-specific click handler bazı durumlarda çalışmıyor (platform view routing). Dart `_onMapClick` → `srrpQueryClick` tek güvenli path. Fallback layer'ı da query'e ekledik → tek yoldan işlenir.

### 4. Dart — `_handleProvinceClickJs` iki parametreli

```dart
void _handleProvinceClickJs(JSAny? nameArg, JSAny? regionArg) {
  ...
  if (initial == SelectionLevel.region &&
      region.isNotEmpty &&
      region != vm.selectedRegionName) {
    vm.selectRegion(region);   // bölgeyi güncelle
  }
  vm.selectProvince(name);     // ili drill-down et
}
```

### 5. Dart — `_handleSelectionClick` district branch güncelleme

```dart
case SelectionLevel.district:
  if (name1 == vm.selectedProvinceName && name2.isNotEmpty) {
    vm.selectDistrict(name2, province: name1);
  } else if (name1.isNotEmpty && name1 != vm.selectedProvinceName) {
    if (region.isNotEmpty && region != vm.selectedRegionName) {
      vm.selectRegion(region);   // cross-region il tıklama
    }
    vm.selectProvince(name1);
  }
```

### 6. Native — `_selectGeoAtPoint` Bölge modu region mismatch

`tappedRegion != selectedRegionName` branch'ı level'a göre ayrıldı:
- `level=region` → sadece `selectRegion` (önceki davranış).
- `level=province|district` → `selectRegion + selectProvince` tek adımda.

## Etki Alanı

- **Web Bölge modu province lvl:** Başka bölgenin iline tıklama = tek adımda `selectRegion + selectProvince`.
- **Web Bölge modu district lvl:** Fallback layer + queryClick yolu her ikisi de region-aware.
- **Web İl modu district lvl:** Zaten önceki fix'te çalışıyordu (`_handleSelectionClick` initial=province branch region'a dokunmaz).
- **Native Bölge modu:** Aynı davranışa getirildi.

## Tekrarlamamak İçin

- ⚠️ **"Mode filter" ≠ "kapsam kilidi"**: Hit filter'ı kullanıcıyı kısıtlamak için değil, yalnızca görsel vurgu için kullan. Her seviyede üst seviye geçişleri aktif kalsın.
- ⚠️ **JS→Dart callback'lerde feature property'leri tam aktar**: Tek isim yerine tam properties (NAME_1, REGION, NAME_2) gönder; Dart tarafı hangisinin gerekli olduğuna karar versin.
- ⚠️ **Flutter Web'de layer-specific click handler'larına güvenme**: `srrpQueryClick` + `_onMapClick` tek güvenli path; yeni layer'ları da querye ekle.

## Bağlantılar

- [[SelectionModes]] — davranış spec
- [[MapViewMaplibreWeb]] — web dual path + hit/color ayrımı
- [[MapViewMaplibreNative]] — native region-aware mismatch
- [[issues/2026-04-18-handle-selection-click-initial-mode]] — önceki initial-mode aware fix
- [[issues/2026-04-18-il-modu-cross-province-click]] — fallback layer temeli

## Tarihçe

- **2026-04-19**: Kullanıcı net spec verdi → bölge filter kaldırıldı, click callback 2 parametreli, Dart + native update. `flutter analyze` temiz.

---
tags: [issue, resolved, web, native, selection-modes]
opened: 2026-04-18
resolved: 2026-04-18
severity: high
platform: all
related: [SelectionModes, MapViewMaplibreNative, MapViewMaplibreWeb, PlatformConsistency]
commit:
---

# İl Modu: city → district Drill-Down + İlçe Seçim Vurgusu

## Belirti

Kullanıcı bildirimi (INBOX):

1. **İl modu 2-step bug:** İl moduna geçip bir ile tıklandığında önce "bölge seçiliyor gibi" görünüyor, ardından tekrar tıklama gerekiyor.
2. **İl seçildiğinde tüm Türkiye ilçeleri görünüyor:** Beklenen davranış → sadece seçili ilin ilçeleri görünmeli, diğer iller sadece sınır olarak kalmalı.
3. **İlçe modunda seçim görsel değil:** Seçilen ilçe hangisi olduğu görsel olarak belli değil.

Kullanıcı netleştirmesi:

> il seçildiğinde, ilin ilçeleri gözükecek. Yani city → district mantığı. diğer ilçeler gözükmeyecek. Diğer bir ili seçersek (gözükmeyecekler seçene kadar, sadece sınırları belli) o ili yükleyeceğiz.

## Tekrar Üretim

### Web
1. Haritayı aç → seçim menüsü → "İl" tıkla
2. 81 il görünür ✓
3. Ankara'ya tıkla
4. **Beklenen:** Sadece Ankara'nın ilçeleri + Ankara mavi çerçeve.
5. **Gözlenen:** Türkiye'nin tüm ilçeleri yükleniyor + Ankara mavi çerçeve.

### Native
1. Aynı adımlar → davranış konseptsel olarak doğru (`_showProvinceOverlay` sadece seçili ilin ilçelerini çiziyor).
2. Sadece ilçe seçildiğinde mavi çerçeve yoktu.

## Kök Sebep

### Web (`map_view_maplibre_web.dart`)

`_syncSelectionMode` → `SelectionLevel.district` dalında:

```dart
if (initial == SelectionLevel.province) {
  _jsSetupDistrictMode(null); // ← YANLIŞ: tüm Türkiye ilçeleri
  _jsHighlightProvince(vm.selectedProvinceName);
}
```

`null` = tüm Türkiye ilçeleri yüklüyor. Bu, sabahki "overlay tüm Türkiye" yanlış anlamasının kalıntısıydı.

### JS (`index.html`)

`srrpSetupDistrictMode(provinceName)` — province verilince hem **hit (tıklama)** hem **color (renk)** aynı filtreyle işliyordu. Bu → "sadece seçili ilin ilçeleri tıklanabilir" demek, ama cross-province navigation için diğer illerin de tıklanabilir olması lazım.

### İlçe Highlight Yoktu

Ne native'de ne web'de seçilen ilçeyi gösteren ayrı katman yoktu. Native'de `highlightDistrict` parametresi var ama sadece fill rengini değiştiriyor (sınır mavi çizmiyor).

## Çözüm

### 1. `index.html` — Hit/Color Filter Ayrımı

`_setupSelectionLayers`'a 8. parametre `colorFilter` eklendi. Verilmezse `hitFilter` kullanılır (geriye uyumlu).

```js
function _setupSelectionLayers(srcId, hoverProp, hitFilter, clickFn, srcName, hoverProp2, _retryCount, colorFilter) {
  ...
  var effectiveColorFilter = (colorFilter !== undefined) ? colorFilter : hitFilter;
  _addUniqueColorLayer(srcId, colorProp, effectiveColorFilter);
}
```

`srrpSetupDistrictMode`:
```js
window.srrpSetupDistrictMode = function (provinceName) {
  var hasProv = (provinceName && provinceName.length > 0);
  var colorFilter = hasProv ? ['==', ['get', 'NAME_1'], provinceName] : null;
  _setupSelectionLayers(
    'srrp-borders-districts', 'NAME_1',
    null,                // hit: filtresiz (tüm Türkiye tıklanabilir)
    window._srrpDistrictClickFn,
    hasProv ? ('İlçe (' + provinceName + ')') : 'İlçe (Tüm Türkiye)',
    'NAME_2', 0,
    colorFilter          // color: sadece seçili ilin ilçeleri renklensin
  );
};
```

Yeni davranış:
- **Hit layer:** tüm Türkiye — cross-province click'i destekler
- **Color layer:** sadece seçili ilin ilçeleri — görsel olarak "bu il seçili" algısı
- Diğer illerin üstüne tıklandığında `_handleDistrictClickJs` → farklı province algılar → `selectProvince` çağırır

### 2. `srrpHighlightDistrict(provinceName, districtName)` — JS Fonksiyonu

İlçe mavi çerçeve için yeni JS fonksiyonu. `NAME_1` + `NAME_2` composite filter ile doğru ilçeyi bulur.

### 3. Web `_syncSelectionMode` — İlçe Change Tracking

`_lastDistrictName` state eklendi. `_onVmChanged` içinde:
- Ağır değişiklik (level/region/province) → full resync
- Sadece district değişmişse → lightweight `_jsHighlightDistrict` çağrısı

### 4. `_syncSelectionMode` — Web İl Modu Düzeltmesi

```dart
if (initial == SelectionLevel.province) {
  _jsSetupDistrictMode(vm.selectedProvinceName); // YALNIZ seçili il
  _jsHighlightProvince(vm.selectedProvinceName);
}
```

### 5. Native — `_showDistrictHighlight`

Yeni method + yeni layer constants (`_districtHighlightSourceId`, `_districtHighlightLayerId`). Her modda ilçe seçildiğinde çağrılır:
- `_syncBorders` sonunda `level==district && district!=null` ise highlight
- Click handler içinde ilçe seçiminden sonra direkt çağrı (_geoSelectBusy yüzünden _syncBorders skip etmesin)

`_removeBorderLayers` artık highlight'ı da temizliyor.

### 6. Native Click Handler — Diagnostic Log

2-step click bug'ını doğrulamak için log eklendi:
```dart
debugPrint('[GEO] İl modu tıklama — clicked=$province tappedDist=$district '
    'curProv=${vm.selectedProvinceName} lvl=${vm.selectionLevel}');
```

## Etki Alanı

- **Web**: İl modunda sadece seçili ilin ilçeleri renkli görünür. Diğer illere tıklanabilir (cross-province).
- **Native**: Davranış zaten doğruydu, sadece ilçe vurgusu eklendi.
- **Geri uyumluluk**: `_setupSelectionLayers`'ın 8. parametresi opsiyonel. Eski çağrılar etkilenmez.
- **Performance**: Web'de artık ~970 ilçe yerine sadece seçili ilin ~10-20 ilçesi renklendiriliyor. Daha hızlı.

## Tekrarlamamak İçin

- [[SelectionModes]] notu güncellendi — "city → district drill-down" netleştirildi.
- [[PlatformConsistency]] için: yeni JS fonksiyonu olduğunda hem web hem native'de karşılık mevcut olmalı. `srrpHighlightDistrict` + `_showDistrictHighlight` paralel.

## 2-Step Click Bug'ının Durumu

Native kodda `_selectGeoAtPoint`'te "önce bölge seçiliyor" mantığı YOK. Kullanıcının algıladığı 2-step muhtemelen web'teki "tüm ilçeler yüklendi, ilk tık görsel geri bildirim vermedi" durumundan kaynaklıydı. Bu fix'le birlikte ortadan kalkması bekleniyor. Native'e debug log eklendi — sorun devam ederse `[GEO]` log'u ile tespit edilecek.

## Bağlantılar

- [[SelectionModes]] — doğru davranış spec
- [[MapViewMaplibreNative]] — native overlay sistemi
- [[MapViewMaplibreWeb]] — web JS interop
- [[PlatformConsistency]] — eşleme kuralı

## Tarihçe

- **2026-04-18 sabah**: Yanlış anlama → İl modunda tüm Türkiye ilçeleri + seçili il overlay.
- **2026-04-18 akşam**: Kullanıcı netleştirdi — `city → district` drill-down. Web bug'ı tespit edildi.
- **2026-04-18 akşam**: Web/JS/Native düzeltmeleri + İlçe highlight + diagnostic log. `flutter analyze` temiz.

---
tags: [issue, resolved, web, selection-modes, critical]
opened: 2026-04-18
resolved: 2026-04-18
severity: critical
platform: web
related: [SelectionModes, MapViewMaplibreWeb, "issues/2026-04-18-il-modu-cross-province-click"]
commit:
---

# `_handleSelectionClick` İl Modunda Bölge Seçiyordu

## Belirti

Kullanıcı testinde [[issues/2026-04-18-il-modu-cross-province-click]] fix'inden sonra bile İl modu yanlış çalışıyor:

1. İl modunu aç → ile tıkla → **o ilin bölgesi seçiliyor** (`_selectedRegionName` set oluyor, `_selectedProvinceName=null`).
2. Sonraki click bölge modundaki il seçimine benziyor.
3. Konsolda `[SRRP] İl modu fallback click → Ankara` düşüyor ama **`[GEO-WEB] İl click → Ankara` düşmüyor**.

Log kanıtı:
```
[GEO-WEB] _syncSelectionMode — initial=province lvl=province region=null prov=null
[SRRP] Seçim modu aktif: İl                                      ← İl moduna girildi
[GEO-WEB] _syncSelectionMode — initial=province lvl=province region=Karadeniz prov=null
[SRRP] Seçim modu aktif: İl (Karadeniz)                          ← REGION SET OLDU!
```

`initial` hâlâ `province` ama `region=Karadeniz`. Sadece `selectRegion` region'ı set edebilir — ama `_handleRegionClickJs` log'u YOK.

## Kök Sebep

Web'de **iki paralel click işleme yolu** var:

1. **JS hit layer click** → `window._srrp{X}ClickFn` → Dart `_handle{X}ClickJs` (initial mode farkındalıklı, doğru akış).
2. **Dart `_onMapClick` global handler** → `_jsQueryClick("selection")` döndürür → Dart `_handleSelectionClick(props)`.

İkinci yol `_handleSelectionClick` ise `_initialSelectionMode`'u **yoksayıyordu**:

```dart
switch (vm.selectionLevel) {
  case SelectionLevel.province:
    // Bölge seçilmemişse → önce bölge seç
    if (vm.selectedRegionName == null && region.isNotEmpty) {
      vm.selectRegion(region);   // ← İl MODUNDA BÖLGE SEÇER! YANLIŞ!
    } else if (name1.isNotEmpty) {
      vm.selectProvince(name1);
    }
  ...
}
```

Bu mantık Bölge modunda doğru (`region=null` iken ilk click → region seç). Ama İl modunda `_initialSelectionMode=province` iken `_selectedRegionName` zaten null başlar → `selectRegion` çağrılır → "bölge açılıyor" bug'ı.

Ayrıca bu paralel handler `_handleProvinceClickJs`'in Dart log'larını "yiyor" gibi duruyor — muhtemelen `selectRegion` ile state değişip notify tetikleyince, ardından JS hit layer click handler'ı çalıştığında artık farklı bir state üzerinde çalışıyor.

## Çözüm

`_handleSelectionClick` tamamen yeniden yazıldı — dış switch `initial` (başlangıç modu), iç switch `selectionLevel` (drill-down seviyesi):

```dart
switch (initial) {
  case SelectionLevel.region:
    // Bölge modu: 3-seviye (region → province → district)
    switch (vm.selectionLevel) { ... }
  case SelectionLevel.province:
    // İl modu: 2-seviye (province → district), region'a DOKUNMA
    if (vm.selectionLevel == SelectionLevel.province) {
      if (name1.isNotEmpty) vm.selectProvince(name1);
    } else if (vm.selectionLevel == SelectionLevel.district) {
      if (name1 == vm.selectedProvinceName && name2.isNotEmpty) {
        vm.selectDistrict(name2, province: name1);
      } else if (name1.isNotEmpty && name1 != vm.selectedProvinceName) {
        vm.selectProvince(name1);   // cross-province drill-down
      }
    }
  case SelectionLevel.district:
    // İlçe modu: tek seviye
    if (name1.isNotEmpty && name2.isNotEmpty) {
      vm.selectDistrict(name2, province: name1);
    }
}
```

Ayrıca debug log eklendi:
```dart
debugPrint('[GEO-WEB] _handleSelectionClick — initial=$initial lvl=${vm.selectionLevel} ...');
```

## Etki Alanı

- **Web İl modu:** Artık region'a dokunulmaz. `selectProvince` doğrudan çağrılır.
- **Web Bölge modu:** Aynı kalır; ayrıca "ilçe seviyesinde başka ile tıklama = doğrudan o ile drill-down" kullanıcı spec'i eklendi (önceden sadece aynı ildeki ilçe seçilebiliyordu).
- **Web İlçe modu:** Tek seviye, değişmedi.
- **Native:** Bu dual-path yok (native'de `_selectGeoAtPoint` tek handler). Değişiklik gereksiz.

## Test Doğrulaması

Kullanıcı test etmeli:
1. İl modu → ile tıkla → `[GEO-WEB] _handleSelectionClick — initial=province lvl=province ...` → `selectProvince`.
2. Log'da `region=null` kalmalı (Karadeniz veya başka bölge set OLMAMALI).
3. Başka ile tıkla → direkt o ile geç (bölge atla).

## Tekrarlamamak İçin

- ⚠️ **Dual click path tehlikeli.** `_onMapClick` ile hit layer'ın click handler'ı her ikisi de aynı click için tetiklenebilir. Her iki yol da aynı `selectX` kararını vermelidir.
- ⚠️ **Her selection click logic `_initialSelectionMode`'u OKUMALI** — `_selectionLevel` tek başına yeterli değil çünkü Bölge modu drill-down da `province`/`district` seviyelerinden geçer.
- Uzun vadeli: İki path'i teke indirmek (ya JS hit layer ya Dart query) daha temiz — ama refactor.

## Bağlantılar

- [[SelectionModes]] — doğru davranış spec
- [[MapViewMaplibreWeb]] — web JS interop + dual path mimarisi
- [[issues/2026-04-18-il-modu-cross-province-click]] — önceki turda buldum sandığım "cross-province click" fix'i
- [[issues/2026-04-18-il-modu-drill-down]] — drill-down temeli

## Tarihçe

- **2026-04-18 gece:** Log'dan `_handleSelectionClick`'in paralel bir path olduğu + İl modunda yanlış davrandığı tespit edildi. Initial-mode aware rewrite uygulandı. `flutter analyze` temiz.

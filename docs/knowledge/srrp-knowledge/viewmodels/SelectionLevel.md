---
tags: [viewmodel, enum]
updated: 2026-04-18
related: [SelectionModes, MapViewModel]
file: frontend/lib/features/map/viewmodels/map_viewmodel.dart
---

# SelectionLevel (Enum)

Haritanın şu anki drill-down seviyesini temsil eder. Dört değer alır.

## Tanım

```dart
enum SelectionLevel { none, region, province, district }
```

Lokasyon: `map_viewmodel.dart:32` (MapViewModel sınıfından önce tanımlı).

## Değerler

| Değer | Anlam | Kullanıldığı Yer |
|---|---|---|
| `none` | Hiçbir seçim modu aktif değil | Harita tek başına, sadece pinler |
| `region` | Bölge seçimi açık, kullanıcı bölgeye tıklayacak | Bölge modu, drill-down öncesi |
| `province` | İl seviyesi — iller görünür, kullanıcı il seçecek | İl modu veya Bölge→İl geçişi |
| `district` | İlçe seviyesi — ilçeler görünür | İl modu seçim sonrası, İlçe modu, Bölge→İl→İlçe drill-down |

## İki Önemli Alan ile İlişkisi

`MapViewModel` iki ayrı `SelectionLevel` alanı tutar:

| Alan | Public | Rolü |
|---|---|---|
| `_selectionLevel` | ✅ `selectionLevel` | **Şu anki** seviye (drill-down ile değişir) |
| `_initialSelectionMode` | ✅ `initialSelectionMode` | Kullanıcının **açtığı** mod (sabit) |

**Örnek**:
- Kullanıcı İl modunu açar → `initialSelectionMode = province`, `selectionLevel = province`
- Kullanıcı Konya'ya tıklar → `selectionLevel = district`, ama `initialSelectionMode` hala `province`

Detay: [[SelectionModes]].

## Geçiş Kuralları

```
none     ←→ (mod aç/kapa)
region   → selectRegion()   → province
province → selectProvince() → district  (HER ZAMAN)
district → (terminaldir, drill-down biter)
```

İstisnalar:
- `clearAllSelection()` → `selectionLevel = initialSelectionMode` (başa sar)
- `closeSelectionMode()` → `selectionLevel = none`, `initialSelectionMode = none`

## Switch Pattern (Dart 3.0+)

Kod tabanı Dart 3.0+ switch expression'larını kullanır:

```dart
switch (vm.selectionLevel) {
  case SelectionLevel.none:     _jsClearSelectionMode();
  case SelectionLevel.region:   _jsSetupRegionMode();
  case SelectionLevel.province: _jsSetupProvinceMode(vm.selectedRegionName);
  case SelectionLevel.district: // mode-specific logic
}
```

**Not**: `break` yok — Dart 3 switch expression'larında otomatik break. `default` yerine enum exhaustive kontrolü ile compile-time safety.

## Invariant'lar

1. ✅ **Exhaustive switch**: 4 değerin hepsi işlenmeli, aksi halde analyzer uyarır.
2. ⚠️ **Yeni değer eklersen** (örn. `street`): Bütün switch'leri güncelle — native, web, bottom sheet, map layer mixin.
3. ✅ **`selectionLevel == none` iken hiçbir seçim state'i olmamalı**: region/province/district adları null.

## Bilinen Tuzaklar

- ⚠️ **Enum sırası önemli değil ama değiştirme**. Serialize edildiği yerler yok ama index'e göre kod varsa (`values[i]`) kırılır.
- ⚠️ **`SelectionLevel.province` + `selectedProvinceName != null`**: Bu state "İl seçildi ama ilçeleri henüz yüklenmedi" anlamına **gelmez** — `selectProvince()` her zaman district'e geçer. Province seviyesinde kalmak **yoktur** (sadece `openProvincesMode()` çağrısı sonrası ilk an).

## Bağlantılar

- [[MapViewModel]] — bu alanı tutan sınıf
- [[SelectionModes]] — davranışsal mantık

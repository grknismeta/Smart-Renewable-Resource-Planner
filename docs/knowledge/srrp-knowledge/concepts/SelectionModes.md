---
tags: [concept, selection, critical]
updated: 2026-04-18
related: [MapViewModel, MapViewMaplibreNative, MapViewMaplibreWeb, PlatformConsistency]
---

# Seçim Modları (Bölge / İl / İlçe)

Haritada üç seçim modu vardır. Kullanıcı bir modu açtığında davranış o mod tarafından belirlenir — başka modlara **otomatik geçmez**.

## 🔑 İki Temel Alan

| Alan | Tip | Anlamı |
|---|---|---|
| `_initialSelectionMode` | `SelectionLevel` | Kullanıcının **açtığı** mod. Davranışı belirler. Asla kendi kendine değişmez. |
| `_selectionLevel` | `SelectionLevel` | **Şu anki** seviye. Kullanıcı drill-down yaptıkça değişir (örn. İl modunda il seçilince `district` olur). |

İkisi farklı olabilir. Örnek: İl modunda **Konya** seçilirse:
- `_initialSelectionMode = province`
- `_selectionLevel = district` (Konya'nın ilçeleri açıldı)

Public getter: `vm.initialSelectionMode` (native widget bu üzerinden erişir — private alana dışarıdan erişim hatası olmasın diye).

## Mod Davranışları

### 🟦 Bölge Modu (`_initialSelectionMode = region`)

- Açılışta: 7 coğrafi bölge gösterilir.
- Bölge tıklanınca: O bölgenin illeri gösterilir. `_selectionLevel = province`.
- Başka bölgeye tıklanınca: O bölgeye geçilir (cross-region navigation).
- İl tıklanınca: O ilin ilçeleri gösterilir. `_selectionLevel = district`.
- İlçe tıklanınca: Bilgi paneli + vurgulu ilçe.
- **Başka ile tıklanırsa** (farklı ildeki ilçe): O ilin ilçelerine geçer.

### 🟩 İl Modu (`_initialSelectionMode = province`)

- Açılışta: **Tüm 81 il** aynı anda gösterilir, farklı renklerde (graph coloring).
- İl tıklanınca: `vm.selectProvince(name)` → `_selectionLevel = district`.
  - Native: **Overlay** sistemiyle tüm iller korunur, seçili il mavi sınırla vurgulanır + ilçeleri üstüne çizilir. Bkz. [[MapViewMaplibreNative]].
  - Web: `srrpSetupDistrictMode(null)` (tüm Türkiye ilçeleri) + `srrpHighlightProvince(name)` (mavi sınır).
- İlçe tıklanınca: Aynı ildeyse `selectDistrict`, farklı ildeyse o ile geçer (cross-province).
- **Kritik**: Diğer iller **aynı renkte kalır** — sadece seçili il mavi çerçeve alır.

### 🟨 İlçe Modu (`_initialSelectionMode = district`)

- Açılışta: **Tüm Türkiye ilçeleri** gösterilir (province filtresi YOK).
- İlçe tıklanınca: `selectDistrict(name, province: X)` → bilgi paneli açılır.
- **Kritik**: Tıklama ile **renkler değişmez**. Sadece bilgi paneli güncellenir.
- Hızlı mouse hareketi: rAF throttle ile ara ilçeler atlanır, kullanıcı mouse'u durdurduğu yere en hızlı varır. Bkz. [[HoverThrottle]].

## Mod Açma / Kapama

ViewModel'de:

```dart
openRegionMode()      // _initialSelectionMode = region
openProvincesMode()   // _initialSelectionMode = province
openDistrictsMode()   // _initialSelectionMode = district
closeSelectionMode()  // _initialSelectionMode = none
clearAllSelection()   // _selectionLevel → _initialSelectionMode (geri sar)
```

`clearAllSelection()` kullanıcıyı **açtığı moda** döndürür — İl modundaysa ile geri, İlçe modundaysa tüm ilçelere geri.

## Click Handler Mantığı (Native)

`_selectGeoAtPoint()` içinde `initialMode` okunur ve 4 dala ayrılır:

```
if (initialMode == region)    → bölge akışı (drill-down)
else if (initialMode == province) → overlay yaklaşımı
else if (initialMode == district) → sadece selectDistrict
else → fallback
```

**Önemli**: `vm.selectProvince(name)` her zaman `_selectionLevel = district`'e geçer. Bu davranış değiştirilemez — [[MapViewModel]] içinde yerleşik.

## Bilinen Tuzaklar

- ⚠️ **`vm._initialSelectionMode` DİREKT erişme**. Private alandır, public getter `vm.initialSelectionMode` kullan.
- ⚠️ **`selectProvince()` çağırınca `selectionLevel` değişir**. Sync listener'lar tetiklenir, border'lar yeniden çizilir.
- ⚠️ **Native `_syncBorders`**: İl modunda `_showProvinceOverlay()` kullanır, diğer modlarda `_loadDistrictBorders()`. Koşul: `level == district && initial == province`.
- ⚠️ **Web'de İlçe modu**: `_syncSelectionMode` `SelectionLevel.district`'e ulaşınca `initial == district` ise **null filtre** gönder (tüm ilçeler). Aksi takdirde sadece seçili ilin ilçeleri filtrelenir → hata.

## İlgili Dosyalar

- `frontend/lib/features/map/viewmodels/map_viewmodel.dart` — mod alanları + metodları
- `frontend/lib/features/map/widgets/map_view_maplibre_native.dart` — native click handler (~satır 600-710)
- `frontend/lib/features/map/widgets/map_view_maplibre_web.dart` — web click handler (~satır 810-880)
- `frontend/web/index.html` — JS seçim katmanları (`srrpSetup*Mode`, `srrpHighlightProvince`)

## Bağlantılar

- [[MapViewModel]] — state yönetimi
- [[MapViewMaplibreNative]] — native davranış detayları
- [[MapViewMaplibreWeb]] — web davranış detayları
- [[PlatformConsistency]] — web↔mobil eşleme kuralları
- [[GraphColoring]] — ilçe/il renklendirmesi
- [[HoverThrottle]] — İlçe modu mouse throttle

---
tags: [concept, selection, critical]
updated: 2026-04-19
related: [MapViewModel, MapViewMaplibreNative, MapViewMaplibreWeb, PlatformConsistency]
---

## 🕐 Son Değişimler

- **2026-04-19:** Cross-region/cross-province her seviyede tek tıkla → [[issues/2026-04-19-cross-region-province-click]]. Bölge modu province lvl: hitFilter null, farklı bölge ili tıklama = `selectRegion + selectProvince`. District lvl: fallback layer region aktarıyor. Native `_selectGeoAtPoint` aynı davranışa uyumlandı.
- **2026-04-18 (gece):** İl modu cross-province click davranışı tam doğrulandı — seçili il dışına tıklama artık **yeni il drill-down**'u başlatır (ilçe seçmek değil). Web'de `srrp-sel-hit-prov-fallback` katmanı eklendi.
- **2026-04-18 (akşam):** İl modu davranışı düzeltildi — `city → district` drill-down. Sabah eklenen "tüm Türkiye ilçeleri + overlay" yanlıştı. Şimdi: il tıklayınca sadece o ilin ilçeleri yüklenir.
- **2026-04-18 (sabah):** Mavi overlay + tüm ilçeler (YANLIŞ — geri alındı).

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

### 🟩 İl Modu (`_initialSelectionMode = province`) — city → district drill-down

- **Açılışta:** 81 il sınırı gösterilir (ilçe YOK). Graph coloring ile farklı renkler.
- **İl tıklanınca:** `vm.selectProvince(name)` → `_selectionLevel = district`.
  - **Sadece o ilin ilçeleri** yüklenir (diğer illerin ilçeleri yüklenmez).
  - O il mavi sınırla vurgulanır.
  - Diğer iller aynı il-seviyesi renginde kalır.
- **Seçili il içindeki ilçeye tıklanınca:** `selectDistrict(district, province)` → mavi çerçeve vurgulu ilçe + bilgi paneli.
- **Seçili il DIŞINDA bir yere tıklanınca:** Orayı kapsayan il'in drill-down'ı başlar (`selectProvince(newProv)`). Tıklanan nokta **ilçe olarak seçilmez** — kullanıcı spec'i: _"tıkladığımız yer ilçe değildir, il'dir"_.
  - Web: `srrp-sel-hit-prov-fallback` şeffaf fill katmanı (seçili il hariç filter) click'i yakalar → `_handleProvinceClickJs` → yeni drill-down.
  - Native: `_selectGeoAtPoint` tek `initialMode==province` dalında `province != vm.selectedProvinceName` kontrolü ile yeni il drill-down.
- **ÖNEMLİ:** İl modu **Bölge modunun bölge-atlama varyantıdır**. Bölge seçilmez, direkt il seviyesinden başlar ve `city → district` drill-down yapar.
- ⚠️ **Eski hata (2026-04-18 sabahı):** İl modu açılır açılmaz **tüm Türkiye'nin ilçeleri** yükleniyordu + seçili il mavi overlay. Düzeltildi.
- ⚠️ **Eski hata (2026-04-18 akşam ilk deneme):** Drill-down sonrası web hit layer `null` bırakılmıştı → kullanıcı seçili il dışındaki **ilçelere** tıklayabiliyordu ve "ilçe seçimi" gibi algılıyordu. Düzeltildi: hit=color=seçili-il + ek province fallback hit katmanı.

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
- ⚠️ **Native `_syncBorders`**: İl modunda il seçilince `_loadDistrictBorders(selectedProvince)` + mavi sınır overlay. **Tüm Türkiye'nin ilçelerini yüklemek yanlış.**
- ⚠️ **Web'de İlçe modu**: `_syncSelectionMode` `SelectionLevel.district`'e ulaşınca:
  - `initial == district` → **null filtre** (tüm Türkiye ilçeleri)
  - `initial == province` → **seçili il filtresi** (sadece o ilin ilçeleri) + `srrpHighlightProvince`
  - `initial == region` → Bölge drill-down'ın son aşaması (il filtresi)

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

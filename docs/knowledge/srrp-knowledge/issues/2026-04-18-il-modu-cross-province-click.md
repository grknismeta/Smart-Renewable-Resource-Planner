---
tags: [issue, resolved, web, selection-modes]
opened: 2026-04-18
resolved: 2026-04-18
severity: high
platform: web
related: [SelectionModes, MapViewMaplibreWeb, "issues/2026-04-18-il-modu-drill-down"]
commit:
---

# İl Modu: Seçili İl Dışı Tıklama = Yeni İl (ilçe değil)

## Belirti

Önceki [[issues/2026-04-18-il-modu-drill-down]] fix'inden sonra kullanıcı testinde:

1. İl modunda bir ile tıkladığımda yine o ilin "bölgesi" açılıyor (2-step hissiyatı).
2. İl mavi çerçeve ile görünüyor, seçili ilin ilçeleri mavi çizili.
3. **Türkiye'deki bütün ilçelere etkileşim yapabiliyorum** — kullanıcı bunu istemiyor.

Kullanıcı spec'i:

> İl modundayken ili seçtikten sonra eğer il dışında başka bir yere tıklarsak, tıkladığımız yerin il'i açılır. **Tıkladığımız yer ilçe değildir** yani.

## Kök Sebep

Önceki fix'te web `srrpSetupDistrictMode` için **hit filter = `null`** (tüm Türkiye ilçeleri tıklanabilir) bırakılmıştı. Amaç cross-province navigasyonu `_handleDistrictClickJs` üstünden yapmaktı:
```js
// Eski: hit=null → Dart tarafı farklı il algılayıp selectProvince çağırırdı
null,  // hitFilter
```

Sorun:
- Kullanıcı seçili il dışındaki bir **ilçeye** hover/click ediyor → cursor pointer oluyor, sonuçta `selectProvince` çağrılsa da "ilçe seçiyormuşum gibi" his veriyor.
- Çıkış yolu var ama semantik kirli: ilçe katmanı işin il düzeyi mesajını da taşıyor.

## Çözüm

### 1. `srrpSetupDistrictMode` — hit = color = seçili il

```js
var filter = hasProv ? ['==', ['get', 'NAME_1'], provinceName] : null;
_setupSelectionLayers(
  'srrp-borders-districts', 'NAME_1',
  filter,   // hit = colorFilter (ikisi de seçili il)
  ...
);
```

Artık **sadece seçili ilin ilçeleri** tıklanabilir. Diğer ilçelere hover yok, pointer yok.

### 2. Yeni `_setupProvinceFallbackLayer(selectedProvince)`

Seçili il dışı tıklamayı yakalamak için şeffaf bir fill katmanı:

```js
map.addLayer({
  id: 'srrp-sel-hit-prov-fallback',
  type: 'fill',
  source: 'srrp-borders-provinces',
  paint: { 'fill-color': 'rgba(0,0,0,0)', 'fill-opacity': 0.001 },
  filter: ['!=', ['get', 'NAME_1'], selectedProvince], // seçili il HARİÇ
}, 'srrp-sel-hit');
```

Click handler → `window._srrpProvinceClickFn(name)` → Dart `_handleProvinceClickJs` → `selectProvince(newProvince)` → drill-down yeni il.

Böylece:
- Seçili il içi tıklama (ilçe) → `_handleDistrictClickJs` → `selectDistrict`
- Seçili il dışı tıklama (il) → `_handleProvinceClickJs` → `selectProvince` (yeni drill-down)

### 3. SEL_LAYERS + temizlik handler'ları

- `'srrp-sel-hit-prov-fallback'` SEL_LAYERS'a eklendi (mode değişiminde otomatik temizlenir).
- `_selProvFallbackClickFn`, `_selProvFallbackMousemoveFn`, `_selProvFallbackMouseleaveFn` global değişkenler — `srrpClearSelectionMode` ve `_setupSelectionLayers` içinde `map.off()` ile kaldırılır (stale listener önlenir).

### 4. Debug log (2-step bug teşhisi)

Web'de 2-step hissiyatını doğrulamak için eklendi:
- `_handleRegionClickJs` → `[GEO-WEB] Bölge click → ...`
- `_handleProvinceClickJs` → `[GEO-WEB] İl click → ... (initial=... lvl=... curProv=...)`
- `_handleDistrictClickJs` → `[GEO-WEB] İlçe click → ... (initial=... lvl=...)`
- `_syncSelectionMode` → `[GEO-WEB] _syncSelectionMode — ...`

## Etki Alanı

- **Web:** İl modunda artık seçili il dışı tıklama doğrudan yeni drill-down başlatır, ilçe katmanına düşmez.
- **Native:** Davranış zaten doğru (`_selectGeoAtPoint` `province != vm.selectedProvinceName` kontrolü yapıyor). Değişiklik yok.
- **Geri uyum:** İlçe modu (`provinceName=null`) aynı kalır — fallback katman kurulmaz, tüm Türkiye ilçeleri tıklanabilir.

## Tekrarlamamak İçin

- "Cross-province navigation'ı ilçe katmanı üzerinden yap" **yanlış yaklaşım**. Her seviyenin kendi hit katmanı olmalı.
- [[SelectionModes]] İl Modu bölümünde "seçili il dışı tıklama = yeni il" netleştirildi.

## Bağlantılar

- [[issues/2026-04-18-il-modu-drill-down]] — önceki drill-down fix'i
- [[SelectionModes]] — doğru davranış spec
- [[MapViewMaplibreWeb]] — web JS interop

## Tarihçe

- **2026-04-18 akşam:** Drill-down fix'i kondu, hit=null tüm Türkiye ilçeleri clickable.
- **2026-04-18 gece:** Kullanıcı testinde "tüm ilçelere erişim" sorunu rapor edildi. Fallback katman + hit filter değişikliği uygulandı.
- **2026-04-18 gece (2. tur):** Log'larla DAHA derin bir bug bulundu — `_handleSelectionClick` paralel Dart handler'ı `_initialSelectionMode`'u yoksayıyordu. İl modunda ile tıklama → `selectRegion(region)` çağırıyordu ("bölge açılıyor" hissiyatının kaynağı). `_handleSelectionClick` initial-mode aware yeniden yazıldı — İl modunda region'a **hiç dokunmaz**. [[issues/2026-04-18-handle-selection-click-initial-mode]] post-mortem.

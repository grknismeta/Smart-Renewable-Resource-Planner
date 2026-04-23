---
tags: [issue, resolved, web, wind, z-index]
opened: 2026-04-19
resolved: 2026-04-19
severity: medium
platform: web
related: [MapStackPositioned, MapViewMaplibreWeb]
commit:
---

# Rüzgar Partikül Canvas'ı UI Overlay'lerinin Üstüne Çıkıyordu

## Belirti

Rüzgar Canlı Akış açıkken partikül canvas'ı harita üstündeki widget'ların (Pin Ekle, Kapasite, Katmanlar paneli, alt bottom sheet) **üzerinde** çizilir hale geliyordu. Partiküller sadece harita alanıyla sınırlı kalmıyor, UI'ı kirletiyordu.

## Kök Sebep

`frontend/web/index.html` içinde `srrpStartWindParticles` canvas kurulumunda:

```js
canvas.style.cssText = 'position:absolute;pointer-events:none;z-index:9999;'
  + 'top:0;left:0;width:100%;height:100%;';
```

Canvas harita container'ına (Flutter HtmlElementView platform view) child olarak ekleniyor. Ancak `z-index:9999` bu canvas'ı Flutter'ın platform view üstündeki Positioned UI widget'larının (katman paneli, pin overlay'leri vb.) stacking context'inin üzerine çıkarıyordu. Flutter CanvasKit modunda platform view overlay'i Flutter canvas'ı üstünde render edilirken içerideki 9999 değeri bu overlay'lerle çakışıyordu.

`pointer-events:none` sayesinde tıklama engellenmese de görsel olarak partiküller UI elementlerinin önünde geziniyordu.

## Çözüm

### İlk Deneme — z-index:1 (YETMEDİ)

Canvas z-index'i `9999 → 1` yapıldı. Kullanıcı testi: sorun **devam etti**, çizgiler hâlâ panelin üstünde.

Neden yetmedi: Flutter `flt-platform-view-slot` element'i `position:absolute` ama `z-index:auto` → stacking context açmıyor. İçerideki `z-index:1` değeri **root stacking context'e yayılıyor** ve Flutter overlay canvas'ı ile aynı seviyede yarışıyor.

### İkinci Deneme — z-index tamamen kaldırıldı

```js
canvas.style.cssText = 'position:absolute;pointer-events:none;'
  + 'top:0;left:0;width:100%;height:100%;';
```

- Canvas harita container'ı içinde, map canvas'tan sonra `appendChild` edildiği için DOM sıralamasında doğal olarak üstünde.
- `z-index` belirtilmediğinde `auto` → stacking context'i yayılmıyor, parent slot içinde kalıyor.
- Flutter overlay canvas DOM'da platform view slot'tan **sonra** geldiği için UI widget'ları doğal olarak wind canvas üstünde.

## Etki Alanı

- Web: rüzgar partikülleri artık map+borders katmanlarının üstünde, Flutter UI widget'larının altında.
- Native: bu canvas yok, etkilenmez.
- Pin shadow / normal UI widget'ları aynı kalır.

## Tekrarlamamak İçin

- ⚠️ **Kural:** Flutter web HtmlElementView içindeki DOM elementleri için `z-index` değerini yüksek tutmayın. `1-10` aralığı map'in iç katmanları için yeterli; 100+ değerleri Flutter overlay'leri geçer.
- [[MapStackPositioned]] notuna benzer: Flutter üst katman güvenliği DOM tarafında da geçerli.

## Bağlantılar

- [[MapViewMaplibreWeb]] — wind particle canvas kurulumu
- [[MapStackPositioned]] — Flutter Stack z-order kuralı (DOM paralel)

## Tarihçe

- **2026-04-19**: Sorun raporlandı (INBOX). Canvas `z-index:9999 → 1` düşürüldü.
- **2026-04-19 (2. tur)**: Kullanıcı test etti — sorun devam etti. `z-index` tamamen kaldırıldı (auto). Platform view slot stacking context açmadığı için `z-index:1` bile root'a yayılıyordu; `auto` ile DOM sırası stacking'i belirler ve Flutter overlay canvas UI widget'larını wind canvas üstünde render eder.

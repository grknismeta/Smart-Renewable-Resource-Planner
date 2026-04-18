---
tags: [concept, performance, web-only]
updated: 2026-04-18
related: [SelectionModes, MapViewMaplibreWeb, PlatformConsistency]
---

# Hover Throttle (İlçe Modu Mouse Performansı)

İlçe modunda mouse haritada hızlı hareket ederken her ilçenin üzerinden geçerken filtre güncellemesi tetikleniyor → performans düşüyor ve kullanıcının "vardığı" ilçe geç belirleniyor.

## Problem

```
Mouse A → B → C → D  (hızlı geçiş, tüm ilçelerin üzerinden)
   │      │     │    │
   v      v     v    v
  setFilter(A)  → setFilter(B) → setFilter(C) → setFilter(D)
    ↳ MapLibre re-render her biri için → 10-20ms × 4 = 40-80ms lag
```

Kullanıcının asıl istediği D ilçesi, ama ara ilçelerin hesaplanması için beklemek zorunda.

## Çözüm: requestAnimationFrame Coalescing

**Sadece son mouse pozisyonunu** bir sonraki frame'de uygula. Ara pozisyonlar atılır.

```javascript
var _pendingHover = null;
var _rafHandle    = null;

function _applyHover() {
  _rafHandle = null;
  if (!_pendingHover) return;
  var f = _hoverFilter(_pendingHover.prov, _pendingHover.dist);
  if (map.getLayer('srrp-sel-hover'))     map.setFilter('srrp-sel-hover', f);
  if (map.getLayer('srrp-sel-extrusion')) map.setFilter('srrp-sel-extrusion', f);
  _pendingHover = null;
}

_selMousemoveFn = function (e) {
  if (!e.features || !e.features.length) return;
  var prov = ..., dist = ...;
  map.getCanvas().style.cursor = 'pointer';

  // Son pozisyonu kaydet
  _pendingHover = { prov: prov, dist: dist };

  // rAF zaten kuyrukta değilse kuyruğa ekle
  if (_rafHandle == null) {
    _rafHandle = requestAnimationFrame(_applyHover);
  }
};
```

### Nasıl Çalışır

```
Frame N:   mousemove(A) → _pendingHover={A} → rAF kuyrukta
           mousemove(B) → _pendingHover={B} (A üzerine yazıldı)
           mousemove(C) → _pendingHover={C}
Frame N+1: _applyHover() çalışır → sadece C için setFilter
           mousemove(D) → _pendingHover={D} → rAF kuyrukta
Frame N+2: _applyHover() → D için setFilter
```

**Maksimum 60 fps** güncelleme. Ara pozisyonlar atılır, kullanıcının durakladığı yere hemen varılır.

## Mouseleave Cancellation

Mouse haritadan çıkarsa bekleyen rAF'ı iptal et — aksi halde stale hover güncellemesi gelir:

```javascript
_selMouseleaveFn = function () {
  if (_rafHandle != null) {
    cancelAnimationFrame(_rafHandle);
    _rafHandle = null;
  }
  _pendingHover = null;
  // ... normal cleanup
};
```

## Neden Bu Yaklaşım?

| Yaklaşım | Avantaj | Dezavantaj |
|---|---|---|
| Debounce (timeout) | Ara güncellemeleri atar | Minimum gecikme (örn. 50ms) hissedilir |
| Throttle (örn. 30 fps) | Sabit rate | Hala ara karelerde render |
| **rAF coalescing** | Tarayıcı render frame'ine hizalanır, atılan kareler hiç hesaplanmaz | - |

rAF, tarayıcının bir sonraki paint'inden önce çalışır → doğal frame-rate sync.

## Kapsam

- **Sadece web**: JS'te. Mobilde hover event'i yok (touch-based).
- **Tüm seçim modları** (`_setupSelectionLayers` içinde): bölge, il, ilçe. Ama pratikte en çok İlçe modunda fark edilir (polygon sayısı 900+).

## Lokasyon

`frontend/web/index.html` → `_setupSelectionLayers()` fonksiyonu → handler tanımları.

## İnvariant'lar

1. ✅ **`_rafHandle == null` kontrolü şart** — aksi halde her mousemove yeni rAF kuyruğa ekler, birikim olur.
2. ✅ **Mouseleave'de cancel** — stale update engellensin.
3. ⚠️ **`_pendingHover` değiştirici atom değil** — JS single-threaded olduğu için sorun yok ama async kod ekleme.

## Bilinen Tuzaklar

- ⚠️ **Mobil tarayıcıda test et**: rAF mobilde de çalışır ama touchmove event flow'u farklı. İlçe modu mobilde kullanılıyorsa manuel test gerekir.
- ⚠️ **Cursor state**: `style.cursor = 'pointer'` rAF dışında anlık ayarlanır — kullanıcı feedback'i geri kalmaz.

## Bağlantılar

- [[SelectionModes]] — İlçe modu davranışları
- [[MapViewMaplibreWeb]] — çağrıldığı widget
- [[PlatformConsistency]] — web-only özellik olduğu için native'e ek ekleme yok

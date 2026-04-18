---
tags: [index, home]
updated: 2026-04-18
---

# 🗺️ SRRP Knowledge Vault

Smart Renewable Resource Planner projesinin atomik bilgi tabanı. Büyük dosyaları tek tek okumak yerine buraya bak.

## 🔴 Her Oturumda İlk Oku

- [[SelectionModes]] — ⚠️ Bölge/İl/İlçe mantığı (en sık yanlış yapılan)
- [[MapStackPositioned]] — ⚠️ Harita Stack'e Positioned olmayan widget ekleme hatası
- [[PlatformConsistency]] — Web↔Mobil eşleme kuralları

## 📁 Klasörler

### `concepts/` — Domain kavramları
- [[SelectionModes]] — Bölge/İl/İlçe mod davranışları
- [[PlatformConsistency]] — Web ve mobil nasıl aynı tutulur
- [[GraphColoring]] — Komşu polygon renklendirme algoritması
- [[ChoroplethScales]] — Fizik bazlı sabit renk skalaları
- [[HoverThrottle]] — rAF ile mouse throttle

### `viewmodels/` — State yönetimi
- [[MapViewModel]] — Harita state ana sınıfı
- [[SelectionLevel]] — Seçim seviyesi enum'u
- [[MapLayerMixin]] — Katman/veri yönetimi mixin *(yapılacak)*

### `widgets/` — UI bileşenleri
- [[MapViewMaplibreNative]] — Android/iOS MapLibre SDK
- [[MapViewMaplibreWeb]] — Web MapLibre GL JS
- [[MapScreen]] — Ana ekran, Stack yapısı
- [[MapBottomSheet]] — Alt panel

### `backend/` — Python/FastAPI
- [[WeatherRouter]] — Choropleth endpoint, global timestamp

### `pitfalls/` — Tuzaklar ve kurallar
- [[MapStackPositioned]] — Stack'e Positioned ekleme kuralı
- [[PrivateFieldAccess]] — ViewModel private alan erişimi

## 📝 Not Yazma Kuralları

1. **Atomik ol**: Bir not = bir kavram. 80 satırı geçme.
2. **Wiki link kullan**: `[[NotAdı]]` — Obsidian otomatik bağlar.
3. **Frontmatter zorunlu**: `updated`, `tags`, `related`.
4. **Satır numarası yerine aralık**: `~satır 600-710` şeklinde (kaysalar anlam bozulmasın).
5. **Tuzaklar vurgulu**: ⚠️ işaretiyle.
6. **Her not şunları içermeli**: Amaç, Kritik alanlar/davranışlar, Invariant'lar, Bilinen tuzaklar, İlgili dosyalar, Bağlantılar.

## 🔄 Güncelleme Workflow

- Kodu değiştirdim → ilgili `.md` notunu **aynı commit'te** güncelle.
- Pre-commit hook uyarı verir (engellemez) — bkz. `.git/hooks/pre-commit`.
- Ortak oturumlarımızda Claude güncellemeyi otomatik yapar + rapor verir.

## 📦 Vault Konumu

- Fiziksel yol: `docs/knowledge/srrp-knowledge/`
- Obsidian: "Open folder as vault" → yukarıdaki yol
- Template: `_template.md`

## 🗂️ Tarihçe

- **2026-04-18**: Vault kuruldu. Faz 0 bug fix/midfix bitti. İlk 5 not: SelectionModes, INDEX, MapViewModel, MapViewMaplibreNative, PlatformConsistency.
- **2026-04-18** (devam): Kalan 10 not yazıldı — GraphColoring, ChoroplethScales, HoverThrottle, SelectionLevel, MapViewMaplibreWeb, MapScreen, MapBottomSheet, WeatherRouter, MapStackPositioned, PrivateFieldAccess. Toplam 15 not aktif. Kalan: MapLayerMixin.
- **ARCHITECTURE.md ilişkisi**: Eski dosya `frontend/ARCHITECTURE.md` referans olarak kalır ama tek kaynak artık bu vault'tur. Yeni bilgi oraya **yazılmaz**, buraya yazılır.

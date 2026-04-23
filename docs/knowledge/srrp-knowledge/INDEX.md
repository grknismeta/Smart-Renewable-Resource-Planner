---
tags: [index, home]
updated: 2026-04-18
---

# 🗺️ SRRP Knowledge Vault

Smart Renewable Resource Planner projesinin atomik bilgi tabanı. Büyük dosyaları tek tek okumak yerine buraya bak.

## 🔴 Her Oturumda İlk Oku

- [[PROJECT-OVERVIEW]] — 🌍 **Büyük resim** (yeni oturumda ilk bu)
- [[INBOX]] — 📥 **İşlenmemiş sorunlar** (Claude her oturum başında buraya bakar)
- [[PLAN-2026-04-19-to-23]] — 🎯 **Aktif sprint planı** (Perşembe 23 Nisan teslim)
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

### `issues/` — Çözülmüş/aktif sorun takibi
- [[INBOX]] — hızlı dump alanı (günlük)
- [[issues/_template]] — yeni issue şablonu
- **Çözülmüş:**
  - [[issues/2026-04-18-bulut-katmani-gorunmuyor]] — diagnostic + error listener
  - [[issues/2026-04-18-il-modu-drill-down]] — city→district drill-down + ilçe highlight
  - [[issues/2026-04-18-il-modu-cross-province-click]] — seçili il dışı tıklama = yeni il (fallback layer)
  - [[issues/2026-04-18-handle-selection-click-initial-mode]] — _handleSelectionClick initial mode yoksayıyordu (İl modunda region set etme bug'ı)
  - [[issues/2026-04-19-wind-particles-z-index]] — rüzgar canvas z-index:9999 → 1 (UI overlay'lerin üstüne çıkıyordu)
  - [[issues/2026-04-19-cross-region-province-click]] — her seviyede cross-region/cross-province tek tıkla geçiş (web+native)
  - [[issues/2026-04-22-analysis-service-bugs]] — Faz 1 canlı test 3 bug: score_3m yok, SQLAlchemy 2.0 Row.t çakışması, scheduler status takılı
  - [[issues/2026-04-22-district-choropleth-east-west]] — Işınım choropleth doğu-batı asimetrisi + legend paleti uyuşmazlığı (per-district latest ts + 0–800 + lacivert start)

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

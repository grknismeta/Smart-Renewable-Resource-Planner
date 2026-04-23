---
tags: [inbox]
updated: 2026-04-23
---

> **2026-04-23 Sprint Progress:** Faz 1–3 tamamlandı + 2026-04-23 düzeltme turu: 3D Türbin/Arazi YAKINDA rozetiyle disable, Önerilen Bölgeler side-panel'i `/analysis/provinces`'e migrate edildi (doğru dosya: `recommendations/recommendations_side_panel.dart`), Zaman Simülasyonu default tarih aralığı DB max tarihine clamp ediliyor (2026-04 "bugün" → veri sonu 2024/2025 uyuşmazlığı çözüldü), mobil backend URL artık Ayarlar → Veri Kaynağı'ndan override edilebiliyor (`BackendConfig` + SharedPreferences; varsayılan güncel PC IP `192.168.1.15`). `flutter analyze` temiz.

# 📥 INBOX — İşlenmemiş Sorunlar & Notlar

Buraya aklına gelen her şeyi hızlıca at. Tam cümle gerekmez, yarı not yeterli. Claude oturum başında buraya bakar, çözer, işaretler.

## Nasıl Kullanılır

1. **Sorunu at:** Yeni satıra `- [ ] sorun açıklaması` ekle. Mobilden ekran görüntüsü, konsol log'u yapıştırırsan daha iyi.
2. **Tarih başlığı kullan:** O günün sorunlarını `## 2026-04-DD` altına topla — eskiler aşağıda kalsın.
3. **Önceliklendir (opsiyonel):** `[!]` aciliyet, `[?]` belirsiz tekrar üretim, `[*]` sadece not.
4. **Çözülünce:** Claude `[x]` işaretler ve `→ [[issues/YYYY-MM-DD-slug]]` link ekler.

## Örnek Format

```markdown
## 2026-04-18
- [ ] Bulut katmanı açılıyor ama görünmüyor, konsol temiz
- [ ] [!] Android'de ilçe modu → harita beyazlıyor
- [ ] [?] Bazen senaryo butonu çalışmıyor, tekrar üretemiyorum
- [*] İleride: legend renkleri dark mode'da zor okunuyor
```

Çözülmüş örnek:
```markdown
- [x] Bulut katmanı görünmüyor → [[issues/2026-04-18-bulut-katmani-gorunmuyor]]
```

---

## 2026-04-18

### ✅ Çözüldü

- [x] Bulut katmanı açılıyor ama görünmüyor, konsol temiz hata yok → [[issues/2026-04-18-bulut-katmani-gorunmuyor]]

---

### 🔴 P0 — Seçim Modları Davranış Düzeltmesi

- [x] **İl modu: `city → district` drill-down + İlçe seçim vurgusu** → [[issues/2026-04-18-il-modu-drill-down]]
  - Web: `_jsSetupDistrictMode(vm.selectedProvinceName)` + hit/color filter ayrımı (cross-province için)
  - Web: yeni `srrpHighlightDistrict(prov, dist)` + ilçe change tracking
  - Native: yeni `_showDistrictHighlight` method + _syncBorders bağlantısı + click handler
  - Diagnostic log eklendi (2-step bug'ı için)
  - `flutter analyze` temiz.
- [x] **İl modu cross-province click: seçili il dışı tıklama = yeni il (ilçe değil)** → [[issues/2026-04-18-il-modu-cross-province-click]]
  - Kullanıcı testi: "Türkiye'nin tüm ilçelerine erişimim var" hissiyatı → yanlış.
  - Çözüm: Web'de hit=color=seçili-il + yeni `srrp-sel-hit-prov-fallback` katmanı (seçili il hariç) → dışarı tıklama `_handleProvinceClickJs`'e düşer.
- [x] **"Bölge açılıyor" bug'ı — `_handleSelectionClick` initial mode yoksayıyordu** → [[issues/2026-04-18-handle-selection-click-initial-mode]]
  - Log kanıtı: İl moduna girince ile tıklama → `selectRegion("Karadeniz")` çağrılıyordu (yanlış).
  - Kök sebep: Dart tarafında `_onMapClick` → `_jsQueryClick` → `_handleSelectionClick` paralel yolu, sadece `selectionLevel` bakıyordu `initial` yoksayılıyordu.
  - Çözüm: `_handleSelectionClick` initial-mode aware rewrite. İl modunda region'a **hiç dokunmaz**.
  - `flutter analyze` temiz.
  - ✅ **Kullanıcı testi onayı (2026-04-19):** "İl artık doğru çalışıyor" — İl modu tıklama → prov=<il> lvl=district, region dokunulmuyor, cross-province fallback doğru.

- [x] **Cross-region / Cross-province tek tıkla geçiş** → [[issues/2026-04-19-cross-region-province-click]]
  - Kullanıcı spec: Her seviyede üst seviye navigasyonu aktif. "Ege seçiliyken Karadeniz'i tıklarsam o bölgeye geçerim", "İl seçtikten sonra bir tıklamayla başka ile geçebilirim".
  - Web: `srrpSetupProvinceMode` hitFilter null yapıldı (tüm iller clickable), colorFilter sadece seçili bölgeye. Click handler 2 parametreli (name, REGION). `srrpQueryClick` fallback layer'ı da query'e ekledi. Dart `_handleProvinceClickJs(name, region)` ve `_handleSelectionClick` district branch region-aware.
  - Native: `_selectGeoAtPoint` Bölge modu branch'ı, province/district lvl'da farklı bölgenin iline tıklama = `selectRegion + selectProvince` tek adımda.
  - `flutter analyze` temiz. ⏳ Kullanıcı web test etmeli.

### 🔴 P0 — Rüzgar Partikülleri Z-Index

- [x] **Partiküller sadece harita üzerinde çizilmeli** → [[issues/2026-04-19-wind-particles-z-index]]
  - 1. tur: `z-index:9999` → `1` — yetmedi (kullanıcı test ekran görüntüsü: çizgiler hâlâ Katmanlar panelinin üstünde).
  - 2. tur: `z-index` tamamen kaldırıldı (auto). Platform view slot stacking context açmadığı için `z-index:1` bile root'a yayılıyordu.
  - ⏳ Kullanıcı web'de tekrar test etmeli (hot-restart `R`).

### 🟠 P1 — Veri Doğruluğu (en ciddi bug'lar)

- [x] **Işınım doğu-batı asimetrisi + legend uyuşmazlığı** → [[issues/2026-04-22-district-choropleth-east-west]]
  - Kök sebep 1: `/district-choropleth mode=latest` tek `global_max_ts` kullanıyordu → doğu ilçeleri (20° enlem + fetch dalgası) düşüyordu.
  - Kök sebep 2: `map_screen.dart` solar legend 0–400 + lacivert-siz; map paleti 0–800 + lacivert start.
  - Çözüm: per-district latest timestamp subquery (`weather.py`) + legend paletini 0–800 + `#1A1A2E` start'la hizala (`map_screen.dart:452`).
  - ⏳ Kullanıcı web test: tam Türkiye renklensin, legend ↔ harita renk uyumu.
- [ ] **Isı (temperature) choropleth kontrolü** — aynı endpoint'i kullandığı için doğu-batı fix ısıyı da düzeltmiş olmalı, ama skala (`-15→45°C`) ayrıca doğrulanmalı. Faz 2 migrasyonuyla `/analysis/choropleth/*` altına taşınacak.
- [ ] **Raporlar → Harita: değerler ~100 (hesaplama hatası).** Neredeyse her il için değer 100 gözüküyor. İl Analizi sekmesiyle **tutarsız**. Muhtemelen normalizasyon bug'ı.

### 🟠 P1 — Bulut Modu (Parça 1 devamı)

- [ ] **Telefonda Bulut Modu çalışmıyor.** Mobile native adapter'a port lazım (şu an sadece web).
- [ ] **Bulut açıkken yakınlaşınca "Zoom Level Not Supported" yazısı görünüyor** → gizlenmeli. (MapLibre built-in mesajı; `maxzoom:8` aşılınca çıkıyor.)

### 🟡 P2 — Feature Geliştirmeleri (kapsamlı)

- [ ] **Bulut görsel geliştirme:**
  - Yağmur bulutu vs. normal bulut ayrımı (şu an tek katman)
  - Ölçek gösterimi (legend) — kullanıcı gerçek zamanlı mı anlayamıyor
- [x] **Zaman Simülasyonu çalışmıyor** — Kök sebep: kullanıcı "bugün" 2026-04-23, varsayılan aralık `now-30d → now`; DB'de veri 2024/2025'te bitiyor. `fetchAnimationData` boş dönüp "veri bulunamadı" hatası veriyordu. Çözüm: `_fetchAnimationRange()` DB daily_max/hourly_max'i okuyup default end date'i clamp ediyor + start'ı end-30d'ye çekiyor (sadece user henüz manuel değiştirmediyse). `map_viewmodel.dart:1696-1740`.
- [ ] **Katmanlar → Önerilen Bölgeler: "henüz veri yok" uyarısı** — backend bitmemiş olabilir, endpoint kontrolü gerek.
- [ ] **Raporlar → Harita sekmesi:**
  - Rüzgar / Sıcaklık / Işınım layer toggle yok (ana haritada var, raporlarda yok)
  - Sağdaki il listesine tıklayınca harita o ile zoom yapmıyor
- [ ] **Önerilen Bölgeler ↔ Raporlar/Harita entegrasyonu:**
  - Ana harita üzerinde önerilen bölgeleri göster
  - Raporlar/Harita'da da göster — kullanıcı bölge seçimi gibi seçebilsin

### 🟣 P3 — Global Projeksiyon (Parça 4, büyük feature)

- [ ] **Globe mode kuralları** (web + mobil için aynı):
  - **KAPALI iken:** kullanıcı TR dışına çıkamaz (maxBounds aktif, zoom limiti aktif)
  - **AÇIK iken:** sınırlamalar kalkar, dünya gezilebilir
  - **Tekrar kapatılınca:** TR koordinatlarına dön, sınırlar & zoom limitleri geri aktif
- [ ] **TR dışı pin davranışı:**
  - Geo motoru / uygunluk analizi sistemleri çalışmaz
  - Sadece o koordinatın hava/ışınım verileri çekilir, sonuç gösterilir, konu kapanır
  - DB'de kaydı tutulur
  - Sol üst bilgi kutusunda uyarı: _"SRRP Türkiye dışındaki konumlar için uygunluk analizi yapmaz"_

### 🔴 P0 — 2026-04-23 (2. tur) — Zaman Simülasyonu 500 + İl Sayımı + Hidro Kriter

- [x] **Zaman Simülasyonu web + mobil HATA** — Kök sebep: `weather.py:/animation` endpoint'i `WeatherData.city_name` kullanıyordu ama `WeatherData` modelinde sadece `province_name` var (city_name yok). Her çağrı `AttributeError` ile 500 dönüyordu. Mobil "veri yüklenirken hata", web "sunucuya bağlanılamadı" mesajları hep aynı 500'ün iki farklı client fallback'iydi. Fix: `WeatherData.city_name → WeatherData.province_name` (hem query hem map), `row.province_name` + district IS NULL/Merkez filtresi. curl testi: `/weather/animation?start=2024-01-01&end=2024-01-07&metric=wind&interval=daily` → 200 OK, 7 frame, 17KB. `weather_service.dart.fetchAnimationData` 60sn timeout + ML error mesajları (timeout / socket / 500 / backend detail) ayrıldı. **Backend restart gerek.**
- [x] **"İller 79/79" → "X/81"** — `province_drill_tab.dart` payda sabit 81'e alındı. 2 ilde son 168 saatte hourly kayıt eksik → pay 79 (normal). Payda 81 sabit → eksik veri gözle görünür.
- [x] **Hidro skor kriteri kullanıcıya anlaşılmıyor** — `recommendations_side_panel.dart` `_CategoryGroup`'a `criteria` parametresi eklendi, başlığın altında tek satır italik açıklama: Rüzgar=v³ / Güneş=400 W/m² cap / Hidro=%70 yağış (5 mm/gün cap) + %30 sıcaklık (12 °C tepe, ±20 °C). "Gerçek HES havza verisi geliyor" notu.

### 🔴 P0 — 2026-04-23 Düzeltme Turu

- [x] **3D Türbin + 3D Arazi "Yakında" disable.** `layers_panel.dart` `_threeDEffectsEnabled = false` sabitiyle her iki toggle YAKINDA rozetiyle devre dışı. Bulut pattern'inin aynısı.
- [x] **Önerilen Bölgeler "Veri Yükle" tuşu hâlâ çalışmıyordu.** Asıl UI entrasyonu `recommendations_panel.dart` değil, `recommendations/recommendations_side_panel.dart` idi (backend log `/recommendations` çağrıldığı için fark edildi). Side-panel baştan yazıldı: `_HorizonBar` (1A/3A/6A/Yıl), `_CategoryGroup` (rüzgar/güneş/hidro top-N), il tıklaması `Navigator.pushNamed('/reports', arguments: {'province': name})`. `MapViewModel.toggleRecommendationsPanel()` panel açılınca hem `loadAnalysisTop()` hem eski `loadRecommendations()` tetikliyor (geri uyum).
- [x] **Telefon backend'e bağlanamıyor.** Kök sebep: `api_client.dart` Android için hardcode `192.168.1.7:8000`, PC'nin güncel LAN IP'si `192.168.1.15`. Çözüm: `core/config/backend_config.dart` yeni modül (SharedPreferences persistence); `BaseService.baseUrl` `BackendConfig.instance.mobileUrl` okuyor; `main.dart` startup'ta `BackendConfig.init()` çağırıyor; Ayarlar → Veri Kaynağı altında `_BackendUrlTile` (URL girişi + Kaydet / Varsayılan butonu, "ÖZEL" rozeti). Varsayılan `defaultMobileBackendUrl = 'http://192.168.1.15:8000'` olarak güncellendi.

<!-- YENİ SORUN EKLE ↓ -->

---

## 🎓 2026-04-19 — Hocam Feedback (Perşembe 23 Nisan'a Kadar Bitmeli)

**Takvim:** 19 → 23 Nisan 2026 (net 4 gün + Perşembe buffer).
**Kota:** Claude Pro haftalık token %43 dolu — disiplinli çalış, gereksiz tur yok.
**Parity:** Her özellik hem web hem mobil. [[PlatformConsistency]] kuralı.
**Plan:** [[PLAN-2026-04-19-to-23]]

### 🔑 Ana Tema — "Verileri Doğru Kullanmıyoruz"

Tüm veri-ilgili item'ların kök sebebi tek: **10+ yıllık hava verisi işlenmemiş, her istek canlı hesaplıyor, sonuçlar tutarsız.** Çözüm → Backend:
1. **Saatlik scheduler** (günde 24 Open-Meteo çekimi) — kullanıcı en başında söylemişti, unutulmuş.
2. **`province_analysis` tablosu** — 10+ yıllık veriyi işle, il×tip skorları kaydet.
3. **Tek kaynak:** Raporlar, İl Analizi, Önerilen Bölgeler, Choropleth hepsi bu tablodan beslenir.

Hocam kendi söyledi: *"Manisanın rüzgarlı olduğu sistem kendi başına bulmalı ve kaydetmeli, tekrardan aramamalı."*

### 🔴 P0 — Faz 1: Backend Veri Altyapısı (tüm demo buna bağlı)

Kullanıcı netleştirdi: _"Saat başı güncelleme demiştim sana en başında da, şimdi de hatırlatıyorum. Günde 24 kere veri çekmiş olacağız."_ + _"Manisanın rüzgarlı olduğu sistem kendi başına bulmalı ve kaydetmeli, tekrardan aramamalı."_

**2026-04-19 — Skor Netleştirmesi (diğer sohbet başlamadan önce):**
- 4 pencere: **30 / 90 / 180 / 365 gün** (`score_1m`, `score_3m`, `score_6m`, `score_yearly`). `score_3m` sonradan eklendi — Önerilen Bölgeler "1-6 ay" spec'i için.
- Wind: **cube-law default** (P ∝ v³); Solar üst sınır: **400 W/m²** (500 yüksekti); Hydro: precipitation + temperature_2m proxy, HES havza verisi TODO.
- `avg_temperature` ham metriği de yaz (modelde kolon var).

- [ ] **Saatlik veri scheduler (APScheduler).** Backend'de her saat başı Open-Meteo'dan 81 il için hourly çekim. Günde 24 snapshot. Son çekim timestamp'i DB'de.
- [ ] **`province_analysis` tablosu.** 10+ yıllık geçmiş + saatlik güncel veriyi işleyip il × tip (rüzgar/güneş/hidro) skorlarını DB'de tut. Raporlar, İl Analizi, Önerilen Bölgeler, Choropleth **tek kaynaktan** beslensin.
- [ ] **"228 dk önce güncellendi" metni düzelt.** Saatlik scheduler bitince mock sıfırlansın — gerçek `last_scheduler_run` timestamp'i göster.
- [ ] **Isı & Işınım choropleth bozuk** — Rüzgar doğru çalışıyor. Scheduler + scale fix sonrası iki metrik de doğru dönmeli.
- [ ] **Raporlar ↔ İl Analizi ↔ Harita tutarlılığı** — Haritada "her şey 100 puan", İl Analizi'nde "hepsi 40-60 puan". Aynı tablodan besleme → aynı skorlar.

### 🔴 P0 — Bulut Örüntüsü: DISABLE + "Yakında" işareti

- [x] **Bulut katmanı toggle'ını disable et + "Yakında" rozeti.** `layers_panel.dart` içinde `_cloudLayerEnabled = false` sabitiyle disabled + badge 'YAKINDA'. Hot-restart gerektirmeyen derleme-sabiti; gelecekte tek satır `true`'ya çevrilerek geri açılacak.
  - İlgili eski item'lar (şu an dondur): telefonda çalışmıyor, "Zoom Level Not Supported", yağmur/normal ayrımı, legend.

### 🟠 P1 — Faz 2: Raporlar Redesign + Harita Entegrasyonu

- [ ] **Raporlar sekmesini "Önerilenler" kartlı yapısına çevir.** Aynı UI dili, tutarlı UX. _(Parite için bekleme; mevcut 6-tab yapısı korundu)_
- [ ] **Raporlar → Harita alt-sekmesi:** Rüzgar / Sıcaklık / Işınım layer toggle + sağdaki il listesinden tıklayınca haritanın o ile zoom olması.
- [ ] **"Raporlar'a geç / çık" state kayboluyor** — Sekmeden çıkıp dönünce seçili il/metrik state'i sıfırlanıyor. ViewModel'de state korunmalı.
- [x] **Önerilen Bölgeler = Raporlar'ın kısa vadeli top-N çıkarımı.** Panel `AnalysisService.fetchProvinces(wind/solar/hydro, horizon)` ile `province_analysis` tablosundan besleniyor. Horizon seçici (1A/3A/6A/Yıl) + 3 kaynak × top-N liste. "ML yakında" boş state kaldırıldı; Weibull kategorileri opsiyonel alt-blok olarak kaldı.
- [ ] **Önerilen Bölgeler'i ana harita ve Raporlar/Harita'da göster.** Kullanıcı bölge seçer gibi seçebilsin.

### 🟠 P1 — Faz 3: Senaryo Yönetimi Düzeltmeleri

Kullanıcı eksikleri netleştirdi:

- [ ] **Senaryo haritada göster/gizle toggle** — Senaryo oluşturulduktan sonra haritada görünsün, istendiğinde gizlenebilsin.
- [x] **Senaryo → "Rapor'a Git" butonu** — Mevcut `scenario_detail_dialog.dart` ve `scenario_mini_report_panel.dart` butonları doğrulandı; `main.dart` route'u `scenarioId` argümanını unpack ediyor, `ReportScreen(initialScenarioId:...)` senaryoyu `selectOnly(id)` ile otomatik seçip Senaryo tab'ına açılıyor.
- [x] **"Tam Ekran" butonu düzeltme** — `scenario_mini_report_panel.dart` "Tam Rapor" ve "Geniş Ekran" butonları `/reports`'a yönlendiriyor; `onReport` card callback'i `scenarioId` argümanıyla push yapıyor ve artık doğru sekmeye iniyor.

### 🟠 P1 — Faz 3: İl Analizi Ekranı Düzeltme

- [x] **İl Analizi skorları Faz 1'deki `province_analysis` tablosundan çekilecek.** `province_drill_tab.dart` içine "Kaynak × Zaman Pencere Skorları" bloğu eklendi: 3 satır (rüzgar/güneş/hidro) × 4 sütun (1A/3A/6A/Yıl). `ReportViewModel.setSelectedProvinceIndex` seçim değişince `analysis.fetchProvinceDetail(name)` çağırıyor.

### 🟡 P2 — Faz 3: Ayarlar Ekranı

Kullanıcı: _"İçeriği sen tespit et."_ Claude tespiti (mevcut state'ten çıkarılmış):

- [x] **Yeni Ayarlar ekranı** — `settings_dialog.dart` placeholder'dan genişletildi: Görünüm (Dark/Light toggle), Veri Kaynağı (sağlayıcı + scheduler + tablo listesi), Hakkında (sürüm kopyala, kapsam). Dil/birim/bildirim yakında notu bırakıldı.

### 🟡 P2 — Genel Bakış (Kaldır)

Kullanıcı: _"Genel Bakış'ı unut, sil."_

- [ ] **Genel Bakış ekranını / sekmesini kaldır.** Navigasyondan link + widget'ları temizle. Kullanılan helper'lar referanssız kalıyorsa sil.

### 🔵 Kesişen Gereklilikler

- [ ] **Platform parity (mobil = web)** — Her özellik her iki platformda **aynı** davranmalı. Her fazın sonunda iki tarafta da smoke test. [[PlatformConsistency]] kuralı.
- [ ] **Tanıtım videosu — AI seslendirmeli.** Feature donduktan sonra senaryo + ekran kaydı + AI voiceover (ElevenLabs / TTS). Detay [[PLAN-2026-04-19-to-23]] Faz 5.

### 🟣 Perşembe Sonrası (P3 — bu sprint dışı)

- Global Projeksiyon (Parça 4) — yukarıdaki P3 bölümüyle birlikte.
- Bulut düzeltme (disable'ı geri aç → mobil port + legend + yağmur ayrımı).
- Zaman Simülasyonu bug araştırması.

---

## Arşiv

2 haftadan eski çözülmüş sorunlar `issues/` altında kalır — buradan silinir.
Aktif takip gereken item'lar burada kalır.

## Bağlantılar

- [[INDEX]] — vault ana haritası
- [[issues/_template]] — yeni issue şablonu

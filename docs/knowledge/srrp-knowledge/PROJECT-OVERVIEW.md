---
tags: [overview, vision, onboarding]
updated: 2026-05-08
related: [INBOX, "PLAN-2026-04-19-to-23", INDEX, PinAddFlow, LibrarySidePanel]
---

# 🌍 SRRP — Proje Büyük Resim

Yeni bir Claude oturumu başladığında **önce bunu oku**, sonra [[INBOX]] + [[PLAN-2026-04-19-to-23]] ile aktif sprint'e geç. Detay isteyen her bölüm için alt tarafta kaynak .md listesi var.

## Proje Nedir

**Smart Renewable Resource Planner (SRRP)** — Türkiye'de yenilenebilir enerji yatırımlarını (rüzgar, güneş, hidroelektrik) planlamak için bir GIS uygulaması. Açık kaynaklı hava verileri + coğrafi veriler + analitik ile kullanıcı (yatırımcı/araştırmacı) bir noktanın ya da ilin yenilenebilir potansiyelini değerlendirebiliyor, santral pinleri yerleştirip ROI tahmini çıkarabiliyor.

Kapsam **sadece Türkiye** (81 il, ~960 ilçe). Globe modu sonra eklenecek ama esas vaka Türkiye odaklı.

## Neden / Kim İçin

- **Bitirme projesi.** Hocam teslim kararı veriyor. İlk teslim: **Perşembe 23 Nisan 2026.**
- O tarihte **tanıtım videosu + çalışan demo** bekleniyor. AI seslendirmeli video (bkz. [[PLAN-2026-04-19-to-23]] Faz 5).
- Son kullanıcı: yatırım analizi yapacak kişi. Demo hikayesi: "Haritada bir il seç → potansiyel skorlarına bak → senaryo oluştur → rapor al."

## Ana Ekranlar (Kullanıcı Gözünden)

| Ekran | Amaç | Durum |
|---|---|---|
| **Harita (ana)** | Seçim modları (Bölge/İl/İlçe), katmanlar, pin yerleştirme, choropleth | ✅ Çalışıyor, P0 bug'lar kapalı |
| **Raporlar** | İl Analizi / Harita / Önerilen Bölgeler alt-sekmeleri | 🔧 Faz 2'de redesign |
| **Önerilen Bölgeler** | 1-6 ay kısa vadede en iyi yatırım illeri (top-N) | 🔧 Faz 1 tablosu bitince dolacak |
| **Senaryo Yönetimi** | Yatırım senaryoları: oluştur, haritada görüntüle, rapora git | 🔧 Faz 3'te bug fix + eksikler |
| **Ayarlar** | Tema, harita stili, birimler, veri tazelik | 🆕 Faz 3'te sıfırdan |
| ~~Genel Bakış~~ | (kaldırılıyor) | ❌ Faz 3'te silinecek |

## Stack (Tek Bakışta)

- **Frontend:** Flutter (web + native). Harita: MapLibre GL JS (web) + MapLibre Native SDK (mobil). Basemap: OpenFreeMap Liberty.
- **Backend:** Python + FastAPI (async). ORM: SQLAlchemy 2.x async + Alembic.
- **DB:** PostgreSQL + PostGIS.
- **Tile Server:** Martin (PostGIS'ten doğrudan .mvt).
- **Cache:** Redis + in-memory fallback.
- **Dış Veri:** Open-Meteo Archive (hava/iklim), OSM/Overpass (sınırlar).

Detay kurulum: [[README.md]] kök dizininde.

## Mimari Prensipler

1. **Tek kaynak prensibi (bu sprint'in kök kararı).** Tüm skorlar/metrikler `province_analysis` tablosundan okunur. Raporlar, İl Analizi, Önerilen Bölgeler, Choropleth — aynı tablo. "Canlı hesaplama" patika deprecate.
2. **Saatlik veri güncellemesi.** APScheduler, 24/gün Open-Meteo çekimi. Bkz. [[WeatherRouter]] + [[PLAN-2026-04-19-to-23]] Faz 1.
3. **Platform parity.** Her özellik web + mobil aynı davranmalı. [[PlatformConsistency]].
4. **Vault tek bilgi kaynağı.** Kod değiştirince ilgili `.md` aynı commit'te güncellenir. Eski `frontend/ARCHITECTURE.md` artık dondu.
5. **Harita Stack kuralı.** MapScreen ana Stack'e eklenen her widget `Positioned` ile sarılmalı. [[MapStackPositioned]].

## Önceki Sprint (19-23 Nisan) — Tamamlandı

Faz 1-3 tamamlandı: APScheduler + `province_analysis` + tek-kaynak endpoints,
Raporlar redesign, Senaryo düzeltme, Ayarlar ekranı, Genel Bakış kaldırıldı.
Tam detay: [[PLAN-2026-04-19-to-23]].

## Aktif Sprint (2026-05-08+) — Pin UX Yeniden Yapılandırma

2026-05-08 test turunda kullanıcı pin akışının ve sol panelin yanlış
yorumlandığını söyledi. Doğru yapı:

1. **Pin V3 inline popover** (tıklanan noktanın üstünde 3-tip mini menü)
2. **Pin V2 zengin floating form** (pin yanına yapışık, sağ veri paneli + alt yıllık tahmin + gelişmiş ayarlar)
3. **Sol Kütüphane panel** (Senaryolar | Pinlerim segmented header, kaynak-gruplu pin listesi, alt "Yeni Kaynak Ekle")
4. **Suitability RES genişletme** (yerleşim/otoyol/sanayi/orman mesafe kontrolleri)
5. **Telefon kritik bug fix** (il modu, zaman simülasyonu, chatbot `part.function_call`)

Detay: [[INBOX]] (2026-05-08 bölümü), [[PinAddFlow]], [[LibrarySidePanel]],
[[AdvancedSettings]].

**Sprint 1 odak:** Pin akışı + sol panel (UX kritik).
**Sprint 2:** Telefon bugları + chatbot fix.
**Sprint 3:** Suitability RES + gelişmiş ayarlar form.
**Sprint 4:** HES backend potansiyel (DSI/EİE), marker stilleri, polish.

## Sprint Sonrası (Bu Teslimden Sonra)

Bunlar bu sprint **dışı**, hatırlatma için:
- **AI Chatbot** (LLM ile doğal dil analizi) — 15 Nisan sonrası kullanıcı söyleyince.
- **ML Projeksiyonu** — `ml_projection_placeholder.dart` hazır, kullanıcı zamanı söyleyecek.
- **İngilizce dil (i18n)** — Flutter `intl`/`.arb` altyapısı kurulacak, dil seçici Ayarlar'a.
- **Global Projeksiyon** — Globe modu + TR dışı pin davranışı. [[INBOX]] P3.
- **LCOE / ROI detay modeli, HES modülü, Docker + Cloud deploy.**

## Bilinen Veri Kalitesi Notları

- Overpass bbox bazı ilçeleri yanlış ile atıyor (Antakya→Adana gibi). Toplama bittikten sonra PostGIS ile koordinat bazlı düzeltme yapılacak. (`memory/project_future_features.md`.)
- 10+ yıllık Open-Meteo arşivi iniyor — `province_analysis` seed'i bu arşivden beslenecek.

## Daha Derin Kaynaklar (Kod Kök Dizininde)

Claude daha fazla bağlam isterse bu dosyalara bakabilir:

- **[[README.md]]** — kurulum + stack + genel yol haritası
- **SRRP_DOC.md** — en güncel "yaşayan" mimari dokümanı
- **ARCHITECTURE.md** — (dondu, referans) frontend mimari detayı
- **SPRINT_CHANGELOG.md** — geçmiş sprint kayıtları
- **PROJECT_DOCUMENTATION_1/2/3.md** — detaylı modül açıklamaları
- **SRRP_DEVELOPMENT_ROADMAP.md** — uzun vadeli yol haritası
- **DISCUSSION_OF_RESULTS.md** — analiz bulgular/tartışma
- **OPTIMIZATION_FEATURE.md** — performans optimizasyon kararları
- **TESTING_STRATEGY.md** — test yaklaşımı
- **new_features_v2.md / SRRP_v2_dev.md** — v2 geliştirme notları

Vault içinde:
- **[[INBOX]]** — aktif sorun listesi (Hocam Feedback dahil)
- **[[PLAN-2026-04-19-to-23]]** — aktif sprint planı
- **[[INDEX]]** — tüm atomik notların haritası
- **[[SelectionModes]]**, **[[MapViewModel]]**, **[[PlatformConsistency]]**, **[[WeatherRouter]]** vb. — atomik kavramlar

## Bağlantılar

- [[INDEX]] — vault haritası
- [[INBOX]] — aktif sorunlar + Hocam Feedback
- [[PLAN-2026-04-19-to-23]] — aktif sprint detayı

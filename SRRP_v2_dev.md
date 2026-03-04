# 🚀 SRRP v2.0 — Geliştirme Yol Haritası
## Smart Renewable Resource Planner — Production-Ready & Expansion Plan

**Tarih:** 25 Şubat 2026  
**Hazırlayan:** Gürkan & Utku  
**Durum:** Planlama Aşaması  
**Hedef:** Akademik MVP → Ticari Ürün Dönüşümü

---

## 📊 GAP ANALİZİ (v1.0 → v2.0)

| Özellik | Mevcut Durum (v1.0) | Hedeflenen Durum (v2.0) |
|---------|---------------------|-------------------------|
| **Enerji Kaynakları** | Güneş, Rüzgar | + Hidroelektrik (Baraj/HES) + Yüzer GES |
| **Veritabanı** | SQLite (3 parça, concurrency sorunu) | PostgreSQL + PostGIS + TimescaleDB |
| **Harita Kapsamı** | Statik Türkiye sınırları (Shapefile bağımlı) | Global / Dinamik Kapsam |
| **Zaman Analizi** | Statik ortalamalar & basit grafikler | Time-Slider ile haritada canlı değişim izleme |
| **Görsellik** | Standart Material/Dark UI | Glassmorphism / Neon Dashboard |
| **Finansallar** | Temel ROI, NPV, Geri Ödeme | + LCOE, Karbon Kredisi, EPİAŞ Arbitrajı |
| **GIS Analiz** | Temel uygunluk (su, yol, eğim) | + Yasaklı Bölgeler, 3D Arazi, Gölgeleme |
| **AI/ML** | scikit-learn yüklü ama aktif değil | LSTM/XGBoost tahmin, İklim senaryoları |
| **Önbellekleme** | Yok | Redis cache katmanı |
| **Dağıtım** | Yerel (Localhost) | Dockerized & Cloud Ready |
| **Enerji Yönetimi** | Sadece üretim | + Tüketim profili, Batarya (ESS), Hibrit |
| **Raporlama** | Ekran içi raporlar | + PDF Fizibilite Raporu (Bankaya sunulabilir) |

---

## 🏗️ FAZ 1 — TEMEL MİMARİ DÖNÜŞÜM (Infrastructure Overhaul)

### 1.1 Veritabanı Migrasyonu: PostgreSQL & PostGIS

Mevcut 3 parçalı SQLite sistemi, tekil ve güçlü bir PostgreSQL sunucusuna taşınacaktır.

**Neden gerekli:**
- Baraj havzaları (`Polygon`), nehir yatakları (`Linestring`) ve yasaklı bölgelerin geometrik sorguları için PostGIS zorunlu
- Çoklu kullanıcı ve concurrent erişim desteği
- TimescaleDB eklentisi ile saatlik hava/üretim verileri optimize edilecek

**Yeni Tablo Yapısı:**

| Şema | Tablo | Açıklama |
|------|-------|----------|
| `spatial_data` | `rivers` | Nehirler (LineString) |
| `spatial_data` | `substations` | Trafo Merkezleri (Point) |
| `spatial_data` | `restricted_zones` | Yasaklı Bölgeler (Polygon) |
| `time_series_data` | `hourly_weather` | TimescaleDB ile optimize saatlik veri |
| `public` | `users`, `pins`, `scenarios` | Mevcut kullanıcı verileri |

**İş Adımları:**
- [ ] Alembic migration scriptleri hazırla
- [ ] SQLite → PostgreSQL veri aktarımı
- [ ] PostGIS eklentisini etkinleştir
- [ ] `database.py` engine'lerini güncelle
- [ ] Tüm CRUD sorgularını PostgreSQL uyumlu hale getir

---

### 1.2 Backend Servis Mimarisi (Modular Monolith)

`backend/app/services` klasörüne yeni modüller:

| Yeni Servis | Dosya | Açıklama |
|-------------|-------|----------|
| **Hidroelektrik Servisi** | `hydro_service.py` | HES ve Yüzer GES hesaplamaları |
| **AI Tahmin Servisi** | `ai_forecasting_service.py` | LSTM/XGBoost tabanlı üretim tahmini |
| **Gelişmiş Finans** | `financial_advanced_service.py` | LCOE, EPİAŞ, Karbon Kredisi |
| **Bilgisayarlı Görü** | `vision_service.py` | Uydu görüntüsünden çatı analizi (OpenCV) |
| **Zaman Serisi** | `time_series_service.py` | Time-Slider için GeoJSON stream |

---

### 1.3 Önbellekleme Katmanı (Redis)

**Teknoloji:** Redis  
**Amaç:** Time-Slider simülasyonu sırasında oluşacak anlık veri trafiğini (81 il × 24 saat) yönetmek ve Open-Meteo API rate limit'lerine takılmamak.

**Önbellek Stratejisi:**
- Saatlik hava durumu verileri → TTL: 1 saat
- Grid analiz sonuçları → TTL: 24 saat
- İnterpolasyon haritaları → TTL: 6 saat

---

## ⚡ FAZ 2 — YENİ ENERJİ MODÜLLERİ (Core Energy Expansion)

### 2.1 Hidroelektrik ve Baraj Modülü (HES)

Sisteme **"Su Enerjisi"** dikey olarak entegre edilecektir. Hidroelektrik, Güneş ve Rüzgar'dan farklıdır — **"Konum" değil, "Yükseklik ve Su Akışı"** önemlidir.

**Fiziksel Formül:**
```
P = ρ × g × Q × H × η
```
- `ρ` — Suyun yoğunluğu (1000 kg/m³)
- `g` — Yerçekimi ivmesi (9.81 m/s²)
- `Q` — Debi (m³/s)
- `H` — Düşü yüksekliği (m)
- `η` — Türbin verimi

**Girdi Parametreleri:**

| Parametre | Kaynak | Açıklama |
|-----------|--------|----------|
| Debi (Q) | Manuel giriş veya Open-Meteo Yağış × Havza Alanı | m³/s |
| Düşü Yüksekliği (H) | DEM verisinden otomatik (iki nokta farkı) | metre |
| Türbin Tipi | Kullanıcı seçimi | Kaplan / Francis / Pelton |
| Havza Alanı | Manuel veya GIS | km² |

**UI Değişiklikleri:**
- "Yeni Kaynak Ekle" dialoguna **"Hidroelektrik Santral"** sekmesi
- Panel Alanı → Havza Alanı (km²) veya Debi (m³/s)
- Panel Modeli → Türbin Tipi (Kaplan, Francis, Pelton)
- DEM'den otomatik düşü yüksekliği hesaplama

**İş Adımları:**
- [ ] `hydro_service.py` yazılması
- [ ] HES için Pydantic şemaları
- [ ] Pins router'a "Hidroelektrik" tip desteği
- [ ] Frontend'de HES pin ekleme dialogu
- [ ] Haritaya nehir yatakları katmanı (blue-line vectors)

---

### 2.2 Yüzer GES (Floating Solar) — Hibrit Özellik

Baraj gölü yüzeyine kurulacak panellerin **çifte kazanç** analizi:

1. **Enerji Üretimi:** Normal panel hesabı
2. **Buharlaşma Engelleme:** Kaplanan yüzey × buharlaşma oranı = m³ su tasarrufu

**Çıktı:** "X kWh elektrik ürettin + Y ton suyun buharlaşmasını engelledin"

- [ ] Yüzer GES hesaplama modülü
- [ ] Buharlaşma engelleme formülü entegrasyonu
- [ ] Çifte kazanç rapor çıktısı

---

### 2.3 Enerji Depolama ve Hibrit Sistemler (ESS)

**Batarya (Li-Ion / LFP) boyutlandırma modülü:**

| Analiz | Açıklama |
|--------|----------|
| **Autonomy Days** | Güneşsiz/rüzgarsız geçen maksimum süre |
| **Batarya Kapasitesi** | Gerekli kWh hesaplama |
| **Maliyet** | Batarya $/kWh × Kapasite |
| **Hibrit Senaryo** | Güneş + Rüzgar + Batarya birleşik maliyet analizi |

- [ ] ESS boyutlandırma servisi
- [ ] Batarya maliyet tablosu (Equipment'e ek)
- [ ] Hibrit senaryo desteği (scenario router genişletme)
- [ ] Frontend'de batarya konfigürasyon paneli

---

### 2.4 Yük Profili (Consumption Analysis)

Sadece üretimi değil, **tüketimi de modelleme.**

**Tüketim Şablonları:**

| Profil | Günlük Desen | Pik Saat |
|--------|-------------|----------|
| 🏠 Ev | Sabah + akşam yoğun | 18:00-22:00 |
| 🏭 Fabrika | Gündüz sabit yük | 08:00-18:00 |
| 🌾 Tarımsal Sulama | Yaz gündüz yoğun | 10:00-16:00 |

**Çıktı:** Üretim ve tüketim eğrilerinin örtüşmesi (Self-Consumption Rate)  
**Soru:** "Hangi saatlerde şebekeden al, hangi saatlerde şebekeye sat?"

- [ ] Tüketim profili şablonları
- [ ] Üretim-tüketim overlay grafiği
- [ ] Self-consumption rate hesaplaması
- [ ] Net metering / feed-in tariff analizi

---

## 🗺️ FAZ 3 — GELİŞMİŞ GIS VE ARAZİ ANALİZLERİ (Spatial Intelligence)

### 3.1 3D Arazi ve Gölgeleme Analizi (Shadow Analysis)

**Teknoloji:** Mapbox GL JS veya Cesium entegrasyonu

| Özellik | Detay |
|---------|-------|
| **3D Terrain** | DEM verisiyle dağ/vadi 3D görselleştirme |
| **Gölgeleme** | Güneşin saatlik açısına göre gölge hesabı |
| **Uyarı** | "Bu vadiye panel kurma, saat 15:00'ten sonra dağın gölgesi düşüyor" |

**Hesaplama:** DEM (Digital Elevation Model) + güneş azimut/zenit açısı → gölge projeksiyonu

- [ ] DEM verisini tile formatına dönüştür
- [ ] Güneş pozisyonu kütüphanesi entegre et (pysolar veya benzeri)
- [ ] Gölge haritası hesaplama endpoint'i
- [ ] Frontend'de 3D arazi katmanı
- [ ] Gölgeleme uyarı sistemi

---

### 3.2 Yasaklı Bölgeler ve Zoning (Red Zones)

| Veri Seti | Kaynak | Tip |
|-----------|--------|-----|
| Milli Parklar | Tabiat Varlıkları Koruma | Polygon |
| Askeri Bölgeler | Kamu verisi | Polygon |
| Sit Alanları | Kültür Bakanlığı | Polygon |
| Kuş Göç Yolları | BirdLife International | LineString/Buffer |

**Fonksiyon:** Pin atıldığında → "⚠️ Yasal Uyarı: Sit Alanı" + ÇED risk puanı artışı

- [ ] Yasaklı bölge veri setlerini PostGIS'e yükle
- [ ] Geo router'a yasal uyarı kontrolü ekle
- [ ] Frontend'de kırmızı alan katmanı (toggle)
- [ ] ÇED risk puanı hesaplama

---

### 3.3 Şebeke Entegrasyon Maliyeti (Grid Connection)

| Veri | Açıklama |
|------|----------|
| Trafo Merkezleri (Substations) | Konum verileri (PostGIS Point) |
| Enerji Nakil Hatları | Hatların güzergahı (PostGIS LineString) |

**Analiz:** Santral ↔ en yakın trafo arası kuş uçuşu mesafe → OG kablo maliyeti → CAPEX'e otomatik ekleme

- [ ] Trafo merkezi verilerini temin et ve yükle
- [ ] En yakın trafo mesafe hesaplama (Haversine / PostGIS)
- [ ] Kablolama maliyet modeli (₺/km veya $/km)
- [ ] Finansal analize otomatik ekleme
- [ ] Haritada trafo katmanı gösterimi

---

### 3.4 Uydu Destekli Çatı Analizi (Computer Vision)

**Akış:**
```
Kullanıcı binaya tıklar
  → Google Static Maps API'den uydu görüntüsü alınır
  → OpenCV ile çatı sınırları tespit edilir
  → Güney cephe alanı (m²) otomatik hesaplanır
  → Sonuç forma doldurulur → "Tek tıkla fizibilite"
```

**Teknoloji:** Google Maps Static API + OpenCV (veya ML model)

- [ ] `vision_service.py` — çatı tespit servisi
- [ ] Google Static Maps API entegrasyonu
- [ ] OpenCV edge detection + alan hesabı
- [ ] Frontend'de "Çatımı Analiz Et" butonu
- [ ] Sonuçların pin formuna otomatik doldurulması

---

## ⏰ FAZ 4 — ZAMAN VE GELECEK SİMÜLASYONU (Predictive Intelligence)

### 4.1 Time-Series Slider (Canlı Simülasyon)

Harita arayüzüne **00:00 – 23:59 arası** kontrol edilebilir bir zaman çubuğu eklenir.

**Görsel Efektler:**
- ☀️ Güneş paneli icon'larının "Glow" efekti saatlik güneş verisine göre artar/azalır (gece söner)
- 💨 Rüzgar okları (vector field) o saatteki yön ve şiddete göre döner
- 🌡️ Sıcaklık gradient'i saatlik olarak güncellenir

**Teknik:**
- Backend: `hourly_weather_data` tablosundan GeoJSON formatında stream
- Önbellek: Redis üzerinden saatlik veri cache'leme
- Frontend: Slider widget + animasyonlu harita katmanı

- [ ] `time_series_service.py` — saatlik GeoJSON endpoint
- [ ] Redis cache entegrasyonu
- [ ] Frontend Time Slider widget'ı
- [ ] Güneş glow animasyonu
- [ ] Rüzgar vektör animasyonu
- [ ] Play/Pause/Speed kontrolleri

---

### 4.2 AI Destekli Üretim Tahmini (Forecasting)

| Parametre | Değer |
|-----------|-------|
| **Model** | LSTM (Long Short-Term Memory) veya XGBoost |
| **Eğitim Verisi** | 10 yıllık Open-Meteo arşivi (2015-2025) |
| **Çıktı** | P50 (Ortalama Beklenti) ve P90 (Kötü Senaryo) |

**Soru:** "Önümüzdeki yıl bu ay üretim ne kadar düşebilir?"

- [ ] `ai_forecasting_service.py` — model eğitim pipeline
- [ ] Model seçimi (XGBoost vs LSTM benchmark)
- [ ] P50 / P90 tahmin endpoint'i
- [ ] Frontend'de tahmin grafiği (güven aralıklı)
- [ ] Model versiyonlama ve yeniden eğitim mekanizması

---

### 4.3 İklim Değişikliği Senaryoları (Climate Twin)

| Senaryo | Kaynak | Açıklama |
|---------|--------|----------|
| **RCP 4.5** | IPCC | İyimser — ılımlı emisyon azaltımı |
| **RCP 8.5** | IPCC | Kötümser — mevcut trend devam |

**Simülasyon Soruları:**
- "2050'de kuraklık %20 artarsa HES üretimim ne olur?"
- "Isınma artarsa güneş paneli verimi (aşırı sıcak) ne kadar azalır?"
- "Rüzgar desenleri değişirse türbin kapasitesi nasıl etkilenir?"

- [ ] IPCC RCP veri seti entegrasyonu
- [ ] Senaryo bazlı üretim düzeltme faktörleri
- [ ] "2050 Senaryosu" butonu (Frontend)
- [ ] Karşılaştırmalı grafik (Bugün vs 2050)

---

## 💰 FAZ 5 — TİCARİ VE OPERASYONEL MODÜLLER (Business Intelligence)

### 5.1 Gelişmiş Finansallar

| Metrik | Formül | Açıklama |
|--------|--------|----------|
| **LCOE** | Toplam Ömür Boyu Maliyet / Toplam Ömür Boyu Üretim | $/kWh — Endüstri standardı |
| **Karbon Kredisi** | Yıllık CO₂ Tasarrufu (Ton) × Karbon Borsası Fiyatı | Ek gelir kalemi |
| **CO₂ Tasarrufu** | Üretim (kWh) × Emisyon Faktörü | Ton CO₂/yıl |

- [ ] `financial_advanced_service.py` yazılması
- [ ] LCOE hesaplama endpoint'i
- [ ] Karbon kredisi gelir hesabı
- [ ] Frontend'de gelişmiş finansal dashboard

---

### 5.2 Enerji Borsası Entegrasyonu (EPİAŞ / Arbitraj)

**Entegrasyon:** Türkiye Spot Piyasa (PTF) elektrik fiyatları

**Arbitraj Algoritması:**
```
Elektrik ucuz (öğle) → Bataryada depola
Elektrik pahalı (akşam) → Şebekeye sat
→ Kâr = ΔFiyat × Depolanan kWh
```

- [ ] EPİAŞ/PTF veri kaynağı entegrasyonu (veya simüle)
- [ ] Saatlik fiyat endpoint'i
- [ ] Arbitraj kar hesaplama
- [ ] Frontend'de fiyat grafiği + arbitraj stratejisi gösterimi

---

### 5.3 Çok Kriterli Karar Destek (MCDM — AHP)

**Sihirbaz (Wizard) Akışı:**
```
"Senin için hangisi daha önemli?"

  Maliyet:    ████████████░░░░  40%
  Üretim:     ██████░░░░░░░░░░  30%
  Risk:       ██████░░░░░░░░░░  30%

  → AHP → Haritadaki heatmap kullanıcıya göre yeniden boyanır
```

**Değer:** Standart harita yerine **"kişiye özel" yatırım haritası**

- [ ] AHP algoritması implementasyonu
- [ ] Kriter ağırlık sihirbazı (Frontend wizard)
- [ ] Dinamik heatmap re-coloring
- [ ] Sonuç açıklama paneli

---

### 5.4 Bakım ve Yıpranma Takvimi (Predictive Maintenance)

| Çevresel Faktör | Risk | Bakım Önerisi |
|-----------------|------|---------------|
| 🌊 Tuzluluk (denize yakınlık) | Korozyon | 6 ayda bir bakım |
| 🏜️ Toz (kuraklık) | %5 verim kaybı | Ayda bir temizlik |
| 💧 Nem (tropikal) | İzolasyon bozulması | Yıllık kontrol |
| ⛈️ Fırtına | Mekanik hasar | Sigorta + güçlendirme |

**Çıktı:** OPEX (İşletme Gideri) tahmini + bakım takvimi

- [ ] Çevresel risk puanlama modeli
- [ ] Ekipman ömür beklentisi hesabı
- [ ] Bakım takvimi oluşturma
- [ ] OPEX hesabının finansal analize eklenmesi

---

## 🛠️ FAZ 6 — OPERASYONEL ARAÇLAR (Field Operations)

### 6.1 Drone Uçuş Rotası Planlayıcısı

| Girdi | Çıktı |
|-------|-------|
| Haritada seçilen poligon alan | Otonom drone uçuş rotası |
| DEM verisinden arazi eğimi | Terrain Following irtifa planı |
| Drone batarya süresi | Sorti sayısı hesabı |

**Dosya Çıktısı:** `.kml` veya `.gpx` (DJI/ArduPilot uyumlu)

**Slogan:** *"SRRP ile planla, Drone'a yükle, Uçur"*

- [ ] Waypoint hesaplama algoritması
- [ ] Terrain following irtifa planlaması
- [ ] KML/GPX export
- [ ] Frontend'de poligon çizim + indirme butonu

---

### 6.2 Profesyonel PDF Fizibilite Raporu

**İçerik (15–20 sayfa):**
1. Kapak Sayfası
2. Yönetici Özeti
3. Konum ve Arazi Analizi (Harita görseli)
4. Enerji Üretim Tahmini (Grafikler)
5. Finansal Tablolar (NPV, LCOE, Geri Ödeme)
6. Risk Analizi (ÇED, İklim, Bakım)
7. Teknik Spesifikasyonlar
8. Ekler (Veri kaynakları, Metodoloji)

**Kalite:** Bankaya kredi başvurusu için sunulabilir seviye

- [ ] PDF template tasarımı
- [ ] Backend rapor oluşturma endpoint'i (ReportLab veya WeasyPrint)
- [ ] Grafik ve harita görseli embed
- [ ] Frontend'de "PDF İndir" butonu

---

### 6.3 Yatırımcı Vitrini (Social Layer) — Opsiyonel / Gelecek

Kullanıcıların projelerini **"Yatırımcı Arıyorum"** etiketiyle yayınlayabileceği pazar yeri modülü.

---

## 🎨 FAZ 7 — ARAYÜZ VE UX STRATEJİSİ (Design System v2.0)

### Tasarım Dili: "Scientific Glassmorphism"

| Öğe | Tasarım |
|-----|---------|
| **Tema** | Koyu mod (Dark Mode) varsayılan |
| **Kartlar** | Neon parlamalı, glassmorphism efektli |
| **Grafikler** | İnteraktif Line Chart (Tooltip detay) |
| **Harita** | İnteraktif katman kontrolü (Layer Control) |
| **Dashboard** | Canlı enerji üretim göstergesi |
| **Mobil** | Responsive tasarım (saha personeli için) |

**UI İyileştirmeleri:**
- [ ] Glassmorphism tasarım sistemi
- [ ] Neon glow kartlar ve göstergeler
- [ ] İnteraktif Line Chart (fl_chart → detaylı tooltip)
- [ ] Responsive mobil layout
- [ ] Animasyonlu geçişler ve mikro-etkileşimler

---

## 📋 ÖNCELİK MATRİSİ

| Öncelik | Özellik | Etki | Efor | Faz |
|---------|---------|------|------|-----|
| 🔴 **Kritik** | PostgreSQL + PostGIS Geçişi | Çok Yüksek | Yüksek | 1 |
| 🔴 **Kritik** | Hidroelektrik Modülü (HES) | Çok Yüksek | Orta | 2 |
| 🔴 **Kritik** | Time-Slider Simülasyon | Yüksek | Yüksek | 4 |
| 🟠 **Yüksek** | Redis Cache Katmanı | Yüksek | Düşük | 1 |
| 🟠 **Yüksek** | LCOE & Karbon Kredisi | Yüksek | Düşük | 5 |
| 🟠 **Yüksek** | Yasaklı Bölgeler Katmanı | Yüksek | Orta | 3 |
| 🟠 **Yüksek** | PDF Fizibilite Raporu | Yüksek | Orta | 6 |
| 🟡 **Orta** | Batarya (ESS) Modülü | Orta | Orta | 2 |
| 🟡 **Orta** | Yük Profili (Consumption) | Orta | Düşük | 2 |
| 🟡 **Orta** | Şebeke Bağlantı Maliyeti | Orta | Orta | 3 |
| 🟡 **Orta** | AI Üretim Tahmini | Orta | Yüksek | 4 |
| 🟡 **Orta** | Glassmorphism UI | Orta | Orta | 7 |
| 🟢 **Düşük** | Gölgeleme Analizi | Düşük-Orta | Yüksek | 3 |
| 🟢 **Düşük** | Uydu Çatı Analizi (CV) | Düşük-Orta | Çok Yüksek | 3 |
| 🟢 **Düşük** | İklim Değişikliği Senaryoları | Düşük | Yüksek | 4 |
| 🟢 **Düşük** | EPİAŞ Arbitraj | Düşük | Orta | 5 |
| 🟢 **Düşük** | MCDM (AHP) | Düşük | Orta | 5 |
| 🟢 **Düşük** | Drone Rota Planlayıcısı | Düşük | Orta | 6 |
| 🟢 **Düşük** | Yüzer GES | Düşük | Düşük | 2 |
| 🟢 **Düşük** | Bakım Takvimi | Düşük | Düşük | 5 |
| ⚪ **Gelecek** | Yatırımcı Vitrini | — | Yüksek | — |
| ⚪ **Gelecek** | 3D Arazi (Cesium) | — | Çok Yüksek | — |

---

## 🏛️ v2.0 MİMARİ ŞEMA

```
┌─────────────────────────────────────────────────────────────┐
│                     FRONTEND (Flutter)                       │
│              Design System v2.0 — Glassmorphism              │
│                                                              │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐    │
│  │Auth    │ │Map +   │ │Report +│ │Scenario│ │AHP     │    │
│  │Screen  │ │3D +    │ │PDF     │ │+ ESS   │ │Wizard  │    │
│  │        │ │Slider  │ │Export  │ │+ Hydro │ │        │    │
│  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘    │
│                          │                                   │
│  ┌───────────────────────┴──────────────────────────────┐   │
│  │              API Service Layer + Redis Cache          │   │
│  └───────────────────────┬──────────────────────────────┘   │
└──────────────────────────┼──────────────────────────────────┘
                           │ REST API
┌──────────────────────────┼──────────────────────────────────┐
│                          ▼                                   │
│                   BACKEND (FastAPI)                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Routers (Genişletilmiş)                   │   │
│  │  pins | users | weather | reports | scenario |        │   │
│  │  optimization | geo | equipments | system |           │   │
│  │  + hydro | + forecast | + grid-connection             │   │
│  └────────────────────┬─────────────────────────────────┘   │
│                       │                                      │
│  ┌────────────────────┴─────────────────────────────────┐   │
│  │              Services (v2.0 Genişletilmiş)            │   │
│  │  solar | wind | grid | geo | interpolation |          │   │
│  │  + hydro | + ai_forecasting | + financial_advanced |  │   │
│  │  + vision | + time_series | collectors                │   │
│  └────────────────────┬─────────────────────────────────┘   │
│                       │                                      │
│  ┌────────────────────┴─────────────────────────────────┐   │
│  │         PostgreSQL + PostGIS + TimescaleDB             │   │
│  │  spatial_data | time_series | users | pins | scenarios│   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
        │                    │
        ▼                    ▼
  ┌──────────┐       ┌──────────────┐
  │  Redis   │       │  Open-Meteo  │
  │  Cache   │       │  + EPİAŞ     │
  └──────────┘       │  + IPCC      │
                     └──────────────┘
```

---

*📌 Bu doküman, `new_features_v2.md` ve `gemini_chats.md` dosyalarındaki tüm fikirler ve konuşmalar tek bir yapıya birleştirilerek oluşturulmuştur.*  
*📌 Mevcut proje dokümantasyonu: [`PROJECT_DOCUMENTATION_1.md`](PROJECT_DOCUMENTATION_1.md) ve [`PROJECT_DOCUMENTATION_2.md`](PROJECT_DOCUMENTATION_2.md)*

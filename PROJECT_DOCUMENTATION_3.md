# SRRP - Proje Dokümantasyonu (Bölüm 3/3)
## Smart Renewable Resource Planner — v2.0 Geçiş Dönemi (Şubat–Nisan 2026)

**📌 Önceki Bölümler:**
- [`PROJECT_DOCUMENTATION_1.md`](PROJECT_DOCUMENTATION_1.md) *(Mimari, Backend, Servisler, Veritabanı)*
- [`PROJECT_DOCUMENTATION_2.md`](PROJECT_DOCUMENTATION_2.md) *(Frontend, Test, Kurulum)*

**📌 Kapsam:** 28 Şubat 2026 → 1 Nisan 2026 arası yapılan tüm değişiklikler
**📌 Son Güncelleme:** 1 Nisan 2026

---

## 13. ALTYAPI DÖNÜŞÜMÜ (Infrastructure Overhaul)

### 13.1 Harita Motoru Geçişi: flutter_map → MapLibre GL JS

Eski sistem Leaflet tabanlı `flutter_map` kullanıyordu. Performans, 3D destek ve vektörel tile ihtiyacı nedeniyle **MapLibre GL JS**'e geçildi.

| Önceki | Sonraki | Neden |
|--------|---------|-------|
| flutter_map (Dart) | MapLibre GL JS (JavaScript) | WebGL performansı, 3D terrain desteği |
| Leaflet raster tiles | Vektörel MVT/PBF tiles | Daha hızlı, interaktif, stil değiştirilebilir |
| Flutter widget harita | JS bridge (index.html) | Canvas kontrolü, custom shader desteği |

**Etkilenen Dosyalar:**
```
frontend/web/index.html          → MapLibre GL JS motor + tüm JS katmanları
frontend/lib/features/map/widgets/
  ├── map_view_maplibre_web.dart  → JS interop (dart:js_util)
  ├── map_view_maplibre_native.dart → Native platform stub
  └── map_view_maplibre_stub.dart   → Conditional import stub
```

**Harita Stilleri (5 seçenek):**
| Stil | Kaynak | Kullanım |
|------|--------|----------|
| Dark Matter | CARTO | Varsayılan (koyu tema) |
| Positron | CARTO | Açık tema |
| Voyager | CARTO | Sokak detaylı |
| Liberty | MapTiler | Detaylı topografya |
| Tema ile Eşitle | Dinamik | Uygulama temasına göre otomatik |

### 13.2 Veritabanı Migrasyonu: 3×SQLite → PostgreSQL + PostGIS

| Önceki | Sonraki |
|--------|---------|
| `system_data.db` (ekipman, hava verisi) | PostgreSQL 16 + PostGIS 3.4 |
| `user_data.db` (kullanıcılar) | Aynı PostgreSQL instance |
| `user_pins_data.db` (pinler) | Aynı PostgreSQL instance |
| Geometry yok | PostGIS ile ST_Contains, ST_DWithin, ST_Distance |

**Bağlantı:** `postgresql://srrp_user:***@localhost:5432/srrp_db`
**ORM:** SQLAlchemy → PostgreSQL dialect

**Tablolar (mevcut):**
| Tablo | Tahmini Boyut | Kayıt |
|-------|---------------|-------|
| hourly_weather_data | ~8.27 GB | ~8.7M satır |
| weather_data | ~937 MB | ~350K satır |
| energy_corridors | ~205 MB | PostGIS geometri |
| hydro_features | ~67 MB | PostGIS geometri |
| equipments | ~KB | Ekipman modelleri |
| users | ~KB | Kullanıcı hesapları |
| pins | ~KB | Kullanıcı pinleri |

### 13.3 Redis Önbellekleme Katmanı

| Parametre | Değer |
|-----------|-------|
| Teknoloji | Redis 7 (Alpine) |
| Bağlantı | `redis://localhost:6379/0` |
| Fallback | In-memory dict (Redis yoksa) |
| Kullanım | Hava durumu cache, choropleth verisi, border GeoJSON |
| TTL | Endpoint'e göre değişken (5dk–1saat) |

### 13.4 Docker Compose Ortamı

```yaml
services:
  srrp_postgres:  # PostgreSQL 16 + PostGIS 3.4
    port: 5432
    volumes: pgdata

  srrp_redis:     # Redis 7 Alpine
    port: 6379
    volumes: redisdata

  srrp_backend:   # FastAPI (Uvicorn)
    port: 8000
    depends_on: [postgres, redis]
```

### 13.5 Vektörel Tile Servisi (MVT/PBF)

| Bileşen | Detay |
|---------|-------|
| Endpoint | `GET /tiles/{z}/{x}/{y}.pbf` |
| Router | `backend/app/routers/tiles.py` |
| Kaynak | PostGIS `energy_corridors` + `hydro_features` tabloları |
| Format | Mapbox Vector Tile (MVT) |
| Kullanım | Enerji nakil hatları, nehir yatakları harita katmanı |

---

## 14. BACKEND GELİŞMELERİ (Şubat–Nisan 2026)

### 14.1 Yeni Router'lar

| Router | Dosya | Açıklama |
|--------|-------|----------|
| **borders** | `borders.py` | İl/ilçe/bölge sınırları GeoJSON servisi |
| **tiles** | `tiles.py` | PostGIS MVT vektörel tile servisi |
| **wind_vectors** | `wind_vectors.py` | Rüzgar vektörleri (canlı akış animasyonu için) |

**Toplam Router Sayısı:** 9 → **12**

### 14.2 Rüzgar Vektörleri Endpoint (Yeni)

```
GET /wind-vectors?dense={true|false}
```

| Parametre | Varsayılan | Açıklama |
|-----------|-----------|----------|
| `dense=false` | 81 nokta | İl merkezi bazlı (eski davranış) |
| `dense=true` | ~1000 nokta | İlçe bazlı yoğun vektör ağı |

**Yardımcı Fonksiyonlar:**
- `_query_city()` → 81 il merkezi sorgusu
- `_query_dense()` → İlçe bazlı ~1000 nokta sorgusu
- `_build_city_result()` / `_build_dense_result()` → GeoJSON builder

### 14.3 Sınır Verileri Endpoint (Yeni)

```
GET /borders/provinces  → 81 il sınırı (GADM TUR-1)
GET /borders/districts  → 957 ilçe sınırı (GADM TUR-2)
GET /borders/regions    → 7 coğrafi bölge
POST /borders/cache/clear → Cache temizleme
```

### 14.4 Hidroelektrik Servisi (Yeni)

| Dosya | Fonksiyon |
|-------|-----------|
| `hydro_service.py` | HES potansiyel hesaplama |
| `seed_hes_equipment.py` | HES ekipman modelleri (Kaplan, Francis, Pelton) |

**Hesaplama:** `P = ρ × g × Q × H × η`
- ρ: Su yoğunluğu (1000 kg/m³)
- g: Yerçekimi (9.81 m/s²)
- Q: Debi (m³/s)
- H: Düşü yüksekliği (m)
- η: Türbin verimi

### 14.5 Gelişmiş Finansal Servis (Yeni)

| Dosya | Metrikler |
|-------|-----------|
| `financial_advanced_service.py` | NPV, ROI, Geri Ödeme Süresi, YEKDEM geliri |

### 14.6 Güncellenmiş Servisler

| Servis | Değişiklik |
|--------|-----------|
| `geo_service.py` | PostGIS sorgularına geçiş, DEM → Elevation API |
| `grid_service.py` | PostgreSQL uyumlu grid hesaplama |
| `interpolation_service.py` | IDW algoritması optimizasyonu |
| `redis_cache.py` | In-memory fallback eklendi |

---

## 15. FRONTEND GELİŞMELERİ (Şubat–Nisan 2026)

### 15.1 Modüler Yapıya Geçiş

Eski `presentation/` yapısı → Yeni `features/` tabanlı modüler yapı:

```
lib/
├── core/
│   ├── constants/         → API URL, uygulama sabitleri
│   ├── network/           → API servisleri (yeni: wind_vector_service.dart)
│   ├── services/          → Çekirdek servisler
│   ├── storage/           → Güvenli depolama
│   ├── theme/             → Tema yönetimi
│   └── utils/             → Yardımcı fonksiyonlar
├── data/
│   ├── models/            → Pin, Scenario, Weather, System modelleri
│   └── turkey_energy_data.dart → Türkiye enerji istatistikleri
├── features/
│   ├── landing/           → Karşılama ekranı (YENİ)
│   │   └── landing_page.dart
│   ├── map/               → Harita modülü (46 dosya)
│   │   ├── dialogs/       → Harita diyalogları
│   │   ├── layers/        → Katman yönetim sistemi
│   │   ├── models/        → Harita veri modelleri
│   │   ├── screens/       → Ana harita ekranı
│   │   ├── viewmodels/    → MapViewModel + LayerMixin
│   │   └── widgets/       → Kontroller, paneller, sidebar
│   └── pins/              → Pin yönetimi (6 dosya)
│       ├── dialogs/       → Ekleme, düzenleme, analiz diyalogları
│       ├── viewmodels/    → Pin diyalog ViewModel
│       └── widgets/       → Ekipman seçici, enerji çıktı widget
└── shared/
    └── widgets/           → Ortak UI bileşenleri
```

### 15.2 Yeni Ekranlar ve Paneller

| Bileşen | Dosya | Açıklama |
|---------|-------|----------|
| **Karşılama Ekranı** | `landing_page.dart` | Vitrin modu, proje tanıtımı |
| **Katmanlar Paneli** | `layers_panel.dart` | 15+ toggle ile katman yönetimi |
| **Dashboard Paneli** | `map_dashboard.dart` | Pin sayıları, kapasite özeti |
| **Önerilen Bölgeler** | `recommendations_panel.dart` | Weibull analizi, şehir detay |
| **Sidebar Sistemi** | `sidebar/` | Modüler veri paneli, pin listesi |

### 15.3 Harita Katmanları (index.html — JavaScript)

Aşağıdaki özellikler Flutter yerine doğrudan JavaScript'te (index.html) implemente edilmiştir. Sebep: MapLibre GL JS'in canvas erişimi ve WebGL performansı.

#### 15.3.1 Rüzgar Parçacıkları v3 (Canlı Akış — Windy Tarzı)

| Parametre | Değer |
|-----------|-------|
| Fonksiyon | `srrpStartWindParticles(geojsonStr)` |
| Grid | 100×50 IDW bilinear interpolasyon |
| Veri Noktaları | ~1000 ilçe bazlı (dense endpoint) |
| Trail Sistemi | Ring buffer (MAX_TRAIL=35), lon/lat depolama |
| Render | `clearRect()` her frame + tam trail yeniden çizim |
| Zoom Adaptif | Parçacık sayısı 600-1500, trail uzunluğu 30-16 |
| Hız | moveFactor=0.00008, speedMul=2.5-6.0 |
| Renk Paleti | Windy stili (koyu mavi → cyan → yeşil → sarı → turuncu → kırmızı) |
| Alpha | Kuadratik fade: `segT * segT * maxAlpha` |
| Sınırlar | 22.0-48.0 lon, 33.0-45.0 lat (Türkiye + tampon) |
| Distance Cutoff | `n0d > 4.0` → Türkiye verisi dışında sıfır hız |

#### 15.3.2 Bulut Örtüsü Katmanı (Cloud Layer)

| Parametre | Değer |
|-----------|-------|
| Fonksiyon | `srrpSetCloudLayer(enable, opacity)` |
| Veri Kaynağı | RainViewer IR Uydu API |
| Tile Format | Raster tile (maxzoom: 8) |
| Güncelleme | Her 10 dakikada otomatik refresh |
| Geçiş | 600ms fade animasyonu |
| Opacity Kontrolü | `srrpSetCloudOpacity(val)` |

#### 15.3.3 İl/İlçe Sınırları

| Parametre | Değer |
|-----------|-------|
| Fonksiyon | `srrpLoadBorderLayers(provUrl, distUrl, regUrl)` |
| İl Sınırları | Her zoomda görünür, `#a0b5c8` renk |
| İlçe Sınırları | zoom ≥ 6'da görünür, `#7a8fa3` renk |
| Çizgi Genişliği | Zoom bazlı interpolasyon |

#### 15.3.4 Choropleth (Isı Haritası) Sistemi

| Parametre | Değer |
|-----------|-------|
| Fonksiyon | `srrpSetChoropleth(mode, dataJson)` |
| Modlar | `solar`, `wind`, `temp`, `none` |
| Renklendirme | MapLibre native interpolate (sürekli gradyan) |
| Veri | İl/ilçe bazlı, backend'den JSON |

#### 15.3.5 Diğer JS Katmanları

| Katman | Fonksiyon | Açıklama |
|--------|-----------|----------|
| 3D Binalar | `srrpSet3DBuildings(enable)` | Extruded building polygonları |
| Projksiyon | `srrpSetGlobe(enable)` | Globe ↔ Mercator geçişi |
| DEM/Yükseklik | `srrpSetDEM(enable)` | Terrain hillshade katmanı |

### 15.4 HES (Hidroelektrik) Pin Desteği

| Bileşen | Durum | Açıklama |
|---------|-------|----------|
| Pin ekleme dialog | ✅ Mevcut | Güneş/Rüzgar/HES sekme seçimi |
| HES ekipman seçici | ⚠️ Sorunlu | "Model bulunamadı" hatası |
| HES pin düzenleme | ⚠️ Sorunlu | Eski yapı kısmen bozuk |
| HES hesaplama | ✅ Mevcut | Backend hydro_service.py aktif |
| HES debi/düşü girişi | ✅ Mevcut | Pin dialog'da ek alanlar |

### 15.5 Wind Vector Service (Yeni — Dart)

```dart
// lib/core/network/wind_vector_service.dart
Future<Map<String, dynamic>> fetchWindVectors({bool dense = true})
// URL: $baseUrl/wind-vectors?dense=$dense
```

---

## 16. KATMAN YÖNETİM SİSTEMİ

### 16.1 Layers Panel Yapısı

Kullanıcının haritada açıp kapatabileceği tüm katmanlar:

| Kategori | Katman | Toggle | Varsayılan |
|----------|--------|--------|-----------|
| **Araçlar** | Önerilen Bölgeler | Tap | Kapalı |
| | İl Modu | Tap | Kapalı |
| | İlçe Modu | Tap | Kapalı |
| | Zaman Simülasyonu | Tap | Kapalı |
| **Harita Stili** | 5 stil seçeneği | Radio | Dark Matter |
| **Projeksiyon** | Global Projeksiyon | Toggle | Kapalı |
| **Isı Haritası** | Güneş Potansiyeli | Tap | Kapalı |
| | Rüzgar Potansiyeli | Tap | Kapalı |
| | Sıcaklık | Tap | Kapalı |
| **Tematik Harita** | Güneş Işınımı | Tap | Kapalı |
| | Rüzgar Hızı | Tap | Kapalı |
| | Sıcaklık | Tap | Kapalı |
| **Uydu Katmanları** | — | Toggle | Kapalı |
| **Rüzgar Parçacıkları** | Canlı Akış | Toggle | Kapalı |
| **3D Efektler** | 3D Türbinler | Toggle | Kapalı |
| | 3D Arazi (DEM) | Toggle | Kapalı |
| **Pin Filtresi** | Güneş / Rüzgar / HES | Segmented | Hepsi |

---

## 17. GÜVENLİK VE KİMLİK DOĞRULAMA

### 17.1 JWT Token Sistemi

| Parametre | Değer |
|-----------|-------|
| Algoritma | HS256 |
| Token Süresi | 43200 dakika (30 gün) |
| Depolama | flutter_secure_storage (mobil), localStorage (web) |
| Refresh | Token yenileme yok (uzun süre) |

### 17.2 Şifre Güvenliği

| Parametre | Değer |
|-----------|-------|
| Hash | Argon2 (passlib) |
| Minimum | Backend'de kontrol |

---

## 18. BİLİNEN SORUNLAR VE HATALAR (1 Nisan 2026)

### 18.1 Aktif Hatalar

| # | Sorun | Önem | Platform | Detay |
|---|-------|------|----------|-------|
| 1 | HES pin düzenleme "Model bulunamadı" | Yüksek | Tümü | Equipment seeding eksik veya bozuk |
| 2 | Rüzgar parçacıkları telefonda çalışmıyor | Yüksek | Mobil | index.html JS → mobil WebView uyumu |
| 3 | Bulut katmanı telefonda çalışmıyor | Orta | Mobil | RainViewer API → mobil WebView |
| 4 | İl sınırları telefonda çalışmıyor | Orta | Mobil | GeoJSON yükleme → mobil WebView |
| 5 | Alt bar (bottom bar) telefonda gözükmüyor | Orta | Mobil | Layout overflow veya z-index |
| 6 | Katmanlar paneli çok büyük (mobil) | Düşük | Mobil | Scroll veya compact mod gerekli |
| 7 | Bulut verisi gecikmeli/eksik (PC) | Düşük | Web | RainViewer API zamanlama farkı |
| 8 | İl-ilçe eşleştirme hataları | Düşük | Tümü | Choropleth'te renksiz ilçeler |
| 9 | Son güncelleme: -541 dk | Düşük | Tümü | Dashboard timestamp hesabı |
| 10 | XXXX.. metin taşması | Düşük | Tümü | Pin ismi çok uzun → overflow |

### 18.2 Bilinen Sınırlamalar

| Sınırlama | Açıklama | Planlanan Çözüm |
|-----------|----------|-----------------|
| Tek kullanıcı limiti yok | Aynı anda sınırsız bağlantı | Rate limiting (Faz 6) |
| Social login yok | Email/şifre veya misafir | Google/Facebook OAuth (gelecek) |
| Sadece Türkiye | Veri ve harita Türkiye sınırlı | Tasarım kararı (değişmeyecek) |
| DEM dosyaları hâlâ diskte | 785 MB kullanılmayan .tif | Faz 1'de silinecek |

---

## 19. COMMIT GEÇMİŞİ ÖZETİ (Şubat–Nisan 2026)

| Tarih | Commit | Açıklama |
|-------|--------|----------|
| Şub 28 | `cd31e9f` | Feature-based modüler yapıya geçiş |
| Şub 28 | `c86716e` | MVT endpoints ve PostGIS config entegrasyonu |
| Mar 01 | `5ae4e75` | Hidroelektrik güncellemesinin ilk adımı |
| Mar 01 | `6497a40` | HES hesaplama ve pin iyileştirmeleri |
| Mar 03 | `2ef9940` | Karşılama ekranı, zaman katmanı, akıllı bölge önerileri |
| Mar 06 | `6dc8eca` | Bug fix güncellemesi |
| Mar 07 | `45e90e8` | Rüzgar parçacık akış katmanı ve yükseklik haritası |
| Mar 08 | `380716b` | Harita hit-test crash düzeltmesi |
| Mar 08 | `0d248be` | Repo temizliği — debug dosyaları kaldırıldı |
| Mar 09 | `645d1a8` | mouse_tracker assertion düzeltmesi |
| Mar 10 | `2eb9eaf` | Önerilen bölgeler paneli + şehir detay grafikleri |
| Mar 11 | `c5b0fea` | Panel entegrasyonu — main.dart güncelleme |
| Mar 12 | `6ab9de5` | tr_TR locale + hata işleyici düzeltmesi |
| Mar 13 | `76ddc08` | Formatter — renk sabitleri yeniden biçimlendi |
| Mar 14 | `98f3365` | PlatformDispatcher crash düzeltmesi |
| Mar 15 | `140c74c` | Dio bağımlılığı kaldırıldı |
| Mar 16 | `1140de8` | Harita + rüzgar parçacığı performans optimizasyonu |
| Mar 17 | `53f4b66` | Katman renk kayması ve zaman widget düzeltmesi |
| Mar 18 | `e349d4b` | Sprint 4 tamamlandı |
| Mar 20 | `53d198f` | Yeni harita özellikleri eklendi |
| Mar 21 | `dade6e0` | MapLibre GL paralel harita motoru eklendi |
| Mar 22 | `f6cb604` | MapLibre 3D harita, il/ilçe navigasyon, pin/heatmap |
| Mar 24 | `925de6c` | Rapor sayfası yenilenmesi başladı |
| Mar 26 | `6ae0596` | Heatmap grid sistemi gerçek verilere dayalı güncelleme |
| Mar 27 | `3d45b64` | MapLibre altyapısına tam geçiş |
| Mar 28 | `76c31b7` | Pine tıklayınca harita etkilenmesi sorunu giderildi |
| Mar 30 | `2a08891` | Vize kısmı tamamlandı, optimizasyon ve UI/UX sırada |

---

## 20. TEKNOLOJİ YIĞINI (Güncel — 1 Nisan 2026)

| Katman | Teknoloji | Versiyon | Değişiklik |
|--------|-----------|----------|-----------|
| **Frontend** | Flutter (Dart) | SDK ^3.8.1 | Değişmedi |
| **Harita** | MapLibre GL JS | 4.x | 🆕 flutter_map'den geçildi |
| **State** | Provider (MVVM) | ^6.1.5 | Değişmedi |
| **Backend** | FastAPI + Uvicorn | 2.1.0 | Değişmedi |
| **Veritabanı** | PostgreSQL 16 + PostGIS 3.4 | 16.x | 🆕 SQLite'dan geçildi |
| **Önbellek** | Redis 7 | 7.x | 🆕 Yeni eklendi |
| **Tile Server** | PostGIS MVT (yerleşik) | — | 🆕 Yeni eklendi |
| **Container** | Docker Compose | v2 | 🆕 Yeni eklendi |
| **Kimlik** | JWT + Argon2 | — | Değişmedi |
| **Veri** | Open-Meteo API | — | Değişmedi |

---

## 21. DOSYA YAPISI ÖZETİ (Backend)

```
backend/
├── app/
│   ├── main.py                    # FastAPI uygulama başlangıcı
│   ├── .env                       # Ortam değişkenleri
│   ├── db/
│   │   ├── database.py            # PostgreSQL bağlantı yönetimi
│   │   ├── models.py              # SQLAlchemy ORM modelleri
│   │   └── crud.py                # CRUD operasyonları
│   ├── routers/                   # 12 API Router
│   │   ├── borders.py             # 🆕 İl/ilçe/bölge sınırları
│   │   ├── equipments.py          # Ekipman CRUD
│   │   ├── geo.py                 # Coğrafi analiz
│   │   ├── optimization.py        # Türbin yerleşim optimizasyonu
│   │   ├── pins.py                # Pin CRUD + analiz
│   │   ├── recommendations.py     # Bölge önerileri
│   │   ├── reports.py             # Raporlama
│   │   ├── scenario.py            # Senaryo yönetimi
│   │   ├── tiles.py               # 🆕 MVT tile servisi
│   │   ├── users.py               # Kullanıcı yönetimi
│   │   ├── weather.py             # Hava durumu
│   │   └── wind_vectors.py        # 🆕 Rüzgar vektörleri
│   └── services/                  # 11 Servis Modülü
│       ├── collectors/            # Veri toplama
│       ├── financial_advanced_service.py  # 🆕 Gelişmiş finansal
│       ├── geo_service.py         # Coğrafi servis (güncellendi)
│       ├── grid_generator.py      # Grid oluşturucu
│       ├── grid_service.py        # Grid yönetimi
│       ├── hourly_weather_helper.py # Saatlik veri yardımcı
│       ├── hydro_service.py       # 🆕 Hidroelektrik hesaplama
│       ├── interpolation_service.py # IDW interpolasyon
│       ├── redis_cache.py         # 🆕 Redis önbellek
│       ├── solar_service.py       # Güneş enerjisi
│       └── wind_service.py        # Rüzgar enerjisi
├── data/                          # Veri dosyaları
│   ├── dem/                       # DEM yükseklik verileri (785 MB)
│   ├── geojson/                   # İl/ilçe sınır dosyaları
│   └── vector/                    # OSM vektör verileri
├── scripts/
│   ├── seed_hes_equipment.py      # 🆕 HES ekipman seeding
│   └── ...                        # Diğer migration/seed scriptleri
└── docker-compose.yml             # 🆕 Container orchestration
```

---

*Bu doküman, Bölüm 1 ve 2'nin devamı olarak Şubat–Nisan 2026 geçiş dönemini kapsar. Proje aktif geliştirme altındadır.*

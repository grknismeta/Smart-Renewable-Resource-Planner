# SRRP — Smart Renewable Resource Planner
### Proje Dokümantasyonu

> **Son güncelleme:** 18 Mart 2026
> Bu dosya projenin tek yaşayan kaynağıdır. Her mimari karar, sprint değişikliği, bilinen sorun ve yol haritası burada tutulur.

---

## İçindekiler

1. [Proje Özeti](#1-proje-özeti)
2. [Teknoloji Yığını](#2-teknoloji-yığını)
3. [Mimari](#3-mimari)
4. [Klasör Yapısı](#4-klasör-yapısı)
5. [Kurulum ve Çalıştırma](#5-kurulum-ve-çalıştırma)
6. [Önemli Mimari Kararlar](#6-önemli-mimari-kararlar)
7. [Sprint Geçmişi](#7-sprint-geçmişi)
8. [Bilinen Sorunlar](#8-bilinen-sorunlar)
9. [Yol Haritası](#9-yol-haritası)

---

## 1. Proje Özeti

SRRP, Türkiye genelinde yenilenebilir enerji kaynaklarının (güneş, rüzgar, hidroelektrik) planlanmasına yardımcı olan bir coğrafi bilgi sistemi uygulamasıdır.

**Temel yetenekler:**
- 81 il ve ~960 ilçe için hava durumu verisi (rüzgar, güneş ışınımı, sıcaklık)
- Harita üzerinde enerji santrali pin yönetimi (konum, kapasite, analiz)
- İl/ilçe/bölge bazlı seçim ve drill-down navigasyon
- Isı haritası ile bölgesel potansiyel görselleştirme
- Raporlar: il bazlı sıralama, istatistik karşılaştırma, PDF export
- MapLibre ile 3D harita modu, raise-on-hover il sınırları

---

## 2. Teknoloji Yığını

| Katman | Teknoloji | Notlar |
|---|---|---|
| **Frontend** | Flutter (Dart) | Web + Native (Android/iOS/Desktop) |
| **Harita (Web)** | MapLibre GL JS | `flutter_maplibre ^0.2.2` paketi |
| **Harita (Native)** | MapLibre Native | Ayrı platform implementasyonu |
| **Basemap** | OpenFreeMap Liberty | `tiles.openfreemap.org/styles/liberty` |
| **Backend** | FastAPI (Python 3.11) | Uvicorn, async |
| **Veritabanı** | PostgreSQL + PostGIS | Coğrafi sorgu ve tile üretimi |
| **ORM** | SQLAlchemy 2.x | Async session |
| **Migration** | Alembic | Versiyonlu şema değişikliği |
| **Tile Server** | Martin | `port 3000`, PostGIS → vector tile |
| **Cache** | Redis + in-memory fallback | Redis yoksa otomatik in-memory devreye girer |
| **Hava Verisi** | Open-Meteo Archive API | 81 il + 929 ilçe, saatlik |
| **İl/İlçe Sınırları** | OSM (Overpass API) | GADM fallback mevcut |
| **State Yönetimi** | Flutter Provider + ViewModel | `safeNotify()` ile güvenli güncelleme |

---

## 3. Mimari

```
┌─────────────────────────────────────────────────┐
│                  Flutter Frontend                │
│                                                 │
│  MapScreen                                      │
│   ├─ MapLibre (Web)  ←── JS Bridge (index.html) │
│   ├─ MapLibre (Native)                          │
│   ├─ MapControls, LayersPanel                   │
│   ├─ ProvinceInfoCard, PinDetailsDialog         │
│   └─ MapViewModel (Provider)                    │
│                                                 │
│  ReportScreen                                   │
│   ├─ ReportStatsRow                             │
│   ├─ ReportRankedList                           │
│   └─ ReportViewModel (Provider)                 │
└──────────────┬──────────────────────────────────┘
               │ HTTP (REST)
┌──────────────▼──────────────────────────────────┐
│                 FastAPI Backend                  │
│                                                 │
│  Routers:                                       │
│   ├─ /weather  → province/district/region özet  │
│   ├─ /reports  → sıralama + skor hesabı         │
│   ├─ /pins     → CRUD                           │
│   ├─ /geo      → borders (OSM/GADM)             │
│   ├─ /borders  → il/ilçe/bölge GeoJSON          │
│   └─ /scenarios, /optimization, /equipments…    │
│                                                 │
│  Services:                                      │
│   ├─ redis_cache.py   (TTL cache)               │
│   ├─ grid_service.py  (ızgara analizi)          │
│   └─ collectors/hourly.py  (veri güncelleme)    │
└──────────────┬──────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────┐
│           PostgreSQL + PostGIS                   │
│                                                 │
│  Tablolar:                                      │
│   ├─ hourly_weather_data   (~10M kayıt)         │
│   ├─ weather_data          (~3M kayıt)          │
│   ├─ pins                                       │
│   ├─ scenarios                                  │
│   └─ users                                      │
└──────────────┬──────────────────────────────────┘
               │ Vector Tile
┌──────────────▼──────────────────────────────────┐
│           Martin Tile Server (port 3000)         │
│  PostGIS → MVT → MapLibre source                │
└─────────────────────────────────────────────────┘
```

### JS Bridge (Web Harita)

Flutter WebView, `index.html` içindeki JS fonksiyonlarını `dart:js` ile çağırır:

| JS Fonksiyonu | Açıklama |
|---|---|
| `srrpSetupRegionMode()` | Bölge seçim katmanını etkinleştirir |
| `srrpSetupProvinceMode(regionFilter)` | İl seçim katmanı; null → tüm 81 il |
| `srrpSetupDistrictMode(provinceName)` | İlçe seçim katmanı; null → tüm ~960 ilçe |
| `srrpUpdatePins(geojsonStr)` | Pin GeoJSON source'unu günceller |
| `srrpUpdateClusterPins(geojsonStr)` | Kümelenmiş pin görünümüne geçer |
| `srrpClearClusterPins()` | Kümelemeyi kapatır, normal pinlere döner |
| `srrpSetHeatmapMode(mode)` | Isı haritasını açar/kapatır (solar/wind/temp) |

---

## 4. Klasör Yapısı

```
smart_renewable_resource_planner/
│
├─ SRRP_DOC.md               ← Bu dosya (tek yaşayan kaynak)
├─ SPRINT_CHANGELOG.md       ← Sprint detayları (test adımları dahil)
├─ martin_config.yaml        ← Martin tile server konfigürasyonu
│
├─ frontend/
│   ├─ lib/
│   │   ├─ core/
│   │   │   ├─ network/       api_client, weather_service, report_service
│   │   │   └─ theme/
│   │   ├─ data/models/       weather_model, pin_model, scenario_model…
│   │   └─ features/
│   │       ├─ map/
│   │       │   ├─ models/    map_models.dart (MapMode, SelectionLevel, MlHeatmapMode, HeatmapPalette)
│   │       │   ├─ viewmodels/ map_viewmodel.dart, map_layer_mixin.dart
│   │       │   ├─ screens/   map_screen.dart
│   │       │   └─ widgets/
│   │       │       ├─ map_view_maplibre_web.dart    ← Web implementasyonu
│   │       │       ├─ map_view_maplibre_native.dart ← Native implementasyonu
│   │       │       ├─ map_view_maplibre_stub.dart   ← Diğer platformlar
│   │       │       ├─ controls/  map_controls.dart
│   │       │       ├─ dialogs/   pin_details_dialog.dart
│   │       │       └─ panels/    layers_panel, province_info_card, time_slider_panel…
│   │       └─ reports/
│   │           ├─ report_screen.dart
│   │           ├─ viewmodels/  report_viewmodel.dart
│   │           └─ widgets/     report_stats_row, report_ranked_list
│   └─ web/
│       └─ index.html          ← MapLibre JS kodu + tüm JS bridge fonksiyonları
│
├─ backend/
│   ├─ app/
│   │   ├─ core/
│   │   │   └─ constants.py   TURKEY_CITIES, REGION_CITIES, CITY_TO_REGION, REGION_ALIASES
│   │   ├─ db/                database.py, models.py, init_db.py
│   │   ├─ routers/           weather, reports, pins, geo, borders, scenarios…
│   │   └─ services/
│   │       ├─ redis_cache.py          TTL cache (Redis + in-memory fallback)
│   │       ├─ grid_service.py
│   │       └─ collectors/
│   │           ├─ hourly.py           Saatlik veri güncelleme + gap detection
│   │           └─ historical.py       Geçmiş veri çekimi
│   ├─ alembic/               DB migration versiyonları
│   ├─ scripts/
│   │   ├─ fix_district_province.py   İlçe/il eşleştirme düzeltmesi
│   │   └─ download_osm_borders.py    OSM sınır indirme
│   └─ turkey_districts.json  İlçe koordinat referans verisi
```

---

## 5. Kurulum ve Çalıştırma

### Backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt

# .env dosyası (örnek):
# DATABASE_URL=postgresql+asyncpg://user:pass@localhost/srrp
# REDIS_URL=redis://localhost:6379

alembic upgrade head           # DB şemasını güncelle
uvicorn app.main:app --reload  # Geliştirme sunucusu (port 8000)
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome          # Web (MapLibre JS bridge aktif)
flutter run -d windows         # Native (MapLibre Native)
```

### Martin Tile Server

```bash
martin --config martin_config.yaml   # port 3000
```

### Veri Toplama (Saatlik Güncelleme)

```bash
cd backend
python -m app.services.collectors.hourly    # Manuel çalıştırma
```

### İlçe/İl Eşleştirme Düzeltmesi

```bash
python scripts/fix_district_province.py --dry-run   # Önce kontrol
python scripts/fix_district_province.py             # Uygula
```

---

## 6. Önemli Mimari Kararlar

### Neden MapLibre? (Leaflet → MapLibre)
Leaflet raster tile tabanlıydı. Vector tile üzerine poligon overlay, 3D bina modu (`fill-extrusion`) ve il sınırı raise-on-hover efekti için MapLibre GL zorunluydu.

### Neden OpenFreeMap? (ArcGIS → OpenFreeMap Liberty)
ArcGIS raster tile üzerine dinamik polygon katmanı eklemek karmaşık ve yavaş. OpenFreeMap vector tile olduğundan MapLibre ile tam uyumlu. ArcGIS URL'leri `map_constants.dart`'ta bırakıldı (fallback olarak).

### Neden PostgreSQL? (SQLite → PostgreSQL)
3 ayrı SQLite dosyası (`system_data.db`, `user_data.db`, `user_pins_data.db`) concurrency sorunları yaratıyordu. PostgreSQL + PostGIS ile tek DB, coğrafi sorgu desteği ve Martin tile server entegrasyonu sağlandı.

### Neden OSM sınırları? (GADM → OSM)
GADM ve OpenFreeMap farklı kaynaklardan geldiğinden il sınırları harita geometrileriyle örtüşmüyordu (Tekirdağ/İstanbul bölgesinde açıkça görülüyordu). OpenFreeMap da OSM verisi kullandığından OSM'den çekilen sınırlar birebir eşleşiyor. GADM kodu `borders.py`'de fallback olarak duruyor.

### Neden In-Memory Cache? (Redis Fallback)
Geliştirme ortamında Redis kurulumunu zorunlu kılmamak için `redis_cache.py`'ye in-memory TTL fallback eklendi. Redis bağlantısı başarısız olursa `_mem_store` dict + `threading.Lock` devreye girer.

### Neden Flat Navigation? (Bölge → İl → İlçe Zorunlu Hiyerarşi)
Önceki tasarımda kullanıcı il seçmek için önce bölge seçmek zorundaydı. Türkiye'de 81 ili düz listelemek ve herhangi bir ilçeye direkt erişmek daha kullanışlı. Bölge filtresi opsiyonel chip olarak korundu.

### Terk Edilenler

| Terk Edilen | Neden |
|---|---|
| `flutter_map` / Leaflet | Vector tile overlay ve 3D efekt yok |
| ArcGIS raster tile'ları | Raster üzerine dinamik overlay zor; kod hâlâ `map_constants.dart`'ta |
| SQLite (3 ayrı DB) | Concurrency sorunu, PostGIS yok |
| GADM sınırları | OSM'den farklı geometri → basemap ile hizasız; `borders.py`'de fallback |
| NASA Power API | Open-Meteo yeterli oldu |
| Canlı saatlik Open-Meteo collector | Veri Colab'da toplu çekildi; `hourly.py` artık gap detection ile çalışıyor |

---

## 7. Sprint Geçmişi

> Ayrıntılar, test adımları ve etkilenen dosyalar için: [`SPRINT_CHANGELOG.md`](SPRINT_CHANGELOG.md)

| Sprint | Konu | Tarih |
|---|---|---|
| **Sprint 1** | Temel düzeltmeler: `province_name → city_name`, normalize karşılaştırma, 82. il filtresi, 13M kayıt PostgreSQL import | Şubat–Mart 2026 |
| **Sprint 2** | Raporlar sekmesi yeniden tasarımı: responsive layout, progress bar'lı sıralama, 4 stat kartı | Mart 2026 |
| **Sprint 3** | İl/İlçe/Bölge modu altyapısı: `SelectionLevel` enum, `ProvinceInfoCard`, bölge/ilçe API endpoint'leri | Mart 2026 |
| **Sprint 3 Ext.** | Düz navigasyon: tüm 81 il veya ~960 ilçeye bölge seçmeden erişim; `_RegionFilterChips` | Mart 2026 |
| **Sprint 4** | Altyapı: in-memory cache fallback, `constants.py` tek kaynak, hourly bucket gap detection, ilçe/il düzeltme scripti | Mart 2026 |
| **Sprint 5** | Pin kümeleme (JS cluster), pin filtreleme paneli, heatmap palet/radius/intensity, "Raporlara Git" butonu | Mart 2026 |

---

## 8. Bilinen Sorunlar

| # | Sorun | Dosya | Durum |
|---|---|---|---|
| 1 | OSM'den çekilen sınır verisi bazen Martin tile'larıyla piksel düzeyinde hizasız kalabiliyor (özellikle kıyı şeridinde) | `borders.py` | İncelenmedi |
| 2 | MapLibre Native'de `fill-extrusion` raise-on-hover efekti web ile birebir aynı değil; pitch animasyonu native'de daha hızlı | `map_view_maplibre_native.dart` | Düşük öncelik |
| 3 | OSM sorgusu 82 il döndürüyor (`_OSM_NON_PROVINCE_NAMES` ile filtreleniyor; KKTC veya başka admin_level=4) | `borders.py` | Geçici çözüm mevcut |
| 4 | `flutter analyze` — `_yr` local variable isim uyarısı (info seviyesi, hata değil) | `map_viewmodel.dart:1369` | Düşük öncelik |

---

## 9. Yol Haritası

### Kısa Vadeli

- [ ] Hata kontrolü ve entegrasyon testi (tüm sprint'ler bittikten sonra)
- [ ] Türkiye bounding box kısıtı — kullanıcı haritayı Türkiye dışına kaydıramamalı
- [ ] Land clip (deniz kırpma) — il/ilçe poligonları kara maskesiyle kesilecek (`ne_10m_land.shp`)
- [ ] Rüzgar partikülleri — animated particle layer (mevcut saatlik rüzgar verisi yeterli)
- [ ] Gece/gündüz harita teması — güneş pozisyonuna göre basemap otomatik değişsin

### Orta Vadeli

- [ ] **ML Projeksiyonu** — LSTM / XGBoost ile enerji üretim tahmini (`scikit-learn` kurulu, veri hazır)
- [ ] **HES (Hidroelektrik) Modülü** — `hydro_service.py` altyapısı
- [ ] LCOE (Levelized Cost of Energy) hesabı
- [ ] Karbon kredisi geliri finansal tabloya eklenmesi
- [ ] DEM ile 3D arazi — `terrain` source (native tarafta kısmen mevcut)

### Uzun Vadeli

- [ ] **AI Chatbot entegrasyonu** *(15 Nisan 2026 sonrasına bırakıldı)*
- [ ] Docker + docker-compose hazırlığı
- [ ] Cloud deployment (VPS / AWS / Railway)
- [ ] Ortam değişkenleri `.env` → secret manager

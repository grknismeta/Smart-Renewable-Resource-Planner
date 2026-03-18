# SRRP — Geliştirme Geçmişi

**Son güncelleme:** 16 Mart 2026

> Bu dosya yaşayan bir belgedir. Her yeni geliştirme, ertelenen karar ve tespit edilen hata buraya eklenir.

---

## Başlangıç Noktası (v1.0 — Ocak/Şubat 2026)

Claude ile çalışmadan önceki durum:

- Flutter + `flutter_map` (Leaflet tabanlı raster tile harita)
- SQLite — 3 ayrı .db dosyası (`system_data.db`, `user_data.db`, `user_pins_data.db`)
- FastAPI backend, 9 router (pins, users, weather, reports, scenarios, optimization, geo, equipments, system)
- Open-Meteo API ile canlı veri çekimi (her istekte API çağrısı)
- İl/ilçe sınırı yok; GIS shapefile sadece `geo_service.py` içinde uygunluk kontrolü için kullanılıyordu
- Harita üzerinde yalnızca pin ve heatmap overlay vardı

---

## Geliştirme Geçmişi (kronolojik)

### Altyapı

- **SQLite → PostgreSQL migrasyonu** yapıldı. 3 parçalı SQLite yapısı tek bir PostgreSQL sunucusuna taşındı. Concurrency sorunu çözüldü, PostGIS desteği kazanıldı.

- **Martin tile server entegrasyonu** eklendi. Hava durumu heatmap tile'ları artık PostGIS üzerinden Martin (port 3000) ile servis ediliyor. Leaflet overlay yerine MapLibre source olarak bağlandı.

- **Alembic migration altyapısı** kuruldu. Şema değişikliklerini versiyonlu takip etmek için.

### Harita Motoru

- **`flutter_map` (Leaflet) → MapLibre GL JS geçişi** yapıldı. `flutter_maplibre` paketi eklendi. Leaflet raster tile sistemi tamamen kaldırıldı.

- **Basemap değişti:** ArcGIS raster tile'ları (dark gray, satellite, street) → **OpenFreeMap Liberty** (`tiles.openfreemap.org/styles/liberty`). Nedeni: vector tile üzerine polygon overlay ve 3D efekt için zorunluydu. ArcGIS tile URL'leri kod içinde (`map_constants.dart`) hâlâ duruyor ama kullanılmıyor.

- **3D bina modu** eklendi. `fill-extrusion` ile `omnt` source-layer'ındaki bina verisi 3 boyutlu gösteriliyor. Source adı (`omnt` / `openmaptiles`) otomatik detect ediliyor.

### İl/İlçe/Bölge Sınırları

- **GADM il sınırları** eklendi. `gadm41_TUR_1.shp` → `geopandas` → `/geo/borders/provinces` endpoint'i → MapLibre source + fill layer.

- **GADM ilçe sınırları** eklendi. `gadm41_TUR_2.shp` → `/geo/borders/districts` endpoint'i.

- **Simplification tolerance düşürüldü:** İl `0.01°` → `0.002°`, ilçe `0.005°` → `0.001°`. Sınır düzgünlüğü artırıldı ama basemap hizalama sorunu devam etti.

- **Sorun tespit edildi:** GADM ve OpenFreeMap geometrileri farklı kaynaklardan geldiği için il sınırları haritanın kendi sınırlarıyla örtüşmüyordu. Tekirdağ/İstanbul bölgesinde açıkça görülüyordu.

- **Karar:** GADM'ı bırak, OSM'den sınır çek. OpenFreeMap da OSM verisi kullandığından geometriler birebir eşleşecek. `download_osm_borders.py` scripti yazıldı.

- **Bölge sınırları** eklendi. `geopandas dissolve` ile 81 il → 7 coğrafi bölge. `/geo/borders/regions` endpoint'i eklendi.

- **OSM sınırları indirildi** (`download_osm_borders.py` çalıştırıldı).
  - `turkey_provinces_osm.geojson` — 82 il (bkz. bilinen sorun #3)
  - `turkey_districts_osm.geojson` — 975 ilçe
  - `borders.py` OSM dosyası varsa otomatik tercih ediyor, yoksa GADM'a geri dönüyor.

- **Script hatası düzeltildi:** `download_osm_borders.py` ilk çalıştırmada `ValueError: Must have equal len keys and value` verdi. `sjoin(predicate="intersects")` sınır ilçelerini birden fazla ile eşleştiriyordu. `~index.duplicated(keep="first")` ile tekilleştirme + indeks bazlı atama ile düzeltildi. Centroid uyarısı için `EPSG:32636`'ya projeksiyon eklendi.

- **Script iyileştirmesi:** Başarılı indirilen dosyalar varsa tekrar indirmeme özelliği eklendi (`--skip-existing` mantığı).

### Seçim Sistemi

- **"Raise on hover" efekti** eklendi. MapLibre `fill-extrusion` layer ile hover'da il/ilçe/bölge 3 boyutlu yükseliyor (8000 m). Görünmesi için kamera pitch=28° yapılıyor.

- **Bölge → İl → İlçe hiyerarşik seçimi** kuruldu. Önceden sadece il seçiliyordu.
  - `SelectionLevel` enum: `none / region / province / district`
  - `_syncSelectionMode` ile ViewModel değişikliği → JS layer otomatik senkronize
  - `ProvinceInfoCard` yeniden yazıldı; bölge/il/ilçe bilgisi + geri butonu eklendi
  - `map_controls.dart` güncellendi: ikon `layers_rounded`, tooltip "Bölge Seç"

- **Hata: Gümüşhane "Diğer" görünüyordu.** GADM NAME_1 ASCII kodlama (`Gumushane`) iken dict Türkçe (`Gümüşhane`). `unicodedata.normalize("NFKD", ...)` ile ASCII-normalize karşılaştırmaya geçildi. Tüm Türkçe karakterli iller artık güvenli eşleşiyor.

- **Hata: İl/ilçe tıklama çalışmıyordu.** `_setupSelectionLayers()` her çağrıldığında `map.on(click/mousemove)` yeni handler ekliyordu, eskiler kaldırılmıyordu. Bölge → İl geçişinde iki handler aynı anda ateşleniyordu. Handler referansları (`_selMousemoveFn`, `_selClickFn`, vb.) module değişkeninde saklanıp `map.off()` ile temizlenerek düzeltildi.

### Veri

- **Open-Meteo Colab notebook** oluşturuldu. 81 il + 929 ilçe için saatlik rüzgar, güneş, sıcaklık, nem verileri Open-Meteo Archive API'den toplu çekildi. 4 adet `.db` dosyası hazır.

### Dokümantasyon

- **`GELISTIRME_GECMISI.md`** (bu dosya) oluşturuldu.

---

## Şu An Kullanılmayanlar ve Neden

| Terk Edilen | Neden |
|---|---|
| `flutter_map` / Leaflet | Vector tile overlay ve 3D efekt desteklemiyor |
| ArcGIS raster tile'ları | Raster tile üzerine polygon overlay zor; OpenFreeMap daha uyumlu |
| SQLite (3 ayrı DB) | Concurrency sorunu, PostGIS desteği yok |
| GADM sınırları | OSM'den farklı geometri → basemap ile hizasız. Kod hâlâ fallback olarak tutuyor |
| `scikit-learn` | Kurulu ama aktif değil; ML projeksiyonu ileriki sprint |
| NASA Power API | Open-Meteo yeterli oldu; kod içinde fallback seçenek olarak anılıyor |
| Canlı Open-Meteo saatlik collector | Veri Colab ile toplu çekildi; import bekliyor |

---

## Bilinen Açık Hatalar

| # | Hata | Dosya | Durum |
|---|------|-------|-------|
| 1 | `/weather/province-summary` endpoint `province_name` kolonu arıyor, tabloda yok (`city_name` olmalı) | `backend/app/routers/weather.py` ~347 | Düzeltilmedi |
| 2 | Flutter `selectedProvinceSummary` getter GADM adı ("Istanbul") ile DB adını ("İstanbul") normalize etmeden karşılaştırıyor; boş sonuç dönebiliyor | `map_viewmodel.dart` | Düzeltilmedi |
| 3 | OSM sorgusu 82 il döndürüyor (Türkiye 81 il). Fazla olan muhtemelen KKTC veya başka bir admin_level=4 relation. Haritada "Diğer" bölgesinde görünebilir | `turkey_provinces_osm.geojson` | İncelenmedi |
| 4 | Hava durumu paneli her zaman "yükleniyor..." gösteriyor. Hata #1'in downstream etkisi | `province_info_card.dart` | Hata #1 düzeltilince çözülecek |

---

## Yapılacaklar

### Sprint 1 — Açık Hatalar ve Eksik Entegrasyon
- [x] `weather.py` `/province-summary`: `province_name` → `city_name` düzeltildi
- [x] Flutter `selectedProvinceSummary`: normalize karşılaştırma eklendi
- [x] 4 `.db` hava verisi dosyasını PostgreSQL'e import et → `merge_to_postgres.py --truncate` ile tamamlandı (16 Mart 2026). `weather_data`: 3,077,932 · `hourly_weather_data`: 9,891,360 · Toplam ~13M kayıt.
- [x] OSM 82. il sorunu düzeltildi — `_OSM_NON_PROVINCE_NAMES = {"Ege"}` filtresi eklendi (`borders.py`)
- [ ] Backend restart et → tüm fixler aktif olsun

### Sprint 2 — Raporlar Sekmesi
- [ ] İl seçilince hava panelinden Raporlar sekmesine navigasyon (province drill-down)
- [ ] İl raporu sayfası: hava istatistikleri + enerji potansiyeli grafikleri + pin özeti
- [ ] Raporlar sekmesinde bölge/il bazlı filtreleme

### Sprint 3 — Veri ve Finans
- [ ] PDF fizibilite raporu export (fl_chart → raster → PDF)
- [ ] LCOE (Levelized Cost of Energy) hesabı ekle
- [ ] Karbon Kredisi geliri finansal tabloya ekle

### Sprint 4 — Harita Görsel İyileştirmeler
- [ ] **Türkiye sınır kısıtı** — Kullanıcı haritayı Türkiye dışına kaydıramamalı. Standart haritadaki bounding box kısıtı da tam doğru değil; her iki harita için de düzgün maxBounds ayarı yapılacak.
- [ ] **Land clip (deniz kırpma)** — İl/ilçe poligonları kara maskesiyle kesilecek; boğaz ve deniz yüzeyleri poligon dışında kalacak. Natural Earth `ne_10m_land.shp` kullanılacak. *(sonraya bırakıldı)*
- [ ] **Rüzgar partikülleri** — Türkiye rüzgar koridorunu animated particle layer ile görselleştir (MapLibre wind layer benzeri). Mevcut saatlik rüzgar verisi yeterli.
- [ ] **ML rüzgar koridoru tespiti** — Saatlik rüzgar verisiyle bölgesel rüzgar koridorları ML ile tespit edilecek (clustering / heatmap). Veri çekildiği için model eğitilebilir.
- [ ] **DEM ile 3D arazi** — Digital Elevation Model verisi ile MapLibre `terrain` source'u aktive et; `fill-extrusion` ile gerçek arazi yüksekliği. `demotiles.maplibre.org` veya Maptiler Terrain kullanılabilir. *(kod altyapısı kısmen mevcut — native tarafta terrain source var)*
- [ ] **Gece/gündüz harita teması** — Güneş pozisyonuna veya kullanıcının yerel saatine göre harita basemap'i otomatik değişsin: gündüz → Liberty (açık/beyaz), gece → dark-matter (koyu/siyah). MapLibre `setStyle()` ile geçiş yapılacak; animasyonlu fade-in/out. Türkiye için eşik saati güneş doğumu/batımı hesaplamasından belirlenecek.

### Sprint 5 — Büyük Özellikler
- [ ] ML projeksiyonu (LSTM / XGBoost) — veri ve `scikit-learn` hazır
- [ ] AI Chatbot entegrasyonu *(15 Nisan sonrasına bırakıldı)*
- [ ] Redis cache katmanı (özellikle hava verisi endpoint'leri)
- [ ] Time Slider simülasyonu (24 saatlik hava animasyonu haritada)
- [ ] HES (Hidroelektrik) modülü — `hydro_service.py`

### Sprint 6 — Deployment
- [ ] Docker + docker-compose hazırlığı
- [ ] Cloud deployment (VPS / AWS / Railway)
- [ ] Ortam değişkenleri `.env` → secret manager

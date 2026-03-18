# SRRP — Sprint Değişiklik Günlüğü

> **Proje:** Smart Renewable Resource Planner
> **Son güncelleme:** 17 Mart 2026
> **Test politikası:** Hata kontrolleri tüm sprintler bittikten sonra yapılacak.

---

## Sprint 1 — Temel Düzeltmeler

### Yapılan Değişiklikler

#### Fix 1-2: Zaman Dilimi Validasyonu (`time_slider_panel.dart`)
- **Önce:** Geçersiz tarih aralığı girince hiçbir şey olmuyordu.
- **Sonra:** Bitiş tarihi başlangıçtan önce seçilirse kırmızı hata mesajı görünüyor.
- "Yükle" butonu hata varken **disabled** (gri, tıklanamaz) hale geliyor.
- Hata mesajı anlık olarak güncelleniyor (onChange).

#### Fix 3-4: Diğer Temel Düzeltmeler
- Önceki sprintlerde tamamlanmıştı; sprint başında onaylandı.

### Etkilenen Dosyalar
| Dosya | Değişiklik |
|---|---|
| `frontend/lib/features/map/widgets/panels/time_slider_panel.dart` | Validasyon hata mesajı + disabled buton |

### Test Adımları
1. **Zaman dilimi validasyonu:**
   - Harita ekranını aç → Sol alt "Zaman Simülasyonu" butonuna tıkla
   - Bitiş tarihini başlangıç tarihinden **önce** ayarla
   - → Kırmızı hata metni görünmeli, "Yükle" butonu gri/disabled olmalı
   - Tarihi düzelt → hata kaybolmalı, buton aktifleşmeli

---

## Sprint 2 — Raporlar Sekmesi Yeniden Tasarımı

### Yapılan Değişiklikler

#### Yeni Dosya: `report_stats_row.dart`
4 özet istatistik kartı içeren yatay şerit:
- **En İyi Lokasyon** — en yüksek skora sahip şehir
- **Ortalama Puan** — tüm lokasyonların ortalaması
- **Bölge/Lokasyon Sayısı** — listedeki toplam kayıt
- **Maksimum Puan** — en yüksek ham skor

#### Yeni Dosya: `report_ranked_list.dart`
Eski `report_list_panel.dart`'ın yerine geçen sıralama paneli:
- Her satırda **renkli ilerleme çubuğu** (kırmızı→yeşil, `Color.lerp`)
- **Sıra rozeti** — ilk 3'e altın/gümüş/bronz rozet
- Değer + skor yan yana gösterim
- Tıklanınca haritada odaklanma (`onSiteSelected`)

#### Tam Yeniden Yazım: `report_screen.dart`
- **Geniş ekran (>900 px):** Harita solda %55 + bilgi paneli sağda %45 (yan yana `Row`)
- **Dar ekran (<900 px):** 3 sekmeli `TabBarView` (Harita | Sıralama | İstatistikler)
- Tab sıralanma listesinden seçilince harita sekmesine otomatik geçiş
- **Türkiye Enerji Paneli akordeon:** Varsayılan kapalı, açılır/kapanır (260 px yükseklik)
- **İl filtre chip'i:** Aktif il filtresi varsa üstte chip + X butonu
- PDF dışa aktarım aynı mantıkla korundu, yeniden düzenlendi
- `LayoutBuilder` ile tamamen responsive

### Etkilenen Dosyalar
| Dosya | Değişiklik |
|---|---|
| `frontend/lib/features/reports/widgets/report_stats_row.dart` | **YENİ** — 4 stat kartı |
| `frontend/lib/features/reports/widgets/report_ranked_list.dart` | **YENİ** — progress bar'lı sıralama |
| `frontend/lib/features/reports/report_screen.dart` | **TAM YENİDEN YAZIM** — responsive layout |

### Test Adımları
1. **Geniş ekran testi:**
   - Tarayıcı penceresini >900 px yap → Raporlar sekmesine geç
   - → Harita sol tarafta, bilgi paneli sağ tarafta görünmeli
   - → Stat kartları (4 adet) üstte görünmeli
   - → Sıralama listesinde renkli progress bar'lar olmalı (kötü = kırmızı, iyi = yeşil)
   - → İlk 3 sıraya altın/gümüş/bronz rozet olmalı

2. **Dar ekran testi:**
   - Tarayıcı penceresini <900 px yap
   - → Harita | Sıralama | İstatistikler sekmeli görünüm çıkmalı
   - Sıralama sekmesinde bir kayda tıkla → Harita sekmesine otomatik geçmeli, marker odaklanmalı

3. **Türkiye Enerji Paneli:**
   - Raporlar > sağ panel → "Türkiye Enerji Özeti" başlığına tıkla
   - → Açılır/kapanır olmalı

4. **İl filtresi:**
   - Harita > bir il seç → Raporlar sekmesine git
   - → Üstte ilçe filtre chip'i görünmeli
   - X'e basınca filtre kalkmalı

5. **PDF dışa aktarım:**
   - Raporlar → PDF butonu → PDF indirilmeli

---

## Sprint 3 — İl/İlçe/Bölge Modu Altyapısı

### Yapılan Değişiklikler

#### Backend: Yeni API Endpoint'leri (`backend/app/routers/weather.py`)

**`GET /weather/district-summary?province={il}&hours={n}`**
- Belirtilen ile ait tüm ilçelerin hava durumu ortalamasını döner
- Response: `DistrictSummary[]` (districtName, provinceName, lat, lon, avgWindSpeed, avgRadiation, avgTemperature, recordCount)

**`GET /weather/region-summary?hours={n}`**
- Türkiye'nin 7 coğrafi bölgesinin il bazlı hava durumu ortalamasını döner
- Response: `RegionSummary[]` (regionName, provinceCount, avgWindSpeed, avgRadiation, avgTemperature)

#### Flutter: Yeni Modeller (`weather_model.dart`)
- `DistrictSummary` — ilçe seviyesi hava verisi modeli
- `RegionSummary` — bölge seviyesi hava verisi modeli

#### Flutter: Yeni Servis Metodları (`weather_service.dart`)
- `fetchDistrictSummary(province, hours)` — ilçe endpoint'ini çağırır
- `fetchRegionSummary(hours)` — bölge endpoint'ini çağırır

#### Flutter: ViewModel Güncellemeleri (`map_viewmodel.dart`)
- `_districtSummaries`, `_regionSummaries` state alanları eklendi
- `loadDistrictSummaries(province)` — bir il seçilince otomatik tetiklenir
- `loadRegionSummaries()` — coğrafi mod açılınca otomatik tetiklenir
- `selectedDistrictSummary` getter — normalize isim eşleşmesiyle seçili ilçenin verisini döner

#### Flutter: ProvinceInfoCard Güncelleme (`province_info_card.dart`)
- `districtSummary` parametresi eklendi
- İlçe seçiliyse → Rüzgar (m/s) + Işınım (W/m²) + Sıcaklık (°C) istatistik chip'leri gösterilir
- `MapScreen`'den `mapViewModel.selectedDistrictSummary` geçiliyor

### Etkilenen Dosyalar
| Dosya | Değişiklik |
|---|---|
| `backend/app/routers/weather.py` | `DistrictSummary` + `RegionSummary` schema + 2 yeni endpoint |
| `frontend/lib/data/models/weather_model.dart` | `DistrictSummary` + `RegionSummary` modeli |
| `frontend/lib/core/network/weather_service.dart` | 2 yeni fetch metodu |
| `frontend/lib/features/map/viewmodels/map_viewmodel.dart` | Yeni state/getter/load metodları |
| `frontend/lib/features/map/widgets/panels/province_info_card.dart` | `districtSummary` parametresi + istatistik chip'leri |
| `frontend/lib/features/map/screens/map_screen.dart` | `districtSummary` prop'u geçirildi |

### Test Adımları
1. **İlçe verisi yükleme:**
   - Harita > İl Modu aç → herhangi bir ile tıkla
   - → İl bilgi kartı açılmalı, alt kısımda "İlçe verileri yükleniyor..." spinner görünmeli
   - İlçe seviyesinde bir ilçeye tıkla
   - → Bilgi kartında ilçe için Rüzgar/Işınım/Sıcaklık chip'leri görünmeli

2. **Bölge verisi:**
   - Backend çalışırken `GET /weather/region-summary` endpoint'i 200 döndürmeli
   - `GET /weather/district-summary?province=İstanbul` → İstanbul ilçelerini döndürmeli

---

## Sprint 3 Extension — Düz Navigasyon Modu (Flat Navigation)

### Motivasyon
Önceden Bölge → İl → İlçe zorunlu hiyerarşisi vardı.
Artık direkt tüm 81 ile veya tüm ~960 ilçeye erişilebilir; bölge filtresi **opsiyonel**.

### Yapılan Değişiklikler

#### JS: `srrpSetupDistrictMode` Güncelleme (`frontend/web/index.html`)
- **Önce:** `provinceName` zorunlu, boş geçince hata
- **Sonra:** `null/""` geçince tüm Türkiye ilçeleri gösterilir
  ```javascript
  // null → hitFilter yok → tüm ilçeler tıklanabilir
  var hitFilter = provinceName ? ['==', ['get', 'NAME_1'], provinceName] : null;
  ```

#### Dart JS Binding (`map_view_maplibre_web.dart`)
- `_jsSetupDistrictMode(String)` → `_jsSetupDistrictMode(String?)` (nullable)
- `_lastRegionName` / `_lastProvinceName` tracker'ları eklendi
- `_onVmChanged`: seviye değişmese bile bölge/il filtresi değişince JS katmanı güncellenir
  ```dart
  // Aynı seviyede filtre değişince de JS güncelleniyor
  || (regionChanged   && vm.selectionLevel == SelectionLevel.province)
  || (provinceChanged && vm.selectionLevel == SelectionLevel.district)
  ```

#### ViewModel Yeni Metodlar (`map_viewmodel.dart`)

| Metod | Açıklama |
|---|---|
| `openProvincesMode()` | Tüm 81 ili gösterir; tekrar basınca kapatır |
| `openDistrictsMode()` | Tüm ~960 ilçeyi gösterir; tekrar basınca kapatır |
| `closeSelectionMode()` | Tüm coğrafi seçim modunu kapatır |
| `clearRegionFilter()` | Bölge filtresini kaldırır, il listesine döner |
| `toggleProvinceMode()` | `openProvincesMode()`'a yönlendirildi (geriye uyumluluk) |

**Düzeltilen metodlar:**
- `clearSelectedProvince()` → artık bölge listesine değil, **il listesine** döner
- `clearSelectedRegion()` → `clearRegionFilter()` delegasyonu
- `clearAllSelection()` → mod aktifken **il seviyesine** döner (önceden bölge seviyesine dönüyordu)

**Yeni getter'lar:**
```dart
bool get isProvincesModeActive  // İl modu aktif mi?
bool get isDistrictsModeActive  // İlçe modu aktif mi? (il filtresi yok)
```

#### Harita Kontrol Butonları (`map_controls.dart`)
- Eski "Bölge Seç" butonu **kaldırıldı**
- **İl Modu butonu** — `Icons.apartment_rounded`, aktifken teal renk
- **İlçe Modu butonu** — `Icons.grid_view_rounded`, aktifken turuncu renk

#### Bölge Filtre Şeridi (`map_screen.dart` → `_RegionFilterChips`)
İl modu aktifken haritanın üstünde çıkan yatay kaydırmalı chip listesi:
- 7 Türkiye bölgesi gösterilir: Marmara, Ege, Akdeniz, İç Anadolu, Karadeniz, Doğu Anadolu, Güneydoğu Anadolu
- Bir bölgeye basınca sadece o bölgenin illeri JS katmanında aktif olur
- Seçili bölgede "Tümü" chip'i çıkar → basınca filtre kalkar
- İl seçilince (ilçe seviyesine geçilince) şerit otomatik gizlenir

### Etkilenen Dosyalar
| Dosya | Değişiklik |
|---|---|
| `frontend/web/index.html` | `srrpSetupDistrictMode` null/empty desteği |
| `frontend/lib/features/map/widgets/map_view_maplibre_web.dart` | Nullable binding + region/province change tracker |
| `frontend/lib/features/map/viewmodels/map_viewmodel.dart` | Yeni mod metodları + getter'lar + fix'ler |
| `frontend/lib/features/map/widgets/controls/map_controls.dart` | İl + İlçe Modu butonları |
| `frontend/lib/features/map/screens/map_screen.dart` | Yeni callback'ler + `_RegionFilterChips` widget |

### Test Adımları

#### İl Modu (Tüm 81 İl)
1. Harita ekranı → sağ üstte **İl Modu** butonuna (`apartment` ikonu) tıkla
2. → Buton teal renk olmalı; tüm Türkiye illeri haritada tıklanabilir olmalı
3. → Haritanın üstünde 7 bölge chip'i görünmeli (Bölge Filtre Şeridi)
4. Herhangi bir ile tıkla → il bilgi kartı açılmalı; ilçe görünümüne geçmeli
5. Geri butona bas → il listesine dönmeli (bölge listesine değil)
6. Tekrar **İl Modu** butonuna bas → mod kapanmalı, chip'ler ve renkli buton kaybolmalı

#### Bölge Filtresi (Opsiyonel)
1. İl modu aktifken → üstteki chip'lerden **"Ege"** seç
2. → Sadece Ege bölgesi illeri tıklanabilir olmalı; chip teal renkte seçili görünmeli
3. **"Tümü"** chip'ine bas → filtre kalkmalı, tüm iller tekrar aktif olmalı
4. Seçili chip'e tekrar bas → aynı filtre kalkma davranışı

#### İlçe Modu (Tüm ~960 İlçe)
1. Harita ekranı → **İlçe Modu** butonuna (`grid_view` ikonu) tıkla
2. → Buton turuncu renk olmalı; tüm Türkiye ilçeleri tıklanabilir olmalı
3. → Bölge filtre şeridi **görünmemeli** (ilçe modunda bölge filtresi yok)
4. Herhangi bir ilçeye tıkla → ilçe bilgi kartı (il seçmeden) açılmalı
5. Tekrar **İlçe Modu** butonuna bas → mod kapanmalı

#### İl → İlçe Drill-Down (Klasik Hiyerarşi Hâlâ Çalışıyor mu?)
1. İl Modu → Bir ile tıkla → O ilin ilçeleri görünmeli
2. Bir ilçeye tıkla → İlçe verisi (Rüzgar/Işınım/Sıcaklık) kart açılmalı
3. Geri → ilçe listesine dön; Geri → il listesine dön

#### Kapat ve Temizle
1. İki moddan birini aç → "X" (Kapat) butonuna bas → her şey temizlenmeli, `SelectionLevel.none`
2. MapLibre 3D modunda da aynı testler çalışmalı

---

## Genel Durum

### `flutter analyze` Sonucu
```
3 issues found (info seviyesi — hata/uyarı yok)
- _yr local variable naming (map_viewmodel.dart)
- print() in test_nan.dart (×2)
```
> Tüm sprint değişiklikleri hata üretmedi.

---

## Sprint 4 — Altyapı

### 4.1 — API Response Cache

#### `backend/app/services/redis_cache.py`
- **In-memory TTL cache** eklendi (`_mem_store` dict + `Lock`): Redis yoksa otomatik devreye girer
- `cache_get` / `cache_set` → Redis başarısız olsa bile in-memory fallback'e yazar
- `cache_delete` / `cache_delete_pattern` / `cache_flush` → her iki katmanı da temizler
- Artık Redis olmadan da cache çalışır (geliştirme ortamında Redis kurulumuna gerek yok)

#### `backend/app/routers/weather.py`
Cache eklenen endpoint'ler:
| Endpoint | Cache Key | TTL |
|---|---|---|
| `GET /weather/province-summary?hours=N` | `weather:province-summary:{hours}` | 30 dak |
| `GET /weather/district-summary?province=X&hours=N` | `weather:district-summary:{province}:{hours}` | 15 dak |
| `GET /weather/region-summary?hours=N` | `weather:region-summary:{hours}` | 30 dak |

### 4.2 — Backend Temizliği

#### `backend/app/core/constants.py`
- `REGION_CITIES`, `CITY_TO_REGION`, `REGION_ALIASES` sözlükleri **buraya taşındı**
- Artık tek kaynak (tek truth): tüm router'lar buradan import eder
- `List` tip import'u eklendi

#### `backend/app/routers/reports.py`
- `REGION_CITIES`, `CITY_TO_REGION`, `REGION_ALIASES` tanımları **kaldırıldı**
- `constants.py`'den import ediliyor (3 satır → 1 satır)

#### `backend/app/routers/weather.py`
- `CITY_TO_REGION` için fonksiyon içi `from app.routers.reports import ...` kaldırıldı
- Dosya başında `from app.core.constants import CITY_TO_REGION` eklendi
- `from collections import defaultdict` zaten dosya başındaydı, `get_region_summary` içindeki tekrar kaldırıldı

### 4.3 — Hourly.py Dinamik Gap Detection

**Önceki sorun:** Pass 2 (yakın boşluk) tüm şehirler için aynı `past_days` değerini kullanıyordu — en uzun boşluktaki şehre göre. Günlük 1-2 saatlik boşluğu olan şehirler de 30 günlük veri çekiyordu.

**Yeni yaklaşım:** Şehirler boşluk büyüklüğüne göre bucket'lara ayrılır:
| Boşluk (gün) | past_days değeri |
|---|---|
| ≤ 1 | 1 |
| 2–7 | 7 |
| 8–30 | 30 |
| 31–92 | 92 (max) |

Her bucket için ayrı API çağrısı yapılır → güncel şehirler yalnızca 1 günlük veri çeker.

#### Değişen Dosya
`backend/app/services/collectors/hourly.py`:
- `from collections import defaultdict` import eklendi (dosya başına)
- Pass 2 bloğu yeniden yazıldı: `bucket_map = defaultdict(list)` ile şehirler gruplandı
- Her bucket için `_fetch_batch_with_retry` ayrı ayrı çağrılıyor

### 4.4 — İlçe/İl Eşleştirme Düzeltmesi

**Sorun:** Overpass API bounding box sorguları bazı ilçeleri yanlış ile atıyordu:
- Antakya → "Adana" kaydedilmiş, "Hatay" olmalı
- Payas → "Adana", "Hatay" olmalı
- Andırın → "Adana", "Kahramanmaraş" olmalı

**Çözüm:** `backend/scripts/fix_district_province.py` (**YENİ**)
- `TURKEY_CITIES` verisiyle doğru il atamasını içeren lookup tablosu oluşturur
- Aynı isimli ilçelerin birden fazla ilde olduğu **ambiguous** durumlar tespit edilir ve atlanır
- `--dry-run` modunda değişiklikleri gösterir ama DB'ye yazmaz
- `--province X` ile sadece belirli bir ilin kayıtları kontrol edilebilir

**Çalıştırma:**
```bash
# Önce dry-run ile kontrol et
python scripts/fix_district_province.py --dry-run

# Sadece Adana ilini düzelt
python scripts/fix_district_province.py --province Adana

# Tüm yanlış atamaları düzelt
python scripts/fix_district_province.py
```

### Etkilenen Dosyalar
| Dosya | Değişiklik |
|---|---|
| `backend/app/services/redis_cache.py` | In-memory TTL fallback cache |
| `backend/app/core/constants.py` | REGION_CITIES + CITY_TO_REGION + REGION_ALIASES eklendi |
| `backend/app/routers/weather.py` | Cache uygulaması + CITY_TO_REGION import düzeltmesi |
| `backend/app/routers/reports.py` | Tekrar kod temizliği (constants.py'den import) |
| `backend/app/services/collectors/hourly.py` | Per-bucket gap detection |
| `backend/scripts/fix_district_province.py` | **YENİ** — ilçe/il düzeltme scripti |

### Test Adımları

#### Cache Testi
1. Backend başlat → `/weather/province-summary` endpoint'ini 2 kez çağır
2. → İlk çağrıda DB sorgusu çalışmalı (log: "Cache MISS")
3. → İkinci çağrıda cache'den dönmeli (log: "Cache HIT"), belirgin şekilde daha hızlı
4. `/weather/region-summary` ve `/weather/district-summary?province=İstanbul` için aynı test

#### Backend Temizliği Testi
1. `reports.py` ve `weather.py`'de `CITY_TO_REGION` kullanımı çalışıyor mu?
2. `python -m py_compile app/routers/reports.py app/routers/weather.py` → hata yok

#### Gap Detection Testi
1. DB'de 1-2 şehrin timestamp'ini geriye çek (simülasyon)
2. `python -m app.services.collectors.hourly` çalıştır
3. Log'da bucket gruplandırmasını gör:
   `[Pass 2] past_days=1: X şehir` ve `[Pass 2] past_days=7: Y şehir` gibi

#### İlçe Düzeltme Testi
```bash
python scripts/fix_district_province.py --dry-run
# → Yanlış il ataması olan ilçeleri listeler
python scripts/fix_district_province.py --province Adana
# → Adana iline ait yanlış kayıtları düzeltir
```

---

## Genel Durum

### `flutter analyze` Sonucu (Sprint 3 Extension sonrası)
```
3 issues found (info seviyesi — hata/uyarı yok)
```

### Backend Syntax
```
ALL OK — py_compile tüm Sprint 4 dosyalarını hatasız geçti
```

### Sıradaki Sprintler
- **Sprint 6+** — AI Chatbot (15 Nisan 2026 sonrası), ML Projeksiyonu

---

## Sprint 5 — Pin Sistemi + Heatmap İyileştirmeleri

### 5.1 — Pin Kümeleme (Clustering)

MapLibre'nin yerleşik cluster özelliği JS shim üzerinden kullanılır.

#### `frontend/web/index.html`
İki yeni JS fonksiyonu:

| Fonksiyon | Açıklama |
|---|---|
| `srrpUpdateClusterPins(geojsonStr)` | Flutter pin layer'larını gizler; cluster GeoJSON source + 3 layer (çember, sayı, tekil pin) ekler |
| `srrpClearClusterPins()` | Cluster layer/source kaldırır, Flutter pin layer'larını tekrar gösterir |

Cluster davranışı:
- `clusterMaxZoom: 10` — zoom ≥ 10'da pinler ayrı ayrı gösterilir
- `clusterRadius: 60` — 60px içindeki pinler gruplandırılır
- Küçük küme (< 5) → Teal `#4ECDC4`, orta (5–15) → Sarı `#FFD93D`, büyük (≥15) → Kırmızı `#FF6B6B`

#### `frontend/lib/features/map/widgets/map_view_maplibre_web.dart`
- `@JS` interop: `_jsUpdateClusterPins()` + `_jsClusterPinsClear()` eklendi
- `_syncPins(pins, is3D, cluster)` — 3. parametre eklendi
- Clustering açıksa → JS cluster source güncellenir, Flutter source güncellenmez
- Clustering kapatılınca → `_jsClusterPinsClear()` çağrılır, Flutter pin layer'ları geri görünür
- `_lastClustering` cache değişkeni eklendi (stil sıfırlamada da temizlenir)

#### `frontend/lib/features/map/viewmodels/map_viewmodel.dart`
- `_showPinClusters` (bool, default: false) state alanı
- `showPinClusters` getter
- `togglePinClustering()` metodu

#### `frontend/lib/features/map/widgets/panels/layers_panel.dart`
- "Pin Kümeleme" toggle satırı (`bubble_chart` ikonu, teal renk, `JS` badge) eklendi

---

### 5.2 — Pin Filtreleme Paneli

#### `frontend/lib/features/map/viewmodels/map_viewmodel.dart`
- `_pinTypeFilter` (Set<String>) — aktif tür filtreleri
- `_pinMinCapacityMw` (double?) — minimum kapasite filtresi (şimdilik UI'da kullanılmıyor)
- **`filteredPins` getter** — filtre yoksa `_pins` döner, filtreleme varsa Where() sonucunu döner
- `hasPinFilter` getter — herhangi bir filtre aktif mi?
- `togglePinTypeFilter(type)` — bir türü filtreden ekler/çıkarır
- `setPinMinCapacity(v)` — kapasite alt sınırı
- `clearPinFilter()` — tüm filtreleri sıfırlar

#### `frontend/lib/features/map/widgets/panels/layers_panel.dart`
Pin Filtresi bölümü (`_pinFilterSection()`):
- 3 tür butonu: Güneş Paneli, Rüzgar Türbini, HES
- Aktif filtreler renkli highlight gösterir
- En az bir filtre aktifken "Filtreyi Temizle" linki görünür

#### `frontend/lib/features/map/widgets/map_view_maplibre_web.dart`
- `_syncPins()` → `vm.filteredPins` kullanır (önceden `vm.pins`)
- `_onMapClick()` → `vm.filteredPins` ile tıklanabilir pinleri kontrol eder
- `_handlePinHoverJs()` → hover kartı için `filteredPins` içinde arar

---

### 5.3 — Pin Detay Kartı İyileştirmesi

#### `frontend/lib/features/map/widgets/dialogs/pin_details_dialog.dart`
- `import report_screen.dart` eklendi
- **Analiz varsa** → "Raporlara Git" yeşil butonu, action butonlarının üstüne eklendi
  - Tıklayınca dialog kapanır → `ReportScreen` push navigation
  - Renk: `Colors.green`, border: `Colors.greenAccent`

---

### 5.4–5.6 — Heatmap Kontrolleri (Renk Paleti, Yarıçap, Yoğunluk)

#### `frontend/lib/features/map/models/map_models.dart`
`HeatmapPalette` enum eklendi:

| Palet | Display | Açıklama |
|---|---|---|
| `classic` | Klasik | Her metrik için farklı renk skalası (orijinal) |
| `thermal` | Termal | Siyah → Mor → Kırmızı → Sarı → Beyaz (termal kamera) |
| `viridis` | Viridis | Mor → Mavi → Teal → Yeşil → Sarı (bilimsel) |

`HeatmapPaletteExt` extension: `displayName` + `icon` getter'ları.

#### `frontend/lib/features/map/viewmodels/map_viewmodel.dart`
Yeni state alanları:
- `_heatmapRadius` (double, 10–100, default: 40)
- `_heatmapIntensity` (double, 0.2–5.0, default: 1.0)
- `_heatmapPalette` (HeatmapPalette, default: classic)

Getter'lar + setter'lar:
- `heatmapRadius` / `setHeatmapRadius(v)` → clamp(10, 100)
- `heatmapIntensity` / `setHeatmapIntensity(v)` → clamp(0.2, 5.0)
- `heatmapPalette` / `setHeatmapPalette(p)`

`HeatmapPalette` export'a eklendi.

#### `frontend/lib/features/map/widgets/map_view_maplibre_web.dart`
- `const` heatmap paint tanımları **kaldırıldı**
- Yerlerine dinamik fonksiyon: `_buildHeatmapPaint(mode, radius, intensity, palette)` + `_heatmapColorRamp(mode, palette)`
- `_syncHeatmapMode(mode, radius, intensity, palette)` — parametreli hale getirildi
- `_lastRadius`, `_lastIntensity`, `_lastPalette` cache değişkenleri eklendi
- Parametre değişince (`paramsChanged`) mevcut heatmap layer kaldırılıp yeniden eklenir
- `_syncAll()` → `vm.heatmapRadius`, `vm.heatmapIntensity`, `vm.heatmapPalette` geçiriyor

#### `frontend/lib/features/map/widgets/panels/layers_panel.dart`
Isı haritası aktifken `_heatmapControls(context)` bölümü gösterilir:
- **Yarıçap Slider** — 10–100, turuncu renk, anlık değer etiketi
- **Yoğunluk Slider** — 0.2–5.0, cyan renk, anlık değer etiketi
- **Palet Seçimi** — 3 buton (Klasik / Termal / Viridis), aktif olan highlight

---

### Etkilenen Dosyalar
| Dosya | Değişiklik |
|---|---|
| `frontend/web/index.html` | `srrpUpdateClusterPins` + `srrpClearClusterPins` JS fonksiyonları |
| `frontend/lib/features/map/models/map_models.dart` | `HeatmapPalette` enum + `HeatmapPaletteExt` |
| `frontend/lib/features/map/viewmodels/map_viewmodel.dart` | Clustering toggle, pin filter, heatmap param state/setter'lar |
| `frontend/lib/features/map/widgets/map_view_maplibre_web.dart` | Cluster interop, dinamik heatmap paint, filteredPins kullanımı |
| `frontend/lib/features/map/widgets/panels/layers_panel.dart` | Cluster toggle, pin filter UI, heatmap controls UI |
| `frontend/lib/features/map/widgets/dialogs/pin_details_dialog.dart` | "Raporlara Git" butonu |

---

### Test Adımları

#### 5.1 — Pin Kümeleme
1. MapLibre 3D moduna geç → Katmanlar paneli → "Pin Filtresi" bölümü → **"Pin Kümeleme"** toggle'ı aç
2. → Haritada yakın pinler yuvarlak küme balonu olarak görünmeli (sayı etiketiyle)
3. → Küçük kümeler teal, büyük kümeler kırmızı renkte olmalı
4. Haritayı yakınlaştır (zoom 10+) → Pinler ayrı ayrı görünmeli
5. Toggle'ı kapat → Normal pin görünümüne dönmeli

#### 5.2 — Pin Filtreleme
1. Katmanlar paneli → "Pin Filtresi" bölümü → **"Güneş"** butonuna tıkla
2. → Haritada sadece güneş paneli pinleri kalmalı, rüzgar/HES pinleri kaybolmalı
3. Güneş + Rüzgar ikisini seç → Her iki tür görünmeli
4. "Filtreyi Temizle" linkine bas → Tüm pinler tekrar görünmeli

#### 5.3 — Pin Detay Kartı
1. Analiz verisi olan bir pine tıkla → Pin detay diyaloğu açılsın
2. → "Raporlara Git" yeşil butonu en üstte görünmeli
3. Butona tıkla → Diyalog kapanmalı, Raporlar sayfası açılmalı

#### 5.4–5.6 — Heatmap Kontrolleri
1. MapLibre 3D → Katmanlar paneli → **"Güneş Potansiyeli"** heatmap seç
2. → Panel içinde Yarıçap + Yoğunluk slider'ları + Palet butonları görünmeli
3. Yarıçap slider'ını artır → Heatmap daireleri büyümeli
4. Yoğunluk slider'ını artır → Heatmap daha belirgin / yoğun görünmeli
5. **"Termal"** paletine geç → Renk skalası siyah→mor→kırmızı→sarı olmalı
6. **"Viridis"** paletine geç → Mor→teal→sarı-yeşil renk skalası görünmeli
7. Heatmap modu kapat (toggle) → Kontroller gizlenmeli

---

## Genel Durum

### `flutter analyze` Sonucu (Sprint 5 sonrası)
```
1 issue found (info seviyesi — hata/uyarı yok)
- _yr local variable naming (map_viewmodel.dart:1369) — önceden var
```

### Backend
Sprint 5'te backend değişikliği yapılmadı.

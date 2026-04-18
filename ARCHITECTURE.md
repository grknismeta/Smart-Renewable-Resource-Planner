# SRRP Architecture Reference

> Bu dosya Claude Code oturumlarında token tasarrufu ve hata önleme için referans olarak kullanılır.
> Kod değişikliği yapmadan ÖNCE bu dosyayı oku.

---

## 1. Proje Yapısı (Özet)

```
backend/                          # FastAPI (Python 3.11)
  app/
    routers/                      # REST endpoint'leri
      weather.py      (1200+ satır) — choropleth, collector-status, hava verileri
      pins.py                     — pin CRUD + analiz
      wind_vectors.py             — rüzgar vektör endpoint'i
      borders.py                  — il/ilçe GeoJSON sınırları
      geo.py                      — coğrafi uygunluk kontrolü
    db/models.py                  — SQLAlchemy modelleri (User DB + System DB)
    core/constants.py             — TURKEY_CITIES (900+ ilçe), plaka kodları
    services/                     — solar_service, wind_service, hydro_service
    hourly_collector.py           — arka plan veri toplayıcı (scheduler)

frontend/                         # Flutter Web (Dart)
  web/index.html    (2300+ satır) — MapLibre GL JS interop katmanı (harita motoru)
  lib/
    main.dart                     — Provider setup, routing
    core/
      network/api_client.dart     — BaseService (dinamik URL: Uri.base.host)
      theme/theme_view_model.dart — Karanlık/aydınlık tema
    features/
      map/                        — ANA MODÜL (aşağıda detaylı)
      pins/                       — Pin ekleme/düzenleme dialog'ları ve viewmodel
      scenarios/                  — Senaryo yönetimi
      reports/                    — Raporlama
      landing/                    — Giriş sayfası
      auth/                       — Kimlik doğrulama
```

---

## 2. Harita Modülü (En Kritik)

### Widget Hiyerarşisi

```
MapScreen (map_screen.dart — 600+ satır)
  └─ Scaffold > Stack
       ├─ [0] MapViewMapLibre          — HtmlElementView (platform view)
       │    └─ Stack
       │         ├─ ml.MapLibreMap     — maplibre paketinin widget'ı
       │         ├─ Pin hover card     — Positioned(bottom:80, left:20)
       │         ├─ Pin info card      — Positioned(bottom:24)
       │         └─ Loading overlay
       │
       ├─ [1..N] Positioned widget'lar — HEPSI Positioned OLMALI (aşağıya bak)
       │    ├─ MapDashboard            — Positioned(top:20, left:20)
       │    ├─ MapControlButton'lar    — Positioned(top:20, right:20)
       │    ├─ LayersPanel             — Positioned(top:90, right:20)
       │    ├─ Legend widget'ları       — Positioned(bottom:40, ...)
       │    ├─ ZoomButtons             — AnimatedPositioned(bottom:40, left:20)
       │    ├─ MapBottomSheet          — non-positioned (DraggableScrollableSheet)
       │    ├─ PlacementIndicator      — Positioned(bottom:22%)
       │    ├─ ProvinceInfoCard        — Positioned(bottom:100, left:20)
       │    ├─ RecommendationsPanel    — AnimatedPositioned(right)
       │    ├─ ScenarioSidePanel       — AnimatedPositioned(left)
       │    └─ ScenarioMiniReport      — Positioned(bottom:180, right:20)
       │
       └─ MapBottomSheet              — DraggableScrollableSheet (mobil sidebar)
```

### ⚠️ KRİTİK KURAL: Stack + Platform View + Touch

**Flutter Web'de `HtmlElementView` (platform view) dokunma olaylarını yakalar.**

1. Ana Stack'e eklenen **non-positioned** çocuklar parent boyutunu kaplar
2. Bu görünmez katman haritanın üstüne oturur ve **tüm touch olaylarını engeller**
3. Bu yüzden harita üstündeki her UI elemanı **mutlaka `Positioned` ile sarılmalı**
4. Her `Positioned` çocuğu **`PointerInterceptor`** ile sarılmalı (mobilde touch geçişi için)

**YAPMA:**
```dart
// ❌ Stack çocuğu olarak non-positioned widget — touch'ı engeller!
Stack(children: [
  MapViewMapLibre(),
  MapOverlays(),      // ← Bu Stack döndürüyor, tüm alanı kaplayıp touch engeller
  MapControls(),      // ← Aynı sorun
])
```

**YAP:**
```dart
// ✅ Her UI elemanı Positioned + PointerInterceptor
Stack(children: [
  MapViewMapLibre(),
  Positioned(top: 20, left: 20, child: PointerInterceptor(child: Dashboard())),
  Positioned(top: 20, right: 20, child: PointerInterceptor(child: Buttons())),
])
```

**İstisna:** `DraggableScrollableSheet` kendi içinde positioning yapar, non-positioned kalabilir.

---

## 3. Flutter ↔ JavaScript Interop

```
Dart (map_view_maplibre_web.dart)          JS (index.html)
─────────────────────────────              ─────────────────
@JS('window.srrpSetGlobe')         →      window.srrpSetGlobe = function(enable) { ... }
@JS('window.srrpSetPinHoverFn')    →      window.srrpSetPinHoverFn = function(fn) { ... }
@JS('window.srrpStartWindParticles')→     window.srrpStartWindParticles = function(data) { ... }
@JS('window.srrpSetCloudLayer')    →      window.srrpSetCloudLayer = function(show, opacity) { ... }
@JS('window.srrpApplyChoropleth')  →      window.srrpApplyChoropleth = function(mode, data) { ... }
@JS('window.srrpSetBaseStyle')     →      window.srrpSetBaseStyle = function(url) { ... }
```

**KURAL:** Harita katmanları (heatmap, choropleth, rüzgar, bulut, sınırlar, pinler) tamamen JS tarafında yönetilir. Dart sadece `window.srrpXxx()` fonksiyonlarını çağırır.

### index.html İç Yapısı (2300+ satır)

| Satır Aralığı | İçerik |
|---|---|
| 1-60 | HTML head, MapLibre GL JS/CSS yükleme |
| 60-160 | Pin hover/click callback'leri |
| 160-250 | Harita border (il/ilçe sınırları) yükleme |
| 250-480 | Base style yönetimi, projeksiyon |
| 480-650 | Rüzgar canvas (parçacık animasyonu) |
| 650-900 | Harita olay yönetimi, globe modu |
| 900-1400 | Heatmap, choropleth, 3D terrain/buildings |
| 1400-1600 | Bulut katmanı (RainViewer API) |
| 1600-2100 | İl/ilçe seçim modu, benzersiz renklendirme |
| 2100-2362 | Script yükleme, hazırlık fonksiyonları |

---

## 4. Veri Akışı

### Pin Türleri — İsimlendirme Uyumsuzluğu

| Katman | Güneş | Rüzgar | HES |
|---|---|---|---|
| UI (Dart display) | `Güneş Paneli` | `Rüzgar Türbini` | `HES` |
| Backend API (type) | `Güneş Paneli` | `Rüzgar Türbini` | `Hidroelektrik` |
| Equipment query | `Solar` | `Wind` | `Hydro` |

Dönüşüm: `pin_dialog_viewmodel.dart` → `backendType`, `_backendEquipmentType`, `toDisplayType()`

### Choropleth Veri Eşleştirme

```
Backend DB (city_name)  →  _tr_ascii()  →  _PROVINCE_ALIAS  →  _DISTRICT_ALIAS  →  GeoJSON lookup
"K. Maras"              →  "k. maras"   →  "kahramanmaras"   →  (match)          →  "Kahramanmaraş|..."
```

Normalizasyon zinciri `weather.py` satır 1030-1210'da.

### API URL'leri (Dinamik)

```dart
// api_client.dart
static String get webApiBase => 'http://${Uri.base.host}:8000';
// Telefonda 192.168.x.x:8000, PC'de localhost:8000
```

**YAPMA:** Hardcoded `127.0.0.1` veya `localhost` kullanma. Telefon erişemez.

---

## 5. State Yönetimi

```
Provider
  ├─ ThemeViewModel          — tema (dark/light)
  ├─ AuthViewModel           — JWT auth, kullanıcı bilgisi
  ├─ MapViewModel            — harita state (1700+ satır)
  │    ├─ MapLayerMixin      — katman toggle'ları (wind, cloud, heatmap, choropleth)
  │    ├─ Globe state        — _preGlobeState ile save/restore
  │    ├─ Selection state    — il/ilçe/bölge seçimi
  │    └─ Pin state          — pin CRUD, placement mode
  ├─ ScenarioViewModel       — senaryo yönetimi
  └─ ApiService              — tüm HTTP servisleri (weather, pins, geo, ...)
```

### Globe Mode Save/Restore

Globe açılınca `_preGlobeState` Map'e kaydedilen özellikler:
`heatmapMode, windParticles, cloudLayer, terrain, buildings, selectionLevel, provinceModeActive, turbines, choroplethMode, animationMode, recommendationsOpen`

Globe kapanınca hepsi geri yüklenir. **Globe modda Türkiye özellikleri devre dışıdır.**

---

## 6. Web vs Native (Mobil Android/iOS) Mimari Farkları

### Conditional Export Mekanizması
```
map_view_maplibre.dart (barrel)
  ├─ dart.library.js_interop → map_view_maplibre_web.dart  (JS interop)
  └─ dart.library.io         → map_view_maplibre_native.dart (MapLibre Flutter SDK)
```

Aynı `MapViewMapLibre` sınıf adı, farklı implementasyonlar. Static metotlar (flyTo, zoomIn, setMaxBounds vs.) her iki dosyada da var.

### Özellik Eşdeğerlik Tablosu

| Özellik | Web Çözümü | Native Çözümü |
|---|---|---|
| Türkiye sınırı | JS `map.setMaxBounds()` | `MapOptions(maxBounds: LngLatBounds(...))` |
| Globe modu | JS `map.setProjection('globe')` | `maxBounds: null` + `pitch: 45` + `minZoom: 1.5` (widget rebuild) |
| İl/ilçe seçimi | JS `queryRenderedFeatures` (click) | `MapEventLongClick` + backend `/geo/city?lat=&lon=` |
| Pin kümeleme | JS MapLibre cluster source | Flutter-level grid-based clustering (`_clusterPins()`) |
| Rüzgar parçacıkları | JS Canvas 2D animasyon | Flutter `CustomPainter + Ticker` overlay (`WindParticleOverlay`) |
| Bulut katmanı | JS raster layer (RainViewer) | Native `RasterSource` + `RasterStyleLayer` (RainViewer) |
| 3D Terrain | JS `setTerrain()` + DEM tiles | `RasterDemSource` + `HillshadeStyleLayer` (görsel) |
| 3D Buildings | JS `fill-extrusion` layer | Desteklenmiyor (SDK sınırı) |
| MapLibre logosu | CSS `display:none` | Logo widget kaldırıldı |

### Native-Specific Dosyalar
- `map_view_maplibre_native.dart` — Tüm native harita mantığı
- `wind_particle_overlay.dart` — Rüzgar CustomPainter overlay (sadece native'de aktif)

### Native Pin Kümeleme Detayı
SDK'nın `GeoJsonSource`'u cluster parametresi **expose etmiyor** (maplibre-0.2.2).
Flutter seviyesinde grid-based clustering: `_clusterPins(pins, zoom)` → zoom'a göre grid boyutu hesaplar, yakın pinleri gruplar.
- Cluster'lar ayrı `_clusterSourceId` GeoJSON source'unda
- Tekil pinler ana `_pinsSourceId`'de kalır
- `MapEventCameraIdle` ile zoom değişiminde yeniden hesaplanır

### Native İl/İlçe Seçim Detayı
SDK'nın `queryLayers()` sadece layerId/sourceId döndürür, feature property (il adı) vermez.
Bu yüzden backend reverse geocoding kullanılır:
1. Kullanıcı haritada tek tıklama yapar → `MapEventClick` → `_selectGeoAtPoint()`
2. Koordinat backend'e gönderilir: `GET /geo/city?lat=...&lon=...`
3. Backend `{province, district}` döndürür
4. ViewModel'de `selectProvince()` veya `selectDistrict()` çağrılır
5. Kamera ilin centroidine animasyonla uçar (`_flyToProvinceCentroid()`)

### Native GeoJSON Asset'leri (Gömülü Sınır Verileri)
İl/ilçe sınır GeoJSON'ları **frontend asset olarak gömülüdür** — backend bağımsız, offline çalışır:
- `assets/geo/turkey_provinces.json` — 82 il, ~434 KB (0.005° simplified)
- `assets/geo/turkey_districts.json` — 975 ilçe, ~1.4 MB (0.005° simplified)
- `rootBundle.loadString()` ile yüklenir, `_cachedProvincesGeoJson`/`_cachedDistrictsGeoJson` static cache'e atılır
- Choropleth katmanı da aynı cache'i kullanır
- **NOT:** Reverse geocoding (`/geo/city`) hâlâ backend'e bağımlıdır (nokta-poligon analizi gerektirir)

| Özellik | Desktop (Chrome) | Mobil (Telefon Chrome / Native) |
|---|---|---|
| Harita kontrolü | Mouse + scroll | Touch gesture |
| Sidebar | Sol kenar çubuğu | Alt DraggableScrollableSheet |
| Touch iletimi | Mouse event → HtmlElementView sorunsuz | Touch → PointerInterceptor ZORUNLU |
| API URL (web) | localhost:8000 | {host-ip}:8000 (Uri.base.host) |
| API URL (native) | — | `127.0.0.1:8000` (adb reverse) veya LAN IP |
| Wind görselleştirme | JS Canvas 2D | Flutter CustomPainter |
| DPI | 1x | devicePixelRatio (2x-3x) |
| Layers panel height | maxHeight: 0.80 | maxHeight: 0.60 |
| Bottom sheet | minChildSize: 0.03 | minChildSize: 0.05 |
| İl/ilçe seçimi | Tek tıklama (JS feature query) | Tek tıklama (backend reverse geocoding) |
| Sınır GeoJSON | Backend'den HTTP fetch | Asset'ten yükleme (offline çalışır) |
| Bölge chip'leri | `top: 8` | Dikey: `top: 125` (dashboard altı), Yatay: `top: 20, left: 260` |

---

## 7. Bilinen Tuzaklar

### 7.1 mouse_tracker Assertion (web)
MapLibre paketi `HtmlElementView`'ı `Stack` içine koyuyor. Style değişiminde `KeyedSubtree` key değişince widget yeniden oluşturuluyor ve kısa süre 0x0 boyutta kalıyor. **Debug modda** yüzlerce `"Cannot hit test a render box with no size"` hatası verir. **Fonksiyonel bir sorun değil**, sadece debug noise.

### 7.2 PointerInterceptor Gerekliliği
`pointer_interceptor: ^0.10.1+2` paketi, Flutter Web'de platform view üzerindeki widget'ların dokunma almasını sağlar. **Her harita üstü widget'ı `PointerInterceptor` ile sar.**

### 7.3 RainViewer Bulut Katmanı Gecikmesi
RainViewer IR uydu verisi 15-30 dk gecikmeli gelir. Bu API sınırlamasıdır, düzeltilemez.

### 7.4 Collector Status Negatif Değer
`minutes_ago` hesabında timezone uyumsuzluğu varsa negatif değer çıkabilir. Backend'de `max(0, ...)` koruması var.

---

## 8. Dosya Değişikliği Kontrol Listesi

Bir widget değişikliği yapmadan önce:

- [ ] Widget, ana Stack'te **Positioned** mı? (Bölüm 2 kuralı)
- [ ] `PointerInterceptor` ile sarılı mı?
- [ ] Mobilde test gereken bir şey mi? (URL, canvas, DPI, touch)
- [ ] Pin türü dönüşümü gerekiyor mu? (Bölüm 4 tablosu)
- [ ] `flutter analyze` sıfır hata mı?

JS (index.html) değişikliği yapmadan önce:

- [ ] `window._srrpMap` null kontrolü var mı?
- [ ] Katman/source eklenmeden önce var mı kontrolü yapılıyor mu?
- [ ] Console.log ile diagnostic eklendi mi?

Backend değişikliği yapmadan önce:

- [ ] Redis cache invalidation gerekiyor mu?
- [ ] DB migration gerekiyor mu?
- [ ] TURKEY_CITIES ile uyumlu mu?

# SRRP - Proje Dokümantasyonu (Bölüm 2/2)
## Smart Renewable Resource Planner — Frontend, Test ve Kurulum

**📌 Önceki Bölüm:** [`PROJECT_DOCUMENTATION_1.md`](PROJECT_DOCUMENTATION_1.md) *(Mimari, Backend, Servisler, Veritabanı)*

---

## 7. FRONTEND MİMARİSİ (Flutter + MVVM)

### 7.1 Genel Yapı

Frontend, **MVVM (Model-View-ViewModel)** deseni ve **Provider** state yönetimi ile inşa edilmiştir.

```
lib/
├── main.dart                          # Uygulama giriş noktası
├── core/                              # Çekirdek servisler ve yardımcılar
│   ├── constants.dart                 # API URL, uygulama sabitleri
│   ├── core.dart                      # Barrel export
│   ├── secure_storage_service.dart    # JWT token güvenli depolama
│   ├── api_services/                  # Backend ile iletişim katmanı
│   │   ├── api_service.dart           # Ana API servis (facade)
│   │   ├── auth_service.dart          # Kimlik doğrulama API
│   │   ├── base_service.dart          # HTTP istekleri temel sınıfı
│   │   ├── equipment_service.dart     # Ekipman CRUD
│   │   ├── geo_service.dart           # Coğrafi analiz API
│   │   ├── optimization_service.dart  # Optimizasyon API
│   │   ├── report_service.dart        # Raporlama API
│   │   ├── resource_service.dart      # Kaynak (Pin) API
│   │   ├── scenario_service.dart      # Senaryo API
│   │   ├── system_service.dart        # Sistem sağlık kontrolü
│   │   └── weather_service.dart       # Hava durumu API
│   ├── base/
│   │   └── base_view_model.dart       # ViewModel temel sınıfı
│   └── utils/
│       ├── format_utils.dart          # Sayı/tarih formatlama
│       └── map_utils.dart             # Harita yardımcı fonksiyonları
├── data/
│   └── models/                        # Veri modelleri (DTO)
│       ├── models.dart                # Barrel export
│       ├── pin_model.dart             # Pin, PinAnalysis, OptimizationResponse
│       ├── scenario_model.dart        # Scenario modeli
│       ├── system_data_models.dart    # RegionalSite, GridAnalysis, Equipment
│       └── weather_model.dart         # Saatlik hava durumu modeli
└── presentation/
    ├── screens/                       # Bağımsız ekranlar
    │   ├── auth_screen.dart           # Giriş/Kayıt ekranı
    │   ├── report_screen.dart         # Raporlama ekranı
    │   └── splash_screen.dart         # Açılış/yükleme ekranı
    ├── features/                      # Özellik bazlı modüller
    │   ├── map/                       # Harita modülü (ana ekran)
    │   ├── pins/                      # Pin yönetimi
    │   └── scenario/                  # Senaryo modülü
    ├── viewmodels/                    # Paylaşılan ViewModel'lar
    │   ├── auth_view_model.dart
    │   ├── report_view_model.dart
    │   └── theme_view_model.dart
    └── widgets/                       # Paylaşılan widget'lar
        ├── common/                    # Ortak UI bileşenleri
        └── report/                    # Rapor widget'ları
```

### 7.2 Provider (State Yönetimi) Hiyerarşisi

Uygulama başlatma sırasında oluşturulan Provider'lar:

```dart
MultiProvider(
  providers: [
    Provider<ApiService>,                    // HTTP servis
    ChangeNotifierProvider<ThemeViewModel>,   // Tema (açık/koyu mod)
    ChangeNotifierProvider<AuthViewModel>,    // Kimlik doğrulama state
    ChangeNotifierProvider<ReportViewModel>,  // Rapor state
    ChangeNotifierProvider<ScenarioViewModel>,// Senaryo state
    ChangeNotifierProxyProvider<AuthViewModel, MapViewModel>, // Harita state
  ],
)
```

### 7.3 Navigasyon Yapısı

```
SplashScreen (Başlangıç)
    │
    ├── isLoggedIn == null  → SplashScreen (Yükleniyor)
    ├── isLoggedIn == true  → MapScreen (Ana Ekran)
    └── isLoggedIn == false → AuthScreen (Giriş)

Named Routes:
  /auth       → AuthScreen
  /map        → MapScreen
  /reports    → ReportScreen
  /scenarios  → ScenarioScreen
```

---

## 8. FRONTEND EKRANLARI VE ÖZELLİKLERİ

### 8.1 Auth Screen (Kimlik Doğrulama)

| Özellik | Detay |
|---------|-------|
| **Giriş Modu** | Email + Şifre ile oturum açma |
| **Kayıt Modu** | Yeni hesap oluşturma (toggle ile geçiş) |
| **Misafir Modu** | Hesap olmadan devam etme seçeneği |
| **UI Tasarımı** | Glassmorphism efektli input alanları, arka planda harita tile gösterimi |
| **Token Saklama** | `flutter_secure_storage` ile güvenli JWT depolama |
| **Tam Ekran** | Immersive Sticky modu ile tam ekran deneyim |

### 8.2 Map Screen (Ana Harita Ekranı)

Uygulamanın **merkezî** ekranı. Tüm temel özellikler bu ekran üzerinden erişilir.

#### 8.2.1 Harita Katmanları

| Katman | Açıklama | Görselleştirme |
|--------|----------|----------------|
| **Temel Harita** | OpenStreetMap tile'ları | Leaflet tiles |
| **Pin Katmanı** | Kullanıcının eklediği güneş/rüzgar pinleri | Marker icon'ları |
| **Irradiance Katmanı** | Güneş ışınım yoğunluk haritası | Renk gradyanı overlay |
| **Temperature Katmanı** | Sıcaklık dağılım haritası | Renk gradyanı overlay |
| **Wind Katmanı** | Rüzgar hızı dağılım haritası | Renk gradyanı overlay |
| **Grid Katmanı** | Enerji potansiyel grid verileri | Puanlı marker'lar |
| **Optimizasyon Katmanı** | Türbin yerleşim sonuçları | Mavi rüzgar icon'ları |
| **Seçim Bölgesi** | Optimizasyon için alan seçimi | Yarı şeffaf mavi dikdörtgen |

#### 8.2.2 Etkileşim Modları

```
Normal Mod
  └── Haritaya tıklama → Geo Uygunluk Kontrolü + Pin Ekleme Dialog

Bölge Seçim Modu
  ├── 1. Tıklama → Sol-üst köşe belirleme
  ├── 2. Tıklama → Sağ-alt köşe belirleme
  └── "Hesapla" → Optimizasyon Dialog'u açılır
```

#### 8.2.3 Sidebar (Yan Panel)

Sol kenardan açılan veri paneli:

| Panel | İçerik |
|-------|--------|
| **Header** | Uygulama logosu, kullanıcı bilgisi |
| **Pins Panel** | Kullanıcının pinlerinin listesi (düzenle/sil) |
| **Data Panel** | Seçili pin'in detaylı analiz verileri |
| **Scenario Button** | Senaryo ekranına geçiş |
| **Footer** | Raporlar, Çıkış butonları |

#### 8.2.4 Harita Kontrolleri

| Kontrol | Açıklama |
|---------|----------|
| **Zoom +/-** | Yakınlaştırma/uzaklaştırma butonları |
| **Katman Paneli** | Solar/Wind/Temperature katman açma/kapama |
| **Bölge Seçimi** | Optimizasyon alanı seçme modu |
| **Hesapla Butonu** | Seçilen alan için optimizasyon başlatma |
| **Time Slider** | Zaman dilimine göre veri görüntüleme |
| **Legend (Lejant)** | Aktif katmanların renk skalası |
| **Resource Action Buttons** | Güneş/Rüzgar kaynak türü seçimi |

#### 8.2.5 Pin İşlemleri

| İşlem | Süreç |
|-------|-------|
| **Pin Ekleme** | Haritaya tıkla → Geo uygunluk kontrolü → Dialog'da detayları gir → Kaydet |
| **Pin Analizi** | Pin oluşturulunca otomatik analiz (solar/wind/financial) → Sonuçlar kaydedilir |
| **Pin Düzenleme** | Sidebar'dan pin seç → Düzenle dialog'u → Güncelle |
| **Pin Silme** | Sidebar'dan pin seç → Sil → Cascade delete (analiz + senaryolar) |

### 8.3 Report Screen (Raporlama Ekranı)

| Özellik | Detay |
|---------|-------|
| **Bölge Filtresi** | 7 coğrafi bölge + "Tümü" seçimi (dropdown) |
| **Tür Filtresi** | Solar / Wind seçimi |
| **Zaman Aralığı** | Yıllık / Aylık / Anlık seçimi |
| **Sıralama** | Potansiyel skora göre en iyiden en kötüye |
| **Harita Görünümü** | Raporlanan noktaların harita üzerinde gösterimi |
| **Focused Site** | Listeden tıklanan bölgeye haritada zoom |
| **Senaryo Raporu** | Senaryo sonuçlarını harita + panel ile gösterim |

#### Rapor Widget'ları:
- **`ReportListPanel`** — Sıralı bölgesel site listesi (kart görünümü)
- **`ReportMap`** — Raporlanan sitelerin harita üzerinde gösterimi
- **`ScenarioMapInReport`** — Senaryo sonuç haritası
- **`ScenarioResultPanel`** — Senaryo detay sonuç paneli

### 8.4 Scenario Screen (Senaryo Ekranı)

| Özellik | Detay |
|---------|-------|
| **Senaryo Oluşturma** | İsim, açıklama ve pin seçimi ile yeni senaryo |
| **Çoklu Pin Desteği** | Bir senaryoya birden fazla pin eklenebilir |
| **Pin Ekleme** | Mevcut senaryoya pin ekleme |
| **Senaryo Hesaplama** | Seçilen pinler için birleşik enerji + finansal analiz |
| **Sonuç Görüntüleme** | Detaylı senaryo sonuç dialog'u |
| **Senaryo Kartları** | Her senaryo ayrı bir kart olarak listelenir |

#### Senaryo Widget'ları:
- **`ScenarioCreateDialog`** — Yeni senaryo oluşturma dialog'u
- **`ScenarioDetailDialog`** — Senaryo detay ve sonuç görüntüleme
- **`ScenarioCard`** — Senaryo listesindeki kart bileşeni

### 8.5 Splash Screen

Uygulama açılırken gösterilen yükleme ekranı. `AuthViewModel` token kontrolü tamamlanana kadar görüntülenir.

---

## 9. ORTAK WİDGET'LAR

### 9.1 Common Widgets

| Widget | Dosya | Açıklama |
|--------|-------|----------|
| `AppBackground` | `app_background.dart` | Uygulama arka plan dekorasyonu |
| `GlassContainer` | `glass_container.dart` | Glassmorphism efektli konteyner |
| `CustomAppBar` | `custom_app_bar.dart` | Özelleştirilmiş üst çubuk |
| `CommonWidgets` | `common_widgets.dart` | Paylaşılan küçük bileşenler |
| `StateWidgets` | `state_widgets.dart` | Loading, Error, Empty state gösterimleri |
| `ThemedInputs` | `themed_inputs.dart` | Tema uyumlu form input'ları |

### 9.2 Map-Specific Widgets

| Widget | Dosya | Açıklama |
|--------|-------|----------|
| `MapView` | `map_view.dart` | Ana harita görünümü (FlutterMap wrapper) |
| `MapOverlays` | `map_overlays.dart` | Harita üstü bilgi panelleri |
| `MapControls` | `map_controls.dart` | Zoom, katman kontrolleri |
| `MapMarkers` | `map_markers.dart` | Pin ve türbin marker'ları |
| `MapLegend` | `map_legend.dart` | Renk skalası lejantı |
| `MapDashboard` | `map_dashboard.dart` | Harita durum göstergesi |
| `MapLayersSystem` | `map_layers_system.dart` | Tüm harita katmanı mantığı |
| `LayersPanel` | `layers_panel.dart` | Katman açma/kapama paneli |
| `EnergyOutputWidget` | `energy_output_widget.dart` | Enerji çıktısı göstergesi |
| `SelectionIndicators` | `selection_indicators.dart` | Bölge seçim durumu |
| `OptimizationButtons` | `optimization_buttons.dart` | Optimizasyon aksiyon butonları |
| `TimeSliderWidget` | `time_slider_widget.dart` | Zaman slider'ı |
| `ResourceActionButtons` | `resource_action_buttons.dart` | Kaynak türü seçim butonları |
| `PinEditDialog` | `pin_edit_dialog.dart` | Pin düzenleme dialog'u |
| `EquipmentSelectorWidget` | `equipment_selector_widget.dart` | Ekipman seçici widget |

---

## 10. VERİ MODELLERİ (Frontend)

### 10.1 Pin Modeli (`pin_model.dart`)

```dart
class Pin {
  int id;
  String title;
  double latitude, longitude;
  String type;  // "Güneş Paneli" | "Rüzgar Türbini"
  double capacityMw;
  double? panelArea;
  int? equipmentId;
  String? equipmentName;
  Map<String, dynamic>? analysis;
}

class OptimizedWindPoint {
  double latitude, longitude;
  double windSpeedMs;
  double annualProductionKwh;
  double score;
}

class OptimizationResponse {
  double totalCapacityMw;
  double totalAnnualProductionKwh;
  int turbineCount;
  List<OptimizedWindPoint> points;
}
```

### 10.2 Senaryo Modeli (`scenario_model.dart`)

```dart
class Scenario {
  int id;
  String name;
  String? description;
  List<int> pinIds;
  DateTime? startDate, endDate;
  Map<String, dynamic>? resultData;
  DateTime? createdAt;
}
```

### 10.3 Sistem Data Modelleri (`system_data_models.dart`)

```dart
class RegionalSite {
  String city;
  String? district;
  String type;
  double latitude, longitude;
  double overallScore;
  double? annualPotentialKwhM2;
  double? avgWindSpeedMs;
  int rank;
}

class Equipment {
  int id;
  String name, type;
  double ratedPowerKw;
  double? efficiency;
  double? costPerUnit;
}
```

### 10.4 Hava Durumu Modeli (`weather_model.dart`)

```dart
class HourlyWeatherData {
  String cityName;
  DateTime timestamp;
  double? temperature2m, apparentTemperature;
  double? windSpeed10m, windSpeed100m;
  double? shortwaveRadiation, directRadiation, diffuseRadiation;
  double? relativeHumidity2m, cloudCover;
  double? precipitation;
}
```

---

## 11. TEST STRATEJİSİ

### 11.1 Test Dosyaları

| Dosya | Kapsam | Test Sayısı |
|-------|--------|-------------|
| `test_api.py` | API endpoint erişilebilirlik ve CRUD | ~15 |
| `test_calculations.py` | Fizik motoru doğruluğu (kübik yasa, verim) | ~8 |
| `test_financials.py` | NPV, ROI, Geri ödeme hesapları | ~6 |
| `test_db_integrity.py` | ACID, cascade delete, cross-tenant izolasyon | ~10 |
| `test_pin_actions.py` | Pin CRUD işlemleri | ~6 |
| `test_pins_api.py` | Pin API endpoint testleri | ~6 |
| `test_reporting_logic.py` | Raporlama mantığı doğruluğu | ~4 |
| `test_scenarios_logic.py` | Senaryo hesaplama mantığı | ~5 |

### 11.2 Kritik Test Senaryoları (Top 10)

| # | Test | Doğrulanan İlke |
|---|------|-----------------|
| 1 | **Credential Defense** | User enumeration koruması (aynı hata mesajı) |
| 2 | **Zero Trust Enforcement** | Token olmadan yazma işlemi reddedilir (401) |
| 3 | **Geospatial Input Hygiene** | Geçersiz koordinat reddedilir (422) |
| 4 | **Cubic Law of Wind** | P ∝ v³ ilişkisi doğrulanır (2× hız → 8× güç) |
| 5 | **Uncapped Efficiency** | %150 verimle hesaplama yapılabilir |
| 6 | **NPV / DCF** | PV = FV / (1+r)^t formülü doğrulanır |
| 7 | **Mathematical Safety** | Sıfır tasarrufta Infinity döner, crash yok |
| 8 | **Cross-Tenant Isolation** | Kullanıcı A, Kullanıcı B'nin verisine erişemez |
| 9 | **ACID Transaction Safety** | Yarıda kalan işlem rollback yapılır |
| 10 | **GDPR Cascade Delete** | Kullanıcı silinirse tüm verisi de silinir |

### 11.3 Test Çalıştırma

```bash
# Backend test dizinine git
cd backend

# Tüm testleri çalıştır
pytest tests/ -v

# Belirli bir test dosyası
pytest tests/test_calculations.py -v

# Coverage raporu
pytest tests/ --cov=app --cov-report=html
```

**Framework:** `pytest` + Database Transaction Isolation + Mocking

---

## 12. KURULUM VE ÇALIŞTIRMA

### 12.1 Gereksinimler

| Bileşen | Minimum Versiyon |
|---------|-----------------|
| Python | 3.10+ |
| Flutter SDK | 3.8.1+ |
| Dart SDK | 3.8.1+ |
| Git | 2.x |

### 12.2 Backend Kurulumu

```bash
# 1. Sanal ortam oluştur
cd backend
python -m venv venv

# 2. Sanal ortamı aktifle
# Windows:
.\venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# 3. Bağımlılıkları yükle
pip install -r requirements.txt

# 4. .env dosyası oluştur
# backend/app/.env
SECRET_KEY=your_secret_key_here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# 5. Backend'i başlat
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Veya toplu betik ile:**
```bash
# Proje kök dizininden:
.\run_backend.bat
```

### 12.3 Frontend Kurulumu

```bash
# 1. Flutter bağımlılıkları
cd frontend
flutter pub get

# 2. API URL'sini yapılandır (lib/core/constants.dart)
# baseUrl değişkenini backend adresine ayarlayın

# 3. Uygulamayı çalıştır
flutter run -d chrome        # Web
flutter run -d windows       # Windows masaüstü
flutter run                  # Bağlı mobil cihaz
```

### 12.4 Backend Bağımlılıkları

| Paket | Kullanım Alanı |
|-------|----------------|
| `fastapi` | Web framework |
| `uvicorn` | ASGI sunucusu |
| `sqlalchemy` | ORM |
| `pydantic` | Veri doğrulama |
| `python-jose` | JWT token yönetimi |
| `passlib` | Şifre hash'leme (Argon2) |
| `requests` + `openmeteo-requests` | HTTP + Open-Meteo API client |
| `requests-cache` + `retry-requests` | Caching ve retry mekanizması |
| `pandas` | Veri manipülasyonu |
| `numpy` | Numerik hesaplamalar |
| `scipy` | IDW interpolasyon (cdist) |
| `scikit-learn` | (ML hazırlığı) |
| `geopandas` | Geospatial veri işleme |
| `rasterio` | DEM (yükseklik haritası) okuma |
| `shapely` | Geometrik analiz |
| `matplotlib` + `seaborn` | Görselleştirme (debug) |

### 12.5 Frontend Bağımlılıkları

| Paket | Kullanım Alanı |
|-------|----------------|
| `flutter_map` | Leaflet tabanlı harita widget'ı |
| `latlong2` | Koordinat işlemleri |
| `provider` | State yönetimi |
| `http` | HTTP istekleri |
| `fl_chart` | Grafik ve chart'lar |
| `flutter_secure_storage` | Güvenli token depolama |
| `flutter_map_cancellable_tile_provider` | İptal edilebilir tile yükleme |
| `google_maps_flutter` | (Alternatif harita) |
| `mapbox_maps_flutter` | (Alternatif harita) |
| `cupertino_icons` | iOS stil ikonlar |

---

## 13. API REFERANS ÖZETİ

### Tüm Endpoint'ler

| Grup | Method | Endpoint | Auth |
|------|--------|----------|------|
| **Root** | GET | `/` | ❌ |
| **Users** | POST | `/users/` | ❌ |
| | POST | `/users/token` | ❌ |
| | GET | `/users/me` | ✅ |
| **Pins** | POST | `/pins/` | ✅ |
| | GET | `/pins/` | ✅ |
| | PUT | `/pins/{id}` | ✅ |
| | DELETE | `/pins/{id}` | ✅ |
| | POST | `/pins/calculate` | ✅ |
| | POST | `/pins/{id}/analyze` | ✅ |
| | GET | `/pins/grid-map` | ✅ |
| **Scenarios** | POST | `/scenarios/` | ✅ |
| | GET | `/scenarios/` | ✅ |
| | PUT | `/scenarios/{id}` | ✅ |
| | POST | `/scenarios/{id}/calculate` | ✅ |
| | POST | `/scenarios/{id}/add-pins` | ✅ |
| **Reports** | GET | `/reports/regional` | ✅ |
| | GET | `/reports/interpolated-map` | ❌ |
| **Weather** | GET | `/weather/cities` | ❌ |
| | GET | `/weather/{city}/hourly` | ❌ |
| | GET | `/weather/{city}/latest` | ❌ |
| | GET | `/weather/summary` | ❌ |
| | GET | `/weather/best-wind` | ❌ |
| | GET | `/weather/best-solar` | ❌ |
| | GET | `/weather/at-time` | ❌ |
| | POST | `/weather/refresh` | ❌ |
| **Optimization** | POST | `/optimization/wind-placement` | ❌ |
| **Geo** | POST | `/geo/check-suitability` | ❌ |
| **Equipments** | GET | `/equipments/` | ❌ |
| | POST | `/equipments/` | ❌ |
| **System** | GET | `/system/health` | ❌ |

---

## 14. PROJE DOSYA YAPISI

```
smart_renewable_resource_planner/
├── backend/
│   ├── app/
│   │   ├── main.py                    # FastAPI uygulama + lifespan
│   │   ├── auth.py                    # JWT + Argon2 kimlik doğrulama
│   │   ├── .env                       # Gizli anahtarlar
│   │   ├── core/
│   │   │   └── constants.py           # 81 il + ilçe koordinat listesi
│   │   ├── crud/
│   │   │   └── crud.py                # Veritabanı CRUD işlemleri
│   │   ├── db/
│   │   │   ├── database.py            # 3 SQLite engine tanımı
│   │   │   ├── models.py              # Tüm ORM modelleri
│   │   │   └── init_db.py             # Veritabanı başlatma
│   │   ├── routers/
│   │   │   ├── pins.py                # Pin CRUD + Hesaplama
│   │   │   ├── users.py               # Kullanıcı kaydı + login
│   │   │   ├── equipments.py          # Ekipman kataloğu
│   │   │   ├── weather.py             # Şehir bazlı hava durumu
│   │   │   ├── reports.py             # Bölgesel raporlar
│   │   │   ├── scenario.py            # Senaryo yönetimi
│   │   │   ├── optimization.py        # Türbin yerleşim optimizasyonu
│   │   │   ├── geo.py                 # GIS uygunluk analizi
│   │   │   └── system.py              # Sistem sağlık kontrolü
│   │   ├── schemas/
│   │   │   └── schemas.py             # Pydantic şemaları
│   │   └── services/
│   │       ├── solar_service.py       # Güneş enerjisi hesaplama
│   │       ├── wind_service.py        # Rüzgar enerjisi hesaplama
│   │       ├── grid_service.py        # Grid analiz servisi
│   │       ├── geo_service.py         # GIS coğrafi analiz
│   │       ├── grid_generator.py      # Grid noktaları oluşturma
│   │       ├── interpolation_service.py # IDW enterpolasyon
│   │       └── collectors/
│   │           ├── base.py            # Open-Meteo client
│   │           ├── historical.py      # Günlük grid veri toplama
│   │           ├── hourly.py          # Saatlik şehir veri toplama
│   │           └── on_demand.py       # İstek bazlı veri çekme
│   ├── tests/                         # Pytest test dosyaları
│   ├── alembic/                       # DB migration dosyaları
│   ├── scripts/                       # Yardımcı betikler
│   ├── data/                          # GIS verileri (DEM, Shapefile)
│   ├── system_data.db                 # Sistem veritabanı (~330 MB)
│   ├── user_data.db                   # Kullanıcı veritabanı
│   └── user_pins_data.db             # Pin hesaplama veritabanı
├── frontend/
│   ├── lib/                           # Dart kaynak kodları
│   ├── pubspec.yaml                   # Flutter bağımlılıkları
│   ├── android/                       # Android platform dosyaları
│   ├── ios/                           # iOS platform dosyaları
│   ├── web/                           # Web platform dosyaları
│   └── windows/                       # Windows platform dosyaları
├── requirements.txt                   # Python bağımlılıkları
├── run_backend.bat                    # Backend başlatma betiği
├── PROJECT_DOCUMENTATION_1.md         # 📦 Bu dokümantasyon (Bölüm 1)
├── PROJECT_DOCUMENTATION_2.md         # 📦 Bu dokümantasyon (Bölüm 2)
└── README.md                          # Kısa açıklama
```

---

## 15. BİLİNEN KISITLAMALAR VE GELİŞTİRME ÖNERİLERİ

### 15.1 Mevcut Kısıtlamalar

| # | Kısıtlama | Detay |
|---|-----------|-------|
| 1 | **Güneş Optimizasyonu** | Sadece rüzgar türbini yerleşim optimizasyonu var; güneş paneli optimizasyonu henüz eklenmemiş |
| 2 | **Veritabanı** | SQLite kullanılıyor; çoklu kullanıcı senaryolarında PostgreSQL'e geçiş gerekebilir |
| 3 | **Optimizasyon Limiti** | Maksimum 50 türbin yerleştirilebilir (sunucu güvenliği) |
| 4 | **GIS Veri Bağımlılığı** | Geo analiz shapefile dosyalarına bağımlı; eksik olursa devre dışı kalır |
| 5 | **API Rate Limiting** | Open-Meteo rate limit'leri toplu veri çekimini yavaşlatabilir |

### 15.2 Gelecek Geliştirme Önerileri

| # | Öneri | Öncelik |
|---|-------|---------|
| 1 | Güneş paneli yerleşim optimizasyonu (`/optimization/solar-placement`) | Yüksek |
| 2 | Optimizasyon sonuçlarını veritabanına kaydetme | Yüksek |
| 3 | Her türbin için detaylı ekonomik analiz view'ı | Orta |
| 4 | Şebeke entegrasyonu simülasyonu | Orta |
| 5 | PostgreSQL'e migration | Orta |
| 6 | ML tabanlı üretim tahmini (scikit-learn entegrasyonu hazır) | Düşük |
| 7 | Gerçek zamanlı WebSocket veri akışı | Düşük |

---

## 16. REFERANSLAR

1. **FastAPI Documentation** — https://fastapi.tiangolo.com/
2. **Open-Meteo API Docs** — https://open-meteo.com/en/docs
3. **IEC 61400-12-1:2017** — Wind energy generation systems
4. **Flutter Documentation** — https://flutter.dev/docs
5. **SQLAlchemy 2.0 Documentation** — https://docs.sqlalchemy.org/
6. **GeoPandas Documentation** — https://geopandas.org/
7. **SciPy IDW** — Inverse Distance Weighting spatial interpolation

---

*📝 Bu dokümantasyon, projenin tüm mevcut özelliklerini kapsamlı olarak belgelemektedir.*  
*📌 Bölüm 1: [`PROJECT_DOCUMENTATION_1.md`](PROJECT_DOCUMENTATION_1.md) — Mimari, Backend, Servisler, Veritabanı*  
*📌 Bölüm 2: [`PROJECT_DOCUMENTATION_2.md`](PROJECT_DOCUMENTATION_2.md) — Frontend, Test, Kurulum, API Referansı*

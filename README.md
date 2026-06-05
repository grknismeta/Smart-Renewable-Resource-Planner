# 🌍 SRRP — Smart Renewable Resource Planner

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![PostGIS](https://img.shields.io/badge/PostGIS-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![MapLibre](https://img.shields.io/badge/MapLibre-396CB2?style=for-the-badge&logo=maplibre&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Caddy](https://img.shields.io/badge/Caddy-1F88C0?style=for-the-badge&logo=caddy&logoColor=white)

> **Canlı:** [https://srrp-app.com](https://srrp-app.com)

---

## 🟢 30 saniyede SRRP (basit anlatım)

SRRP, **Türkiye haritası üzerinde yenilenebilir enerji santrali (güneş / rüzgar / hidroelektrik) kurmak için en uygun yeri bulmana** yardım eden bir web uygulamasıdır.

Haritada bir noktaya tıklarsın; SRRP sana şunu söyler:

- ☀️ Burada **ne kadar güneş / rüzgar / su** var?
- 🚫 Buraya santral kurmak **yasak mı** (göl, yerleşim, askeri/koruma alanı, çok dik yamaç)?
- 📈 Bu santral **yıllar içinde ne kadar enerji** üretir, **ne zaman kendini amorti eder**?
- 🌡️ **İklim değişimi** (RCP senaryoları) bu potansiyeli nasıl etkiler?

Giriş yapmadan **"Keşfet"** ile haritayı, katmanları ve örnek santralleri inceleyebilir; giriş yapınca kendi santral planlarını oluşturup kaydedebilirsin.

---

## 🔭 Daha geniş anlatım

SRRP, **açık coğrafi verileri** (OpenStreetMap/GADM sınırları, su kütleleri, yerleşim, iletim hatları) ve **açık iklim verilerini** (Open-Meteo — 81 il + ~975 ilçe için 10+ yıllık günlük/aylık seri) birleştiren bir **Coğrafi Bilgi Sistemi (GIS) + karar destek** uygulamasıdır.

Üç ana yetenek etrafında kurgulanmıştır:

1. **Uygunluk analizi (Suitability):** PostGIS mekânsal sorgularıyla bir koordinatın güneş/rüzgar/HES için uygun olup olmadığını ve yasak sebeplerini saniyeler içinde döndürür.
2. **Üretim & finans projeksiyonu:** Fiziksel üretim formülleri + **SARIMAX** zaman serisi modeli ile aylık üretim, yıllık toplam, gelir/gider, geri ödeme (payback) ve CO₂ tasarrufu tahmini.
3. **İklim projeksiyonu (ML):** Geçmiş trendi extrapolate eden SARIMAX baseline'ı **IPCC RCP 4.5 / RCP 8.5** delta'larıyla ayarlayarak "iklim değişimi bu metriği hangi yöne, ne kadar iter" sezgisini harita ve grafiklerle verir.

Bunların üstüne; çok-katmanlı vektör harita (tematik renklendirme, ısı haritası, 3D arazi + 3D santral modelleri, rüzgar partikül akışı), il/ilçe drill-down raporları, senaryo karşılaştırma ve bir **AI sohbet asistanı** (Gemini) oturur.

---

## ⚡ Özellikler

| Alan | Özellik |
|------|---------|
| **Harita** | MapLibre GL tabanlı vektör harita; tematik choropleth (il/ilçe), ısı haritası, **3D arazi** (terrain + hillshade), **3D santral** modelleri (three.js GLB — dönen türbin + güneş paneli), rüzgar partikül akışı, izohips (contour) |
| **Uygunluk** | Koordinat → su / yerleşim / askeri-koruma / iletim hattı mesafesi / eğim kontrolü (PostGIS + Open-Meteo Elevation) |
| **Pin / Santral** | Harita üzerinde santral kur, kapasite hesapla (GES panel alanı, RES türbin, HES debi×düşü), düzenle/sil (CRUD), 3D görünüm |
| **ML Projeksiyon** | SARIMAX aylık tahmin, RCP 4.5/8.5 iklim senaryoları, finansal projeksiyon (gelir/payback/CO₂) |
| **Raporlar** | İl/ilçe drill-down, potansiyel sıralama, senaryo karşılaştırma, mini-harita |
| **Auth** | E-posta **veya** kullanıcı adı ile giriş, Google OAuth, parola belirle/değiştir, JWT, brute-force kilidi |
| **Misafir** | "Keşfet" salt-okunur modu — katmanlar + vitrin santralleri + il bilgi kartları |
| **AI** | Doğal dil ile veri sorgulama (Gemini tabanlı sohbet asistanı) |
| **Performans** | PostGIS GIST indeksleri, FastAPI'den doğrudan `ST_AsMVT` vektör tile üretimi, Redis (+ in-memory fallback) cache, ml_forecast precompute tablosu |

---

## 🛠️ Teknoloji Yığını

**Frontend**
- **Flutter** (Web + Native — Windows/masaüstü ve mobil paylaşımlı kod tabanı)
- **MapLibre GL** — Web'de `web/index.html` içindeki JS köprüsü (maplibre-gl-js 4.x) + native'de `maplibre` Flutter paketi
- **three.js** — harita üzerinde 3D santral modelleri (custom WebGL layer)
- **Basemap:** OpenFreeMap / Carto (vektör tile)
- State yönetimi: `provider` (MVVM — ViewModel'ler)

**Backend**
- **Python 3.11 + FastAPI** (Uvicorn)
- **SQLAlchemy 2.x (senkron)** + `psycopg2` — PostgreSQL/PostGIS
- **PostgreSQL 17 + PostGIS 3.x** — mekânsal sorgular + `ST_AsMVT` ile MVT tile üretimi (ayrı tile sunucusu YOK)
- **Redis** (+ in-memory fallback) — cache
- **statsmodels (SARIMAX)** — zaman serisi tahmini; `geopandas/shapely` — sınır/contains sorguları
- Kimlik: JWT (`python-jose`), parola hash (`passlib`), Google ID-token doğrulama

**Veri & Dış Servisler**
- **Open-Meteo** — Archive (geçmiş hava), Elevation (yükseklik/eğim) API
- **OpenStreetMap / GADM** — il/ilçe sınırları (GeoJSON), su/yerleşim/koruma alanları (Overpass)
- **Google OAuth** — sosyal giriş

**Dağıtım (Deploy)**
- **Docker Compose** — `caddy` (public 80/443) + `backend` + `db (postgis)` + `redis` (iç ağ)
- **Caddy** — reverse proxy + otomatik HTTPS (Let's Encrypt); `/api/*` → backend, SPA `try_files`
- **DigitalOcean** droplet — canlı: `https://srrp-app.com`

---

## 🏗️ Mimari (üst seviye)

```mermaid
flowchart LR
    subgraph Client["🌐 İstemci"]
        FE["Flutter Web/Native<br/>MapLibre + three.js"]
    end

    subgraph Edge["🛡️ Caddy (80/443)"]
        CADDY["Reverse Proxy<br/>+ otomatik HTTPS<br/>/api/* → backend · SPA"]
    end

    subgraph Backend["⚙️ FastAPI (Uvicorn)"]
        API["REST API + routers"]
        MVT["MVT tile (ST_AsMVT)"]
        ML["SARIMAX + RCP motoru"]
        GEO["Geo suitability"]
    end

    subgraph Data["🗄️ Veri Katmanı"]
        PG[("PostgreSQL + PostGIS")]
        REDIS[("Redis cache")]
    end

    subgraph Ext["☁️ Dış Servisler"]
        OM["Open-Meteo<br/>(Archive + Elevation)"]
        OAUTH["Google OAuth"]
        BASE["OpenFreeMap basemap"]
    end

    FE -->|HTTPS| CADDY
    FE -.->|vektör tile| BASE
    CADDY --> API
    API --> MVT --> PG
    API --> ML --> PG
    API --> GEO --> PG
    API --> REDIS
    GEO -.->|yükseklik/eğim| OM
    ML -.->|geçmiş hava| OM
    API -.->|ID-token doğrula| OAUTH
```

---

## 🧩 Modül / Bileşen Yapısı

```mermaid
flowchart TB
    subgraph FE["Frontend — lib/features"]
        F_map["map<br/>(harita, katmanlar, paneller)"]
        F_pins["pins<br/>(santral CRUD + akış)"]
        F_reports["reports<br/>(il/ilçe drill-down)"]
        F_scen["scenarios<br/>(senaryo karşılaştırma)"]
        F_auth["auth<br/>(giriş/kayıt/hesap)"]
        F_landing["landing<br/>(+ Keşfet misafir)"]
        F_chat["chatbot (AI)"]
    end

    subgraph BE["Backend — app/routers"]
        R_geo["geo<br/>(suitability)"]
        R_ml["ml<br/>(SARIMAX + RCP + choropleth)"]
        R_tiles["tiles<br/>(ST_AsMVT)"]
        R_pins["pins / equipments"]
        R_reports["reports / analysis"]
        R_borders["borders (GADM)"]
        R_users["users (auth)"]
        R_chat["chat (Gemini)"]
        R_weather["weather / wind_vectors"]
    end

    F_map --> R_tiles & R_ml & R_geo & R_weather & R_borders
    F_pins --> R_pins
    F_reports --> R_reports
    F_scen --> R_reports
    F_auth --> R_users
    F_chat --> R_chat
```

---

## 🗃️ Veri Modeli (ER — özet)

```mermaid
erDiagram
    USER ||--o{ PIN : "kurar (owner_id)"
    USER ||--o{ SCENARIO : "oluşturur"
    USER ||--o{ EQUIPMENT : "ekler (owner_id, sistem=NULL)"
    PIN  ||--o{ PIN_ANALYSIS : "analiz edilir"
    PIN  }o--|| EQUIPMENT : "kullanır (equipment_id)"

    USER {
        int id PK
        string email UK
        string username UK "nullable"
        string full_name
        string hashed_password "OAuth'ta NULL"
    }
    PIN {
        int id PK
        int owner_id FK
        string type "GES|RES|HES"
        float latitude
        float longitude
        float capacity_mw
    }
    EQUIPMENT {
        int id PK
        int owner_id FK "NULL=sistem"
        string type
        float rated_power_kw
        float efficiency
    }
    SCENARIO {
        int id PK
        int owner_id FK
        string name
    }
    PIN_ANALYSIS {
        int id PK
        int pin_id FK
        json result
    }

    WEATHER_DATA {
        float latitude
        float longitude
        date date
        string province_name
        string district_name
        float shortwave_radiation_sum
        float wind_speed_mean
    }
    MONTHLY_CLIMATE {
        string province_name
        string district_name
        int month
        float value
    }
    ML_FORECAST {
        string scope "province|district"
        string resource "solar|wind"
        string metric
        string scenario "baseline|rcp45|rcp85"
        int year
        int month
        float value
    }
```

> `WEATHER_DATA`, `MONTHLY_CLIMATE`, `ML_FORECAST` analitik/precompute tablolarıdır (kullanıcı verisinden bağımsız; koordinat/il-ilçe ile eşlenir).

---

## 🔄 Örnek Akış — Santral kur + uygunluk + projeksiyon

```mermaid
sequenceDiagram
    actor U as Kullanıcı
    participant FE as Flutter
    participant API as FastAPI
    participant PG as PostGIS
    participant OM as Open-Meteo

    U->>FE: Haritada konuma tıkla ("Santral Kur")
    FE->>API: POST /geo/check-suitability {lat, lon}
    API->>PG: il/ilçe (GADM contains) + su/yerleşim/yasak/iletim sorgusu
    API->>OM: yükseklik/eğim (kısa timeout, opsiyonel)
    API-->>FE: {solar/wind/hydro uygun mu + sebepler}
    U->>FE: Tip + parametre gir → Kaydet
    FE->>API: POST /pins (capacity_mw hesaplı)
    U->>FE: "Projeksiyon" iste
    FE->>API: GET /ml/project/pin/{id}/financial
    API->>PG: ml_forecast + climatology oku → SARIMAX/finans
    API-->>FE: aylık üretim + yıllık gelir + payback + CO₂
```

---

## 🚀 Kurulum ve Çalıştırma (yerel geliştirme)

Gerekli: **Flutter SDK**, **Python 3.11+**, **PostgreSQL 17 + PostGIS**, (opsiyonel) **Redis**.

### 1) Backend (FastAPI)

```bash
cd backend
python -m venv venv
venv\Scripts\activate            # Windows  (Linux/mac: source venv/bin/activate)
pip install -r requirements.txt
```

Kökte `.env` oluştur:

```env
DATABASE_URL=postgresql://srrp_admin:SIFRE@localhost:5432/srrp_db
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=degistir-uzun-rastgele-bir-deger
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440
GEO_ANALYSIS_ENABLED=true
GOOGLE_CLIENT_ID=...apps.googleusercontent.com
GOOGLE_API_KEY=...        # AI sohbet (Gemini) için, opsiyonel
```

> Şema **Alembic gerektirmez**: uygulama açılışta `create_all` + idempotent `ALTER TABLE ... IF NOT EXISTS` DDL'leriyle kendini günceller. PostGIS uzantısı ve veri tabloları (`weather_data`, `monthly_climate`, sınır/su/yasak katmanları, `ml_forecast`) ayrıca yüklenmelidir.

```bash
uvicorn app.main:app --reload   # http://localhost:8000  (Swagger: /docs)
```

### 2) Frontend (Flutter)

```bash
cd frontend
flutter pub get
flutter run -d chrome           # Web (MapLibre JS köprüsü)
# veya: flutter run -d windows  # Native masaüstü
```

> Frontend, `localhost`'ta backend'i `:8000`'de, canlıda ise `origin + /api`'de arar (bkz. `web/index.html` → `SRRP_API_BASE`).

---

## 🐳 Dağıtım (Production — Docker + Caddy)

Tek komutla tüm yığın (Caddy + backend + PostGIS + Redis):

```bash
# Kökte .env: SECRET_KEY, POSTGRES_PASSWORD, ALLOWED_ORIGINS, GOOGLE_* ...
docker compose -f docker-compose.prod.yml up -d --build
```

- **Caddy** 80/443'ü dinler; `/api/*` → backend (prefix soyulur), kalan → SPA. HTTPS otomatik (Let's Encrypt).
- Backend `--root-path /api` ile çalışır (reverse-proxy arkasında trailing-slash redirect'leri prefix'i korusun diye).
- `db/redis/backend` host'a port açmaz (sadece iç ağ); yalnız Caddy public.

---

## 📁 Klasör Yapısı

```text
smart_renewable_resource_planner/
├── docker-compose.prod.yml     # Prod yığını (caddy + backend + db + redis)
├── Caddyfile                   # Reverse proxy + otomatik HTTPS
├── frontend/                   # Flutter (Web + Native)
│   ├── lib/core/               # network (api_service), theme, storage, base VM
│   ├── lib/features/           # map · pins · reports · scenarios · auth · landing · chatbot · help · settings
│   ├── web/index.html          # MapLibre JS köprüsü (terrain, choropleth, 3D, particles)
│   └── Dockerfile.deploy        # flutter build web → caddy imajı
└── backend/                    # FastAPI
    ├── app/routers/            # geo · ml · tiles · pins · equipments · reports · analysis · borders · users · chat · weather · ...
    ├── app/services/           # geo_service · ml_sarimax_service · climate_scenarios · redis_cache · ...
    ├── app/db/models.py        # SQLAlchemy modelleri
    ├── scripts/                # veri çekme + ml_forecast üretimi (build_ml_forecasts, fetch_district_weather, ...)
    └── Dockerfile
```

---

## 🌡️ ML & İklim Senaryoları (kısaca)

- **Baseline:** Aylık seriye **SARIMAX** (mevsimsel `(1,1,1)(1,1,1,12)`) + Fourier/CO₂ exog ile geçmiş trend extrapolasyonu.
- **RCP 4.5 / RCP 8.5:** Baseline üzerine IPCC AR6 Akdeniz/Türkiye yönelimli **yıllık kümülatif delta** (güneş↑, bulut↓, yağış↓, debi↓, rüzgar↓, sıcaklık↑). `ml_forecast` tablosuna senaryo bazında precompute edilir.
- **Choropleth normalizasyonu:** RCP delta'sı bir yıl için tüm lokasyonlara aynı çarpan olduğundan, harita renkleri **baseline aralığına göre** normalize edilir (aksi halde senaryolar aynı renkte çıkar).

---

## 🗺️ Yol Haritası

- [ ] Tüm ~975 ilçe için günlük hava verisi backfill'inin tamamlanması (dağıtık fetch)
- [ ] AI sohbet asistanının genişletilmesi
- [ ] CMIP6/CORDEX tabanlı yüksek çözünürlüklü iklim projeksiyonu
- [ ] İngilizce dil desteği
- [ ] Native (mobil) sürüm yayını

---

## 📜 Lisans & Notlar

Akademik/araştırma amaçlı geliştirilmiştir. İklim projeksiyonları ve finansal tahminler **gösterge niteliğindedir**, yatırım danışmanlığı değildir. Dış veri kaynaklarının (Open-Meteo, OSM/GADM) kendi lisans/atıf koşulları geçerlidir.

---
tags: [plan, backend, sprint, checkpoint]
updated: 2026-05-17
related: [INDEX, INBOX, PROJECT-OVERVIEW, WeatherRouter, SuitabilityChecks]
---

# 🛠️ Backend Sprint Planı — 2026-05-17 Checkpoint

> Pin sprinti **tamamlandı**. Bu doküman backend tarafının kalan açık işlerini
> tek bir kaynakta toplar. Sıralı sprint'ler, kabul kriterleri ve riskler.
> Her sprint sonunda buraya `✅` koyacağız; sıradakine geçmeden önce
> `KARARLAR` bölümündeki seçimleri kontrol et.

## 🎯 Stratejik Çerçeve

Kullanıcının dile getirdiği üç ana hedef:
1. **3D harita özellikleri** (terrain + sky + binalar)
2. **DEM `.tif` dosyalarından kurtulma → PostGIS'e geç**
3. **Docker ile statik veri sorununu çöz** (785 MB DEM + 3.5 GB OSM image'a sığmasın)

Benim eklemelerim ("teknik gözle ne lazım"):
4. **`province_analysis` tek-kaynak hattı** — `score_1m/3m/6m/yearly` formülleri tanımlı değil. Raporlar/İl Analizi/Choropleth tutarsız (haritada hepsi 100, İl Analizi 40-60). [[INBOX]] 2026-05-09 bölümü.
5. **Pin validation endpoint (`POST /pins/validate`)** — Suitability için backend yapısı eksik. Şu an `geo_service._analyze_solar/_wind` stub. RES için yerleşim/otoyol/sanayi/orman kontrolü yok.
6. **APScheduler doğrulama** — Kod var (`scheduler.py` `CronTrigger(minute=0)` + startup once), gerçek çalışma test edilmeli. "228 dk önce" mock metni gerçek `last_scheduler_run`'a bağlanmalı.
7. **Chatbot `part.function_call` hatası** — Gemini SDK response parse'ında crash; tek satır `hasattr` fix.

## 📦 Mevcut State (1 cümlede)

- **Backend**: 13 router, 11 servis. `hydro_service`, `solar_service`, `wind_service`, `analysis_service`, `ml_projection_service`, `scheduler` **kod-mevcut**. `geo_service._get_terrain_data` ve `_analyze_wind`/`_analyze_hydro` çoğu yerde **stub**.
- **DB**: PostgreSQL + PostGIS, alembic head: `014_fix_equipments_id_sequence`. `hourly_weather_data` 8.27 GB, `province_analysis` tablosu var ama doluluk şüpheli.
- **Statik veri**: `backend/data/dem/*.tif` = **785 MB** (kod kullanmıyor, stub). `backend/data/vector/` = **3.5 GB** (GADM shapefile'ları + OSM polygon'lar; bir kısmı PostGIS'e import edildi, bir kısmı boşta).
- **Docker**: Kök dizinde `docker-compose.yml` var (local test); production-ready deploy adımları yapılmadı.

---

## 🗂️ Sprint Sıralaması

| # | Sprint | Süre | Kullanıcı önceliği | Risk |
|---|---|---|---|---|
| **S1** | Backend Veri Tutarlılığı + Scheduler doğrulama | 3-5 gün | Orta | Düşük (kod hazır, test) |
| **S2** | 3D Harita + DEM'den Kurtulma | 1 hafta | **Yüksek (1)** | Orta (Elevation API rate limit) |
| **S3** | OSM → PostGIS Migration + Pin Validation | 1-2 hafta | **Yüksek (2)** | Orta-Yüksek (büyük veri import) |
| **S4** | Docker Production-Ready + Statik Veri Stratejisi | 3-5 gün | **Yüksek (3)** | Düşük |
| **S5** | Uygunluk Skoru Motoru (Multi-criteria + Grid Pre-compute) | 2 hafta | Orta | Yüksek (algoritma karmaşası) |
| **S6** | Finansal Katman + EPİAŞ Entegrasyonu | 1 hafta | Düşük | Düşük |
| **S7** | AWS / Hetzner Deploy + SSL | 3-5 gün | Düşük (önce local solidify) | Orta (DNS/SSL) |

**Süre toplamı:** ~6-8 hafta yoğun çalışma; gerçek hayatta 2-3 ay.

---

## 📋 Sprint Detayları

### S1 — Climatology Skoru + Pin Generation History ✅ BACKEND TAMAM (2026-05-17)

**Tamamlanan:** S1.1–S1.7 + S1.10 (backend tarafı %100). 162 row climatology
tablosunda; doğru sıralama (top wind: Trakya+Marmara; top solar: İç Anadolu).
Otomatik 6 ayda bir refresh aktif. Pin auto-analyze bug bonus fix.

**Bekleyen:** S1.8 (Pin install_date picker) + S1.9 (Üretim Geçmişi UI) —
kullanıcı test sonrası halledilecek.



**Mimari karar (Manisa örneği):** Skor SÜREKLİ DEĞİŞMEZ. Manisa rüzgar
karakteri 10+ yıl boyunca stabil — "Bu sene az rüzgar" diye listeden
düşürmek yanlış. Statik climatology + dinamik pin generation history
ayrımı.

**Hedef:** İki ayrı sistem kuruyoruz:

| Sistem | Veri Kaynağı | Güncelleme | Amaç |
|---|---|---|---|
| **Climatology** (il/ilçe×tip statik) | 10+ yıl günlük + 2 yıl saatlik | 6 ayda bir | "Manisa rüzgar 87/100" — bölgesel karakter |
| **Pin Generation History** (pin bazlı) | Saatlik veri × pin.installation_date | Saatlik (sadece kullanıcı pinleri) | "Bu pin kurulduğundan beri 142 MWh, bugün 8 MWh" |

**🔒 INVARIANT — Raporlar Endpoint'leri Aynı Kalır:**

Frontend Raporlar ekranı şu endpoint'leri kullanıyor (cross-check 2026-05-17):

| Endpoint | Kullanım | Sprint Etkisi |
|---|---|---|
| `GET /analysis/provinces?type=&horizon=&limit=` | İl listesi skorlu | İçeride climatology'den oku — signature **aynı** |
| `GET /analysis/province/{name}` | Tek il detay | İçeride climatology'den oku — signature **aynı** |
| `GET /analysis/choropleth/{metric}` | Tematik harita | climatology + saatlik veri — signature **aynı** |
| `GET /analysis/projection` | Trend projeksiyonu | climatology hourly_typical_profile'dan — signature **aynı** |
| `GET /reports/regional` | Bölgesel rapor | climatology aggregation — signature **aynı** |
| `GET /weather/monthly` | Aylık trend grafiği | Mevcut hourly_weather_data — değişmez |

S1'de endpoint **signature'ları değiştirilmeyecek**; frontend testten geçer.
Sadece içeride `province_analysis` → `climatology` swap.

**Climatology metrikleri (her il+tip için):**
- `avg_wind_speed_10y` — 10+ yıl günlük ortalama (rüzgar için)
- `weibull_k` — Süreklilik şekil parametresi (k>2 = sürekli, k<1.5 = kararsız)
- `weibull_c` — Skala parametresi
- `capacity_factor` — Teknik kapasite faktörü (rüzgar için power curve, güneş için PR)
- `avg_solar_irradiance_10y` — kWh/m²/yıl
- `avg_temperature_10y` — Panel verim düzeltmesi için
- `seasonal_variance` — Mevsim arası fark (düşük = kararlı)
- `hourly_typical_profile` — JSON: 12 ay × 24 saat tipik değer (interpolasyon için)
- `score_climatology` — Multi-criteria 0-100 (formül [[ScoreFormula]])

**Kabul kriterleri:**
- [ ] Alembic `015_climatology_and_pin_install_date` migration:
  - `climatology` tablosu (province_name, district_name nullable, resource_type, yukarıdaki metrikler, computed_at)
  - `pins.installation_date` (DateTime, nullable — varsayılan `created_at`)
- [ ] `climatology_service.py` — One-shot hesaplama scripti (`python -m app.services.climatology_compute`)
- [ ] İlk hesap çıktısı: 81 il × 3 tip = 243 row, opsiyonel ilçe seviyesi (~960 × 3 = 2880 row)
- [ ] Scheduler: 6 ayda bir auto-refresh (`CronTrigger(month='*/6', day=1, hour=2)`)
- [ ] `/analysis/provinces?type=wind&horizon=yearly` endpoint'i **climatology** tablosundan döner (eski `province_analysis` deprecate)
- [ ] `Pin` model'a `installation_date` field; AddPinDialog'a opsiyonel date picker (boş ise `today`)
- [ ] `GET /pins/{id}/generation?period=today|month|year|total|range` endpoint
  - Saatlik veri var (son 2 yıl) → direkt sorgu
  - Daha eski → günlük × `hourly_typical_profile` interpolasyon
- [ ] PinDetailsDialog "Üretim Geçmişi" sekmesi: kart sayıları (bugün/ay/yıl/toplam) + zaman serisi grafiği
- [ ] Önerilen Bölgeler paneli artık climatology'den top-N gösterir
- [ ] Choropleth ısı + ışınım doğu-batı asimetrisi: climatology ile tek-kaynak → otomatik düzelir
- [ ] APScheduler hourly fetch hala çalışır (saatlik veri biriksin diye); ama recompute her saat **yok**, sadece 6 aylık climatology refresh

**Climatology Skor Formülü (KARAR #1, tavsiyem):**

```
score_wind = (
    capacity_factor × 0.35           # Teknik üretkenlik (en önemli)
  + (avg_wind_speed - 4.0)/8.0 × 0.25  # Mutlak hız (cut-in üstü)
  + min(weibull_k, 3.0)/3.0 × 0.20  # Süreklilik (k yüksek = iyi)
  + (1 - seasonal_variance) × 0.10   # Stabilite
  + grid_proximity × 0.10            # Şebeke yakınlığı (PostGIS S3)
) × 100

score_solar = (
    capacity_factor × 0.30
  + ghi_normalized × 0.25            # 1200-2000 kWh/m² aralığında
  + (1 - cloud_variance) × 0.15
  + temperature_derate × 0.10        # >25°C verim kaybı
  + slope_orientation × 0.10         # Güney + 5-15° eğim (S2'de)
  + grid_proximity × 0.10
) × 100

score_hydro = (... S3 sonrası HES PostGIS verisi gelince ...)
```

**Pin Generation History Hesap Mantığı:**

```python
def get_pin_generation(pin_id, from_date, to_date):
    pin = get_pin(pin_id)
    installation = pin.installation_date or pin.created_at
    actual_from = max(from_date, installation)

    if actual_from >= (today - 2_years):
        # Saatlik veri mevcut → gerçek hesap
        hourly = query_hourly_weather(pin.lat, pin.lon, actual_from, to_date)
        production = compute_production_per_hour(hourly, pin.type, pin.equipment, pin.advanced_params)
    else:
        # Eski tarih → günlük veri × climatology saatlik profil
        daily = query_daily_weather(pin.lat, pin.lon, actual_from, to_date)
        profile = get_climatology_hourly_profile(pin.province, pin.type)
        production = interpolate_daily_to_hourly(daily, profile, pin.equipment, pin.advanced_params)
    return aggregate(production, period=...)
```

**Riskler:**
- Climatology hesabı uzun sürebilir (8.27 GB hourly + 10y daily) — ilk çalışmada 1-2 saat normal. Background job, blocking değil.
- Pin generation interpolasyon doğruluğu: günlük × tipik profil = ~%85 doğruluk. Bilimsel kesinlik için yeter.
- Frontend AddPinDialog'a installation_date picker eklenmeli — küçük UI iş.

---

### S2 — 3D Harita + DEM'den Kurtulma ✅ TAMAM (2026-05-17)

**Tamamlanan:**
- ✅ **AWS Terrarium CDN** — `srrpSetTerrain` MapLibre demo tile yerine
  `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png`
  + encoding='terrarium'. Global yüksek-resolution DEM ücretsiz.
- ✅ **Parametrik exaggeration** — `srrpSetTerrainExaggeration(double)`
  JS shim. MapViewModel.setTerrainExaggeration + Layers panel slider
  (1.0×–3.0×, 0.1 adım, anlık update — kaynak yeniden yüklenmez).
- ✅ **Open-Meteo Elevation API** — `geo_service._get_terrain_data`:
  5 nokta batch (ana + 4 komşu) → elevation + slope hesabı.
  Redis cache 7 gün TTL, lat/lon 0.001° round (~100m precision).
- ✅ **DEM .tif silindi** — 785 MB `backend/data/dem/*.tif` kaldırıldı,
  `.gitignore`'a eklendi.
- ✅ **Pin uygunluk analizinde gerçek elevation/slope** — `_analyze_solar`,
  `_analyze_wind`, `_analyze_hydro` Open-Meteo'dan gerçek değer alıyor.
  Test: Yusufeli 917m/33.3° → "Orta-dik yamaç, montaj maliyeti artabilir";
  Konya 1027m/3.5° → düz, eğim notu yok.

**Doğrulanmış test sonuçları:**
| Konum | Elevation | Slope | Karakter |
|---|---|---|---|
| Manisa Ovası | 80m | 12.4° | Gediz vadi orta dik ✅ |
| Yusufeli (Artvin) | 917m | 33.3° | Çoruh Vadisi çok dik ✅ |
| Konya Ovası | 1027m | 3.5° | İç Anadolu plato düz ✅ |

**Performans:**
- Tek koordinat → 1 API call → 5 nokta batch → ~200ms
- Cache hit → 0ms (Redis)
- 7 gün TTL — terrain neredeyse hiç değişmez



**Hedef:** MapLibre `setTerrain()` aktif, AWS Terrain CDN'inden yükseklik. `backend/data/dem/*.tif` **silinir** (785 MB temizleniyor). `geo_service._get_terrain_data` Open-Meteo Elevation API kullanır (stub değil).

**Kabul kriterleri:**
- [ ] `index.html`'de `map.addSource('terrain-dem', { type: 'raster-dem', url: 'https://elevation-tiles-prod.s3.amazonaws.com/terrarium/{z}/{x}/{y}.png', encoding: 'terrarium' })`
- [ ] `map.setTerrain({ source: 'terrain-dem', exaggeration: 1.5 })`
- [ ] Sky layer eklenmiş (atmosfer efekti)
- [ ] Layers panel "3D Arazi" toggle çalışıyor (şu an "YAKINDA" rozetli)
- [ ] Exaggeration slider (1.0-3.0 arası, default 1.5)
- [ ] `geo_service._get_terrain_data` → `https://api.open-meteo.com/v1/elevation?latitude=X&longitude=Y` çağrısı (cache 7 gün)
- [ ] `backend/data/dem/` klasörü **silindi**, `.gitignore`'a eklendi
- [ ] Pin uygunluk analizinde gerçek elevation değeri görünüyor (artık "DEM bekleniyor" notu yok)

**Riskler:**
- Open-Meteo Elevation API rate limit (günlük 10K istek) — Redis cache + grid round (lat/lon 0.01 round) gerekli.
- Terrarium PNG decode tarayıcı tarafında, performans test edilmeli (mobil!).
- AWS S3 elevation-tiles-prod ücretsiz ama CORS / availability kontrolü.

**Beklenen kazanım:** 785 MB disk temizlendi, gerçek 3D terrain (Google Earth hissi).

---

### S3 — OSM → PostGIS Migration + Pin Validation

**Hedef:** `backend/data/vector/gis_osm_*.shp` dosyaları PostGIS'e import edilir. `POST /pins/validate` endpoint çalışır. `_analyze_wind` gerçek uygunluk döner.

**PostGIS'e gidecekler:**
| Dosya | Boyut | Hedef tablo |
|---|---|---|
| `gis_osm_water_a_free_1.shp` | 58 MB | `restricted_water` |
| `gis_osm_landuse_a_free_1.shp` | 513 MB | `land_use_zones` |
| `gis_osm_natural_*.shp` | 26 MB | `natural_features` (forest, peak vs.) |
| `gis_osm_railways_*.shp` | 5.8 MB | `restricted_railways` |
| `gis_osm_roads_*.shp` | 1.1 GB | `restricted_roads` (sadece motorway/trunk filter) |
| `gis_osm_buildings_*.shp` | 1.7 GB | `urban_centers` (admin boundary'ye fallback) |

**Kabul kriterleri:**
- [ ] `import_osm_to_postgis.py` script yazıldı (`shp2pgsql` veya `geopandas + GeoAlchemy`)
- [ ] Alembic migration `015_postgis_restricted_tables` ile spatial index'li tablolar oluşturuldu
- [ ] `POST /pins/validate` endpoint yazıldı, schema:
  ```json
  {
    "suitable": true,
    "score": 78,
    "blockers": [],
    "warnings": [{ "type": "slope", "message": "...", "severity": "medium" }],
    "details": { "elevation", "slope", "nearest_road_m", "nearest_water_m", "nearest_substation_km", "land_use" }
  }
  ```
- [ ] `geo_service._analyze_wind` gerçek mantık: yerleşim 1.5km, otoyol 500m, sanayi 1km, orman içi yasak (PostGIS `ST_Distance` query)
- [ ] `geo_service._analyze_solar` benzer şekilde
- [ ] Frontend AddPinDialog suitability banner gerçek backend response'unu gösterir (mevcut stub'lar gerçekleşir)
- [ ] `backend/data/vector/gis_osm_*` dosyaları **silindi** (PostGIS'e taşındı), `gadm41_TUR_*` kalır (sınır geojson kaynağı)

**Riskler:**
- Import süresi: 1.1 GB roads + 1.7 GB buildings PostGIS'e 30-60 dk sürebilir. Script idempotent olmalı (kısmi başarıdan kurtarma).
- Spatial index olmadan `ST_Distance` çok yavaş — `GIST(geom)` zorunlu.
- Roads filtresi: tüm OSM yolları çekmek anlamsız, sadece `highway IN ('motorway', 'trunk', 'primary')`.

**Beklenen kazanım:** 3.5 GB temizlendi, Pin uygunluk gerçek çalışıyor.

---

### S4 — Docker Production-Ready + Statik Veri Stratejisi

**Hedef:** Kullanıcının "Docker ile statik veri sorununu" çözmek. Hangi veri image'a girecek, hangisi volume olacak netleşsin.

**Strateji önerisi:**
| Veri | Boyut | Strateji |
|---|---|---|
| Backend kodu | ~2 MB | **Image içinde** (COPY) |
| Frontend web build | ~30 MB | **Image içinde** (nginx static serve) |
| `gadm41_TUR_*.shp` (sınır geojson) | ~38 MB | **Image içinde** (read-only) |
| `hourly_weather_data` 8.27 GB | büyük | **Volume** (`pg_data` named volume), seed dump |
| `restricted_*` PostGIS tabloları | ~350 MB | **Volume** (DB içinde), seed dump |
| PostgreSQL veri klasörü | dynamic | **Volume** (`pg_data`) |
| Redis | minimal | **Volume** (`redis_data`) |

**Kabul kriterleri:**
- [ ] `docker-compose.yml` multi-service: `postgres`, `redis`, `backend`, `nginx` (statik frontend + reverse proxy)
- [ ] `Dockerfile` (backend): multi-stage build (deps cache → app), ~200 MB image
- [ ] `Dockerfile` (nginx): Flutter web build COPY + reverse proxy config
- [ ] Named volumes: `pg_data`, `redis_data`
- [ ] PostgreSQL seed dump: `pg_dump -Fc` çıktısı `seed/srrp_seed.dump` (alembic migrations + restricted_* tabloları); ilk `docker-compose up` sonrası `pg_restore` otomatik
- [ ] `.dockerignore` — DEM, OSM raw dosyaları, `node_modules`, `__pycache__`, `.venv` exclude
- [ ] Environment: `.env` template (DATABASE_URL, REDIS_URL, JWT_SECRET, OPEN_METEO_KEY)
- [ ] Healthcheck'ler: postgres, backend
- [ ] Alembic `upgrade head` otomatik (backend entrypoint script)
- [ ] `docker-compose up -d` ile sıfır manuel adımla çalışıyor

**Riskler:**
- Seed dump boyutu büyük olabilir (8 GB), git'e koyma → Git LFS veya separate download URL.
- Production'da seed'in nasıl güncelleneceği (yeni hourly veri biriktikçe seed eskimez mi?) — strateji: seed sadece restricted_* + alembic; hourly veri scheduler'a bırakılır.

---

### S5 — Uygunluk Skoru Motoru

**Hedef:** S1'in `province_analysis` tek-kaynak hattını koordinat-bazlı multi-criteria skora çıkarmak. 1km × 1km grid pre-compute.

**Kabul kriterleri:**
- [ ] `app/services/scoring_service.py` — GES/RES/HES için ayrı skor formülleri (Roadmap Faz 3.1)
- [ ] `grid_scores` tablosu: ~500K satır (Türkiye 1km grid), her hücre için 3 tip skor
- [ ] Haftalık cron job: tüm grid'i recompute
- [ ] `GET /optimization/top-sites?resource=wind&limit=50` — pre-computed top-N
- [ ] Önerilen Bölgeler paneli artık "veri yok" demiyor, gerçek liste
- [ ] AHP wizard backend hazırlığı (kullanıcı tercih ağırlıkları endpoint'i)

**Riskler:**
- 500K hücre PostgreSQL'de update — chunk'lı (10K'lık batch) olmalı.
- Skor formülünün doğru kalibre edilmesi: literatür çalışması gerekiyor.

---

### S6 — Finansal Katman

**Hedef:** LCOE, IRR, karbon kredisi, EPİAŞ arbitraj. Mevcut `finance_service.py` + `financial_advanced_service.py` üzerine inşa.

**Kabul kriterleri:**
- [ ] LCOE formülü implement edildi (omur boyu maliyet / toplam üretim)
- [ ] IRR (NPV=0 için iskonto oranı, scipy `optimize.brentq`)
- [ ] Karbon kredisi modeli: CO₂ tasarrufu × borsa fiyatı (sabit env değer)
- [ ] Şebeke bağlantı maliyeti: en yakın trafo (`PostGIS ST_Distance`) × $/km
- [ ] (Opsiyonel) EPİAŞ saatlik spot fiyat API → arbitraj
- [ ] Frontend Senaryo karşılaştırma ekranı bu metrikleri gösterir

---

### S7 — AWS EC2 Free Tier Deploy + Kapatma Planı

**Hedef:** `docker-compose` AWS EC2 t2.micro Free Tier'ında. Proje
2-5 ay aktif kalacak (kullanıcı planı 2026-05-17), 12 aylık free tier
fazlasıyla yeter. Projenin kapanışında temiz cleanup adımları planlandı.

**AWS Free Tier 12 ay ücretsiz kaynakları:**
- EC2 t2.micro (1 vCPU, 1 GB RAM, x86_64): 750 saat/ay (tek instance 24/7)
- 30 GB EBS gp2/gp3 storage
- 100 GB veri çıkışı/ay
- ECR: 500 MB/ay free (image ~200 MB → sığar)
- S3: 5 GB free (backup için)
- CloudWatch basic monitoring free

**Frontend deploy:** **GitHub Pages** veya **Cloudflare Pages**
(statik Flutter web build, jüri demo için ideal).

**Domain:** Opsiyonel. AWS default DNS yeterli
(`ec2-x-y-z-w.eu-central-1.compute.amazonaws.com`). İstenirse
Namecheap'ten .me ~$8/yıl tek seferlik.

**Kabul kriterleri (deploy):**
- [ ] AWS hesabı açıldı, Free Tier 12 ay aktif
- [ ] **EC2 t2.micro** (Ubuntu 22.04 LTS, eu-central-1 Frankfurt) launched
- [ ] Security Group: 22 (SSH key only), 80/443 (HTTP/HTTPS)
- [ ] Elastic IP atanmış (instance restart'ta IP değişmesin)
- [ ] **ECR repository** oluşturuldu: `srrp-backend`, `srrp-frontend`
- [ ] GitHub Actions: push'ta `docker build --platform linux/amd64` + ECR push
- [ ] EC2'a Docker + AWS CLI install
- [ ] `aws ecr get-login-password | docker login` ile authenticate
- [ ] `docker-compose.prod.yml` ECR image referansları + production env
- [ ] PostgreSQL container'ı (Docker), volume `pg_data` EBS üzerinde
- [ ] (Opsiyonel) Domain Route 53 veya başka registrar A record → Elastic IP
- [ ] `certbot --nginx` Let's Encrypt SSL ücretsiz
- [ ] CORS origins production domain veya AWS DNS hostname
- [ ] **Frontend:** `flutter build web` → GitHub Pages veya Cloudflare Pages
- [ ] `pg_dump` haftalık cron → S3 bucket (free tier 5 GB)
- [ ] `fail2ban`, ufw firewall (22/80/443)
- [ ] CloudWatch basic alarm: CPU > 90% veya disk > 80%

**Maliyet beklentisi (proje ömrü 5 ay):**
- 5 ay × $0 = **$0 toplam** (Free Tier dahilinde)
- Opsiyonel: Elastic IP unutulup `stop` edilirse 1¢/saat × 100 saat = ~$1 (önemsiz)
- Opsiyonel: Domain $8/yıl tek seferlik

**Kapanış adımları (proje 5. ayını dolduğunda):**

1. Final `pg_dump` indir, harici disk veya bulut'a sakla (academic record)
2. Frontend statik kopyası indirir (GitHub Pages otomatik kalır zaten)
3. `docker-compose down -v` ile container + volume sil
4. EC2 instance **terminate** (stop değil — disk bile silinsin)
5. ECR repositories delete
6. S3 bucket boşalt + delete
7. Elastic IP release et (release etmezsen $0.005/saat charge başlar)
8. AWS hesabını **kapatma**: opsiyonel; sadece kapatmayı bırak, free tier
   biterse zaten servisler durdurulmuştur

Önemli: Elastic IP'yi release etmeyi unutma — proje kapandıktan sonra
"unutulmuş kaynak" yüzünden $5-10 birikebilir.

**Önkoşul:** S1-S4 local'de tamamen test edilip çalışıyor olmalı.

**Fallback (AWS sorun olursa):**
- Render free tier (web service, 750 saat/ay, 15dk inaktiflik sonrası uyur — demo öncesi "uyandır")
- Fly.io free tier (3× shared-cpu-1x VM, 256 MB her biri — küçük)
- Oracle Cloud Always Free (ARM, multi-arch build derdi var, $0 süresiz — proje uzun sürerse)

---

## ✅ KARARLAR (2026-05-17 finalize)

| # | Karar | Sonuç | Not |
|---|---|---|---|
| 1 | Climatology skor formülü | **Multi-criteria** (capacity_factor + Weibull k + variance + grid proximity) | S1 sprint detayında. Manisa karakter doğru yansır. |
| 2 | ~~Score recompute stratejisi~~ | **GEÇERSİZ** — Recompute yok, 6 ayda bir refresh | Climatology statik. Pin generation history dinamik. |
| 3 | Terrain tile kaynağı | **AWS Terrain CDN** (terrarium PNG, ücretsiz) | Sunucu yükü yok, CDN tarayıcıya doğrudan |
| 4 | Backend yükseklik API | **Open-Meteo Elevation** + 7 gün Redis cache | Frontend AWS Terrain, backend Open-Meteo — paralel kullanım |
| 5 | OSM roads filtresi | **motorway + trunk + primary** (~200 MB) | RES için il yolu kontrolü de dahil |
| 6 | PostgreSQL seed dağıtım | **Şema + climatology + restricted_*** dahil dump (~400 MB), hourly_weather scheduler'dan dolar | İlk açılışta gerçek climatology kullanılabilir, "veri yok" diyemez |
| 7 | Docker image registry | **AWS ECR** (AWS ekosistemi içinde tutarlı, Free Tier 500 MB/ay) | GitHub Actions → ECR push otomasyonu. Image ~200 MB → free tier sıfır masraf. |
| 8 | Deploy hedefi | **AWS EC2 t2.micro Free Tier (12 ay)** + PostgreSQL Docker | Proje 2-5 ay aktif kalacak (kullanıcı planı 2026-05-17), Free Tier süresi fazlasıyla yeter. Tek mimari (x86_64), multi-arch Docker karmaşası YOK. |

---

## 🚀 Önerilen Başlangıç Sırası

Senin önceliklerinle benim teknik gereksinim sıralamamın **kesişimi**:

1. **S1** önce (3-5 gün) — Verinin doğru akması; her şeyin tabanı.
2. **S2** (1 hafta) — 3D + DEM'den kurtulma; **kullanıcının 1. isteği**. Tek başına çekici demo.
3. **S3** (1-2 hafta) — OSM PostGIS + Pin Validation; suitability gerçek hale geliyor.
4. **S4** (3-5 gün) — Docker production-ready; **kullanıcının 3. isteği**. S3 sonrası tüm statik veri PostGIS'te → Docker temiz.
5. **S5** → **S6** → **S7** (sonra, vakit ve enerjiye göre).

Eğer deploy aceleyse: **S1 → S4 → S2/S3** sırası da olur (önce stabil base, sonra özellikler).

---

## 📝 Yazma Kuralları

- Bu doküman **canlı**. Her sprint sonunda burayı güncelle:
  - Sprint başlığına `✅ TAMAM (YYYY-MM-DD)` ekle
  - Eğer plan değişti → "Karar Geçmişi" altına 1 satır not düş
  - Kabul kriterlerini check (`[x]`)
- Sprint sırasında atomik notlar yaz: `docs/knowledge/srrp-knowledge/concepts/<KavramAdı>.md`
- INBOX'a sprint başlangıcı + bitişi için **2 satır** kayıt yeterli (büyük sprint kayıtları burada).

## 🔗 Bağlantılar

- [[INBOX]] — günlük punch-list (aktif item'lar burada)
- [[PROJECT-OVERVIEW]] — proje vizyonu
- [[PLAN-2026-04-19-to-23]] — geçmiş sprint planı (Faz 1-3)
- `SRRP_DEVELOPMENT_ROADMAP.md` (kök) — uzun vadeli faz haritası
- [[WeatherRouter]] — choropleth + hourly endpoint detayı
- [[SuitabilityChecks]] — tip-aware uygunluk kuralları (frontend tarafı)
- [[AdvancedSettings]] — Sprint A backend bağlantı detayı (tamam)
- [[PinFlowController]] — Pin sprint final mimarisi

---

## 📜 Karar Geçmişi

- **2026-05-17**: Plan oluşturuldu (Gürkan + Claude). 8 karar bekliyor.
- **2026-05-17 (v2)**: 8 kararın hepsi finalize edildi. **Önemli mimari değişiklik**:
  - S1 baştan yazıldı. Skor artık SÜREKLİ recompute değil — `province_analysis` deprecated.
  - Yeni model: **Climatology (statik, 6 ayda bir)** + **Pin Generation History (dinamik, saatlik)**.
  - Manisa örneği problemi çözüldü: 10+ yıllık ortalamadan iyi bölgeler doğru listelenir.
  - Deploy: AWS EC2 t2.micro Free Tier kararlaştırıldı (Hetzner alternatifi düştü).
- **2026-05-17 (v3)**: "0$ maliyet prensibi" → Oracle Always Free önerildi
  (ARM, süresiz $0). Plan bu yönde güncellendi.
- **2026-05-17 (v4)**: Kullanıcı bilgisi: **Proje 2-5 ay aktif, sonra
  kapanacak**. Oracle Always Free gereksiz karmaşıklık (multi-arch Docker,
  ARM uyumluluk). **Geri AWS EC2 Free Tier 12 ay'a dönüldü** — x86_64 tek
  mimari, basit build. ECR registry kullanılacak. Kapanış adımları
  (terminate, Elastic IP release, S3 cleanup) S7 detayına eklendi.
- **2026-05-17 (v5)**: Gemini SDK migration tamamlandı (`google-generativeai`
  → `google-genai`). Backend AI teknik borcu kapandı, S1'e gidiş yolu açık.

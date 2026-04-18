# SRRP v2.0 — Kapsamli Gelistirme Yol Haritasi

**Proje:** Smart Renewable Resource Planner
**Hazirlayan:** Gurkan & Claude Code
**Tarih:** 1 Nisan 2026
**Durum:** Aktif Gelistirme
**Hedef:** Akademik MVP → Ticari Urun Donusumu

---

## MEVCUT DURUM OZETI

### Teknoloji Yigini
| Katman | Teknoloji | Durum |
|--------|-----------|-------|
| Frontend | Flutter (Web/Mobile/Desktop) | Aktif |
| Harita | MapLibre GL JS | Aktif |
| Backend | FastAPI 2.1.0 (Python 3.11+) | Aktif |
| Veritabani | PostgreSQL 16 + PostGIS 3.4 | Aktif |
| Onbellek | Redis 7 (+ in-memory fallback) | Aktif |
| Vektorel Harita | Martin Tile Server / PostGIS MVT | Aktif |
| Kimlik Dogrulama | JWT + Argon2 | Aktif |
| Veri Kaynagi | Open-Meteo API, OpenStreetMap | Aktif |
| Container | Docker Compose | Hazir (local test) |

### Backend Modulleri (13 Router, 11 Servis)
- **Pinler:** CRUD, analiz, batch re-analyze, finansal hesaplama
- **Hava Durumu:** Saatlik/gunluk/haftalik ozet, il/ilce bazli choropleth
- **Ruzgar Vektorleri:** Canli akis animasyonu (Windy tarzi v3)
- **Oneriler:** Weibull dagilimi bazli akilli bolge onerileri
- **Optimizasyon:** Turbin/panel yerlestirme optimizasyonu
- **Senaryolar:** Coklu senaryo olusturma ve karsilastirma
- **Raporlar:** Bolgesel enerji potansiyeli raporlari
- **Tile Server:** PostGIS MVT/PBF vektorel harita servisi
- **Cografi Analiz:** PostGIS tabanli uygunluk analizi
- **Hidro:** HES potansiyel hesaplamasi

### Frontend Modulleri (8 Ozellik)
- **Harita:** MapLibre GL JS, choropleth, ruzgar parcaciklari, 3D binalar
- **Pinler:** Ekleme/duzenleme/silme, detay analizi
- **Raporlar:** Il/ilce bazli enerji raporlari
- **Senaryolar:** Coklu senaryo yonetimi
- **Ayarlar:** Kullanici tercihleri
- **Giris:** Landing page (vitrin modu)
- **Yardim:** Kullanim kilavuzu
- **Kimlik:** Login/register

### Veritabani Boyutlari
| Tablo | Boyut | Kayit Sayisi (tahmini) |
|-------|-------|------------------------|
| hourly_weather_data | 8.27 GB | ~8.7M satir |
| weather_data | 937 MB | ~350K satir |
| energy_corridors | 205 MB | PostGIS geometri |
| hydro_features | 67 MB | PostGIS geometri |
| Diger (pins, users, vb.) | ~6 MB | Kucuk tablolar |
| **TOPLAM** | **~9.5 GB** | |

---

## FAZ 0: MEVCUT HATALARIN DUZELTILMESI

> **Oncelik: KRITIK — Diger fazlara gecmeden once tamamlanmali**

### 0.1 Ruzgar Parcaciklari (Canli Akis) — Ince Ayar
| Gorev | Durum | Detay |
|-------|-------|-------|
| v3 trail engine performans testi | Bekliyor | Telefonda ve bilgisayarda test |
| Zoom gecislerinde partikul surekliligi | Bekliyor | clearRect yaklasimiyla titreme yok ama gozle dogrula |
| Dense veri endpoint testi | Bekliyor | `/wind-vectors?dense=true` ~1000 nokta donuyor mu? |
| Renk paleti ince ayar | Bekliyor | Windy referansiyla karsilastir |

### 0.2 Veri Kalitesi Duzeltmeleri
| Gorev | Durum | Detay |
|-------|-------|-------|
| Ilce-il eslestirme hatalari | Bekliyor | Antakya→Hatay, Payas→Hatay, Andirin→K.Maras |
| Choropleth'te renksiz kalan ilceler | Bekliyor | Yanlis city_name → GeoJSON eslesmez |
| SQL duzeltme scripti yazimi | Bekliyor | `UPDATE hourly_weather_data SET city_name=...` |

### 0.3 UI/UX Duzeltmeleri
| Gorev | Durum | Detay |
|-------|-------|-------|
| Sidebar gorsel ince ayar (mobil) | Bekliyor | Mobil gorunumde panel boyutlari |
| Time slider optimizasyonu | Bekliyor | Animasyon modu performansi |
| Feature interaction handling | Bekliyor | Choropleth + wind + globe cakisma |

### 0.4 Bulut Ortusu (Cloud Layer) Fix
| Gorev | Durum | Detay |
|-------|-------|-------|
| Cloud layer opacity ayari | Bekliyor | 3D terrain aktifken bulut katmaninin dogru gorunmesi |
| Bulut verisi guncelleme sikligi | Bekliyor | Saatlik Open-Meteo cloud_cover ile senkron |
| Toggle ile acma/kapama | Bekliyor | Layers panelindeki mevcut toggle'in dogru calismasi |

### 0.5 Il Sinirlari Varsayilan Gorunurluk Fix
| Gorev | Durum | Detay |
|-------|-------|-------|
| Baslangicta il sinirlari gorunsun | Bekliyor | Harita yuklendiginde il sinirlari varsayilan acik |
| Ilce sinirlari zoom seviyesine gore | Bekliyor | Zoom >8 iken ilce sinirlari otomatik gorunsun |
| Sinir cizgi stili iyilestirme | Bekliyor | Daha belirgin, ince ve temiz cizgiler |

### 0.6 Global Projeksiyon Tasarimi
| Gorev | Durum | Detay |
|-------|-------|-------|
| Globe modu state yonetimi | Bekliyor | Turkiye disina cikinca harita davranisi |
| Turkiye disi pin engelleme | Bekliyor | Kullanici sadece Turkiye'ye pin koyabilsin |
| Zoom-out siniri | Bekliyor | Maksimum zoom-out seviyesi belirlenmesi |
| Globe → flat gecis animasyonu | Bekliyor | Yaklastikca projection degisimi |

> **Not:** Global projeksiyon tasarimi Faz 0'da planlanir, uygulama Faz 1'de yapilir.

---

## FAZ 1: 3D HARITA VE GORSEL IYILESTIRMELER

> **Sure Tahmini: 1-2 hafta**

### 1.1 MapLibre 3D Terrain Aktivasyonu
| Gorev | Dosya | Detay |
|-------|-------|-------|
| Terrain source ekleme | `index.html` | `map.addSource('terrain-dem', { type: 'raster-dem', url: '...' })` |
| setTerrain cagirma | `index.html` | `map.setTerrain({ source: 'terrain-dem', exaggeration: 1.5 })` |
| Sky layer ekleme | `index.html` | Atmosfer efekti (Google Earth hissi) |
| DEM toggle entegrasyonu | `layers_panel.dart` | Mevcut DEM toggle'i terrain'e bagla |
| Exaggeration slider | `layers_panel.dart` | Kullanici yukseklik abartmasini ayarlayabilsin |
| Terrain tile kaynagi secimi | Config | AWS Terrain (ucretsiz, sinirsiz) veya MapTiler |

**Performans Notu:** Terrain tile'lari CDN'den gelir, sunucuya yuk bindirmez. 30 kullanici bile sorun degil.

### 1.2 Yerel DEM Dosyalarinin Kaldirilmasi
| Gorev | Dosya | Detay |
|-------|-------|-------|
| `geo_service.py` DEM bagimliligi | `geo_service.py` | `_get_terrain_data()` → Open-Meteo Elevation API |
| 785 MB .tif dosyalarini sil | `backend/data/dem/` | Artik gereksiz |
| `.gitignore` guncelle | `.gitignore` | `backend/data/dem/` ekle |

### 1.3 Harita Gorsel Iyilestirmeleri
| Gorev | Detay |
|-------|-------|
| Gece/gunduz modu | Harita stilini saate gore degistir |
| Bulut katmani iyilestirmesi | Mevcut cloud layer'in 3D terrain ile uyumu |
| Pin'lerin 3D araziye oturmasi | Terrain aktifken pin'ler yukseklige gore konumlansin |

---

## FAZ 2: KISITLAMA SISTEMI (Kirmizi/Yesil Bolgeler)

> **Sure Tahmini: 2-3 hafta**

### 2.1 PostGIS Kisitlama Veritabani

**Yeni Tablolar:**

| Tablo | Geometri | Veri Kaynagi | Tahmini Boyut |
|-------|----------|-------------|---------------|
| `restricted_water` | Polygon | OSM water_a | ~55 MB |
| `restricted_roads` | LineString | OSM roads (otoyol/devlet yolu) | ~200 MB (filtrelenmis) |
| `restricted_parks` | Polygon | Tabiat Varliklari / IUCN | ~10 MB |
| `restricted_military` | Polygon | Kamu verisi (sinirli) | ~2 MB |
| `restricted_airports` | Polygon (buffer) | OSM aeroway | ~1 MB |
| `urban_centers` | Polygon | OSM admin boundaries | ~50 MB |
| `power_substations` | Point | OSM power=substation | ~5 MB |
| `power_lines` | LineString | OSM power=line | ~30 MB |

**Toplam ek veri:** ~350 MB (PostGIS'te)

### 2.2 Pin Validation Endpoint

```
POST /pins/validate
Body: { "lat": 37.5, "lon": 32.1, "type": "solar" }

Response:
{
  "suitable": true,
  "score": 78,
  "blockers": [],
  "warnings": [
    { "type": "slope", "message": "Egim %22 — kurulum maliyeti artabilir", "severity": "medium" }
  ],
  "details": {
    "elevation": 1250,
    "slope": 22,
    "nearest_road_m": 450,
    "nearest_water_m": 3200,
    "nearest_substation_km": 12.5,
    "land_use": "tarimsal"
  }
}
```

### 2.3 Frontend Entegrasyonu
| Gorev | Detay |
|-------|-------|
| Pin ekleme dialogunda validation sonucu goster | Blocker varsa pin eklenemez |
| Uyari badge'leri | Sari/kirmizi uyari ikonlari |
| Kisitlama katmani toggle | Haritada kirmizi bolgeler gosterilsin |
| MVT tile olarak kisitlama gorsellestirme | PostGIS → tile server → harita katmani |

---

## FAZ 3: UYGUNLUK SKORU MOTORU

> **Sure Tahmini: 3-4 hafta**

### 3.1 Multi-Criteria Skor Hesaplama

**Gunes Paneli Skoru (0-100):**

| Faktor | Agirlik | Veri Kaynagi | Hesaplama |
|--------|---------|-------------|-----------|
| Yillik GHI ortalamasi | %30 | hourly_weather_data | kWh/m²/yil |
| Sicaklik etkisi | %10 | hourly_weather_data | >25°C → verim dususu |
| Egim (guney yonlu ideal) | %10 | Elevation API | 5-15° guney = 100 puan |
| Bulutluluk varyansi | %5 | hourly_weather_data | Dusuk varyans = kararli |
| Sebeke mesafesi | %15 | PostGIS substations | <5km = 100, >20km = 0 |
| Ulasim erisimi | %10 | PostGIS roads | Yakin ama ustunde degil |
| Arazi duzlugu | %10 | Elevation API | Duz ova = kolay kurulum |
| Arazi kullanimi | %10 | PostGIS landuse | Tarimsal/bos = uygun |

**Ruzgar Turbini Skoru (0-100):**

| Faktor | Agirlik | Veri Kaynagi | Hesaplama |
|--------|---------|-------------|-----------|
| Ort. ruzgar hizi (100m) | %30 | hourly_weather_data | m/s → puan egrisi |
| Ruzgar surekliligi | %15 | hourly_weather_data | Weibull k parametresi |
| Yon tutarliligi | %10 | hourly_weather_data | Sirkulasyon analizi |
| Mevsimsel varyans | %5 | hourly_weather_data | Yaz-kis farki dusuk = iyi |
| Sebeke mesafesi | %15 | PostGIS substations | Ayni |
| Egim | %10 | Elevation API | Tepe ustu ideal |
| Turbulans riski | %10 | Toporafya + ruzgar | Dag arkasi kotu |
| Bos alan yeterliligi | %5 | PostGIS landuse | Turbin araligi hesabi |

**Hidroelektrik Skoru (0-100):**

| Faktor | Agirlik | Veri Kaynagi | Hesaplama |
|--------|---------|-------------|-----------|
| Debi potansiyeli | %25 | Nehir yakinligi + yagis | PostGIS + weather |
| Dusu yuksekligi | %25 | Elevation API | 2 nokta arasi fark |
| Gol olusma alani | %15 | Vadi morfolojisi | DEM + toporafya |
| Yillik yagis kararliligi | %10 | weather_data | Kuraklik riski |
| Cevre hassasiyeti | %10 | PostGIS restricted | Koruma alani yakinligi |
| Ulasim | %15 | PostGIS roads | Ekipman tasima imkani |

### 3.2 Grid Bazli Pre-Compute
| Gorev | Detay |
|-------|-------|
| 1km × 1km grid olustur | Turkiye uzerinde ~500K hucre |
| Her hucre icin skor hesapla | Cron job: haftada 1 kez |
| Sonuclari PostgreSQL'e kaydet | `grid_scores` tablosu |
| MVT tile olarak servis et | Heatmap katmani |

### 3.3 Onerilen Bolgeler Paneli v2
| Gorev | Detay |
|-------|-------|
| Grid skorlarini haritada goster | Yesil→sari→kirmizi heatmap |
| Il/ilce bazli siralama | "En iyi 10 ilce" listesi |
| Faktor dokumu | "Neden bu skor?" aciklamasi |
| Enerji tipine gore filtreleme | Gunes/ruzgar/HES ayri haritalar |

### 3.4 AHP (Analytic Hierarchy Process) Sihirbazi
| Gorev | Detay |
|-------|-------|
| Ikili karsilastirma wizard'i | "Sebeke mesafesi mi onemli, ruzgar hizi mi?" — kullanici secer |
| Tutarlilik kontrolu (CR < 0.1) | Kullanicinin cevaplari tutarsizsa uyari ver |
| Otomatik agirlik hesaplama | AHP matrisinden faktor agirliklarini cikart |
| Profil kaydetme | "Yatirimci profili", "Cevreci profil" gibi hazir setler |
| Faz 3.1 ile entegrasyon | AHP agirliklari → multi-criteria skor hesaplamaya aktar |

---

## FAZ 4: FINANSAL KATMAN

> **Sure Tahmini: 2-3 hafta**

### 4.1 Gelismis Finansal Hesaplamalar
| Metrik | Formul | Durum |
|--------|--------|-------|
| LCOE | Toplam Omur Boyu Maliyet / Toplam Uretim | Yeni |
| NPV | Iskontolu nakit akisi toplami | Mevcut (iyilestirilecek) |
| IRR | NPV=0 yapan iskonto orani | Yeni |
| Geri Odeme | CAPEX / Yillik Net Gelir | Mevcut |
| YEKDEM Geliri | Uretim × Garanti Fiyat (10 yil) | Mevcut |
| Karbon Kredisi | CO2 tasarrufu × Borsa fiyati | Yeni |
| OPEX Tahmini | Bakim + Sigorta + Arazi kirasi | Mevcut (iyilestirilecek) |

### 4.2 Sebeke Baglanti Maliyeti
| Gorev | Detay |
|-------|-------|
| En yakin trafo mesafesi | PostGIS ST_Distance |
| OG kablo maliyeti hesabi | mesafe × birim fiyat → CAPEX'e ekle |
| Trafo kapasitesi kontrolu | Kapasite asimi uyarisi |

### 4.3 EPIAS Entegrasyonu (Opsiyonel)
| Gorev | Detay |
|-------|-------|
| Spot piyasa fiyatlari API | EPIAS/EXIST verileri |
| Arbitraj stratejisi | Ucuz saatte depola, pahali saatte sat |
| Gelir projeksiyonu | Saatlik uretim × saatlik fiyat |

---

## FAZ 5: YAPAY ZEKA VE ML OZELLIKLERI

> **Sure Tahmini: 4-6 hafta**

### 5.1 AI Chatbot Entegrasyonu

> **Not:** 15 Nisan 2026 sonrasi baslanmasi planlanmisti — tarih gecti, baslanabilir.

| Gorev | Detay |
|-------|-------|
| LLM secimi | Gemini API (ucretsiz tier) veya Claude API |
| Chatbot backend servisi | `ai_chat_service.py` |
| Chatbot frontend widget'i | Harita ekraninda sag altta floating button |
| Baglam bilincliligi | Pin verisi, hava durumu, skor bilgisi chatbot'a iletilir |

**Chatbot Kullanim Senaryolari:**

```
Kullanici: "Konya'da gunes paneli icin en iyi ilce neresi?"
Bot: "Konya'nin en yuksek GHI degerine sahip ilcesi Cihanbeyli
      (5.2 kWh/m²/gun). Egim %3, sebeke mesafesi 8km.
      Uygunluk skoru: 87/100. Pin eklemek ister misiniz?"

Kullanici: "Bu pin neden dusuk skor aldi?"
Bot: "Pin #42 (Artvin, Yusufeli) — Skor: 34/100
      Dusuk sebep: Egim %45 (cok dik), sebeke 28km uzakta,
      yillik GHI 3.1 kWh/m²/gun (ortalamanin altinda).
      Ancak HES potansiyeli yuksek: debi tahmini 12 m³/s."

Kullanici: "Ruzgar turbini icin 5 milyon TL butcem var, nereye kurmaliyim?"
Bot: "Butcenize gore 2.5 MW turbin onerilir.
      En iyi 3 bolge: 1) Bandirma (kapasite faktoru %38),
      2) Canakkale (CF %35), 3) Sinop (%33).
      Geri odeme suresi: Bandirma 4.2 yil, Canakkale 4.8 yil.
      Detayli finansal rapor olusturayim mi?"
```

### 5.2 ML Tabanli Uretim Tahmini

| Gorev | Detay |
|-------|-------|
| Model secimi | XGBoost (hizli, az veri) veya LSTM (zaman serisi) |
| Egitim verisi | 1+ yillik hourly_weather_data |
| P50/P90 tahminleri | Ortalama ve kotu senaryo projeksiyonlari |
| `ml_projection_placeholder.dart` → gercek widget | Frontend grafik entegrasyonu |
| Mevsimsel decomposition | STL veya Prophet ile trend/sezon/artik ayrimi |

### 5.3 Akilli Oneriler Motoru (AI-Powered)
| Gorev | Detay |
|-------|-------|
| Kullanici profili analizi | Hangi pinleri nereye koyuyor, ne tercih ediyor |
| Proaktif oneri | "Bu bolgeye ruzgar yerine gunes daha verimli" |
| Anomali tespiti | "Bu pinin uretim tahmini beklenenden %30 dusuk" |
| Karsilastirma | "Senaryonuz A, B'den %15 daha karli" |

### 5.4 Iklim Degisikligi Senaryolari (Ileri Seviye)
| Gorev | Detay |
|-------|-------|
| IPCC RCP 4.5 / 8.5 verileri | Gelecek projeksiyonlari |
| "2050'de bu bolge" simulasyonu | Sicaklik/yagis/ruzgar degisim etkisi |
| HES kuraklik riski | Yillik yagis azalma projeksiyonu |

### 5.5 Predictive Maintenance (Ongorucu Bakim)
| Gorev | Detay |
|-------|-------|
| Bolgesel cevre analizi | Tuzluluk (deniz yakinligi), toz yogunlugu, nem orani |
| Panel kirlilik modeli | Toz + nem + sicaklik → temizleme sikligi tahmini |
| Turbin asinma modeli | Ruzgar hizi + turbulans + tuz → bakim takvimi |
| Bakim takvimi onerisi | "Bu bolgede panelleri ayda 1 temizle, turbin yaglamasi 6 ayda 1" |
| Maliyet etkisi | Bakim ihmalinin verim dususune etkisi (%) |

---

## FAZ 6: SUNUCU TASIMA (DEPLOYMENT)

> **ONEMLI: Tum ozellikler local'de test edilip dogrulandiktan sonra!**

### 6.1 On Kosullar (Local Test)
| Kontrol | Detay |
|---------|-------|
| Tum ozellikler local'de calisiyor | Manuel test listesi |
| Coklu kullanici testi | 2-3 farkli tarayici/cihazdan ayni anda |
| Hata yakalama | Error boundary'ler, backend exception handling |
| Performans | Choroplethi 3 saniyede yukle, pin analizi 5 saniyede |
| Guvenlik | JWT token suresi, CORS ayarlari, SQL injection kontrolu |

### 6.2 Sunucu Secimi
| Secenk | Fiyat | Ozellik | Oneri |
|--------|-------|---------|-------|
| Hetzner CX22 | ~$5/ay | 2 vCPU, 4 GB RAM, 40 GB SSD | Baslangic icin ideal |
| Hetzner CX32 | ~$9/ay | 4 vCPU, 8 GB RAM, 80 GB SSD | Buyume asamasi |
| Contabo VPS S | $7/ay | 4 vCPU, 8 GB RAM, 50 GB SSD | Alternatif |
| Oracle Free | $0 | 4 OCPU, 24 GB RAM (ARM) | Bulabilirsen en iyi |

### 6.3 Deployment Mimarisi

```
                    Internet
                       |
                    Nginx (SSL/Reverse Proxy)
                    /          \
        Flutter Web           /api/* → Uvicorn
        (statik)              (FastAPI backend)
                                  |
                         PostgreSQL + PostGIS
                                  |
                              Redis Cache
                                  |
                         Cron (veri guncelleme)
```

### 6.4 Deployment Adimlari
| Adim | Komut/Islem | Dikkat |
|------|-------------|--------|
| 1. VPS olustur | Hetzner panel | Ubuntu 22.04 LTS |
| 2. Docker kur | `apt install docker.io docker-compose` | |
| 3. PostgreSQL + Redis | `docker-compose up -d` | Mevcut docker-compose.yml |
| 4. DB migration | `alembic upgrade head` | |
| 5. Veri aktarimi | `pg_dump` → `pg_restore` | ~5 GB, scp ile transfer |
| 6. Backend deploy | Docker build + systemd | Auto-restart |
| 7. Frontend build | `flutter build web` → nginx | Statik dosya |
| 8. SSL sertifikasi | `certbot --nginx` | Let's Encrypt (ucretsiz) |
| 9. Domain ayarla | DNS A record → VPS IP | |
| 10. CORS guncelle | `main.py` origins | Domain adi ekle |
| 11. Cron kurulumu | `crontab -e` | Saatlik veri cekme |
| 12. Monitoring | `htop`, `journalctl`, disk alarm | |

### 6.5 Sunucu Guvenligi
| Onlem | Detay |
|-------|-------|
| SSH key authentication | Sifre ile girisi kapat |
| Firewall (ufw) | Sadece 80, 443, 22 portlari ac |
| fail2ban | Brute-force korumasi |
| Otomatik yedekleme | Haftada 1 pg_dump → harici depolama |
| Rate limiting | Nginx'te API rate limit |
| Swap ekleme | 2 GB swap → OOM korumasi |
| Log rotation | `logrotate` → disk dolmasini onle |

### 6.6 Dikkat Edilecek Noktalar
| Konu | Sorun | Cozum |
|------|-------|-------|
| API Base URL | Frontend `localhost` → sunucu domain | `.env` veya config dosyasi |
| CORS | Cross-origin istekler engellenir | Domain'i origins listesine ekle |
| HTTPS | HTTP'de geolocation/kamera calismaz | Let's Encrypt SSL |
| Zaman dilimi | Sunucu UTC, Turkiye UTC+3 | `timezone.utc` kullan (zaten oyle) |
| RAM | Buyuk sorgularda OOM | Swap + sorgu optimizasyonu |
| Open-Meteo limit | Gunluk 10K istek | Cron araligini ayarla |
| Disk dolmasi | PostgreSQL + loglar buyur | Log rotation + eski veri temizligi |
| Cold start | Backend ilk baslangicta yavas | Preload + health check |

---

## FAZ 7: ILERI SEVIYE OZELLIKLER

> **Sure: Uzun vadeli (3-6 ay)**

### 7.1 Profesyonel PDF Raporlama
- Kapak sayfasi, yonetici ozeti
- Finansal tablolar, teknik analiz
- Harita gorselleri (ekran goruntusu)
- Yasal riskler, uygunluk analizi
- 15-20 sayfa, bankaya sunulabilir kalite

### 7.2 Enerji Depolama (Batarya ESS)
- Li-Ion / LFP boyutlandirma
- "Gunesiz/ruzgarsiz gecen maks. sure" (Autonomy Days)
- Batarya kapasitesi (kWh) ve maliyet tahmini

### 7.3 Yuk Profili (Tuketim Analizi)
- Ev, fabrika, tarimsal sulama profilleri
- Uretim-tuketim egrisi ortusme orani (Self-Consumption Rate)
- Fazla uretimi sebekeye sat / bataryaya depola

### 7.4 Drone Ucus Rotasi Planlayicisi
- Haritada poligon secimi
- .kml / .gpx cikti
- Arazi egimine uygun irtifa planlamasi

### 7.5 Yatirumci Vitrini (Social Layer) — Opsiyonel
- Projeleri "Yatirimci Ariyorum" etiketiyle yayinlama
- Anonim veya acik paylasim

### 7.6 Yuzer GES (Floating Solar)
- Baraj golu yuzeyinde panel yerlestirme simulasyonu
- Buharlaşma tasarrufu hesabi (gol yuzeyinin kapatilma orani → su tasarrufu)
- HES + Yuzer GES hibrit senaryo (ayni barajda ikisi birden)
- Dalga ve ruzgar etkisi analizi (gol yuzey kosullari)
- Ozel CAPEX/OPEX hesabi (yuzer platform maliyeti dahil)

### 7.7 Uydu Destekli Cati Analizi (Computer Vision)
- OpenCV ile uydu/hava fotografindan cati siniri tespiti
- Cati alani hesabi (m²) ve yon analizi (guney/bati/dogu)
- Golge analizi (komsu bina, agac golgeleri)
- Panel yerlestirme optimizasyonu (kac panel sigar)
- Uretim tahmini (cati alani × verim × GHI)

### 7.8 Design System v2.0 (Scientific Glassmorphism)
- Tutarli dark mode temasi (tum ekranlar)
- Neon vurgu renkleri (enerji tipine gore: sari=gunes, mavi=ruzgar, yesil=HES)
- Glassmorphism kartlar ve paneller
- Animasyonlu veri gecisleri (fade, slide, scale)
- Responsive grid sistemi (mobil/tablet/desktop)
- Bilimsel grafik stili (eksen etiketleri, birim gosterimi, legend)

---

## SILINECEK / TASINACAK DOSYALAR

### Silinecekler
| Dosya/Klasor | Boyut | Sebep |
|-------------|-------|-------|
| `backend/data/dem/*.tif` | 785 MB | MapLibre terrain + Elevation API yeterli |
| `backend/data/vector/gis_osm_buildings_*` | 1.7 GB | MapLibre 3D buildings zaten CDN'den |
| `backend/data/vector/gis_osm_roads_*` | 1.1 GB | Harita base layer CDN'den |
| `backend/tamdb/` | 1.7 GB | Eski SQLite yedekleri |
| `backend/data/user_data.db` (0 byte) | 0 | Bos dosya |
| `backend/database.db` | 196 KB | Eski SQLite |
| `backend/srrp_dev.db` | 152 KB | Eski gelistirme DB |
| `backend/user_pins_data.db` | 64 KB | Eski SQLite |
| **TOPLAM TASARRUF** | **~5.3 GB** | |

### PostGIS'e Tasinacaklar
| Dosya | Boyut | Hedef Tablo |
|-------|-------|-------------|
| `gis_osm_water_a_free_1.*` | 58 MB | `restricted_water` |
| `gis_osm_landuse_a_free_1.*` | 513 MB | `land_use_zones` |
| `gis_osm_natural_*` | 26 MB | `natural_features` |
| `gis_osm_railways_*` | 5.8 MB | `restricted_railways` |

### Sunucuya Gidecek Veriler
| Biles | Boyut |
|-------|-------|
| PostgreSQL dump (6 ay kirpilmis) | ~5.2 GB |
| GeoJSON dosyalari (provinces + districts) | ~38 MB |
| Flutter web build | ~30 MB |
| Backend kaynak kodu | ~2 MB |
| **TOPLAM** | **~5.3 GB** |

---

## GELISTIRME ONCELIK SIRASI

```
SIMDI          FAZ 0: Bug fix'ler ve ince ayarlar
  |               - Ruzgar parcaciklari v3 test
  |               - Veri kalitesi duzeltmeleri
  |               - UI/UX duzeltmeleri
  |               - Bulut ortusu fix
  |               - Il sinirlari fix
  |               - Global projeksiyon tasarimi
  v
1-2 HAFTA      FAZ 1: 3D Terrain + Gorsel iyilestirmeler
  |               - MapLibre setTerrain()
  |               - DEM dosyalari silme
  |               - Harita atmosfer efektleri
  |               - Global projeksiyon uygulamasi
  v
2-3 HAFTA      FAZ 2: Kisitlama Sistemi
  |               - PostGIS kisitlama tablolari
  |               - Pin validation endpoint
  |               - Kirmizi bolge gorsellestirme
  v
3-4 HAFTA      FAZ 3: Uygunluk Skoru Motoru
  |               - Multi-criteria hesaplama
  |               - Grid bazli pre-compute
  |               - Heatmap katmani
  |               - AHP sihirbazi (kullanici agirlik tercihi)
  v
2-3 HAFTA      FAZ 4: Finansal Katman
  |               - LCOE, IRR, karbon kredisi
  |               - Sebeke baglanti maliyeti
  v
4-6 HAFTA      FAZ 5: Yapay Zeka
  |               - AI Chatbot
  |               - ML uretim tahmini
  |               - Akilli oneriler
  |               - Predictive maintenance
  v
[LOCAL TEST]   Tum ozellikler dogrulanir
  |            Coklu kullanici testi yapilir
  |            Hatalar yakalanir ve duzeltilir
  v
1 HAFTA        FAZ 6: Sunucu Tasima
  |               - VPS kurulumu
  |               - Docker deployment
  |               - SSL + Domain
  |               - Monitoring
  v
UZUN VADE      FAZ 7: Ileri ozellikler
                  - PDF rapor, ESS, yuk profili
                  - Drone planlama, yatirimci vitrini
                  - Yuzer GES, cati analizi (CV)
                  - Design System v2.0
```

---

## YAPAY ZEKA ENTEGRASYON NOKTALARI (Ozet)

| Modul | AI Kullanimi | Faz |
|-------|-------------|-----|
| **Pin Analizi** | "Bu pin neden dusuk skor aldi?" aciklamasi | Faz 5 |
| **Onerilen Bolgeler** | Kullanici tercihine gore dinamik oneri | Faz 5 |
| **Chatbot** | Dogal dille soru-cevap, komut verme | Faz 5 |
| **Uretim Tahmini** | ML model ile P50/P90 projeksiyon | Faz 5 |
| **Anomali Tespiti** | "Bu veri normal degil" uyarisi | Faz 5 |
| **Senaryo Karsilastirma** | "A senaryosu B'den %15 daha karli" | Faz 5 |
| **Iklim Projeksiyonu** | 2050 iklim senaryolari | Faz 7 |
| **Predictive Maintenance** | Tuzluluk/toz/nem bazli bakim takvimi onerisi | Faz 5 |
| **AHP Sihirbazi** | Kullanici tercihlerinden otomatik agirlik hesaplama | Faz 3 |
| **Rapor Olusturma** | AI destekli rapor metni yazimi | Faz 7 |
| **Cati Analizi (CV)** | OpenCV ile uydu fotografindan cati tespiti | Faz 7 |

---

> **ALTIN KURAL:** "Bilgisayarda gorup test etmeden sunucuya yukleme!"
> Tum fazlar local'de tamamlanip, coklu kullanici testinden gecip,
> hatalar yakalanip duzeltildikten sonra sunucuya geçilecek.

---

*Bu dokuman SRRP projesinin canli gelistirme yol haritasidir ve her faz tamamlandikca guncellenecektir.*

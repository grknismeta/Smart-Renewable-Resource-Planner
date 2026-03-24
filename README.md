# 🌍 SRRP — Smart Renewable Resource Planner

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![MapLibre](https://img.shields.io/badge/MapLibre-4A90E2?style=for-the-badge&logo=maplibre&logoColor=white)

**Smart Renewable Resource Planner (SRRP)**, Türkiye genelinde yenilenebilir enerji kaynaklarının (güneş, rüzgar, hidroelektrik) planlanmasına, enerji çıktılarının tahminine ve yatırım geri dönüş (ROI/Maliyet) analizine yardımcı olan gelişmiş bir coğrafi bilgi sistemi (GIS) uygulamasıdır.

Bu proje, açık kaynaklı hava durumu verileri ile coğrafi verileri birleştirerek yatırımcılara ve araştırmacılara yüksek hassasiyetli bölgesel analiz imkanı sunar.

---

## ⚡ Temel Yetenekler

* **Kapsamlı Veri Ağı:** Türkiye'deki 81 il ve yaklaşık 960 ilçe için geçmişe dönük ve güncel saatlik hava durumu verisi (rüzgar, güneş ışınımı, sıcaklık vb.).
* **Gelişmiş Harita Deneyimi:** MapLibre GL JS tabanlı, vector tile mimarisiyle çalışan detaylı 3D harita (`raise-on-hover` il sınırları ve `fill-extrusion` bina modları).
* **Isı Haritaları (Heatmaps):** Güneş, rüzgar ve sıcaklık potansiyelini bölgesel düzeyde görselleştirmek için dinamik ısı haritası katmanları.
* **Pin / Santral Yönetimi:** Harita üzerinde santral konumlandırma, kapasite belirleme ve spesifik lokasyon analizleri yapabilme (CRUD işlemleri ile).
* **Dinamik Navigasyon:** İl, ilçe veya bölge bazlı filtrelemeler ve `drill-down` görünümleri ile Türkiye haritasında kolay dolaşım.
* **Analiz ve Raporlama:** İller/ilçeler arası potansiyel sıralamaları, istatistik karşılaştırmaları, verimlilik skor hesaplamaları ve PDF/Excel çıktı desteği.
* **Yüksek Performans:** PostgreSQL/PostGIS, Martin Vector Tile Server, Redis Cache (ve in-memory fallback) ve asenkron FastAPI altyapısı sayesinde devasa hava durumu verilerinde (~10M+ kayıt) milisaniyelik gecikme ile çalışma yeteneği.

---

## 🛠️ Teknoloji Yığını

* **Frontend:** Flutter (Web ve Native Masaüstü/Mobil destekli)
* **Harita Motoru:** MapLibre GL JS (`flutter_maplibre` üzerinden arayüz bağlantısı)
* **Basemap Sağlayıcı:** OpenFreeMap Liberty (Vector Tile)
* **Backend:** Python + FastAPI (Asenkron mimari, Uvicorn)
* **Veritabanı:** PostgreSQL + PostGIS eklentisi (Coğrafi sorgular ve vektör üretimi için)
* **ORM ve Migration:** SQLAlchemy 2.x (Async) ve Alembic
* **Tile Sunucusu:** Martin Tile Server (PostGIS'ten doğrudan .mvt - Mapbox Vector Tile üretimi)
* **Önbellek (Cache):** Redis & In-Memory Fallback mekanizması
* **Dış Veri Kaynakları:**
  * Hava/İklim Verileri: Open-Meteo Archive API
  * Sınır Koordinatları: OpenStreetMap (OSM) / Overpass API

---

## 🚀 Kurulum ve Çalıştırma

Projenin çalışabilmesi için sisteminizde **Flutter SDK**, **Python 3.11+**, **PostgreSQL/PostGIS** ve **Martin Tile Server** kurulu olmalıdır.

### 1. Backend (FastAPI) Kurulumu

```bash
cd backend
python -m venv venv

# Windows için sanal ortamı aktif etme
venv\Scripts\activate

# Bağımlılıkları yükleme
pip install -r requirements.txt
```

`.env` dosyanızı aşağıdaki örneğe göre oluşturun:
```env
DATABASE_URL=postgresql+asyncpg://kullanici:sifre@localhost/srrp
REDIS_URL=redis://localhost:6379
```

Veritabanını oluşturun ve sunucuyu başlatın:
```bash
alembic upgrade head           # Şema güncellemelerini eşitle
uvicorn app.main:app --reload  # API'yi port 8000'de başlat
```

### 2. Martin Tile Server'ı Başlatma

Harita katmanlarını oluşturmak için Martin sunucusunu ayar dosyasıyla çalıştırın:
```bash
martin --config martin_config.yaml  # port 3000
```

### 3. Frontend (Flutter) Kurulumu

```bash
cd frontend
flutter pub get

# Web tarayıcısında çalıştırmak için (JS MapLibre entegrasyonu ile):
flutter run -d chrome

# Native masaüstü uygulaması olarak çalıştırmak için:
flutter run -d windows
```

> **Veri Toplama:** Projenin içerisindeki hava durumu verilerini güncellemek için backend içerisindeki scriptler (örn: `python -m app.services.collectors.hourly`) manuel veya cron job olarak ayarlanabilir.

---

## 📁 Mimari ve Klasör Yapısı

Sistem, Flutter tabanlı istemcinin asenkron Python tabanlı API ve PostGIS/Martin üzerinden doğrudan akış alan harita altyapısı ile haberleştiği, tamamen ayrıştırılmış bir mimaride kurgulanmıştır.

```text
smart_renewable_resource_planner/
├── SRRP_DOC.md               # Detaylı Mimari ve Proje Dokümantasyonu (Ana Kaynak)
├── SPRINT_CHANGELOG.md       # Tamamlanan sprint'ler ve test süreçleri
├── martin_config.yaml        # Vektör tile sunucu ayarları
├── frontend/                 # Flutter uygulama dizini
│   ├── lib/core/             # Ağ katmanı, tema ve servisler
│   ├── lib/features/         # Harita görünümü, pinler ve veri vizüalizasyonu
│   └── web/                  # MapLibre JS köprü betikleri
└── backend/                  # FastAPI sunucu dizini
    ├── app/routers/          # Hava durumu, analiz, pin API endpoint'leri
    ├── app/services/         # Veri toplayıcılar, ızgara analizi, önbellek modülleri
    ├── app/db/               # SQLAlchemy modelleri
    └── scripts/              # Veritabanı ve koordinat bakım scriptleri
```

---

## 🗺️ Yol Haritası (Roadmap)

- **ML Entegrasyonu:** Enerji üretim tahminleri için LSTM / XGBoost algoritmalarının veri modellerine entegre edilmesi.
- **HES Modülü:** Hidroelektrik enerji santrali modellerinin haritaya eklenmesi.
- **LCOE ve ROI:** Levelized Cost of Energy hesaplamaları ve yatırımın geri dönüş süresinin detaylı modellenmesi.
- **Cloud Deployment:** Projenin tüm servislerinin (DB, Martin, API, Frontend) Dockerlaştırılarak AWS/Railway üzerinde yayına alınması.
- **AI Chatbot Destekli Asistan:** Kullanıcıların sistem veri tabanını doğal dil ile analiz edebilmesi için bir LLM entegrasyonu.

---

## 📖 Daha Fazla Dokümantasyon

Mimari kararlar, sprint kayıtları, bilinen sorunlar ve API detayları hakkında en çok güncellenen ve yaşayan döküman için repo içerisindeki [**SRRP_DOC.md**](./SRRP_DOC.md) dosyasına göz atabilirsiniz.

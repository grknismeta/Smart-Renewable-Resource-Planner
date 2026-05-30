# Sprint R0 — Colab Veri Çekme (İlçe granüler, sadece EKSİK veri)

## 🎯 Felsefe — DB'de ZATEN olan veriyi tekrar çekme

| Veri | Mevcut yer | Yeniden çekiyor muyuz? |
|---|---|---|
| temperature_2m | `hourly_weather_data` (2 yıl) + `climatology.avg_temperature_10y` | ❌ Hayır |
| wind_speed_10m / 100m | `hourly_weather_data` + `climatology.avg_wind_speed_10y` | ❌ Hayır |
| shortwave_radiation | `hourly_weather_data` + `climatology.hourly_typical_profile` (12×24) | ❌ Hayır |
| precipitation (2 yıl) | `hourly_weather_data.precipitation` | ⚠️ 10 yıl seri için yeniden çek |
| cloud_cover (2 yıl) | `hourly_weather_data.cloud_cover` | ⚠️ 10 yıl seri için yeniden çek |
| **Wind direction histogramı (8 yön × aylık)** | — | ✅ YENİ (climatology'de yok) |
| **Sunshine duration** | — | ✅ YENİ |
| **River discharge** | — | ✅ YENİ |

## 📋 3 Notebook

| Notebook | Çeker | Çıktı | Süre |
|---|---|---|---|
| **A** `A_open_meteo_hourly.py` | hourly: wind_direction_10m + cloud_cover | `wind_direction_histogram.csv` + `monthly_cloud_cover.csv` | ~40-55 dk |
| **B** `B_open_meteo_daily.py` | daily: precipitation_sum + sunshine_duration | `climate_monthly.csv` | ~5-10 dk |
| **C** `C_open_meteo_flood.py` | daily: river_discharge | `river_discharge_monthly.csv` | ~15-25 dk |

**940 ilçe × 10 yıl (2015-2024)** · Hepsi Open-Meteo ücretsiz API'leri · 2820 toplam call, 10k günlük kotanın altında.

## 🚀 Çalıştırma — Tek tıkla, dış dosya yok

940 ilçe centroidi script'in başına **gzip+base64 olarak gömülü** (17KB). JSON yükleme YOK.

### Tek adım:
1. https://colab.research.google.com → **Yeni notebook**
2. A/B/C scriptlerinden birinin **TÜM İÇERİĞİNİ** kopyala → boş hücreye yapıştır → **Ctrl+Enter**
3. Log her 50 ilçede bir satır basar. Süre dolunca CSV otomatik indirilir.

### Paralel için 3 tab:
- **2 ek Colab sekmesi** aç → birine A, diğerine C yapıştır
- B'yi önce tek başına test et, sonra A ve C paralel çalışsın

## ✅ DOĞRULAMA — Önce B (en hızlı)

R0'a tam başlamadan **B notebook**'unu tek başına çalıştır (~5-10 dk):
1. `climate_monthly.csv` indir
2. **Spot check** (CSV açıp ara):
   - **Konya/Karapınar** Temmuz `sunshine_hours_month` ≈ **350-400** olmalı
   - **Rize/Pazar** Ekim/Kasım `precip_mm` ≈ **150+** olmalı
   - **Konya/Karapınar** Aralık `precip_mm` ≈ **20-40** olmalı (kuru iç anadolu)
3. CSV'yi bana gönder → format doğru ise A ve C'yi de çalıştır

## 📂 Beklenen 4 CSV (toplam ~10-15 MB)

```
wind_direction_histogram.csv    # province, district, month (0=yıllık, 1-12), direction (N..NW), freq_pct
monthly_cloud_cover.csv          # province, district, month, cloud_cover_pct
climate_monthly.csv              # province, district, year, month, precip_mm, sunshine_hours_month
river_discharge_monthly.csv      # province, district, year, month, discharge_mean_m3s, discharge_min_m3s, discharge_max_m3s
```

## 🏞️ Nehirler stratejisi

**Soru:** 940 ilçenin hepsinde river_discharge mantıklı mı? Hayır, çoğu sıfır olacak (karasal ilçeler nehre uzak). Ama yine de **hepsini çekiyoruz** çünkü:
- Süre maliyeti düşük (~15-25 dk)
- Post-process'te `discharge_mean_m3s < 1.0` olanları "düşük HES potansiyeli" işaretliyoruz
- Karadeniz/Doğu Anadolu/Güneydoğu ilçelerinin gerçek nehir debisi alınır

**Sanity check (script sonunda otomatik basar):** En yüksek 20 ilçenin debi listesi — Yusufeli/Borçka/Tortum/Pazar/Çamlıhemşin gibi HES bölgelerini görmelisin.

### Pin-level on-demand (R3'te)
Kullanıcı HES pin oluşturduğunda backend pin'in **exact koordinatından** Open-Meteo Flood live çeker (Redis cache, 7 gün TTL). İlçe centroidi gibi karada değil, gerçek nehir noktası → daha sağlıklı.

### Güncellik
- Open-Meteo Flood = **Copernicus GloFAS** modeli, günlük güncellenir, 5 günlük forecast da var
- DSİ AGİ (Akım Gözlem İstasyonu) gerçek verileri **kapalı** (PDF yıllık raporlar)
- Yani Türkiye için **modeled** veri — gerçeğe yakın ama tek açık seçenek
- Kullanıcı HES pin formunda `flow_rate` field'ında **manuel override** ekleyebilir (saha ölçümü varsa)

## 🛠️ Sorun çıkarsa

- **`Connection reset / 429 / 503`** — Otomatik retry (2/4/8s backoff). Hata devam ederse CONCURRENT'i azalt (A: 5→3, B/C: 8→4).
- **`memory error`** — A scripti en ağır. Her ilçe işlendikçe raw data atılıyor, OOM olmamalı. Olursa batch'e bölerim (söyle).
- **`files.download` çalışmadı** — Sol panel 📁 → CSV'ye sağ tık → İndir.

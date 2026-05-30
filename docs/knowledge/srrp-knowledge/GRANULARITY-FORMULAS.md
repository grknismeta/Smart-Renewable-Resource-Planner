---
tags: [concept, formula, granularity, backend, ml]
updated: 2026-05-28
related: [INDEX, PLAN-2026-05-27-IZOHIPS-ML, PLAN-2026-05-28-ML-CLIMATE-PROJECTION, BACKEND-PLAN-2026-05-17]
---

# 📐 Veri Granülerlik & Hesaplama Formülleri

> **Kullanıcı sorusu (2026-05-27):**
> "Verilerin bazıları saatlik, bazıları günlük olduğu için, hesaplama yaparken
> buna uygun bir formül sağlamalıyız. Ne yapalım?"
>
> Cevap: 3 farklı freq elimizde, **kullanım yerine göre doğru kaynağı seç,
> eksikte fallback'e in**. Bu doküman karar ağacı + formül + örnek.

---

## 🗂️ Veri Katmanları

| Tablo / Alan | Freq | Süre | Boyut | Doluluk |
|---|---|---|---|---|
| `hourly_weather_data` | **Saatlik** | 2 yıl (Open-Meteo Archive + Live) | ~8 GB | Yer odaklı; tüm Türkiye değil |
| `climatology.monthly_*` | **Aylık** | 10-yıl ortalaması (2015-2024) | 162 row | 81 il × 2 kaynak = tam |
| `climatology.avg_*_10y`, `capacity_factor` | **Yıllık** (statik) | 10 yıl ort. | 162 row | Tam |
| `pins.installation_date` + `pin_generation_history` | **Pin-bazlı saatlik** | install_date → bugün | Kullanıcı pin sayısına göre | Sadece aktif pinler |

### Hangi sütunlar nerede?

**`hourly_weather_data` saatlik:**
- `temperature_2m_c`, `wind_speed_10m`, `wind_speed_100m`
- `shortwave_radiation_wm2`, `cloud_cover_pct`, `precipitation_mm`
- `wind_direction_10m` (eski) — yeni veri `wind_direction_histogram` ile aylık

**`climatology` aylık JSON:**
- `monthly_precipitation` [12 değer mm]
- `monthly_sunshine_hours` [12 değer saat/ay]
- `monthly_cloud_cover` [12 değer %]
- `monthly_river_discharge` [12 değer m³/s]
- `wind_direction_histogram` `{0: {N,NE,E,...}, 1-12: {...}}` (0=yıllık)
- `hourly_typical_profile` `{month_idx: {hour: value}}` (12 ay × 24 saat — solar irradiance default ay profili)

**`climatology` yıllık statik:**
- `avg_temperature_10y`, `avg_wind_speed_10y`, `avg_solar_irradiance_10y`
- `score_climatology` (kaynak-içi 0-100 normalize, H5)
- `capacity_factor` (kaynak başına)

---

## 🧭 Karar Ağacı — Hangi Kaynak Ne Zaman?

```
                ┌─────────────────────────────┐
                │ İhtiyacın resolution nedir? │
                └──────────────┬──────────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
        Saatlik             Aylık              Yıllık
        (live)            (Reports)          (Finans/CF)
            │                  │                  │
            ▼                  ▼                  ▼
   ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
   │ hourly_weather   │ │ climatology      │ │ capacity_factor  │
   │ son 24-48 saat   │ │ monthly_* JSON   │ │ × 8760 × MW      │
   └──────────────────┘ └──────────────────┘ └──────────────────┘
            │                  │                  │
            ▼ (yoksa)          ▼ (yoksa)
   monthly profile      annual / 12 (düz)
            │
            ▼ (yoksa)
   annual / 8760 (düz)
```

---

## 📊 Kullanım Yerleri & Formüller

### 1. ⚡ Anlık Üretim (Santral Tab "Bugün" KPI)

**Hedef**: Şu anda pin ne kadar üretiyor?

```
ÖNCELİK 1 — hourly_weather_data son 24h
  ↓ pin.city + pin.district eşleşmesi (province_aliases ile)
  ↓ son 24h timestamp filtrle
  ↓ pin_type'a göre formül:
    GES:  P_kW = G × A × η × PR    (G: shortwave_radiation W/m², A: panel area, η: efficiency, PR: 0.85)
    RES:  P_kW = 0.5 × ρ × A_rotor × v³ × Cp × η  (v: wind_speed_100m)
    HES:  P_kW = ρ × g × Q × H × η  (Q: flow_rate, H: head_height)

FALLBACK — climatology.hourly_typical_profile[ay][saat] × CF × capacity_mw
ÜCÜNCÜ — capacity_mw × 1000 × CF (yıllık ortalama saatlik güç)
```

**Mevcut backend kod**: `backend/app/services/pin_generation_service.py` `compute_pin_generation()`

---

### 2. 📅 Aylık Üretim (Reports stacked bar)

**Hedef**: Pin / il / bölge için 12-ay üretim dağılımı.

```
GES:  annual_kwh × monthly_sunshine_hours[m] / Σ monthly_sunshine_hours
RES:  annual_kwh / 12   (climatology'de aylık wind speed yok → düz dağılım)
HES:  annual_kwh × monthly_river_discharge[m] / Σ monthly_river_discharge
```

**Mevcut backend kod**: `backend/app/routers/scenario.py` `_monthly_distribution(pin, resource)` (P1/4)

**Örnek**: Konya GES 10 MW, CF=0.18:
- `annual_kwh = 10 × 1000 × 0.18 × 8760 = 15,768,000 kWh`
- Konya monthly_sunshine = [186, 197, 245, 273, 339, 363, 393, 359, 296, 248, 192, 165]
- Toplam = 3,156 saat
- Temmuz payı = 393/3156 = %12.5
- Temmuz üretim = 15,768,000 × 0.125 = **1,966,000 kWh**

---

### 3. 💰 Yıllık Üretim (Finans, CAPEX/NPV/IRR)

**Hedef**: Tek sayı — yıllık ortalama üretim.

```
annual_kwh = capacity_mw × 1000 × capacity_factor × 8760
```

- `capacity_factor`: climatology'den **statik** (10-yıl ortalaması)
  - Solar Türkiye ort.: 0.15-0.22 (Akdeniz/İç Anadolu yüksek, Karadeniz düşük)
  - Wind Türkiye ort.: 0.20-0.40 (Trakya/Ege yüksek)
  - Hydro: 0.30-0.55 (debi sürekliliğine göre)

**Mevcut backend kod**: `backend/app/routers/scenario.py` `_climatology_capacity_factor(pin, resource)`

---

### 4. 🗓️ Senaryo Hesap (Kullanıcı tarih aralığı)

**Hedef**: `start_date` → `end_date` arası toplam üretim.

```
Range içindeki tam aylar için aylık üretim formülü
+ Kısmi ilk/son ay için interpolasyon (gün sayısına göre)
+ HES için sezon ağırlıklı (kış pik debi)
```

**Mevcut backend kod**: `backend/app/routers/scenario.py` `calculate_scenario()`. 
**N1 değişimi**: `end_date` null → bugüne kadar üretmeye devam (open-ended).

---

### 5. 🌬️ Wind Rose (Reports)

**Hedef**: Yön histogramı — hangi yönden ne kadar rüzgar geliyor?

```
ÖNCELİK — climatology.wind_direction_histogram[0]  (yıllık ortalama)
ALT-DETAY — climatology.wind_direction_histogram[1..12]  (aylık)
FALLBACK — mock (uniform 12.5% her yön)
```

**Mevcut frontend**: `WindRoseCard` (climate_widgets.dart).
**Veri**: 2026-05-27 R0 import sonrası gerçek (162 il satırı dolu).

---

### 6. 🧠 ML Forecast (P1 Sprint, gelecekte)

**Hedef**: Pin/il için 1-10 yıl gelecek tahmin.

```
INPUT  : climatology.monthly_* (10 yıl × 12 ay = 120 datapoint)
MODEL  : SARIMAX(p,d,q)(P,D,Q,12)  (auto_arima ile order seçimi)
OUTPUT : 60 ay forecast + ±2σ confidence interval

ÖNEMLİ — saatlik veri ML'e VERME:
  - 2 yıllık veri kısa (~17,520 satır)
  - Gürültülü (saatlik random fluctuation)
  - ML overfit eder
```

Pin için pin_generation_history kullanılır (kullanıcı pin'i için saatlik
agregat → aylık). En az 12 ay veri yoksa **il climatology trend fallback**.

> **⚠️ BİRİM TUTARLILIĞI (2026-05-28 fix)** — climatology fallback'i KULLANIRKEN
> climatology metriği (güneşlenme **saati**, nehir **debisi**) doğrudan kWh
> sayılMAZ; yalnızca **mevsimsel şekil** olarak kullanılır. Gerçek enerji
> büyüklüğü `_expected_annual_kwh = capacity_mw × 1000 × 8760 × CF`
> (solar 0.18 / wind 0.32 / hydro 0.45 — `DEFAULT_CAPACITY_FACTOR_FALLBACK`).
> `_rescale_climatology_to_energy` forecast point'lerini bu yıllık toplama
> ölçekler, aylık dağılımı korur. Rüzgar için aylık iklim metriği olmadığından
> (bkz. Sorun 2) düz 1/12 dağılım. Aksi halde 1 MW pin ~3.700 kWh/yıl gibi
> ~400× düşük çıkar (eski bug). Kod: `ml_sarimax_service._climatology_fallback`.
> Finansal projeksiyon (`project_pin_financial`) bu doğru kWh'ı kullanır.

---

## 🔍 Granülerlik Mismatch'leri & Çözüm

### Sorun 1: GES aylık dağılımı tutarsız

**Belirti**: Solar'ın aylık üretiminde 12 ay birbirine yakın çıkıyor (mantık yanlış).
**Sebep**: `monthly_sunshine_hours` boş — fallback `annual / 12` (düz dağılım).
**Çözüm**: R0 CSV import çalıştırılmış (✅ tamam). 81 il dolu.

### Sorun 2: RES aylık dağılımı eşit

**Belirti**: Kış-yaz rüzgar farkı yok (RES için kış güçlü olmalı).
**Sebep**: Climatology'de aylık `wind_speed` profili yok (sadece histogramı yön).
**Çözüm önerisi** (gelecek sprint):
- Open-Meteo Archive'den aylık wind speed avg çek (Türkiye 940 ilçe × 12 ay = 11,280 satır)
- Climatology'e `monthly_wind_speed` JSON kolonu ekle (Migration)
- `_monthly_distribution(pin, "wind")` → `monthly_wind_speed[m]³` ile ağırlıkla
  (kübik çünkü güç ~v³)

### Sorun 3: HES barajlı vs nehir tipi

**Belirti**: Aynı debi/düşü ile hesaplama yapılıyor ama barajlı reservoir'a sahip.
**Sebep**: `calculate_annual_hydro_production` tip detection var (`plant_type` field).
**Çözüm**: Mevcut kod tipini doğru tespit ediyor (head≥100 OR basin≥100 → barajlı).

### Sorun 4: ML'e saatlik mi aylık mı veri ver?

**Cevap**: **Aylık.** Saatlik veri:
- ML overfit eder (yüksek gürültü)
- 2 yıl × 8760 = 17,520 datapoint çok büyük, train yavaş
- Climate trend için aylık 10-yıl seri daha temiz

**Uzun yıllarda** (10+ yıl saatlik veri toplandıkça) → LSTM/Transformer modelleri saatlik veriyi avantajlı kullanabilir, ama o ayrı sprint (P3 sonrası).

---

## 🛠️ Kod Tarafı — Helper Fonksiyon (Q2.2)

Yakında ekleyeceğimiz `generation_resolver.py`:

```python
def resolve_generation(
    pin: Pin,
    period_start: date,
    period_end: date,
    target_freq: Literal["hourly", "monthly", "yearly"],
) -> dict:
    """Granülerlik-aware üretim kaynak seçimi.

    Karar mantığı:
      hourly:  hourly_weather_data → climatology hourly_typical → annual/8760
      monthly: monthly_aggregate(hourly) → climatology monthly_* → annual/12
      yearly:  capacity × CF × 8760 → climatology yıllık ortalama
    """
    if target_freq == "hourly":
        return _resolve_hourly(pin, period_start, period_end)
    elif target_freq == "monthly":
        return _resolve_monthly(pin, period_start, period_end)
    else:
        return _resolve_yearly(pin, period_start, period_end)
```

Bu, `scenario.py`, `pin_generation_service.py`, gelecekteki `ml_projection_service.py`
hepsinin **tek kaynaktan beslenmesini** garanti eder. Tutarsızlık biter.

---

## 📋 Kabul Kriterleri (Granülerlik fix tam yapıldığında)

- ✅ Reports'ta her grafik üzerinde "Saatlik 2y" / "Aylık 10y" / "Yıllık CF" rozet (Q3)
- ✅ `generation_resolver.py` mevcut, `scenario.py` ve `pin_generation_service.py` kullanıyor (Q2.2)
- ✅ ML model **sadece aylık veri** ile train edilir (P1)
- ⏳ `monthly_wind_speed` climatology'e eklenir (gelecek sprint, opsiyonel)

---

## 🔗 Bağlı Notlar
- [[BACKEND-PLAN-2026-05-17]] — backend mimari
- [[PLAN-2026-05-27-IZOHIPS-ML]] — aktif sprint
- [[INBOX]] — kullanıcı feedback'leri

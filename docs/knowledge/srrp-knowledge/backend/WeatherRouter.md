---
tags: [backend, api, endpoint]
updated: 2026-04-18
related: [ChoroplethScales, MapLayerMixin]
file: backend/app/routers/weather.py
---

# WeatherRouter (`/api/weather/*`)

Hava durumu verileri için FastAPI router. Choropleth, summary, animation endpoint'lerini barındırır.

## Ana Endpoint'ler

| Endpoint | Amaç |
|---|---|
| `GET /api/weather/choropleth?mode=temperature|wind|solar` | İlçe bazlı ısı haritası verisi |
| `GET /api/weather/summary` | Tüm iller için özet (heatmap için) |
| `GET /api/weather/{city_name}/history` | Belirli ilin son 24 saat geçmişi |
| `GET /api/weather/{city_name}/latest` | Belirli ilin son kaydı |
| `GET /api/weather/animation/{metric}` | Animasyon için frame bazlı veri |

## 🔑 Choropleth Global Timestamp Kuralı

Choropleth endpoint'i için **tek bir global `MAX(timestamp)`** kullanılır — her ilçeye ayrı değil.

### Neden?

Eski yaklaşımda per-district `MAX(timestamp)` hesaplanıyordu:
```python
# ESKI (Sorunlu)
for dist in districts:
    row = query.filter(district=dist).order_by(ts.desc()).first()
```

- Bazı ilçelerde 12:00'ın verisi, bazılarında 13:00'ın verisi → batı ile doğu tutarsız renkler
- Özellikle solar için `> 0` filtresi + timezone kayması büyük boşluk yaratıyordu

### Güncel Yaklaşım

```python
global_max_ts = db.query(func.max(HourlyWeatherData.timestamp))\
    .filter(HourlyWeatherData.district_name.isnot(None))\
    .scalar()

rows = db.query(...).filter(
    HourlyWeatherData.timestamp == global_max_ts
).all()
```

Tüm ilçeler için **aynı saatin** verisi döner. Bazı ilçelerde o saatin verisi yoksa ilçe sonuçta yer almaz (beyaz görünür).

## Response Formatı

```json
{
  "İstanbul|Kadıköy": {
    "temperature_2m": 18.4,
    "wind_speed_100m": 12.3,
    "shortwave_radiation": 450
  },
  "İstanbul|Beşiktaş": { ... },
  ...
  "_meta": {
    "data_timestamp": "2026-04-18T14:00:00+03:00",
    "solar_timestamp": "2026-04-18T13:00:00+03:00"
  }
}
```

### `_meta` Alanı

Frontend tooltip'te "X dk/saat önce güncellendi" göstermek için kullanılır ([[MapScreen#_formatTimestamp]]).

- `data_timestamp`: Ana choropleth veri zamanı (ISO 8601)
- `solar_timestamp`: Solar için ayrı (solar günün belli saatlerinde 0 → ayrı max alınır)

Key separator `"İl|İlçe"` — Türkçe karakter + `|` ile unique composite. Frontend parse eder.

## Solar Timestamp Özel Durumu

Güneş ışınımı gece 0'dır. Global `MAX` alırken tüm ilçelerde gece değerleri 0'sa o saat döner, yanlış "0 W/m²" gösterilir.

Çözüm: Solar için **ayrı** global timestamp — `shortwave_radiation > 0` olan son saat. `_meta.solar_timestamp` olarak döner.

## `HourlyWeatherData` Model

```python
class HourlyWeatherData:
    id              # PK
    timestamp       # UTC saat
    city_name       # İl adı (NAME_1 eşleşir)
    district_name   # İlçe adı (NAME_2 eşleşir)
    latitude, longitude
    temperature_2m      # Sıcaklık (°C)
    wind_speed_10m      # 10m rüzgar (m/s)
    wind_speed_100m     # 100m rüzgar (m/s) — türbin yüksekliği
    shortwave_radiation # Solar (W/m²)
    # + diğer OpenMeteo alanları
```

## Provider: OpenMeteo

Veri kaynağı Open-Meteo (`open-meteo.com`). Saatlik batch job'lar çeker, `HourlyWeatherData` tablosuna yazar.

Reference coords → her ilçe için referans bir lat/lon koordinatı kullanılır (ilçe merkezi veya centroid).

## İnvariant'lar

1. ⚠️ **Choropleth global timestamp** — per-district değil. Aksi halde doğu-batı tutarsızlığı.
2. ⚠️ **`district_name.isnot(None)`** — ilçe bazlı query'lerde null district'leri filtrele (il-only kayıtlar var).
3. ✅ **`_meta` her zaman dahil** — frontend bu alana güvenir.
4. ⚠️ **Timezone**: Backend UTC'de saklar, `MAX(timestamp)` UTC döner. Frontend `_formatTimestamp` göreli hesapta sorun olmaz.

## Bilinen Tuzaklar

- ⚠️ **Solar filter frontend'de değil backend'de**: `> 0` filtresi frontend stops'ta zaten karanlık gösterdiği için gereksiz. Backend global timestamp'e karışmasın.
- ⚠️ **Eksik ilçeler**: Bazı ilçelerde coord yanlış olup veri çekilemedi (örn. Antakya → Adana bounding box'a yanlış atandı). [[project_future_features#Veri Kalitesi]].
- ⚠️ **Cache**: Backend'de Redis/memcache yok, her request SQL'e gider. Frontend `MapLayerMixin`'de 60sn cache var.

## Performans

Global timestamp query + tek `SELECT` → ~1000 ilçe için tipik 50-100ms.

Optimizasyon gerekirse:
- `timestamp` alanına index (zaten var olmalı)
- Materialized view (son saatin özetini tutan)
- Redis cache (backend seviyesinde)

## Son Değişimler

- **2026-04-18**:
  - Per-district `MAX(timestamp)` → global `MAX(timestamp)` geçişi
  - `_meta.data_timestamp`, `_meta.solar_timestamp` eklendi
  - Solar için ayrı timestamp (günün güneşli son saati)

## Bağlantılar

- [[ChoroplethScales]] — frontend renk skalaları
- [[MapLayerMixin]] — frontend cache + refresh *(yapılacak)*
- [[MapScreen]] — tooltip tüketicisi

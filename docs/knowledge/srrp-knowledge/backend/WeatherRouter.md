---
tags: [backend, api, endpoint]
updated: 2026-04-22
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

## 🔑 Choropleth — Per-District Latest Timestamp Kuralı

Choropleth endpoint'i (`/district-choropleth?mode=latest`) için **her ilçe kendi en son saatine** göre dönüş üretir. Tek global timestamp kullanılmaz.

### Neden?

**1. tur (yanlış çözüm — 2026-04-18):** Per-district `MAX(timestamp)` loop yerine tek `global_max_ts` kullanıldı. Düşünce: "aynı saat = tutarlı". Ama:

**2. tur (kök sebep — 2026-04-22):** Tek global saat **doğu-batı asimetrisine** yol açar:
- Türkiye 25°E–45°E → ~1h 20m güneş farkı.
- APScheduler saat başı tüm 81 il için fetch yapsa bile dalgalı (rate-limit); doğu ilçeleri batıdan 10–30 dk geç dolar.
- `WHERE timestamp == global_max_ts` → doğu ilçeleri o saati henüz tutmuyorsa **düşer** → "sol yükleniyor sağ yüklenmiyor".
- Solar'da daha da kötü: `global_solar_ts = max(ts WHERE radiation > 0)` → gün batımında batının son güneşli saati alınıyor, doğu karanlıkta = 0.

### Güncel Yaklaşım (per-district subquery join)

```python
# Her ilçenin en son saati
latest_per_district = (db.query(
    HourlyWeatherData.city_name.label("c"),
    HourlyWeatherData.district_name.label("d"),
    func.max(HourlyWeatherData.timestamp).label("max_ts"),
).filter(HourlyWeatherData.district_name.isnot(None))
 .group_by(HourlyWeatherData.city_name,
           HourlyWeatherData.district_name)
 .subquery())

rows = db.query(...).join(latest_per_district, and_(
    HourlyWeatherData.city_name == latest_per_district.c.c,
    HourlyWeatherData.district_name == latest_per_district.c.d,
    HourlyWeatherData.timestamp == latest_per_district.c.max_ts,
)).all()
```

Solar için ayrı subquery (`WHERE shortwave_radiation > 0`). Gece ilçeleri solar lookup'ta bulunmaz → `raw_solar = None` → frontend'de lacivert floor doğru.

Geri dönüş [[issues/2026-04-22-district-choropleth-east-west]].

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
    "data_timestamp": "2026-04-22T14:00:00+03:00",     // max(ilçe saatleri)
    "data_timestamp_min": "2026-04-22T13:00:00+03:00", // min (doğu ilçelerinin gecikmesi burada görülür)
    "solar_timestamp": "2026-04-22T13:00:00+03:00"     // max(gündüz saatleri)
  }
}
```

### `_meta` Alanı

Frontend tooltip'te "X dk/saat önce güncellendi" göstermek için kullanılır ([[MapScreen#_formatTimestamp]]).

- `data_timestamp`: Ana choropleth veri zamanı (ISO 8601)
- `solar_timestamp`: Solar için ayrı (solar günün belli saatlerinde 0 → ayrı max alınır)

Key separator `"İl|İlçe"` — Türkçe karakter + `|` ile unique composite. Frontend parse eder.

## Solar Timestamp Özel Durumu

Güneş ışınımı gece 0'dır. Frontend'de 0 W/m² = `#1a1a2e` lacivert floor (`[[ChoroplethScales]]`).

Per-district solar subquery `WHERE shortwave_radiation > 0` → her ilçenin kendi son **gündüz** saati. Gece ilçeleri subquery'den düşer → `raw_solar = None` → map'te lacivert kalır (doğru). `_meta.solar_timestamp` max alan → UI'da "gündüz verisi X dk önce" yazısı için.

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

1. ⚠️ **Per-district latest timestamp** — coğrafi olarak dağıtılmış veriye tek global saat filtresi uygulama; enlem farkı + fetch dalgası = yarı sonuç. Subquery join kullan.
2. ⚠️ **`district_name.isnot(None)`** — ilçe bazlı query'lerde null district'leri filtrele (il-only kayıtlar var).
3. ✅ **`_meta` her zaman dahil** — frontend bu alana güvenir. `data_timestamp` max, `data_timestamp_min` ilk fetch edilen ilçenin saati.
4. ⚠️ **Timezone**: Backend UTC'de saklar. Frontend `_formatTimestamp` göreli hesapta sorun olmaz.

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

- **2026-04-22**: Tek `global_max_ts` yaklaşımı **kaldırıldı** (doğu-batı asimetrisi kök sebebi). Her ilçe için `func.max(timestamp) GROUP BY (city, district)` subquery → join. Solar için de ayrı subquery (`radiation > 0`). Meta'ya `data_timestamp_min` eklendi. Bkz. [[issues/2026-04-22-district-choropleth-east-west]].
- **2026-04-18**:
  - Per-district loop `MAX(timestamp)` → tek global `MAX(timestamp)` geçişi (sonradan geri alındı — yukarı)
  - `_meta.data_timestamp`, `_meta.solar_timestamp` eklendi
  - Solar için ayrı timestamp (günün güneşli son saati)

## Bağlantılar

- [[ChoroplethScales]] — frontend renk skalaları
- [[MapLayerMixin]] — frontend cache + refresh *(yapılacak)*
- [[MapScreen]] — tooltip tüketicisi

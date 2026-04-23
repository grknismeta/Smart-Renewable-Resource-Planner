---
tags: [issue, resolved, backend, frontend, choropleth, faz1]
opened: 2026-04-22
resolved: 2026-04-22
severity: high
platform: web, backend
related: ["WeatherRouter", "ChoroplethScales", "PLAN-2026-04-19-to-23", "INBOX"]
---

# Işınım Choropleth Doğu-Batı Asimetrisi + Legend Uyuşmazlığı

## Belirti

Kullanıcı: _"Işınım haritasında hem renk uyuşmazlığı var hem de veri yüklenmesinde sorun var, sol taraf yükleniyor sağ taraf yüklenmiyor. Bunun bir limitleme ile ilgisi olabilir."_

1. Işınım (solar) katmanı açıldığında Türkiye'nin batısı renklenirken doğusu boş kalıyor.
2. Haritada gözüken renk legend'deki değerle uyuşmuyor (Antalya gerçekte ~500 W/m² civarı, legend 400 W/m²'yi maksimum gösteriyor).

## Kök Sebep (2 ayrı bug)

### 1. `weather.py /district-choropleth mode=latest` tek global timestamp

Eski mantık:
```python
global_max_ts = db.query(func.max(HourlyWeatherData.timestamp))...scalar()
# WHERE timestamp == global_max_ts  → sadece bu saati tutan ilçeler döner
```

Türkiye **enlem açıklığı ~20°** (25°E → 45°E ≈ **1h 20m** güneş farkı) + APScheduler fetch dalgası nedeniyle **doğudaki ilçeler her saat aynı timestamp'te veriye sahip değil**. "Tek global saat" filtresi → doğu ilçeleri düşer → harita yarı dolu.

Solar için ayrı `global_solar_ts = max(ts WHERE radiation > 0)` daha da kötü: gün batımında batıda güneş hâlâ varken doğu karanlıkta → global max daylight saat = batı'nın son güneşi → doğu'nun o saatteki radiation'ı **0**.

### 2. Frontend `map_screen.dart` solar legend paletle uyumsuz

Map paleti (`index.html` + `map_view_maplibre_native.dart` + `map_layer_mixin.dart`): **10 stop, 0–800 W/m², `#1a1a2e` lacivert başlangıç + `#4D0014` bordo son**.

Legend (`map_screen.dart:455`): 9 stop, **`#FFFFCC` soluk sarıdan** başlıyor (lacivert yok), `maxLabel:'400'` (yarı skala). Kullanıcı haritada orange gördü → legend'a baktı → "320–400" yazıyordu ama gerçek değer ~500.

## Çözüm

### 1. Per-district latest timestamp subquery

`_aggregate`/global timestamp kaldırıldı. Her ilçe için **kendi** en son saati:

```python
latest_per_district = db.query(
    HourlyWeatherData.city_name.label("c"),
    HourlyWeatherData.district_name.label("d"),
    func.max(HourlyWeatherData.timestamp).label("max_ts"),
).filter(HourlyWeatherData.district_name.isnot(None))
 .group_by(...).subquery()

rows = db.query(...).join(latest_per_district, and_(
    HourlyWeatherData.city_name == latest_per_district.c.c,
    HourlyWeatherData.district_name == latest_per_district.c.d,
    HourlyWeatherData.timestamp == latest_per_district.c.max_ts,
)).all()
```

Aynı yaklaşım solar için de (`WHERE shortwave_radiation > 0` filtreli ayrı subquery) — gece ilçeleri için lacivert floor korunur, gündüz ilçeleri kendi son gündüz saatini alır.

Meta alanı: tek `data_timestamp` yerine `data_timestamp` (max) + `data_timestamp_min` (min). İleri sürüm uyumu için `data_timestamp` max olarak bırakıldı.

### 2. Legend paletini 0–800 + lacivert başlangıçla hizala

`map_screen.dart` solar legend:
- 10 stop (map paletiyle birebir)
- İlk stop `Color(0xFF1A1A2E)` — gece/lacivert
- `maxLabel: '800'`, `tickLabels: ['0', '200', '400', '600', '800']`

## Doğrulama

- `python -m py_compile weather.py` → OK.
- `flutter analyze map_screen.dart` → "No issues found! (76.4s)".
- Kullanıcı web test: katman aç → Türkiye'nin tamamı renklensin, gece ilçeleri lacivert kalsın, gündüz ilçeleri sarı-turuncu-kırmızı gradyanıyla doğru eşleşsin.

## Tekrarlamamak İçin

- ⚠️ **"Tek global timestamp" anti-pattern'i**: Coğrafi olarak dağıtılmış bir veri kümesinde tek saat filtresi **enlem farkı + fetch dalgası** yüzünden kısmi sonuç üretir. Daima **per-entity latest** subquery kullan.
- ⚠️ **Legend ↔ map paleti parity**: 3 yerde (index.html, native dart, layer_mixin) palet tutarlıysa legend **4. yer** olarak unutulmamalı. Palet değişirse her 4 yeri aynı commit'te güncelle (bkz. [[ChoroplethScales]] kural notu).
- ⚠️ **Faz 2 migrasyonu**: Bu fix geçici. Asıl çözüm frontend'in `/analysis/choropleth/{metric}` endpoint'ine taşınması — 6 aylık ortalama skorla tek tutarlı sayı, timestamp karmaşası yok.

## Dosyalar

- `backend/app/routers/weather.py` — `/district-choropleth` mode=latest per-district subquery (~40 satır değişti, satır 1131–1235)
- `frontend/lib/features/map/screens/map_screen.dart` — solar legend palette 0–800 + lacivert start (satır 452–472)

## Bağlantılar

- [[WeatherRouter]]
- [[ChoroplethScales]]
- [[PLAN-2026-04-19-to-23]]
- [[issues/2026-04-22-analysis-service-bugs]] — aynı gün Faz 1 service bug serisi
- [[INBOX]]

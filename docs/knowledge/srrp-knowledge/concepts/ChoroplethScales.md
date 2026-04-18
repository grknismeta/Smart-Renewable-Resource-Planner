---
tags: [concept, choropleth, rendering]
updated: 2026-04-18
related: [WeatherRouter, MapLayerMixin, PlatformConsistency]
---

# Choropleth: Fizik Bazlı Sabit Renk Skalaları

Choropleth (ilçe bazlı ısı haritası) için adaptif yerine **sabit, fiziksel** skalalar kullanılır. Nedeni: kullanıcı iki farklı anı karşılaştırabilsin, renk değeri anlamlı kalsın.

## Önceki Yaklaşım (Geri Alındı)

Percentile-based (p10/p90) adaptif skalalama kullanılıyordu:
- Her request'te min/max veriye göre skalanın değişmesi
- "Bugün İstanbul sıcak (kırmızı)" vs "yarın kırmızı ama değerler daha düşük" → kullanıcı yanılır
- Sezonlar arası karşılaştırma imkansız

## Güncel: Sabit Fiziksel Skalalar

### Sıcaklık (`°C`, -15 → 45)
```
-15  → #08306B  (çok koyu mavi)
 -5  → #2171B5
  0  → #E0F3F8
  5  → #C6DBEF
 10  → #ABD9E9
 15  → #74ADD1
 20  → #66BD63  (donma noktası üstü → yeşil)
 25  → #A6D96A
 30  → #FEE08B
 33  → #FDAE61
 36  → #F46D43
 40  → #D73027
 45  → #A50026  (aşırı sıcak)
```

### Rüzgar (`m/s`, 0 → 25)
```
 0   → #F7FBFF  (sakin)
 2   → #DEEBF7
 4   → #C6DBEF
 6   → #9ECAE1
 8   → #6BAED6
10   → #4292C6
13   → #2171B5
16   → #08519C
20   → #083D7F
25   → #08306B  (fırtına)
```

### Güneş Işınımı (`W/m²`, 0 → 800)
```
  0  → #1a1a2e  (gece/kapalı)
 50  → #FFFFCC
150  → #FFEDA0
250  → #FED976
350  → #FEB24C
450  → #FD8D3C
550  → #FC4E2A
650  → #E31A1C
750  → #BD0026
800  → #4D0014  (maksimum ışınım)
```

## İmplementasyon

| Platform | Dosya | Fonksiyon |
|---|---|---|
| Web | `frontend/web/index.html` | `_choroplethBuildStops(mode)` |
| Native | `frontend/lib/features/map/viewmodels/map_layer_mixin.dart` | `_buildChoroplethPaint()` içinde |

Her iki tarafta **aynı stops** — platform tutarlılığı ([[PlatformConsistency]]) için.

## Backend Bağlantısı

Backend sadece ham değerleri döner, rengi uygulamaz. Bkz. [[WeatherRouter]].

Response:
```json
{
  "İstanbul|Kadıköy": { "temperature_2m": 18.4, "wind_speed_100m": 12.3, ... },
  ...
  "_meta": {
    "data_timestamp": "2026-04-18T14:00:00+03:00",
    "solar_timestamp": "2026-04-18T13:00:00+03:00"
  }
}
```

`_meta` alanı önemli — tüm ilçeler için **aynı saatin** verisi, tooltip'te "X dk/saat önce güncellendi" göstermek için kullanılır.

## Global Timestamp (Doğu-Batı Tutarlılığı)

**Eski sorun**: Her ilçe için `MAX(timestamp)` ayrı hesaplanıyordu → bazı ilçeler 12:00'daki veriyi, bazıları 13:00'daki veriyi gösteriyordu. Sonuç: batı ile doğu arasında yapay renk tutarsızlığı.

**Çözüm**: Tek bir global `MAX(timestamp)` → tüm ilçelere aynı saati uygula. Detay: [[WeatherRouter]].

## Choropleth Modları

```dart
enum ChoroplethMode { none, temperature, wind, solar }
```

- `none` → katman kapalı
- `temperature` → `temperature_2m` alanı
- `wind` → `wind_speed_100m` alanı (100m rüzgarı, türbin yüksekliği)
- `solar` → `shortwave_radiation` alanı

## İnvariant'lar

1. ✅ **Skala sabit** — runtime'da verilerden türetilmez. Fizikseldir.
2. ✅ **Her iki platform aynı stop'ları kullanır** — web JS ve native Dart senkron.
3. ⚠️ **Global timestamp zorunlu** — backend per-district değil, tek bir MAX uygular.
4. ⚠️ **Solar modunda `> 0` filtresi BACKEND tarafında uygulanmaz** — timestamp tutarsızlığı yaratıyordu. Frontend stops'taki 0 değeri karanlığı zaten gösterir.

## Tuzaklar

- ⚠️ **Yeni bir ölçüm eklerken stops yazılmalı**. Adaptif'e dönmek cazip gelebilir — yapma. Fiziksel anlamlı aralık bul (örn. nem için 0-100, bulut örtüsü için 0-1).
- ⚠️ **Cache**: Choropleth verisi `_choroplethCache` + `_choroplethCacheTime` ile 60 saniye cache'lenir. Yeni veri için `forceRefreshChoropleth()` çağır.
- ⚠️ **Renk stops değişirse iki platformu da güncelle**. Native'de unuttuysan web-native arasında tutarsızlık olur.

## Bağlantılar

- [[WeatherRouter]] — backend endpoint
- [[MapLayerMixin]] — choropleth cache + refresh *(yapılacak)*
- [[PlatformConsistency]]

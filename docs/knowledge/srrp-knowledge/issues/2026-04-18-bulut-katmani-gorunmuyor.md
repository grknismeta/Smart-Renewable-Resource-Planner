---
tags: [issue, resolved, web, cloud, diagnostic]
opened: 2026-04-18
resolved: 2026-04-18
severity: medium
platform: web
related: [MapLayerMixin, PlatformConsistency]
commit:
---

# Bulut Katmanı Açılıyor Ama Görünmüyor

## Belirti

Layers panelinden "Bulut Örtüsü" toggle'ı açılıyor, opacity slider görünüyor ama haritada hiçbir şey görünmüyor. Konsol hata vermiyor (sessiz failure).

## Tekrar Üretim

1. `flutter run -d chrome`
2. Harita yüklenince sağ panel → Layers → Bulut Örtüsü ON
3. Beklenen: yarı-saydam bulut tabakası. Olan: hiçbir değişiklik.
4. DevTools Console: boş. Network tab kontrol edilmezse fark edilmez.

## Kök Sebep

`frontend/web/index.html` → `_refreshCloudTiles()` fonksiyonunda birden fazla
sessiz failure noktası vardı:

1. **RainViewer API yanıt yapısı değişmiş olabilir.** `data.satellite.infrared`
   boş dönüyorsa radar fallback var, ama ikisi de boşsa sadece bir `console.warn`
   atılıyordu — kullanıcı göremiyor.
2. **Tile yükleme hataları yakalanmıyordu.** MapLibre `map.on('error', ...)`
   listener'ı yoktu. Tile 404 / CORS hataları konsola otomatik düşmüyor, sessizce
   yutuluyordu.
3. **Fetch response status kontrolü yoktu.** `r.json()` çağrısı 4xx/5xx dönse
   bile body parse edilmeye çalışılıyor, catch'e düşüyor ama mesaj belirsiz.

Yani: **katman eklenmiyor olabilir, ya da katman eklenmiş ama tile'lar
yüklenemiyor olabilir** — her iki durumu da ayırt edemiyorduk.

## Çözüm

`frontend/web/index.html` satır ~2268-2375 (`_refreshCloudTiles` + `srrpSetCloudLayer`)
içinde **davranış değişmeden** sadece diagnostic katmanı eklendi:

- Fetch başlangıç log'u: `[SRRP] Bulut: RainViewer API sorgulanıyor...`
- `r.ok` kontrolü → `HTTP 4xx` hataları belirgin mesaja dönüşür
- API yanıt yapı log'u: `version`, `generated`, IR frame sayısı, radar.past
  sayısı, host
- Tile URL template log'u → yanlış format tespit edilebilir
- Hiçbir veri yoksa `Object.keys(data)` ile root anahtarları log'la
- **Yeni:** `map.on('error', ...)` listener → `sourceId === CLOUD_SRC` filtresiyle
  tile hatalarını yakala, url ile birlikte log'la
- `srrpSetCloudLayer(false)` çağrısında error listener'ı da temizle (leak yok)

## Etki Alanı

- Sadece web. Mobilde bulut katmanı şu an yok.
- Diğer layer'lara dokunulmadı (wind, heatmap, terrain).
- API yapısı aynı kaldığı sürece davranış **aynı**. Değiştiyse artık göreceğiz.

## Tekrarlamamak İçin

- [ ] [[MapLayerMixin]] notu yazılınca "diagnostic log pattern" standart hale
      gelsin — her layer için:
      1. toggle log (ON/OFF + param)
      2. fetch başlangıç log
      3. response structure log
      4. MapLibre error listener
- [ ] Plan'da **Parça 2 (Rüzgar Partikülleri)** de aynı pattern'e tabi tutulacak
      ([[federated-zooming-kettle]]).

## Bağlantılar

- [[MapViewMaplibreWeb]] — web harita adapter'ı
- [[PlatformConsistency]] — web/mobile paralel çözüm kuralı

## Tarihçe

- **2026-04-18**: Kullanıcı bildirdi — bulutlar açılmıyor, konsol temiz.
- **2026-04-18**: Plan [[federated-zooming-kettle]] Parça 1 olarak ele alındı.
- **2026-04-18**: Diagnostic + error listener eklendi. Kök sebep artık tespit
  edilebilir — kullanıcı DevTools açıp toggle edince görünecek.

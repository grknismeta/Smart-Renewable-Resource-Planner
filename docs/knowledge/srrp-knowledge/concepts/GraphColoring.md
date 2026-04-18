---
tags: [concept, algorithm, rendering]
updated: 2026-04-18
related: [MapViewMaplibreNative, MapViewMaplibreWeb, SelectionModes]
---

# Graph Coloring (Komşu Polygon Renklendirme)

Harita üzerinde komşu il/ilçelerin birbirinden **farklı renk** almasını sağlayan algoritma. İki aşamalı: komşuluk tespiti + greedy renklendirme.

## Amaç

Türkiye'de bitişik iller (veya bitişik ilçeler) varsayılan olarak benzer renk alıyorsa kullanıcı sınırları ayırt edemez. Graph coloring problemi gibi çözülür: komşular farklı renk alır.

## 🔑 Komşuluk Tespiti: VERTEX-SHARING

Basit yaklaşım: bbox overlap. Ama adjacent ama disjoint bbox'lar yanlış pozitif verir.

**Doğru yaklaşım**: iki polygon aynı vertex'i (köşeyi) paylaşıyorsa komşudur.

```
Her polygon'un tüm vertex'leri ~100m hassasiyetle key'e dönüştürülür:
  key = "lat_rounded|lon_rounded"  (4 decimal places)

Vertex key seti oluşturulur: Map<vertexKey, Set<polygonIndex>>

Eğer iki polygon aynı vertex key'ini paylaşıyorsa → komşu.
```

**Neden ~100m?**: Türkiye'nin idari sınırları aynı koordinat dosyalarından türetildi; ortak sınır vertex'leri birebir eşleşir. 100m'lik yuvarlama küçük floating-point kayıplarını tolere eder.

## Greedy Renklendirme

```
1. Komşuluk grafiği kurulur (yukarıdaki vertex-sharing ile).
2. Polygon'lar sırayla (veya derece'ye göre) gezilir.
3. Her polygon için: komşularının aldığı renkleri bul → paletten ilk boş indexi seç.
4. Atanan renk polygon'un `_color` property'sine yazılır.
```

Palette 20 renk içerir — çeşitlilik ve görsel denge için (kırmızı/yeşil/sarı/gri/lacivert + tonları).

## İki Platform İmplementasyonu

| Platform | Lokasyon | Fonksiyon |
|---|---|---|
| Native (Dart) | `map_view_maplibre_native.dart` | `_colorizeFeatures(features, {useRegionColors})` |
| Web (JS) | `web/index.html` | `_addUniqueColorLayer(srcId, colorProp, hitFilter)` |

Her ikisi de aynı palet + aynı vertex-sharing mantığını kullanır. Sonuçlar **tam eşleşmez** (greedy sıraya bağlı) ama görsel olarak yakındır.

## `useRegionColors` Modu

Native'de `_colorizeFeatures(..., useRegionColors: true)` → il renklendirmesi, ama aynı bölgedeki iller aynı renk ailesinden (örn. tüm Marmara tonları kırmızı-benzeri). Ana palet yerine bölge-ağırlıklı palet kullanılır.

Amaç: Bölge modunda il sınırları görünsün ama "Marmara" gibi gruplama da renkle hissedilsin.

## Kullanıldığı Yerler

**Native**:
- `_loadProvinceBorders()` — il renklendirme (`useRegionColors: true`)
- `_loadDistrictBorders()` — ilçe renklendirme
- `_showProvinceOverlay()` — İl modu overlay ilçeleri

**Web**:
- `srrpSetupRegionMode()`, `srrpSetupProvinceMode()`, `srrpSetupDistrictMode()` — hepsi setup sonunda `_addUniqueColorLayer()` çağırır
- Composite mode (İlçe): renk property'si `NAME_2` (ilçe adı), yoksa `NAME_1` (il adı)

## Invariant'lar

1. ✅ **Deep copy** yap — orijinal GeoJSON feature'larını `_color` property'si ile kirletme. `jsonDecode(jsonEncode(f))` ile klonla.
2. ✅ **Deterministik sıra** — aynı girdiden aynı çıktı. Feature'ları index'e göre işle, random sıralama kullanma.
3. ⚠️ **Türkiye dışı feature'lar filtrelenmiş olmalı** — Ege adaları vb. önce `_isFeatureInTurkey()` ile ayıkla, sonra colorize et.

## Bilinen Tuzaklar

- ⚠️ **Komşuluk eksik algılanabilir**: Denizden ayrılan küçük adacıklar (örn. Bozcaada → Çanakkale) vertex paylaşmaz → ana karaya komşu sayılmaz. Palette büyüktür (20 renk) olası çakışma görsel olarak önemsiz.
- ⚠️ **Rounding hassasiyeti değiştirilmemeli**. 4 decimal = ~10m, çok dar. 3 decimal = ~100m, ideal. 2 decimal → yanlış pozitif komşulukları.
- ⚠️ **Web'de layer zaten varsa önce kaldır**. `_addUniqueColorLayer` baştan `map.getLayer('srrp-sel-unique') && removeLayer` çağırır.

## Palette (Native ve Web ortak)

20 renk, `rgba(r,g,b,0.38-0.44)`. Temel paletler: kırmızı, yeşil, sarı, açık gri, lacivert + tonları. Detay: `_srrpUniqPalette` (JS) ve native'deki eşleniği.

## Bağlantılar

- [[MapViewMaplibreNative]] — Dart imp.
- [[MapViewMaplibreWeb]] — web imp.
- [[SelectionModes]] — mod bazlı hangi renklendirme kullanılır
- [[PlatformConsistency]]

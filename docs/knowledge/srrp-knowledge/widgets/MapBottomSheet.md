---
tags: [widget, panel]
updated: 2026-04-18
related: [MapScreen, MapViewModel]
file: frontend/lib/features/map/widgets/panels/map_bottom_sheet.dart
---

# MapBottomSheet

Alt panel / çekmece. Seçim modları, veri yenileme, sidebar (senaryolar, öneriler) butonlarını içerir. `StatefulWidget` — animasyonlu refresh ikonu için `SingleTickerProviderStateMixin`.

## Amaç

Kullanıcıya harita üzerinde bulunabilecek **tüm ana eylemleri** tek yerde sunar:
- Seçim modları: Bölge / İl / İlçe (bkz. [[SelectionModes]])
- Verileri yenile (refresh)
- Senaryolar (scenarios) erişimi
- Öneriler paneli (recommendations)
- Pin filtreleri (tip, min kapasite)

## Yapı

```
MapBottomSheet (StatefulWidget)
  → AnimatedContainer (açık/kapalı yüksekliği)
    → Column
      ├─ Grip handle (sürüklenebilir)
      ├─ Seçim modu butonları (Bölge/İl/İlçe)
      ├─ Veri yenileme butonu (rotating icon)
      ├─ Pin filtreleri
      ├─ Scenarios butonu → widget.onScenariosTap
      └─ SidebarFooter (bilgi/menü)
```

## Parametre

```dart
final VoidCallback? onScenariosTap;
```

- `onScenariosTap`: Senaryolar butonu tıklandığında tetiklenir. Null ise buton gizli/disabled.
- Erişim: `widget.onScenariosTap` (StatefulWidget State içinden).

## Refresh Butonu

"Verileri Güncelle" butonu — tıklanınca ikonu 360° döner ve `vm.refreshAllWeatherData()` tetiklenir. Spinner ikonu animasyon controller üzerinden kontrol edilir.

```dart
late AnimationController _refreshSpinController;

_refreshSpinController = AnimationController(
  vsync: this,
  duration: Duration(milliseconds: 800),
);

onTap: mapViewModel.isRefreshing
  ? null  // Zaten yenileniyor, tıklama devre dışı
  : () {
      _refreshSpinController.repeat();
      mapViewModel.refreshAllWeatherData().then((_) {
        _refreshSpinController.stop();
      });
    },
```

Refresh mantığı [[MapViewModel#Refresh]] + `MapLayerMixin.forceRefreshChoropleth()`.

## Seçim Modu Butonları

Üç ayrı buton; her biri VM'deki karşılık gelen metodu çağırır:

| Buton | Metod                              | Sonuç                |
| ----- | ---------------------------------- | -------------------- |
| Bölge | `mapViewModel.openRegionMode()`    | 7 bölge görünür      |
| İl    | `mapViewModel.openProvincesMode()` | 81 il görünür        |
| İlçe  | `mapViewModel.openDistrictsMode()` | Tüm Türkiye ilçeleri |

Aktif mod highlight edilir (`isProvinceModeActive`, `isDistrictsModeActive`, `isRegionsModeActive`).

Detay: [[SelectionModes]].

## Tema

- Renk: `Colors.blueAccent` (primary accent; `theme.primaryColor` kullanılmıyor — o property artık yok/geçerli değil).
- Border radius: üst köşeler yuvarlak (16px).
- Shadow: üst gölge (panel altında daha derin).

## İnvariant'lar

1. ✅ **`StatefulWidget`** — animasyon state'i için. `StatelessWidget`'a döndürme.
2. ✅ **`SingleTickerProviderStateMixin`** — `AnimationController.vsync: this`.
3. ⚠️ **`dispose()`'da `_refreshSpinController.dispose()`** — aksi halde ticker leak.
4. ⚠️ **`widget.onScenariosTap` kullan** — `StatefulWidget`'in field'ı; state class'ında `onScenariosTap` değil.

## Bilinen Tuzaklar

- ⚠️ **`theme.primaryColor` kullanma**: ThemeViewModel'de o property yok. `Colors.blueAccent` veya theme'in accent renk getter'ı.
- ⚠️ **Refresh devam ederken buton**: `isRefreshing` true iken `onTap: null` yap, aksi halde multiple refresh tetiklenir.
- ⚠️ **Stack kuralı**: `MapScreen` Stack'ine eklendiği için `MapBottomSheet` bir **`Positioned`**'ın child'ı olmalı. Bkz. [[MapStackPositioned]].

## Son Değişimler

- **2026-04-18**:
  - `StatelessWidget` → `StatefulWidget` dönüşümü
  - Refresh butonu + rotating icon animation
  - `theme.primaryColor` kullanımları `Colors.blueAccent` ile değiştirildi
  - SidebarFooter öncesine yerleştirildi

## Bağlantılar

- [[MapScreen]] — ebeveyn ekran
- [[MapViewModel]] — refresh + mod metodları
- [[SelectionModes]] — mod davranışları
- [[MapStackPositioned]] — Stack kuralı

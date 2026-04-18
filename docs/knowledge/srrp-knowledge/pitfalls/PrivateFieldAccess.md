---
tags: [pitfall, dart, library-boundary]
updated: 2026-04-18
related: [MapViewModel, MapViewMaplibreNative]
---

# ⚠️ Dart Private Alana Farklı Library'den Erişim

Dart'ta `_` ile başlayan alanlar **library-private**'dır. Bir library'den başka bir library'deki `_xxx` alanına erişim **compile-time hata** verir.

## Kural

> ViewModel (veya başka class) alanının adı `_` ile başlıyorsa, **başka bir `.dart` dosyasından** erişmek için **public getter** şarttır.

## Örnek (Hata)

```dart
// lib/features/map/viewmodels/map_viewmodel.dart
class MapViewModel {
  SelectionLevel _initialSelectionMode = SelectionLevel.none;
}
```

```dart
// lib/features/map/widgets/map_view_maplibre_native.dart
// Farklı library (farklı .dart dosyası)

final initialMode = vm._initialSelectionMode;  // ❌ COMPILE ERROR
// Error: The member '_initialSelectionMode' can only be used within
//   'package:frontend/features/map/viewmodels/map_viewmodel.dart'
```

## Çözüm: Public Getter

```dart
// map_viewmodel.dart
class MapViewModel {
  SelectionLevel _initialSelectionMode = SelectionLevel.none;

  SelectionLevel get initialSelectionMode => _initialSelectionMode;  // ✅
}
```

```dart
// map_view_maplibre_native.dart
final initialMode = vm.initialSelectionMode;  // ✅ OK
```

## Neden Private?

- Sınıfın **iç state'ini dış dünyadan gizler**.
- Encapsulation — dış kullanıcılar doğrudan yazmamalı.
- Refactor güvenliği — alanı yeniden adlandırabilirsin, dışarısı kırılmaz (public API sabit kalır).

## Library Sınırı

Dart'ta "library" genellikle **tek bir `.dart` dosyası** veya `part of` ile birleşen dosyalar topluluğu.

- Aynı dosyadaki farklı class'lar: private alanlara erişebilir.
- Farklı dosyalardaki class'lar: erişemez (private'e).

## `part of` ile Erişim (İstisna)

Bir dosyayı `part of` ile başka bir library'nin parçası yaparsan private erişim açılır:

```dart
// map_layer_mixin.dart
part of 'map_viewmodel.dart';  // Aynı library!

mixin MapLayerMixin {
  void _xxx() {
    // Buradaki kod map_viewmodel.dart'ın private alanlarına erişebilir
  }
}
```

**Not**: Proje bu pattern'i kullanıyor — `MapLayerMixin` ViewModel'in private alanlarına erişir.

## Pattern: Public Getter + Private Setter

Yalnızca okunabilir olsun, dışarıdan değiştirilmesin istiyorsan:

```dart
class MapViewModel {
  SelectionLevel _initialSelectionMode = SelectionLevel.none;

  // Dışa: sadece okuma
  SelectionLevel get initialSelectionMode => _initialSelectionMode;

  // İçe: set metodları kontrollü
  void openRegionMode() {
    _initialSelectionMode = SelectionLevel.region;
    safeNotify();
  }
}
```

Dış kod `vm.initialSelectionMode` okuyabilir ama `vm.initialSelectionMode = ...` yazamaz.

## Tarihte Yapılan Hatalar

- **2026-04-18**: `map_view_maplibre_native.dart`'ta `vm._initialSelectionMode` yazıldı → `flutter analyze` hata verdi → public getter `initialSelectionMode` eklendi, fixed.

## Ne Zaman Farkına Varılır?

- `flutter analyze` → hata listeler.
- Build sırasında: `Error: The member '_xxx' can only be used within '...'`
- IDE (VS Code, Antigravity): kırmızı altı çizili + tooltip.

## Tuzak: Aynı Sınıfta Gibi Görünen Farklı Library

```dart
// extension_methods.dart
extension MyExt on MyClass {
  void doSomething() {
    _privateField;  // ❌ Extension farklı library — erişim yok!
  }
}
```

Extension'lar ayrı library olabilir. Eğer extension library'deyse ve extension'u uyguladığı class başka library'deyse, private erişim yok.

## İnvariant'lar

1. ⚠️ **Dış library'den `_xxx` erişme** — getter tanımla.
2. ✅ **Read-only state için**: private alan + public getter.
3. ✅ **Read-write state için**: metod (örn. `openRegionMode()`) setter yerine — yan etkileri (notify, load) tetikleyebilsin.
4. ✅ **part of ile birleşen dosyalarda**: private erişim OK (aynı library).

## Bağlantılar

- [[MapViewModel]] — örnek: `initialSelectionMode` getter
- [[MapViewMaplibreNative]] — getter tüketicisi
- [[SelectionModes]] — bu alanın davranışsal önemi

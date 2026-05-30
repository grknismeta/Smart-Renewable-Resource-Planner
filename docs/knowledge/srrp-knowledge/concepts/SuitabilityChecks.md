---
tags: [concept, pin, suitability, validation]
updated: 2026-05-09
related: [PinAddFlow, PinPanelShell]
---

# Suitability Checks — Tip-Aware Konum Uygunluğu

Pin ekleme ve düzenleme sırasında **seçilen santral tipinin bu konuma uygun
olup olmadığını** kontrol eder. Backend `/geo/check-suitability` endpoint'i
tip-bağımsız değil — `solar_details / wind_details / hydro_details` ayrı
döner.

## 3 Senaryo (2026-05-09 Kullanıcı Belirledi)

| Senaryo | Davranış |
|---|---|
| **1. Yeni pin ekleme — yer uygun mu o tipe?** | API call sonrası tip-aware evaluate. Tipe-uygun değilse Kaydet pasif. |
| **2. Tip değiştirme — yeni tip uygun mu?** | Cache'den re-evaluate (yeni API yok). Yeni tip uygun değilse Kaydet pasif, uyarı. |
| **3. Düzenleme — değişen tip/konum çakışır mı?** | Edit mode'a girince re-check. Tip değiştirilirse re-evaluate. Uyarı banner (block etmez — kullanıcı yine kaydedebilir, ama analiz sonuçları gerçekçi olmayabilir). |

## Backend Response Yapısı

`POST /geo/check-suitability` döner:
```json
{
  "suitable": true,           // genel (legacy)
  "recommendation": "...",
  "solar_details": {
    "suitable": true,
    "reasons": ["..."]
  },
  "wind_details": {
    "suitable": false,
    "reasons": ["Yerleşim 1.2 km", "Eğim 45°"]
  },
  "hydro_details": {
    "suitable": false,
    "reasons": ["Akarsuya 5 km uzak"]
  }
}
```

## Frontend Akış

### Add Pin Akışı (`AddPinDialog`)

```dart
// 1. initState — VM listener kur (tip değişimini dinle)
_viewModel.addListener(_onViewModelChanged);

// 2. PostFrameCallback — ilk geo check
_checkSuitability();
  ↓
// 3. API → result cache + tip-aware evaluate
_lastGeoResult = result;
_evaluateSuitabilityForType(_viewModel.selectedType, result);

// 4. Kullanıcı tipi değiştirir → listener tetiklenir
void _onViewModelChanged() {
  if (vm.selectedType != _lastEvaluatedType && _lastGeoResult != null) {
    _evaluateSuitabilityForType(vm.selectedType, _lastGeoResult!);
  }
  // YENİ API CALL YOK — cache'den
}
```

**`_evaluateSuitabilityForType`:**
1. Tipe göre `detailKey` seç (`solar_details/wind_details/hydro_details`)
2. `result[detailKey]['suitable']` ve `['reasons']` oku
3. `setState`: `_isSuitable`, `_suitabilityMessage`, `_suitabilityReasons`

**Kaydet butonu:** `_isSuitable == false` → disabled.

### Edit Pin Akışı (`PinDetailsDialog`)

Add ile aynı mantık, ayrı state:
- `_editIsCheckingSuitability`, `_editIsSuitable`, `_editSuitabilityMessage`
- `_editLastGeoResult`, `_editLastEvaluatedType`
- `_checkEditSuitability()` edit mode'a girince çağrılır
- `_onEditViewModelChanged` tip değişimini izler

**Fark:** Edit mode'da Kaydet **disabled değil** — sadece **uyarı banner**.
Sebep: kullanıcı pini koymuş, sonradan tip uygun değilse de düzenleme
yapabilmeli ("Bu pin RES'tendi ama şimdi yer GES'e uygun, ben yine güncelliyorum"
gibi senaryolar).

## ⚠️ Yaygın Tuzaklar

1. **Cache invalidation**: pin konumu değişirse (`_movePinFormTo`) cache'i
   sıfırla, yeni `_checkSuitability` çağır. Şu an `_movePinFormTo` form
   widget'ını key reset ediyor → AddPinDialog yeniden init oluyor → ilk
   `_checkSuitability` tetiklenir. OK.
2. **Genel `suitable` ile tip-spesifik karıştırma**: Eski kod `result['suitable']`
   kullanıyordu — yanlış. Tip-aware `solar_details / wind_details / hydro_details`
   kullanılmalı.
3. **Listener leak**: `_viewModel.addListener` → `dispose`'da `removeListener`.
   Edit için `_cancelEdit` de temizler.
4. **Çift API call**: tip değişiminde yeni API call YOK — cache'den. Konum
   sabit kaldığı sürece sonuç değişmez.

## Bağlantılar

- [[PinAddFlow]] — pin ekleme akışı
- [[PinPanelShell]] — kabuk widget'ı
- Backend: `app/routers/geo.py` `/geo/check-suitability`
- Backend: `app/services/geo_service.py` `_analyze_solar/wind/hydro`
- [[INBOX]] — 2026-05-09 Sprint 4

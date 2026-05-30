---
tags: [concept, ux, panel, library]
updated: 2026-05-08
related: [PinAddFlow, MapViewModel, PlatformConsistency]
---

# Library Side Panel (Senaryolar | Pinlerim)

Sol kenardan kayan ana yönetim paneli. Kullanıcının ifadesiyle "Kütüphane" —
hem senaryoları hem pinleri tek yerden yönetir.

## 🔑 Temel Kural

> Pinlerim ve Senaryolar **aynı panelin iki sekmesi**. Bottom sheet'te
> ayrı tab değil — sol kayar büyük panel. Bottom sheet sadece kompakt
> özet için kullanılır.

Kullanıcının ifadesi (2026-05-08):
> "Bu ikili sol taraftan açılan yapılar. Alta eklemişsin ikisini ama ben
> HTML dosyasındaki gibi olmasını istemiştim senden."

## Anatomi

```
┌─ KÜTÜPHANE ─────────────────[×]┐
│                                │
│  [Senaryolar]   [Pinlerim]     │  ← segmented header
│  ─────────────                 │
│                                │
│  🔍 [Senaryo ara...]            │
│                                │
│  ┌────────────────────────┐    │
│  │ 🟢 Türkiye 2030     AKTIF │ │  ← aktif highlight
│  │ 📍 14 pin · 285 MW · 58.2M│ │
│  └────────────────────────┘    │
│                                │
│  ┌────────────────────────┐    │
│  │ 🟡 İç Anadolu Solar    │    │
│  │ 📍 6 pin · 92 MW · 23.4M │  │
│  └────────────────────────┘    │
│                                │
│  ┌────────────────────────┐    │
│  │ + Yeni senaryo oluştur  │   │
│  └────────────────────────┘    │
│                                │
├────────────────────────────────┤
│  ┌─[+ Yeni Kaynak Ekle ]────┐  │  ← Santral Kur popover tetikler
│  └────────────────────────┘    │
└────────────────────────────────┘
```

## Pinlerim Sekmesi (Gruplu Liste)

```
[Senaryolar]   [Pinlerim ✓]
─────────────

▼ ☀ Güneş (8)
  📍 Eskişehir GES-1     10 MW   85%
  📍 Eskişehir GES-2     12 MW   82%
  📍 Konya GES-Merkez   45 MW   88%
  ...

▼ 💨 Rüzgar (2)
  📍 İstanbul RES        18 MW   34%
  📍 Çanakkale GES        8 MW   31%

▼ 💧 HES (2)
  📍 Kızılırmak Barajı   45 MW   42%
  📍 Yusufeli HES        85 MW   55%
```

Her grup açılır-kapanır (default açık). Pin tıklanınca → pin detay bottom
card açılır (cross-sheet navigation, [[PinAddFlow]] son aşaması).

## Senaryolar Sekmesi

- Aktif senaryo üstte highlight (yeşil kenarlık, "AKTIF" rozeti).
- Her kart: ad, pin sayısı, toplam MW, toplam maliyet.
- Tıklayınca → senaryoyu aktif yap + haritada o senaryonun pinleri vurgulu.
- Sağ üst menü (⋮): "Düzenle / Sil / Rapora git" (drop-down).

## Genişlik

- **Desktop:** sabit 320px
- **Tablet (600-900px):** 280px
- **Mobile (<600px):** bottom sheet'e dönüşür mü? **Hayır** — mobile'da
  full-screen overlay (drawer pattern). Sol kenardan kayan tam ekran
  panel; close butonu sağ üstte.

## Bottom Sheet'te Ne Kalır

Eskisi gibi: kompakt özet:
- Veri tazelik göstergesi ("Son güncelleme: az önce")
- KPI'lar (Rüzgar 2 / Güneş 8 / HES 2 / Toplam 10 MW)
- "Verileri Güncelle" tuşu
- "Rapora Git" tuşu

**Pinlerim/Senaryolar tab paneli artık burada yok** — sol kütüphaneye
taşındı.

## Erişim

1. **Sol kenar tuşu** (`MapControlButton` — Kütüphane ikonu) → panel aç/kapa
2. **Bottom sheet'ten** → "Senaryolarım" linki (eski "Senaryolarım" tuşunun
   davranışı bu olur — direkt Senaryolar sekmesinden açar)
3. **Pin detay'dan** → "Senaryolar" butonu (mevcut cross-sheet — Pinlerim
   sekmesinden açar, ilgili pin highlight'lı)

## Mevcut Kodu Hangi Dosyalar Etkiler

- `frontend/lib/features/scenarios/widgets/scenario_side_panel.dart` →
  **yeniden adlandır** `library_side_panel.dart`, segmented header eklenir
- `frontend/lib/features/map/widgets/panels/pins_scenarios_tab_panel.dart` →
  **SİL** (2026-05-08'de yanlışlıkla eklenmişti, bottom sheet'ten kaldırılacak)
- `frontend/lib/features/map/widgets/panels/map_bottom_sheet.dart` →
  `PinsScenariosTabPanel` kaldır, eski `PinsPanel`'ı geri koy (kompakt mod)
  veya tamamen kaldır

## ⚠️ Yaygın Tuzaklar

1. **Bottom sheet'e tab eklememe**: Tek doğru yer sol panel. Bottom sheet
   sadece özet.
2. **Senaryo aktivasyonu state**: `ScenarioViewModel.activeScenarioId`
   tek source. Pinlerim sekmesi de bunu okur (aktif senaryoya pin ekle).
3. **Pin grup başlığı sayacı**: `pins.where(type == 'X').length` her render'da
   hesaplanmasın, ChangeNotifier listen'de cache'le.

## Bağlantılar

- [[PinAddFlow]] — pin ekleme akışı (panelin altındaki tuştan tetiklenir)
- [[MapViewModel]] — `activePinDetail`, `placingPinType` state
- [[PlatformConsistency]] — mobile drawer parite
- [[INBOX]] — 2026-05-08 sprint planı

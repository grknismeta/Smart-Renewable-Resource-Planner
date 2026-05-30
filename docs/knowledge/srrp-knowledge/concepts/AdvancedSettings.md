---
tags: [concept, pin, advanced, technical-spec]
updated: 2026-05-17
related: [PinAddFlow, PinFlowController, MapViewModel]
---

# Pin Gelişmiş Ayarlar (Technical Parameters)

Pin ekleme/düzenleme formunun expandable sub-form bölümü. Kullanıcının
santral teknik parametrelerini detayla girebileceği alan. Default kapalı
("⚙ Gelişmiş Ayarlar ▾"), tıklanınca AnimatedSize ile açılır.

## 2026-05-17 Sprint A — Backend bağlandı

- **Migration**: `013_pin_advanced_params_and_user_equipments.py`
  - `pins`: +`panel_tilt`, `panel_azimuth`, `panel_power_w`, `hub_height`,
    `rotor_diameter`, `rated_power_kw` (Float, nullable)
  - `equipments`: +`owner_id` (Int, nullable, indexed). NULL=sistem, dolu=user.
- **Schemas**: `PinBase`'e 6 yeni alan; `EquipmentResponse`'a `owner_id`.
- **CRUD**: `get_equipments(user_id=)` system+user filter; `create_user_equipment`
  ve `delete_user_equipment` eklendi.
- **Router** `/equipments`:
  - `GET /` → user-aware (system + user'ın kendi'si)
  - `POST /` → kullanıcı kendi ekipmanı oluşturur (owner_id otomatik)
  - `DELETE /{id}` → sadece kendi ekipmanını silebilir
- **Frontend Equipment modeli**: `ownerId` alanı + `isUserOwned` getter.
- **EquipmentService**: `createEquipment(...)`, `deleteEquipment(id)`.
- **MapViewModel.addPin/updatePin + ResourceService**: 6 yeni parametre
  (`panelTilt`, `panelAzimuth`, `panelPowerW`, `hubHeight`, `rotorDiameter`,
  `ratedPowerKw`).
- **AddPinDialog/PinDetailsDialog save handler'ları**: yeni alanları payload'a
  geçirir.
- **AdvancedSettingsPanel**: GES için "Panel Tipini Kaydet", RES için
  "Türbin Tipini Kaydet" butonu — mini dialog ile ekipman adı, backend POST,
  `MapViewModel.loadEquipments(forceRefresh:true)`, snackbar feedback.

⚠️ **Deploy adımı**: `cd backend && alembic upgrade head` (013).

## 2026-05-17 Sprint B — Mevcut Durum

`frontend/lib/features/pins/widgets/advanced_settings_panel.dart`
(`AdvancedSettingsPanel`) widget'ı yazıldı. AddPinDialog + PinDetailsDialog
edit form ortak kullanır (composition pattern, bkz. [[PinPanelShell]]).

**Ana formdaki değişiklikler:**
- HES için Debi/Düşü/Havza alanları ana formdan **kaldırıldı**, Gelişmiş
  Ayarlar > HES bloğuna taşındı.
- GES Panel Alanı ana formdan **kaldırıldı**, Gelişmiş Ayarlar > GES
  bloğunda (default 10m²).
- HES tipi için Equipment Selector **gizlendi** (kullanıcı kararı: HES'te
  ekipman/türbin tipi seçimi yok, tüm hidrolik parametreler advanced'da).
- RES + GES için Equipment Selector ana formda kalır (Panel/Türbin Modeli).

**Sprint A (backend migration) bekliyor:**
- `pins` tablosuna eklenecek: `panel_tilt`, `panel_azimuth`, `panel_power_w`,
  `hub_height`, `rotor_diameter`, `rated_power_kw`. HES alanları zaten var.
- `equipments` tablosuna `owner_id` (nullable, NULL = sistem ekipmanı, dolu =
  kullanıcı kendi eklediği).
- `POST /equipments` endpoint + GET filter (system + kullanıcı'nın kendi).
- Equipment dropdown'a "Yeni Ekipman Ekle" stub Sprint A ile birlikte
  bağlanacak (şu an widget'ta yok — backend gelmeden yanıltıcı UX olmasın).

`PinDialogViewModel` field'ları (Sprint B1):
```dart
double? panelTilt, panelAzimuth, panelPowerW;     // GES
double? hubHeight, rotorDiameter, ratedPowerKw;   // RES
// HES: flowRate, headHeight, basinAreaKm2 (mevcut)
```
Setter'lar: `setPanelTilt(String)` vs. `_parseOptional` ile null-friendly.
Edit mode seed: `seedAdvanced({...})`.

## GES (Güneş Paneli)

Domain araştırması: Fiziksel etmenler **siyah hücre alanı + eğim/yön**.

| Parametre | Birim | Default | Açıklama |
|---|---|---|---|
| **Panel açısı (tilt)** | derece (°) | 30 | Türkiye için optimal ~30°. Düşük enlemde daha az. |
| **Panel yönü (azimuth)** | derece (°) | 180 (güney) | Kuzey yarımkürede güney maksimum. |
| **Gölgelenme faktörü** | % | 0 | Manuel: 0-30%. Auto: 3D bina + arazi gölgesi (Aşama 4). |
| **Panel verimi** | % | 18-22 | Modelden otomatik (panel modeli seçilince). |
| **Sıcaklık katsayısı** | %/°C | -0.4 | 25°C üstü her derece için kayıp. |
| **Toz/kirlilik kaybı** | % | 5 | Yıllık bakım sıklığına göre. |

UI: tilt için 0-90° slider, azimuth için **pusula widget** (kuzey 0° / doğu
90° / güney 180° / batı 270°).

## RES (Rüzgar Türbini)

Domain araştırması: Türbin güç eğrisi + yön + yükseklik.

| Parametre | Birim | Default | Açıklama |
|---|---|---|---|
| **Hub yüksekliği** | m | 100 | Modern türbinler 80-150m. Yükseldikçe rüzgar daha temiz. |
| **Blade çapı** | m | 130 | Güç ∝ alan = π·(D/2)². Tipik 80-160m. |
| **Blade sayısı** | adet | 3 | Genelde 3, nadir 2. |
| **Cut-in hızı** | m/s | 3 | Devreye giriş eşiği. |
| **Rated hız** | m/s | 12 | Nominal güç hızı. |
| **Cut-out hızı** | m/s | 25 | Güvenlik için durma eşiği. |
| **Nominal güç** | kW | 4500 | Modelden otomatik. |
| **Türbin yönü (yaw)** | derece (°) | dominant rüzgar | Default: konumun yıllık dominant rüzgar yönü (backend `wind_direction_dominant`). |
| **Yön ayarı** | manuel/auto | auto | Auto: yawing mekanizması rüzgarı takip eder. Manuel: sabit. |

UI: yön için **pusula widget**. Default backend'den gelen dominant rüzgar
yönüne ayarlı, kullanıcı override edebilir (derece girişi de var).

## HES (Hidroelektrik)

Domain araştırması: Güç = ρ·g·Q·H·η (su yoğunluğu × yerçekimi × debi × düşü × verim).

| Parametre | Birim | Default | Açıklama |
|---|---|---|---|
| **Debi (Q)** | m³/s | — | Saniyede akan su miktarı. Hesabın anahtar girdisi. |
| **Düşü (H)** | m | — | Su seviyesinin türbine düşme yüksekliği. |
| **Havza alanı** | km² | — | Yağıştan beslenen drenaj alanı. |
| **Yağış miktarı** | mm/yıl | konum bazlı | Backend hesap için (debi tahmini). |
| **Akış hızı** | m³/s | dönemsel | Yıllık ortalama vs ekstrem. |
| **Türbin tipi** | enum | auto | Düşüye göre öneri: Pelton (>250m) / Francis (50-250m) / Kaplan (<50m) |
| **Türbin verimi** | % | 90-94 | Tipe göre değişir (Pelton 90-95, Francis 90-94, Kaplan 90-93). |
| **Havuz genişliği** | m | opsiyonel | Baraj rezervuarı (depolama). |
| **Baraj depolama** | toggle | false | "Bu HES baraj rezervuarına bağlı" — depolama varsa true. |
| **Su tüketimi** | toggle | true | Türbin geçen su tüketilir mi (run-of-river vs. rezervuar). |

UI:
- Türbin tipi: 3 kart (Pelton/Francis/Kaplan), düşü değerine göre **önerilen**
  vurgulu. Kullanıcı manuel seçebilir.
- Verim otomatik tipe göre güncellenir, manuel override slider.

### HES Backend Potansiyel Modeli (Sprint 4)

İdeal akış: backend Türkiye akarsularını + ortalama debi + drenaj alanı + DEM'den
düşü potansiyelini bilir → kullanıcı koordinat seçer, **debi/düşü/havza
otomatik tahmin** gelir. Kullanıcı sadece doğrular veya günceller.

Veri kaynakları (araştırılacak):
- **DSI** (Devlet Su İşleri) — Türkiye debi gözlem istasyonları
- **EİE** (Elektrik İşleri Etüt İdaresi) — hidroelektrik potansiyel raporları
- **OSM `waterway=river` + `width` tag** — yatak genişliği
- **DEM raster** (SRTM 30m) — düşü hesabı için elevation profili

Bu **Sprint 4** kapsamında. Şu an: kullanıcı manuel girer; default `null`.

## Form Yapısı

Gelişmiş ayarlar bir `ExpansionTile` veya benzeri:

```
⚙ Gelişmiş Ayarlar ▾                    [kapat]
─────────────────────────────────────────
[GES alanları:]
  Panel açısı:    [30°] ━━━━━━━●━━━━━━━ (slider 0-90)
  Panel yönü:     [🧭 pusula widget]
  Gölgelenme:     [0%] ━━━━━━━━━━━━━━
  ...
[Hesaplanan değerler önizleme:]
  Tahmin verim: 19.2%
  Yıllık üretim: 142 GWh
```

Her input değişikliğinde **canlı önizleme** güncellenir (yıllık üretim,
verim, kapasite faktörü).

## Pusula Widget (Yön Seçimi)

RES yön + GES azimuth için ortak widget. Görsel daire, 0-360° arası
sürüklenebilir ok. Aynı zamanda altta sayısal input.

```
       N (0°)
        ▲
   ┌────│────┐
W ─┤    ◉    ├─ E (90°)
   └────│────┘
        ▼
       S (180°)

Yön: [135°] (manuel input)
[🧭 Dominant rüzgar yönüne sıfırla]
```

## Backend Endpoint Etkileri

Yeni / güncellenecek:

- `POST /pins/` — payload'a `advanced_settings: {...}` ekle.
- `Pin` model — `advanced_settings` JSON kolon.
- `PinCalculationService` — gelişmiş parametreleri hesaba dahil et.

## ⚠️ Yaygın Tuzaklar

1. **Default'lar mantıklı olmalı**: Boş bıraktığında "ortalama Türkiye"
   değeri kullan, kullanıcı eksik bilgi yüzünden yanlış hesap almasın.
2. **Pusula widget tap vs drag**: hem dokun-konum hem sürükle desteklenmeli.
3. **Türbin tipi öneri ↔ override race**: kullanıcı düşü değiştirince
   öneri güncellenir ama önceki manuel seçim **kaybolmasın** — onay sor.

## Bağlantılar

- [[PinAddFlow]] — ana form akışı
- [[MapViewModel]] — pin state
- [[INBOX]] — 2026-05-08 sprint planı

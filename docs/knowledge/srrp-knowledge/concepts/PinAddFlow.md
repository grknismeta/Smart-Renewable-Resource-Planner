---
tags: [concept, ux, pin, flow]
updated: 2026-05-08
related: [LibrarySidePanel, AdvancedSettings, PlatformConsistency, MapViewModel]
---

# Pin Add Flow (V3 popover → V2 floating form)

Kullanıcının haritada yeni santral pini eklerken yaşadığı akış. **Harita asla
tamamen bloklanmaz** — her aşamada arka planda görünür kalır.

## 🔑 Temel Kural

> Pin eklerken yanlış nokta seçimini **anında, kapatmadan, haritadan**
> düzeltebilmeli. Bu yüzden form harita üstüne yarı saydam değil, **kenara
> yapışık floating** açılır; ortaya açılan modal yasaktır.

Kullanıcının ifadesi (2026-05-08):
> "Eklediğin yeri görmeden ekleme yapmak zorunda kal. Güzel değil."

## Akış (Web)

```
┌─ 1. "Pin Ekle" / "Santral Kur" tuşu (sağ üst) ─────┐
│  Tıklanır → placing mode (cursor crosshair)        │
│  Layers panel'de tip-aware suitability overlay aç  │
└────────────────────────────────────────────────────┘
                        ↓
┌─ 2. Harita tıkla → V3 INLINE POPOVER ──────────────┐
│  Tıklanan noktanın TAM ÜSTÜNDE küçük popover:      │
│  ┌─────────────────────────────────────┐           │
│  │ 📍 Yusufeli / Artvin   40.82°,41.53°│           │
│  │ Burada ne kuracaksın?               │           │
│  │  ☀ Güneş  💨 Rüzgar  💧 HES         │           │
│  │  Tip seç → form genişler. ESC kapat │           │
│  └─────────────────────────────────────┘           │
│  Harita arka planda görünür, pin "preview" işareti │
│  (yarı saydam) tıklanan noktada çizilir.           │
└────────────────────────────────────────────────────┘
                        ↓
┌─ 3. Tip seç → V2 ZENGİN FLOATING FORM ─────────────┐
│  Pin'e yapışık (kenara anchor, ortaya değil):      │
│                                                     │
│  ┌─ [☀ ikon] Yeni Kaynak              [×] ─┐       │
│  │  📍 Yusufeli / Artvin · 40.82°, 41.53°   │       │
│  ├──────────────────────────────────────────┤       │
│  │ [GES] [RES] [HES]  segmented             │       │
│  ├──────────────────────────────────────────┤       │
│  │ KAYNAK ADI                  │ MEVSİMSEL: │       │
│  │ [Yusufeli HES-1__________]  │ 🌡 8.2°C   │       │
│  │ SENARYO                     │ ☀ 173 W/m² │       │
│  │ [Türkiye 2030 ▼]            │ 💨 3.4 m/s │       │
│  │ DEBİ (m³/s)                 │            │       │
│  │ [85.0]                      │            │       │
│  │ DÜŞÜ (m)                    │            │       │
│  │ [120]                       │            │       │
│  ├──────────────────────────────────────────┤       │
│  │ YILLIK ÜRETİM TAHMİNİ                    │       │
│  │ 78.4 GWh   ▲ +%4.2 (geçen yıl)           │       │
│  │ Bu ay (Mayıs) tahmini: 9.1 GWh           │       │
│  ├──────────────────────────────────────────┤       │
│  │ ⚙ Gelişmiş Ayarlar ▾                     │       │
│  │ [İptal]                       [Kaydet]    │       │
│  └──────────────────────────────────────────┘       │
└────────────────────────────────────────────────────┘
```

## Akış (Mobile / Dikey)

Aynı 3 aşama, ama:
- **V3 popover** — tıklanan noktanın üstünde ama daha küçük (kart genişliği
  240px civarı). 3 tip butonu büyük dokunulabilir alan.
- **V2 form** — `DraggableScrollableSheet` kademeli:
  - **Peek (%30)**: header (il/ilçe + koordinatlar) + tip segmented + Kaydet/İptal
  - **Expanded (%70)**: tüm form içeriği scroll'lu
- Drag handle üstte. Kullanıcı parmakla aşağı kaydırıp daraltır, harita
  serbest kalır.

## Etkileşim Kuralları

| Aksiyon | Davranış |
|---|---|
| Form içine tıkla | Form etkileşimi (input, button) |
| Form **dışına** tıkla (haritaya) | Harita pan/zoom serbest, form açık kalır |
| Form'un üstüne drag | Form drag (mobile bottom sheet) |
| Harita üstüne drag | Harita pan, form sabit |
| ESC tuşu (web) | Form kapanır (popover veya panel) |
| Geri buton (mobile) | Form kapanır |

## Görsel Tema — Gradyan Arka Plan

Form arka planı tip-aware gradyan:
- **Üst (%30)**: Seçili tip rengi yarı saydam (GES turuncu, RES mavi, HES yeşil).
- **Alt (%70)**: Uygulamanın aktif teması (dark `#1A1F2A` / light `#F5F7FA`).

Bu gradyan kullanıcıya seçtiği tipi sürekli hatırlatır, ayrıca harita
arkasıyla yumuşak geçiş sağlar.

## Header — İl/İlçe Reverse Geocoding

Pin koordinatı backend `/geo/city?lat=&lon=` ile reverse-geocode edilir,
form header'da il/ilçe baskın gösterilir. Koordinat alt satırda küçük.

Türkiye dışı koordinat (Globe modu) için:
- Header: "Türkiye dışı" + koordinat
- Suitability check atlanır
- Form yine açılır ama "Sadece hava verisi kaydı" notu ile

## Tip-Spesifik Form Alanları

| Tip | Ek Alan |
|---|---|
| **GES** | Panel alanı (m²) |
| **RES** | Türbin sayısı (adet) |
| **HES** | Debi (m³/s), Düşü (m), Havza (km²) |

Tüm tipler için zorunlu: Kaynak adı, Senaryo (opsiyonel dropdown).

Gelişmiş ayarlar sub-form için bkz. [[AdvancedSettings]].

## Yıllık Üretim Tahmini

Form'un alt bölümü her input değişikliğinde **canlı preview** gösterir:
- Yıllık tahmini üretim (GWh / kWh)
- Geçen yıl üretimi karşılaştırma (%Δ)
- Bu ayın geçen yıl üretimi

Hesaplama backend `/pins/preview` (yeni endpoint — Sprint 1'de eklenecek)
veya frontend formül kullanır (basit GES: alan × verim × ışınım × 365).

## Mevcut Kodu Hangi Dosyalar Etkiler

- `frontend/lib/features/pins/dialogs/add_pin_dialog.dart` → **yeniden adlandır**
  `pin_add_panel.dart`, yapı tamamen yeniden yazılır
- `frontend/lib/features/map/widgets/pin_type_popover_inline.dart` *(yeni)* — V3 popover
- `frontend/lib/features/pins/widgets/advanced_settings_form.dart` *(yeni)* — gelişmiş ayarlar
- `frontend/lib/features/map/screens/map_screen.dart` — overlay yapısı (popover + form)

## ⚠️ Yaygın Tuzaklar

1. **Ortada bottom card kullanma**: Yanlış — kullanıcı ekran orta-alta açan
   `Center` wrapper yerine form'u **kenara** anchor etmeli. 2026-05-08 ilk
   teslimde bu hata yapılmıştı, refactor edildi.
2. **Modal showDialog kullanma**: Eski hata. Harita asla bloklanmaz.
3. **Reverse geocoding cache**: Aynı koordinat için tekrar tekrar fetch
   etme — `MapViewModel`'da `_lastGeocodeResult` cache'le.
4. **Popover positioning**: Tıklanan noktanın *üstünde* ama ekran kenarına
   yakınsa **flip** (altta/yanda göster) — clip etmesin.

## Bağlantılar

- [[LibrarySidePanel]] — sol panel (Senaryolar | Pinlerim)
- [[AdvancedSettings]] — gelişmiş ayarlar parametreleri (GES/RES/HES)
- [[PlatformConsistency]] — web ↔ mobil parite
- [[MapViewModel]] — `placingPinType`, `activePinDetail` state
- [[INBOX]] — 2026-05-08 sprint planı

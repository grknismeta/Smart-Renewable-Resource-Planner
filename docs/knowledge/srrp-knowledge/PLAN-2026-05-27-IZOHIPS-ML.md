---
tags: [plan, sprint, izohips, ml-projection, checkpoint]
updated: 2026-05-28
related: [INDEX, INBOX, BACKEND-PLAN-2026-05-17, TESTS-2026-05-28-O2-P2-P3]
status: completed
---

# 🗺️🧠 PLAN — İzohips Harita + ML Projeksiyonu (2026-05-27)

> ✅ **2026-05-28 DURUM: Tüm sprintler tamamlandı** (O1+O1.4+O2 + P1+P2+P3).
> Testler: [[TESTS-2026-05-28-O2-P2-P3]] (otomatik 8/8 geçti, manuel UI bekliyor).
>
> Kullanıcı kararı: **B yolu** — yeni feature'lar (izohips + ML) bu sprint'te.
> AWS deploy (S4-S7) sonraya bırakıldı.
>
> Test öncesi karar matrisinden çıkan **final tercihler:**
> - İzohips: **O1 + O2 paralel** (hem MVP hem self-host pipeline) ✅
> - ML model: **statsmodels SARIMAX** (Prophet'in %85-90 kalite, %15 boyut) ✅
> - Climate scenarios: **P3'te eklendi** (RCP4.5/8.5 delta motoru) ✅
>
> **Son Değişimler:**
> - 2026-05-28: O1.4 native contour raster parite (`map_view_maplibre_native.dart`
>   `_syncContourLayer`); O2 self-hosted MVT pipeline (`contour_tiles.py` endpoint +
>   `build_contour_mvt.py` script + frontend kaynak seçici); P2 Projeksiyon tab
>   (`projection_tab.dart` + `ml_forecast_service.dart` + `projection_viewmodel.dart`);
>   P3 climate scenarios (`climate_scenarios.py` + `/ml/scenario/province` + frontend
>   `ClimateScenarioCard`). `.venv`'e statsmodels+pmdarima kuruldu.

## 📦 Mevcut Altyapı

- ✅ Hillshade aktif (`web/index.html` line 1103, AWS Terrarium PNG tile)
- ✅ `ml_projection_service.py` mevcut (placeholder/stub)
- ✅ `ml_projection_placeholder.dart` (frontend UI placeholder)
- ✅ Climatology: 81 il × 2 kaynak × 12 ay (gerçek 10-yıl ortalaması)
- ✅ Hourly weather: 2 yıl saatlik (`hourly_weather_data`, ~8 GB)
- ✅ Pin generation history (kullanıcı pin install_date'inden bugüne)

---

## 🎯 SPRINT O — İZOHİPS HARİTA

### Phase O1 — MVP: OpenTopoMap raster overlay (1 gün)

**Hedef:** Layers panel'da "İzohips" toggle. Açıldığında haritaya kontur çizgileri + renkli yükselti haritası bindirir.

| # | Görev | Dosya | Effort |
|---|---|---|---|
| O1.1 | Layers panel'a "İzohips" toggle + opacity slider | `layers_panel.dart` | 30 dk |
| O1.2 | `srrpToggleContour(bool enabled, num opacity)` JS bridge | `web/index.html` (yeni raster source `srrp-contour`, hillshade üstü) | 1 saat |
| O1.3 | `MapViewModel.setContourEnabled` + `setContourOpacity` | `map_view_model.dart` | 30 dk |
| O1.4 | Native parite — `map_view_maplibre_native.dart` | maplibre native raster source | 1 saat |
| O1.5 | Attribution chip "© OpenTopoMap (CC-BY-SA)" | Layers panel altı | 15 dk |

**Tile source:** `https://{a,b,c}.tile.opentopomap.org/{z}/{x}/{y}.png`
**Rate limit:** ~10K req/saat (anonymous). Production'da O2 ile değiştirilir.

### Phase O2 — Self-hosted contour MVT (3-5 gün, AWS öncesi)

**Hedef:** Production'da OpenTopoMap rate limit'inden kurtul. Kendi tile sunucumuz.

| # | Görev | Detay | Effort |
|---|---|---|---|
| O2.1 | SRTM 1-arc-second DEM indir | Türkiye için `srtm.csi.cgiar.org` (~5 tile, 30m resolution) | 1 saat |
| O2.2 | `gdal_contour` pipeline | 20m/50m/100m intervals → GeoJSON. Bash script `scripts/build_contours.sh` | 1 gün |
| O2.3 | `tippecanoe` ile MVT'ye çevir | zoom 9-14, level filter (z9'da 500m, z14'te 20m) | 4 saat |
| O2.4 | Backend tile server | `app/routers/tiles.py` `/contour/{z}/{x}/{y}.pbf` | 4 saat |
| O2.5 | Frontend contour layer style | line color elevation'a göre, index lines bold | 2 saat |
| O2.6 | Label katmanı | Major contour'larda elevation rakamı | 2 saat |

**Çıktı:** `backend/data/tiles/contour/*.pbf` (Türkiye için ~200 MB)
**Avantaj:** Atıf yok, rate limit yok, hızlı, markalı stil.

### O Sprint kabul kriterleri

- ✅ Layers panel'da "İzohips" toggle çalışır
- ✅ Opacity 0-100% slider yumuşak update
- ✅ Hillshade ile birlikte açık olabilir (üstüne biner, %50 default opacity)
- ✅ Mobile native parite (Android'de aynı görünüm)
- ✅ Performance: zoom yumuşak, tile fetch < 2 sn

---

## 🧠 SPRINT P — ML PROJEKSİYONU

### Phase P1 — Backend: SARIMAX pin generation forecast (6-7 gün)

**Model:** statsmodels `SARIMAX(p,d,q)(P,D,Q,12)` + `pmdarima.auto_arima` ile order seçimi.

**Avantaj-Maliyet:**
| Boyut | Prophet | SARIMAX | Linear+Seasonal |
|---|---|---|---|
| Disk | ~200-350 MB | ~30 MB | 0 MB |
| Kalite | %100 | %85-90 | %60-70 |
| Implementation | 7-8 gün | 6-7 gün | 5 gün |
| Confidence band | Var | Var | Manuel σ |

| # | Görev | Dosya | Effort |
|---|---|---|---|
| P1.1 | `pip install statsmodels pmdarima` + requirements.txt güncel | backend | 30 dk |
| P1.2 | `ml_projection_service.py` rewrite | SARIMAX wrapper class | 1 gün |
| P1.3 | `project_pin_generation(pin_id, years_ahead=5)` | Pin'in geçmiş üretiminden gelecek tahmin. 60 ay forecast + 95% CI | 1 gün |
| P1.4 | `project_climatology(province, resource, years_ahead)` | İl bazlı climatology trend tahmini (irradiance, wind speed) | 1 gün |
| P1.5 | Auto-ARIMA order seçimi | `auto_arima` ile (p,d,q)×(P,D,Q,s) otomatik | 4 saat |
| P1.6 | Backend endpoint `/ml/project/pin/{id}?years=N` | FastAPI router | 4 saat |
| P1.7 | Backend endpoint `/ml/project/province/{name}?years=N` | il bazlı | 4 saat |
| P1.8 | Unit test + smoke test | Geçmiş verinin son 1 yılı kapatılarak validation. MAPE < %20 hedef | 1 gün |
| P1.9 | Redis cache layer | Pin forecast 24 saat, province forecast 7 gün | 4 saat |

**Validasyon planı:**
- Climatology'de 10 yıl monthly veri var → ilk 9 yılı train, son 1 yılı test
- Mean Absolute Percentage Error (MAPE) hesapla
- Pin başına ve il başına kabul kriteri: MAPE < %20

### Phase P2 — Frontend ML UI (3-4 gün)

| # | Görev | Dosya | Effort |
|---|---|---|---|
| P2.1 | Reports'a 7. tab: "Projeksiyon" | `report_screen.dart` (+1 tab) | 2 saat |
| P2.2 | Pin seçici (Santral tab pattern'i) | yeni `projection_tab.dart` | 4 saat |
| P2.3 | Horizon slider (1-10 yıl) | + reload trigger | 2 saat |
| P2.4 | Forecast LineChart | `fl_chart` historical solid + forecast dashed + CI fill | 1 gün |
| P2.5 | Yıllık KPI grid | "5 yıl toplam üretim", "Trend ±%", "MAPE %", "Güven" rozetleri | 4 saat |
| P2.6 | `ml_projection_placeholder.dart` → real widget | Mevcut placeholder dosyasını gerçekle değiştir | dahil |
| P2.7 | İl bazlı projeksiyon — İl Analizi tab'a sub-tab | "Projeksiyon" alt sekme (Potansiyel/Hava/Projeksiyon) | 4 saat |

### Phase P3 — Climate scenarios (opsiyonel, 3-5 gün, isteğe bağlı)

**Kullanıcı kararı: MVP'ye dahil değil.** P1+P2 tamamlanınca tekrar gözden geçirilir.

İçeriği (referans):
- RCP 4.5 (iyimser) / RCP 8.5 (kötümser) toggle
- Sıcaklık artışı → solar verim düşüşü (-0.4%/°C)
- Climatology baseline'a bias correction

---

## 📅 ÖNERİLEN ÇALIŞMA AKIŞI

```
[Test fasılası — N1-N5 + CSV doğrulama] (kullanıcı)
        │
        ▼
[Backend P1 + Frontend O1 paralel başla]
   ├─ Backend: P1.1-P1.5 (5 gün)        ─┐
   └─ Frontend: O1.1-O1.5 (1 gün)        ├─ Çakışmaz, paralel
        │                                 │
        ▼                                 │
[Backend P1.6-P1.9 + Frontend O2 paralel]  ←─┘
   ├─ Backend: P1.6-P1.9 (2 gün)
   └─ Backend: O2.1-O2.6 pipeline (3-5 gün)
        │
        ▼
[Frontend P2 (3-4 gün)]
   └─ ML UI — chart, KPI, projection tab
        │
        ▼
[Test fasılası — kullanıcı testi]
        │
        ▼
[Karar: P3 climate scenarios mı, AWS deploy mı?]
```

**Toplam minimum (P3 hariç):** ~12-14 gün (yaklaşık 2 hafta yoğun mesai)
**P3 dahil:** ~17-19 gün (3 hafta)

---

## 🚨 RİSKLER & MİTİGASYON

| Risk | Etkisi | Mitigasyon |
|---|---|---|
| OpenTopoMap rate limit (O1) | Production'da çökme | O2'yi paralel başlat → ready when needed |
| SARIMAX cold start yavaş (P1) | İlk istek 5-10 sn | Redis cache + pre-warm script (pop. iller önceden) |
| Pin verisi az (<6 ay) → kötü forecast | MAPE çok yüksek | Fallback: pin geçmişi yoksa il climatology üzerinden trend |
| Mobile bandwidth — contour tiles ağır | Yavaş yükleme | min_zoom 9 ile sınırla; mobile auto-off seçenek |
| auto_arima yavaş (her pin için) | Endpoint yavaş | Order'ı cache et (pin başına tek seferlik) |

---

## 📋 SPRINT KABUL KRİTERLERİ

### O Sprint:
- Layers panel'da "İzohips" toggle açılıp kapanır
- Opacity slider çalışır, 0→100% smooth
- O1 phase: OpenTopoMap layer görünür, attribution chip görünür
- O2 phase: Self-hosted MVT tile server çalışır, kontür çizgileri elevation'a göre renkli, major lines (her 500m) label'lı

### P Sprint:
- `/ml/project/pin/{id}?years=5` → JSON: `{months: [...60], forecast: [...60], lower: [...60], upper: [...60], mape: 0.15}`
- Reports'ta "Projeksiyon" tab açılır
- Pin seçilince chart 1-2 sn içinde gelir
- Horizon slider değişimi anında reload
- Validasyon: en az 3 farklı pin için MAPE < %20

---

## 🔗 BAĞLI NOTLAR

- [[INBOX]] — kullanıcı test feedback'leri buraya gelir
- [[BACKEND-PLAN-2026-05-17]] — eski backend sprint planı (S1-S7)
- [[project_future_features]] (memory) — "ML projeksiyonu" maddesi (artık aktif sprint)

---

## ✅ TAMAMLAMA İZ

- [ ] Phase O1
- [ ] Phase O2
- [ ] Phase P1
- [ ] Phase P2
- [ ] (Opsiyonel) Phase P3
- [ ] Sprint sonu retrospektif → vault güncelle, INBOX'a tamamlananları yaz

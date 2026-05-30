---
tags: [concept, reports, sprint, checkpoint, frontend, backend]
updated: 2026-05-20
related: [INDEX, INBOX, BACKEND-PLAN-2026-05-17, ChoroplethScales]
---

# 📊 Raporlar v3 — Landing-first Hiyerarşi

> Kullanıcının `SRRP Raporlar.html` mockup'ından doğan yeniden tasarım.
> Eski 5 tab (İl Analizi, Senaryo, Trend, Harita, Export) → yeni **6 tab**.
> Hiyerarşi: **Türkiye → Bölge → İl → İlçe → Pin**.

## 🎯 Amaç

Raporlar ekranı drill-down hiyerarşisiyle yeniden kuruldu. Genel Bakış'tan
bölge kartına, oradan il kartına tıklayarak detaya inilir. Tüm tab'lar
climatology + statik veri kaynaklı, gerçek/mock hibrit.

## 🗂️ 6 Tab (sıra önemli — `report_screen.dart` index'leri)

| # | Tab | Dosya | Veri kaynağı |
|---|-----|-------|--------------|
| 0 | Genel Bakış (Landing) | `tabs/landing_tab.dart` | `/analysis/landing` |
| 1 | Bölge | `tabs/region_tab.dart` | `/analysis/region/{id}` |
| 2 | İl Analizi | `tabs/province_drill_tab.dart` | `/analysis/province/*` |
| 3 | Senaryo | `tabs/scenario_compare_tab.dart` | `/scenarios/*` |
| 4 | Santral | `tabs/santral_tab.dart` | `/pins/{id}/generation` |
| 5 | Export | `tabs/export_tab.dart` | (mevcut) |

Eski "Trend" ve "Harita" tab'ları kaldırıldı — Landing'e eridi.

## 🧩 Mock → Gerçek Fallback Mimarisi (kritik)

`climate_aggregate_service.py` **önce climatology DB**'yi okur, JSON kolonları
NULL ise `data/mock_climate_regional.json`'dan bölge template'i döner.
**R0 Colab CSV'leri import edilince** (`scripts/import_colab_csvs.py`) DB
dolar → mock otomatik devre dışı. Frontend kodunda **sıfır değişiklik**.

`source` flag'i: `"db"` | `"mock_region:karadeniz"` | `"hybrid_5of10_db"`.
UI'da rozet olarak gösterilir (turuncu=mock, yeşil=db).

## 🔌 Backend (yeni — 2026-05-20)

- **Migration 016**: `climatology` tablosuna 5 JSON kolon —
  `wind_direction_histogram`, `monthly_precipitation`, `monthly_cloud_cover`,
  `monthly_sunshine_hours`, `monthly_river_discharge`
- Endpoint'ler (`routers/analysis.py`): `/landing`, `/region/{id}`,
  `/province/{name}/climate`, `/province/{name}/districts`
- Servisler: `climate_aggregate_service.py` (DB+mock), `district_scoring_service.py`
  (ilçe sentetik skor — deterministic hash noise)
- Statik veri: `data/tr_stats.json` (TEİAŞ 2024), `data/tr_regions.json`
  (7 bölge × 81 il), `data/mock_climate_regional.json`

## 🧭 Tab-arası Navigasyon

`ReportNavController` (`viewmodels/report_nav_controller.dart`) — tab'lar ayrı
`ChangeNotifierProvider` scope'larında. Drill-down mesajı `pendingRegionId` /
`pendingProvince` ile taşınır, hedef tab `consumeRegion()/consumeProvince()`
ile tüketir. `report_screen.dart` seviyesinde provide edilir.

## 📐 Sprint Durumu (R0-R4)

- **R0** Veri çekme — 🟡 440/940 ilçe · gece 04:00 görevi (`run_overnight_fetch.bat`)
- **R1** Landing + Bölge — ✅ KPI + pasta grafik + climate strip + Wind Rose
- **R2** İl + Hava sub-tab — ✅ 3 kolon ilçeler + karşılaştırma tablosu
- **R3** Santral — ✅ pin detay + üretim + interaktif simülatör · *TR Finans bekliyor*
- **R4** Senaryo — ✅ tek detay + Kıyasla (2'ye böl) + finans + cashflow

## ⚠️ Bilinen Tuzaklar

- **`RegionSummary` ad çakışması**: `weather_model.dart`'ta zaten var. R1'in
  yeni sınıfı `RegionMeta` olarak adlandırıldı. `analysis_service.dart`'ta
  `TrendPoint` → `LandingTrendPoint` aynı sebeple.
- **Climatology il adı karışıklığı**: DB'de hem "Balıkesir" hem "Balikesir"
  ayrı satır. Endpoint'ler `province_aliases` ile her iki varyasyonu eşler.
- **HES skoru çoğu ilde NULL**: climatology hydro skoru üretmiyor — debi
  verisi (R0 C scripti) gelince düzelecek.

## ⏳ Bekleyen

- TR Finans paneli (YEKDEM/CAPEX/vergi — kullanıcı araştırması)
- HES ML debi projeksiyonu (`ml_projection_service`'e 4. metrik)
- Gece veri çekimi tamamlanınca mock→gerçek doğrulaması

## 📁 İlgili Dosyalar

- Frontend: `lib/features/reports/` (tabs/, viewmodels/, widgets/climate/)
- Backend: `routers/analysis.py`, `services/climate_aggregate_service.py`,
  `services/district_scoring_service.py`, `alembic/versions/016_*`
- Colab: `colab/A_*.py`, `colab/B_*.py`, `colab/C_*.py`, `colab/README.md`
- Import: `backend/scripts/import_colab_csvs.py`

## 🔗 Bağlantılar

- [[BACKEND-PLAN-2026-05-17]] — S1 climatology (bu işin temeli)
- [[ChoroplethScales]] — harita renk skalaları
- [[INBOX]] — günlük sprint kayıtları

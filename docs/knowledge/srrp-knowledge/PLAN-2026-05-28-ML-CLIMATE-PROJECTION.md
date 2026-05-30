---
created: 2026-05-28
updated: 2026-05-28
tags: [plan, sprint, ml, climate-projection, choropleth, thematic-map]
related: [INDEX, PLAN-2026-05-27-IZOHIPS-ML, TESTS-2026-05-28-O2-P2-P3]
status: in-progress
---

# 🧠🗺️ PLAN — ML İklim Projeksiyonu + Tematik Harita (2026-05-28)

> Kullanıcı kararları (AskUserQuestion):
> - **ML yaklaşımı:** İklim projeksiyonu + batch precompute (günlük hava DEĞİL,
>   aylık iklim normali + RCP trend; günlük gösterim interpolasyonla)
> - **Relief:** Terrain-RGB + istemci renklendirme (ayrı sprint, ML'den sonra)
> - **Sıra:** Önce ML

## 🎯 Vizyon

Kullanıcının istediği: "Türkiye'nin geleceğe dönük hava/iklim durumu, il+ilçe
+pin bazında, tematik haritada zaman içinde gösterilsin."

**Bilimsel çerçeve:** Hava ~14 gün öngörülebilir (kaos). 10 yıl ileri "günlük
hava" imkânsız. Bunun yerine **iklim projeksiyonu**: aylık mevsim normali +
uzun-vade trend (SARIMAX) + RCP senaryo deltası. Günlük gösterim = mevsimsel
spline interpolasyonu.

**Cevaplanacak sorular:**
1. İllerin geleceğe dönük iklimi? → il choropleth + yıl slider
2. İlçelerin geleceğe dönük iklimi? → ilçe choropleth
3. İl/ilçe potansiyelleri? → mevcut skorların gelecek projeksiyonu
4. Pinlerin gelecekteki enerji + finansal dönütü? → üretim×tarife

---

## 📦 Mevcut Altyapı (yeniden kullanılacak)

- ✅ `climatology` tablosu — il + ilçe satırları, monthly_* JSON kolonlar
- ✅ `SARIMAXForecaster` + `project_climatology` (P1)
- ✅ `climate_scenarios.py` RCP4.5/8.5 delta motoru (P3)
- ✅ `/analysis/choropleth/{metric}` + `_syncChoropleth` (web+native) — TEMATİK HARİTA HAZIR
- ✅ Grid aggregation 1003 nokta (il+ilçe)
- ✅ Projeksiyon tab (P2)

---

## 🚀 SPRINT M — ML İklim Projeksiyonu

### M-A — Batch precompute altyapısı  ← ŞİMDİ
| # | Görev | Dosya |
|---|---|---|
| M-A.1 | `ml_forecast` tablosu + migration 017 | `models.py`, `alembic/versions/017_*` |
| M-A.2 | İlçe aylık seri builder (climatology/grid'den) | `ml_sarimax_service.py` |
| M-A.3 | Best-model seçimi (auto_arima / Holt-Winters / linear+seasonal → min MAPE) | `ml_sarimax_service.py` |
| M-A.4 | `build_ml_forecasts.py` batch — il+ilçe × metrik × senaryo → DB | `scripts/` |

### M-B — Tematik harita zaman boyutu
| # | Görev | Dosya |
|---|---|---|
| M-B.1 | `/ml/choropleth/{metric}?year=&scenario=&level=province\|district` | `routers/ml.py` |
| M-B.2 | Frontend yıl slider + senaryo seçici + ▶ oynat | yeni panel widget |
| M-B.3 | maplibre choropleth zaman güncellemesi (web+native) | `index.html`, native |

### M-C — Pin finansal projeksiyon
| # | Görev | Dosya |
|---|---|---|
| M-C.1 | Pin gelir projeksiyonu (üretim × tarife/YEKDEM) | `ml_sarimax_service.py` |
| M-C.2 | Frontend pin finansal kart | `projection_tab.dart` |

### M-D — Günlük interpolasyon + UI cilası
| # | Görev | Dosya |
|---|---|---|
| M-D.1 | Aylık→günlük mevsimsel spline | `ml_sarimax_service.py` |
| M-D.2 | Projeksiyon tab cila + tematik harita gömme | frontend |

---

## ⚡ Performans Stratejisi

- **Batch precompute** → kullanıcı hiç model fit beklemez, DB okur
- Aylık çözünürlük → ~970 ilçe × 4 metrik × 3 senaryo = ~1.5M satır (Postgres'te küçük)
- Günlük gösterim → istemci/sunucu interpolasyon (depolama yok)
- Choropleth endpoint Redis cache (yıl+senaryo+metrik anahtarı)

## ⚠️ Bilinen Kısıt — İlçe çözünürlüğü
Climatology'de **ilçe-bazlı satır yok** (R0 Colab climate CSV'leri il-keyed). Gerçek
ilçe-çözünürlüklü iklim serisi için Open-Meteo'dan per-ilçe çekim gerekir (büyük veri
işi, sonraya). Şimdilik **ilçe choropleth = ilin forecast değeri** (downscaling yok).
İl bazlı: 162 kombinasyon × 2 metrik = 324 seri, ~117K satır precompute edildi.

## Durum (2026-05-28)
- **M-A** ✅ tablo+migration 017, ml_batch_service (multi-family seçim), batch ~117K satır
- **M-B.1** ✅ `/ml/choropleth/{metric}` + `/years` endpoint (canlı test geçti)
- **M-B.2/3** ⏳ frontend tematik harita animasyon — backend+dart servis hazır, UI kaldı (interaktif test gerekir)
- **M-C** ✅ backend + frontend (PinFinancialCard, USD/TL toggle, kümülatif net chart). Pin kWh birim bug'ı düzeltildi (1MW→1.58M kWh, payback 2031).
- **M-D** ⏳ günlük interpolasyon + cila kaldı

## Sprint M-E/F/G/H — Yeni vizyon (2026-05-28)
Kullanıcı kararları:
- **İlçe-seviyesi ML**: 1003 ilçe × aylık × 10 yıl forecast precompute
- **Aylık ML projeksiyon**: yıllık-ortalama dışında ay-bazlı seriler
- **Yüksek nitelikli ML**: mevsim+ay özellikleri (Fourier), opsiyonel CO₂ exogenous
- **Raporlar tüm-yıllar grafiği**: 10 yıl geçmiş + 10 yıl projeksiyon tek grafikte

### M-E — Veri tamamlama (precipitation/cloud/humidity)
- M-E.1: weather_data günlük tabloya `precipitation_sum`, `cloud_cover_mean`, `humidity_mean` ekle (migration + Open-Meteo backfill 2015→bugün)

### M-F — İlçe ML
- M-F.1: ilçe aylık seri builder (climatology değil, **daily weather_data aggregate**)
- M-F.2: build_ml_forecasts.py ilçe scope; tüm ilçeler için precompute

### M-G — Yüksek nitelikli ML
- M-G.1 ✅: SARIMAX(p,d,q)(P,D,Q,12) + **exog [month_sin, month_cos, year_trend]**
  - SARIMAXForecaster._build_exog, with_exog=True default
  - method label: `sarimax_auto_exog`
  - Aksaray test: flat-218 → 2025:217.7 → 2034:213.8 (trend %0.24/yıl)
- M-G.2 ⏳: Cloud × Radiation joint modeling (M-E sonrası)

### M-H — Raporlar + UI
- M-H.1 ✅ backend: project_climatology daily-aggregate (109 ay gerçek), /ml/series endpoint
- M-H.2 ✅: mevcut endpoint zaten aylık döner
- M-H.3 ✅: ML harita renk skalası legend (min-max gradient + metric birimi)
- M-H.4 ✅: ML harita aylık slider (120-step, Mar 2028 vb.)

### M-I — Veri kalitesi
- M-I.1 ⏳: Batch tamamlanınca aykırı değer denetimi

### M-J — UX netlik
- M-J.1 ✅: Baz vs senaryo açıklayıcı not (flat-yıllık yanılgısını önle)

### M-E — Veri tamamlama
- M-E.1 ⏳: weather_data precipitation/cloud/humidity backfill (Open-Meteo Historical)
  - Migration 020 ✅, backfill_weather_extras.py ✅, arka planda çalışıyor

## Sprint T — Tematik harita uzun pencereler (2y/5y/10y) ✅
- **T-1..T-5** ✅ time_window genişletme, thematic_aggregate tablo+migration 018, hibrit batch (yakın saatlik/eski günlük), precomputed serving + aylık scheduler, frontend enum+seçici
- **T-6** ✅ thematic_timeseries tablo+migration 019, build_thematic_timeseries batch (428K), /weather/animation-precomputed, time sim panel Haftalık/Aylık ⚡ + Son N yıl
- Bilinen kısıt: weather_data son ~1 yıl province_name backfill boşluğu → en güncel frame'ler seyrek

## Son Değişimler
- 2026-05-28: M-A tamamlandı — `ml_forecast` tablosu (migration 017), `ml_batch_service.py`
  (ilçe seri builder + multi-family model seçimi: SARIMAX/Holt-Winters/linear+seasonal),
  `build_ml_forecasts.py` batch (324 il serisi × 3 senaryo = ~117K satır). İlçe verisi
  yok → il değerinden türetilecek.
- 2026-05-28: M-B.1 choropleth endpoint + M-C backend (pin finansal) + dart servis katmanı
  (MlChoropleth, MlPinFinancial DTO). Pin kWh fallback birim bug'ı spawn task ile ayrıldı.

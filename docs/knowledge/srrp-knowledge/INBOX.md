---
tags: [inbox]
updated: 2026-05-25
---

> **2026-05-25 Reports Rework Sprint 3 (G1-G8 — kullanıcı test feedback'i):** Test 2 sonrası yeni feedback için 8 görev. **G1 Capacity widget close:** Eski tek satırda HES + close butonu yoktu. Yeni 2 satır layout (Rüzgar·Güneş·Kapasite üst / HES alt) + sağ üstte close (─) ikonu collapsed pill'e döner. **G2 ReportMiniMap tap-to-activate:** Parent scroll içinde harita gesture conflict (yanlış yer + kaydırılamıyor). Default `AbsorbPointer(absorbing:true)` + ortada "dokun" hint; tap → `_active=true` mavi border + "Bitir" chip (sağ üst) → tap kapatır. **G3 İl Analizi tablo satır renklendirme:** Score'a göre 6 ton subtle bg (emerald 80+ / green 70+ / lime 60+ / amber 50+ / orange 40+ / red <40, alpha 0.04-0.08). **G4 Karşılaştırma sistemi:** Tablo satırlarına checkbox (28dp sol kolon) + 2+ seçilince üstte "Karşılaştır (N)" butonu + yeni `ComparePage` (`pages/compare_page.dart`) — bar+score breakdown, geri tuşu auto. minTableWidth 560→600. **G5 Senaryo pin tıklanabilir:** _PinList'teki satırlar artık StatelessWidget _PinRow → InkWell + `ReportNavController.requestPin` ile Santral drill-down + chevron ikonu, pin adı + şehir gösterimi (vm.allPins'ten lookup). **G6 Senaryo düzenleme:** Header'a "Düzenle" butonu + `ScenarioEditDialog` (yeni dosya `widgets/dialogs/scenario_edit_dialog.dart`) — ad, açıklama, tarih aralığı (showDateRangePicker), pin checkbox listesi tipe göre grupland (Güneş/Rüzgar/Hidro). Submit → `vm.updateScenarioFields` → PUT /scenarios/{id} → otomatik recalculate. metaChip'ler tıklanır olarak güncellendi. **G7 Gerçek karşılaştırma sayfası:** Eski "ekran 2'ye böl" `_CompareView` SİLİNDİ. Toolbar "Kıyasla" → Navigator.push → yeni `ScenarioComparePage` — KPI delta tablosu (toplam kWh, Solar/Wind/Hydro, CAPEX, NPV, IRR, LCOE, payback delta + yeşil/kırmızı renk + %fark), aylık delta bar chart (A-B her ay; orta çizgi 0 referans), pin overlap card (sadece A / ortak / sadece B sayıları). compareMode toggle kaldırıldı. **G8 İlçe drill-down:** _DistrictRow tap → yeni `DistrictDetailPage` (`pages/district_detail_page.dart`) — best resource hero, 3 büyük score bar, ilçe merkez+0.2° bbox bound mini harita (G2 tap-to-activate), tahmini MW. Checkbox tap kendi sandbox'ında (`GestureDetector behavior: opaque`), satırın geri kalan InkWell tap = detay aç. Toplam: ~1600 satır eklendi, ~150 silindi, 4 yeni dosya + 6 modify. `flutter analyze` 0 issue.

> **2026-05-25 Reports Rework Sprint 2 (F1-F4, Fix1-6, P1/4, P2/6, P2/7, Polish1-2):** Test sonrası bildirilen UI sorunları için kapsamlı rework. **F1 Quick Fixes (4):** AppBar Yıllık/Aylık ölü toggle silindi; MapDashboard ↔ Pin Ekle çakışma (mobilde collapsed pill <480dp); bottom sheet "Kü..."/"R..." overflow (AnimatedGradientButton compact mode); Zaman Sim 61px overflow (playbackRow 2 satıra bölündü). **F2 Mobile Reports:** Yeni shared `ReportRangeSelector` widget'ı, Santral period chip'i, Region 6-KPI mobilde 3×2 grid. **F3 Web Reports:** Landing maxWidth 1400 cap, KPI aspectRatio responsive (1.5→2.4), Region tab ≥1100px master-detail (40/60). **F4 Tıklanabilir Harita:** `ReportMiniMap` + `bounds` (LngLatBounds) + `onMarkerTap` desteği — bölge/il sınır içinde clip, drill-down. **Kullanıcı Fix Listesi:** WeatherStrip'lerde MIN/ORT/MAX + ORT çizgisi + bar üstü değer (Fix1); Landing bölge kartları aspectRatio + Wrap (Fix2); İlçe Karşılaştırma Tablosu yatay scroll + minTableWidth 560, Senaryo Toolbar mobilde Column (Fix3); Santral Hero KPI 2+1 grid + Toolbar dropdown Expanded (Fix4); İl Analizi geniş ekran Potansiyel+Hava yan yana (Fix5); Senaryo paneline pin mini haritası bbox-bound + drill-down (Fix6). **P1/4 Senaryo Aylık Breakdown:** Backend `_monthly_distribution(pin, resource)` climatology profilinden 12-ay payı (solar→sunshine, hydro→discharge, wind→flat); frontend stacked bar chart (`_MonthlyBreakdownChart`). **P2/6 Pin Capacity Validation 3 katmanlı:** Frontend `validate()` HES flow/head zorunlu + GES panel_area ≥10 m², backend `PinCreate` Pydantic `model_validator`, `cleanup_invalid_pins.py` script (dry-run/--fix/--delete). **P2/7 Source Badge Unify:** Inline `_SourceBadge`/`_ClimateSourceBadge` → shared `ReportSourceBadge`. **Polish:** `ReportNavController.requestPin` ile senaryo→santral drill-down; ScenarioReportVM `pinsLoaded` ayrımı (loading vs empty). **Toplam:** ~1500 satır eklendi, ~400 silindi, 13 frontend + 3 backend dosya. `flutter analyze` 0 issue, backend smoke test ✅.

---

## 🚀 Production / Canlı Deploy Notları (Amazon EC2'ye geçişte)

- [ ] **DB geçersiz pin temizliği:** `cd backend && .\venv\Scripts\python.exe scripts\cleanup_invalid_pins.py` ile dry-run rapor al, sonra `--delete` ile sil. Lokal DB'de 10 geçersiz pin var (8 GES city=NULL, 1 RES "Yurtdışı" kasıtlı koru, 2 HES flow/head=0). Production'a temiz DB ile geç. Detay: `backend/scripts/cleanup_invalid_pins.py` docstring.
- [ ] **Backend pin validation server-side:** P2/6c ile PinCreate Pydantic validator devrede; PUT /pins/{id} de aynı şemayı kullandığı için bypass yok. Production'da frontend versiyonu güncel mi kontrol et.
- [ ] **Climatology canonical:** 81 il Türkçe canonical (2026-05-24 dedup script çalıştırıldı). Production'a clean import script ile.
- [ ] **Cleanup script Windows console encoding:** `sys.stdout.reconfigure(encoding="utf-8")` ile cp1254 fix edildi. Linux EC2'de zaten utf-8 default.
- [ ] **RES için aylık wind verisi eksik:** Climatology tablosunda aylık wind speed kolonu yok — `monthly_breakdown` RES için düz dağılım (1/12). Production öncesi Open-Meteo aylık ortalama wind fetch script + climatology kolonu ekle.

---

> **2026-05-20 Reports Rework v3 (R0-R4) — Raporlar Yeniden Tasarımı:** Kullanıcının `SRRP Raporlar.html` mockup'ına göre Raporlar ekranı baştan kuruldu. Eski 5 tab → **6 tab** (Genel Bakış · Bölge · İl Analizi · Senaryo · Santral · Export), hiyerarşi Türkiye→Bölge→İl→İlçe→Pin. **Backend:** Migration 016 (climatology'e 5 JSON kolon: wind_direction_histogram, monthly_precipitation/cloud_cover/sunshine/river_discharge), 4 yeni endpoint (`/analysis/landing`, `/region/{id}`, `/province/{name}/climate`, `/province/{name}/districts`), `climate_aggregate_service` (DB-önce mock-fallback), `district_scoring_service` (ilçe sentetik skor), statik veri (tr_stats.json TEİAŞ 2024, tr_regions.json 7 bölge × 81 il, mock_climate_regional.json). **Frontend:** 6 tab gerçek içerikle — Landing (KPI + **pasta/donut grafik** + 7 bölge kartı + Top 10 + 10-yıl trend + potansiyel/gerçek), Bölge (climate strip + Wind Rose + debi + il grid), İl Analizi v3 (Potansiyel/Hava sub-tab + 3 kolon GES/RES/HES ilçeler + karşılaştırma tablosu), Senaryo (tek detay + **Kıyasla butonu → ekran 2'ye böl** + finans kartları + cashflow grafiği), Santral (pin seçici + üretim + type detay + **interaktif simülatör** GES tilt/azimuth + RES power curve/hub + climate profili). **Mock→gerçek geçiş:** climate JSON kolonları NULL ise mock'tan beslenir, `import_colab_csvs.py` ile DB dolunca otomatik gerçeğe döner — frontend dokunulmaz. **Drill-down navigasyon:** `ReportNavController` ile bölge kartı→Bölge tab, il kartı→İl tab. **R0 veri:** Open-Meteo'dan 940 ilçe × 10 yıl çekiliyor — 440/940 climate çekildi, kalan + A/C scriptleri için gece 04:00 Windows zamanlanmış görevi (`run_overnight_fetch.bat`) kuruldu (kota reset sonrası). Tüm `flutter analyze` temiz. Detay: [[ReportsV3]].

> **2026-05-09 Sprint:** Pin pozisyonlama clip-aware fix (spaceAbove/Below boundary detect + tail flip), `lottie` paketi pubspec'e eklendi (asset gelince Lottie wrapper hazır), [[AnimatedGradientButton]] reusable widget (hover/tap-only shimmer sweep + 6 mikro-ikon), bottom sheet Kütüphane/Raporlar butonları yeni widget'la değiştirildi, chatbot `_safe_response_text` (`part.function_call` parça'ları için fallback), İç Anadolu Türkçe-safe lowercase fix, Raporlar slide-up animasyon route.

> **2026-05-09 Sprint Devam — Pin Mimari Refactor:** PinDetailsDialog pin tıklamada hâlâ side-panel fallback'indeydi (AI FAB ona göre kayıyordu) — pin click anında `_pinAnchorScreenPos` artık pin lat/lng'sinden hesaplanır, harita pan/zoom'da pin'le birlikte takip eder. Daha büyük refactor: [[PinPanelShell]] composition widget (Flutter idiomatic) — AddPinDialog + PinDetailsDialog ortak kabuk (header, il/ilçe, gradient, scroll). Kod tekrarı %30 azaldı, yeni pin modları (karşılaştır/optimize) artık tek body widget yazarak eklenir.

> **2026-05-09 Sprint 4 — Pin Perf + Suitability + 4-yön Soft:** Pin pop-up'larda kasma fix: anchor pixel pos `ValueNotifier` + `ValueListenableBuilder` + `RepaintBoundary` ([[PinAnchorPerf]]) — Stack rebuild yok, sadece overlay paint güncellenir. Pop-up positioning 4-yön (above/below/right/left) + `AnimatedPositioned` 250ms easeOutCubic soft geçiş. Tip-aware [[SuitabilityChecks]]: backend `solar_details/wind_details/hydro_details` parse, AddPinDialog tip değişiminde cache'den re-evaluate (yeni API yok), PinDetailsDialog edit mode'da check + uyarı banner (block etmez). MOBİL ertelenenler: il modu native, zaman simülasyonu native frame, MVT vektör paket sınırı, rüzgar partikül parite, pin form/popover native parite — kullanıcı mobil aktif edince yapılacak.

> **2026-05-09 Sprint 5 — Pop-up Basitleştirme + Pinler Arası Geçiş:** Sprint 4'ün overengineering'i geri sarıldı: `AnimatedPositioned` kaldırıldı (kapanma anında ortaya animate eden glitch + pin pan/zoom takip lag) → sade `Positioned`. Kapanma fallback `Positioned(bottom:16,...)` kaldırıldı → `SizedBox.shrink()` (widget tree'den çıkar, glitch yok). Click guard mantığı düzeltildi (`map_view_maplibre_web.dart`): pop-up açıkken sadece pin tıklamasına izin verilir (selection/choropleth engellenir) → pinler arası geçiş etkin. Popover kapatınca `placingMode` otomatik temizlenir. [[PinAnchorPerf]] yaygın tuzaklara `AnimatedPositioned KULLANMA` notu eklendi.

> **2026-05-09 Sprint 6 — just_the_tooltip Migration:** Sprint 5 fix'leri yetmedi (kasma + pinler arası geçiş + AI FAB sola kayma sorunları devam etti). Kullanıcı: "Sade derken bunu kastetmiyordum, just_the_tooltip kütüphanesini ekle." pubspec'e `just_the_tooltip: ^0.0.12` eklendi. Custom `_anchoredPositioned` + `_PinPopoverWithTail` + `_TailPainter` + `_Placement` enum **silindi** (~200 satır kod azalması). Yeni `_PinTooltipHost` widget'ı `JustTheController` + `JustTheTooltip` ile pin form/detail/popover ortak kabuk. AI FAB `right` mantığı: pin form/detail çakışma kaldırıldı (artık side panel değil → sola kaymıyor). Detay: [[JustTheTooltipPattern]].

> **2026-05-09 Strategic Reset — PinFlowController:** Sprint 6 da yetmedi (V3 popover anında kayboluyor, pinler arası geçiş çalışmıyor, kasma devam, AI FAB sola). Kök neden: **8+ state field karmaşası**, 3 ayrı pop-up tek anchor notifier paylaşıyordu, eski `VM.placingPinType` ile yeni `_placingMode` paralel path'ler. **Tüm pin akışı yeniden tasarlandı.** Yeni: [[PinFlowController]] (ChangeNotifier state machine: idle→placing→typeSelection→addForm→detail→editForm) + tek `PinFlowOverlay` widget (controller-driven). Eski 8 state field + 12 helper metodu + dosya-içi `_PinTooltipHost` SİLİNDİ (~400 satır azalma). `VM.placingPinType`/`activePinDetail` deprecate (geriye uyum). PinsPanel + ScenarioSidePanel cross-sheet caller'lar `Provider.of<PinFlowController>` ile controller'a yönlendirildi. Test öncesi `flutter clean && flutter pub get && flutter run -d chrome` GEREKLİ. Detay: [[PinFlowAudit]], [[PinFlowController]].

> **2026-05-19 Bug 3 + Bulk Fix + Alias Map (3'lü combo):** Test 7 sonucu pinler 1000× düşük üretim gösteriyordu — kök sebep `capacity_mw` formülünün **tek panel** olarak kayıtlı olmasıydı. Üç katmanda düzeltildi: (1) **Frontend** `PinDialogViewModel.getSelectedCapacityMw` formülü: GES için `panel_area × efficiency × 1 kW/m² / 1000 MW`, HES için `8.5 × Q × H / 1000 MW`, RES için aynı (tek türbin). (2) **Backend bulk fix** `scripts/fix_existing_pins.py`: tüm pin'leri taradı, **97 pin'in city/district** null'dan GADM reverse-geocode ile dolduruldu, **71 pin'in capacity_mw**'i yeniden hesaplandı. (3) **`province_aliases.py`** helper: Kahramanmaraş↔K. Maras, Afyonkarahisar↔Afyon gibi DB'deki kısaltmalı yazımları çözüyor. Test sonucu: 99 pin doğru, 19 no_data (HES'ler + Türkiye dışı koordinat pin'leri). Pin örnekleri: İstanbul RES 4.5 MW→240K kWh/ay ✅, İzmir RES 6.2 MW→273K kWh/ay ✅, Hatay GES 575 kW→73K kWh/ay ✅, Çanakkale GES 57 kW→7K kWh/ay ✅. Önceki 7.5M+ kWh imkansız değerler kayboldu, gerçekçi MW seviyesinde.

> **2026-05-19 Pin Generation Bug A+B Fix (NULL guard + multi-district avg):** Test 7 ile fark edilen 2 ek bug. (A) `pin.city=None` durumda filter atlanıp **tüm Türkiye'nin** hourly_weather toplanıyordu → 7.5M kWh gibi imkansız değerler (İstanbul/Eskişehir RES pin'leri). Fix: city None → erken çık, `no_data` döner. (B) `pin.district=None` durumda city eşleşip district filter olmadığı için her timestamp **TÜM ilçeler için ayrı ayrı sayılıyordu** → 12× yanlış toplam (Çanakkale GES 66700 kWh). Fix: `func.avg(metric) GROUP BY timestamp` ile ilçeler arası saatlik ortalama, sonra power_curve × capacity. Doğru pin'ler etkilenmedi (Samsun GES 22.46 kWh tutarlı). Eski tablodaki 5.7M/7.5M/66700 değerleri sıfırlandı veya gerçekçi hale geldi. **Bug 3 (capacity_mw=275W tek panel)** hala bekliyor — pin oluşturma capacity formülü yanlış, mevcut pin'ler 1000× düşük kapasiteli kayıtlı.

> **2026-05-19 Pin Generation Match Fix:** Test 7 API'ında her zaman `total_kwh=0` dönüyordu. Kök sebep `_generation_from_hourly_actual`'da `lat/lon round(0.5) grid` exact match — `hourly_weather_data` farklı precision'da toplandığı için hiç eşleşmiyordu. **Düzeltme:** city_name + district_name eşleşmesi (ASCII fold ile Balıkesir/Balikesir gibi varyasyonları tolere eder). Ek olarak: saatlik veri boş döndüyse `_generation_from_climatology` fallback'e geçsin (önceden hardcoded if/else, fallback yoktu). Test sonucu: Samsun GES (0.45kW capacity) → 22.46 kWh/ay (13 gün veri), source=`hourly_actual`. HES için `no_data` dönüyor (climatology'de hydro hourly_typical_profile henüz yok, S3'te). Bug #3 (`capacity_mw=275W` tek panel) ayrı bir task — sonra ele alınacak.

> **2026-05-19 S2+ Hillshade Layer Eklendi:** Kullanıcı 3D Terrain testinde "kabartma var ama yüksekliği anlamıyorum, renkler birbirine yapışık" dedi. Çözüm: MapLibre native **hillshade** layer eklendi (3D Arazi açıkken otomatik) — DEM tabanlı gölge/highlight ile dağların kabartma algısı dramatic artar. Default 55% exaggeration, KKB öğle güneşi açısı (335°). Layers panel'de yeni **Gölge Yoğunluğu** slider (0-150%, deep-orange renk) — Yükseklik Abartısı slider'ının altında. Choropleth fill üstüne, sınır çizgisi altına yerleşir (renk veriyle birleşir). Frontend `srrpSetHillshadeIntensity` + Dart bridge + VM state + Layers slider tek pakette. `flutter analyze` 0 issue.

> **2026-05-19 Solar Choropleth Renk Skalası Ters Çevrildi:** Kullanıcı raporu — gece saatinde "Anlık" modda Türkiye'nin batısı koyu kırmızı, doğusu sarı/turuncu görünüyordu. Diagnostic: gerçek peak değerleri tam tersi (Konya/Antalya 1000+ W/m² batıda, Rize/Trabzon 350 W/m² doğuda). **Sorun veri değil, renk skalası sezgi karşıtıydı**: eski palette 0=lacivert, 50=soluk sarı, 800=koyu bordo → "yüksek değer = koyu" tersine sezgi. **Yeni progresyon: gece koyu lacivert → şafak bordo → öğle parlak sarı** (inferno-like). 4 dosyada güncellendi: `web/index.html` `_choroplethBuildStops`, `map_view_maplibre_native.dart` solar ramp, `map_layer_mixin.dart` solar ramp, `map_screen.dart` legend, `map_overlays.dart` legend. Plus eski 48h pencere değişikliği rollback (24h yeterli, sorun renk skalasıydı). Detay: [[ChoroplethScales]] (güncellenmiş).

> **2026-05-17 S2 ✅ TAMAM — 3D Terrain + DEM'den Kurtulma:** 6 madde bitti. ① `srrpSetTerrain` AWS Terrarium CDN'e geçti (terrarium PNG, global yüksek-resolution, ücretsiz). ② `srrpSetTerrainExaggeration(double)` parametrik; MapViewModel.setTerrainExaggeration + Layers panel slider (1×–3×, 0.1 adım, anlık update). ③ `geo_service._get_terrain_data` Open-Meteo Elevation API → 5-nokta batch (ana + N/S/E/W komşu) → elevation + slope hesabı. Redis cache 7 gün TTL. ④ **785 MB DEM .tif silindi** (`backend/data/dem/`), `.gitignore`'a eklendi. ⑤ Pin uygunluk analizinde gerçek elevation/slope notları: Yusufeli 917m/33.3°→"orta-dik yamaç maliyet artar"; Konya 1027m/3.5°→eğim notu yok (düz). ⑥ `_analyze_solar/_wind/_hydro` notları güncellendi ("DEM bekleniyor" → "Open-Meteo gerçek değer"). Detay: [[BACKEND-PLAN-2026-05-17]] S2.

> **2026-05-17 S1 Backend ✅ TAMAM — Climatology + Pin Generation:** Backend tarafı tamamlandı. 9/10 adım bitti (S1.8+S1.9 frontend UI test sonrası): ① Migration 015 (climatology tablosu + pins.installation_date), ② Climatology SQLAlchemy model, ③ `climatology_service.py` (Türkçe ASCII fold + il-geneli toplama, mevcut "Balıkesir"/"Balikesir" varyasyonu çözüldü), ④ Pilot 8 il kalibre formül (Çanakkale wind 62, Konya solar 56 doğru sıralama), ⑤ **81 il × 2 kaynak = 162 row** climatology tablosunda kayıtlı (Top wind: İstanbul/Tekirdağ/Edirne/Kırklareli/Çanakkale — Trakya+Marmara dominant ✅; Top solar: Karaman/Van/Niğde/Burdur/Mersin — İç Anadolu+Akdeniz ✅), ⑥ `/analysis/provinces` ve `/analysis/province/{name}` ve `/analysis/choropleth/{metric}` climatology'den okuyor — **signature aynı**, frontend dokunulmadı, Raporlar ekranı 81 il'i doğru gösteriyor, ⑦ `GET /pins/{id}/generation` endpoint (period: today/week/month/year/total/range, saatlik veri varsa direkt, eski tarihler için climatology hourly_typical_profile interpolation), ⑩ APScheduler 6 ayda bir auto-refresh (Ocak+Temmuz 1, 03:00 UTC). **Bonus pin fix:** AddPinDialog'a otomatik analyze çağrısı eklendi — pin eklendikten sonra "Güncelle" basmadan analiz hazır. Detay: [[BACKEND-PLAN-2026-05-17]] S1.

> **2026-05-17 Gemini SDK Migration (teknik borç kapandı):** `google-generativeai 0.8.6` → `google-genai 2.4.0`. Eski paket deprecated, yeni paket aktif. Değişiklikler: `genai.configure()` → `genai.Client(api_key=...)`, `genai.GenerativeModel` → `client.chats.create(model=, config=, history=)`, `genai.protos.*` → `google.genai.types.*` (Tool, FunctionDeclaration, Schema, Type aynı API). `chatbot_service.py` ve `chatbot_tools.py` tamamen rewrite (lazy import + 6 tool declaration). Test: `python -c "from app.services import chatbot_service" → SDK available: True; 6 function declaration yüklendi`. INBOX'tan eski "chatbot part.function_call fix" maddesi de kapandı (yeni SDK'da defensive `_safe_response_text` helper'ı korunuyor).

> **2026-05-17 Backend Sprint Açıldı — `BACKEND-PLAN-2026-05-17.md`:** Pin sprinti bittikten sonra backend mimarisi için kapsamlı plan oluşturuldu. **Önemli mimari karar:** Skor sürekli recompute edilmiyor; statik **climatology** (10+ yıl × 6 ayda bir) + dinamik **pin generation history** (saatlik veri + interpolation, kullanıcı pin install_date'inden bugüne). Manisa örneği: bölge karakteri statik kalır, son ay az rüzgar diye listeden düşmez. `province_analysis` deprecated, `climatology` tablosu yeni. 7 sprint planlandı: S1 climatology+pin generation, S2 3D terrain+DEM kurtuluş, S3 OSM→PostGIS+pin validation, S4 Docker production, S5 multi-criteria skor motoru, S6 finansal, S7 AWS EC2 deploy. 8 karar finalize. Detay: [[BACKEND-PLAN-2026-05-17]].

> **2026-05-17 Sprint A+1 — Sprint Final Polish (pin yapısı kararlı):**
> ① **Ekipman düzenleme**: `PUT /equipments/{id}` + `EditEquipmentDialog` (name + nominal güç + tip-spesifik specs) + EquipmentSelector dropdown'a "KENDİM" rozeti + seçili user-owned ekipman için "Bu modeli düzenle/sil" satırı.
> ② **Cache invalidate bug**: `MapViewModel.loadEquipments(forceRefresh:true)` 5 dakika cache mantığına takılıyordu → düzeltildi. PinDialogViewModel artık MapViewModel'i listen eder, ekipman ekleme/güncelleme sonrası dropdown anında rebuild olur.
> ③ **PostgreSQL sequence drift**: `equipments_id_seq` 1'den başlıyordu ama tabloda 10 satır vardı → ilk POST UniqueViolation veriyordu. Migration `014_fix_equipments_id_sequence.py` ile `setval` yapıldı.
> ④ **Dropdown bubble fix**: Flutter web platform-view bug'ı — dropdown overlay Material global Overlay'a yerleşir, MapLibre canvas tıklamayı yutardı (pin konumu değişirdi). EquipmentSelector + ThemedDropdown items'ı `PointerInterceptor` ile sarıldı.
> ⑤ **notifyListeners override → explicit sync**: PinFlowController.notifyListeners override edilmişti, her notify'da setClickGuard JS bridge çağırıyordu (anchor recompute her pan/zoom'da → JS init race riski + gereksiz performance yükü). Kaldırıldı; her mode-değişen public method'da explicit `_syncMapClickState()` + `try/catch` ile JS yüklenmeden silent geç.
> ⑥ **Pinler arası geçiş bug fix**: JS `srrpQueryClick` clickGuard aktifken queryClick'i tamamen iptal ediyordu → pin pop-up açıkken başka pine tıklayınca geçemezdik. JS early-exit kaldırıldı; Dart tarafı (`_onMapClick`) zaten `type=='pin'` ise guard'a rağmen geçirir.
> **Pin sprint mimarisi tamamlanmış sayılır.** Sırada Faz 5 MOBİL veya başka feature.

> **2026-05-17 Sprint A — Backend migration + Ekipman Kaydet + 3 Davranış Fix:**
> Backend tarafı: alembic 013_pin_advanced_params_and_user_equipments → `pins` tablosuna 6 yeni alan (`panel_tilt`, `panel_azimuth`, `panel_power_w`, `hub_height`, `rotor_diameter`, `rated_power_kw`); `equipments.owner_id` (nullable, NULL=sistem, dolu=user). CRUD `get_equipments(user_id=)` system+user filter; yeni `create_user_equipment`, `delete_user_equipment`. Router `equipments`: `POST /` (kullanıcı kendi ekipmanı), `DELETE /{id}` (sadece kendi'si). Pin CRUD'a dokunulmadı — `pin.model_dump()` zaten yeni alanları geçirir. Frontend: Equipment modeline `ownerId`, EquipmentService `createEquipment`/`deleteEquipment`. MapViewModel.addPin/updatePin + ResourceService 6 yeni parametre. AdvancedSettingsPanel'a "Panel Tipini Kaydet" / "Türbin Tipini Kaydet" butonu (GES/RES) — mini dialog ile ekipman adı, backend POST, loadEquipments(forceRefresh:true).
> Davranış fix'leri: ① **setChoroplethMode auto-open ilçe modu mantığı kaldırıldı** (kullanıcı kararı: "ilçe modu sadece bizzat açtığımda çalışmalı"). Tematik standalone render edilir, ilçe modu manuel kontrolde. ② **Form içi tip değişiminde `PinFlowController.changeType` sync**: AddPinDialog ve PinDetailsDialog tip selectorları artık `_changeTypeSynced` helper'ı ile hem `PinDialogViewModel` hem `PinFlowController` çağırır — RES→GES geçişinde tematik harita güncellenir, HES seçiminde tematik kapanır + su kaynakları açılır. ③ **Graph coloring opacity tematik aktifken %20** (JS `_srrpSyncGraphColoringOpacity`): kullanıcı manuel ilçe modu açıkken tematik tıklarsa, rengarenk graph coloring şeffaflaşır ve choropleth okunabilir. Tematik kapanınca %100'e döner. Detay: [[AdvancedSettings]].
> ⚠️ Backend deploy adımı: `cd backend && alembic upgrade head` (013_pin_advanced_params migration).

> **2026-05-17 Sprint B+1 — 5 Bug Fix:** ① HES pin flow kapanınca **su kaynakları layer'ı açık kalıyordu** → PinFlowController._activateSuitabilityLayers'a `toggleHydroLayer` eklendi (HES'te otomatik aç, RES/GES'te otomatik kapat, pin flow close'da geri kapat). ② Tematik kapanınca ilçe modu davranışı düzeltildi: yeni `_districtModeAutoOpenedByThematic` flag — tematik açılırken ilçe modu zaten açıksa kullanıcı manuel açmıştır (flag=false), kapalıysa otomatik açılır (flag=true); tematik kapanırken sadece flag=true ise ilçe modu kapanır. ③ AI butonu FAB'dan **MapControlButton (50px)** boyutuna çekildi, sağ-üst Santral Kur+Katmanlar Column'unun 3. elemanı oldu (artık right offset hesabı yok). LayersPanel top:90→218 (3 buton + gap'lere göre). ④ PinFlowOverlay Stack içinde **harita+wind particles'tan hemen sonra** taşındı (eski en sondaydı) → UI butonları (sağ üst, sol alt zoom, layers panel, bottom sheet, chatbot panel) hep pop-up'ın üstünde kalır. ⑤ Pin flow aktifken **ilçe seçimi engellenir**: yeni `MapViewMapLibre.setPinPlacementActive(bool)` static API, PinFlowController.notifyListeners override ile sync — placing/typeSelection/addForm modlarında queryClick atlanır, tıklama doğrudan pin pozisyonuna gider; detail/editForm'da setClickGuard true (pinler arası geçiş için pin tıklamasına izin). Native/stub'a no-op API eklendi.

> **2026-05-17 Sprint B — Pin Gelişmiş Ayarlar (UI shell, backend Sprint A bekliyor):** Kullanıcı testi sonrası 7 madde geldi. Hızlı düzeltmeler bitti (1-6): ① pin detail no-analysis dalındaki **çift koordinat** Location Card'ı kaldırıldı (PinPanelShell header zaten il/ilçe+koord gösteriyor). ② layers_panel 'İletim Hatları' butonu kaldırıldı (VM toggle'ı geriye uyum için duruyor). ③ PinDetailsDialog edit form'a **Senaryo dropdown** eklendi (add ile simetri; pin halihazırda senaryodaysa default seçili). ④ PinFlowController'a **mod auto-close** eklendi — enterPlacing/selectType/openPinDetail/changeType → yasaklı bölgeler + tipe uygun tematik (GES→solar, RES→wind, HES→tematik yok) otomatik açılır; close()'da geri kapanır. ⑤ MapViewModel.setChoroplethMode override → ChoroplethMode.none'a geçişte ilçe modu da kapanır. Sonra ⑥ büyük: Gelişmiş Ayarlar refactor — yeni `AdvancedSettingsPanel` widget (AddPinDialog + PinDetailsDialog ortak), tip-aware expandable: GES (panel alanı/eğim/azimuth/güç), RES (kule yüksekliği/rotor çapı/nominal güç), HES (debi/düşü/havza — ana formdan taşındı). HES tipinde Equipment Selector gizlendi (kullanıcı kararı: HES'te ekipman seçimi yok). **Sprint A (backend migration)** kullanıcı onayı sonrası: pins tablosuna 6 yeni alan, equipments tablosuna owner_id, POST /equipments endpoint, EquipmentSelector'a "Yeni Ekipman Ekle" stub bağlama. Detay: [[AdvancedSettings]], [[PinFlowController]].

> **2026-05-09 Strategic Reset v2 — Manuel `_AnchoredBubble`:** Reset v1'de pop-up `just_the_tooltip` ile sarılmıştı; kullanıcı testinde **pop-up sol-üst köşeye düşüyor + tıklayınca kayboluyordu**. Kök neden: `just_the_tooltip` `Overlay.of(context)` global overlay'a route ediyor → Stack > Positioned(1x1) anchor pattern'ına saygı göstermiyor + tap-outside modal dismiss tetikleniyor. `isModal:false` yetmedi. **Çözüm:** Paket bırakıldı, `pin_flow_overlay.dart` içine **manuel `_AnchoredBubble` + `_TailPainter`** yazıldı: `Positioned(left/top/bottom)` hesaplı yerleşim, spaceAbove/spaceBelow flip, edge clamp, custom 3-nokta tail. `PinFlowController` state machine değişmedi (clean). Bkz: [[JustTheTooltipPattern]] (geriye bakış + yeni pattern dökümantasyonu — başlık tarihsel).


> **2026-05-08 Test Turu — Yeni Sprint Açıldı:** Pin akışı V2 bottom-card refactor + Pinlerim/Senaryolar segmented bottom sheet teslimat **yanlış yorumlanmış**. Kullanıcı doğru akışı netleştirdi: **V3 inline popover (tıklanan noktanın üstünde 3-tip mini menü) → V2 floating zengin form (pin yanına yapışık)** + sol Kütüphane panel (Senaryolar | Pinlerim segmented header, "Yeni Kaynak Ekle" butonu altta). Detay: [[PinAddFlow]], [[LibrarySidePanel]], [[AdvancedSettings]]. Sprint 1 planı aşağıda.

> **2026-04-23 Sprint Progress:** Faz 1–3 tamamlandı + 2026-04-23 düzeltme turu: 3D Türbin/Arazi YAKINDA rozetiyle disable, Önerilen Bölgeler side-panel'i `/analysis/provinces`'e migrate edildi (doğru dosya: `recommendations/recommendations_side_panel.dart`), Zaman Simülasyonu default tarih aralığı DB max tarihine clamp ediliyor (2026-04 "bugün" → veri sonu 2024/2025 uyuşmazlığı çözüldü), mobil backend URL artık Ayarlar → Veri Kaynağı'ndan override edilebiliyor (`BackendConfig` + SharedPreferences; varsayılan güncel PC IP `192.168.1.15`). `flutter analyze` temiz.

# 📥 INBOX — İşlenmemiş Sorunlar & Notlar

Buraya aklına gelen her şeyi hızlıca at. Tam cümle gerekmez, yarı not yeterli. Claude oturum başında buraya bakar, çözer, işaretler.

## Nasıl Kullanılır

1. **Sorunu at:** Yeni satıra `- [ ] sorun açıklaması` ekle. Mobilden ekran görüntüsü, konsol log'u yapıştırırsan daha iyi.
2. **Tarih başlığı kullan:** O günün sorunlarını `## 2026-04-DD` altına topla — eskiler aşağıda kalsın.
3. **Önceliklendir (opsiyonel):** `[!]` aciliyet, `[?]` belirsiz tekrar üretim, `[*]` sadece not.
4. **Çözülünce:** Claude `[x]` işaretler ve `→ [[issues/YYYY-MM-DD-slug]]` link ekler.

## Örnek Format

```markdown
## 2026-04-18
- [ ] Bulut katmanı açılıyor ama görünmüyor, konsol temiz
- [ ] [!] Android'de ilçe modu → harita beyazlıyor
- [ ] [?] Bazen senaryo butonu çalışmıyor, tekrar üretemiyorum
- [*] İleride: legend renkleri dark mode'da zor okunuyor
```

Çözülmüş örnek:
```markdown
- [x] Bulut katmanı görünmüyor → [[issues/2026-04-18-bulut-katmani-gorunmuyor]]
```

---

## 2026-05-08 — Test Bulguları + Sprint Planı

### 🔴 P0 — Pin Akışı Yeniden (Sprint 1)

Kullanıcı 2026-05-08 testinde mevcut "ortada bottom card" yapısının yanlış olduğunu açıkladı. Doğru akış (HTML prototip ile uyumlu):

1. **"Pin Ekle" → placing mode** (haritada cursor crosshair).
2. **Harita tıkla → V3 inline popover** tıklanan noktanın *üstünde*:
   - `📍 Yusufeli / Artvin   40.82°,41.53°`
   - 3 büyük dokunulabilir kart: ☀ Güneş · 💨 Rüzgar · 💧 HES
   - "ESC ile kapat" hint
3. **Tip seç → V2 floating form** (pin'e yapışık, harita yanda görünür):
   - Header: tip ikonu + "Yeni Kaynak" + **il/ilçe** + koordinatlar (koordinat altta küçük, il/ilçe baskın)
   - **Sol sütun:** Kaynak adı (text), Senaryo (dropdown), tip-spesifik field (panel alanı / türbin sayısı / boş)
   - **Sağ sütun:** Mevsimsel ortalama sıcaklık, ışınım, rüzgar (info chip)
   - **Alt:** Yıllık üretim tahmini + bu ayın geçen yıl üretimi (karşılaştırma)
   - Type selector (GES/RES/HES segmented — form içinde değiştirilebilir)
   - **Gelişmiş Ayarlar** butonu → expandable sub-form (bkz. [[AdvancedSettings]])
4. **Mobile bottom sheet kademeli** (peek 30% → expand 70%), dragable.
5. **Arka plan gradyan:** üst = tip rengi (turuncu/mavi/yeşil), alt = uygulama teması (dark/light).
6. **Etkileşim:** Form dışına tıkla / harita drag → harita pan/zoom; **form içine tıkla → harita pasif**.

Detay: [[PinAddFlow]].

- [ ] **V3 inline popover** widget'ı (yeni `pin_type_popover_inline.dart`) — placing mode + map tap'te tıklanan noktada konumlanır.
- [ ] **V2 zengin floating form** refactor (`add_pin_dialog.dart` → `pin_add_panel.dart`): header'da il/ilçe, sağ info chip'ler, alt yıllık tahmin, gradyan arka plan.
- [ ] Reverse geocoding (zaten var: `/geo/city?lat=&lon=`) form header'a entegre.
- [ ] **Gelişmiş Ayarlar** sub-form (bkz. [[AdvancedSettings]]): pusula widget (RES), HES havuz/debi/düşü/türbin tipi, GES panel açı/azimuth.
- [ ] Mobile bottom sheet `DraggableScrollableSheet`'e geçir (kademeli peek/expand).
- [ ] Mevcut "ortada bottom card" wrapper'ı kaldır.

### 🔴 P0 — Sol Kütüphane Panel (Sprint 1)

Kullanıcı 2026-05-08 testinde Pinlerim/Senaryolar bottom-sheet segmented yerine **sol kayar panel** istediğini belirtti (HTML "Kütüphane" prototipi).

- [ ] **`ScenarioSidePanel` genişlet** → "Senaryolar | Pinlerim" segmented header. Pinlerim sekmesi kaynak tipine göre **gruplu** liste (Güneş 8 / Rüzgar 2 / HES 2 başlıklı bölümler).
- [ ] Aktif senaryo highlight (Türkiye 2030 Yenilenebilir gibi).
- [ ] Senaryo kart formatı: pin sayısı + total MW + toplam maliyet.
- [ ] Alt: "+ Yeni Kaynak Ekle" butonu (Santral Kur popover'ı tetikler).
- [ ] **Bottom sheet'teki `PinsScenariosTabPanel` kaldırılır** (2026-05-08'de eklenmişti). Bottom sheet sadece kompakt özet + refresh + report tuşu.
- [ ] Cross-sheet navigation kalır (pin detay → Kütüphane'de Senaryolar sekmesi).

Detay: [[LibrarySidePanel]].

### 🔴 P0 — Suitability RES Genişletme

Kullanıcı: "Rüzgar uygunluğu için mevzuat şartları yerleşim, otoyol, sanayi, su uzaklığı dahil — şu an çoğu yer yeşil çıkıyor."

- [ ] Backend `_analyze_wind` aktive et: yerleşim 1.5km (OSM `residential`), otoyol/highway 500m, sanayi 1km, orman içi yasak.
- [ ] OSM landuse import script genişlet: `forest`, `residential`, `retail`, `commercial`, `motorway` ekle.
- [ ] Frontend: tip seçildikten sonra tip-aware "kurulamaz alanlar" overlay (RES için yerleşim + sanayi + orman çevresi yarı saydam pembe).

### 🟠 P1 — Telefon (Native) Kritik Buglar

- [ ] **İl modu native'de bölge renklendirmesi davranıyor** — her il farklı renk yerine bölge bazında. `_syncBorders` veya `_showProvinceOverlay` mantığı province-distinct color filter yapmıyor; bölge color callback'i fallback ediyor.
- [ ] **Zaman simülasyonu native'de renk/veri değişmiyor** — animation tick ilerliyor ama choropleth source güncellenmiyor. `applyAnimationFrameToChoropleth` native tarafı incelenmeli.
- [ ] **Native yasaklı/su MVT toggle gözükmüyor** — bilinen paket sınırı (Flutter MapLibre 0.2.2 `source-layer` desteklemiyor). Aşama 4 polish; şimdilik native'de "Yakında" rozeti.
- [ ] **Rüzgar partikül davranış farkı (web ↔ native)** — native custom Dart math vs web JS plugin, parametre uyumsuzluğu olabilir. Test görseli alındıktan sonra debug.

### 🟠 P1 — Chatbot `part.function_call` Hatası

Telefon Gemini Flash testte: `Sohbet asistanı hatası: could not convert 'part.function_call' to text.`

- [ ] **Hızlı fix:** `chatbot_service.py` response parse'ında `if hasattr(part, 'function_call')` branch (function call'ı string'e çevirme dene).
- [ ] **Doğru fix:** `google-generativeai` → `google-genai` SDK migrasyonu (P3 borç, FutureWarning'lerle birlikte temizle).

### 🟡 P2 — HES Backend Potansiyel Modeli (Sprint 4'e ertelendi)

- [ ] Türkiye su kaynakları + debi + havza verisi (DSI / EİE) araştırma + import. HES için debi/düşü/havuz değerleri kullanıcı manuel girmek zorunda kalmasın.

### 🟡 P2 — Marker Stilleri (Sprint 4)

- [ ] **4-segment toggle** Layers panel'de: Operasyon (V3 ring) · Trend (V5 sparkline) · 3D extrude · Sade (nokta).

### 🔵 P3 — Yasaklı Sebep Gösterimi (opsiyonel)

Kullanıcı: "Hepsi kırmızı kalsın daha iyi olabilir, sebep gösterimi emeğe değer mi bilmiyorum." → şimdilik **yapma**, "Yakında" notu bile yok. Kullanıcı geri dönerse Sprint 4+.

---

## 2026-04-18

### ✅ Çözüldü

- [x] Bulut katmanı açılıyor ama görünmüyor, konsol temiz hata yok → [[issues/2026-04-18-bulut-katmani-gorunmuyor]]

---

### 🔴 P0 — Seçim Modları Davranış Düzeltmesi

- [x] **İl modu: `city → district` drill-down + İlçe seçim vurgusu** → [[issues/2026-04-18-il-modu-drill-down]]
  - Web: `_jsSetupDistrictMode(vm.selectedProvinceName)` + hit/color filter ayrımı (cross-province için)
  - Web: yeni `srrpHighlightDistrict(prov, dist)` + ilçe change tracking
  - Native: yeni `_showDistrictHighlight` method + _syncBorders bağlantısı + click handler
  - Diagnostic log eklendi (2-step bug'ı için)
  - `flutter analyze` temiz.
- [x] **İl modu cross-province click: seçili il dışı tıklama = yeni il (ilçe değil)** → [[issues/2026-04-18-il-modu-cross-province-click]]
  - Kullanıcı testi: "Türkiye'nin tüm ilçelerine erişimim var" hissiyatı → yanlış.
  - Çözüm: Web'de hit=color=seçili-il + yeni `srrp-sel-hit-prov-fallback` katmanı (seçili il hariç) → dışarı tıklama `_handleProvinceClickJs`'e düşer.
- [x] **"Bölge açılıyor" bug'ı — `_handleSelectionClick` initial mode yoksayıyordu** → [[issues/2026-04-18-handle-selection-click-initial-mode]]
  - Log kanıtı: İl moduna girince ile tıklama → `selectRegion("Karadeniz")` çağrılıyordu (yanlış).
  - Kök sebep: Dart tarafında `_onMapClick` → `_jsQueryClick` → `_handleSelectionClick` paralel yolu, sadece `selectionLevel` bakıyordu `initial` yoksayılıyordu.
  - Çözüm: `_handleSelectionClick` initial-mode aware rewrite. İl modunda region'a **hiç dokunmaz**.
  - `flutter analyze` temiz.
  - ✅ **Kullanıcı testi onayı (2026-04-19):** "İl artık doğru çalışıyor" — İl modu tıklama → prov=<il> lvl=district, region dokunulmuyor, cross-province fallback doğru.

- [x] **Cross-region / Cross-province tek tıkla geçiş** → [[issues/2026-04-19-cross-region-province-click]]
  - Kullanıcı spec: Her seviyede üst seviye navigasyonu aktif. "Ege seçiliyken Karadeniz'i tıklarsam o bölgeye geçerim", "İl seçtikten sonra bir tıklamayla başka ile geçebilirim".
  - Web: `srrpSetupProvinceMode` hitFilter null yapıldı (tüm iller clickable), colorFilter sadece seçili bölgeye. Click handler 2 parametreli (name, REGION). `srrpQueryClick` fallback layer'ı da query'e ekledi. Dart `_handleProvinceClickJs(name, region)` ve `_handleSelectionClick` district branch region-aware.
  - Native: `_selectGeoAtPoint` Bölge modu branch'ı, province/district lvl'da farklı bölgenin iline tıklama = `selectRegion + selectProvince` tek adımda.
  - `flutter analyze` temiz. ⏳ Kullanıcı web test etmeli.

### 🔴 P0 — Rüzgar Partikülleri Z-Index

- [x] **Partiküller sadece harita üzerinde çizilmeli** → [[issues/2026-04-19-wind-particles-z-index]]
  - 1. tur: `z-index:9999` → `1` — yetmedi (kullanıcı test ekran görüntüsü: çizgiler hâlâ Katmanlar panelinin üstünde).
  - 2. tur: `z-index` tamamen kaldırıldı (auto). Platform view slot stacking context açmadığı için `z-index:1` bile root'a yayılıyordu.
  - ⏳ Kullanıcı web'de tekrar test etmeli (hot-restart `R`).

### 🟠 P1 — Veri Doğruluğu (en ciddi bug'lar)

- [x] **Işınım doğu-batı asimetrisi + legend uyuşmazlığı** → [[issues/2026-04-22-district-choropleth-east-west]]
  - Kök sebep 1: `/district-choropleth mode=latest` tek `global_max_ts` kullanıyordu → doğu ilçeleri (20° enlem + fetch dalgası) düşüyordu.
  - Kök sebep 2: `map_screen.dart` solar legend 0–400 + lacivert-siz; map paleti 0–800 + lacivert start.
  - Çözüm: per-district latest timestamp subquery (`weather.py`) + legend paletini 0–800 + `#1A1A2E` start'la hizala (`map_screen.dart:452`).
  - ⏳ Kullanıcı web test: tam Türkiye renklensin, legend ↔ harita renk uyumu.
- [ ] **Isı (temperature) choropleth kontrolü** — aynı endpoint'i kullandığı için doğu-batı fix ısıyı da düzeltmiş olmalı, ama skala (`-15→45°C`) ayrıca doğrulanmalı. Faz 2 migrasyonuyla `/analysis/choropleth/*` altına taşınacak.
- [ ] **Raporlar → Harita: değerler ~100 (hesaplama hatası).** Neredeyse her il için değer 100 gözüküyor. İl Analizi sekmesiyle **tutarsız**. Muhtemelen normalizasyon bug'ı.

### 🟠 P1 — Bulut Modu (Parça 1 devamı)

- [ ] **Telefonda Bulut Modu çalışmıyor.** Mobile native adapter'a port lazım (şu an sadece web).
- [ ] **Bulut açıkken yakınlaşınca "Zoom Level Not Supported" yazısı görünüyor** → gizlenmeli. (MapLibre built-in mesajı; `maxzoom:8` aşılınca çıkıyor.)

### 🟡 P2 — Feature Geliştirmeleri (kapsamlı)

- [ ] **Bulut görsel geliştirme:**
  - Yağmur bulutu vs. normal bulut ayrımı (şu an tek katman)
  - Ölçek gösterimi (legend) — kullanıcı gerçek zamanlı mı anlayamıyor
- [x] **Zaman Simülasyonu çalışmıyor** — Kök sebep: kullanıcı "bugün" 2026-04-23, varsayılan aralık `now-30d → now`; DB'de veri 2024/2025'te bitiyor. `fetchAnimationData` boş dönüp "veri bulunamadı" hatası veriyordu. Çözüm: `_fetchAnimationRange()` DB daily_max/hourly_max'i okuyup default end date'i clamp ediyor + start'ı end-30d'ye çekiyor (sadece user henüz manuel değiştirmediyse). `map_viewmodel.dart:1696-1740`.
- [ ] **Katmanlar → Önerilen Bölgeler: "henüz veri yok" uyarısı** — backend bitmemiş olabilir, endpoint kontrolü gerek.
- [ ] **Raporlar → Harita sekmesi:**
  - Rüzgar / Sıcaklık / Işınım layer toggle yok (ana haritada var, raporlarda yok)
  - Sağdaki il listesine tıklayınca harita o ile zoom yapmıyor
- [ ] **Önerilen Bölgeler ↔ Raporlar/Harita entegrasyonu:**
  - Ana harita üzerinde önerilen bölgeleri göster
  - Raporlar/Harita'da da göster — kullanıcı bölge seçimi gibi seçebilsin

### 🟣 P3 — Global Projeksiyon (Parça 4, büyük feature)

- [ ] **Globe mode kuralları** (web + mobil için aynı):
  - **KAPALI iken:** kullanıcı TR dışına çıkamaz (maxBounds aktif, zoom limiti aktif)
  - **AÇIK iken:** sınırlamalar kalkar, dünya gezilebilir
  - **Tekrar kapatılınca:** TR koordinatlarına dön, sınırlar & zoom limitleri geri aktif
- [ ] **TR dışı pin davranışı:**
  - Geo motoru / uygunluk analizi sistemleri çalışmaz
  - Sadece o koordinatın hava/ışınım verileri çekilir, sonuç gösterilir, konu kapanır
  - DB'de kaydı tutulur
  - Sol üst bilgi kutusunda uyarı: _"SRRP Türkiye dışındaki konumlar için uygunluk analizi yapmaz"_

### 🔴 P0 — 2026-04-23 (2. tur) — Zaman Simülasyonu 500 + İl Sayımı + Hidro Kriter

- [x] **Zaman Simülasyonu web + mobil HATA** — Kök sebep: `weather.py:/animation` endpoint'i `WeatherData.city_name` kullanıyordu ama `WeatherData` modelinde sadece `province_name` var (city_name yok). Her çağrı `AttributeError` ile 500 dönüyordu. Mobil "veri yüklenirken hata", web "sunucuya bağlanılamadı" mesajları hep aynı 500'ün iki farklı client fallback'iydi. Fix: `WeatherData.city_name → WeatherData.province_name` (hem query hem map), `row.province_name` + district IS NULL/Merkez filtresi. curl testi: `/weather/animation?start=2024-01-01&end=2024-01-07&metric=wind&interval=daily` → 200 OK, 7 frame, 17KB. `weather_service.dart.fetchAnimationData` 60sn timeout + ML error mesajları (timeout / socket / 500 / backend detail) ayrıldı. **Backend restart gerek.**
- [x] **"İller 79/79" → "X/81"** — `province_drill_tab.dart` payda sabit 81'e alındı. 2 ilde son 168 saatte hourly kayıt eksik → pay 79 (normal). Payda 81 sabit → eksik veri gözle görünür.
- [x] **Hidro skor kriteri kullanıcıya anlaşılmıyor** — `recommendations_side_panel.dart` `_CategoryGroup`'a `criteria` parametresi eklendi, başlığın altında tek satır italik açıklama: Rüzgar=v³ / Güneş=400 W/m² cap / Hidro=%70 yağış (5 mm/gün cap) + %30 sıcaklık (12 °C tepe, ±20 °C). "Gerçek HES havza verisi geliyor" notu.

### 🔴 P0 — 2026-04-23 Düzeltme Turu

- [x] **3D Türbin + 3D Arazi "Yakında" disable.** `layers_panel.dart` `_threeDEffectsEnabled = false` sabitiyle her iki toggle YAKINDA rozetiyle devre dışı. Bulut pattern'inin aynısı.
- [x] **Önerilen Bölgeler "Veri Yükle" tuşu hâlâ çalışmıyordu.** Asıl UI entrasyonu `recommendations_panel.dart` değil, `recommendations/recommendations_side_panel.dart` idi (backend log `/recommendations` çağrıldığı için fark edildi). Side-panel baştan yazıldı: `_HorizonBar` (1A/3A/6A/Yıl), `_CategoryGroup` (rüzgar/güneş/hidro top-N), il tıklaması `Navigator.pushNamed('/reports', arguments: {'province': name})`. `MapViewModel.toggleRecommendationsPanel()` panel açılınca hem `loadAnalysisTop()` hem eski `loadRecommendations()` tetikliyor (geri uyum).
- [x] **Telefon backend'e bağlanamıyor.** Kök sebep: `api_client.dart` Android için hardcode `192.168.1.7:8000`, PC'nin güncel LAN IP'si `192.168.1.15`. Çözüm: `core/config/backend_config.dart` yeni modül (SharedPreferences persistence); `BaseService.baseUrl` `BackendConfig.instance.mobileUrl` okuyor; `main.dart` startup'ta `BackendConfig.init()` çağırıyor; Ayarlar → Veri Kaynağı altında `_BackendUrlTile` (URL girişi + Kaydet / Varsayılan butonu, "ÖZEL" rozeti). Varsayılan `defaultMobileBackendUrl = 'http://192.168.1.15:8000'` olarak güncellendi.

<!-- YENİ SORUN EKLE ↓ -->

---

## 🎓 2026-04-19 — Hocam Feedback (Perşembe 23 Nisan'a Kadar Bitmeli)

**Takvim:** 19 → 23 Nisan 2026 (net 4 gün + Perşembe buffer).
**Kota:** Claude Pro haftalık token %43 dolu — disiplinli çalış, gereksiz tur yok.
**Parity:** Her özellik hem web hem mobil. [[PlatformConsistency]] kuralı.
**Plan:** [[PLAN-2026-04-19-to-23]]

### 🔑 Ana Tema — "Verileri Doğru Kullanmıyoruz"

Tüm veri-ilgili item'ların kök sebebi tek: **10+ yıllık hava verisi işlenmemiş, her istek canlı hesaplıyor, sonuçlar tutarsız.** Çözüm → Backend:
1. **Saatlik scheduler** (günde 24 Open-Meteo çekimi) — kullanıcı en başında söylemişti, unutulmuş.
2. **`province_analysis` tablosu** — 10+ yıllık veriyi işle, il×tip skorları kaydet.
3. **Tek kaynak:** Raporlar, İl Analizi, Önerilen Bölgeler, Choropleth hepsi bu tablodan beslenir.

Hocam kendi söyledi: *"Manisanın rüzgarlı olduğu sistem kendi başına bulmalı ve kaydetmeli, tekrardan aramamalı."*

### 🔴 P0 — Faz 1: Backend Veri Altyapısı (tüm demo buna bağlı)

Kullanıcı netleştirdi: _"Saat başı güncelleme demiştim sana en başında da, şimdi de hatırlatıyorum. Günde 24 kere veri çekmiş olacağız."_ + _"Manisanın rüzgarlı olduğu sistem kendi başına bulmalı ve kaydetmeli, tekrardan aramamalı."_

**2026-04-19 — Skor Netleştirmesi (diğer sohbet başlamadan önce):**
- 4 pencere: **30 / 90 / 180 / 365 gün** (`score_1m`, `score_3m`, `score_6m`, `score_yearly`). `score_3m` sonradan eklendi — Önerilen Bölgeler "1-6 ay" spec'i için.
- Wind: **cube-law default** (P ∝ v³); Solar üst sınır: **400 W/m²** (500 yüksekti); Hydro: precipitation + temperature_2m proxy, HES havza verisi TODO.
- `avg_temperature` ham metriği de yaz (modelde kolon var).

- [ ] **Saatlik veri scheduler (APScheduler).** Backend'de her saat başı Open-Meteo'dan 81 il için hourly çekim. Günde 24 snapshot. Son çekim timestamp'i DB'de.
- [ ] **`province_analysis` tablosu.** 10+ yıllık geçmiş + saatlik güncel veriyi işleyip il × tip (rüzgar/güneş/hidro) skorlarını DB'de tut. Raporlar, İl Analizi, Önerilen Bölgeler, Choropleth **tek kaynaktan** beslensin.
- [ ] **"228 dk önce güncellendi" metni düzelt.** Saatlik scheduler bitince mock sıfırlansın — gerçek `last_scheduler_run` timestamp'i göster.
- [ ] **Isı & Işınım choropleth bozuk** — Rüzgar doğru çalışıyor. Scheduler + scale fix sonrası iki metrik de doğru dönmeli.
- [ ] **Raporlar ↔ İl Analizi ↔ Harita tutarlılığı** — Haritada "her şey 100 puan", İl Analizi'nde "hepsi 40-60 puan". Aynı tablodan besleme → aynı skorlar.

### 🔴 P0 — Bulut Örüntüsü: DISABLE + "Yakında" işareti

- [x] **Bulut katmanı toggle'ını disable et + "Yakında" rozeti.** `layers_panel.dart` içinde `_cloudLayerEnabled = false` sabitiyle disabled + badge 'YAKINDA'. Hot-restart gerektirmeyen derleme-sabiti; gelecekte tek satır `true`'ya çevrilerek geri açılacak.
  - İlgili eski item'lar (şu an dondur): telefonda çalışmıyor, "Zoom Level Not Supported", yağmur/normal ayrımı, legend.

### 🟠 P1 — Faz 2: Raporlar Redesign + Harita Entegrasyonu

- [ ] **Raporlar sekmesini "Önerilenler" kartlı yapısına çevir.** Aynı UI dili, tutarlı UX. _(Parite için bekleme; mevcut 6-tab yapısı korundu)_
- [ ] **Raporlar → Harita alt-sekmesi:** Rüzgar / Sıcaklık / Işınım layer toggle + sağdaki il listesinden tıklayınca haritanın o ile zoom olması.
- [ ] **"Raporlar'a geç / çık" state kayboluyor** — Sekmeden çıkıp dönünce seçili il/metrik state'i sıfırlanıyor. ViewModel'de state korunmalı.
- [x] **Önerilen Bölgeler = Raporlar'ın kısa vadeli top-N çıkarımı.** Panel `AnalysisService.fetchProvinces(wind/solar/hydro, horizon)` ile `province_analysis` tablosundan besleniyor. Horizon seçici (1A/3A/6A/Yıl) + 3 kaynak × top-N liste. "ML yakında" boş state kaldırıldı; Weibull kategorileri opsiyonel alt-blok olarak kaldı.
- [ ] **Önerilen Bölgeler'i ana harita ve Raporlar/Harita'da göster.** Kullanıcı bölge seçer gibi seçebilsin.

### 🟠 P1 — Faz 3: Senaryo Yönetimi Düzeltmeleri

Kullanıcı eksikleri netleştirdi:

- [ ] **Senaryo haritada göster/gizle toggle** — Senaryo oluşturulduktan sonra haritada görünsün, istendiğinde gizlenebilsin.
- [x] **Senaryo → "Rapor'a Git" butonu** — Mevcut `scenario_detail_dialog.dart` ve `scenario_mini_report_panel.dart` butonları doğrulandı; `main.dart` route'u `scenarioId` argümanını unpack ediyor, `ReportScreen(initialScenarioId:...)` senaryoyu `selectOnly(id)` ile otomatik seçip Senaryo tab'ına açılıyor.
- [x] **"Tam Ekran" butonu düzeltme** — `scenario_mini_report_panel.dart` "Tam Rapor" ve "Geniş Ekran" butonları `/reports`'a yönlendiriyor; `onReport` card callback'i `scenarioId` argümanıyla push yapıyor ve artık doğru sekmeye iniyor.

### 🟠 P1 — Faz 3: İl Analizi Ekranı Düzeltme

- [x] **İl Analizi skorları Faz 1'deki `province_analysis` tablosundan çekilecek.** `province_drill_tab.dart` içine "Kaynak × Zaman Pencere Skorları" bloğu eklendi: 3 satır (rüzgar/güneş/hidro) × 4 sütun (1A/3A/6A/Yıl). `ReportViewModel.setSelectedProvinceIndex` seçim değişince `analysis.fetchProvinceDetail(name)` çağırıyor.

### 🟡 P2 — Faz 3: Ayarlar Ekranı

Kullanıcı: _"İçeriği sen tespit et."_ Claude tespiti (mevcut state'ten çıkarılmış):

- [x] **Yeni Ayarlar ekranı** — `settings_dialog.dart` placeholder'dan genişletildi: Görünüm (Dark/Light toggle), Veri Kaynağı (sağlayıcı + scheduler + tablo listesi), Hakkında (sürüm kopyala, kapsam). Dil/birim/bildirim yakında notu bırakıldı.

### 🟡 P2 — Genel Bakış (Kaldır)

Kullanıcı: _"Genel Bakış'ı unut, sil."_

- [ ] **Genel Bakış ekranını / sekmesini kaldır.** Navigasyondan link + widget'ları temizle. Kullanılan helper'lar referanssız kalıyorsa sil.

### 🔵 Kesişen Gereklilikler

- [ ] **Platform parity (mobil = web)** — Her özellik her iki platformda **aynı** davranmalı. Her fazın sonunda iki tarafta da smoke test. [[PlatformConsistency]] kuralı.
- [ ] **Tanıtım videosu — AI seslendirmeli.** Feature donduktan sonra senaryo + ekran kaydı + AI voiceover (ElevenLabs / TTS). Detay [[PLAN-2026-04-19-to-23]] Faz 5.

### 🟣 Perşembe Sonrası (P3 — bu sprint dışı)

- Global Projeksiyon (Parça 4) — yukarıdaki P3 bölümüyle birlikte.
- Bulut düzeltme (disable'ı geri aç → mobil port + legend + yağmur ayrımı).
- Zaman Simülasyonu bug araştırması.

---

---

## 🚀 2026-04-25 → 2026-05-07 Final Sprint Progress

**Mod:** Çoklu oturum + token disiplini. Vault güncellemesi her commit'te değil, sprint sonu toplu.

### ✅ Tamamlanan

- **Aşama 1.A1 — 8 değerli zaman penceresi enum** (current/week/month/threeMonth/sixMonth/yearly/season) backend `time_window.py` + frontend `WeatherTimeModeProvider`. Tematik panel dropdown + season chip'leri.
- **Aşama 1.A2 — Heatmap → Choropleth** tek görsel dil. `setLayer()` choropleth bridge, `fetchHeatmapDataForLayer` no-op, `_interpolatedData` boş. `/reports/interpolated-map` endpoint silindi. Ölü kod (~620 satır + 1 dosya) temizlendi.
- **Aşama 1.A2.c — Animation backend payload districts formatı** `frame.vals = {"İl|İlçe": val}` (eski `pts` array'i `format=points` legacy). GADM-driven payload — DB → GADM kanonik isim çevirme (`Adiyaman→Adıyaman`, `Afyon→Afyonkarahisar`, vb). Animation 911→921 ilçe (TURKEY_CITIES ile %99.5 örtüşme).
- **Aşama 1.B (yeniden) — Modern Time Simulation** — JS bridge silindi, pure Dart Timer, `TimeSimulationController` (~270 satır) + `TimeSimulationPanel` (~330 satır). `map_viewmodel.dart`'tan ~466 satır legacy animation kodu silindi.
- **Aşama 2 INBOX temizliği:** Genel Bakış sekmesi (1618 satır `overview_tab.dart`), 5 tab kaldı. Senaryo göster/gizle göz ikonu (`_hiddenScenarioIds` + filter pipeline). Reports → Harita flyTo. Reports state persist (`_initialized` flag).
- **Aşama 3.A — Finansal modül** (önceki turlardan): LCOE, payback, NPV, IRR, CO₂ avoidance servisi + UI sekmesi.
- **Aşama 3.B — 3D efektler aktif** (`_threeDEffectsEnabled = true`): Hillshade + setTerrain + sky + 3D Buildings + 3D pin stili. Web tam, Native sadece görsel hillshade (paket sınırı).
- **Aşama 3.C — AI Chatbot (Google Gemini)**: `chatbot_service.py` + `chatbot_tools.py` (6 tool: get_province_score, get_recommendations, compare_provinces, get_scenario_financials, get_weather_summary, compute_what_if). Frontend `ChatService` + `ChatViewModel` + `ChatbotPanel` (sağ alt mor FAB). Model: `gemini-flash-latest` (eski `2.0-flash-exp` ve `1.5-flash` deprecated). `.env`'den okunur (`load_dotenv` main.py'a eklendi).
- **Aşama 3.D — ML Projeksiyon**: Seasonal naive + lineer trend forecaster (`ml_projection_service.py`). `/analysis/projection` endpoint + frontend `MlProjectionCard` (fl_chart line + 95% CI band). `ml_projection_placeholder.dart` silindi.
- **Aşama B — PostGIS-driven GeoService refactor**: 8 shapefile (~500MB RAM) → DB sorguları (~50MB). Startup 30-60sn → ~5sn. `GEO_ANALYSIS_ENABLED=true` default. `_get_location_info` keyword-arg fix (lat/lon swap bug'ı).
- **Aşama B-4 — `restricted_zones` backfill**: OSM Overpass API → 6.237 polygon (military 5.4K + protected 591 + nature 112 + national_park 107). Savepoint pattern ile per-row commit.
- **Suitability mantık revizyonu**: Kullanıcı specs'ine göre — GES neredeyse her yer (su+yasaklı hariç), RES açık alan + uzak yerleşim, HES sadece akarsu kıyısı (riverbank ≤500m ideal, ≤1km uygun). `_water_type_at()` + feature_type-aware reasons.
- **Frontend MapLibre defensive guards** (`getSource undefined` race condition) — `index.html` `_setupSelectionLayers` + `srrpQueryClick` style-load guard + try/catch.
- **Aşama I — Vector layer toggle**: 3 yeni katman (💧 Su Kaynakları, 🚫 Yasaklı Bölgeler, ⚡ İletim Hatları) — backend MVT zaten hazır, frontend Layers Panel'a eklendi. Web JS shim (`srrpToggleHydroLayer/Restricted/EnergyCorridor` + tek `VectorSource` lazy + feature_type renk skeması). Native stub (Flutter MapLibre 0.2.2 layer-source-layer desteklemiyor — Aşama 4 polish).
- **Big city AVG fix**: Daily animation'da Adana/Ankara/İstanbul/İzmir/Bursa/... 10 ilin "Merkez" ilçesi olmadığı için filter düşürüyordu. Artık il × tarih `AVG()` + GADM yayma (721 → 921 ilçe).
- **Database migration fix**: PostgreSQL'de tabloların hiç oluşturulmamış olduğu tespit edildi (host PG'si vs Docker PG çakışması — backend `localhost:5432` host PG'sine bağlanıyordu). 18 tablo `create_all` ile zorlandı.
- **APScheduler startup garantili**: `start_scheduler` `trigger="date", run_date=now(UTC)` ile immediate fetch garanti edildi. `_hourly_fetch_and_recompute` aşama bazlı log eklendi.
- **`run_backend.bat` GEO_ANALYSIS_ENABLED=true** + Redis container ayağa (`docker-compose up -d redis`).

### 🔧 Mimari Kararlar

- **DEM (raster) → DB'ye yüklemek YANLIŞ** — `data/dem/*.tif` 8 dosya kalsın; rio-tiler ile dinamik tile server (Aşama 4 polish). Vector → PostGIS, Raster → dosya bazlı.
- **GADM = otoriter kaynak**: `turkey_districts_osm.geojson` 975 polygon. Backend tüm choropleth/animation key'leri GADM kanonik adıyla üretir (`gadm_lookup.py` resolve_province + resolve_district + Türkçe normalize).
- **GridService (eski IDW heatmap)** kullanılıyor 3 yerde (optimization, pins listesi, reports yıllık) — silmek riskli, ilçe bazlı recompute Aşama 4 polish.
- **2 venv karışıklığı**: `.venv` (kök, `run_backend.bat` kullanıyor) + `backend/venv` (eski). Paketler kök `.venv`'e yüklenmeli. Cleanup Aşama 4'te.

---

## 🎯 Sıradaki — Aşama J→M (2026-05-07 itibarıyla)

### J — "Santral Kur" UX Yenileme (Claude Design HTML hazır)
- Dosya: `SRRP Pin Design.html` (proje kökünde) — Claude Design tarafından üretilen responsive prototip (desktop+tablet+mobile)
- **Karar verilen tasarım kararları:**
  - Sol panel = Senaryolar (default tab) + Pinlerim (segmented tab) — birleşik
  - Marker mode toggle: Operasyon (V3, CF halka) ↔ Trend (V5, sparkline) + cluster
  - Add flow: V3 inline popover → "Detaylı düzenle" → V4 side panel/bottom sheet (progressive disclosure)
  - Pin detay: desktop dashboard / mobile bottom sheet (responsive)
  - "Pin Ekle" → "Santral Kur" rename + 3 tip seçim adımı (RES/GES/HES)
- **Tip seçilince**: harita o tipe özel **suitability overlay**'leri otomatik açılır (yeni `setMvtLayers` macro setter zaten hazır)
- Pin click → mevcut edit dialog (zaten çalışıyor, dokunma)
- Karşılaştırma şu an Reports'ta — harita üzerinde animasyonlu split-marker ileride

### I-Plus — Suitability/Buildable Areas Overlay (Claude Design soracak)
- **Tek tip aktif** mod (santral seçilince harita yeniden boyanır — 3 tip aynı anda değil)
- **3 katmanlı görselleştirme**:
  - Alt: il/ilçe verim choropleth (`province_analysis` mevcut)
  - Orta: uygun yeşil polygon (yeni `suitability_*` tabloları — Aşama L'de pre-compute)
  - Üst: yasaklı kırmızı yarı saydam (`restricted_zones` mevcut)
- **Zoom-aware detay**: z<8 il, z=8-11 ilçe, z>=11 polygon (MVT min_zoom field zaten kullanılıyor)
- **Lejant + eşik slider** (real-time MapLibre filter expression)
- **Kurulamaz alana tıklayınca**: tooltip + hızlı panel açılır ama "Kaydet" disabled + uyarı banner (sebep `/geo/check-suitability` `reasons[]`'den gelir)
- **HES özel**:
  - Akarsu line (mevcut `riverbank` filter)
  - Akış yönü partikülleri (rüzgar partikül sistemini akarsuya uygula)
  - Top-N HES aday markerleri (Aşama L pre-compute, debi×düşü skoru)

### L — Optimal Nokta Pre-compute Scheduler
- Backend haftalık tarama → her tip için top-N koordinat
- Yeni tablo: `optimal_sites (id, resource_type, lat, lon, score, reasons, computed_at)`
- HES için: `riverbank` polygon centroid + DEM gradient (DEM yok = proxy)
- RES için: yerleşim 1.5km uzaklık (OSM bina import sonrası tam) + `province_analysis.score_wind_yearly`
- GES için: yasaklı bölge dışı + `province_analysis.score_solar_yearly`
- Endpoint: `GET /optimization/top-sites?resource=hes&limit=50`

### M — Akarsu/Rüzgar Vektör Görselleştirme
- HES için akarsu yön okları (rüzgar partikülünden ödünç)
- Zoom-aware görünürlük: uzakta en güçlüler, yaklaştıkça hepsi
- Hover/tap → debi/hız değer popup

### Aşama 4 Polish
- DEM raster tile server (rio-tiler + FastAPI) — yerel yüksek-çözünürlük 3D arazi
- OSM bina/landuse import (RES yerleşim 1.5km, GES orman yasak — gerçek veri)
- google-generativeai → google-genai SDK migration (deprecated)
- GridService ilçe-bazlı recompute (broadcast yerine gerçek hesap)
- Native MVT desteği (Flutter MapLibre paketi sınırı — custom platform channel)
- Globe mode (TR-dışı pin davranışı — INBOX P3)
- Bulut polish (mobil port, legend, yağmur)
- Tanıtım videosu güncelleme

### AWS Deployment
- **Şu an deploy etme** — feature dalgası bitsin (~3 hafta).
- Hedef: **Tier A** (Free Tier EC2 t3.micro + RDS PostGIS db.t3.micro 12 ay ücretsiz). Mevcut `docker-compose.yml` aynen taşınır.
- Alternatif: Azure for Students ($100 kredi, kart yok — `.edu.tr` mail) veya Render.com (en hızlı).
- Demo'dan 5-7 gün öncesi production push.

---

## 🐛 Açık Bug'lar / Eksik Veriler

- **Animation hâlâ ~50 ilçe siyah**: 2014 büyükşehir reformu sonrası yeni ilçeler (Sakarya/Adapazarı, Diyarbakır/Sur, Şanlıurfa/Eyyübiye, Tekirdağ/Süleymanpaşa, Eskişehir/Odunpazarı, Erzurum/Yakutiye, Manisa/Şehzadeler, Ordu/Altınordu, Van/Tuşba, Hakkâri/Derecik, vb.) — Open-Meteo collector eski TURKEY_CITIES listesi ile çekiyor. **Çözüm:** `location_inventory` tablosu + GADM-driven collector refactor (Aşama 4). Veya spot fix: 50 yeni ilçeye lat/lon manuel ekle.
- **Hatay yanlış il bug'ı**: Open-Meteo bbox query Antakya/Defne/Arsuz/Belen/Payas/Reyhanlı için Adana'ya kayıyor. Veri kalitesi sorunu — collector lat/lon → reverse geocoding ile düzeltilebilir.
- **GADM gürültü**: Muğla|Kalymnos (Yunan adası), Ağrı|Panos (yok), Muğla|Kara Ada — borders.py REGION='Diğer' filter genişletilebilir.
- **Native MVT desteği yok** — Flutter MapLibre 0.2.2 layer-level `source-layer` desteklemiyor. UI toggle çalışır ama mobil tarafta layer görünmez.
- **`google-generativeai` deprecated warning** — `google-genai` SDK'ya migration gerek (Aşama 4).

---

## ⚙️ Token / Workflow Notları

- Bu sohbet 200+ tool call, çok uzun → token tüketimi yüksek. Yeni oturum başlangıcı: `/clear` + bu nottan oku.
- `wind_vectors.py` system-reminder her mesajda re-injected (~3K token boşa) — sebebi belirsiz, Claude Code internal cache mekanizması.
- Vault güncellemesi commit-bazlı değil sprint-bazlı (`MEMORY.md` kuralı gevşetildi).

---

## Arşiv

2 haftadan eski çözülmüş sorunlar `issues/` altında kalır — buradan silinir.
Aktif takip gereken item'lar burada kalır.

## Bağlantılar

- [[INDEX]] — vault ana haritası
- [[issues/_template]] — yeni issue şablonu
- [[PLAN-2026-04-19-to-23]] — eski sprint planı (referans)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/map/widgets/map_view_maplibre.dart';
import 'package:frontend/features/map/widgets/panels/map_overlays.dart';
import 'package:frontend/features/map/widgets/panels/recommendations/recommendations_side_panel.dart';
import 'package:frontend/features/map/widgets/panels/province_info_card.dart'; // ignore: unused_import — geriye uyum için tutuluyor (eski paneller refer edebilir)
import 'package:frontend/features/map/widgets/panels/unified_selection_card.dart';
import 'package:frontend/features/map/widgets/panels/map_bottom_sheet.dart';
import 'package:frontend/features/map/widgets/map_widgets.dart';
import 'package:frontend/features/scenarios/widgets/scenario_side_panel.dart';
import 'package:frontend/features/reports/report_screen.dart';
import 'package:frontend/features/scenarios/widgets/scenario_mini_report_panel.dart';
import 'package:frontend/features/map/widgets/panels/time_simulation_panel.dart';
import 'package:frontend/features/map/widgets/panels/ml_projection_panel.dart';
import 'package:frontend/features/map/animation/time_simulation_controller.dart';
import 'package:frontend/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:frontend/features/map/widgets/wind_particle_overlay.dart';
import 'package:frontend/features/chatbot/viewmodels/chat_viewmodel.dart';
import 'package:frontend/features/chatbot/widgets/chatbot_panel.dart';
import 'package:frontend/features/pins/controllers/pin_flow_controller.dart';
import 'package:frontend/features/pins/widgets/pin_flow_overlay.dart';
import 'package:frontend/features/landing/showcase_pins.dart';


/// 2026-06-01: Native rüzgar partikül overlay'i (CPU CustomPaint) Windy tarzı
/// GPU akışıyla yarışamadığı için native'de DEVRE DIŞI (web-only). Gelecekte
/// native GPU partikül (shader/platform channel) eklenirse `true` yapılır.
const bool _kNativeWindParticles = false;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _showLayersPanel = false;
  bool _showScenariosPanel = false;
  bool _showChatbotPanel = false;

  // Aşama 1.B (yeniden) — Zaman simülasyonu controller'ı bu screen'in
  // ömrüne bağlı; MapScreen kapanınca dispose edilir, choropleth restore olur.
  TimeSimulationController? _timeSimController;
  TimeSimulationController _ensureTimeSimController() {
    if (_timeSimController != null) return _timeSimController!;
    final api = Provider.of<ApiService>(context, listen: false);
    final mapVM = Provider.of<MapViewModel>(context, listen: false);
    _timeSimController = TimeSimulationController(
      api: api,
      applyToChoropleth: (metric, vals) =>
          mapVM.applyAnimationFrameToChoropleth(metric: metric, vals: vals),
      restoreChoropleth: mapVM.restoreChoroplethFromAnimation,
    );
    return _timeSimController!;
  }

  // 2026-05-09 Strategic Reset — Tek source of truth: PinFlowController.
  // Eski 8 state field + 8 helper metodu kaldırıldı. Tüm pin lifecycle
  // (idle → placing → typeSelection → addForm → detail → editForm) controller
  // tarafından yönetiliyor. Bkz: [[PinFlowAudit]], [[PinFlowController]].
  PinFlowController? _pinFlow;

  PinFlowController _ensurePinFlow() {
    if (_pinFlow != null) return _pinFlow!;
    final mapVM = Provider.of<MapViewModel>(context, listen: false);
    _pinFlow = PinFlowController(mapVM);
    return _pinFlow!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<MapViewModel>(context, listen: false).loadWeatherForTime(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      // Harita pan/zoom event'inde pin anchor'ı yenile.
      MapViewMapLibre.registerAnchorListener(_onMapMovedRecomputeAnchor);

      // 2026-06-04: MİSAFİR (Keşfet) salt-okunur keşif modu. Landing'den PUSH
      // ile gelinir (landing dispose OLMAZ → onun kapattığı etkileşim + Türkiye
      // sınırı JS global'inde kalır). Bu yüzden burada:
      //   • etkileşimi AÇ (pan/zoom yapılabilsin),
      //   • Türkiye sınırını koru (keşif Türkiye-kilitli, tutarlı),
      //   • vitrin pinlerini göster (fetchPins misafirde zaten erken döner →
      //     srrp-pins kaynağını ezmez, çakışma yok).
      final guest =
          Provider.of<AuthViewModel>(context, listen: false).isLoggedIn != true;
      if (guest) {
        MapViewMapLibre.setInteractive(true);
        MapViewMapLibre.setMaxBounds(24.0, 34.0, 46.0, 44.0);
        final isDark =
            Provider.of<ThemeViewModel>(context, listen: false).isDarkMode;
        MapViewMapLibre.setShowcasePins(buildShowcaseGeoJson(isDark: isDark));
      }
    });
  }

  @override
  void dispose() {
    MapViewMapLibre.registerAnchorListener(null);
    _pinFlow?.dispose();
    _timeSimController?.dispose();
    super.dispose();
  }

  void _onMapMovedRecomputeAnchor() {
    if (!mounted) return;
    _pinFlow?.recomputeAnchor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context);
    final isAuthenticated = authVM.isLoggedIn == true;
    // 2026-05-25 (G10): Login olur olmaz chatbot status'u arka planda yükle —
    // kullanıcı butona basmadan önce hazır olsun (status indicator için).
    if (isAuthenticated) {
      final chatVM = Provider.of<ChatViewModel>(context, listen: false);
      if (chatVM.status == null && chatVM.statusError == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          chatVM.initStatus();
        });
      }
    }
    // 2026-05-09 Strategic Reset: Pin lifecycle tek controller.
    final pinFlow = _ensurePinFlow();
    return ChangeNotifierProvider<PinFlowController>.value(
      value: pinFlow,
      child: ChangeNotifierProvider<TimeSimulationController>.value(
      value: _ensureTimeSimController(),
      child: Consumer2<MapViewModel, ScenarioViewModel>(
      builder: (context, mapViewModel, scenarioVM, child) {
        // Tema değişiminde harita stilini otomatik senkronize et
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) mapViewModel.syncBaseStyleWithTheme(theme.isDarkMode);
        });
        // Aşama 2: Senaryo göster/gizle — gizli senaryoların pin'lerini
        // MapViewModel filter'ına ilet (filteredPins bunu kullanır).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) mapViewModel.setHiddenScenarioPinIds(scenarioVM.hiddenPinIds);
        });
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // 1. MapLibre harita motoru
              MapViewMapLibre(
                onMapTap: (ml.Position p) => _handleMapTap(
                  mapViewModel,
                  LatLng(p.lat.toDouble(), p.lng.toDouble()),
                ),
                onPinTap: (Pin pin) => _showPinDialog(pin),
              ),

              // Rüzgar parçacık animasyonu — native CPU CustomPaint, Windy GPU
              // akışıyla yarışamıyor ("birkaç nokta") → 2026-06-01 native'de
              // DEVRE DIŞI (web-only; Canlı Rüzgar toggle'ı da 'WEB' rozetli).
              // `_kNativeWindParticles` ileride native GPU partikül gelince true.
              if (_kNativeWindParticles && !kIsWeb && mapViewModel.showWindParticles)
                Positioned.fill(
                  child: WindParticleOverlay(
                    vectors: mapViewModel.windVectors,
                    active: mapViewModel.showWindParticles,
                    quality: mapViewModel.windQuality,
                  ),
                ),

              // 2026-05-17 — Pin Flow pop-up overlay (harita ÜSTÜNDE,
              // UI butonların ALTINDA). Stack içinde haritadan hemen sonra
              // ki sağ üst butonlar / sol alt scale / katmanlar paneli /
              // bottom sheet hep pop-up'ın üstünde kalır.
              // Suitability layer aç/kapa controller içinde
              // (`_activateSuitabilityLayers`).
              PinFlowOverlay(controller: pinFlow),

              // Aşağıdaki tüm kontroller sadece giriş yapıldığında gösterilir
              if (isAuthenticated) ...[

              // 2. Overlay'ler (Dashboard, Açıklama, Lejandlar)
              // Dashboard — sol üst köşe
              Builder(builder: (ctx) {
                final isMobile = MediaQuery.of(ctx).size.width < 600;
                final pad = isMobile ? 10.0 : 20.0;
                final scale = isMobile ? 0.85 : 1.0;
                final dashboardBottom = isMobile ? 88.0 : 120.0; // tooltip top

                return Stack(
                  children: [
                    if (!mapViewModel.showGlobe)
                      Positioned(
                        top: pad,
                        left: pad,
                        child: PointerInterceptor(
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: MapDashboard(theme: theme),
                          ),
                        ),
                      ),
                    if (mapViewModel.showGlobe)
                      Positioned(
                        top: pad,
                        left: pad,
                        child: PointerInterceptor(
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: GlobeInfoCard(theme: theme),
                          ),
                        ),
                      ),
                    // Birleşik Seçim Kartı — dashboard'un altında, sol üst.
                    // Eski iki kart (_ChoroplethTooltip + ProvinceInfoCard) buraya
                    // taşındı. Tek state kaynağı, breadcrumb tıklanabilir, "Raporu
                    // Görüntüle" butonu altta. Bkz: unified_selection_card.dart.
                    if (mapViewModel.selectedRegionName != null ||
                        mapViewModel.selectedProvinceName != null ||
                        mapViewModel.selectedDistrictName != null ||
                        mapViewModel.choroplethTapDistrict != null)
                      Positioned(
                        top: dashboardBottom,
                        left: pad,
                        child: PointerInterceptor(
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: UnifiedSelectionCard(
                              theme: theme,
                              selectionLevel: mapViewModel.selectionLevel,
                              regionName: mapViewModel.selectedRegionName,
                              provinceName: mapViewModel.selectedProvinceName,
                              districtName: mapViewModel.selectedDistrictName,
                              provinceSummary: mapViewModel.selectedProvinceSummary,
                              districtSummary: mapViewModel.selectedDistrictSummary,
                              regionSummary: mapViewModel.selectedRegionSummary,
                              isLoadingDistrictSummaries: mapViewModel.isLoadingDistrictSummaries,
                              choroplethMode: mapViewModel.choroplethMode,
                              choroplethTapData: mapViewModel.choroplethTapData,
                              choroplethTapDistrictLabel: mapViewModel.choroplethTapDistrict,
                              onClose: () {
                                mapViewModel.clearAllSelection();
                                mapViewModel.clearChoroplethTap();
                              },
                              onSelectRegion: (region) {
                                mapViewModel.openRegionMode();
                                mapViewModel.selectRegion(region);
                              },
                              onSelectProvince: (province) {
                                mapViewModel.openProvincesMode();
                                mapViewModel.selectProvince(province);
                              },
                              onSelectDistrict: (province, district) {
                                mapViewModel.openDistrictsMode();
                                mapViewModel.selectDistrict(district, province: province);
                              },
                              onMetricTap: (mode) {
                                // 2026-05-08 Madde 3: chip tıkla → tematik harita
                                mapViewModel.setChoroplethMode(mode);
                              },
                              onViewReport: mapViewModel.selectedProvinceName != null
                                  ? () => Navigator.push(
                                        context,
                                        createReportRoute(
                                          initialProvince:
                                              mapViewModel.selectedProvinceName,
                                        ),
                                      )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }),
              // Layers Panel — sağ üst, sağ-üst Row'un altında.
              // 2026-05-17 — Butonlar yatay Row'a alındı (3 buton yan yana,
              // 50px each + 16px gap = 182 genişlik). Panel top:90 yeterli
              // (20 top + 50 button + 20 gap = 90).
              if (_showLayersPanel)
                Positioned(
                  top: 90,
                  right: 20,
                  child: PointerInterceptor(
                    child: LayersPanel(
                      theme: theme,
                      mapViewModel: mapViewModel,
                      onClearMapSelection: () =>
                          MapViewMapLibre.clearSelectionMode(),
                    ),
                  ),
                ),
              // Choropleth & Heatmap legends
              ..._buildLegends(mapViewModel, theme),

              // 3. Kayan Kontroller (Butonlar) — sağ üst yatay Row.
              // 2026-05-17 — Eski dikey Column kaldırıldı. Sol→sağ:
              // Pin Ekle · AI · Katmanlar (kullanıcı isteği). LayersPanel
              // açıldığında bu Row'un hemen altından başlar (top:90).
              // 2026-05-26 (M4): Mobile (<600) butonlar arası boşluk 16→8.
              Builder(builder: (btnCtx) {
                final isMobileBtns =
                    MediaQuery.of(btnCtx).size.width < 600;
                final btnGap = isMobileBtns ? 8.0 : 16.0;
                return Positioned(
                top: 20,
                right: 20,
                child: PointerInterceptor(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 2026-06-04: "Santral Kur" yalnız giriş yapana. Misafir
                      // (Keşfet) salt-okunur — pin kuramaz/düzenleyemez.
                      if (isAuthenticated)
                        AnimatedBuilder(
                          animation: pinFlow,
                          builder: (_, __) {
                            final placing = pinFlow.mode == PinFlowMode.placing;
                            return MapControlButton(
                              icon: Icons.add_location_alt_outlined,
                              tooltip: placing
                                  ? "Santral Kur — Haritada tıklayın"
                                  : "Santral Kur",
                              onTap: () {
                                if (placing) {
                                  pinFlow.cancelPlacing();
                                } else {
                                  pinFlow.enterPlacing();
                                }
                              },
                              color: placing
                                  ? Colors.greenAccent
                                  : Colors.blueAccent,
                              theme: theme,
                            );
                          },
                        ),
                      if (isAuthenticated) ...[
                        SizedBox(width: btnGap),
                        // 2026-05-25 (G10): AI buton + canlı status indicator
                        // (yeşil = aktif, turuncu = yükleniyor, kırmızı = kapalı).
                        Consumer<ChatViewModel>(
                          builder: (ctx, chatVM, _) {
                            final available = chatVM.isAvailable;
                            final statusKnown = chatVM.status != null;
                            final dotColor = !statusKnown
                                ? Colors.orangeAccent
                                : (available
                                    ? Colors.greenAccent
                                    : Colors.redAccent);
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                MapControlButton(
                                  icon: Icons.auto_awesome_rounded,
                                  tooltip: statusKnown
                                      ? (available
                                          ? "AI Asistanı (Hazır)"
                                          : "AI Asistanı (Kurulum gerekli)")
                                      : "AI Asistanı",
                                  onTap: () => setState(
                                      () => _showChatbotPanel = true),
                                  color: Colors.purpleAccent,
                                  theme: theme,
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.cardColor,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                      SizedBox(width: btnGap),
                      MapControlButton(
                        icon: Icons.layers_outlined,
                        tooltip: "Katmanlar",
                        onTap: () => setState(
                            () => _showLayersPanel = !_showLayersPanel),
                        color: _showLayersPanel
                            ? Colors.greenAccent
                            : theme.textColor,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              );
              }),
              // Zoom butonları — sol alt
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                bottom: mapViewModel.choroplethMode != ChoroplethMode.none ? 155 : 40,
                left: 20,
                child: PointerInterceptor(
                  child: Column(
                    children: [
                      _buildZoomButton(Icons.add, MapViewMapLibre.zoomIn, theme),
                      const SizedBox(height: 8),
                      _buildZoomButton(Icons.remove, MapViewMapLibre.zoomOut, theme),
                    ],
                  ),
                ),
              ),

              // 5. Eylem Göstergeleri (pin yerleştirme, bölge seçimi)
              if (mapViewModel.placingPinType != null)
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.22,
                  left: 0,
                  right: mapViewModel.isRecommendationsPanelOpen ? 380 : 0,
                  child: PointerInterceptor(
                    child: PlacementIndicator(
                      placingPinType: mapViewModel.placingPinType,
                      onCancel: mapViewModel.stopPlacingMarker,
                    ),
                  ),
                ),

              if (mapViewModel.isSelectingRegion)
                Positioned(
                  bottom: mapViewModel.placingPinType != null
                      ? MediaQuery.of(context).size.height * 0.22 + 100
                      : MediaQuery.of(context).size.height * 0.22,
                  left: 0,
                  right: mapViewModel.isRecommendationsPanelOpen ? 380 : 0,
                  child: PointerInterceptor(
                    child: RegionSelectionIndicator(
                      points: mapViewModel.selectionPoints,
                      onCancel: mapViewModel.clearRegionSelection,
                    ),
                  ),
                ),

              // 6. Öneri Paneli (sağdan kayar)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                top: 0,
                bottom: 0,
                right: mapViewModel.isRecommendationsPanelOpen ? 0 : -380,
                width: 380,
                child: PointerInterceptor(
                  child: RecommendationsSidePanel(
                    theme: theme,
                    mapViewModel: mapViewModel,
                    onCityNavigate: (lat, lon) =>
                        MapViewMapLibre.flyTo(lat, lon, zoom: 10.0),
                  ),
                ),
              ),

              // 6b. Zaman Simülasyonu Paneli (1.B yeniden — modern controller)
              if (context.watch<TimeSimulationController>().isOpen)
                Positioned(
                  bottom: 12,
                  left: 20,
                  right: mapViewModel.isRecommendationsPanelOpen ? 400 : 20,
                  child: PointerInterceptor(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TimeSimulationPanel(theme: theme),
                    ),
                  ),
                ),

              // 6b2. ML İklim Projeksiyon Paneli (M-B.2/3) — sağ-alt
              if (mapViewModel.mlProjectionPanelOpen)
                Positioned(
                  bottom: 12,
                  right: 20,
                  child: PointerInterceptor(
                    child: MlProjectionPanel(
                      theme: theme,
                      onClose: () =>
                          mapViewModel.setMlProjectionPanel(false),
                    ),
                  ),
                ),

              // 6c. (Eski ProvinceInfoCard kaldırıldı 2026-05-08 — yerine sol üst
              //      `UnifiedSelectionCard` (yukarıda dashboard'un altında).
              //      Tek kart, breadcrumb tıklanabilir, çakışma + state donması
              //      sorunları kökten çözüldü.)

              // 7. Senaryo Paneli (soldan kayar)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                top: 0,
                bottom: 0,
                left: _showScenariosPanel ? 0 : -330,
                width: 320,
                child: PointerInterceptor(
                  child: ScenarioSidePanel(
                    theme: theme,
                    onClose: () =>
                        setState(() => _showScenariosPanel = false),
                  ),
                ),
              ),

              // 8. Senaryo Mini Rapor Paneli
              if (scenarioVM.hasSelection)
                Positioned(
                  bottom: 180,
                  right: 20,
                  child: PointerInterceptor(
                    child: ScenarioMiniReportPanel(
                      theme: theme,
                      scenarioVM: scenarioVM,
                    ),
                  ),
                ),

              // 9. Alt Sheet — en sonda: diğer tüm widget'ların üstünde
              MapBottomSheet(
                onScenariosTap: () =>
                    setState(() => _showScenariosPanel = !_showScenariosPanel),
              ),

              // 10. AI Chatbot sliding panel — sağdan kayar (3.C).
              // 2026-05-17 — Eski FAB (sağ alt) kaldırıldı; AI butonu artık
              // sağ-üst Column'da (MapControlButton boyutunda). Panel açma
              // tetikleyici aynı setState.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                right: _showChatbotPanel ? 0 : -380,
                child: PointerInterceptor(
                  child: ChatbotPanel(
                    onClose: () => setState(() => _showChatbotPanel = false),
                  ),
                ),
              ),

              ], // if (isAuthenticated) sonu
              // Not: PinFlowOverlay yukarıda (harita üzeri, UI alt). Burada
              // duplicate yok.
            ],
          ),
        );
      },
    ),
    ),
    );
  }

  // 2026-05-09 Strategic Reset — Eski _buildPinFormOverlay/_buildPinDetailOverlay
  // kaldırıldı. Yerine tek `PinFlowOverlay` widget'ı (mode-aware controller).

  void _handleMapTap(MapViewModel viewModel, LatLng point) {
    if (viewModel.isSelectingRegion) {
      viewModel.recordSelectionPoint(point);
      return;
    }
    // 2026-05-09 Strategic Reset — pin lifecycle tek satırda controller'a.
    // Mode-aware davranır: placing → typeSelection, typeSelection/addForm →
    // pin konumunu taşır, detail/idle → ilgilenmez (caller başka şey yapsın).
    final flow = _pinFlow;
    if (flow != null && flow.onMapTap(point)) {
      return;
    }
  }

  /// 2026-05-09 Strategic Reset — Pin tıklamasında controller'a delege.
  /// Eski `_showPinDialog`/`_closePinDetail`/`_movePinFormTo`/
  /// `_openPinTypePopover`/`_onPinTypePopoverSelect`/`_closePinTypePopover`/
  /// `_buildPinTypePopoverInline` helper'ları kaldırıldı — hepsi
  /// `PinFlowController` içinde, `PinFlowOverlay` widget'ı tarafından render.
  void _showPinDialog(Pin pin) {
    _pinFlow?.openPinDetail(pin);
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap, ThemeViewModel theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1)),
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.textColor),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  List<Widget> _buildLegends(MapViewModel vm, ThemeViewModel theme) {
    final legends = <Widget>[];
    // Zaman simülasyonu açıksa legend'lar panelin üstüne çıksın
    final legendBottom =
        (_timeSimController?.isOpen ?? false) ? 240.0 : 40.0;

    // Heatmap legends (sağ alt)
    Widget? heatLegend;
    if (vm.currentLayer == MapLayerType.irradiance) {
      heatLegend = LegendWidget(
        theme: theme, title: 'Işınım Yoğunluğu', titleFontSize: 11,
        unit: 'kWh/m²/yıl',
        gradientColors: [Colors.black.withValues(alpha: 0.5), Colors.deepOrangeAccent, Colors.redAccent.shade700, Colors.orangeAccent, Colors.white],
        minLabel: '0', maxLabel: '2200',
        tickLabels: const ['0', '550', '1100', '1650', '2200'],
      );
    } else if (vm.currentLayer == MapLayerType.wind) {
      heatLegend = LegendWidget(
        theme: theme, title: 'Rüzgar Hızı', unit: 'm/s',
        gradientColors: [Colors.black.withValues(alpha: 0.5), Colors.blueAccent.shade700, Colors.cyanAccent, Colors.white],
        minLabel: '0', maxLabel: '15+',
        tickLabels: const ['0', '3', '6', '9', '12', '15+'],
      );
    } else if (vm.currentLayer == MapLayerType.temp) {
      heatLegend = LegendWidget(
        theme: theme, title: 'Sıcaklık', unit: '°C',
        gradientColors: [Colors.indigo, Colors.cyan, Colors.yellow, Colors.red.shade900],
        minLabel: '-10', maxLabel: '40+',
        tickLabels: const ['-10', '5', '20', '35', '40+'],
      );
    }
    if (heatLegend != null) {
      legends.add(Positioned(bottom: legendBottom, right: 20, child: PointerInterceptor(child: heatLegend)));
    }

    // Choropleth legends (sol alt)
    Widget? choroLegend;
    if (vm.choroplethMode == ChoroplethMode.solar) {
      // Palet: 0 W/m² (gece/lacivert) → 50 (soluk sarı) → 800 (bordo).
      // Sıralama index.html _choroplethBuildStops('solar') ve
      // map_view_maplibre_native.dart solar stop listesiyle BİREBİR aynı olmalı.
      choroLegend = LegendWidget(
        theme: theme, title: 'Güneş Işınımı (İlçe)', titleFontSize: 10, unit: 'W/m²', width: 210,
        // 2026-05-19 — Renk skalası TERS ÇEVRİLDİ (sezgi: gece=koyu, çok güneş=parlak).
        // index.html + map_view_maplibre_native.dart + map_layer_mixin.dart ile aynı.
        gradientColors: const [
          Color(0xFF1A1A2E), // 0 — gece / lacivert
          Color(0xFF4D0014), // 50 — çok düşük (şafak/akşam) koyu bordo
          Color(0xFFBD0026), // 150
          Color(0xFFE31A1C), // 250
          Color(0xFFFC4E2A), // 350
          Color(0xFFFD8D3C), // 450
          Color(0xFFFEB24C), // 550
          Color(0xFFFED976), // 650
          Color(0xFFFFEDA0), // 750
          Color(0xFFFFFFCC), // 800 — maksimum / parlak sarı
        ],
        minLabel: '0', maxLabel: '800',
        tickLabels: const ['0', '200', '400', '600', '800'],
      );
    } else if (vm.choroplethMode == ChoroplethMode.wind) {
      choroLegend = LegendWidget(
        theme: theme, title: 'Rüzgar Hızı (İlçe)', titleFontSize: 10, unit: 'm/s', width: 190,
        gradientColors: const [Color(0xFFF7FBFF), Color(0xFFDEEBF7), Color(0xFFC6DBEF), Color(0xFF9ECAE1), Color(0xFF6BAED6), Color(0xFF4292C6), Color(0xFF2171B5), Color(0xFF08519C), Color(0xFF083D7F), Color(0xFF08306B)],
        minLabel: '0', maxLabel: '12',
        tickLabels: const ['0', '2', '4', '6', '8', '10', '12'],
      );
    } else if (vm.choroplethMode == ChoroplethMode.temperature) {
      choroLegend = LegendWidget(
        theme: theme, title: 'Sıcaklık (İlçe)', titleFontSize: 10, unit: '°C', width: 210,
        gradientColors: const [Color(0xFF08306B), Color(0xFF2171B5), Color(0xFF6BAED6), Color(0xFFC6DBEF), Color(0xFFD9F0A3), Color(0xFF78C679), Color(0xFF31A354), Color(0xFF006837), Color(0xFF31A354), Color(0xFFFED976), Color(0xFFFEB24C), Color(0xFFFD8D3C), Color(0xFFE31A1C), Color(0xFFBD0026), Color(0xFF800026)],
        minLabel: '-15', maxLabel: '45',
        tickLabels: const ['-15', '0', '10', '20', '30', '40', '45'],
      );
    }
    if (choroLegend != null) {
      legends.add(Positioned(bottom: legendBottom, left: 12, child: PointerInterceptor(child: choroLegend)));
    }

    return legends;
  }

  // 2026-05-09 Strategic Reset — Eski helper'lar kaldırıldı:
  //   - _isInTurkey, _checkGeoSuitability, _closePinForm
  // Hepsi PinFlowController içinde veya ihtiyaç yok (geoCheck zaten
  // form içinde yapılıyor, controller close() preview pin'i temizliyor).
}



// ─── (Eski `_ChoroplethTooltip` widget'ı kaldırıldı 2026-05-08) ───────────
// Yerine `UnifiedSelectionCard` kullanılıyor. Choropleth tap → selection state
// merge → tek kart açılır (sol üst dashboard altı). Çift kart desenkronu kökten
// çözüldü. Bkz: widgets/panels/unified_selection_card.dart


// 2026-05-09 Strategic Reset — Eski `_PinTooltipHost` widget kaldırıldı.
// `PinFlowOverlay` (features/pins/widgets/pin_flow_overlay.dart) artık tek
// noktada controller-driven tooltip kabuğunu yönetir.

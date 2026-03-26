import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;

import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/map/widgets/map_view_maplibre.dart';
import 'package:frontend/features/map/widgets/panels/map_overlays.dart';
import 'package:frontend/features/map/widgets/panels/recommendations/recommendations_side_panel.dart';
import 'package:frontend/features/map/widgets/panels/province_info_card.dart';
import 'package:frontend/features/map/widgets/panels/map_bottom_sheet.dart';
import 'package:frontend/features/map/widgets/map_widgets.dart';
import 'package:frontend/features/scenarios/widgets/scenario_side_panel.dart';
import 'package:frontend/features/reports/report_screen.dart';
import 'package:frontend/features/scenarios/widgets/scenario_mini_report_panel.dart';
import 'package:frontend/features/map/widgets/panels/time_slider_panel.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _showLayersPanel = false;
  bool _showScenariosPanel = false;

  // Pin ekleme koruması: aynı anda birden fazla dialog açılmasını önler
  bool _isProcessingGeoCheck = false;

  // Pin modu debounce: "Pin Ekle" butonuna basınca harita click event'i
  // de tetikleniyor. 600ms içinde gelen map tap'i ignore et.
  DateTime? _pinModeActivatedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<MapViewModel>(context, listen: false).loadWeatherForTime(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    return Consumer2<MapViewModel, ScenarioViewModel>(
      builder: (context, mapViewModel, scenarioVM, child) {
        // Tema değişiminde harita stilini otomatik senkronize et
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) mapViewModel.syncBaseStyleWithTheme(theme.isDarkMode);
        });
        return Scaffold(
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

              // 2. Overlay'ler (Dashboard, Açıklama, Lejandlar)
              MapOverlays(
                theme: theme,
                mapViewModel: mapViewModel,
                layersPanel: _showLayersPanel
                    ? LayersPanel(
                        theme: theme,
                        mapViewModel: mapViewModel,
                      )
                    : null,
              ),

              // 3. Kayan Kontroller (Butonlar)
              MapControls(
                theme: theme,
                onAddPin: () {
                  mapViewModel.startPlacingMarker('Güneş Paneli');
                  _pinModeActivatedAt = DateTime.now();
                },
                onSelectRegion: () {
                  if (mapViewModel.isSelectingRegion) {
                    mapViewModel.clearRegionSelection();
                  } else {
                    mapViewModel.startSelectingRegion();
                  }
                },
                onToggleLayers: () =>
                    setState(() => _showLayersPanel = !_showLayersPanel),
                onZoomIn: MapViewMapLibre.zoomIn,
                onZoomOut: MapViewMapLibre.zoomOut,
                isSelectingRegion: mapViewModel.isSelectingRegion,
                isLayersPanelVisible: _showLayersPanel,
                onToggleRecommendations: () =>
                    mapViewModel.toggleRecommendationsPanel(),
                isRecommendationsPanelOpen:
                    mapViewModel.isRecommendationsPanelOpen,
                // İl Modu — tüm 81 ili doğrudan göster
                onOpenProvincesMode: () {
                  mapViewModel.openProvincesMode();
                  if (!mapViewModel.isProvinceModeActive) {
                    MapViewMapLibre.clearSelectionMode();
                  }
                },
                isProvincesModeActive: mapViewModel.isProvincesModeActive,
                // İlçe Modu — tüm Türkiye ilçelerini doğrudan göster
                onOpenDistrictsMode: () {
                  mapViewModel.openDistrictsMode();
                  if (!mapViewModel.isProvinceModeActive) {
                    MapViewMapLibre.clearSelectionMode();
                  }
                },
                isDistrictsModeActive: mapViewModel.isDistrictsModeActive,
                onToggleAnimation: () => mapViewModel.toggleAnimationMode(),
                isAnimationMode: mapViewModel.isAnimationMode,
                isGlobeMode: mapViewModel.showGlobe,
              ),

              // 3b. Bölge Filtre Şeridi — İl modu aktifken üstte kayar chip'ler
              if (mapViewModel.isProvincesModeActive)
                Positioned(
                  top: 72,
                  left: 0,
                  right: mapViewModel.isRecommendationsPanelOpen ? 380 : 0,
                  child: PointerInterceptor(
                    child: _RegionFilterChips(
                      mapViewModel: mapViewModel,
                      theme: theme,
                    ),
                  ),
                ),

              // 4. Alt Sheet
              MapBottomSheet(
                onScenariosTap: () =>
                    setState(() => _showScenariosPanel = !_showScenariosPanel),
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

              // 6b. Zaman Simülasyonu Paneli
              if (mapViewModel.isAnimationMode)
                Positioned(
                  bottom: 12,
                  left: 20,
                  right: mapViewModel.isRecommendationsPanelOpen ? 400 : 20,
                  child: PointerInterceptor(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TimeSliderPanel(
                        theme: theme,
                        mapViewModel: mapViewModel,
                      ),
                    ),
                  ),
                ),

              // 6c. Coğrafi Seçim Bilgi Kartı
              if (mapViewModel.isProvinceModeActive &&
                  (mapViewModel.selectedRegionName != null ||
                      mapViewModel.selectedProvinceName != null ||
                      mapViewModel.selectedDistrictName != null))
                Positioned(
                  bottom: 100,
                  left: 20,
                  child: PointerInterceptor(child: ProvinceInfoCard(
                    provinceName: mapViewModel.selectedProvinceName ?? '',
                    summary: mapViewModel.selectedProvinceSummary,
                    districtSummary: mapViewModel.selectedDistrictSummary,
                    allPins: mapViewModel.pins,
                    theme: theme,
                    selectionLevel: mapViewModel.selectionLevel,
                    regionName: mapViewModel.selectedRegionName,
                    districtName: mapViewModel.selectedDistrictName,
                    onClose: () => mapViewModel.clearAllSelection(),
                    onBack: (mapViewModel.selectedRegionName != null ||
                            mapViewModel.selectedProvinceName != null ||
                            mapViewModel.selectedDistrictName != null)
                        ? () {
                            if (mapViewModel.selectedDistrictName != null) {
                              mapViewModel.clearSelectedDistrict();
                            } else if (mapViewModel.selectedProvinceName !=
                                null) {
                              mapViewModel.clearSelectedProvince();
                            } else {
                              mapViewModel.clearRegionFilter();
                            }
                          }
                        : null,
                    onViewReport: mapViewModel.selectedProvinceName != null
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportScreen(
                                  initialProvince:
                                      mapViewModel.selectedProvinceName,
                                ),
                              ),
                            )
                        : null,
                  )),
                ),

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

              // 9. Collector Sağlık Rozeti — sol alt köşe
              Positioned(
                bottom: 12,
                left: 12,
                child: PointerInterceptor(child: const _CollectorStatusBadge()),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleMapTap(MapViewModel viewModel, LatLng point) {
    if (viewModel.isSelectingRegion) {
      viewModel.recordSelectionPoint(point);
      return;
    }

    if (viewModel.placingPinType != null) {
      if (_pinModeActivatedAt != null &&
          DateTime.now().difference(_pinModeActivatedAt!) <
              const Duration(milliseconds: 600)) {
        return;
      }
      _checkGeoSuitability(viewModel, point);
    }
  }

  /// Pin dialog'unu açar — açılmadan önce click guard aktifleştirilir,
  /// dialog kapanınca devre dışı bırakılır.
  Future<void> _showPinDialog(Pin pin) async {
    MapViewMapLibre.setClickGuard(true);
    try {
      await MapDialogs.showPinActionsDialog(context, pin);
    } finally {
      MapViewMapLibre.setClickGuard(false);
    }
  }

  Future<void> _checkGeoSuitability(
      MapViewModel viewModel, LatLng point) async {
    if (_isProcessingGeoCheck) return;
    _isProcessingGeoCheck = true;

    // Dialog açılınca click guard aktifleştir
    MapViewMapLibre.setClickGuard(true);

    final theme = Provider.of<ThemeViewModel>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text('Analiz ediliyor...',
                  style: TextStyle(color: theme.textColor)),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await viewModel.geoCheck(point);
      if (!mounted) return;
      Navigator.pop(context);

      if (result != null) {
        await showDialog(
          context: context,
          builder: (ctx) => AddPinDialog(
            point: point,
            initialPinType: viewModel.placingPinType ?? 'Güneş Paneli',
          ),
        );
        viewModel.stopPlacingMarker();
      }
    } catch (e) {
      debugPrint('Geo Check Exception: $e');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      _isProcessingGeoCheck = false;
      MapViewMapLibre.setClickGuard(false);
    }
  }
}


// ── Bölge Filtre Şeridi ───────────────────────────────────────────────────────

class _RegionFilterChips extends StatelessWidget {
  static const _regions = [
    'Marmara', 'Ege', 'Akdeniz', 'İç Anadolu',
    'Karadeniz', 'Doğu Anadolu', 'Güneydoğu Anadolu',
  ];

  final MapViewModel mapViewModel;
  final ThemeViewModel theme;

  const _RegionFilterChips({
    required this.mapViewModel,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final selectedRegion = mapViewModel.selectedRegionName;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 76, vertical: 6),
      child: Row(
        children: [
          if (selectedRegion != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chip(
                label: 'Tümü',
                icon: Icons.close_rounded,
                selected: false,
                onTap: () => mapViewModel.clearRegionFilter(),
                isReset: true,
              ),
            ),
          ..._regions.map((region) {
            final isSelected = selectedRegion == region;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chip(
                label: region,
                selected: isSelected,
                onTap: () => isSelected
                    ? mapViewModel.clearRegionFilter()
                    : mapViewModel.selectRegion(region),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
    bool isReset = false,
  }) {
    final bg = isReset
        ? Colors.tealAccent.withValues(alpha: 0.15)
        : selected
            ? Colors.tealAccent.withValues(alpha: 0.2)
            : theme.cardColor.withValues(alpha: 0.92);
    final border = isReset || selected
        ? Colors.tealAccent.withValues(alpha: 0.55)
        : theme.secondaryTextColor.withValues(alpha: 0.25);
    final labelColor =
        isReset || selected ? Colors.tealAccent : theme.textColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: labelColor),
              const SizedBox(width: 4),
            ] else if (selected) ...[
              Icon(Icons.check_rounded, size: 12, color: labelColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight:
                    selected || isReset ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Collector Sağlık Rozeti ───────────────────────────────────────────────────

class _CollectorStatusBadge extends StatefulWidget {
  const _CollectorStatusBadge();

  @override
  State<_CollectorStatusBadge> createState() => _CollectorStatusBadgeState();
}

class _CollectorStatusBadgeState extends State<_CollectorStatusBadge> {
  Map<String, dynamic>? _status;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.weather.fetchCollectorStatus();
      if (mounted) setState(() => _status = result);
    } catch (_) {
      if (mounted) setState(() => _status = {'healthy': false});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null) return const SizedBox.shrink();

    final healthy = s['healthy'] == true;
    final minutesAgo = s['minutes_ago'] as int?;
    final records = s['records_48h'] as int? ?? 0;

    final color = healthy ? Colors.greenAccent : Colors.orangeAccent;
    final label = minutesAgo == null
        ? 'Veri yok'
        : minutesAgo < 60
            ? '$minutesAgo dk önce'
            : '${(minutesAgo / 60).round()} sa önce';

    return GestureDetector(
      onTap: _fetch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Veri: $label  •  ${records}k',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

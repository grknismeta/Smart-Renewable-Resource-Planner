import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:maplibre/maplibre.dart' as ml;

import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/map/widgets/map_view.dart';
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


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final AnimatedMapController _animatedMapController;

  // Local state for UI toggles (could be in VM but acceptable here for UI-only state)
  bool _showLayersPanel = false;
  bool _showScenariosPanel = false;
  String _selectedBaseMap = 'dark';

  // USE_MAPLIBRE=true flag'i → başlangıçta MapLibre 3D aktif et
  static const bool _maplibreEnvFlag =
      bool.fromEnvironment('USE_MAPLIBRE', defaultValue: false);

  // Hover — ValueNotifier ile sadece MapOverlays rebuild oluyor,
  // MapView/FlutterMap rebuild OLMUYOR. Bu, "Cannot hit test a render box
  // that has never been laid out" crash'ini engeller.
  final ValueNotifier<LatLng?> _hoverNotifier = ValueNotifier<LatLng?>(null);

  // Pin ekleme koruması: aynı anda birden fazla dialog açılmasını önler
  bool _isProcessingGeoCheck = false;

  @override
  void initState() {
    super.initState();
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
      mapViewModel.loadWeatherForTime(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      // dart-define ile MapLibre başlatıldıysa VM'e yansıt
      if (kIsWeb && _maplibreEnvFlag) {
        mapViewModel.setMapMode(MapMode.maplibre3d);
      }
    });
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    _hoverNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    // Use Consumer to rebuild when MapViewModel changes
    return Consumer2<MapViewModel, ScenarioViewModel>(
      builder: (context, mapViewModel, scenarioVM, child) {
         return Scaffold(
           body: Row(
             children: [
               Expanded(
                 child: Stack(
                   children: [
                     // 1. Map Engine — VM.mapMode ile seçilir
                     if (mapViewModel.mapMode == MapMode.maplibre3d)
                       MapViewMapLibre(
                         onMapTap: (ml.Position p) => _handleMapTap(
                           mapViewModel,
                           LatLng(p.lat.toDouble(), p.lng.toDouble()),
                         ),
                         onPinTap: (Pin pin) =>
                             MapDialogs.showPinActionsDialog(context, pin),
                       )
                     else
                       MapView(
                         mapController: _animatedMapController.mapController,
                         selectedBaseMap: _selectedBaseMap,
                         onMapTap: (tapPosition, point) => _handleMapTap(mapViewModel, point),
                         onHover: (point) => _hoverNotifier.value = point,
                         onExitRange: () => _hoverNotifier.value = null,
                       ),

                     // 2. Overlays (Dashboard, Hover Info, Legends)
                     // ValueListenableBuilder ile sadece overlay rebuild oluyor,
                     // FlutterMap/MapView ETKİLENMİYOR.
                     ValueListenableBuilder<LatLng?>(
                       valueListenable: _hoverNotifier,
                       builder: (context, hoverPosition, _) {
                         return MapOverlays(
                           theme: theme,
                           mapViewModel: mapViewModel,
                           hoverPosition: hoverPosition,
                           layersPanel: _showLayersPanel
                              ? LayersPanel(
                                  theme: theme,
                                  mapViewModel: mapViewModel,
                                  selectedBaseMap: _selectedBaseMap,
                                  onBaseMapChanged: (val) => setState(() => _selectedBaseMap = val),
                                )
                              : null,
                         );
                       },
                     ),
                     
                     // 3. Floating Controls (Buttons)
                     MapControls(
                       theme: theme,
                       onAddPin: () => mapViewModel.startPlacingMarker('Güneş Paneli'),
                       onSelectRegion: () {
                          if (mapViewModel.isSelectingRegion) {
                            mapViewModel.clearRegionSelection();
                          } else {
                            mapViewModel.startSelectingRegion();
                          }
                       },
                       onToggleLayers: () => setState(() => _showLayersPanel = !_showLayersPanel),
                       onZoomIn: _zoomIn,
                       onZoomOut: _zoomOut,
                       isSelectingRegion: mapViewModel.isSelectingRegion,
                       isLayersPanelVisible: _showLayersPanel,
                       onToggleRecommendations: () => mapViewModel.toggleRecommendationsPanel(),
                       isRecommendationsPanelOpen: mapViewModel.isRecommendationsPanelOpen,
                       // İl Modu — tüm 81 ili doğrudan göster
                       onOpenProvincesMode: () {
                         mapViewModel.openProvincesMode();
                         // Mod kapatıldıysa JS katmanını da temizle
                         if (!mapViewModel.isProvinceModeActive &&
                             kIsWeb &&
                             mapViewModel.mapMode == MapMode.maplibre3d) {
                           MapViewMapLibre.clearSelectionMode();
                         }
                       },
                       isProvincesModeActive: mapViewModel.isProvincesModeActive,
                       // İlçe Modu — tüm Türkiye ilçelerini doğrudan göster
                       onOpenDistrictsMode: () {
                         mapViewModel.openDistrictsMode();
                         if (!mapViewModel.isProvinceModeActive &&
                             kIsWeb &&
                             mapViewModel.mapMode == MapMode.maplibre3d) {
                           MapViewMapLibre.clearSelectionMode();
                         }
                       },
                       isDistrictsModeActive: mapViewModel.isDistrictsModeActive,
                       onToggleAnimation: () => mapViewModel.toggleAnimationMode(),
                       isAnimationMode: mapViewModel.isAnimationMode,
                     ),

                     // 3b. Bölge Filtre Şeridi — İl modu aktifken üstte kayar chip'ler
                     if (mapViewModel.isProvincesModeActive)
                       Positioned(
                         top: 72,
                         left: 0,
                         right: mapViewModel.isRecommendationsPanelOpen ? 380 : 0,
                         child: _RegionFilterChips(
                           mapViewModel: mapViewModel,
                           theme: theme,
                         ),
                       ),

                     // 4. Map Bottom Sheet (Persistent Sidebar Replacement)
                     MapBottomSheet(
                       onScenariosTap: () => setState(() =>
                         _showScenariosPanel = !_showScenariosPanel),
                     ),

                     // 4b. MapLibre hızlı toggle — sağ üst köşe (yalnızca web'de)
                     if (kIsWeb)
                       Positioned(
                         top: 12,
                         right: mapViewModel.isRecommendationsPanelOpen ? 390 : 12,
                         child: Tooltip(
                           message: mapViewModel.mapMode == MapMode.maplibre3d
                               ? 'Standart haritaya geç'
                               : '3D Harita (MapLibre)\'e geç',
                           child: GestureDetector(
                             onTap: () => mapViewModel.setMapMode(
                               mapViewModel.mapMode == MapMode.maplibre3d
                                   ? MapMode.standard
                                   : MapMode.maplibre3d,
                             ),
                             child: AnimatedContainer(
                               duration: const Duration(milliseconds: 200),
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                               decoration: BoxDecoration(
                                 color: mapViewModel.mapMode == MapMode.maplibre3d
                                     ? Colors.deepPurple.withValues(alpha: 0.85)
                                     : Colors.black54,
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(
                                   color: mapViewModel.mapMode == MapMode.maplibre3d
                                       ? Colors.purpleAccent.withValues(alpha: 0.6)
                                       : Colors.white24,
                                 ),
                               ),
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Icon(
                                     mapViewModel.mapMode == MapMode.maplibre3d
                                         ? Icons.view_in_ar_rounded
                                         : Icons.map_outlined,
                                     size: 14,
                                     color: Colors.white,
                                   ),
                                   const SizedBox(width: 5),
                                   Text(
                                     mapViewModel.mapMode == MapMode.maplibre3d
                                         ? '3D Harita'
                                         : 'Standart',
                                     style: const TextStyle(
                                       color: Colors.white,
                                       fontSize: 11,
                                       fontWeight: FontWeight.w600,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                           ),
                         ),
                       ),

                     // 5. Contextual Action Indicators (e.g., "Click to place pin")
                     // bottom değerleri responsive: ekran yüksekliğinin %22'si (~180px 820px'de)
                     if (mapViewModel.placingPinType != null)
                      Positioned(
                        bottom: MediaQuery.of(context).size.height * 0.22,
                        left: 0,
                        right: mapViewModel.isRecommendationsPanelOpen ? 380 : 0,
                        child: PlacementIndicator(
                          placingPinType: mapViewModel.placingPinType,
                          onCancel: mapViewModel.stopPlacingMarker,
                        ),
                      ),

                    if (mapViewModel.isSelectingRegion)
                      Positioned(
                        bottom: mapViewModel.placingPinType != null
                            ? MediaQuery.of(context).size.height * 0.22 + 100
                            : MediaQuery.of(context).size.height * 0.22,
                        left: 0,
                        right: mapViewModel.isRecommendationsPanelOpen ? 380 : 0,
                        child: RegionSelectionIndicator(
                          points: mapViewModel.selectionPoints,
                          onCancel: mapViewModel.clearRegionSelection,
                        ),
                      ),

                     // 6. Recommendations Side Panel (slides from right)
                     AnimatedPositioned(
                       duration: const Duration(milliseconds: 350),
                       curve: Curves.easeInOutCubic,
                       top: 0,
                       bottom: 0,
                       right: mapViewModel.isRecommendationsPanelOpen ? 0 : -380,
                       width: 380,
                       child: RecommendationsSidePanel(
                         theme: theme,
                         mapViewModel: mapViewModel,
                         onCityNavigate: (lat, lon) => _animateMapTo(
                           LatLng(lat, lon), 10.0,
                         ),
                       ),
                     ),

                     // 6b. Zaman Simülasyonu Paneli (bottom floating)
                     if (mapViewModel.isAnimationMode)
                       Positioned(
                         bottom: 12,
                         left: 20,
                         right: mapViewModel.isRecommendationsPanelOpen ? 400 : 20,
                         child: Align(
                           alignment: Alignment.bottomCenter,
                           child: TimeSliderPanel(
                             theme: theme,
                             mapViewModel: mapViewModel,
                           ),
                         ),
                       ),

                     // 6b. Coğrafi Seçim Bilgi Kartı
                     // Bölge seçilince → il seviyesinde, il seçilince → ilçe seviyesinde gösterilir
                     if (mapViewModel.isProvinceModeActive &&
                         (mapViewModel.selectedRegionName != null ||
                          mapViewModel.selectedProvinceName != null ||
                          mapViewModel.selectedDistrictName != null))
                       Positioned(
                         bottom: 100,
                         left: 20,
                         child: ProvinceInfoCard(
                           // Hangi isim gösterilecek: ilçe > il > bölge
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
                                     // İlçe seçili → ilçe seçimini temizle
                                     mapViewModel.clearSelectedDistrict();
                                   } else if (mapViewModel.selectedProvinceName != null) {
                                     // İl seçili → il listesine geri dön
                                     mapViewModel.clearSelectedProvince();
                                   } else {
                                     // Bölge filtresi var → filtre kaldır, tüm iller
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
                         ),
                       ),

                     // 7. Scenarios Side Panel (slides from left)
                     AnimatedPositioned(
                       duration: const Duration(milliseconds: 350),
                       curve: Curves.easeInOutCubic,
                       top: 0,
                       bottom: 0,
                       left: _showScenariosPanel ? 0 : -330,
                       width: 320,
                       child: ScenarioSidePanel(
                         theme: theme,
                         onClose: () => setState(() => _showScenariosPanel = false),
                       ),
                     ),

                     // 8. Senaryo Mini Rapor Paneli (senaryo seçiliyken görünür)
                     if (scenarioVM.hasSelection)
                       Positioned(
                         bottom: 180,
                         right: 20,
                         child: ScenarioMiniReportPanel(
                           theme: theme,
                           scenarioVM: scenarioVM,
                         ),
                       ),
                   ],
                 ),
               ),
             ],
           ),
         );
      },
    );
  }

  void _handleMapTap(MapViewModel viewModel, LatLng point) {
     // Delegate interactions to ViewModel logic
     // Note: checkGeoSuitability needs BuildContext to show dialogs if staying in VM
     // OR we move dialog triggering here. Use result from VM.
     
     if (viewModel.isSelectingRegion) {
        viewModel.recordSelectionPoint(point);
        return;
     }

     if (viewModel.placingPinType != null) {
        // Trigger Suitability Check
        // Since logic was in MapScreen, we need to invoke the extracted logic or VM method
        // For now, let's assume we invoke a method on VM that might return a Future result
        _checkGeoSuitability(viewModel, point);
     }
  }

  Future<void> _checkGeoSuitability(MapViewModel viewModel, LatLng point) async {
    // Tekrar tıklamayı engelle
    if (_isProcessingGeoCheck) return;
    _isProcessingGeoCheck = true;

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
               Text("Analiz ediliyor...", style: TextStyle(color: theme.textColor)),
            ],
          ),
        ),
      ),
    );

    try {
       final result = await viewModel.geoCheck(point);

       if (!mounted) return;
       Navigator.pop(context); // Close loading

       if (result != null) {
          // await: dialog kapanana kadar guard aktif kalır → üst üste açılmaz
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
       debugPrint("Geo Check Exception: $e");
       if (!mounted) return;
       Navigator.pop(context);
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
       _isProcessingGeoCheck = false;
    }
  }

  void _animateMapTo(LatLng target, double zoom) {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    if (mapViewModel.mapMode == MapMode.maplibre3d) {
      // MapLibre modunda JS flyTo kullan
      MapViewMapLibre.flyTo(target.latitude, target.longitude, zoom: zoom);
    } else {
      _animatedMapController.animateTo(dest: target, zoom: zoom);
    }
  }

  void _zoomIn() {
    final mc = _animatedMapController.mapController;
    mc.move(mc.camera.center, mc.camera.zoom + 1);
  }

  void _zoomOut() {
    final mc = _animatedMapController.mapController;
    mc.move(mc.camera.center, mc.camera.zoom - 1);
  }

}

// ── Bölge Filtre Şeridi ─────────────────────────────────────────────────────
/// İl modu aktifken harita üzerinde floating chip listesi gösterir.
/// Seçilen bölge → sadece o bölgenin illeri gösterilir (opsiyonel filtre).
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
          // Tümü chip'i — bölge filtresi aktifken göster
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
          // Bölge chip'leri
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
    final labelColor = isReset || selected ? Colors.tealAccent : theme.textColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                fontWeight: selected || isReset ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

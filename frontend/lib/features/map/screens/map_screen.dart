import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

import 'package:frontend/features/map/widgets/map_view.dart';
import 'package:frontend/features/map/widgets/panels/map_overlays.dart';
import 'package:frontend/features/map/widgets/panels/recommendations/recommendations_side_panel.dart';
import 'package:frontend/features/map/widgets/panels/map_bottom_sheet.dart';
import 'package:frontend/features/map/widgets/map_widgets.dart';
import 'package:frontend/features/scenarios/widgets/scenario_side_panel.dart';
import 'package:frontend/features/scenarios/widgets/scenario_mini_report_panel.dart';


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

  // Hover — ValueNotifier ile sadece MapOverlays rebuild oluyor,
  // MapView/FlutterMap rebuild OLMUYOR. Bu, "Cannot hit test a render box
  // that has never been laid out" crash'ini engeller.
  final ValueNotifier<LatLng?> _hoverNotifier = ValueNotifier<LatLng?>(null);

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
      // Load initial weather data
      mapViewModel.loadWeatherForTime(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
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
                     // 1. Map Engine (Bottom Layer)
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
                     ),

                     // 4. Map Bottom Sheet (Persistent Sidebar Replacement)
                     MapBottomSheet(
                       onScenariosTap: () => setState(() =>
                         _showScenariosPanel = !_showScenariosPanel),
                     ),

                     // 5. Contextual Action Indicators (e.g., "Click to place pin")
                     if (mapViewModel.placingPinType != null)
                      Positioned(
                        bottom: 180,
                        left: 0,
                        right: 0,
                        child: PlacementIndicator(
                          placingPinType: mapViewModel.placingPinType,
                          onCancel: mapViewModel.stopPlacingMarker,
                        ),
                      ),

                    if (mapViewModel.isSelectingRegion)
                      Positioned(
                        bottom: mapViewModel.placingPinType != null ? 280 : 180,
                        left: 0,
                        right: 0,
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
     // Invoke the VM/Service
     // Show Loading Dialog
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
       // Using the new API Service structure via VM or directly
       // Ideally VM should expose this.
       // For this refactor, I'll access the service via Provider.of<ApiService> as before, 
       // but cleaner would be viewModel.checkGeoSuitability(point)
       
       // Access ApiService
       // apiService is not in VM yet? Let's use context read.
       // Wait, ApiService was passed to VM or accessible via Provider.
       // Let's use the one in context.
       
       // import 'package:frontend/core/api_services/api_service.dart'; // Need to import this
       // final apiService = Provider.of<ApiService>(context, listen: false);
       // final result = await apiService.geo.checkGeoSuitability(point.latitude, point.longitude);
       
       // BUT I want to move this logic effectively.
       // Let's call the VM method. I'll need to add it to MapViewModel if not present.
       // Looking at MapViewModel, it has `checkGeoSuitability` method from previous turn fixes?
       // The user said "Login Transfer: UI içindeki tüm setState gerektiren fonksiyonları... MapViewModel'e taşı."
       
       final result = await viewModel.geoCheck(point);
       
       if (!mounted) return;
       Navigator.pop(context); // Close loading

       if (result != null) {
          showDialog(
            context: context,
            builder: (ctx) => AddPinDialog(
               point: point,
               initialPinType: viewModel.placingPinType ?? 'Güneş Paneli',
            ),
          ).then((_) {
             viewModel.stopPlacingMarker();
          });
       }
    } catch (e) {
       debugPrint("Geo Check Exception: $e");
       if (!mounted) return;
       Navigator.pop(context);
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _animateMapTo(LatLng target, double zoom) {
    _animatedMapController.animateTo(dest: target, zoom: zoom);
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

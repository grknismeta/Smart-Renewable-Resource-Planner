import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
// Map components
import 'package:frontend/features/map/widgets/map_view.dart';
import 'package:frontend/features/map/widgets/map_controls.dart';
import 'package:frontend/features/map/widgets/layers_panel.dart';
import 'package:frontend/features/map/overlays/map_overlays.dart';
import 'package:frontend/features/map/overlays/selection_indicators.dart';
import 'package:frontend/features/map/widgets/panels/recommendations/recommendations_side_panel.dart';

// Sidebar & Dialogs
import 'package:frontend/features/sidebar/map_bottom_sheet.dart';
import 'package:frontend/features/map/widgets/dialogs/add_pin_dialog.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final AnimatedMapController _animatedMapController;

  // Local state for UI toggles
  bool _showLayersPanel = false;
  String _selectedBaseMap = 'dark';

  // Hover — ValueNotifier ile sadece MapOverlays rebuild oluyor,
  // MapView/FlutterMap rebuild OLMUYOR.
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
    return Consumer<MapViewModel>(
      builder: (context, mapViewModel, child) {
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
                        onAddPin: () => _showPinTypePicker(mapViewModel),
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
                        onToggleVectorLayer: () =>
                            mapViewModel.toggleVectorLayer(!mapViewModel.showVectorLayer),
                        isSelectingRegion: mapViewModel.isSelectingRegion,
                        isLayersPanelVisible: _showLayersPanel,
                        showVectorLayer: mapViewModel.showVectorLayer,
                        onToggleRecommendations: () => mapViewModel.toggleRecommendationsPanel(),
                        isRecommendationsPanelOpen: mapViewModel.isRecommendationsPanelOpen,
                      ),

                     // 4. Map Bottom Sheet (Persistent Sidebar Replacement)
                     const MapBottomSheet(),

                     // 5. Contextual Action Indicators
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
     if (viewModel.isSelectingRegion) {
        viewModel.recordSelectionPoint(point);
        return;
     }

     if (viewModel.placingPinType != null) {
        _checkGeoSuitability(viewModel, point);
     }
  }

  Future<void> _checkGeoSuitability(MapViewModel viewModel, LatLng point) async {
     if (!context.mounted) return;

     final apiService = Provider.of<ApiService>(context, listen: false);
     final themeVM = Provider.of<ThemeViewModel>(context, listen: false);
     final scenarioVM = Provider.of<ScenarioViewModel>(context, listen: false);

     showDialog(
       context: context,
       builder: (ctx) => MultiProvider(
         providers: [
           ChangeNotifierProvider<MapViewModel>.value(value: viewModel),
           ChangeNotifierProvider<ThemeViewModel>.value(value: themeVM),
           ChangeNotifierProvider<ScenarioViewModel>.value(value: scenarioVM),
           Provider<ApiService>.value(value: apiService),
         ],
         child: AddPinDialog(
            point: point,
            initialPinType: viewModel.placingPinType ?? 'Güneş Paneli',
         ),
       ),
     ).then((_) {
        viewModel.stopPlacingMarker();
     });
  }

  void _showPinTypePicker(MapViewModel viewModel) {
    final theme = Provider.of<ThemeViewModel>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Pin Türü Seç', style: TextStyle(color: theme.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pinTypeOption(theme, 'Güneş Paneli', Icons.wb_sunny, Colors.orange, viewModel),
            _pinTypeOption(theme, 'Rüzgar Türbini', Icons.air, Colors.lightBlue, viewModel),
            _pinTypeOption(theme, 'Hidroelektrik', Icons.water, Colors.cyan, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _pinTypeOption(ThemeViewModel theme, String type, IconData icon, Color color, MapViewModel vm) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(type, style: TextStyle(color: theme.textColor)),
      onTap: () {
        Navigator.pop(context);
        vm.startPlacingMarker(type);
      },
    );
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

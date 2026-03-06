import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

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

// Sidebar & Dialogs
import 'package:frontend/features/sidebar/map_bottom_sheet.dart';
import 'package:frontend/features/map/widgets/dialogs/add_pin_dialog.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  
  // Local state for UI toggles (could be in VM but acceptable here for UI-only state)
  bool _showLayersPanel = false;
  String _selectedBaseMap = 'dark';
  LatLng? _hoverPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
      // Load initial weather data
      mapViewModel.loadWeatherForTime(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
    });
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
                       mapController: _mapController,
                       selectedBaseMap: _selectedBaseMap,
                       onMapTap: (tapPosition, point) => _handleMapTap(mapViewModel, point),
                       onHover: (point) => setState(() => _hoverPosition = point),
                       onExitRange: () => setState(() => _hoverPosition = null),
                     ),

                     // 2. Overlays (Dashboard, Hover Info, Legends)
                     MapOverlays(
                       theme: theme,
                       mapViewModel: mapViewModel,
                       hoverPosition: _hoverPosition,
                       layersPanel: _showLayersPanel 
                          ? LayersPanel(
                              theme: theme,
                              mapViewModel: mapViewModel,
                              selectedBaseMap: _selectedBaseMap,
                              onBaseMapChanged: (val) => setState(() => _selectedBaseMap = val),
                            )
                          : null,
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
                      ),

                     // 4. Map Bottom Sheet (Persistent Sidebar Replacement)
                     const MapBottomSheet(),

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
     // Dialog kendi içinde geoCheck + uygunluk kontrolü yapıyor
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

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
  }
}

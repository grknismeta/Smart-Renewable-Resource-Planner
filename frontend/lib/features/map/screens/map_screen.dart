import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/core/theme/theme_view_model.dart';

// New Atomic Components
import 'package:frontend/features/map/widgets/map_view.dart';
import 'package:frontend/features/map/widgets/panels/map_overlays.dart';


import 'package:frontend/features/map/widgets/panels/map_bottom_sheet.dart';
import 'package:frontend/features/map/widgets/map_widgets.dart'; 
// Import AddPinDialog


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

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
  }
}

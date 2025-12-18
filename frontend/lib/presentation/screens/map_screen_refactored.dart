// presentation/screens/map_screen.dart
//
// Refactored: Modern Flutter Architecture
// Sorumluluk: Sadece layout composition - business logic yok

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../providers/map_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/sidebar_menu.dart';
import '../features/map/widgets/map_controls.dart';
import '../features/map/widgets/resource_action_buttons.dart';
import '../features/map/widgets/optimization_buttons.dart';
import '../widgets/map/map_widgets.dart';
import '../widgets/map/flutter_map_view.dart';
import '../features/map/widgets/time_slider_widget.dart';

/// Main Map Screen - Clean, composable architecture
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _showLayersPanel = false;
  String _selectedBaseMap = 'dark';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      mapProvider.loadWeatherForTime(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: isWideScreen
          ? null
          : AppBar(
              title: const Text('SRRP'),
              backgroundColor: theme.backgroundColor,
              foregroundColor: theme.textColor,
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWideScreen) const SidebarMenu(),
          Expanded(
            child: Stack(
              children: [
                // Main Map View
                FlutterMapView(
                  mapController: _mapController,
                  selectedBaseMap: _selectedBaseMap,
                ),

                // Dashboard (Top Left)
                Positioned(
                  top: 20,
                  left: 20,
                  child: MapDashboard(theme: theme),
                ),

                // Controls (Top Right)
                _buildTopRightControls(mapProvider, theme),

                // Time Slider (Bottom Center)
                Positioned(
                  bottom: 100,
                  left: 20,
                  right: 20,
                  child: const TimeSliderWidget(),
                ),

                // Placement Indicator
                if (mapProvider.placingPinType != null)
                  Positioned(
                    bottom: 180,
                    left: 0,
                    right: 0,
                    child: PlacementIndicator(
                      placingPinType: mapProvider.placingPinType,
                      onCancel: mapProvider.stopPlacingMarker,
                    ),
                  ),

                // Region Selection Indicator
                if (mapProvider.isSelectingRegion)
                  Positioned(
                    bottom: mapProvider.placingPinType != null ? 280 : 180,
                    left: 0,
                    right: 0,
                    child: RegionSelectionIndicator(
                      points: mapProvider.selectionPoints,
                      onCancel: mapProvider.clearRegionSelection,
                    ),
                  ),

                // Map Controls (Zoom, etc.)
                MapControls(
                  onZoomIn: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                  onZoomOut: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                  onToggleLayers: () =>
                      setState(() => _showLayersPanel = !_showLayersPanel),
                  showLayersPanel: _showLayersPanel,
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRightControls(MapProvider mapProvider, ThemeProvider theme) {
    return Positioned(
      top: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Resource Action Buttons
          ResourceActionButtons(mapProvider: mapProvider),
          const SizedBox(height: 10),

          // Optimization Buttons
          OptimizationButtons(mapProvider: mapProvider),
          const SizedBox(height: 10),

          // Layers Toggle (already in MapControls, remove duplication)
          if (_showLayersPanel)
            LayersPanel(
              theme: theme,
              mapProvider: mapProvider,
              selectedBaseMap: _selectedBaseMap,
              onBaseMapChanged: (value) =>
                  setState(() => _selectedBaseMap = value),
            ),
        ],
      ),
    );
  }
}

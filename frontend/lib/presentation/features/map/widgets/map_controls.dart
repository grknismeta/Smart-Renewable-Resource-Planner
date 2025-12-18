// presentation/features/map/widgets/map_controls.dart
//
// Sorumluluk: Harita kontrol butonları (zoom, layers, etc.)
// Tek sorumluluk prensibi - sadece kontrol UI'ı

import 'package:flutter/material.dart';
import '../../../../providers/theme_provider.dart';

/// Harita kontrol butonları widget'ı
class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onToggleLayers;
  final bool showLayersPanel;
  final ThemeProvider theme;

  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onToggleLayers,
    required this.showLayersPanel,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Zoom In
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            backgroundColor: theme.cardColor,
            onPressed: onZoomIn,
            child: Icon(Icons.add, color: theme.textColor),
          ),
          const SizedBox(height: 10),

          // Zoom Out
          FloatingActionButton.small(
            heroTag: 'zoom_out',
            backgroundColor: theme.cardColor,
            onPressed: onZoomOut,
            child: Icon(Icons.remove, color: theme.textColor),
          ),
          const SizedBox(height: 10),

          // Layers Toggle
          FloatingActionButton.small(
            heroTag: 'layer_toggle',
            backgroundColor: theme.cardColor,
            onPressed: onToggleLayers,
            child: Icon(Icons.layers, color: theme.textColor),
          ),
        ],
      ),
    );
  }
}

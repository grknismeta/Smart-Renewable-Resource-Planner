import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../viewmodels/theme_view_model.dart';
import '../viewmodels/map_view_model.dart'; // For finding nearest city
import 'map_legend.dart';
import 'map_dashboard.dart'; // For MapDashboard
import 'map_layers_system.dart';

class MapOverlays extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;
  final LatLng? hoverPosition;
  final Widget? layersPanel;

  const MapOverlays({
    super.key,
    required this.theme,
    required this.mapViewModel,
    this.hoverPosition,
    this.layersPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Dashboard (Top Left)
        Positioned(
          top: 20,
          left: 20,
          child: MapDashboard(theme: theme),
        ),

        // 2. Hover Info (Bottom Left, above controls)
        if (hoverPosition != null && mapViewModel.currentLayer != MapLayerType.none)
          Positioned(
            top: 180,
            left: 20,
            child: _buildHoverInfo(context),
          ),

        // 3. Layers Panel (Below Controls, Top Right)
        if (layersPanel != null)
           Positioned(
             top: 140, // Adjust based on control height
             right: 20,
             child: layersPanel!,
           ),

        // 4. Legends (Bottom Right)
        if (mapViewModel.currentLayer == MapLayerType.irradiance)
          Positioned(
            bottom: 40,
            right: 20,
            child: LegendWidget(
              theme: theme,
              title: 'Işınım Yoğunluğu',
              titleFontSize: 11,
              unit: 'kWh/m²/yıl',
              gradientColors: [
                Colors.black87,
                Colors.red.shade900,
                Colors.orange,
                Colors.yellow,
              ],
              minLabel: '0',
              maxLabel: '2200',
            ),
          )
        else if (mapViewModel.currentLayer == MapLayerType.wind)
          Positioned(
            bottom: 40,
            right: 20,
            child: LegendWidget(
              theme: theme,
              title: 'Rüzgar Hızı',
              unit: 'm/s',
              gradientColors: [
                Colors.grey.shade300,
                Colors.blue.shade200,
                Colors.blue.shade700,
                Colors.deepPurple.shade900,
              ],
              minLabel: '0',
              maxLabel: '15+',
            ),
          )
        else if (mapViewModel.currentLayer == MapLayerType.temp)
          Positioned(
            bottom: 40,
            right: 20,
            child: LegendWidget(
              theme: theme,
              title: 'Sıcaklık',
              unit: '°C',
              gradientColors: [
                Colors.indigo,
                Colors.cyan,
                Colors.yellow,
                Colors.red.shade900,
              ],
              minLabel: '-10',
              maxLabel: '40+',
            ),
          ),
      ],
    );
  }

  Widget _buildHoverInfo(BuildContext context) {
    final nearestCity = mapViewModel.findNearestCity(hoverPosition!);
    if (nearestCity == null) return const SizedBox.shrink();

    final isTemp = mapViewModel.currentLayer == MapLayerType.temp;
    final value = isTemp ? nearestCity.temperature : nearestCity.windSpeed;
    final unit = isTemp ? '°C' : 'm/s';
    final icon = isTemp ? Icons.thermostat : Icons.air;
    final color = isTemp ? Colors.blue : Colors.green;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nearestCity.cityName,
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: TextStyle(color: theme.secondaryTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

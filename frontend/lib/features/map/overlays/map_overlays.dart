import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/weather_model.dart'; // Added for CityWeatherSummary
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart'; // For finding nearest city
import 'package:frontend/features/map/widgets/map_legend.dart';
import 'package:frontend/features/map/overlays/map_dashboard.dart'; // For MapDashboard
import 'package:frontend/features/map/widgets/map_date_picker.dart';


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
             top: 190, // Positioned below the Top Right controls stack
             right: 20,
             child: layersPanel!,
           ),

        // 4. Tarih Seçici (Sol alt — hava katmanı açıkken görünür)
        if (mapViewModel.currentLayer != MapLayerType.none)
          Positioned(
            bottom: 100,
            left: 20,
            child: MapDatePickerWidget(
              theme: theme,
              mapViewModel: mapViewModel,
            ),
          ),

        // 5. Legends (Bottom Right)
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
                Colors.black.withValues(alpha: 0.5), // Representing Transparent/Low
                Colors.deepOrangeAccent,
                Colors.redAccent.shade700,
                Colors.orangeAccent,
                Colors.white,
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
                Colors.black.withValues(alpha: 0.5),
                Colors.blueAccent.shade700,
                Colors.cyanAccent,
                Colors.white,
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

    // DEBUG: Inspect radiation data
    if (mapViewModel.currentLayer == MapLayerType.irradiance) {
        debugPrint("Hover City: ${nearestCity.cityName}");
        debugPrint("Radiation: ${nearestCity.radiation}");
        debugPrint("Shortwave: ${nearestCity.shortwaveRadiation}");
        debugPrint("Timestamp: ${nearestCity.timestamp}");
    }

    double value = 0;
    String valueText = '';
    IconData icon = Icons.help_outline;
    Color color = Colors.grey;

    switch (mapViewModel.currentLayer) {
      case MapLayerType.temp:
        value = nearestCity.temperature;
        valueText = '${value.toStringAsFixed(1)} °C';
        icon = Icons.thermostat;
        color = Colors.blue;
        break;
      case MapLayerType.irradiance:
        // Summary'den yıllık potansiyel tahmini
        final summary = mapViewModel.weatherSummary.firstWhere(
            (s) => s.cityName == nearestCity.cityName,
            orElse: () => mapViewModel.weatherSummary.isEmpty 
              ? CityWeatherSummary(cityName: '', lat: 0, lon: 0, recordCount: 0) // Dummy
              : mapViewModel.weatherSummary.first // Fallback
        );
        
        if (summary.totalRadiation != null) {
           // 7 günlük veriden yıllık tahmin: (TotalWh / 1000) * 52 hafta
           final weeklyKwh = summary.totalRadiation! / 1000.0;
           final annualKwh = weeklyKwh * 52; 
           
           if (annualKwh >= 1000000) {
              valueText = '${(annualKwh / 1000000).toStringAsFixed(2)} GWh/m²/yıl';
           } else if (annualKwh >= 1000) {
              valueText = '${(annualKwh / 1000).toStringAsFixed(2)} MWh/m²/yıl';
           } else {
              valueText = '${annualKwh.toStringAsFixed(0)} kWh/m²/yıl';
           }
        } else {
           valueText = 'Veri Yok';
        }

        icon = Icons.wb_sunny;
        color = Colors.orange;
        break;
      case MapLayerType.wind:
      default:
        value = nearestCity.windSpeed;
        valueText = '${value.toStringAsFixed(1)} m/s';
        icon = Icons.air;
        color = Colors.green;
        break;
    }

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
                valueText,
                style: TextStyle(color: theme.secondaryTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

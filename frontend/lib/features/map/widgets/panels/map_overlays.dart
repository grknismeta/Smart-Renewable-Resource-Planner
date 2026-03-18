import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/data/models/weather_model.dart'; // Added for CityWeatherSummary
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/widgets/panels/map_legend.dart';
import 'package:frontend/features/map/widgets/panels/map_dashboard.dart';


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

        // 2. Hover Info (her zaman göster — katman bağımsız)
        if (hoverPosition != null)
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
    // Katman none ise: weatherSummary fallback'i ile şehir adı göster
    if (mapViewModel.currentLayer == MapLayerType.none) {
      final cityName = mapViewModel.findNearestCityName(hoverPosition!);
      if (cityName == null) return const SizedBox.shrink();
      return _buildLocationCard(cityName);
    }

    final nearestCity = mapViewModel.findNearestCity(hoverPosition!);
    if (nearestCity == null) return const SizedBox.shrink();

    String valueText = '';
    IconData icon = Icons.help_outline;
    Color color = Colors.grey;

    switch (mapViewModel.currentLayer) {
      case MapLayerType.temp:
        valueText = '${nearestCity.temperature.toStringAsFixed(1)} °C';
        icon = Icons.thermostat;
        color = Colors.blue;
        break;
      case MapLayerType.irradiance:
        final summary = mapViewModel.weatherSummary.firstWhere(
          (s) => s.cityName == nearestCity.cityName,
          orElse: () => CityWeatherSummary(cityName: '', lat: 0, lon: 0, recordCount: 0),
        );
        if (summary.totalRadiation != null) {
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
        valueText = '${nearestCity.windSpeed.toStringAsFixed(1)} m/s';
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

  /// Katman seçili değilken gösterilen minimal konum kartı
  Widget _buildLocationCard(String cityName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 16,
            color: theme.secondaryTextColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            cityName,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/widgets/panels/map_legend.dart';
import 'package:frontend/features/map/widgets/panels/map_dashboard.dart';


class MapOverlays extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;
  final Widget? layersPanel;

  const MapOverlays({
    super.key,
    required this.theme,
    required this.mapViewModel,
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
          child: PointerInterceptor(child: MapDashboard(theme: theme)),
        ),


        // 3. Layers Panel (Below Controls, Top Right)
        if (layersPanel != null)
           Positioned(
             top: 190, // Positioned below the Top Right controls stack
             right: 20,
             child: PointerInterceptor(child: layersPanel!),
           ),

        // 4. Legends (Bottom Right)
        if (mapViewModel.currentLayer == MapLayerType.irradiance)
          Positioned(
            bottom: 40,
            right: 20,
            child: PointerInterceptor(
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
            ),
          )
        else if (mapViewModel.currentLayer == MapLayerType.wind)
          Positioned(
            bottom: 40,
            right: 20,
            child: PointerInterceptor(
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
            ),
          )
        else if (mapViewModel.currentLayer == MapLayerType.temp)
          Positioned(
            bottom: 40,
            right: 20,
            child: PointerInterceptor(
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
          ),
      ],
    );
  }

}

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

        // 1. Dashboard (Top Left) — Globe modunda gizle
        if (!mapViewModel.showGlobe)
          Positioned(
            top: 20,
            left: 20,
            child: PointerInterceptor(child: MapDashboard(theme: theme)),
          ),

        // 1b. Globe Modu Bilgi Kartı (Top Left)
        if (mapViewModel.showGlobe)
          Positioned(
            top: 20,
            left: 20,
            child: PointerInterceptor(
              child: GlobeInfoCard(theme: theme),
            ),
          ),


        // 3. Layers Panel (Below Controls, Top Right)
        if (layersPanel != null)
           Positioned(
             top: 90, // 2 buttons only (Add Pin + Layers) ≈ 50+16+50 = 116px → 90 safe offset
             right: 20,
             child: PointerInterceptor(child: layersPanel!),
           ),

        // 4. Legends (Bottom Right) — ısı haritası katmanları
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
                  Colors.black.withValues(alpha: 0.5),
                  Colors.deepOrangeAccent,
                  Colors.redAccent.shade700,
                  Colors.orangeAccent,
                  Colors.white,
                ],
                minLabel: '0',
                maxLabel: '2200',
                tickLabels: const ['0', '550', '1100', '1650', '2200'],
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
                tickLabels: const ['0', '3', '6', '9', '12', '15+'],
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
                tickLabels: const ['-10', '5', '20', '35', '40+'],
              ),
            ),
          ),

        // ── Choropleth Legendları (Sol Alt — zoom butonlarının üstünde) ───
        if (mapViewModel.choroplethMode == ChoroplethMode.solar)
          Positioned(
            bottom: 40,
            left: 12,
            child: PointerInterceptor(
              child: LegendWidget(
                theme: theme,
                title: 'Güneş Işınımı (İlçe)',
                titleFontSize: 10,
                unit: 'W/m²',
                width: 190,
                gradientColors: const [
                  Color(0xFFFFFFCC),
                  Color(0xFFFFEDA0),
                  Color(0xFFFED976),
                  Color(0xFFFEB24C),
                  Color(0xFFFD8D3C),
                  Color(0xFFFC4E2A),
                  Color(0xFFE31A1C),
                  Color(0xFFBD0026),
                  Color(0xFF800026),
                  Color(0xFF4D0014),
                ],
                minLabel: '0',
                maxLabel: '400',
                tickLabels: const ['0', '80', '160', '240', '320', '400'],
              ),
            ),
          )
        else if (mapViewModel.choroplethMode == ChoroplethMode.wind)
          Positioned(
            bottom: 40,
            left: 12,
            child: PointerInterceptor(
              child: LegendWidget(
                theme: theme,
                title: 'Rüzgar Hızı (İlçe)',
                titleFontSize: 10,
                unit: 'm/s',
                width: 190,
                gradientColors: const [
                  Color(0xFFF7FBFF),
                  Color(0xFFDEEBF7),
                  Color(0xFFC6DBEF),
                  Color(0xFF9ECAE1),
                  Color(0xFF6BAED6),
                  Color(0xFF4292C6),
                  Color(0xFF2171B5),
                  Color(0xFF08519C),
                  Color(0xFF083D7F),
                  Color(0xFF08306B),
                ],
                minLabel: '0',
                maxLabel: '12',
                tickLabels: const ['0', '2', '4', '6', '8', '10', '12'],
              ),
            ),
          )
        else if (mapViewModel.choroplethMode == ChoroplethMode.temperature)
          Positioned(
            bottom: 40,
            left: 12,
            child: PointerInterceptor(
              child: LegendWidget(
                theme: theme,
                title: 'Sıcaklık (İlçe)',
                titleFontSize: 10,
                unit: '°C',
                width: 210,
                gradientColors: const [
                  // -15 → 0: Koyu mavi → açık mavi
                  Color(0xFF08306B),
                  Color(0xFF2171B5),
                  Color(0xFF6BAED6),
                  // 0 → 15: Açık mavi → açık yeşil
                  Color(0xFFC6DBEF),
                  Color(0xFFD9F0A3),
                  // 15 → 20: Yeşile geçiş
                  Color(0xFF78C679),
                  // 20 → 30: Optimal aralık — yeşil
                  Color(0xFF31A354),
                  Color(0xFF006837),
                  Color(0xFF31A354),
                  // 30 → 35: Sarıya geçiş
                  Color(0xFFFED976),
                  Color(0xFFFEB24C),
                  // 35 → 40: Turuncu → kırmızı
                  Color(0xFFFD8D3C),
                  Color(0xFFE31A1C),
                  // 40 → 45: Koyu kırmızı
                  Color(0xFFBD0026),
                  Color(0xFF800026),
                ],
                minLabel: '-15',
                maxLabel: '45',
                tickLabels: const ['-15', '0', '10', '20', '30', '40', '45'],
              ),
            ),
          ),
      ],
    );
  }

}

// ── Globe Modu Bilgi Kartı ───────────────────────────────────────────────────

class GlobeInfoCard extends StatelessWidget {
  final ThemeViewModel theme;

  const GlobeInfoCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.public_rounded, size: 16,
                color: Colors.deepPurpleAccent),
            const SizedBox(width: 6),
            Text(
              'Global Projeksiyon',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Dünyanın herhangi bir noktasına pin ekleyebilirsiniz. '
            'Türkiye katmanları bu modda devre dışıdır.',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline_rounded, size: 11,
                  color: Colors.deepPurpleAccent),
              const SizedBox(width: 4),
              Text(
                'Yurtdışı pin desteği aktif',
                style: TextStyle(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.9),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

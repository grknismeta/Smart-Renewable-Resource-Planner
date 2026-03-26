import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/viewmodels/map_view_model.dart';

class MapDashboard extends StatelessWidget {
  final ThemeViewModel theme;

  const MapDashboard({super.key, required this.theme});

  /// Türkiye sınırları içinde mi? (lat 35-43, lon 25-46)
  static bool _isInTurkey(double lat, double lon) {
    return lat >= 35.0 && lat <= 43.0 && lon >= 25.0 && lon <= 46.0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapViewModel>(
      builder: (context, mapViewModel, _) {
        final isGlobe = mapViewModel.showGlobe;
        final allPins = mapViewModel.pins;

        // Globe modunda tüm pinleri, normal modda sadece Türkiye pinlerini sayar
        final turkeyPins = allPins.where(
          (p) => _isInTurkey(p.latitude, p.longitude),
        ).toList();
        final globalPins = allPins.where(
          (p) => !_isInTurkey(p.latitude, p.longitude),
        ).toList();
        final activePins = isGlobe ? allPins : turkeyPins;

        // Pin sayılarını hesapla
        final windPins = activePins
            .where((p) => p.type == 'Rüzgar Türbini')
            .length;
        final solarPins = activePins
            .where((p) => p.type == 'Güneş Paneli')
            .length;
        final hesPins = activePins
            .where((p) => p.type == 'Hidroelektrik')
            .length;
        final totalCapacity = activePins.fold<double>(
          0,
          (sum, pin) => sum + pin.capacityMw,
        );

        // Globe modunda Türkiye dışı ekstra sayılar
        final globalWind = isGlobe
            ? globalPins.where((p) => p.type == 'Rüzgar Türbini').length
            : 0;
        final globalSolar = isGlobe
            ? globalPins.where((p) => p.type == 'Güneş Paneli').length
            : 0;
        final globalHes = isGlobe
            ? globalPins.where((p) => p.type == 'Hidroelektrik').length
            : 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.secondaryTextColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              _buildStatItem(
                'Rüzgar',
                '$windPins',
                windPins > 0 ? Colors.blueAccent : theme.secondaryTextColor,
                globalExtra: globalWind > 0 ? '+$globalWind' : null,
              ),
              _divider(),
              _buildStatItem(
                'Güneş',
                '$solarPins',
                solarPins > 0 ? Colors.orangeAccent : theme.secondaryTextColor,
                globalExtra: globalSolar > 0 ? '+$globalSolar' : null,
              ),
              _divider(),
              _buildStatItem(
                'HES',
                '$hesPins',
                hesPins > 0 ? const Color(0xFF29B6F6) : theme.secondaryTextColor,
                globalExtra: globalHes > 0 ? '+$globalHes' : null,
              ),
              _divider(),
              _buildStatItem(
                'Kapasite',
                '${totalCapacity.toStringAsFixed(1)} MW',
                Colors.greenAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: 1,
        height: 30,
        color: theme.secondaryTextColor.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor,
      {String? globalExtra}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (globalExtra != null) ...[
              const SizedBox(width: 4),
              Text(
                globalExtra,
                style: TextStyle(
                  color: valueColor.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

class MapDashboard extends StatelessWidget {
  final ThemeViewModel theme;

  const MapDashboard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer<MapViewModel>(
      builder: (context, mapViewModel, _) {
        // Pin sayılarını hesapla
        final windPins = mapViewModel.pins
            .where((p) => p.type == 'Rüzgar Türbini')
            .length;
        final solarPins = mapViewModel.pins
            .where((p) => p.type == 'Güneş Paneli')
            .length;
        final totalCapacity = mapViewModel.pins.fold<double>(
          0,
          (sum, pin) => sum + pin.capacityMw,
        );

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
              ),
              const SizedBox(width: 20),
              Container(
                width: 1,
                height: 30,
                color: theme.secondaryTextColor.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 20),
              _buildStatItem(
                'Güneş',
                '$solarPins',
                solarPins > 0 ? Colors.orangeAccent : theme.secondaryTextColor,
              ),
              const SizedBox(width: 20),
              Container(
                width: 1,
                height: 30,
                color: theme.secondaryTextColor.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 20),
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

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// lib/presentation/widgets/sidebar/pins_panel.dart

import 'package:flutter/material.dart';
import '../../../data/models/pin_model.dart';
import '../../../providers/map_provider.dart';
import '../../../providers/theme_provider.dart';
import '../map/map_dialogs.dart';

/// Sidebar'da pin listesini gösteren panel
class PinsPanel extends StatelessWidget {
  final ThemeProvider theme;
  final MapProvider mapProvider;
  final bool isCollapsed;

  const PinsPanel({
    super.key,
    required this.theme,
    required this.mapProvider,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      // Dar modda sadece ikon
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          Icons.location_on,
          color: theme.secondaryTextColor.withValues(alpha: 0.6),
        ),
      );
    }

    // Geniş modda tam liste
    final solarPins = mapProvider.pins
        .where((p) => p.type == 'Güneş Paneli')
        .toList();
    final windPins = mapProvider.pins
        .where((p) => p.type == 'Rüzgar Türbini')
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Icon(Icons.location_on, color: theme.textColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pinlerim',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.backgroundColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${mapProvider.pins.length}',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Güneş Panelleri
          if (solarPins.isNotEmpty) ...[
            _buildCategoryHeader(
              'Güneş Panelleri',
              solarPins.length,
              Colors.orange,
            ),
            const SizedBox(height: 6),
            ...solarPins.map(
              (pin) => _buildPinItem(context, pin, Colors.orange),
            ),
            const SizedBox(height: 8),
          ],

          // Rüzgar Türbinleri
          if (windPins.isNotEmpty) ...[
            _buildCategoryHeader(
              'Rüzgar Türbinleri',
              windPins.length,
              Colors.blue,
            ),
            const SizedBox(height: 6),
            ...windPins.map((pin) => _buildPinItem(context, pin, Colors.blue)),
          ],

          // Boş durum
          if (mapProvider.pins.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Henüz pin eklenmedi',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($count)',
          style: TextStyle(
            color: theme.secondaryTextColor.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildPinItem(BuildContext context, Pin pin, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => MapDialogs.showPinActionsDialog(context, pin),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: theme.backgroundColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  pin.type == 'Güneş Paneli'
                      ? Icons.wb_sunny
                      : Icons.wind_power,
                  color: accentColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pin.name,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${pin.capacityMw.toStringAsFixed(1)} MW',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.secondaryTextColor.withValues(alpha: 0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

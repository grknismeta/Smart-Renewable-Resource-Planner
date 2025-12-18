// presentation/features/map/widgets/resource_action_buttons.dart
//
// Sorumluluk: Kaynak ekleme action butonları
// Reusable, temiz UI component

import 'package:flutter/material.dart';
import '../../../../providers/map_provider.dart';
import '../../../widgets/map/map_widgets.dart';

/// Kaynak ekleme butonları (Güneş Paneli + Rüzgar Türbini)
class ResourceActionButtons extends StatelessWidget {
  final MapProvider mapProvider;

  const ResourceActionButtons({super.key, required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      bottom: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rüzgar Türbini
          ResourceActionButton(
            type: 'Rüzgar Türbini',
            onTap: () => mapProvider.startPlacingMarker('Rüzgar Türbini'),
          ),
          const SizedBox(height: 10),

          // Güneş Paneli
          ResourceActionButton(
            type: 'Güneş Paneli',
            onTap: () => mapProvider.startPlacingMarker('Güneş Paneli'),
          ),
        ],
      ),
    );
  }
}

// lib/presentation/widgets/control_buttons.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/map_provider.dart';

class ControlButtons extends StatelessWidget {
  const ControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);

    return Column(
      children: [
        // Harita Katmanı Değiştirme Butonu
        FloatingActionButton(
          heroTag: 'btn3',
          mini: true,
          onPressed: mapProvider.changeMapLayer,
          child: const Icon(Icons.layers),
        ),
        const SizedBox(height: 8),
        // Pin Ekleme Modu Butonu
        FloatingActionButton(
          heroTag: 'btn2',
          mini: true,
          backgroundColor: mapProvider.isPlacingMarker
              ? Colors.blue[800]
              : Theme.of(context).primaryColor,
          onPressed: () {
            mapProvider.togglePlacingMarkerMode();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  mapProvider.isPlacingMarker
                      ? 'Pin Ekleme Modu: Aktif'
                      : 'Pin Ekleme Modu: Kapalı',
                ),
                duration: const Duration(milliseconds: 800),
              ),
            );
          },
          child: const Icon(Icons.add_location_alt),
        ),
        const SizedBox(height: 8),
        // Hesaplama Başlatma Butonu (şimdilik boş)
        FloatingActionButton(
          heroTag: 'btn1',
          mini: true,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hesaplama modülü yakında!'),
                duration: Duration(milliseconds: 800),
              ),
            );
          },
          child: const Icon(Icons.energy_savings_leaf),
        ),
      ],
    );
  }
}

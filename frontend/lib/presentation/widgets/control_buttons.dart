// lib/presentation/widgets/control_buttons.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/map_provider.dart';

class ControlButtons extends StatelessWidget {
  const ControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);

    // --- HATA DÜZELTMESİ: Eksik değişken tanımlamaları eklendi ---
    // Bu değişkenler, butonların rengini belirlemek ve
    // iptal butonunu gösterip göstermemek için kullanılır.
    final placingSolar = mapProvider.placingPinType == 'Güneş Paneli';
    final placingWind = mapProvider.placingPinType == 'Rüzgar Türbini';
    final isPlacing = placingSolar || placingWind;
    // --- DÜZELTME SONU ---
    return Column(
      children: [
        // --- 1. GÜNCELLEME: Katman (Layer) Değiştirme Butonu ---
        FloatingActionButton(
          heroTag: 'btn_layer',
          onPressed: mapProvider.changeMapLayer,
          tooltip: 'Katman Değiştir',
          child: Icon(
            mapProvider.currentLayer == MapLayer.none
                ? Icons.layers
                : mapProvider.currentLayer == MapLayer.wind
                ? Icons.air
                : Icons.wb_sunny,
          ),
        ),
        const SizedBox(height: 10),

        // --- 2. GÜNCELLEME: Tek "Ekle" Butonu - Tip dropdown ile seçim
        FloatingActionButton(
          heroTag: 'btn_add',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Theme.of(context).cardColor,
              builder: (ctx) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.solar_power),
                      title: const Text('Güneş Paneli'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        mapProvider.startPlacingMarker('Güneş Paneli');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.wind_power),
                      title: const Text('Rüzgar Türbini'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        mapProvider.startPlacingMarker('Rüzgar Türbini');
                      },
                    ),
                  ],
                );
              },
            );
          },
          tooltip: 'Ekle',
          backgroundColor: isPlacing ? Colors.green : Colors.blueGrey,
          child: const Icon(Icons.add),
        ),

        // --- 4. GÜNCELLEME: Ekleme Modu Aktifse "İptal" Butonu Göster ---
        if (isPlacing) ...[
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'btn_cancel',
            onPressed: mapProvider.stopPlacingMarker,
            tooltip: 'Ekleme Modunu Kapat',
            backgroundColor: Colors.red,
            child: const Icon(Icons.close),
          ),
        ],
      ],
    );
  }
}

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

        // --- 2. GÜNCELLEME: Güneş Paneli Ekle Butonu ---
        FloatingActionButton(
          heroTag: 'btn_solar',
          onPressed: () => mapProvider.startPlacingMarker('Güneş Paneli'),
          tooltip: 'Güneş Paneli Ekle',
          backgroundColor: placingSolar ? Colors.amber : Colors.blueGrey,
          child: const Icon(Icons.solar_power),
        ),
        const SizedBox(height: 10),

        // --- 3. GÜNCELLEME: Rüzgar Türbini Ekle Butonu ---
        FloatingActionButton(
          heroTag: 'btn_wind',
          onPressed: () => mapProvider.startPlacingMarker('Rüzgar Türbini'),
          tooltip: 'Rüzgar Türbini Ekle',
          backgroundColor: placingWind ? Colors.blue : Colors.blueGrey,
          child: const Icon(Icons.wind_power),
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

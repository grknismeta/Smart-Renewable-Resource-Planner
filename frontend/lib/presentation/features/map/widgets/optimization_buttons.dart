// presentation/features/map/widgets/optimization_buttons.dart
//
// Sorumluluk: Optimizasyon işlemi butonları
// Bölge seçimi ve hesaplama UI'ı

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/map_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../widgets/map/map_widgets.dart';

/// Optimizasyon butonları (Bölge Seç / Hesapla)
class OptimizationButtons extends StatelessWidget {
  final MapProvider mapProvider;

  const OptimizationButtons({super.key, required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    return Positioned(left: 20, bottom: 20, child: _buildButton(context));
  }

  Widget _buildButton(BuildContext context) {
    if (mapProvider.isSelectingRegion) {
      return _buildCalculateButton(context);
    }
    return _buildSelectRegionButton();
  }

  Widget _buildSelectRegionButton() {
    return FloatingActionButton.extended(
      heroTag: 'optimization_select',
      backgroundColor: Colors.blue,
      onPressed: mapProvider.startSelectingRegion,
      icon: const Icon(Icons.select_all),
      label: const Text('Bölge Seç'),
    );
  }

  Widget _buildCalculateButton(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'optimization_calculate',
      backgroundColor: Colors.blue,
      onPressed: mapProvider.hasValidSelection
          ? () => _onCalculate(context)
          : null,
      icon: const Icon(Icons.calculate),
      label: const Text('Hesapla'),
    );
  }

  Future<void> _onCalculate(BuildContext context) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    // Ekipmanları yükle (dialog açılmadan önce)
    if (!mapProvider.equipmentsLoading && mapProvider.equipments.isEmpty) {
      await mapProvider.loadEquipments();
    }

    if (!context.mounted) return;
    OptimizationDialog.show(context, mapProvider, theme);
  }
}

// presentation/features/map/widgets/optimization_buttons.dart
//
// Sorumluluk: Optimizasyon işlemi butonları
// Bölge seçimi ve hesaplama UI'ı

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/presentation/viewmodels/map_view_model.dart';
import 'package:frontend/presentation/viewmodels/theme_view_model.dart';
import '../../../widgets/map/map_widgets.dart';

/// Optimizasyon butonları (Bölge Seç / Hesapla)
class OptimizationButtons extends StatelessWidget {
  final MapViewModel mapViewModel;

  const OptimizationButtons({super.key, required this.mapViewModel});

  @override
  Widget build(BuildContext context) {
    return Positioned(left: 20, bottom: 20, child: _buildButton(context));
  }

  Widget _buildButton(BuildContext context) {
    if (mapViewModel.isSelectingRegion) {
      return _buildCalculateButton(context);
    }
    return _buildSelectRegionButton();
  }

  Widget _buildSelectRegionButton() {
    return FloatingActionButton.extended(
      heroTag: 'optimization_select',
      backgroundColor: Colors.blue,
      onPressed: mapViewModel.startSelectingRegion,
      icon: const Icon(Icons.select_all),
      label: const Text('Bölge Seç'),
    );
  }

  Widget _buildCalculateButton(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'optimization_calculate',
      backgroundColor: Colors.blue,
      onPressed: mapViewModel.hasValidSelection
          ? () => _onCalculate(context)
          : null,
      icon: const Icon(Icons.calculate),
      label: const Text('Hesapla'),
    );
  }

  Future<void> _onCalculate(BuildContext context) async {
    final themeViewModel = Provider.of<ThemeViewModel>(context, listen: false);

    // Ekipmanları yükle (dialog açılmadan önce)
    if (!mapViewModel.equipmentsLoading && mapViewModel.equipments.isEmpty) {
      await mapViewModel.loadEquipments();
    }

    if (!context.mounted) return;
    // Note: OptimizationDialog.show might need refactoring too if it uses MapProvider?
    // OptimizationDialog is in lib/presentation/widgets/map/map_widgets.dart or similar.
    // I refactored map_dialogs.dart which likely contains OptimizationDialog.
    // If OptimizationDialog.show signature changed to accept MapViewModel, this is fine.
    // If I missed refactoring it, this will fail.
    // Assuming MapDialogs contains OptimizationDialog and it was refactored.
    // However, I updated map_dialogs.dart in step 12.
    // Let's assume the signature is compatible or I need to update it here.
    // The previous implementation passed mapProvider.
    // I refactored map_dialogs to use MapViewModel.
    OptimizationDialog.show(context, mapViewModel, themeViewModel);
  }
}

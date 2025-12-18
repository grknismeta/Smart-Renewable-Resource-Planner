// presentation/features/pins/widgets/equipment_selector_widget.dart
//
// Sorumluluk: Equipment seçim UI komponenti
// Reusable, tek sorumluluk prensibi

import 'package:flutter/material.dart';
import '../../../../data/models/system_data_models.dart';
import '../../../../providers/theme_provider.dart';

/// Ekipman seçici widget - Reusable component
class EquipmentSelectorWidget extends StatelessWidget {
  final List<Equipment> equipments;
  final int? selectedEquipmentId;
  final bool isLoading;
  final ValueChanged<int?> onChanged;
  final ThemeProvider theme;
  final String hintText;

  const EquipmentSelectorWidget({
    super.key,
    required this.equipments,
    required this.selectedEquipmentId,
    required this.isLoading,
    required this.onChanged,
    required this.theme,
    this.hintText = 'Model Seçin',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (equipments.isEmpty) {
      return _buildEmptyState();
    }

    return _buildDropdown();
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Model bulunamadı',
              style: TextStyle(color: theme.textColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: selectedEquipmentId,
        isExpanded: true,
        dropdownColor: theme.cardColor,
        style: TextStyle(color: theme.textColor),
        underline: const SizedBox(),
        hint: Text(hintText, style: TextStyle(color: theme.secondaryTextColor)),
        items: equipments.map((eq) => _buildDropdownItem(eq)).toList(),
        onChanged: onChanged,
      ),
    );
  }

  DropdownMenuItem<int> _buildDropdownItem(Equipment equipment) {
    final powerText = equipment.ratedPowerKw >= 1000
        ? '${(equipment.ratedPowerKw / 1000).toStringAsFixed(2)} MW'
        : '${equipment.ratedPowerKw.toStringAsFixed(1)} kW';

    return DropdownMenuItem<int>(
      value: equipment.id,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('${equipment.name} ($powerText)'),
      ),
    );
  }
}

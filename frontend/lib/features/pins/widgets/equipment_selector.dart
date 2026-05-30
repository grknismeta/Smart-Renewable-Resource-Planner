// presentation/features/pins/widgets/equipment_selector_widget.dart
//
// Sorumluluk: Equipment seçim UI komponenti
// Reusable, tek sorumluluk prensibi
// 2026-05-17 — User-owned ekipmanlar için "Kendi modelim" rozeti +
// seçili user-owned ekipman için alt satırda "Düzenle" butonu eklendi.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/pins/widgets/edit_equipment_dialog.dart';

/// Ekipman seçici widget - Reusable component
class EquipmentSelectorWidget extends StatelessWidget {
  final List<Equipment> equipments;
  final int? selectedEquipmentId;
  final bool isLoading;
  final ValueChanged<int?> onChanged;
  final ThemeViewModel theme;
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

    // Seçili ekipman user-owned ise dropdown altında 'Düzenle' butonu göster
    Equipment? selectedEq;
    if (selectedEquipmentId != null) {
      for (final e in equipments) {
        if (e.id == selectedEquipmentId) { selectedEq = e; break; }
      }
    }
    final canEdit = selectedEq != null && selectedEq.isUserOwned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDropdown(),
        if (canEdit) ...[
          const SizedBox(height: 6),
          _buildEditRow(context, selectedEq),
        ],
      ],
    );
  }

  /// Seçili user-owned ekipman için "Düzenle" satırı. Tıklayınca dialog
  /// açılır (mevcut değerlerle seed edilir), kullanıcı düzenler veya siler.
  Widget _buildEditRow(BuildContext context, Equipment eq) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () async {
          final changed = await EditEquipmentDialog.show(context, eq);
          if (changed) {
            // Silindiyse selection'ı temizle (caller bunu yansıtır)
            // — equipments listesi MapViewModel listener üzerinden yenilenir,
            // PinDialogViewModel availableEquipments güncel döner.
            // Burada özellikle bir şey yapmamıza gerek yok; ama eğer
            // seçili id artık listede yoksa onChanged(null) iyi olur.
            final stillExists = equipments.any((e) => e.id == eq.id);
            if (!stillExists) onChanged(null);
          }
        },
        icon: Icon(Icons.tune_rounded, size: 16, color: Colors.lightBlueAccent),
        label: Text(
          'Bu modeli düzenle / sil',
          style: TextStyle(
            color: Colors.lightBlueAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
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

    // 2026-05-17 — Flutter web platform-view bug fix: dropdown overlay
    // Material global Overlay'a yerleşir, PinFlowOverlay'in PointerInterceptor
    // alanı dışında. Item'a tıklama altta MapLibre canvas'a bubble eder ve
    // pin konumunu değiştirir. Her item'ı PointerInterceptor ile sarmak
    // tıklamayı yutar, canvas'a inmez.
    return DropdownMenuItem<int>(
      value: equipment.id,
      child: PointerInterceptor(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${equipment.name} ($powerText)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (equipment.isUserOwned) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: Colors.lightBlueAccent.withValues(alpha: 0.5),
                        width: 0.5),
                  ),
                  child: const Text(
                    'KENDİM',
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

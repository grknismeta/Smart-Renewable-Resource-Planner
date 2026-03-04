import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/features/map/viewmodels/map_view_model.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/widgets/dialogs/map_dialogs.dart';

/// Optimizasyon hesaplaması dialog'u
class OptimizationDialog {
  OptimizationDialog._();

  static void show(
    BuildContext context,
    MapViewModel mapViewModel,
    ThemeViewModel theme,
  ) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _OptimizationDialogContent(mapViewModel: mapViewModel, theme: theme),
    );
  }
}

class _OptimizationDialogContent extends StatefulWidget {
  final MapViewModel mapViewModel;
  final ThemeViewModel theme;

  const _OptimizationDialogContent({
    required this.mapViewModel,
    required this.theme,
  });

  @override
  State<_OptimizationDialogContent> createState() =>
      _OptimizationDialogContentState();
}

class _OptimizationDialogContentState
    extends State<_OptimizationDialogContent> {
  int? selectedEquipmentId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWindEquipments();
    });
  }

  Future<void> _loadWindEquipments() async {
    // Mevcut rüzgar türbinlerini kontrol et
    final hasWind = widget.mapViewModel.equipments.any((e) => e.type == 'Wind');

    if (!hasWind) {
      await widget.mapViewModel.loadEquipments(type: 'Wind');
    }

    // Seçim yap
    if (mounted) {
      final windEquipments = widget.mapViewModel.equipments
          .where((e) => e.type == 'Wind')
          .toList();

      if (windEquipments.isNotEmpty) {
        setState(() {
          selectedEquipmentId = windEquipments.first.id;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final windEquipments = widget.mapViewModel.equipments
        .where((e) => e.type == 'Wind')
        .toList();

    // Ensure selectedId corresponds to an actual equipment in the list
    if (selectedEquipmentId != null && !windEquipments.any((e) => e.id == selectedEquipmentId)) {
      selectedEquipmentId = null;
    }

    if (selectedEquipmentId == null && windEquipments.isNotEmpty) {
      selectedEquipmentId = windEquipments.first.id;
    }

    return AlertDialog(
      backgroundColor: widget.theme.cardColor,
      title: Row(
        children: [
          const Icon(Icons.calculate, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(child: Text('Rüzgar Yerleşimi Hesapla')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seçilen Bölge:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.theme.textColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.mapViewModel.selectionPoints.length} Köşe Seçildi:',
                    style: TextStyle(
                      color: widget.theme.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...List.generate(
                    widget.mapViewModel.selectionPoints.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: _buildCoordRow(
                        'Köşe ${index + 1}',
                        widget.mapViewModel.selectionPoints[index],
                        widget.theme,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Türbin Modeli:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.theme.textColor,
                    fontSize: 14,
                  ),
                ),
                if (widget.mapViewModel.isEquipmentLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: selectedEquipmentId,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.theme.cardColor.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              items: windEquipments
                  .map((e) => e.id)
                  .toSet() // Ensure unique IDs
                  .map((id) {
                    final e = windEquipments.firstWhere((element) => element.id == id);
                    return DropdownMenuItem<int>(
                      value: e.id,
                      child: Text(
                        '${e.name} • ${e.ratedPowerKw.toStringAsFixed(0)} kW',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  })
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (val) {
                      setState(() {
                        selectedEquipmentId = val;
                      });
                    },
            ),
            if (windEquipments.isEmpty &&
                !widget.mapViewModel.isEquipmentLoading)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Uygun rüzgar türbini bulunamadı.',
                  style: TextStyle(color: Colors.orange.shade400, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading 
              ? null 
              : () {
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                },
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading
              ? null
              : () async {
                  if (selectedEquipmentId == null) {
                    MapDialogs.showErrorDialog(
                      context,
                      'Lütfen bir türbin seçin.',
                    );
                    return;
                  }

                  setState(() {
                    _isLoading = true;
                  });

                  try {
                    await widget.mapViewModel.calculateOptimization(
                      equipmentId: selectedEquipmentId!,
                    );
                    if (context.mounted) {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Optimizasyon tamamlandı! ${widget.mapViewModel.optimizationResult?.turbineCount ?? 0} türbin yerleştirildi.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                      MapDialogs.showErrorDialog(context, 'Hata: $e');
                    }
                  }
                },
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.check),
          label: Text(_isLoading ? 'Hesaplanıyor...' : 'Hesapla'),
        ),
      ],
    );
  }

  Widget _buildCoordRow(String label, LatLng? coord, ThemeViewModel theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
        Expanded(
          child: Text(
            coord != null
                ? '${coord.latitude.toStringAsFixed(4)}, ${coord.longitude.toStringAsFixed(4)}'
                : '-',
            style: TextStyle(color: theme.textColor, fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

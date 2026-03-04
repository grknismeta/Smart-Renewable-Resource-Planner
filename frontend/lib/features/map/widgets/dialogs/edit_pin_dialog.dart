import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/viewmodels/map_view_model.dart';
import 'package:frontend/features/map/widgets/map_constants.dart';
import 'package:frontend/features/pins/viewmodels/pin_dialog_viewmodel.dart';

import 'package:frontend/core/widgets/themed_inputs.dart';
import 'package:frontend/features/pins/widgets/equipment_selector.dart';
import 'package:frontend/features/map/widgets/dialogs/map_dialogs.dart'; // For error/calculation dialogs

class EditPinDialog extends StatefulWidget {
  final Pin pin;

  const EditPinDialog({super.key, required this.pin});

  static void show(BuildContext context, Pin pin) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Let content duplicate theme color
      builder: (_) => EditPinDialog(pin: pin),
    );

    if (result is PinCalculationResponse && context.mounted) {
      debugPrint("EditPinDialog: Got result, showing AnalysisDialog");
      final theme = Provider.of<ThemeViewModel>(context, listen: false);
      try {
        MapDialogs.showCalculationResultDialog(context, result, theme);
      } catch (e) {
        debugPrint("EditPinDialog: Error showing dialog: $e");
      }
    } else {
      debugPrint(
        "EditPinDialog: No result or context unmounted. Result type: ${result.runtimeType}",
      );
    }
  }

  @override
  State<EditPinDialog> createState() => _EditPinDialogState();
}

class _EditPinDialogState extends State<EditPinDialog> {
  late PinDialogViewModel _viewModel;
  late TextEditingController _nameController;
  late TextEditingController _panelAreaController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pin.name);
    _panelAreaController = TextEditingController(
      text: widget.pin.panelArea?.toStringAsFixed(1) ?? "100.0",
    );

    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    _viewModel = PinDialogViewModel(
      mapViewModel,
      widget.pin.type,
      initialEquipmentId: widget.pin.equipmentId,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadInitialData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _panelAreaController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final iconColor = MapConstants.getForegroundColor(widget.pin.type);
    final bgColor = MapConstants.getBackgroundColor(widget.pin.type);
    final iconData = MapConstants.getIcon(widget.pin.type);

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<PinDialogViewModel>(
        builder: (context, viewModel, child) {
          return Container(
            color: theme.cardColor,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header Info ---
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: iconColor, width: 2),
                        ),
                        child: Icon(iconData, color: iconColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kaynak İşlemleri',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor,
                            ),
                          ),
                          Text(
                            'ID: ${widget.pin.id}',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Yıllık Potansiyel: ${widget.pin.avgSolarIrradiance?.toStringAsFixed(2) ?? 'N/A'} kWh/m²',
                    style: TextStyle(color: theme.textColor),
                  ),
                  Divider(
                    color: theme.secondaryTextColor.withValues(alpha: 0.2),
                    height: 24,
                  ),

                  // --- Inputs ---
                  ThemedTextField(
                    controller: _nameController,
                    label: 'Kaynak Adı',
                    theme: theme,
                  ),
                  const SizedBox(height: 16),

                  ThemedDropdown<String>(
                    value: viewModel.selectedType,
                    label: 'Kaynak Tipi',
                    theme: theme,
                    items: ['Güneş Paneli', 'Rüzgar Türbini']
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t,
                              style: TextStyle(color: theme.textColor),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) viewModel.changeType(val);
                    },
                  ),
                  const SizedBox(height: 16),

                  EquipmentSelectorWidget(
                    equipments: viewModel.availableEquipments,
                    selectedEquipmentId: viewModel.selectedEquipmentId,
                    isLoading: viewModel.isLoadingEquipments,
                    onChanged: (id) {
                      if (id != null) viewModel.selectEquipment(id);
                    },
                    theme: theme,
                  ),

                  if (viewModel.selectedType == 'Güneş Paneli') ...[
                    const SizedBox(height: 16),
                    ThemedTextField(
                      controller: _panelAreaController,
                      label: 'Panel Alanı (m²)',
                      theme: theme,
                      isNumber: true,
                    ),
                  ],

                  if (viewModel.isSubmitting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const SizedBox(height: 24),

                  // --- Actions ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _handleDelete(context),
                      ),

                      Row(
                        children: [
                          // Save Button
                          OutlinedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Kaydet'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                            onPressed: viewModel.canSubmit
                                ? () => _handleUpdate(context, viewModel)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          // Calculate Button
                          ElevatedButton.icon(
                            icon: const Icon(Icons.calculate),
                            label: const Text('Hesapla'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: viewModel.canSubmit
                                ? () => _handleCalculate(context, viewModel)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Silinsin mi?"),
        content: const Text("Bu kaynağı silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
      try {
        await mapViewModel.deletePin(widget.pin.id);
        if (context.mounted) Navigator.pop(context); // Close bottom sheet
      } catch (e) {
        if (context.mounted) MapDialogs.showErrorDialog(context, e.toString());
      }
    }
  }

  Future<void> _performUpdate(
    BuildContext context,
    PinDialogViewModel viewModel,
  ) async {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final capacityMw = viewModel.getSelectedCapacityMw();

    if (capacityMw == null) throw Exception("Kapasite seçilmedi");

    await mapViewModel.updatePin(
      widget.pin.id,
      LatLng(widget.pin.latitude, widget.pin.longitude),
      _nameController.text,
      viewModel.selectedType,
      capacityMw,
      viewModel.selectedEquipmentId,
      double.tryParse(_panelAreaController.text),
    );
  }

  Future<void> _handleUpdate(
    BuildContext context,
    PinDialogViewModel viewModel,
  ) async {
    try {
      await _performUpdate(context, viewModel);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kaynak güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) MapDialogs.showErrorDialog(context, e.toString());
    }
  }

  Future<void> _handleCalculate(
    BuildContext context,
    PinDialogViewModel viewModel,
  ) async {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);

    try {
      // 1. Önce güncellemeyi yap (Pop etmeden)
      await _performUpdate(context, viewModel);

      // 2. Kapasite bilgisini tekrar al
      final capacityMw = viewModel.getSelectedCapacityMw();
      if (capacityMw == null) return;

      // 3. Hesaplamayı başlat
      await mapViewModel.calculatePotential(
        lat: widget.pin.latitude,
        lon: widget.pin.longitude,
        type: viewModel.selectedType,
        capacityMw: capacityMw,
        panelArea: double.tryParse(_panelAreaController.text) ?? 0.0,
      );

      // 4. Sonuç varsa dialogu kapat ve sonucu dön
      if (mapViewModel.latestCalculationResult != null && context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(mapViewModel.latestCalculationResult);
        }
      }
    } catch (e) {
      if (context.mounted) MapDialogs.showErrorDialog(context, e.toString());
    }
  }
}

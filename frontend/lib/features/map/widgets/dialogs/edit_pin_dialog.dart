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
import 'package:frontend/features/map/widgets/dialogs/map_dialogs.dart';

class EditPinDialog extends StatefulWidget {
  final Pin pin;

  const EditPinDialog({super.key, required this.pin});

  static void show(BuildContext context, Pin pin) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

  // HES alanları
  late TextEditingController _headHeightController;
  late TextEditingController _flowRateController;
  late TextEditingController _basinAreaController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pin.name);
    _panelAreaController = TextEditingController(
      text: widget.pin.panelArea?.toStringAsFixed(1) ?? "100.0",
    );
    _headHeightController = TextEditingController(
      text: widget.pin.headHeight?.toStringAsFixed(1) ?? '',
    );
    _flowRateController = TextEditingController(
      text: widget.pin.flowRate?.toStringAsFixed(3) ?? '',
    );
    _basinAreaController = TextEditingController(
      text: widget.pin.basinAreaKm2?.toStringAsFixed(1) ?? '',
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
    _headHeightController.dispose();
    _flowRateController.dispose();
    _basinAreaController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final iconColor = MapConstants.getForegroundColor(widget.pin.type);
    final bgColor = MapConstants.getBackgroundColor(widget.pin.type);
    final iconData = MapConstants.getIcon(widget.pin.type);
    final isHes = widget.pin.type == 'Hidroelektrik';

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
                  // --- Header ---
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
                            widget.pin.type,
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Koordinat bilgisi
                  Text(
                    '${widget.pin.latitude.toStringAsFixed(4)}, ${widget.pin.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                  Divider(
                    color: theme.secondaryTextColor.withValues(alpha: 0.2),
                    height: 24,
                  ),

                  // --- Ad ---
                  ThemedTextField(
                    controller: _nameController,
                    label: 'Kaynak Adı',
                    theme: theme,
                  ),
                  const SizedBox(height: 16),

                  // --- Tip Seçimi (HES için sabit göster, değiştirme) ---
                  if (!isHes) ...[
                    ThemedDropdown<String>(
                      value: viewModel.selectedType,
                      label: 'Kaynak Tipi',
                      theme: theme,
                      items: ['Güneş Paneli', 'Rüzgar Türbini', 'Hidroelektrik']
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
                  ],

                  // --- HES Alanları ---
                  if (viewModel.selectedType == 'Hidroelektrik') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.water_drop, color: Colors.teal, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'HES Parametreleri',
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ThemedTextField(
                            controller: _headHeightController,
                            label: 'Düşü Yüksekliği (m)',
                            isNumber: true,
                            theme: theme,
                          ),
                          const SizedBox(height: 10),
                          ThemedTextField(
                            controller: _flowRateController,
                            label: 'Debi (m³/s)',
                            isNumber: true,
                            theme: theme,
                          ),
                          const SizedBox(height: 10),
                          ThemedTextField(
                            controller: _basinAreaController,
                            label: 'Havza Alanı (km²)',
                            isNumber: true,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- Güneş Panel Alanı ---
                  if (viewModel.selectedType == 'Güneş Paneli') ...[
                    ThemedTextField(
                      controller: _panelAreaController,
                      label: 'Panel Alanı (m²)',
                      theme: theme,
                      isNumber: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- Ekipman Seçici (Sadece Güneş ve Rüzgar için) ---
                  if (viewModel.selectedType != 'Hidroelektrik') ...[
                    EquipmentSelectorWidget(
                      equipments: viewModel.availableEquipments,
                      selectedEquipmentId: viewModel.selectedEquipmentId,
                      isLoading: viewModel.isLoadingEquipments,
                      onChanged: (id) {
                        if (id != null) viewModel.selectEquipment(id);
                      },
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (viewModel.isSubmitting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const SizedBox(height: 8),

                  // --- Aksiyonlar ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _handleDelete(context),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Kaydet'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                            onPressed: () => _handleUpdate(context, viewModel),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.calculate),
                            label: const Text('Hesapla'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _handleCalculate(context, viewModel),
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
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) MapDialogs.showErrorDialog(context, e.toString());
      }
    }
  }

  Future<void> _performUpdate(BuildContext context, PinDialogViewModel viewModel) async {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final isHes = viewModel.selectedType == 'Hidroelektrik';

    double capacityMw;
    if (isHes) {
      capacityMw = viewModel.getSelectedCapacityMw() ?? widget.pin.capacityMw;
    } else {
      final cap = viewModel.getSelectedCapacityMw();
      if (cap == null) throw Exception("Lütfen bir ekipman modeli seçin.");
      capacityMw = cap;
    }

    final headHeight = double.tryParse(_headHeightController.text.trim());
    final flowRate = double.tryParse(_flowRateController.text.trim());
    final basinArea = double.tryParse(_basinAreaController.text.trim());

    await mapViewModel.updatePin(
      widget.pin.id,
      LatLng(widget.pin.latitude, widget.pin.longitude),
      _nameController.text,
      viewModel.selectedType,
      capacityMw,
      isHes ? null : viewModel.selectedEquipmentId,
      isHes ? null : double.tryParse(_panelAreaController.text),
      flowRate: flowRate,
      headHeight: headHeight,
      basinAreaKm2: basinArea,
    );
  }

  Future<void> _handleUpdate(BuildContext context, PinDialogViewModel viewModel) async {
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

  Future<void> _handleCalculate(BuildContext context, PinDialogViewModel viewModel) async {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final isHes = viewModel.selectedType == 'Hidroelektrik';

    try {
      await _performUpdate(context, viewModel);

      final capacityMw = isHes
          ? (viewModel.getSelectedCapacityMw() ?? widget.pin.capacityMw)
          : (viewModel.getSelectedCapacityMw() ?? 0.0);

      await mapViewModel.calculatePotential(
        lat: widget.pin.latitude,
        lon: widget.pin.longitude,
        type: viewModel.selectedType,
        capacityMw: capacityMw,
        panelArea: double.tryParse(_panelAreaController.text) ?? 0.0,
        flowRate: double.tryParse(_flowRateController.text.trim()),
        headHeight: double.tryParse(_headHeightController.text.trim()),
        basinAreaKm2: double.tryParse(_basinAreaController.text.trim()),
      );

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

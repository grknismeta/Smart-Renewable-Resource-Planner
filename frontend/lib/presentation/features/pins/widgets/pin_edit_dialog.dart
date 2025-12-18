// presentation/features/pins/widgets/pin_edit_dialog.dart
//
// Sorumluluk: Pin edit dialog UI - Sadeleştirilmiş, ViewModel kullanıyor

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/pin_model.dart';
import '../../../../providers/map_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../viewmodels/pin_dialog_viewmodel.dart';
import 'equipment_selector_widget.dart';
import '../../../widgets/map/map_constants.dart';

/// Pin düzenleme dialog'u - ViewModel pattern ile sadeleştirilmiş
class PinEditDialog extends StatefulWidget {
  final Pin pin;

  const PinEditDialog({super.key, required this.pin});

  @override
  State<PinEditDialog> createState() => _PinEditDialogState();
}

class _PinEditDialogState extends State<PinEditDialog> {
  late PinDialogViewModel _viewModel;
  late TextEditingController _nameController;
  late TextEditingController _panelAreaController;

  @override
  void initState() {
    super.initState();
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    _viewModel = PinDialogViewModel(
      mapProvider,
      widget.pin.type,
      initialEquipmentId: widget.pin.equipmentId,
    );

    _nameController = TextEditingController(text: widget.pin.name);
    _panelAreaController = TextEditingController(
      text: widget.pin.panelArea?.toStringAsFixed(1) ?? "100.0",
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _nameController.dispose();
    _panelAreaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: _buildDialog(context, theme, mapProvider),
    );
  }

  Widget _buildDialog(
    BuildContext context,
    ThemeProvider theme,
    MapProvider mapProvider,
  ) {
    return Consumer<PinDialogViewModel>(
      builder: (context, vm, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 10),
                _buildInfo(theme),
                const Divider(height: 24),
                _buildNameField(theme),
                const SizedBox(height: 16),
                _buildTypeSelector(vm, theme),
                const SizedBox(height: 16),
                _buildEquipmentSelector(vm, theme),
                if (vm.selectedType == 'Güneş Paneli') ...[
                  const SizedBox(height: 16),
                  _buildPanelAreaField(theme),
                ],
                if (vm.hasError) _buildErrorMessage(vm, theme),
                if (mapProvider.isLoading) _buildLoadingIndicator(),
                const SizedBox(height: 20),
                _buildActions(vm, mapProvider, theme),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    final iconColor = MapConstants.getForegroundColor(widget.pin.type);
    final bgColor = MapConstants.getBackgroundColor(widget.pin.type);
    final iconData = MapConstants.getIcon(widget.pin.type);

    return Row(
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
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfo(ThemeProvider theme) {
    return Text(
      'Yıllık Potansiyel: ${widget.pin.avgSolarIrradiance?.toStringAsFixed(2) ?? 'N/A'} kWh/m²',
      style: TextStyle(color: theme.textColor),
    );
  }

  Widget _buildNameField(ThemeProvider theme) {
    return TextField(
      controller: _nameController,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        labelText: 'Kaynak Adı',
        labelStyle: TextStyle(color: theme.secondaryTextColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.secondaryTextColor.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(PinDialogViewModel vm, ThemeProvider theme) {
    return DropdownButtonFormField<String>(
      value: vm.selectedType,
      dropdownColor: theme.cardColor,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        labelText: 'Kaynak Tipi',
        labelStyle: TextStyle(color: theme.secondaryTextColor),
      ),
      items: [
        'Güneş Paneli',
        'Rüzgar Türbini',
      ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (val) => val != null ? vm.changeType(val) : null,
    );
  }

  Widget _buildEquipmentSelector(PinDialogViewModel vm, ThemeProvider theme) {
    return EquipmentSelectorWidget(
      equipments: vm.availableEquipments,
      selectedEquipmentId: vm.selectedEquipmentId,
      isLoading: vm.isLoadingEquipments,
      onChanged: (id) => id != null ? vm.selectEquipment(id) : null,
      theme: theme,
    );
  }

  Widget _buildPanelAreaField(ThemeProvider theme) {
    return TextField(
      controller: _panelAreaController,
      style: TextStyle(color: theme.textColor),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Panel Alanı (m²)',
        labelStyle: TextStyle(color: theme.secondaryTextColor),
      ),
    );
  }

  Widget _buildErrorMessage(PinDialogViewModel vm, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        vm.errorMessage!,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildActions(
    PinDialogViewModel vm,
    MapProvider mapProvider,
    ThemeProvider theme,
  ) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () async {
            Navigator.of(context).pop();
            await mapProvider.deletePin(widget.pin.id);
          },
        ),
        const Spacer(),
        ElevatedButton.icon(
          icon: const Icon(Icons.calculate),
          label: const Text('Hesapla'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: vm.canSubmit ? () => _onCalculate(vm, mapProvider) : null,
        ),
      ],
    );
  }

  Future<void> _onCalculate(
    PinDialogViewModel vm,
    MapProvider mapProvider,
  ) async {
    final success = await vm.calculatePotential(
      lat: widget.pin.latitude,
      lon: widget.pin.longitude,
      panelArea: double.tryParse(_panelAreaController.text) ?? 0.0,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      // Show result dialog - implement elsewhere
    }
  }
}

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../data/models/pin_model.dart';
import '../../../data/models/system_data_models.dart';
import '../../../presentation/viewmodels/map_view_model.dart';
import '../../../presentation/viewmodels/theme_view_model.dart';
import 'energy_output_widget.dart';
import 'map_constants.dart';

/// Pin ile ilgili tüm dialog işlemlerini yöneten yardımcı sınıf
class MapDialogs {
  MapDialogs._();

  /// Hata dialog'u gösterir
  static void showErrorDialog(BuildContext context, String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Pin aksiyonları için bottom sheet gösterir
  static void showPinActionsDialog(BuildContext context, Pin pin) {
    // MapViewModel ve ThemeViewModel kullanımı
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final themeViewModel = Provider.of<ThemeViewModel>(context, listen: false);
    final nameController = TextEditingController(text: pin.name);
    final panelAreaController = TextEditingController(
      text: pin.panelArea?.toStringAsFixed(1) ?? "100.0",
    );
    String selectedType = pin.type;
    int? selectedEquipmentId = pin.equipmentId;

    // Equipment tipine göre determiner
    String getEquipmentType(String pinType) {
      return pinType == 'Güneş Paneli' ? 'Solar' : 'Wind';
    }

    final iconColor = MapConstants.getForegroundColor(pin.type);
    final bgColor = MapConstants.getBackgroundColor(pin.type);
    final iconData = MapConstants.getIcon(pin.type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: themeViewModel.cardColor,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setStateSB) {
            final isCalculating = mapViewModel.isBusy; // isLoading -> isBusy
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                color: themeViewModel.textColor,
                              ),
                            ),
                            Text(
                              'ID: ${pin.id}',
                              style: TextStyle(
                                color: themeViewModel.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Yıllık Potansiyel: ${pin.avgSolarIrradiance?.toStringAsFixed(2) ?? 'N/A'} kWh/m²',
                      style: TextStyle(color: themeViewModel.textColor),
                    ),
                    Divider(
                      color: themeViewModel.secondaryTextColor.withValues(
                        alpha: 0.2,
                      ),
                      height: 24,
                    ),
                    _buildTextField(
                      nameController,
                      'Kaynak Adı',
                      themeViewModel,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: themeViewModel.cardColor,
                      style: TextStyle(color: themeViewModel.textColor),
                      decoration: _inputDecoration(
                        'Kaynak Tipi',
                        themeViewModel,
                      ),
                      items: ['Güneş Paneli', 'Rüzgar Türbini']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setStateSB(() {
                            selectedType = newValue;
                            selectedEquipmentId =
                                null; // Type değişince modeli reset et
                            final equipmentType = getEquipmentType(
                              selectedType,
                            );
                            mapViewModel.loadEquipments(
                              type: equipmentType,
                              forceRefresh: true,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Consumer<MapViewModel>(
                      builder: (context, viewModel, _) {
                        final equipmentType = getEquipmentType(selectedType);

                        // Build sırasında setState çağrılmaması için post-frame callback kullan
                        if (viewModel.equipments.isEmpty &&
                            !viewModel.equipmentsLoading) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            viewModel.loadEquipments(type: equipmentType);
                          });
                        }

                        final filteredEquipments = viewModel.equipments
                            .where((e) => e.type == equipmentType)
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (viewModel.equipmentsLoading)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(
                                  height: 40,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            else if (filteredEquipments.isEmpty)
                              Text(
                                'Model bulunamadı',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: themeViewModel.secondaryTextColor
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<int>(
                                  value: selectedEquipmentId,
                                  isExpanded: true,
                                  dropdownColor: themeViewModel.cardColor,
                                  style: TextStyle(
                                    color: themeViewModel.textColor,
                                  ),
                                  underline: const SizedBox(),
                                  hint: Text(
                                    'Model Seçin',
                                    style: TextStyle(
                                      color: themeViewModel.secondaryTextColor,
                                    ),
                                  ),
                                  items: filteredEquipments
                                      .map(
                                        (eq) => DropdownMenuItem<int>(
                                          value: eq.id,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Text(
                                              '${eq.name} (${eq.ratedPowerKw >= 1000 ? (eq.ratedPowerKw / 1000).toStringAsFixed(2) : eq.ratedPowerKw.toStringAsFixed(1)} ${eq.ratedPowerKw >= 1000 ? 'MW' : 'kW'})',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      setStateSB(
                                        () => selectedEquipmentId = newValue,
                                      );
                                    }
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (selectedType == 'Güneş Paneli') ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        panelAreaController,
                        'Panel Alanı (m²)',
                        themeViewModel,
                        isNumber: true,
                      ),
                    ],
                    if (isCalculating)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            try {
                              await mapViewModel.deletePin(pin.id);
                            } catch (e) {
                              showErrorDialog(context, e.toString());
                            }
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
                          onPressed: () async {
                            if (isCalculating) return;
                            if (selectedEquipmentId == null) {
                              showErrorDialog(
                                context,
                                'Lütfen bir model seçin',
                              );
                              return;
                            }
                            setStateSB(() {});
                            try {
                              // Seçilen equipment'ı bul
                              final equipment = mapViewModel.equipments
                                  .firstWhere(
                                    (e) => e.id == selectedEquipmentId,
                                  );
                              final capacityMw = equipment.ratedPowerKw / 1000;

                              await mapViewModel.calculatePotential(
                                lat: pin.latitude,
                                lon: pin.longitude,
                                type: selectedType,
                                capacityMw: capacityMw,
                                panelArea:
                                    double.tryParse(panelAreaController.text) ??
                                    0.0,
                              );
                              Navigator.of(ctx).pop();
                              if (mapViewModel.latestCalculationResult !=
                                  null) {
                                showCalculationResultDialog(
                                  context,
                                  mapViewModel.latestCalculationResult!,
                                  themeViewModel,
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                showErrorDialog(ctx, e.toString());
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Yeni pin ekleme dialog'u gösterir
  static void showAddPinDialog(
    BuildContext context,
    LatLng point,
    String pinType,
  ) {
    final themeViewModel = Provider.of<ThemeViewModel>(context, listen: false);
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final nameController = TextEditingController(text: 'Yeni Kaynak');
    String selectedType = pinType;
    int? selectedEquipmentId;

    // Başlangıçta equipment'ları yükle
    final initialType = selectedType == 'Güneş Paneli' ? 'Solar' : 'Wind';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mapViewModel.loadEquipments(type: initialType);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Consumer<MapViewModel>(
        builder: (context, viewModel, child) {
          return StatefulBuilder(
            builder: (sbContext, setStateSB) {
              final activeType = selectedType == 'Güneş Paneli'
                  ? 'Solar'
                  : 'Wind';
              final availableEquipments = viewModel.equipments
                  .where((e) => e.type == activeType)
                  .toList();

              Equipment? selectedEquipment;
              if (selectedEquipmentId != null) {
                try {
                  selectedEquipment = availableEquipments.firstWhere(
                    (e) => e.id == selectedEquipmentId,
                  );
                } catch (_) {}
              }

              return Dialog(
                backgroundColor: themeViewModel.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                insetPadding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Header ---
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    (selectedType == 'Güneş Paneli'
                                            ? Colors.orange
                                            : Colors.blue)
                                        .withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                selectedType == 'Güneş Paneli'
                                    ? Icons.wb_sunny
                                    : Icons.wind_power,
                                color: selectedType == 'Güneş Paneli'
                                    ? Colors.orange
                                    : Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Yeni Kaynak Ekle',
                                style: TextStyle(
                                  color: themeViewModel.textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: themeViewModel.secondaryTextColor,
                              ),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // --- Location Info ---
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: themeViewModel.backgroundColor.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeViewModel.secondaryTextColor
                                  .withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: themeViewModel.secondaryTextColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  color: themeViewModel.secondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- Name Input ---
                        _buildTextField(
                          nameController,
                          'Kaynak Adı',
                          themeViewModel,
                        ),
                        const SizedBox(height: 20),

                        // --- Type Selector (Segmented) ---
                        _buildModernTypeSelector(themeViewModel, selectedType, (
                          val,
                        ) {
                          setStateSB(() {
                            selectedType = val;
                            selectedEquipmentId = null; // Reset selection
                            selectedEquipment = null;
                          });
                          // Load new equipments
                          final newType = val == 'Güneş Paneli'
                              ? 'Solar'
                              : 'Wind';
                          viewModel.loadEquipments(
                            type: newType,
                            forceRefresh: true,
                          );
                        }),
                        const SizedBox(height: 20),

                        // --- Equipment Selector Tile ---
                        Text(
                          selectedType == 'Güneş Paneli'
                              ? 'Panel Modeli'
                              : 'Türbin Modeli',
                          style: TextStyle(
                            color: themeViewModel.secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildEquipmentSelectorTile(
                          context: context,
                          theme: themeViewModel,
                          selectedEquipment: selectedEquipment,
                          isLoading: viewModel.isEquipmentLoading,
                          isEmpty: availableEquipments.isEmpty,
                          onTap: () {
                            if (viewModel.isEquipmentLoading ||
                                availableEquipments.isEmpty) {
                              return;
                            }
                            _showEquipmentPickerBottomSheet(
                              context,
                              themeViewModel,
                              availableEquipments,
                              (id) {
                                setStateSB(() => selectedEquipmentId = id);
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 32),

                        // --- Action Buttons ---
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: BorderSide(
                                    color: themeViewModel.secondaryTextColor
                                        .withValues(alpha: 0.3),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'İptal',
                                  style: TextStyle(
                                    color: themeViewModel.textColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: selectedEquipmentId == null
                                    ? null
                                    : () async {
                                        try {
                                          final selectedEq = availableEquipments
                                              .firstWhere(
                                                (e) =>
                                                    e.id == selectedEquipmentId,
                                              );
                                          final capacityMw =
                                              selectedEq.ratedPowerKw / 1000.0;

                                          await viewModel.addPin(
                                            point,
                                            nameController.text,
                                            selectedType,
                                            capacityMw,
                                            selectedEquipmentId,
                                          );
                                          if (dialogContext.mounted) {
                                            Navigator.of(dialogContext).pop();
                                          }
                                        } catch (e) {
                                          if (dialogContext.mounted) {
                                            showErrorDialog(
                                              dialogContext,
                                              e.toString(),
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Kaydet',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- Modern Helper Widgets ---

  static Widget _buildModernTypeSelector(
    ThemeViewModel theme,
    String currentType,
    Function(String) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          _buildSegmentButton(
            theme: theme,
            label: 'Güneş Paneli',
            icon: Icons.wb_sunny_outlined,
            isSelected: currentType == 'Güneş Paneli',
            onTap: () => onChanged('Güneş Paneli'),
            activeColor: Colors.orange,
          ),
          _buildSegmentButton(
            theme: theme,
            label: 'Rüzgar Türbini',
            icon: Icons.wind_power_outlined,
            isSelected: currentType == 'Rüzgar Türbini',
            onTap: () => onChanged('Rüzgar Türbini'),
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  static Widget _buildSegmentButton({
    required ThemeViewModel theme,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeColor : theme.secondaryTextColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? theme.textColor
                      : theme.secondaryTextColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildEquipmentSelectorTile({
    required BuildContext context,
    required ThemeViewModel theme,
    required Equipment? selectedEquipment,
    required bool isLoading,
    required bool isEmpty,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedEquipment != null
                ? Colors.blue.withValues(alpha: 0.5)
                : theme.secondaryTextColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: isLoading
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : isEmpty
                  ? Text(
                      'Uygun model bulunamadı',
                      style: TextStyle(color: Colors.orange),
                    )
                  : selectedEquipment != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedEquipment.name,
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selectedEquipment.ratedPowerKw >= 1000 ? (selectedEquipment.ratedPowerKw / 1000).toStringAsFixed(2) : selectedEquipment.ratedPowerKw.toStringAsFixed(1)} ${selectedEquipment.ratedPowerKw >= 1000 ? 'MW' : 'kW'}',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Model Seçiniz',
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
            ),
            Icon(Icons.keyboard_arrow_down, color: theme.secondaryTextColor),
          ],
        ),
      ),
    );
  }

  static void _showEquipmentPickerBottomSheet(
    BuildContext context,
    ThemeViewModel theme,
    List<Equipment> equipments,
    Function(int) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.secondaryTextColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Model Seçin',
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: equipments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final eq = equipments[index];
                      return InkWell(
                        onTap: () {
                          onSelected(eq.id);
                          Navigator.of(ctx).pop();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.backgroundColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.secondaryTextColor.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.bolt,
                                  color: theme.textColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      eq.name,
                                      style: TextStyle(
                                        color: theme.textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Güç: ${eq.ratedPowerKw >= 1000 ? (eq.ratedPowerKw / 1000).toStringAsFixed(2) : eq.ratedPowerKw.toStringAsFixed(1)} ${eq.ratedPowerKw >= 1000 ? 'MW' : 'kW'}',
                                      style: TextStyle(
                                        color: theme.secondaryTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: theme.secondaryTextColor,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Hesaplama sonucu dialog'u gösterir
  static void showCalculationResultDialog(
    BuildContext context,
    PinCalculationResponse result,
    ThemeViewModel theme,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern Enerji Çıktı Widget'ı
              EnergyOutputWidget(result: result, theme: theme),
              const SizedBox(height: 16),
              // Kapat butonu
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton.icon(
                  onPressed: () {
                    Provider.of<MapViewModel>(
                      context,
                      listen: false,
                    ).clearCalculationResult();
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Kapat'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Input decoration helper
  static InputDecoration _inputDecoration(String label, ThemeViewModel theme) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.secondaryTextColor),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: theme.secondaryTextColor.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue),
      ),
      filled: true,
      fillColor: theme.backgroundColor.withValues(alpha: 0.5),
    );
  }

  /// Text field builder helper
  static Widget _buildTextField(
    TextEditingController controller,
    String label,
    ThemeViewModel theme, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textColor),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: _inputDecoration(label, theme),
    );
  }
}
// --- YENİ: BÖLGE SEÇİM GÖSTERGESİ WIDGET'I ---

/// Bölge seçim işlemini gösterir ve kontrol sağlar (Çoklu Köşe Versiyonu)
class RegionSelectionIndicator extends StatelessWidget {
  final List<LatLng> points;
  final VoidCallback onCancel;

  const RegionSelectionIndicator({
    super.key,
    required this.points,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık ve İstatistik
          Row(
            children: [
              const Icon(Icons.select_all, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      points.length < 3
                          ? 'En az 3 köşe seçin (${points.length}/3+)'
                          : 'Bölge hazır! ${points.length} köşe seçildi.',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (points.isNotEmpty)
                      Text(
                        'Köşeleri sürükleyerek hareket ettirebilirsiniz',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                onPressed: onCancel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Köşe Noktaları Listesi
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    points.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildPointChip(
                        index + 1,
                        points[index],
                        theme,
                        () => mapViewModel.removeLastPoint(),
                        isLast: index == points.length - 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Kontrol Butonları
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => mapViewModel.removeLastPoint(),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Son Noktayı Sil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (points.length >= 3)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => mapViewModel.finishRegionSelection(),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Seçimi Bitir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildPointChip(
    int number,
    LatLng coord,
    ThemeViewModel theme,
    VoidCallback onDelete, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLast
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isLast
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.blue.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'K$number: ${coord.latitude.toStringAsFixed(3)}, ${coord.longitude.toStringAsFixed(3)}',
            style: TextStyle(color: theme.textColor, fontSize: 10),
          ),
          if (isLast) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onDelete,
              child: Icon(Icons.close, size: 14, color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }
}

// --- YENİ: OPTİMİZASYON DIALOG'U ---

/// Optimizasyon hesaplaması dialog'u
class OptimizationDialog {
  OptimizationDialog._();

  static void show(
    BuildContext context,
    MapViewModel mapViewModel,
    ThemeViewModel theme,
  ) {
    int? selectedEquipmentId;
    bool requestedEquipments = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setStateSB) {
            final isCalculating = mapViewModel.isBusy;
            final equipmentLoading = mapViewModel.isEquipmentLoading;
            final equipments = mapViewModel.equipments;

            if (!requestedEquipments &&
                !equipmentLoading &&
                equipments.isEmpty) {
              requestedEquipments = true;
              mapViewModel.loadEquipments().then((_) {
                if (dialogContext.mounted) setStateSB(() {});
              });
            }

            selectedEquipmentId ??= equipments.isNotEmpty
                ? equipments.first.id
                : null;

            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Row(
                children: [
                  const Icon(Icons.calculate, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Yerleşimi Hesapla')),
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
                        color: theme.textColor,
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
                            '${mapViewModel.selectionPoints.length} Köşe Seçildi:',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...List.generate(
                            mapViewModel.selectionPoints.length,
                            (index) => Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: _buildCoordRow(
                                'Köşe ${index + 1}',
                                mapViewModel.selectionPoints[index],
                                theme,
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
                          'Türbin/Panel Modeli:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                            fontSize: 14,
                          ),
                        ),
                        if (equipmentLoading)
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
                        fillColor: theme.cardColor.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      items: equipments
                          .map(
                            (e) => DropdownMenuItem<int>(
                              value: e.id,
                              child: Text(
                                '${e.name} (${e.type}) • ${e.ratedPowerKw.toStringAsFixed(0)} kW',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isCalculating
                          ? null
                          : (val) {
                              setStateSB(() {
                                selectedEquipmentId = val;
                              });
                            },
                    ),
                    if (equipments.isEmpty && !equipmentLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          'Ekipman bulunamadı, lütfen sistem yöneticisine danışın.',
                          style: TextStyle(
                            color: Colors.orange.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCalculating
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton.icon(
                  onPressed: isCalculating
                      ? null
                      : () async {
                          if (selectedEquipmentId == null) {
                            MapDialogs.showErrorDialog(
                              dialogContext,
                              'Lütfen bir ekipman seçin.',
                            );
                            return;
                          }

                          try {
                            await mapViewModel.calculateOptimization(
                              equipmentId: selectedEquipmentId!,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Optimizasyon tamamlandı! ${mapViewModel.optimizationResult?.turbineCount ?? 0} türbin yerleştirildi.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              MapDialogs.showErrorDialog(
                                dialogContext,
                                'Hata: $e',
                              );
                            }
                          }
                        },
                  icon: isCalculating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(isCalculating ? 'Hesaplanıyor...' : 'Hesapla'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildCoordRow(
    String label,
    LatLng? coord,
    ThemeViewModel theme,
  ) {
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

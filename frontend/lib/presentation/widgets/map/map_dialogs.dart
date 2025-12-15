import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../data/models/pin_model.dart';
import '../../../providers/map_provider.dart';
import '../../../providers/theme_provider.dart';
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
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final nameController = TextEditingController(text: pin.name);
    final capacityController = TextEditingController(
      text: pin.capacityMw.toStringAsFixed(1),
    );
    final panelAreaController = TextEditingController(
      text: pin.panelArea?.toStringAsFixed(1) ?? "100.0",
    );
    String selectedType = pin.type;

    final iconColor = MapConstants.getForegroundColor(pin.type);
    final bgColor = MapConstants.getBackgroundColor(pin.type);
    final iconData = MapConstants.getIcon(pin.type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setStateSB) {
            final isCalculating = mapProvider.isLoading;
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
                                color: theme.textColor,
                              ),
                            ),
                            Text(
                              'ID: ${pin.id}',
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
                      'Yıllık Potansiyel: ${pin.avgSolarIrradiance?.toStringAsFixed(2) ?? 'N/A'} kWh/m²',
                      style: TextStyle(color: theme.textColor),
                    ),
                    Divider(
                      color: theme.secondaryTextColor.withValues(alpha: 0.2),
                      height: 24,
                    ),
                    _buildTextField(nameController, 'Kaynak Adı', theme),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.textColor),
                      decoration: _inputDecoration('Kaynak Tipi', theme),
                      items: ['Güneş Paneli', 'Rüzgar Türbini']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (newValue) {
                        if (newValue != null)
                          setStateSB(() => selectedType = newValue);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      capacityController,
                      'Kapasite (MW)',
                      theme,
                      isNumber: true,
                    ),
                    if (selectedType == 'Güneş Paneli') ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        panelAreaController,
                        'Panel Alanı (m²)',
                        theme,
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
                              await mapProvider.deletePin(pin.id);
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
                            setStateSB(() {});
                            try {
                              await mapProvider.calculatePotential(
                                lat: pin.latitude,
                                lon: pin.longitude,
                                type: selectedType,
                                capacityMw:
                                    double.tryParse(capacityController.text) ??
                                    1.0,
                                panelArea:
                                    double.tryParse(panelAreaController.text) ??
                                    0.0,
                              );
                              Navigator.of(ctx).pop();
                              if (mapProvider.latestCalculationResult != null) {
                                showCalculationResultDialog(
                                  context,
                                  mapProvider.latestCalculationResult!,
                                  theme,
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted)
                                showErrorDialog(ctx, e.toString());
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
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final nameController = TextEditingController(text: 'Yeni Kaynak');
    final capacityController = TextEditingController(text: '1.0');
    String selectedType = pinType;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setStateSB) {
          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text(
              'Yeni ${selectedType == "Güneş Paneli" ? "Güneş Paneli" : "Rüzgar Türbini"} Ekle',
              style: TextStyle(color: theme.textColor),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Konum: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(nameController, 'Kaynak Adı', theme),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.textColor),
                    decoration: _inputDecoration('Kaynak Tipi', theme),
                    items: ['Güneş Paneli', 'Rüzgar Türbini']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setStateSB(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    capacityController,
                    'Kapasite (MW)',
                    theme,
                    isNumber: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await mapProvider.addPin(
                      point,
                      nameController.text,
                      selectedType,
                      double.tryParse(capacityController.text) ?? 1.0,
                    );
                    Navigator.of(ctx).pop();
                  } catch (e) {
                    showErrorDialog(context, e.toString());
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Hesaplama sonucu dialog'u gösterir
  static void showCalculationResultDialog(
    BuildContext context,
    PinCalculationResponse result,
    ThemeProvider theme,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          'Hesaplama Sonucu',
          style: TextStyle(color: theme.textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kaynak Tipi: ${result.resourceType}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            Divider(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
            if (result.solarCalculation != null) ...[
              _buildResultRow(
                'Anlık Güç',
                '${result.solarCalculation!.powerOutputKw.toStringAsFixed(2)} kW',
                theme,
              ),
              _buildResultRow(
                'Panel Verimi',
                '%${(result.solarCalculation!.panelEfficiency * 100).toStringAsFixed(1)}',
                theme,
              ),
              _buildResultRow(
                'Işınım',
                '${result.solarCalculation!.solarIrradianceKwM2.toStringAsFixed(3)} kW/m²',
                theme,
              ),
              _buildResultRow(
                'Sıcaklık',
                '${result.solarCalculation!.temperatureCelsius.toStringAsFixed(1)} °C',
                theme,
              ),
            ],
            if (result.windCalculation != null) ...[
              _buildResultRow(
                'Anlık Güç',
                '${result.windCalculation!.powerOutputKw.toStringAsFixed(2)} kW',
                theme,
              ),
              _buildResultRow(
                'Rüzgar Hızı',
                '${result.windCalculation!.windSpeedMS.toStringAsFixed(1)} m/s',
                theme,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Provider.of<MapProvider>(
                context,
                listen: false,
              ).clearCalculationResult();
              Navigator.of(ctx).pop();
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Input decoration helper
  static InputDecoration _inputDecoration(String label, ThemeProvider theme) {
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
    ThemeProvider theme, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textColor),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: _inputDecoration(label, theme),
    );
  }

  /// Result row builder helper
  static Widget _buildResultRow(
    String title,
    String value,
    ThemeProvider theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$title:', style: TextStyle(color: theme.secondaryTextColor)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

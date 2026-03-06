import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/features/pins/viewmodels/pin_dialog_viewmodel.dart';
import 'package:frontend/features/map/viewmodels/map_view_model.dart';

import 'package:frontend/core/widgets/themed_inputs.dart';
import 'package:frontend/features/pins/widgets/equipment_selector.dart';
import 'package:frontend/features/map/widgets/dialogs/map_dialog_base.dart';
import 'package:frontend/features/map/widgets/dialogs/map_dialogs.dart'; // For error dialog

class AddPinDialog extends StatefulWidget {
  final LatLng point;
  final String initialPinType;

  const AddPinDialog({
    super.key,
    required this.point,
    required this.initialPinType,
  });

  static void show(BuildContext context, LatLng point, String pinType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddPinDialog(point: point, initialPinType: pinType),
    );
  }

  @override
  State<AddPinDialog> createState() => _AddPinDialogState();
}

class _AddPinDialogState extends State<AddPinDialog> {
  late PinDialogViewModel _viewModel;
  late TextEditingController _nameController;
  late TextEditingController _headHeightController;
  late TextEditingController _flowRateController;
  late TextEditingController _basinAreaController;
  // İki Nokta Elevation Analizi
  late TextEditingController _intakeLatController;
  late TextEditingController _intakeLonController;
  Map<String, dynamic>? _elevationResult;
  bool _isCalculatingElevation = false;
  int? _selectedScenarioId;

  bool _isCheckingSuitability = true;
  bool _isSuitable = false;
  String _suitabilityMessage = "Konum analiz ediliyor...";
  List<String> _suitabilityReasons = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Yeni Kaynak');
    _headHeightController = TextEditingController();
    _flowRateController = TextEditingController();
    _basinAreaController = TextEditingController();
    _intakeLatController = TextEditingController();
    _intakeLonController = TextEditingController();
    
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    _viewModel = PinDialogViewModel(
      mapViewModel,
      widget.initialPinType,
    );

    // Load scenarios and initial equipments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScenarioViewModel>(context, listen: false).loadScenarios();
      _viewModel.loadInitialData();
      _checkSuitability();
    });
  }

  Future<void> _checkSuitability() async {
    setState(() {
      _isCheckingSuitability = true;
      _suitabilityMessage = "Konum analiz ediliyor...";
    });

    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final result = await mapViewModel.geoCheck(widget.point);

    if (!mounted) return;

    if (result != null) {
      // Geo devre dışıysa her pin tipi için izin ver
      final bool geoDisabled = result['geo_disabled'] == true;
      if (geoDisabled) {
        setState(() {
          _isCheckingSuitability = false;
          _isSuitable = true;
          _suitabilityMessage = "Coğrafya analizi devre dışı. Kuruluma izin veriliyor.";
          _suitabilityReasons = [];
        });
        return;
      }

      // Pin tipine göre uygunluğu belirle
      final pinType = _viewModel.selectedType;
      bool suitable;
      String message = result['recommendation'] ?? "";
      List<String> reasons = [];

      if (pinType == 'Hidroelektrik') {
        // HES: hydro_details'e bak
        final hydro = result['hydro_details'];
        suitable = hydro?['suitable'] ?? true;
        if (!suitable && hydro?['reasons'] != null) {
          for (var r in hydro['reasons']) {
            reasons.add("HES: $r");
          }
        }
        // Notları mesaj olarak ekle
        if (hydro?['notes'] != null && (hydro['notes'] as List).isNotEmpty) {
          message = (hydro['notes'] as List).first.toString();
        }
      } else {
        // Güneş / Rüzgar: genel suitable
        suitable = result['suitable'] ?? false;
        if (!suitable) {
          final solar = result['solar_details'];
          final wind = result['wind_details'];
          if (pinType == 'Güneş Paneli' && solar != null && solar['reasons'] != null) {
            for (var r in solar['reasons']) reasons.add("Güneş: $r");
          }
          if (pinType == 'Rüzgar Türbini' && wind != null && wind['reasons'] != null) {
            for (var r in wind['reasons']) reasons.add("Rüzgar: $r");
          }
          // Hiç neden yoksa solar+wind ikisini birden tara
          if (reasons.isEmpty) {
            if (solar?['reasons'] != null) for (var r in solar['reasons']) reasons.add("Güneş: $r");
            if (wind?['reasons'] != null) for (var r in wind['reasons']) reasons.add("Rüzgar: $r");
          }
        }
      }

      setState(() {
        _isCheckingSuitability = false;
        _isSuitable = suitable;
        _suitabilityMessage = message.isNotEmpty
            ? message
            : (suitable ? "Kurulum için uygun." : "Bu konuma kurulum yapılamaz.");
        _suitabilityReasons = reasons;
      });
    } else {
      setState(() {
        _isCheckingSuitability = false;
        _isSuitable = true; // Sunucuya ulaşılamazsa izin ver (offline-friendly)
        _suitabilityMessage = "Konum analizi atlandı. Kuruluma izin veriliyor.";
      });
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _headHeightController.dispose();
    _flowRateController.dispose();
    _basinAreaController.dispose();
    _intakeLatController.dispose();
    _intakeLonController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final scenarioVM = Provider.of<ScenarioViewModel>(context);

    // PinDialogViewModel ChangeNotifier olduğu için onu dinlememiz lazım.
    // Ancak _viewModel lokal olarak oluşturuldu.
    // ChangeNotifierProvider.value ile sarmalayabiliriz veya AnimatedBuilder kullanabiliriz.
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<PinDialogViewModel>(
        builder: (context, viewModel, child) {
          return Dialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    MapDialogHeader(
                      title: 'Yeni Kaynak Ekle',
                      icon: viewModel.selectedType == 'Güneş Paneli'
                          ? Icons.wb_sunny
                          : viewModel.selectedType == 'Hidroelektrik'
                              ? Icons.water_drop
                              : Icons.wind_power,
                      color: viewModel.selectedType == 'Güneş Paneli'
                          ? Colors.orange
                          : viewModel.selectedType == 'Hidroelektrik'
                              ? Colors.teal
                              : Colors.blue,
                      onClose: () => Navigator.of(context).pop(),
                      theme: theme,
                    ),
                    const SizedBox(height: 24),

                    // Location Info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.secondaryTextColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: theme.secondaryTextColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.point.latitude.toStringAsFixed(4)}, ${widget.point.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const SizedBox(height: 12),
                    // Suitability Status Widget
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isCheckingSuitability 
                            ? theme.cardColor 
                            : (_isSuitable ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isCheckingSuitability
                              ? theme.secondaryTextColor.withValues(alpha: 0.2)
                              : (_isSuitable ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5)),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_isCheckingSuitability)
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.secondaryTextColor))
                          else
                            Icon(
                              _isSuitable ? Icons.check_circle : Icons.error,
                              color: _isSuitable ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _suitabilityMessage,
                                  style: TextStyle(
                                    color: _isCheckingSuitability 
                                        ? theme.secondaryTextColor 
                                        : (_isSuitable ? Colors.green : Colors.red),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!_isCheckingSuitability && !_isSuitable && _suitabilityReasons.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  ..._suitabilityReasons.map((r) => Text(
                                    "• $r",
                                    style: TextStyle(color: theme.textColor, fontSize: 12),
                                  )),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name Input
                    ThemedTextField(
                      controller: _nameController,
                      label: 'Kaynak Adı',
                      theme: theme,
                    ),
                    const SizedBox(height: 20),

                    // Panel Area Input (Only for Solar)
                    if (viewModel.selectedType == 'Güneş Paneli') ...[
                      const SizedBox(height: 20),
                      ThemedTextField(
                        label: 'Panel Alanı (m²) - Örn: 10',
                        isNumber: true,
                        onChanged: (val) => viewModel.setPanelArea(val),
                        controller: TextEditingController(text: viewModel.panelArea.toString())
                          ..selection = TextSelection.fromPosition(
                             TextPosition(offset: viewModel.panelArea.toString().length),
                          ),
                        theme: theme,
                      ),
                    ],

                    // HES Input Fields (Only for Hidroelektrik)
                    if (viewModel.selectedType == 'Hidroelektrik') ...[
                      const SizedBox(height: 20),
                      ThemedTextField(
                        controller: _headHeightController,
                        label: 'Düşü Yüksekliği (m) *',
                        isNumber: true,
                        onChanged: (val) => viewModel.setHeadHeight(val),
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      ThemedTextField(
                        controller: _flowRateController,
                        label: 'Debi (m³/s) - Biliniyorsa',
                        isNumber: true,
                        onChanged: (val) => viewModel.setFlowRate(val),
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      ThemedTextField(
                        controller: _basinAreaController,
                        label: 'Havza Alanı (km²) - Yağıştan debi tahmini için',
                        isNumber: true,
                        onChanged: (val) => viewModel.setBasinArea(val),
                        theme: theme,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Debi veya Havza Alanından en az birini giriniz.',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // --- İKİ NOKTA RAKIM ANALİZİ ---
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.terrain, color: Colors.teal, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Otomatik Düşü Hesaplama',
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Su alma noktasının koordinatlarını girin. Mevcut pin konumu türbin noktası olarak kullanılacaktır.',
                              style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ThemedTextField(
                                    controller: _intakeLatController,
                                    label: 'Su Alma Enlem',
                                    isNumber: true,
                                    theme: theme,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ThemedTextField(
                                    controller: _intakeLonController,
                                    label: 'Su Alma Boylam',
                                    isNumber: true,
                                    theme: theme,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isCalculatingElevation ? null : () => _calculateElevation(theme),
                                icon: _isCalculatingElevation
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.calculate, size: 18),
                                label: Text(_isCalculatingElevation ? 'Hesaplanıyor...' : 'Rakım ve Düşü Hesapla'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            // Elevation Sonucu
                            if (_elevationResult != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  children: [
                                    _buildElevationRow('Su Alma Rakımı', '${_elevationResult!['intake_elevation_m']} m', theme),
                                    _buildElevationRow('Türbin Rakımı', '${_elevationResult!['turbine_elevation_m']} m', theme),
                                    _buildElevationRow('Brüt Düşü', '${_elevationResult!['gross_head_m']} m', theme, highlight: true),
                                    _buildElevationRow('Mesafe', '${_elevationResult!['distance_m']} m', theme),
                                    if (_elevationResult!['penstock'] != null) ...[
                                      const Divider(),
                                      _buildElevationRow('Boru Uzunluğu', '${_elevationResult!['penstock']['penstock_length_m']} m', theme),
                                      _buildElevationRow('Boru Maliyeti', '\$${_elevationResult!['penstock']['total_cost_usd']}', theme, highlight: true),
                                    ],
                                    if (_elevationResult!['suggested_turbine'] != null)
                                      _buildElevationRow('Önerilen Türbin', '${_elevationResult!['suggested_turbine']}', theme),
                                    if (_elevationResult!['warnings'] != null && (_elevationResult!['warnings'] as List).isNotEmpty)
                                      ...(_elevationResult!['warnings'] as List).map((w) => Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(w.toString(), style: const TextStyle(fontSize: 10, color: Colors.orange)),
                                      )),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Scenario Selector
                    ThemedDropdown<int?>(
                      value: _selectedScenarioId,
                      label: 'Senaryoya Ekle (Opsiyonel)',
                      theme: theme,
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            "Senaryoya ekleme",
                            style: TextStyle(color: theme.secondaryTextColor),
                          ),
                        ),
                        ...scenarioVM.scenarios.map(
                          (s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(
                              s.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.textColor),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedScenarioId = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Type Selector
                    _buildTypeSelector(theme, viewModel),
                    const SizedBox(height: 20),

                    // Equipment Selector
                    Text(
                      viewModel.selectedType == 'Güneş Paneli'
                          ? 'Panel Modeli'
                          : viewModel.selectedType == 'Hidroelektrik'
                              ? 'Türbin Tipi'
                              : 'Türbin Modeli',
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EquipmentSelectorWidget(
                      equipments: viewModel.availableEquipments,
                      selectedEquipmentId: viewModel.selectedEquipmentId,
                      isLoading: viewModel.isLoadingEquipments,
                      theme: theme,
                      onChanged: (id) {
                        if (id != null) viewModel.selectEquipment(id);
                      },
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    MapDialogActionButtons(
                      theme: theme,
                      onCancel: () => Navigator.of(context).pop(),
                      onSave: (viewModel.canSubmit && !_isCheckingSuitability && _isSuitable) ? () => _handleSave(context, viewModel) : null,
                      isSaving: viewModel.isSubmitting,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeSelector(ThemeViewModel theme, PinDialogViewModel viewModel) {
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
            label: 'Güneş',
            icon: Icons.wb_sunny_outlined,
            isSelected: viewModel.selectedType == 'Güneş Paneli',
            onTap: () => viewModel.changeType('Güneş Paneli'),
            activeColor: Colors.orange,
          ),
          _buildSegmentButton(
            theme: theme,
            label: 'Rüzgar',
            icon: Icons.wind_power_outlined,
            isSelected: viewModel.selectedType == 'Rüzgar Türbini',
            onTap: () => viewModel.changeType('Rüzgar Türbini'),
            activeColor: Colors.blue,
          ),
          _buildSegmentButton(
            theme: theme,
            label: 'HES',
            icon: Icons.water_drop_outlined,
            isSelected: viewModel.selectedType == 'Hidroelektrik',
            onTap: () => viewModel.changeType('Hidroelektrik'),
            activeColor: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
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
                  color: isSelected ? theme.textColor : theme.secondaryTextColor,
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

  // --- İKİ NOKTA RAKIM HESAPLAMA ---
  Future<void> _calculateElevation(ThemeViewModel theme) async {
    final intakeLatText = _intakeLatController.text.trim();
    final intakeLonText = _intakeLonController.text.trim();

    final intakeLat = double.tryParse(intakeLatText);
    final intakeLon = double.tryParse(intakeLonText);

    if (intakeLat == null || intakeLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli enlem ve boylam değerleri giriniz.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCalculatingElevation = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.resource.hydroElevationAnalysis(
        intakeLat: intakeLat,
        intakeLon: intakeLon,
        turbineLat: widget.point.latitude,
        turbineLon: widget.point.longitude,
        flowRate: _viewModel.flowRate > 0 ? _viewModel.flowRate : null,
      );

      if (!mounted) return;

      setState(() {
        _elevationResult = result;
        _isCalculatingElevation = false;
      });

      // Brüt düşüyü head_height alanına otomatik doldur
      final grossHead = result['gross_head_m'];
      if (grossHead != null && grossHead > 0) {
        _headHeightController.text = grossHead.toString();
        _viewModel.setHeadHeight(grossHead.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Düşü yüksekliği otomatik dolduruldu: $grossHead m'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCalculatingElevation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rakım hesaplanamadı: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildElevationRow(String label, String value, ThemeViewModel theme, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: theme.secondaryTextColor),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? Colors.teal : theme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave(BuildContext context, PinDialogViewModel viewModel) async {

    final validationError = viewModel.validate();
    if (validationError != null) {
      MapDialogs.showErrorDialog(context, validationError);
      return;
    }

    // Capacity calculation logic inside ViewModel or here? 
    // ViewModel has calculatePotential but addPin is in MapViewModel.
    // We should call MapViewModel.addPin here.
    
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final capacityMw = viewModel.getSelectedCapacityMw();
    
    if (capacityMw == null) return;

    try {
      // 1. Pini ekle
      final newPin = await mapViewModel.addPin(
        widget.point,
        _nameController.text,
        viewModel.selectedType,
        capacityMw,
        viewModel.selectedEquipmentId,
        viewModel.panelArea,
        flowRate: viewModel.flowRate,
        headHeight: viewModel.headHeight,
        basinAreaKm2: viewModel.basinAreaKm2,
      );

      // 2. Senaryo seçiliyse ona da ekle
      if (_selectedScenarioId != null && context.mounted) {
        await Provider.of<ApiService>(context, listen: false)
            .scenario
            .addPinsToScenario(_selectedScenarioId!, [newPin.id]);
        
        if (context.mounted) {
          Provider.of<ScenarioViewModel>(context, listen: false).loadScenarios();
        }
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kaynak başarıyla eklendi${_selectedScenarioId != null ? ' ve senaryoya dahil edildi' : ''}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        MapDialogs.showErrorDialog(context, e.toString());
      }
    }
  }
}

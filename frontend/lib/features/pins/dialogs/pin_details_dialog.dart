import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/viewmodels/map_view_model.dart';
import 'package:frontend/features/pins/viewmodels/pin_dialog_viewmodel.dart';
import 'package:frontend/features/pins/controllers/pin_flow_controller.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/features/reports/report_screen.dart' show createReportRoute;

import 'package:frontend/shared/widgets/themed_inputs.dart';
import 'package:frontend/features/pins/widgets/equipment_selector.dart';
import 'package:frontend/features/pins/widgets/energy_output_widget.dart';
import 'package:frontend/features/pins/widgets/pin_panel_shell.dart';
import 'package:frontend/features/pins/widgets/advanced_settings_panel.dart';


/// Pin Detail/Edit Bottom Card — V2 pattern (floating bottom card / mobile sheet).
///
/// 2026-05-08 — Eski `Dialog` + glass blur kaldırıldı. Artık map_screen
/// Stack overlay'i tarafından state-based render edilir; harita asla
/// bloklanmaz. Pin'e tıklayınca alt-orta'da floating card açılır, harita
/// arka planda görünür kalır. Düzenleme moduna girince aynı card içinde
/// form açılır (state in-place).
///
/// Web (≥600px): ortada-alta floating, max 460px width.
/// Mobile (<600px): tam genişlik bottom-anchored, drag handle.
class PinDetailsDialog extends StatefulWidget {
  final Pin pin;
  final VoidCallback onClose;
  // 2026-05-08 — Cross-sheet navigation (A.5).
  // Pin detay'dan senaryolar paneline geçiş için callback. Caller (map_screen)
  // ister `_closePinDetail()` + senaryo side panel'ini açar.
  final VoidCallback? onOpenScenarios;

  /// 2026-05-26 (K1): Floating draggable card için header drag callback'leri.
  /// PinFlowOverlay tarafından sağlanır; PinPanelShell'e iletilir.
  final ValueChanged<Offset>? onDragDelta;
  final VoidCallback? onDragEnd;

  const PinDetailsDialog({
    super.key,
    required this.pin,
    required this.onClose,
    this.onOpenScenarios,
    this.onDragDelta,
    this.onDragEnd,
  });

  @override
  State<PinDetailsDialog> createState() => _PinDetailsDialogState();
}

class _PinDetailsDialogState extends State<PinDetailsDialog> {
  bool _isEditing = false;
  late Pin _currentPin;
  bool _isAnalyzing = false;

  /// 2026-05-26 (N2): Edit mode "Kaydet" — updatePin + scenario + analyze
  /// zinciri ~3-5 sn. Spinner + disabled.
  bool _isSavingEdit = false;

  // Edit Mode State
  PinDialogViewModel? _editViewModel;
  late TextEditingController _nameController;
  TextEditingController? _panelAreaController;

  // 2026-05-17 Sprint B — Gelişmiş Ayarlar (edit mode).
  TextEditingController? _flowRateController;
  TextEditingController? _headHeightController;
  TextEditingController? _basinAreaController;
  TextEditingController? _panelTiltController;
  TextEditingController? _panelAzimuthController;
  TextEditingController? _panelPowerWController;
  TextEditingController? _hubHeightController;
  TextEditingController? _rotorDiameterController;
  TextEditingController? _ratedPowerKwController;
  bool _editAdvancedExpanded = false;

  // 2026-05-09 Sprint 4 Madde 3: Edit mode'da suitability check + tip-aware
  // re-evaluate. Kullanıcı düzenlerken tip değiştirirse veya konum hâlâ
  // uygun mu yeniden değerlendir.
  bool _editIsCheckingSuitability = false;
  bool _editIsSuitable = true;
  String _editSuitabilityMessage = '';
  List<String> _editSuitabilityReasons = [];
  Map<String, dynamic>? _editLastGeoResult;
  String? _editLastEvaluatedType;

  // 2026-05-17 — Pin düzenleme sırasında senaryo dropdown'u.
  // Pin halihazırda bir senaryoda ise default seçili. Kullanıcı değiştirirse
  // _handleUpdateSaved içinde addPinsToScenario çağrılır (mevcut senaryodan
  // çıkarma şu an scope dışı — Senaryolar paneli üzerinden yapılır).
  int? _editSelectedScenarioId;
  int? _initialScenarioIdForEdit;

  @override
  void initState() {
    super.initState();
    _currentPin = widget.pin;
    _nameController = TextEditingController(text: _currentPin.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _panelAreaController?.dispose();
    _flowRateController?.dispose();
    _headHeightController?.dispose();
    _basinAreaController?.dispose();
    _panelTiltController?.dispose();
    _panelAzimuthController?.dispose();
    _panelPowerWController?.dispose();
    _hubHeightController?.dispose();
    _rotorDiameterController?.dispose();
    _ratedPowerKwController?.dispose();
    _editViewModel?.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final scenarioVM = Provider.of<ScenarioViewModel>(context, listen: false);

    // 2026-05-17 — Pin'in mevcut senaryosunu bul (varsa ilk eşleşeni al).
    int? currentScenarioId;
    for (final s in scenarioVM.scenarios) {
      if (s.pinIds.contains(_currentPin.id)) {
        currentScenarioId = s.id;
        break;
      }
    }
    _initialScenarioIdForEdit = currentScenarioId;
    _editSelectedScenarioId = currentScenarioId;

    // Senaryo listesini güncel tut (yeni senaryo oluşturulduysa görünsün)
    scenarioVM.loadScenarios();

    // Backend 'Hidroelektrik' döner ama ViewModel 'HES' bekler
    final displayType = PinDialogViewModel.toDisplayType(_currentPin.type);
    _editViewModel = PinDialogViewModel(
      mapViewModel,
      displayType,
      initialEquipmentId: _currentPin.equipmentId,
    );

    // Set initial values
    if (_currentPin.panelArea != null) {
      _editViewModel!.setPanelArea(_currentPin.panelArea.toString());
    }
    if (_currentPin.flowRate != null) {
      _editViewModel!.setFlowRate(_currentPin.flowRate.toString());
    }
    if (_currentPin.headHeight != null) {
      _editViewModel!.setHeadHeight(_currentPin.headHeight.toString());
    }
    if (_currentPin.basinAreaKm2 != null) {
      _editViewModel!.setBasinArea(_currentPin.basinAreaKm2.toString());
    }

    _panelAreaController?.dispose();
    _panelAreaController = TextEditingController(
      text: _currentPin.panelArea?.toString() ?? '10.0',
    );

    // 2026-05-17 Sprint B — Advanced settings controller'ları, mevcut pin
    // verisiyle seed edilir. Backend henüz panel_tilt/azimuth/hub_height vs.
    // döndürmüyor (Sprint A migration sonrası bağlanacak); o zamana kadar
    // sadece HES alanları gerçek değer alır, GES/RES alanları boş açılır.
    _flowRateController?.dispose();
    _flowRateController = TextEditingController(
      text: _currentPin.flowRate?.toString() ?? '',
    );
    _headHeightController?.dispose();
    _headHeightController = TextEditingController(
      text: _currentPin.headHeight?.toString() ?? '',
    );
    _basinAreaController?.dispose();
    _basinAreaController = TextEditingController(
      text: _currentPin.basinAreaKm2?.toString() ?? '',
    );
    _panelTiltController?.dispose();
    _panelTiltController = TextEditingController(
      text: _currentPin.panelTilt?.toString() ?? '',
    );
    _panelAzimuthController?.dispose();
    _panelAzimuthController = TextEditingController(
      text: _currentPin.panelAzimuth?.toString() ?? '',
    );
    _panelPowerWController?.dispose();
    _panelPowerWController = TextEditingController();
    _hubHeightController?.dispose();
    _hubHeightController = TextEditingController();
    _rotorDiameterController?.dispose();
    _rotorDiameterController = TextEditingController();
    _ratedPowerKwController?.dispose();
    _ratedPowerKwController = TextEditingController();

    _editViewModel!.seedAdvanced(
      panelTilt: _currentPin.panelTilt,
      panelAzimuth: _currentPin.panelAzimuth,
    );

    _editViewModel!.loadInitialData();
    // Madde 3: Edit mode'a girince tip-aware suitability check
    _editViewModel!.addListener(_onEditViewModelChanged);
    setState(() {
      _isEditing = true;
    });
    _checkEditSuitability();
  }

  /// Edit mode'da suitability re-check. Konum aynı (pin sabit) ama tip
  /// değişebilir (Solar→HES gibi) — yeni tip için uygun mu kontrol.
  Future<void> _checkEditSuitability() async {
    if (_editViewModel == null) return;
    setState(() {
      _editIsCheckingSuitability = true;
      _editSuitabilityMessage = 'Konum tekrar analiz ediliyor...';
    });
    final mapVM = Provider.of<MapViewModel>(context, listen: false);
    final result = await mapVM.geoCheck(
      LatLng(_currentPin.latitude, _currentPin.longitude),
    );
    if (!mounted || _editViewModel == null) return;
    if (result != null) {
      _editLastGeoResult = result;
      _evaluateEditSuitability(_editViewModel!.selectedType, result);
    } else {
      setState(() {
        _editIsCheckingSuitability = false;
        _editIsSuitable = false;
        _editSuitabilityMessage = 'Analiz yapılamadı, riskli düzenleme.';
      });
    }
  }

  void _onEditViewModelChanged() {
    if (_editViewModel == null) return;
    if (_editViewModel!.selectedType != _editLastEvaluatedType &&
        _editLastGeoResult != null) {
      _evaluateEditSuitability(_editViewModel!.selectedType, _editLastGeoResult!);
    }
  }

  void _evaluateEditSuitability(String pinType, Map<String, dynamic> result) {
    final detailKey = pinType == 'Güneş Paneli'
        ? 'solar_details'
        : pinType == 'Rüzgar Türbini'
            ? 'wind_details'
            : 'hydro_details';
    final typeLabel = pinType == 'Güneş Paneli'
        ? 'GES'
        : pinType == 'Rüzgar Türbini'
            ? 'RES'
            : 'HES';
    final detail = result[detailKey] as Map<String, dynamic>?;
    final bool typeSuitable;
    final List<String> reasons = [];
    String message;

    if (detail != null) {
      typeSuitable = detail['suitable'] ?? false;
      if (!typeSuitable && detail['reasons'] != null) {
        for (final r in (detail['reasons'] as List)) {
          reasons.add(r.toString());
        }
      }
      message = typeSuitable
          ? '✓ $typeLabel için uygun.'
          : '⚠ $typeLabel için bu konum UYGUN DEĞİL. Yine de kaydedebilirsiniz ama analiz sonuçları gerçekçi olmayabilir.';
    } else {
      typeSuitable = result['suitable'] ?? false;
      message = typeSuitable
          ? '✓ $typeLabel için uygun.'
          : '⚠ $typeLabel için kontrol bilgisi yok.';
    }

    setState(() {
      _editIsCheckingSuitability = false;
      _editIsSuitable = typeSuitable;
      _editSuitabilityMessage = message;
      _editSuitabilityReasons = reasons;
      _editLastEvaluatedType = pinType;
    });
  }

  void _cancelEdit() {
    _editViewModel?.removeListener(_onEditViewModelChanged);
    _editViewModel?.dispose();
    _editViewModel = null;
    _panelAreaController?.dispose();
    _panelAreaController = null;
    _flowRateController?.dispose();
    _flowRateController = null;
    _headHeightController?.dispose();
    _headHeightController = null;
    _basinAreaController?.dispose();
    _basinAreaController = null;
    _panelTiltController?.dispose();
    _panelTiltController = null;
    _panelAzimuthController?.dispose();
    _panelAzimuthController = null;
    _panelPowerWController?.dispose();
    _panelPowerWController = null;
    _hubHeightController?.dispose();
    _hubHeightController = null;
    _rotorDiameterController?.dispose();
    _rotorDiameterController = null;
    _ratedPowerKwController?.dispose();
    _ratedPowerKwController = null;
    _nameController.text = _currentPin.name;
    setState(() {
      _isEditing = false;
      _editAdvancedExpanded = false;
      _editLastGeoResult = null;
      _editLastEvaluatedType = null;
      _editSuitabilityMessage = '';
      _editSuitabilityReasons = [];
    });
  }

  Future<void> _handleUpdateSaved() async {
    if (_editViewModel == null) return;

    final validationError = _editViewModel!.validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError), backgroundColor: Colors.red));
      return;
    }

    final capacityMw = _editViewModel!.getSelectedCapacityMw();
    if (capacityMw == null) return;

    // N2: Spinner — updatePin + scenario + recalculate uzun sürüyor.
    setState(() => _isSavingEdit = true);

    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    try {
      final updatedPin = await mapViewModel.updatePin(
        _currentPin.id,
        LatLng(_currentPin.latitude, _currentPin.longitude),
        _nameController.text,
        _editViewModel!.backendType,
        capacityMw,
        _editViewModel!.selectedEquipmentId,
        _editViewModel!.panelArea,
        flowRate: _editViewModel!.flowRate > 0 ? _editViewModel!.flowRate : null,
        headHeight: _editViewModel!.headHeight > 0 ? _editViewModel!.headHeight : null,
        basinAreaKm2: _editViewModel!.basinAreaKm2 > 0 ? _editViewModel!.basinAreaKm2 : null,
        // 2026-05-17 Sprint A — Gelişmiş Ayarlar manuel parametreler
        panelTilt: _editViewModel!.panelTilt,
        panelAzimuth: _editViewModel!.panelAzimuth,
        panelPowerW: _editViewModel!.panelPowerW,
        hubHeight: _editViewModel!.hubHeight,
        rotorDiameter: _editViewModel!.rotorDiameter,
        ratedPowerKw: _editViewModel!.ratedPowerKw,
      );
      
      // 2026-05-17 — Senaryo dropdown'da yeni bir senaryo seçildiyse, pin'i
      // o senaryoya da ekle (mevcut senaryodan çıkarma şu an Senaryolar paneli
      // üzerinden yapılır — bkz. _enterEditMode).
      if (_editSelectedScenarioId != null &&
          _editSelectedScenarioId != _initialScenarioIdForEdit &&
          mounted) {
        try {
          // ignore: use_build_context_synchronously
          await Provider.of<ApiService>(context, listen: false)
              .scenario
              .addPinsToScenario(_editSelectedScenarioId!, [updatedPin.id]);
          if (mounted) {
            // ignore: use_build_context_synchronously
            Provider.of<ScenarioViewModel>(context, listen: false)
                .loadScenarios();
          }
        } catch (e) {
          if (mounted) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Senaryoya eklenemedi: $e'),
              backgroundColor: Colors.orange,
            ));
          }
        }
      }

      setState(() {
        _currentPin = updatedPin;
        _isEditing = false;
      });
      _editViewModel?.dispose();
      _editViewModel = null;

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      // N2: Spinner sönsün
      if (mounted) setState(() => _isSavingEdit = false);
    }
  }

  Future<void> _handleAnalyze() async {
    setState(() => _isAnalyzing = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final updatedPin = await apiService.resource.analyzePin(_currentPin.id);

      // Update global list as well if needed, but for now just local state
      if (mounted) {
        setState(() {
          _currentPin = updatedPin;
        });
        // Notify user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Analiz güncellendi"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);

    // 2026-05-09 Faz B: PinPanelShell composition kullanılıyor.
    // Kabuk (header, il/ilçe, gradient, scroll) shell tarafında. Burada
    // sadece view veya edit body widget'ı döndürülür. Eski BackdropFilter
    // glass efekti shell'de yok — tutarlı görünüm için kaldırıldı (Add ile
    // aynı style).
    final isEditing = _isEditing;
    final typeColor = _currentPin.type == 'Güneş Paneli'
        ? Colors.orange
        : _currentPin.type == 'Hidroelektrik'
            ? const Color(0xFF1DB954)
            : Colors.blueAccent;
    final typeIcon = _currentPin.type == 'Güneş Paneli'
        ? Icons.wb_sunny
        : _currentPin.type == 'Hidroelektrik'
            ? Icons.water_drop
            : Icons.wind_power;

    return PinPanelShell(
      point: LatLng(_currentPin.latitude, _currentPin.longitude),
      accentColor: typeColor,
      typeIcon: typeIcon,
      title: isEditing
          ? '${_currentPin.name} · Düzenle'
          : _currentPin.name,
      onClose: widget.onClose,
      onDragDelta: widget.onDragDelta,
      onDragEnd: widget.onDragEnd,
      body: isEditing ? _buildEditForm(theme) : _buildViewContent(theme),
    );
  }

  // (Kaldırıldı 2026-05-09 Faz B) `_buildHeader` artık `PinPanelShell` tarafından
  // yönetiliyor — başlık + close butonu + il/ilçe + tip ikonu hepsi shell'de.

  Widget _buildViewContent(ThemeViewModel theme) {
    // Analiz verisi varsa EnergyOutputWidget göster
    if (_currentPin.analysis != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EnergyOutputWidget(result: _currentPin.analysis!, theme: theme),
          const SizedBox(height: 20),
          // Actions Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
               // Güncelle Butonu
               ElevatedButton.icon(
                 onPressed: _isAnalyzing ? null : _handleAnalyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.cardColor,
                    foregroundColor: theme.textColor,
                    elevation: 0,
                    side: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
                  ),
                  icon: _isAnalyzing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_isAnalyzing ? "..." : "Güncelle"),
               ),
               // Düzenle Butonu (Daha kompakt)
               ElevatedButton.icon(
                  onPressed: _enterEditMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.cardColor,
                    foregroundColor: theme.textColor,
                    elevation: 0,
                    side: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
                  ),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Düzenle"),
               ),
               // Senaryolara Git (cross-sheet navigation — A.5)
               if (widget.onOpenScenarios != null)
                 ElevatedButton.icon(
                   onPressed: widget.onOpenScenarios,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.lightBlueAccent.withValues(alpha: 0.18),
                     foregroundColor: Colors.lightBlueAccent,
                     elevation: 0,
                     side: BorderSide(color: Colors.lightBlueAccent.withValues(alpha: 0.4)),
                   ),
                   icon: const Icon(Icons.layers_rounded, size: 18),
                   label: const Text('Senaryolar'),
                 ),
               // Detaylı Rapor — Santral tab'ında bu pin'in extended raporu
               ElevatedButton.icon(
                 onPressed: () {
                   Navigator.of(context).push(
                     createReportRoute(initialPinId: _currentPin.id),
                   );
                 },
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.cyanAccent.withValues(alpha: 0.18),
                   foregroundColor: Colors.cyanAccent,
                   elevation: 0,
                   side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                 ),
                 icon: const Icon(Icons.bar_chart_rounded, size: 18),
                 label: const Text('Detaylı Rapor'),
               ),
               // Sil Butonu (Kırmızı) - Kapat yerine
               ElevatedButton.icon(
                  onPressed: () => _handleDelete(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text("Sil"),
               ),
            ],
          ),
        ],
      );
    }

    // Analiz verisi yoksa: konum bilgisi shell header'da zaten var
    // (il/ilçe + koord) — burada tekrar koordinat satırı koymuyoruz.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: Colors.orange.withValues(alpha: 0.1),
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
           ),
           child: Column(
             children: [
               const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
               const SizedBox(height: 12),
               const Text(
                 "Henüz analiz verisi yok.",
                 style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 8),
               Text(
                 "Detaylı üretim tahmini için verileri güncelleyin.",
                 style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
                 textAlign: TextAlign.center,
               ),
             ],
           ),
         ),
         const SizedBox(height: 24),

          // Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _handleAnalyze,
                icon: _isAnalyzing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(_isAnalyzing ? "Hesaplanıyor..." : "Analizi Başlat"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _enterEditMode,
                icon: const Icon(Icons.edit),
                label: const Text("Düzenle"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textColor,
                  side: BorderSide(color: theme.secondaryTextColor),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
              // Delete Button for No Analysis view
              IconButton(
                onPressed: _handleDelete,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                icon: const Icon(Icons.delete),
              ),
            ],
          ),
      ],
    );
  }
  


  Widget _buildEditForm(ThemeViewModel theme) {
    if (_editViewModel == null) return const SizedBox();

    return ChangeNotifierProvider.value(
       value: _editViewModel!,
       child: Consumer<PinDialogViewModel>(
         builder: (ctx, vm, _) {
           final scenarioVM = Provider.of<ScenarioViewModel>(ctx);
           return Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
                // 2026-05-09 Madde 3: Edit mode suitability banner.
                // Tip değiştirilirse veya bu konum o tipe uygun değilse
                // kullanıcıyı uyarır (block etmez — kayıt yine yapılabilir
                // ama analiz sonuçları gerçekçi olmayabilir).
                _buildEditSuitabilityBanner(theme),
                const SizedBox(height: 12),

                ThemedTextField(
                  controller: _nameController,
                  label: "Kaynak Adı",
                  theme: theme
                ),
                const SizedBox(height: 16),

                // 2026-05-17 — Senaryo dropdown (add dialog ile simetri).
                // Pin halihazırda bir senaryoda ise default seçili gelir.
                // Yeni bir senaryo seçilirse save'de pin oraya da eklenir.
                ThemedDropdown<int?>(
                  value: _editSelectedScenarioId,
                  label: 'Senaryoya Ekle (Opsiyonel)',
                  theme: theme,
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Senaryoya ekleme',
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
                    DropdownMenuItem<int?>(
                      value: -1,
                      child: Row(
                        children: [
                          const Icon(Icons.add, size: 18, color: Colors.lightBlueAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Yeni Senaryo Oluştur',
                            style: TextStyle(color: Colors.lightBlueAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == -1) {
                      _showQuickScenarioCreateForEdit(scenarioVM, theme);
                    } else {
                      setState(() => _editSelectedScenarioId = val);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Type Switcher
                Container(
                  decoration: BoxDecoration(
                    color: theme.backgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildTypeOption(theme, "Güneş Paneli", Icons.wb_sunny, vm.selectedType == "Güneş Paneli", () => _changeTypeSynced(vm, "Güneş Paneli")),
                      _buildTypeOption(theme, "Rüzgar Türbini", Icons.wind_power, vm.selectedType == "Rüzgar Türbini", () => _changeTypeSynced(vm, "Rüzgar Türbini")),
                      _buildTypeOption(theme, "HES", Icons.water_drop, vm.selectedType == "HES", () => _changeTypeSynced(vm, "HES")),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Equipment selector — RES + GES için ana formda, HES'te gizli.
                // 2026-05-17 Sprint B kullanıcı kararı: HES'te ekipman seçimi
                // yok; tüm hidrolik parametreler Gelişmiş Ayarlar'da.
                if (vm.selectedType != 'HES') ...[
                  Text(
                    vm.selectedType == 'Güneş Paneli'
                        ? 'Panel Modeli'
                        : 'Türbin Modeli',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  EquipmentSelectorWidget(
                    equipments: vm.availableEquipments,
                    selectedEquipmentId: vm.selectedEquipmentId,
                    isLoading: vm.isLoadingEquipments,
                    theme: theme,
                    onChanged: (id) { if(id!=null) vm.selectEquipment(id); },
                  ),
                  const SizedBox(height: 16),
                ],

                // 2026-05-17 Sprint B — Gelişmiş Ayarlar expandable.
                AdvancedSettingsPanel(
                  theme: theme,
                  vm: vm,
                  expanded: _editAdvancedExpanded,
                  onToggle: () => setState(() =>
                      _editAdvancedExpanded = !_editAdvancedExpanded),
                  panelAreaController: _panelAreaController!,
                  panelTiltController: _panelTiltController!,
                  panelAzimuthController: _panelAzimuthController!,
                  panelPowerWController: _panelPowerWController!,
                  hubHeightController: _hubHeightController!,
                  rotorDiameterController: _rotorDiameterController!,
                  ratedPowerKwController: _ratedPowerKwController!,
                  flowRateController: _flowRateController!,
                  headHeightController: _headHeightController!,
                  basinAreaController: _basinAreaController!,
                ),

                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isSavingEdit ? null : _cancelEdit,
                        child: Text("İptal", style: TextStyle(color: theme.secondaryTextColor)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        // N2: spinner + disabled.
                        onPressed: _isSavingEdit ? null : _handleUpdateSaved,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: _isSavingEdit
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text("Kaydet"),
                      ),
                    ),
                  ],
                ),

             ],
           );
         }
       ),
    );
  }
  
  /// Edit dialog içinden hızlı senaryo oluşturma (add dialog ile aynı pattern).
  Future<void> _showQuickScenarioCreateForEdit(
      ScenarioViewModel scenarioVM, ThemeViewModel theme) async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Yeni Senaryo', style: TextStyle(color: theme.textColor)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'Senaryo adı',
            hintStyle: TextStyle(color: theme.secondaryTextColor),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: theme.secondaryTextColor.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal',
                style: TextStyle(color: theme.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, nameCtrl.text.trim());
              }
            },
            child: const Text('Oluştur',
                style: TextStyle(color: Colors.lightBlueAccent)),
          ),
        ],
      ),
    );
    nameCtrl.dispose();

    if (result != null && mounted) {
      try {
        await scenarioVM.createScenario(ScenarioCreate(name: result));
        if (mounted && scenarioVM.scenarios.isNotEmpty) {
          final newId = scenarioVM.scenarios.first.id;
          setState(() => _editSelectedScenarioId = newId);
        }
      } catch (_) {
        // createScenario zaten error state'i set ediyor
      }
    }
  }

  /// 2026-05-17 — Form içi tip değiştirme PinDialogViewModel + PinFlowController
  /// ikisini birden sync eder ki suitability layers tipe göre güncellensin.
  void _changeTypeSynced(PinDialogViewModel vm, String newType) {
    vm.changeType(newType);
    try {
      Provider.of<PinFlowController>(context, listen: false).changeType(newType);
    } catch (_) {
      // PinFlowController scope dışında ise sessiz geç
    }
  }

  Widget _buildTypeOption(ThemeViewModel theme, String label, IconData icon, bool isSelected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
             duration: const Duration(milliseconds: 200),
             padding: const EdgeInsets.symmetric(vertical: 12),
             decoration: BoxDecoration(
               color: isSelected ? theme.cardColor : Colors.transparent,
               borderRadius: BorderRadius.circular(12),
               boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
             ),
             child: Icon(icon, color: isSelected ? (label.contains("Güneş") ? Colors.orange : label == "HES" ? Colors.teal : Colors.blue) : theme.secondaryTextColor),
          ),
        ),
      );
  }

  Future<void> _handleDelete() async {
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

    if (confirm == true && mounted) {
      final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
      try {
        await mapViewModel.deletePin(_currentPin.id);
        if (mounted) widget.onClose(); // Bottom card'ı kapat
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        }
      }
    }
  }

  /// Edit mode suitability banner — check yapılıyorsa spinner, sonuç yeşil
  /// veya kırmızı renkte uyarı. Sebepler varsa madde madde gösterir.
  Widget _buildEditSuitabilityBanner(ThemeViewModel theme) {
    if (_editIsCheckingSuitability) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: theme.secondaryTextColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.secondaryTextColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _editSuitabilityMessage,
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    if (_editSuitabilityMessage.isEmpty) return const SizedBox.shrink();
    final color = _editIsSuitable ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _editIsSuitable ? Icons.check_circle : Icons.warning_amber_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _editSuitabilityMessage,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_editSuitabilityReasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            ..._editSuitabilityReasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(left: 26, top: 2),
                child: Text(
                  '• $r',
                  style: TextStyle(color: theme.textColor, fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

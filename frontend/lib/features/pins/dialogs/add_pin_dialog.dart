import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/features/pins/viewmodels/pin_dialog_viewmodel.dart';
import 'package:frontend/features/pins/controllers/pin_flow_controller.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/shared/widgets/themed_inputs.dart';
import 'package:frontend/features/pins/widgets/equipment_selector.dart';
import 'package:frontend/features/pins/widgets/pin_panel_shell.dart';
import 'package:frontend/features/pins/widgets/advanced_settings_panel.dart';
import 'package:frontend/shared/widgets/dialog_base.dart';
import 'package:frontend/features/map/dialogs/map_dialogs.dart'; // For error dialog

/// Pin Ekleme Formu — V2 pattern (floating bottom card / mobile bottom sheet).
///
/// 2026-05-08 — `Dialog`/`showDialog` modal yerine artık map_screen Stack
/// overlay'i tarafından state-based render edilir. Harita asla bloklanmaz;
/// kullanıcı arkadaki konumu görerek formu doldurur.
///
/// Kabuk: web (≥600px) ortada-alta floating, mobile <600px tam genişlik
/// bottom-anchored. Aynı widget responsive — tek codebase.
///
/// `onClose` callback'i caller (map_screen) sağlar; close button → setState ile
/// `_pinFormPoint = null` set eder. Dış `barrier` yok — kullanıcı haritada
/// pan/zoom yapabilir, harita üzerine tıklamak formu kapatmaz.
class AddPinDialog extends StatefulWidget {
  final LatLng point;
  final String initialPinType;
  final VoidCallback onClose;

  /// 2026-05-26 (K1): Floating draggable card için header drag callback'leri.
  /// PinFlowOverlay tarafından sağlanır; PinPanelShell'e iletilir.
  final ValueChanged<Offset>? onDragDelta;
  final VoidCallback? onDragEnd;

  const AddPinDialog({
    super.key,
    required this.point,
    required this.initialPinType,
    required this.onClose,
    this.onDragDelta,
    this.onDragEnd,
  });

  @override
  State<AddPinDialog> createState() => _AddPinDialogState();
}

class _AddPinDialogState extends State<AddPinDialog> {
  late PinDialogViewModel _viewModel;
  late TextEditingController _nameController;
  late TextEditingController _panelAreaController;
  final TextEditingController _flowRateController = TextEditingController();
  final TextEditingController _headHeightController = TextEditingController();
  final TextEditingController _basinAreaController = TextEditingController();
  // 2026-05-17 Sprint B — Advanced parametre controller'ları
  final TextEditingController _panelTiltController = TextEditingController();
  final TextEditingController _panelAzimuthController = TextEditingController();
  final TextEditingController _panelPowerWController = TextEditingController();
  final TextEditingController _hubHeightController = TextEditingController();
  final TextEditingController _rotorDiameterController = TextEditingController();
  final TextEditingController _ratedPowerKwController = TextEditingController();
  bool _advancedExpanded = false;
  int? _selectedScenarioId;

  bool _isCheckingSuitability = true;
  bool _isSuitable = false;
  String _suitabilityMessage = "Konum analiz ediliyor...";
  List<String> _suitabilityReasons = [];

  /// 2026-05-26 (N2): "Kaydet" tıklandıktan sonra spinner durumu.
  /// `mapViewModel.addPin` + `analyzePin` + `addPinsToScenario` zinciri
  /// 3-5 saniye sürebiliyor; eski hâl: kullanıcı butona basıyor, ekranda
  /// hiçbir değişiklik yok → tekrar tıklıyor → duplicate.
  bool _isSaving = false;

  /// 2026-05-09 Sprint 4 Madde 3: Backend'den gelen tip-aware geo result
  /// cache. Tip değişiminde re-API yerine cache'den yeniden değerlendirme.
  Map<String, dynamic>? _lastGeoResult;
  String? _lastEvaluatedType;

  // 2026-05-09 Faz B: Reverse geocode (il/ilçe header) PinPanelShell'e taşındı.

  @override
  void initState() {
    super.initState();
    // 2026-05-26 (M3): "Yeni Kaynak" yerine kullanıcının pin sayısına göre
    // otomatik numara — "Yeni Kaynak #3" gibi. Çoklu "Yeni Kaynak" görünüm
    // sorunu çözülür. Tipe göre kısa etiket: GES / RES / HES.
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final pinCount = mapViewModel.pins.length;
    final typeShort = switch (widget.initialPinType) {
      'Güneş Paneli' => 'GES',
      'Rüzgar Türbini' => 'RES',
      'Hidroelektrik' => 'HES',
      _ => 'Kaynak',
    };
    _nameController =
        TextEditingController(text: 'Yeni $typeShort #${pinCount + 1}');
    _panelAreaController = TextEditingController(text: '10.0');

    _viewModel = PinDialogViewModel(
      mapViewModel,
      widget.initialPinType,
    );
    // Tip değişiminde suitability'i yeniden değerlendir (cache'den).
    _viewModel.addListener(_onViewModelChanged);

    // Load scenarios and initial equipments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScenarioViewModel>(context, listen: false).loadScenarios();
      _viewModel.loadInitialData();
      _checkSuitability();
    });
  }

  void _onViewModelChanged() {
    // Tip değiştiyse: cache'den re-evaluate (yeni API call yok)
    if (_viewModel.selectedType != _lastEvaluatedType &&
        _lastGeoResult != null) {
      _evaluateSuitabilityForType(_viewModel.selectedType, _lastGeoResult!);
    }
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
      _lastGeoResult = result;
      _evaluateSuitabilityForType(_viewModel.selectedType, result);
    } else {
      setState(() {
        _isCheckingSuitability = false;
        _isSuitable = false; // Güvenli taraf: Analiz yapılamazsa izin verme
        _suitabilityMessage = "Analiz sunucusuna ulaşılamadı.";
        _suitabilityReasons = [];
      });
    }
  }

  /// 2026-05-09 Sprint 4 Madde 3: Tip-aware suitability değerlendirme.
  /// Backend response `solar_details / wind_details / hydro_details` döner;
  /// seçilen tipin bayrağına göre form'u `suitable / unsuitable` çevirir.
  /// Tip değiştirilince yeni API call yapmadan cache'den yeniden değerlendirir.
  void _evaluateSuitabilityForType(String pinType, Map<String, dynamic> result) {
    // Tipe göre backend detail key
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
    final String message;

    if (detail != null) {
      typeSuitable = detail['suitable'] ?? false;
      if (!typeSuitable && detail['reasons'] != null) {
        for (final r in (detail['reasons'] as List)) {
          reasons.add(r.toString());
        }
      }
      message = typeSuitable
          ? '$typeLabel için uygun arazi.'
          : '$typeLabel için uygun değil.';
    } else {
      // Backend tip-aware detail yoksa genel `suitable` flag'ine düş
      typeSuitable = result['suitable'] ?? false;
      message = result['recommendation']?.toString() ??
          (typeSuitable
              ? '$typeLabel için uygun.'
              : '$typeLabel için kontrol edilemedi.');
    }

    setState(() {
      _isCheckingSuitability = false;
      _isSuitable = typeSuitable;
      _suitabilityMessage = message;
      _suitabilityReasons = reasons;
      _lastEvaluatedType = pinType;
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _nameController.dispose();
    _panelAreaController.dispose();
    _flowRateController.dispose();
    _headHeightController.dispose();
    _basinAreaController.dispose();
    _panelTiltController.dispose();
    _panelAzimuthController.dispose();
    _panelPowerWController.dispose();
    _hubHeightController.dispose();
    _rotorDiameterController.dispose();
    _ratedPowerKwController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _showQuickScenarioCreate(ScenarioViewModel scenarioVM, ThemeViewModel theme) async {
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
              borderSide: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: theme.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, nameCtrl.text.trim());
              }
            },
            child: const Text('Oluştur', style: TextStyle(color: Colors.lightBlueAccent)),
          ),
        ],
      ),
    );
    nameCtrl.dispose();

    if (result != null && mounted) {
      try {
        await scenarioVM.createScenario(ScenarioCreate(name: result));
        if (mounted) {
          final newId = scenarioVM.scenarios.first.id;
          setState(() => _selectedScenarioId = newId);
        }
      } catch (_) {
        // createScenario already sets error in viewmodel
      }
    }
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
          // 2026-05-09 Faz B: Kabuk artık `PinPanelShell`'de (composition
          // pattern). Header (tip ikonu + il/ilçe + close), gradient,
          // responsive boyut, scroll wrapper — shell yönetir. Burada sadece
          // form body kalır.
          final typeColor = viewModel.selectedType == 'Güneş Paneli'
              ? Colors.orange
              : viewModel.selectedType == 'HES'
                  ? const Color(0xFF1DB954)
                  : Colors.blueAccent;
          final typeIcon = viewModel.selectedType == 'Güneş Paneli'
              ? Icons.wb_sunny
              : viewModel.selectedType == 'HES'
                  ? Icons.water
                  : Icons.wind_power;
          return PinPanelShell(
            point: widget.point,
            accentColor: typeColor,
            typeIcon: typeIcon,
            title: 'Yeni Kaynak Ekle',
            onClose: widget.onClose,
            onDragDelta: widget.onDragDelta,
            onDragEnd: widget.onDragEnd,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
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

                    // 2026-05-17 Sprint B — Panel Alanı ana formdan kaldırıldı,
                    // Gelişmiş Ayarlar > GES bloğuna taşındı.

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
                        DropdownMenuItem<int?>(
                          value: -1,
                          child: Row(
                            children: [
                              Icon(Icons.add, size: 18, color: Colors.lightBlueAccent),
                              const SizedBox(width: 6),
                              Text(
                                "Yeni Senaryo Oluştur",
                                style: TextStyle(color: Colors.lightBlueAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == -1) {
                          _showQuickScenarioCreate(scenarioVM, theme);
                        } else {
                          setState(() => _selectedScenarioId = val);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Type Selector
                    _buildTypeSelector(theme, viewModel),
                    const SizedBox(height: 20),

                    // Equipment Selector — RES ve GES için ana formda;
                    // HES'te gizli (kullanıcı isteği: HES için seçim yok).
                    // 2026-05-17 Sprint B kararı.
                    if (viewModel.selectedType != 'HES') ...[
                      Text(
                        viewModel.selectedType == 'Güneş Paneli'
                            ? 'Panel Modeli'
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
                      const SizedBox(height: 16),
                    ],

                    // 2026-05-17 Sprint B — Gelişmiş Ayarlar expandable.
                    // Tipe göre manuel parametre alanları. Aynı pop-up içinde
                    // genişler/daralır (kullanıcı seçimi: expandable).
                    _buildAdvancedSettings(theme, viewModel),

                    const SizedBox(height: 32),

                    // Action Buttons
                    // N2: _isSaving zinciri tetikler — addPin + analyze +
                    // scenario ekleme tamamlanana kadar buton spinner+disabled.
                    MapDialogActionButtons(
                      theme: theme,
                      onCancel: _isSaving ? () {} : widget.onClose,
                      onSave: (viewModel.canSubmit &&
                              !_isCheckingSuitability &&
                              _isSuitable &&
                              !_isSaving)
                          ? () => _handleSave(context, viewModel)
                          : null,
                      isSaving: viewModel.isSubmitting || _isSaving,
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 2026-05-17 Sprint B — Tip-aware Gelişmiş Ayarlar paneli.
  /// Pop-up içi expandable: header tıklanınca alanlar açılır/kapanır.
  /// Boş bırakılan alanlar backend'de default'a düşer (Sprint A migration
  /// sonrası gerçek payload'a eklenir).
  Widget _buildAdvancedSettings(ThemeViewModel theme, PinDialogViewModel vm) {
    return AdvancedSettingsPanel(
      theme: theme,
      vm: vm,
      expanded: _advancedExpanded,
      onToggle: () => setState(() => _advancedExpanded = !_advancedExpanded),
      panelAreaController: _panelAreaController,
      panelTiltController: _panelTiltController,
      panelAzimuthController: _panelAzimuthController,
      panelPowerWController: _panelPowerWController,
      hubHeightController: _hubHeightController,
      rotorDiameterController: _rotorDiameterController,
      ratedPowerKwController: _ratedPowerKwController,
      flowRateController: _flowRateController,
      headHeightController: _headHeightController,
      basinAreaController: _basinAreaController,
    );
  }

  /// 2026-05-17 — Form içi tip değiştirme hem `PinDialogViewModel` (form
  /// state için) hem `PinFlowController` (suitability layers sync için)
  /// çağırır. Aksi halde RES→GES geçişinde tematik harita güncellenmez.
  void _changeTypeSynced(PinDialogViewModel vm, String newType) {
    vm.changeType(newType);
    try {
      Provider.of<PinFlowController>(context, listen: false).changeType(newType);
    } catch (_) {
      // PinFlowController scope dışında ise sessiz geç (testler vs).
    }
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
            label: 'Güneş Paneli',
            icon: Icons.wb_sunny_outlined,
            isSelected: viewModel.selectedType == 'Güneş Paneli',
            onTap: () => _changeTypeSynced(viewModel, 'Güneş Paneli'),
            activeColor: Colors.orange,
          ),
          _buildSegmentButton(
            theme: theme,
            label: 'Rüzgar Türbini',
            icon: Icons.wind_power_outlined,
            isSelected: viewModel.selectedType == 'Rüzgar Türbini',
            onTap: () => _changeTypeSynced(viewModel, 'Rüzgar Türbini'),
            activeColor: Colors.blue,
          ),
          _buildSegmentButton(
            theme: theme,
            label: 'HES',
            icon: Icons.water_outlined,
            isSelected: viewModel.selectedType == 'HES',
            onTap: () => _changeTypeSynced(viewModel, 'HES'),
            activeColor: const Color(0xFF1DB954), // Spotify yeşili
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
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? theme.textColor : theme.secondaryTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
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

    // N2: Spinner — kaydet zinciri ~3-5 sn alıyor.
    setState(() => _isSaving = true);

    try {
      // 1. Pini ekle (backend'e 'Hidroelektrik' gönder, 'HES' değil)
      final newPin = await mapViewModel.addPin(
        widget.point,
        _nameController.text,
        viewModel.backendType,
        capacityMw,
        viewModel.selectedEquipmentId,
        viewModel.panelArea,
        flowRate: viewModel.flowRate > 0 ? viewModel.flowRate : null,
        headHeight: viewModel.headHeight > 0 ? viewModel.headHeight : null,
        basinAreaKm2: viewModel.basinAreaKm2 > 0 ? viewModel.basinAreaKm2 : null,
        // 2026-05-17 Sprint A — Gelişmiş Ayarlar manuel parametreler
        panelTilt: viewModel.panelTilt,
        panelAzimuth: viewModel.panelAzimuth,
        panelPowerW: viewModel.panelPowerW,
        hubHeight: viewModel.hubHeight,
        rotorDiameter: viewModel.rotorDiameter,
        ratedPowerKw: viewModel.ratedPowerKw,
      );

      // 2. Senaryo seçiliyse ona da ekle
      if (_selectedScenarioId != null && context.mounted) {
        await Provider.of<ApiService>(context, listen: false)
            .scenario
            .addPinsToScenario(_selectedScenarioId!, [newPin.id]);
        // mounted yeniden kontrol et (await sonrası context geçersiz olabilir)
        if (context.mounted) {
          Provider.of<ScenarioViewModel>(context, listen: false).loadScenarios();
        }
      }

      // 3. 2026-05-17 — Otomatik analiz: pin eklendikten sonra hemen
      // /pins/{id}/analyze çağır → kullanıcı pine tıkladığında "Güncelle"
      // basmadan veri hazır olsun. Eski davranış: pin oluşur, analiz boş;
      // sonraki pin eklenince önceki pin'in analizi geliyordu (timing bug).
      if (context.mounted) {
        try {
          final api = Provider.of<ApiService>(context, listen: false);
          await api.resource.analyzePin(newPin.id);
          // Pin listesini yenile — yeni analiz bilgisi gelsin
          if (context.mounted) {
            await Provider.of<MapViewModel>(context, listen: false).fetchPins();
          }
        } catch (e) {
          debugPrint('[AddPin] otomatik analiz hatası: $e');
          // Sessiz geç — pin yine de eklenmiş, kullanıcı sonra manuel
          // "Güncelle" basabilir.
        }
      }

      if (context.mounted) {
        widget.onClose();
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
    } finally {
      // N2: Spinner sönsün (success → widget zaten kapanmış olsa bile
      // mounted kontrolü ile setState güvenli).
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 2026-05-09 Faz B: `_buildLocationTitle` ve `_buildSeasonalInfoChip` artık
  // kullanılmıyor — header (il/ilçe + koordinat) PinPanelShell tarafından
  // yönetiliyor. Mevsim chip kullanıcı isteğine göre Sprint 4'te shell'in
  // `trailing` parametresi olarak geri eklenebilir.
}

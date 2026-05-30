// lib/features/pins/widgets/advanced_settings_panel.dart
//
// 2026-05-17 Sprint B — Pin Gelişmiş Ayarlar (expandable panel)
// ============================================================================
// Pin add / pin edit dialog'larında ortak kullanılan "Gelişmiş Ayarlar"
// bölümü. Tipe göre manuel parametre alanları gösterir:
//
//   GES (Güneş Paneli):
//     - Panel Alanı (m²)            → vm.setPanelArea
//     - Panel Eğim Açısı (°)        → vm.setPanelTilt
//     - Azimuth (°, 180=güney)       → vm.setPanelAzimuth
//     - Tek Panel Gücü (W)          → vm.setPanelPowerW
//
//   RES (Rüzgar Türbini):
//     - Kule Yüksekliği (m)         → vm.setHubHeight
//     - Rotor Çapı (m)              → vm.setRotorDiameter
//     - Nominal Güç (kW)            → vm.setRatedPowerKw
//
//   HES (Hidroelektrik):
//     - Debi (m³/s)                 → vm.setFlowRate
//     - Düşü Yüksekliği (m)         → vm.setHeadHeight
//     - Havza Alanı (km²)           → vm.setBasinArea
//
// Backend ile ilişki: Sprint A migration sonrası tüm alanlar pin payload'una
// eklenecek. Şu an stub — boş bırakılırsa null gider, backend default'a düşer.
//
// Design pattern: caller (AddPinDialog veya PinDetailsDialog) state'i yönetir
// (expanded flag + controllers), bu widget sadece render eder. Bkz.
// `pin_panel_shell.dart` aynı composition pattern.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/pins/viewmodels/pin_dialog_viewmodel.dart';
import 'package:frontend/shared/widgets/themed_inputs.dart';

class AdvancedSettingsPanel extends StatelessWidget {
  final ThemeViewModel theme;
  final PinDialogViewModel vm;
  final bool expanded;
  final VoidCallback onToggle;

  // GES
  final TextEditingController panelAreaController;
  final TextEditingController panelTiltController;
  final TextEditingController panelAzimuthController;
  final TextEditingController panelPowerWController;
  // RES
  final TextEditingController hubHeightController;
  final TextEditingController rotorDiameterController;
  final TextEditingController ratedPowerKwController;
  // HES
  final TextEditingController flowRateController;
  final TextEditingController headHeightController;
  final TextEditingController basinAreaController;

  const AdvancedSettingsPanel({
    super.key,
    required this.theme,
    required this.vm,
    required this.expanded,
    required this.onToggle,
    required this.panelAreaController,
    required this.panelTiltController,
    required this.panelAzimuthController,
    required this.panelPowerWController,
    required this.hubHeightController,
    required this.rotorDiameterController,
    required this.ratedPowerKwController,
    required this.flowRateController,
    required this.headHeightController,
    required this.basinAreaController,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentForType(vm.selectedType);
    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: expanded ? 0.4 : 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — tıklanır toggle
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gelişmiş Ayarlar',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _hintForType(vm.selectedType),
                    style: TextStyle(
                      color: theme.secondaryTextColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: expanded ? 0.5 : 0.0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Body — expandable
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Builder(
                      builder: (ctx) => _bodyForType(ctx, vm.selectedType),
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _bodyForType(BuildContext context, String type) {
    if (type == 'Güneş Paneli') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _sectionLabel('Panel Geometrisi'),
          const SizedBox(height: 8),
          ThemedTextField(
            controller: panelAreaController,
            label: 'Panel Alanı (m²) — Opsiyonel (default 10)',
            isNumber: true,
            onChanged: vm.setPanelArea,
            theme: theme,
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ThemedTextField(
                controller: panelTiltController,
                label: 'Eğim (°)',
                isNumber: true,
                onChanged: vm.setPanelTilt,
                theme: theme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ThemedTextField(
                controller: panelAzimuthController,
                label: 'Azimuth (°)',
                isNumber: true,
                onChanged: vm.setPanelAzimuth,
                theme: theme,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ThemedTextField(
            controller: panelPowerWController,
            label: 'Tek Panel Gücü (W) — Opsiyonel',
            isNumber: true,
            onChanged: vm.setPanelPowerW,
            theme: theme,
          ),
          const SizedBox(height: 10),
          _saveAsEquipmentButton(context, 'Solar', 'Panel Tipini Kaydet'),
        ],
      );
    }
    if (type == 'Rüzgar Türbini') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _sectionLabel('Türbin Geometrisi'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ThemedTextField(
                controller: hubHeightController,
                label: 'Kule Y. (m)',
                isNumber: true,
                onChanged: vm.setHubHeight,
                theme: theme,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ThemedTextField(
                controller: rotorDiameterController,
                label: 'Rotor Çapı (m)',
                isNumber: true,
                onChanged: vm.setRotorDiameter,
                theme: theme,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ThemedTextField(
            controller: ratedPowerKwController,
            label: 'Nominal Güç (kW) — Opsiyonel',
            isNumber: true,
            onChanged: vm.setRatedPowerKw,
            theme: theme,
          ),
          const SizedBox(height: 10),
          _saveAsEquipmentButton(context, 'Wind', 'Türbin Tipini Kaydet'),
        ],
      );
    }
    // HES
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        _sectionLabel('Hidrolik Parametreler'),
        const SizedBox(height: 8),
        ThemedTextField(
          controller: flowRateController,
          label: 'Debi (m³/s) — Opsiyonel',
          isNumber: true,
          onChanged: vm.setFlowRate,
          theme: theme,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ThemedTextField(
              controller: headHeightController,
              label: 'Düşü (m)',
              isNumber: true,
              onChanged: vm.setHeadHeight,
              theme: theme,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ThemedTextField(
              controller: basinAreaController,
              label: 'Havza (km²)',
              isNumber: true,
              onChanged: vm.setBasinArea,
              theme: theme,
            ),
          ),
        ]),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: theme.secondaryTextColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      );

  /// 2026-05-17 Sprint A — 'Panel Tipini Kaydet' / 'Türbin Tipini Kaydet'
  /// butonu. Tıklayınca mini dialog açılır (ekipman adı), kullanıcı onaylar,
  /// backend'e POST /equipments gider, başarılı ise MapViewModel.loadEquipments
  /// force refresh + snackbar.
  Widget _saveAsEquipmentButton(
      BuildContext context, String backendType, String label) {
    final accent = _accentForType(vm.selectedType);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showSaveEquipmentDialog(context, backendType),
        icon: Icon(Icons.bookmark_add_outlined, size: 18, color: accent),
        label: Text(
          label,
          style: TextStyle(color: accent, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: accent.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Future<void> _showSaveEquipmentDialog(
      BuildContext context, String backendType) async {
    // Doğrulama: temel parametre boş olmasın
    final ratedKw = backendType == 'Solar'
        ? ((vm.panelPowerW ?? 0) / 1000.0)
        : (vm.ratedPowerKw ?? 0);
    if (ratedKw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(backendType == 'Solar'
            ? 'Önce "Tek Panel Gücü (W)" değerini girin.'
            : 'Önce "Nominal Güç (kW)" değerini girin.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final nameCtrl = TextEditingController(
      text: backendType == 'Solar'
          ? 'Özel Panel · ${vm.panelPowerW!.toStringAsFixed(0)}W'
          : 'Özel Türbin · ${vm.ratedPowerKw!.toStringAsFixed(0)}kW',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          backendType == 'Solar'
              ? 'Panel Tipini Kaydet'
              : 'Türbin Tipini Kaydet',
          style: TextStyle(color: theme.textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bu ekipman sadece sizin hesabınızda kayıtlı olur, '
              'Panel/Türbin Modeli listesinde "Kendi modelim" rozetiyle '
              'gözükür.',
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ThemedTextField(
              controller: nameCtrl,
              label: 'Ekipman Adı',
              theme: theme,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal',
                style: TextStyle(color: theme.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet',
                style: TextStyle(color: Colors.lightBlueAccent)),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) {
      nameCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (name.isEmpty) return;

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final mapVM = Provider.of<MapViewModel>(context, listen: false);

      // Backend spec object — gelişmiş ayarlardaki tüm parametreler kayıtlı.
      final specs = backendType == 'Solar'
          ? <String, dynamic>{
              if (vm.panelTilt != null) 'tilt': vm.panelTilt,
              if (vm.panelAzimuth != null) 'azimuth': vm.panelAzimuth,
              if (vm.panelArea > 0) 'area_m2': vm.panelArea,
              if (vm.panelPowerW != null) 'power_w': vm.panelPowerW,
            }
          : <String, dynamic>{
              if (vm.hubHeight != null) 'hub_height_m': vm.hubHeight,
              if (vm.rotorDiameter != null)
                'rotor_diameter_m': vm.rotorDiameter,
              if (vm.ratedPowerKw != null) 'rated_power_kw': vm.ratedPowerKw,
            };

      final created = await api.equipment.createEquipment(
        name: name,
        type: backendType,
        ratedPowerKw: ratedKw,
        specs: specs,
      );

      // Cache invalidate + reload
      await mapVM.loadEquipments(forceRefresh: true);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${created.name}" eklendi. Model listesinde görünür.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ekipman kaydedilemedi: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Color _accentForType(String type) {
    if (type == 'Güneş Paneli') return Colors.orange;
    if (type == 'HES' || type == 'Hidroelektrik') return const Color(0xFF1DB954);
    return Colors.blueAccent;
  }

  String _hintForType(String type) {
    if (type == 'Güneş Paneli') return 'Panel · Açı · Güç';
    if (type == 'HES' || type == 'Hidroelektrik') return 'Debi · Düşü · Havza';
    return 'Kule · Rotor · Güç';
  }
}

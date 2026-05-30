// lib/features/pins/widgets/edit_equipment_dialog.dart
//
// 2026-05-17 — Kullanıcı-özel ekipman düzenleme / silme dialog'u.
// EquipmentSelectorWidget'tan "Düzenle" butonuyla açılır. Sadece user-owned
// (Equipment.isUserOwned == true) ekipmanlar için anlamlı; sistem ekipmanları
// güncellenemez (backend PUT/DELETE 404 döner).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/shared/widgets/themed_inputs.dart';

class EditEquipmentDialog extends StatefulWidget {
  final Equipment equipment;

  const EditEquipmentDialog({super.key, required this.equipment});

  /// Helper — caller'lar showDialog yerine bunu çağırır. Düzenleme veya
  /// silme yapıldıysa true döner (caller listeyi reload eder).
  static Future<bool> show(BuildContext context, Equipment equipment) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => EditEquipmentDialog(equipment: equipment),
    );
    return result ?? false;
  }

  @override
  State<EditEquipmentDialog> createState() => _EditEquipmentDialogState();
}

class _EditEquipmentDialogState extends State<EditEquipmentDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ratedPowerCtrl;
  // Type-specific spec controller'ları (type'a göre dolan)
  late final TextEditingController _tiltCtrl;
  late final TextEditingController _azimuthCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _panelPowerWCtrl;
  late final TextEditingController _hubHeightCtrl;
  late final TextEditingController _rotorCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final eq = widget.equipment;
    _nameCtrl = TextEditingController(text: eq.name);
    _ratedPowerCtrl = TextEditingController(text: eq.ratedPowerKw.toString());

    // Specs varsa içinden seed et
    final specs = eq.specs ?? {};
    _tiltCtrl = TextEditingController(
        text: specs['tilt']?.toString() ?? '');
    _azimuthCtrl = TextEditingController(
        text: specs['azimuth']?.toString() ?? '');
    _areaCtrl = TextEditingController(
        text: specs['area_m2']?.toString() ?? '');
    _panelPowerWCtrl = TextEditingController(
        text: specs['power_w']?.toString() ?? '');
    _hubHeightCtrl = TextEditingController(
        text: specs['hub_height_m']?.toString() ?? '');
    _rotorCtrl = TextEditingController(
        text: specs['rotor_diameter_m']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ratedPowerCtrl.dispose();
    _tiltCtrl.dispose();
    _azimuthCtrl.dispose();
    _areaCtrl.dispose();
    _panelPowerWCtrl.dispose();
    _hubHeightCtrl.dispose();
    _rotorCtrl.dispose();
    super.dispose();
  }

  double? _parseOptional(TextEditingController c) {
    final v = c.text.trim();
    if (v.isEmpty) return null;
    return double.tryParse(v.replaceAll(',', '.'));
  }

  Map<String, dynamic> _buildSpecs() {
    final type = widget.equipment.type;
    if (type == 'Solar') {
      return {
        if (_tiltCtrl.text.trim().isNotEmpty) 'tilt': _parseOptional(_tiltCtrl),
        if (_azimuthCtrl.text.trim().isNotEmpty)
          'azimuth': _parseOptional(_azimuthCtrl),
        if (_areaCtrl.text.trim().isNotEmpty)
          'area_m2': _parseOptional(_areaCtrl),
        if (_panelPowerWCtrl.text.trim().isNotEmpty)
          'power_w': _parseOptional(_panelPowerWCtrl),
      };
    }
    if (type == 'Wind') {
      return {
        if (_hubHeightCtrl.text.trim().isNotEmpty)
          'hub_height_m': _parseOptional(_hubHeightCtrl),
        if (_rotorCtrl.text.trim().isNotEmpty)
          'rotor_diameter_m': _parseOptional(_rotorCtrl),
        'rated_power_kw': _parseOptional(_ratedPowerCtrl),
      };
    }
    return {};
  }

  Future<void> _handleSave() async {
    final name = _nameCtrl.text.trim();
    final ratedPower = _parseOptional(_ratedPowerCtrl);
    if (name.isEmpty || ratedPower == null || ratedPower <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('İsim ve nominal güç boş bırakılamaz.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final mapVM = Provider.of<MapViewModel>(context, listen: false);
      await api.equipment.updateEquipment(
        equipmentId: widget.equipment.id,
        name: name,
        type: widget.equipment.type,
        ratedPowerKw: ratedPower,
        efficiency: widget.equipment.efficiency,
        costPerUnit: widget.equipment.costPerUnit,
        specs: _buildSpecs(),
      );
      await mapVM.loadEquipments(forceRefresh: true);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"$name" güncellendi.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Güncellenemedi: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ekipman silinsin mi?'),
        content: Text(
          '"${widget.equipment.name}" kalıcı olarak silinecek. '
          'Bu ekipmanı kullanan mevcut pinler etkilenmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final mapVM = Provider.of<MapViewModel>(context, listen: false);
      final ok = await api.equipment.deleteEquipment(widget.equipment.id);
      if (!ok) throw Exception('silme başarısız');
      await mapVM.loadEquipments(forceRefresh: true);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${widget.equipment.name}" silindi.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Silinemedi: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final isSolar = widget.equipment.type == 'Solar';
    final accent = isSolar
        ? Colors.orange
        : widget.equipment.type == 'Wind'
            ? Colors.blueAccent
            : const Color(0xFF1DB954);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Row(
        children: [
          Icon(Icons.edit_note_rounded, color: accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSolar ? 'Panel Tipini Düzenle' : 'Türbin Tipini Düzenle',
              style: TextStyle(color: theme.textColor, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ThemedTextField(
                controller: _nameCtrl,
                label: 'Ekipman Adı',
                theme: theme,
              ),
              const SizedBox(height: 12),
              ThemedTextField(
                controller: _ratedPowerCtrl,
                label: isSolar
                    ? 'Nominal Güç (kW) — toplam'
                    : 'Nominal Güç (kW)',
                isNumber: true,
                theme: theme,
              ),
              const SizedBox(height: 16),
              Text(
                'Teknik Parametreler',
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              if (isSolar) ...[
                Row(children: [
                  Expanded(
                    child: ThemedTextField(
                      controller: _tiltCtrl,
                      label: 'Eğim (°)',
                      isNumber: true,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ThemedTextField(
                      controller: _azimuthCtrl,
                      label: 'Azimuth (°)',
                      isNumber: true,
                      theme: theme,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                ThemedTextField(
                  controller: _areaCtrl,
                  label: 'Alan (m²) — Opsiyonel',
                  isNumber: true,
                  theme: theme,
                ),
                const SizedBox(height: 10),
                ThemedTextField(
                  controller: _panelPowerWCtrl,
                  label: 'Tek Panel Gücü (W) — Opsiyonel',
                  isNumber: true,
                  theme: theme,
                ),
              ] else if (widget.equipment.type == 'Wind') ...[
                Row(children: [
                  Expanded(
                    child: ThemedTextField(
                      controller: _hubHeightCtrl,
                      label: 'Kule Y. (m)',
                      isNumber: true,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ThemedTextField(
                      controller: _rotorCtrl,
                      label: 'Rotor Çapı (m)',
                      isNumber: true,
                      theme: theme,
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isSaving ? null : _handleDelete,
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
          label: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
        ),
        const Spacer(),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: Text('İptal', style: TextStyle(color: theme.secondaryTextColor)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kaydet'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}

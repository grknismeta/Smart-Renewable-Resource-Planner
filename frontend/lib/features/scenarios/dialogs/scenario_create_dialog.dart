import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/core/theme/app_theme.dart';

class ScenarioCreateDialog extends StatefulWidget {
  final ThemeViewModel theme;
  final Scenario? scenarioToEdit;

  const ScenarioCreateDialog({
    super.key,
    required this.theme,
    this.scenarioToEdit,
  });

  @override
  State<ScenarioCreateDialog> createState() => _ScenarioCreateDialogState();
}

class _ScenarioCreateDialogState extends State<ScenarioCreateDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late List<int> _selectedPinIds;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.scenarioToEdit?.name,
    );
    _descController = TextEditingController(
      text: widget.scenarioToEdit?.description,
    );
    _selectedPinIds = [];
    if (widget.scenarioToEdit != null) {
      _selectedPinIds.addAll(widget.scenarioToEdit!.pinIds);
    }

    _startDate =
        widget.scenarioToEdit?.startDate ??
        DateTime.now().add(const Duration(days: -365));
    _endDate = widget.scenarioToEdit?.endDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final pins = mapViewModel.pins;
    final theme = widget.theme;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.scenarioToEdit != null
                  ? 'Senaryoyu Düzenle'
                  : 'Yeni Senaryo Oluştur',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: theme.textColor),
                      decoration: InputDecoration(
                        labelText: 'Senaryo Adı',
                        labelStyle: TextStyle(color: theme.secondaryTextColor),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.secondaryTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descController,
                      style: TextStyle(color: theme.textColor),
                      decoration: InputDecoration(
                        labelText: 'Açıklama (Opsiyonel)',
                        labelStyle: TextStyle(color: theme.secondaryTextColor),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.secondaryTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Kaynakları Seç (Birden fazla seçilebilir)',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.secondaryTextColor.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: pins.isEmpty
                          ? Center(
                              child: Text(
                                "Pin yok",
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: pins.length,
                              itemBuilder: (ctx, i) {
                                final pin = pins[i];
                                final isSelected = _selectedPinIds.contains(
                                  pin.id,
                                );
                                return CheckboxListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  dense: true,
                                  title: Text(
                                    '${pin.name} (${pin.equipmentName ?? pin.type})',
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                  value: isSelected,
                                  activeColor: Colors.blueAccent,
                                  checkColor: Colors.white,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedPinIds.add(pin.id);
                                      } else {
                                        _selectedPinIds.remove(pin.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Başlangıç Tarihi',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        _startDate != null
                            ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                            : 'Tarihi seçin',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(
                        Icons.calendar_today,
                        color: theme.textColor,
                        size: 20,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Bitiş Tarihi',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        _endDate != null
                            ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                            : 'Tarihi seçin',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(
                        Icons.calendar_today,
                        color: theme.textColor,
                        size: 20,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: _startDate ?? DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _endDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'İptal',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _handleSave,
                  child: Text(
                    widget.scenarioToEdit != null ? 'Güncelle' : 'Oluştur',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_nameController.text.isEmpty || _selectedPinIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen isim girin ve en az bir kaynak seçin!'),
        ),
      );
      return;
    }

    final scenarioViewModel = Provider.of<ScenarioViewModel>(
      context,
      listen: false,
    );

    final scenarioCreate = ScenarioCreate(
      name: _nameController.text,
      description: _descController.text.isEmpty ? null : _descController.text,
      pinIds: _selectedPinIds,
      startDate: _startDate,
      endDate: _endDate,
    );

    try {
      Navigator.pop(context); // Close dialog first

      // Show temporary loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.scenarioToEdit != null
                ? 'Senaryo güncelleniyor...'
                : 'Senaryo oluşturuluyor...',
          ),
        ),
      );

      if (widget.scenarioToEdit != null) {
        await scenarioViewModel.updateScenario(
          widget.scenarioToEdit!.id,
          scenarioCreate,
        );
      } else {
        await scenarioViewModel.createScenario(scenarioCreate);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.scenarioToEdit != null
                  ? 'Senaryo güncellendi!'
                  : 'Senaryo başarıyla oluşturuldu!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }
}

// lib/features/reports/widgets/dialogs/scenario_edit_dialog.dart
//
// 2026-05-25 (G5+G6): Senaryo düzenleme dialog'u — Reports → Senaryo header'da
// "Düzenle" butonuyla açılır. Tüm alanlar düzenlenebilir:
//   • Ad (name)
//   • Açıklama (description, opsiyonel)
//   • Başlangıç + Bitiş tarihi (showDateRangePicker)
//   • Pin listesi (checkbox grid — tipe göre renkli)
//
// Submit → `_ScenarioEditResult` döner, caller `vm.updateScenarioFields` ile
// backend'e gönderir + otomatik recalculate.

import 'package:flutter/material.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/shared/widgets/srrp_date_picker.dart';

class ScenarioEditResult {
  final String name;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<int> pinIds;

  const ScenarioEditResult({
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    required this.pinIds,
  });
}

class ScenarioEditDialog extends StatefulWidget {
  final Scenario scenario;
  final List<Pin> allPins;

  const ScenarioEditDialog({
    super.key,
    required this.scenario,
    required this.allPins,
  });

  @override
  State<ScenarioEditDialog> createState() => _ScenarioEditDialogState();
}

class _ScenarioEditDialogState extends State<ScenarioEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  DateTime? _startDate;
  DateTime? _endDate;
  late Set<int> _selectedPinIds;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.scenario.name);
    _descCtrl = TextEditingController(text: widget.scenario.description ?? '');
    _startDate = widget.scenario.startDate;
    _endDate = widget.scenario.endDate;
    _selectedPinIds = widget.scenario.pinIds.toSet();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Color _typeColor(String type) => switch (type) {
        'Güneş Paneli' => const Color(0xFFF59E0B),
        'Rüzgar Türbini' => const Color(0xFF3B82F6),
        'Hidroelektrik' => const Color(0xFF06B6D4),
        _ => Colors.white54,
      };

  String _fmtDate(DateTime? d) => d == null
      ? 'Seç'
      : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// 2026-05-26 (N1): "Süresiz" → end_date null → backend bugüne kadar üretir.
  /// Kullanıcı end_date'i pickedan kaldırabilsin diye ayrı bir toggle.
  bool get _isOpenEnded => _endDate == null;

  Future<void> _pickDates() async {
    // 2026-05-27 (N5): Flutter showDateRangePicker → SrrpDateRangePicker
    // (Google takvim tarzı: yıl → ay → gün hiyerarşisi, kompakt single dialog).
    final now = DateTime.now();
    final firstDate = DateTime(2015);
    final lastDate = DateTime(now.year + 30);
    final result = await showSrrpDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialStart: _startDate ?? now,
      initialEnd: _endDate,
      allowOpenEnd: true,
      title: 'Senaryo Tarih Aralığı',
    );
    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
    }
  }

  /// N1: "Süresiz" toggle — end_date'i null'a çek; tekrar tıklarsa
  /// start_date + 1 yıl varsayılan dön.
  void _toggleOpenEnded() {
    setState(() {
      if (_isOpenEnded) {
        // Süresiz → tarihli'ye dön (varsayılan: start + 1 yıl)
        final base = _startDate ?? DateTime.now();
        _endDate = DateTime(base.year + 1, base.month, base.day);
      } else {
        _endDate = null;
      }
    });
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senaryo adı boş olamaz')),
      );
      return;
    }
    if (_selectedPinIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az 1 pin seçili olmalı')),
      );
      return;
    }
    Navigator.of(context).pop(
      ScenarioEditResult(
        name: name,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        pinIds: _selectedPinIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const Divider(color: Colors.white12, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Senaryo Adı'),
                    const SizedBox(height: 5),
                    _textField(_nameCtrl, hint: 'örn. Marmara GES 2026'),
                    const SizedBox(height: 12),
                    _label('Açıklama (opsiyonel)'),
                    const SizedBox(height: 5),
                    _textField(_descCtrl, hint: 'Kısa not...', maxLines: 2),
                    const SizedBox(height: 14),
                    _label('Tarih Aralığı (Ufuk)'),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: _pickDates,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range_rounded,
                                size: 16, color: Colors.cyanAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isOpenEnded
                                    ? '${_fmtDate(_startDate)}  →  Süresiz'
                                    : '${_fmtDate(_startDate)}  →  ${_fmtDate(_endDate)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // N1: "Süresiz" toggle — end_date null. Backend bugüne
                    // kadar üretir, yeni veri geldikçe senaryo genişler.
                    InkWell(
                      onTap: _toggleOpenEnded,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isOpenEnded
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 16,
                              color: _isOpenEnded
                                  ? Colors.cyanAccent
                                  : Colors.white.withValues(alpha: 0.55),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Süresiz — bugüne kadar üret',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _label('Pin Seçimi'),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedPinIds.length} / ${widget.allPins.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10.5,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            if (_selectedPinIds.length == widget.allPins.length) {
                              _selectedPinIds.clear();
                            } else {
                              _selectedPinIds =
                                  widget.allPins.map((p) => p.id).toSet();
                            }
                          }),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 0),
                            minimumSize: const Size(0, 28),
                          ),
                          child: Text(
                            _selectedPinIds.length == widget.allPins.length
                                ? 'Hiçbiri'
                                : 'Tümü',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (widget.allPins.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Text(
                          'Pin yok — haritadan santral ekle.',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      )
                    else
                      ..._buildPinList(),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded,
              size: 18, color: Colors.cyanAccent),
          const SizedBox(width: 8),
          const Text(
            'Senaryoyu Düzenle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Colors.white54),
            tooltip: 'Kapat',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal',
                style: TextStyle(color: Colors.white60)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded, size: 15),
            label: const Text('Kaydet ve Yeniden Hesapla'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.50),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );

  Widget _textField(TextEditingController c,
      {String? hint, int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.30),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.cyanAccent.withValues(alpha: 0.50),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPinList() {
    // Pin'leri tipe göre grupla
    final byType = <String, List<Pin>>{};
    for (final p in widget.allPins) {
      byType.putIfAbsent(p.type, () => []).add(p);
    }
    final tiles = <Widget>[];
    byType.forEach((type, pins) {
      final c = _typeColor(type);
      tiles.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              '$type · ${pins.length}',
              style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ));
      for (final p in pins) {
        final sel = _selectedPinIds.contains(p.id);
        tiles.add(
          InkWell(
            onTap: () => setState(() {
              if (sel) {
                _selectedPinIds.remove(p.id);
              } else {
                _selectedPinIds.add(p.id);
              }
            }),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? c.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: sel
                      ? c.withValues(alpha: 0.40)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: sel,
                      onChanged: (_) => setState(() {
                        if (sel) {
                          _selectedPinIds.remove(p.id);
                        } else {
                          _selectedPinIds.add(p.id);
                        }
                      }),
                      visualDensity: const VisualDensity(
                          horizontal: -4, vertical: -4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeColor: c,
                      checkColor: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${p.capacityMw.toStringAsFixed(2)} MW',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (p.city != null && p.city!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '· ${p.city}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }
    });
    return tiles;
  }
}

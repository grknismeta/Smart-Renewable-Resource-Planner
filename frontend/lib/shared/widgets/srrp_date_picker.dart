// lib/shared/widgets/srrp_date_picker.dart
//
// 2026-05-27 (N5) — Google Calendar tarzı tarih seçici.
// ----------------------------------------------------------------------------
// Hiyerarşik navigasyon:
//   • Gün grid (default)         — 7×6 takvim
//   • Ay grid                    — başlığa tıklayınca açılır (3×4)
//   • Yıl grid                   — ay başlığına tıklayınca açılır (3×4 onar yıllık)
//
// Mode'lar:
//   • Single                     — tek tarih seç
//   • Range                      — iki tıklama: ilk start, ikinci end (start≥end
//                                  ise swap). `allowOpenEnd` ile bitişi süresiz
//                                  bırakma seçeneği.
//
// Kullanım:
//   final range = await showSrrpDateRangePicker(
//     context: context,
//     initialStart: DateTime(2024, 1, 1),
//     initialEnd:   DateTime(2025, 12, 31),
//     firstDate:    DateTime(2015, 1, 1),
//     lastDate:     DateTime(2055, 12, 31),
//     allowOpenEnd: true,
//   );
//   // range.start, range.end (end null → "süresiz")
//
//   final single = await showSrrpDatePicker(
//     context: context,
//     initialDate: DateTime.now(),
//     firstDate:   DateTime(2015),
//     lastDate:    DateTime(2030),
//   );

import 'package:flutter/material.dart';

/// Range picker dönüş — `end` null → "süresiz" anlamı taşır (caller
/// `allowOpenEnd:true` verdiyse).
class SrrpDateRange {
  final DateTime start;
  final DateTime? end;
  const SrrpDateRange({required this.start, this.end});
}

/// Range picker dialog'u — `Future&lt;SrrpDateRange?&gt;` döner; null = İptal.
Future<SrrpDateRange?> showSrrpDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialStart,
  DateTime? initialEnd,
  bool allowOpenEnd = false,
  String title = 'Tarih Aralığı Seç',
}) {
  return showDialog<SrrpDateRange>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _SrrpDatePickerDialog(
      mode: _PickerMode.range,
      title: title,
      firstDate: firstDate,
      lastDate: lastDate,
      initialStart: initialStart,
      initialEnd: initialEnd,
      allowOpenEnd: allowOpenEnd,
    ),
  );
}

/// Single date picker dialog'u — `Future&lt;DateTime?&gt;` döner.
Future<DateTime?> showSrrpDatePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialDate,
  String title = 'Tarih Seç',
}) async {
  final res = await showDialog<SrrpDateRange>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _SrrpDatePickerDialog(
      mode: _PickerMode.single,
      title: title,
      firstDate: firstDate,
      lastDate: lastDate,
      initialStart: initialDate,
      allowOpenEnd: false,
    ),
  );
  return res?.start;
}

enum _PickerMode { single, range }
enum _ViewMode { day, month, year }

class _SrrpDatePickerDialog extends StatefulWidget {
  final _PickerMode mode;
  final String title;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final bool allowOpenEnd;

  const _SrrpDatePickerDialog({
    required this.mode,
    required this.title,
    required this.firstDate,
    required this.lastDate,
    this.initialStart,
    this.initialEnd,
    this.allowOpenEnd = false,
  });

  @override
  State<_SrrpDatePickerDialog> createState() => _SrrpDatePickerDialogState();
}

class _SrrpDatePickerDialogState extends State<_SrrpDatePickerDialog> {
  late DateTime _displayedMonth; // ayın 1'i
  late _ViewMode _view;
  DateTime? _start;
  DateTime? _end;
  bool _openEnd = false;

  static const _monthsTr = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _monthsShortTr = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  static const _weekdaysTr = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart != null ? _dateOnly(widget.initialStart!) : null;
    _end = widget.initialEnd != null ? _dateOnly(widget.initialEnd!) : null;
    _openEnd = widget.allowOpenEnd &&
        widget.mode == _PickerMode.range &&
        widget.initialEnd == null;
    final ref = _start ?? DateTime.now();
    _displayedMonth = DateTime(ref.year, ref.month);
    _view = _ViewMode.day;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _onDayTap(DateTime day) {
    setState(() {
      if (widget.mode == _PickerMode.single) {
        _start = day;
        return;
      }
      // Range mode
      if (_start == null || (_end != null && !_openEnd)) {
        // Yeni seçim — sadece start
        _start = day;
        _end = null;
      } else {
        // Start var, end yok → end ata. Eğer day < start ise swap.
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
        _openEnd = false; // end seçildi
      }
    });
  }

  void _toggleOpenEnd() {
    setState(() {
      _openEnd = !_openEnd;
      if (_openEnd) {
        _end = null;
      }
    });
  }

  void _confirm() {
    if (_start == null) {
      Navigator.of(context).pop();
      return;
    }
    // Range modunda end gerekli (open-end değilse)
    if (widget.mode == _PickerMode.range && _end == null && !_openEnd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bitiş tarihini seç (veya "Süresiz" seç).'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(SrrpDateRange(start: _start!, end: _end));
  }

  // ── View navigation ──────────────────────────────────────────────────────

  void _showMonthGrid() => setState(() => _view = _ViewMode.month);
  void _showYearGrid() => setState(() => _view = _ViewMode.year);

  void _shiftMonth(int delta) {
    setState(() {
      final m = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
      if (m.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month))) {
        return;
      }
      if (m.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month))) {
        return;
      }
      _displayedMonth = m;
    });
  }

  void _shiftYear(int delta) {
    setState(() {
      final y = _displayedMonth.year + delta;
      if (y < widget.firstDate.year || y > widget.lastDate.year) return;
      _displayedMonth = DateTime(y, _displayedMonth.month);
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleBar(),
            const Divider(color: Colors.white12, height: 1),
            _buildHeader(),
            const SizedBox(height: 6),
            Expanded(child: _buildBody()),
            const Divider(color: Colors.white12, height: 1),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, size: 16, color: Colors.cyanAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18,
                color: Colors.white54),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'İptal',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  /// Header — ay/yıl başlığı + back/forward okları.
  /// Day view: "Mart 2024" başlık (tıklanır → month grid), ← → ay ileri/geri
  /// Month view: "2024" başlık (tıklanır → year grid), ← → yıl ileri/geri
  /// Year view: "2020-2029" başlık (statik), ← → decade kayar
  Widget _buildHeader() {
    String label;
    VoidCallback? onLabelTap;
    VoidCallback onLeft;
    VoidCallback onRight;
    switch (_view) {
      case _ViewMode.day:
        label = '${_monthsTr[_displayedMonth.month - 1]} ${_displayedMonth.year}';
        onLabelTap = _showMonthGrid;
        onLeft = () => _shiftMonth(-1);
        onRight = () => _shiftMonth(1);
      case _ViewMode.month:
        label = '${_displayedMonth.year}';
        onLabelTap = _showYearGrid;
        onLeft = () => _shiftYear(-1);
        onRight = () => _shiftYear(1);
      case _ViewMode.year:
        final decadeStart = (_displayedMonth.year ~/ 10) * 10;
        label = '$decadeStart - ${decadeStart + 9}';
        onLabelTap = null;
        onLeft = () => _shiftYear(-10);
        onRight = () => _shiftYear(10);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: Colors.white70),
            onPressed: onLeft,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: Center(
              child: InkWell(
                onTap: onLabelTap,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (onLabelTap != null) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 18,
                          color: Colors.cyanAccent,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: Colors.white70),
            onPressed: onRight,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_view) {
      case _ViewMode.day:
        return _buildDayGrid();
      case _ViewMode.month:
        return _buildMonthGrid();
      case _ViewMode.year:
        return _buildYearGrid();
    }
  }

  // ── Day grid ─────────────────────────────────────────────────────────────

  Widget _buildDayGrid() {
    final y = _displayedMonth.year;
    final m = _displayedMonth.month;
    final firstOfMonth = DateTime(y, m, 1);
    // Pazartesi başlangıç → weekday 1=Mon, 7=Sun. firstWeekday - 1 = leading blanks
    final leading = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          // Gün adları
          Row(
            children: _weekdaysTr
                .map((w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          // Gün grid
          ...List.generate(rows, (rowIdx) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                children: List.generate(7, (colIdx) {
                  final cellIdx = rowIdx * 7 + colIdx;
                  final dayNum = cellIdx - leading + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 34));
                  }
                  final day = DateTime(y, m, dayNum);
                  return Expanded(child: _buildDayCell(day));
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final disabled = day.isBefore(_dateOnly(widget.firstDate)) ||
        day.isAfter(_dateOnly(widget.lastDate));
    final isStart = _start != null && _isSameDay(day, _start!);
    final isEnd = _end != null && _isSameDay(day, _end!);
    final inRange = widget.mode == _PickerMode.range &&
        _start != null &&
        _end != null &&
        day.isAfter(_start!) &&
        day.isBefore(_end!);
    final isToday = _isSameDay(day, DateTime.now());

    Color bg;
    Color fg;
    if (isStart || isEnd) {
      bg = Colors.cyanAccent;
      fg = Colors.black;
    } else if (inRange) {
      bg = Colors.cyanAccent.withValues(alpha: 0.18);
      fg = Colors.white;
    } else {
      bg = Colors.transparent;
      fg = disabled ? Colors.white24 : Colors.white;
    }

    return InkWell(
      onTap: disabled ? null : () => _onDayTap(day),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: (isToday && !isStart && !isEnd)
              ? Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5))
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: (isStart || isEnd) ? FontWeight.w800 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Month grid ───────────────────────────────────────────────────────────

  Widget _buildMonthGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 2.0,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: List.generate(12, (i) {
          final monthNum = i + 1;
          final selected = _displayedMonth.month == monthNum;
          final inFirst = DateTime(_displayedMonth.year, monthNum)
              .isAfter(DateTime(widget.firstDate.year,
                      widget.firstDate.month - 1));
          final inLast = DateTime(_displayedMonth.year, monthNum)
              .isBefore(DateTime(widget.lastDate.year,
                      widget.lastDate.month + 1));
          final enabled = inFirst && inLast;
          return InkWell(
            onTap: enabled
                ? () => setState(() {
                      _displayedMonth =
                          DateTime(_displayedMonth.year, monthNum);
                      _view = _ViewMode.day;
                    })
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? Colors.cyanAccent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? Colors.cyanAccent.withValues(alpha: 0.50)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _monthsShortTr[i],
                style: TextStyle(
                  color: enabled
                      ? (selected ? Colors.cyanAccent : Colors.white)
                      : Colors.white24,
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Year grid ────────────────────────────────────────────────────────────

  Widget _buildYearGrid() {
    final decadeStart = (_displayedMonth.year ~/ 10) * 10;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 2.0,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: List.generate(12, (i) {
          final year = decadeStart + i - 1; // -1 .. +10
          final enabled =
              year >= widget.firstDate.year && year <= widget.lastDate.year;
          final selected = year == _displayedMonth.year;
          return InkWell(
            onTap: enabled
                ? () => setState(() {
                      _displayedMonth =
                          DateTime(year, _displayedMonth.month);
                      _view = _ViewMode.month;
                    })
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? Colors.cyanAccent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? Colors.cyanAccent.withValues(alpha: 0.50)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$year',
                style: TextStyle(
                  color: enabled
                      ? (selected ? Colors.cyanAccent : Colors.white)
                      : Colors.white24,
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow(),
          if (widget.allowOpenEnd && widget.mode == _PickerMode.range) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: _toggleOpenEnd,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _openEnd
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 16,
                      color: _openEnd
                          ? Colors.cyanAccent
                          : Colors.white.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Süresiz — bugüne kadar üret',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Tamam'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    String fmt(DateTime? d) => d == null
        ? '—'
        : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    if (widget.mode == _PickerMode.single) {
      return Row(
        children: [
          _summaryChip('Tarih', fmt(_start)),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _summaryChip('Başlangıç', fmt(_start))),
        const SizedBox(width: 6),
        Expanded(
          child: _summaryChip(
            'Bitiş',
            _openEnd ? 'Süresiz' : fmt(_end),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

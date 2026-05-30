// lib/features/map/widgets/panels/time_simulation_panel.dart
//
// Aşama 1.B (yeniden) — Modern Zaman Simülasyonu paneli.
//
// Eski `time_slider_panel.dart` yerine geldi. Artık:
//   • Tek `TimeSimulationController` state'inden beslenir
//   • Pure Dart timer (JS bridge yok)
//   • Tek görsel dil: ilçe choropleth (her frame'de polygon update)
//   • Tek legend (animasyon aktifken choropleth legend "frame değeri" gösterir)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/map/animation/time_simulation_controller.dart';
import 'package:frontend/shared/widgets/srrp_date_picker.dart';

class TimeSimulationPanel extends StatelessWidget {
  final ThemeViewModel theme;
  const TimeSimulationPanel({super.key, required this.theme});

  static const _metrics = <(String, String)>[
    ('wind',        'Rüzgar'),
    ('temperature', 'Sıcaklık'),
    ('radiation',   'Işınım'),
  ];
  static const _intervals = <(String, String)>[
    ('daily',  'Günlük'),
    ('hourly', 'Saatlik'),
    // T-6: uzun pencere (precompute) — tarih aralığı yerine "Son N yıl"
    ('weekly',  'Haftalık ⚡'),
    ('monthly', 'Aylık ⚡'),
  ];

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TimeSimulationController>();
    final cs = theme.cardColor;
    final tc = theme.textColor;
    final sc = theme.secondaryTextColor;

    // 2026-05-25 (F1): Dar ekranda (1080px telefonda ~393dp) playbackRow tek
    // satıra sığmıyordu — RIGHT OVERFLOWED BY 61 PIXELS. MediaQuery ile aktif
    // ekran genişliğine göre cap; ayrıca _playbackRow LayoutBuilder ile
    // <380 ise speed slider'ını alt satıra atıyor.
    final screenW = MediaQuery.of(context).size.width;
    final maxPanelW = screenW < 700 ? screenW - 24.0 : 660.0;
    return Container(
      constraints: BoxConstraints(maxWidth: maxPanelW),
      decoration: BoxDecoration(
        color: cs.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context, tc, sc, ctrl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: _configRow(context, tc, sc, ctrl),
          ),
          if (ctrl.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                ctrl.error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          Divider(color: sc.withValues(alpha: 0.15), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: _playbackRow(context, tc, sc, ctrl),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: _scrubber(context, sc, ctrl),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _timestampRow(sc, ctrl),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext ctx, Color tc, Color sc, TimeSimulationController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 4),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline_rounded,
              color: Colors.cyanAccent, size: 18),
          const SizedBox(width: 8),
          Text('Zaman Simülasyonu',
              style: TextStyle(color: tc, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          if (ctrl.hasData)
            _iconBtn(Icons.restart_alt_rounded, sc, () {
              ctrl.pause();
              ctrl.seek(0);
            }, tooltip: 'Başa Al'),
          _iconBtn(Icons.close_rounded, sc, () => ctrl.close(), tooltip: 'Kapat'),
        ],
      ),
    );
  }

  Widget _configRow(BuildContext ctx, Color tc, Color sc, TimeSimulationController ctrl) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Uzun pencere modunda tarih aralığı gizlenir (precompute "Son N yıl").
        if (!ctrl.isLongWindow) ...[
          _datePicker(ctx,
              label: 'Başlangıç',
              date: ctrl.startDate,
              tc: tc, sc: sc,
              onPick: ctrl.setStartDate),
          Text('–', style: TextStyle(color: sc)),
          _datePicker(ctx,
              label: 'Bitiş',
              date: ctrl.endDate,
              tc: tc, sc: sc,
              onPick: ctrl.setEndDate),
        ],
        _dropdownChip(
            value: ctrl.metric,
            items: _metrics,
            tc: tc, sc: sc,
            onChanged: ctrl.setMetric),
        _dropdownChip(
            value: ctrl.interval,
            items: _intervals,
            tc: tc, sc: sc,
            onChanged: ctrl.setInterval),
        // T-6: uzun pencerede "Son N yıl" seçici
        if (ctrl.isLongWindow)
          _dropdownChip(
              value: '${ctrl.yearsWindow}',
              items: const [('2', 'Son 2 Yıl'), ('5', 'Son 5 Yıl'), ('10', 'Son 10 Yıl')],
              tc: tc, sc: sc,
              onChanged: (v) => ctrl.setYearsWindow(int.tryParse(v) ?? 5)),
        _loadButton(ctrl),
      ],
    );
  }

  Widget _datePicker(
    BuildContext ctx, {
    required String label,
    required DateTime date,
    required Color tc,
    required Color sc,
    required ValueChanged<DateTime> onPick,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      // N5: SrrpDatePicker (year/month/day grid)
      onTap: () async {
        final picked = await showSrrpDatePicker(
          context: ctx,
          initialDate: date,
          firstDate: DateTime(2015),
          lastDate: DateTime(2027, 12, 31),
          title: label,
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sc.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sc.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 13, color: sc),
            const SizedBox(width: 5),
            Text(_fmt(date),
                style: TextStyle(color: tc, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _dropdownChip({
    required String value,
    required List<(String, String)> items,
    required Color tc,
    required Color sc,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: sc.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: sc.withValues(alpha: 0.2)),
      ),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1A1A2E),
        style: TextStyle(color: tc, fontSize: 12),
        items: items
            .map((e) => DropdownMenuItem<String>(
                  value: e.$1,
                  child: Text(e.$2, style: TextStyle(color: tc, fontSize: 12)),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _loadButton(TimeSimulationController ctrl) {
    if (ctrl.status == TimeSimStatus.loading) {
      return const SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.cyanAccent),
      );
    }
    final hasError = ctrl.dateRangeError != null;
    return ElevatedButton.icon(
      onPressed: hasError ? null : ctrl.load,
      icon: const Icon(Icons.download_rounded, size: 15),
      label: const Text('Yükle', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan.shade800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
      ),
    );
  }

  Widget _playbackRow(BuildContext ctx, Color tc, Color sc, TimeSimulationController ctrl) {
    final hasData = ctrl.hasData;
    final controls = [
      _playBtn(Icons.skip_previous_rounded, () => ctrl.seek(0),
          enabled: hasData, sc: sc),
      _playBtn(Icons.fast_rewind_rounded, () => ctrl.stepBy(-5),
          enabled: hasData, sc: sc),
      // ▶/⏸ Merkez
      GestureDetector(
        onTap: hasData
            ? () => ctrl.isPlaying ? ctrl.pause() : ctrl.play()
            : null,
        child: Container(
          width: 40, height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: hasData
                ? Colors.cyanAccent.withValues(alpha: 0.18)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: hasData
                  ? Colors.cyanAccent.withValues(alpha: 0.6)
                  : sc.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            ctrl.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: hasData ? Colors.cyanAccent : sc,
            size: 22,
          ),
        ),
      ),
      _playBtn(Icons.fast_forward_rounded, () => ctrl.stepBy(5),
          enabled: hasData, sc: sc),
      _playBtn(Icons.skip_next_rounded, () => ctrl.seek(ctrl.totalFrames - 1),
          enabled: hasData, sc: sc),
    ];

    Widget speedControl({bool expanded = true}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed_rounded, color: sc, size: 14),
            const SizedBox(width: 4),
            SizedBox(
              width: expanded ? 120 : 90,
              child: SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.cyanAccent,
                  inactiveTrackColor: sc.withValues(alpha: 0.2),
                  thumbColor: Colors.cyanAccent,
                ),
                child: Slider(
                  value: ctrl.speedFps.clamp(1.0, 20.0),
                  min: 1, max: 20, divisions: 19,
                  onChanged: ctrl.setSpeed,
                ),
              ),
            ),
            Text('${ctrl.speedFps.toInt()} fps',
                style: TextStyle(color: sc, fontSize: 11)),
          ],
        );

    // 2026-05-25 (F1): Dar ekranda (<380dp) playbackRow taşıyordu. Şimdi
    // LayoutBuilder ile sığmıyorsa speed kontrolü alta atılıyor.
    return LayoutBuilder(builder: (lctx, c) {
      final compact = c.maxWidth < 380;
      if (compact) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: controls,
            ),
            const SizedBox(height: 4),
            speedControl(expanded: false),
          ],
        );
      }
      return Row(
        children: [
          ...controls,
          const Spacer(),
          speedControl(),
        ],
      );
    });
  }

  Widget _scrubber(BuildContext ctx, Color sc, TimeSimulationController ctrl) {
    final total = ctrl.totalFrames;
    if (total == 0) {
      return LinearProgressIndicator(
        backgroundColor: sc.withValues(alpha: 0.15),
        valueColor: const AlwaysStoppedAnimation(Colors.cyanAccent),
        value: ctrl.status == TimeSimStatus.loading ? null : 0,
      );
    }
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(ctx).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.cyanAccent,
              inactiveTrackColor: const Color(0xFF2A4050),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: ctrl.currentFrame.toDouble(),
              min: 0, max: (total - 1).toDouble(),
              divisions: total > 1 ? total - 1 : 1,
              onChanged: (v) => ctrl.seek(v.round()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${ctrl.currentFrame + 1}/$total',
            style: TextStyle(color: sc, fontSize: 11)),
      ],
    );
  }

  Widget _timestampRow(Color sc, TimeSimulationController ctrl) {
    return Row(
      children: [
        const Icon(Icons.access_time_rounded, size: 13, color: Colors.cyanAccent),
        const SizedBox(width: 5),
        Text(
          ctrl.currentTimestamp.isNotEmpty ? ctrl.currentTimestamp : '—',
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (ctrl.rangeHint.isNotEmpty)
          Text(ctrl.rangeHint, style: TextStyle(color: sc, fontSize: 10)),
      ],
    );
  }

  Widget _playBtn(IconData icon, VoidCallback onTap,
      {required bool enabled, required Color sc}) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: enabled ? sc.withValues(alpha: 0.85) : sc.withValues(alpha: 0.3),
      onPressed: enabled ? onTap : null,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap,
      {String? tooltip}) {
    final btn = IconButton(
      icon: Icon(icon, size: 18),
      color: color,
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }
}

import 'package:flutter/material.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

/// Zaman Simülasyonu paneli — harita üzerinde hava durumu animasyonu oynatır.
///
/// Layout (bottom floating, ≤640px geniş):
/// ┌─────────────────────────────────────────────────────┐
/// │  🎬 Zaman Simülasyonu          [Sıfırla]  [✕]      │
/// │  Başlangıç: [date]   Bitiş: [date]                 │
/// │  Metrik: [▼]   Aralık: [▼]         [YÜKLE]        │
/// │─────────────────────────────────────────────────────│
/// │  [⏮] [◀] [▶/⏸] [▶] [⏭]   Hız: ●───  5 fps       │
/// │  [████████████░░░░░░░░░]  45/365                   │
/// │  📅 2024-02-14                    2015–2024 günlük  │
/// └─────────────────────────────────────────────────────┘
class TimeSliderPanel extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;

  const TimeSliderPanel({
    super.key,
    required this.theme,
    required this.mapViewModel,
  });

  // ── Metrik seçenekleri ─────────────────────────────────────────────────────
  static const _metrics = <(String, String)>[
    ('wind',        'Rüzgar'),
    ('temperature', 'Sıcaklık'),
    ('radiation',   'Işınım'),
  ];

  // ── Aralık seçenekleri ─────────────────────────────────────────────────────
  static const _intervals = <(String, String)>[
    ('daily',  'Günlük'),
    ('hourly', 'Saatlik'),
  ];

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final vm = mapViewModel;
    final cs = theme.cardColor;
    final tc = theme.textColor;
    final sc = theme.secondaryTextColor;

    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      decoration: BoxDecoration(
        color: cs.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık
          _buildHeader(context, tc, sc, vm),
          // Tarih + Metrik + Yükle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _buildConfigRow(context, tc, sc, vm),
          ),
          // Hata
          if (vm.animError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                vm.animError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          Divider(color: sc.withValues(alpha: 0.15), height: 1),
          // Oynatma
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildPlaybackRow(context, tc, sc, vm),
          ),
          // Scrubber
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _buildScrubber(context, tc, sc, vm),
          ),
          // Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildTimestampRow(sc, vm),
          ),
        ],
      ),
    );
  }

  // ── Başlık satırı ──────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext ctx, Color tc, Color sc, MapViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline_rounded,
              color: Colors.cyanAccent, size: 18),
          const SizedBox(width: 8),
          Text('Zaman Simülasyonu',
              style: TextStyle(color: tc, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          if (vm.animTotalFrames > 0)
            _iconBtn(Icons.restart_alt_rounded, sc,
                () { vm.pauseAnimation(); vm.seekAnimation(0); },
                tooltip: 'Başa Al'),
          _iconBtn(Icons.close_rounded, sc,
              () => vm.toggleAnimationMode(),
              tooltip: 'Kapat'),
        ],
      ),
    );
  }

  // ── Yapılandırma satırı ─────────────────────────────────────────────────────
  Widget _buildConfigRow(BuildContext ctx, Color tc, Color sc, MapViewModel vm) {
    final dateError = vm.animDateRangeError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _datePicker(ctx,
                label: 'Başlangıç',
                date: vm.animStartDate,
                tc: tc, sc: sc,
                onPick: (d) => vm.setAnimDateRange(d, vm.animEndDate)),
            Text('–', style: TextStyle(color: sc)),
            _datePicker(ctx,
                label: 'Bitiş',
                date: vm.animEndDate,
                tc: tc, sc: sc,
                onPick: (d) => vm.setAnimDateRange(vm.animStartDate, d)),
            _dropdownChip(
                value: vm.animMetric,
                items: _metrics,
                tc: tc, sc: sc,
                onChanged: vm.setAnimMetric),
            _dropdownChip(
                value: vm.animInterval,
                items: _intervals,
                tc: tc, sc: sc,
                onChanged: vm.setAnimInterval),
            _loadButton(vm),
          ],
        ),
        if (dateError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              dateError,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
            ),
          ),
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
      onTap: () async {
        final picked = await showDatePicker(
          context: ctx,
          initialDate: date,
          firstDate: DateTime(2015),
          lastDate: DateTime(2026, 12, 31),
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
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }

  Widget _loadButton(MapViewModel vm) {
    if (vm.animIsLoading) {
      return const SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.cyanAccent),
      );
    }
    final hasError = vm.animDateRangeError != null;
    return ElevatedButton.icon(
      onPressed: hasError ? null : () => vm.loadAnimationData(),
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

  // ── Oynatma kontrolleri ─────────────────────────────────────────────────────
  Widget _buildPlaybackRow(BuildContext ctx, Color tc, Color sc, MapViewModel vm) {
    final hasData = vm.animTotalFrames > 0;
    return Row(
      children: [
        _playBtn(Icons.skip_previous_rounded,
            () => vm.seekAnimation(0), enabled: hasData, sc: sc),
        _playBtn(Icons.fast_rewind_rounded,
            () => vm.seekAnimation(vm.animCurrentFrame - 5), enabled: hasData, sc: sc),
        // ▶/⏸ Merkez butonu
        GestureDetector(
          onTap: hasData
              ? () => vm.animIsPlaying ? vm.pauseAnimation() : vm.playAnimation()
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
              vm.animIsPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: hasData ? Colors.cyanAccent : sc,
              size: 22,
            ),
          ),
        ),
        _playBtn(Icons.fast_forward_rounded,
            () => vm.seekAnimation(vm.animCurrentFrame + 5), enabled: hasData, sc: sc),
        _playBtn(Icons.skip_next_rounded,
            () => vm.seekAnimation(vm.animTotalFrames - 1), enabled: hasData, sc: sc),
        const Spacer(),
        // Hız slider
        Icon(Icons.speed_rounded, color: sc, size: 14),
        const SizedBox(width: 4),
        SizedBox(
          width: 90,
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
              value: vm.animSpeedFps.clamp(1.0, 20.0),
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: vm.setAnimSpeed,
            ),
          ),
        ),
        Text('${vm.animSpeedFps.toInt()} fps',
            style: TextStyle(color: sc, fontSize: 11)),
      ],
    );
  }

  // ── Frame scrubber ──────────────────────────────────────────────────────────
  Widget _buildScrubber(BuildContext ctx, Color tc, Color sc, MapViewModel vm) {
    final total = vm.animTotalFrames;
    if (total == 0) {
      return LinearProgressIndicator(
        backgroundColor: sc.withValues(alpha: 0.15),
        valueColor: const AlwaysStoppedAnimation(Colors.cyanAccent),
        value: vm.animIsLoading ? null : 0,
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
              value: vm.animCurrentFrame.toDouble(),
              min: 0,
              max: (total - 1).toDouble(),
              divisions: total > 1 ? total - 1 : 1,
              onChanged: (v) => vm.seekAnimation(v.round()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${vm.animCurrentFrame + 1}/$total',
            style: TextStyle(color: sc, fontSize: 11)),
      ],
    );
  }

  // ── Timestamp + aralık bilgisi ──────────────────────────────────────────────
  Widget _buildTimestampRow(Color sc, MapViewModel vm) {
    return Row(
      children: [
        const Icon(Icons.access_time_rounded, size: 13, color: Colors.cyanAccent),
        const SizedBox(width: 5),
        Text(
          vm.animCurrentTimestamp.isNotEmpty ? vm.animCurrentTimestamp : '—',
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (vm.animRangeInfo.isNotEmpty)
          Text(vm.animRangeInfo, style: TextStyle(color: sc, fontSize: 10)),
      ],
    );
  }

  // ── Yardımcılar ─────────────────────────────────────────────────────────────

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

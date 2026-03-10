import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

/// Harita üzerinde tarih/saat seçimi yapan yüzen kart widget'ı.
/// Seçilen tarih MapViewModel.loadWeatherForTime() ile aktarılır.
class MapDatePickerWidget extends StatefulWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;

  const MapDatePickerWidget({
    super.key,
    required this.theme,
    required this.mapViewModel,
  });

  @override
  State<MapDatePickerWidget> createState() => _MapDatePickerWidgetState();
}

class _MapDatePickerWidgetState extends State<MapDatePickerWidget>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  static final _dateFmt = DateFormat('dd.MM.yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  /// Tarih seçimi
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = widget.mapViewModel.selectedTime;

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4ECDC4),
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E2E),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      final newTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
      );
      _applyTime(newTime);
    }
  }

  /// Saat seçimi
  Future<void> _pickTime() async {
    final current = widget.mapViewModel.selectedTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4ECDC4),
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E2E),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      final newTime = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
      );
      _applyTime(newTime);
    }
  }

  void _applyTime(DateTime time) {
    widget.mapViewModel.loadWeatherForTime(time);
  }

  /// Anlık zamana dön
  void _resetToNow() {
    _applyTime(DateTime.now().subtract(const Duration(hours: 1)));
  }

  /// Bir gün geri
  void _goBackOneDay() {
    final current = widget.mapViewModel.selectedTime;
    _applyTime(current.subtract(const Duration(days: 1)));
  }

  /// Bir gün ileri (bugünden ileriye geçmesin)
  void _goForwardOneDay() {
    final current = widget.mapViewModel.selectedTime;
    final tomorrow = DateTime.now().add(const Duration(hours: 1));
    final next = current.add(const Duration(days: 1));
    if (next.isBefore(tomorrow)) {
      _applyTime(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final vm = widget.mapViewModel;
    final selected = vm.selectedTime;
    final isNow =
        DateTime.now().difference(selected).abs() < const Duration(hours: 2);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4ECDC4).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Başlık satırı ─────────────────────────────────────────────────
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: isNow ? Colors.greenAccent : const Color(0xFF4ECDC4),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dateFmt.format(selected),
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isNow
                            ? '${_timeFmt.format(selected)}  (Anlık)'
                            : _timeFmt.format(selected),
                        style: TextStyle(
                          color: isNow
                              ? Colors.greenAccent
                              : theme.secondaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 280),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.secondaryTextColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Genişleyen panel ──────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                Divider(
                  height: 1,
                  color: theme.secondaryTextColor.withValues(alpha: 0.2),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Tarih ve saat seçiciler
                      SizedBox(
                        width: 250,
                        child: Row(
                          children: [
                            Expanded(
                              child: _DateTimeButton(
                                label: 'Tarih',
                                value: _dateFmt.format(selected),
                                icon: Icons.calendar_today_rounded,
                                color: const Color(0xFF4ECDC4),
                                onTap: _pickDate,
                                theme: theme,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DateTimeButton(
                                label: 'Saat',
                                value: _timeFmt.format(selected),
                                icon: Icons.schedule_rounded,
                                color: const Color(0xFF56CCF2),
                                onTap: _pickTime,
                                theme: theme,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Gezinme butonları
                      SizedBox(
                        width: 250,
                        child: Row(
                          children: [
                            // ← Önceki gün
                            Expanded(
                              child: _NavButton(
                                icon: Icons.chevron_left_rounded,
                                label: '−1 gün',
                                onTap: _goBackOneDay,
                                theme: theme,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Şimdi
                            Expanded(
                              child: _NavButton(
                                icon: Icons.gps_fixed_rounded,
                                label: 'Şimdi',
                                onTap: _resetToNow,
                                theme: theme,
                                highlight: true,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // → Sonraki gün
                            Expanded(
                              child: _NavButton(
                                icon: Icons.chevron_right_rounded,
                                label: '+1 gün',
                                onTap: _goForwardOneDay,
                                theme: theme,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Yükleniyor göstergesi
                      if (vm.isBusy)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF4ECDC4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Veri yükleniyor...',
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yardımcı buton bileşenleri ───────────────────────────────────────────────

class _DateTimeButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final ThemeViewModel theme;

  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeViewModel theme;
  final bool highlight;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.greenAccent : theme.secondaryTextColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.greenAccent.withValues(alpha: 0.1)
              : theme.cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

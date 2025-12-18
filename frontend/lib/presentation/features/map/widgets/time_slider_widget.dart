// presentation/features/map/widgets/time_slider_widget.dart
//
// Sorumluluk: Zaman çizelgesi slider'ı
// State'i kendi içinde tutar, MapProvider üzerinden verileri yükler

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/map_provider.dart';
import '../../../../providers/theme_provider.dart';

class TimeSliderWidget extends StatefulWidget {
  const TimeSliderWidget({super.key});

  @override
  State<TimeSliderWidget> createState() => _TimeSliderWidgetState();
}

class _TimeSliderWidgetState extends State<TimeSliderWidget> {
  // Pencerenin üst sınırı (bugün)
  DateTime _timeWindowEnd = DateTime.now();
  // Seçili gün
  DateTime _selectedTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);

    final windowEndDay = DateTime(
      _timeWindowEnd.year,
      _timeWindowEnd.month,
      _timeWindowEnd.day,
    );
    const daysBack = 7;
    final minDate = windowEndDay.subtract(const Duration(days: daysBack));
    final maxDate = windowEndDay;

    final selectedDay = DateTime(
      _selectedTime.year,
      _selectedTime.month,
      _selectedTime.day,
    );

    final minMs = minDate.millisecondsSinceEpoch.toDouble();
    final maxMs = maxDate.millisecondsSinceEpoch.toDouble();
    final selMs = selectedDay.millisecondsSinceEpoch.toDouble();
    final clampedMs = selMs.clamp(minMs, maxMs);
    final displayDate = DateTime.fromMillisecondsSinceEpoch(clampedMs.toInt());
    final totalDays = maxDate.difference(minDate).inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Zaman Çizelgesi',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatDate(displayDate),
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blueAccent,
              inactiveTrackColor: theme.secondaryTextColor.withValues(
                alpha: 0.3,
              ),
              thumbColor: Colors.blueAccent,
              overlayColor: Colors.blueAccent.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: clampedMs,
              min: minMs,
              max: maxMs,
              divisions: totalDays,
              onChanged: (value) {
                const dayMs = 86400000; // 24*60*60*1000
                final steps = ((value - minMs) / dayMs).round();
                final snappedMs = (minMs + steps * dayMs).clamp(minMs, maxMs);
                final chosenDate = DateTime.fromMillisecondsSinceEpoch(
                  snappedMs.toInt(),
                );

                final requestTime = DateTime(
                  chosenDate.year,
                  chosenDate.month,
                  chosenDate.day,
                  12,
                );

                setState(() {
                  _selectedTime = chosenDate;
                });
                mapProvider.loadWeatherForTime(requestTime);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '-$daysBack gün',
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
              ),
              TextButton(
                onPressed: () {
                  final now = DateTime.now();
                  setState(() {
                    final today = DateTime(now.year, now.month, now.day);
                    _timeWindowEnd = today;
                    _selectedTime = today;
                  });
                  final noon = DateTime(now.year, now.month, now.day, 12);
                  mapProvider.loadWeatherForTime(noon);
                },
                child: const Text('Bugün', style: TextStyle(fontSize: 12)),
              ),
              Text(
                'Bugün',
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
}

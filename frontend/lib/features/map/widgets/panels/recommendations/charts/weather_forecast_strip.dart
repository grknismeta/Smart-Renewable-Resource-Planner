import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:intl/intl.dart';

/// 7 günlük kompakt hava tahmini şeridi.
class WeatherForecastStrip extends StatelessWidget {
  final List<CityWeatherData> hourlyData;
  final ThemeViewModel theme;

  const WeatherForecastStrip({
    super.key,
    required this.hourlyData,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (hourlyData.isEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Tahmin verisi mevcut değil',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }

    // Saatlik veriyi günlük gruplara ayır
    final dailyGroups = <String, List<CityWeatherData>>{};
    for (final d in hourlyData) {
      final dayKey = DateFormat('yyyy-MM-dd').format(d.timestamp);
      dailyGroups.putIfAbsent(dayKey, () => []).add(d);
    }

    final sortedDays = dailyGroups.keys.toList()..sort();
    final days = sortedDays.take(7).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blueGrey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.lightBlueAccent),
              const SizedBox(width: 6),
              Text(
                '7 Günlük Tahmin',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final records = dailyGroups[days[index]]!;
                return _DayCard(records: records, theme: theme);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final List<CityWeatherData> records;
  final ThemeViewModel theme;

  const _DayCard({required this.records, required this.theme});

  @override
  Widget build(BuildContext context) {
    final date = records.first.timestamp;
    final dayName = DateFormat('EEE', 'tr_TR').format(date);

    final temps = records.map((r) => r.temperature).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final avgWind = records.map((r) => r.windSpeed).reduce((a, b) => a + b) / records.length;
    final avgCloud = records
        .where((r) => r.cloudCover != null)
        .map((r) => r.cloudCover!)
        .fold(0.0, (a, b) => a + b) /
        records.where((r) => r.cloudCover != null).length.clamp(1, 999);

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: theme.secondaryTextColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dayName,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Icon(
            _weatherIcon(avgCloud),
            size: 18,
            color: _weatherColor(avgCloud),
          ),
          Text(
            '${minTemp.toInt()}°/${maxTemp.toInt()}°',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 9,
            ),
          ),
          Text(
            '${avgWind.toStringAsFixed(1)}m/s',
            style: TextStyle(
              color: Colors.cyanAccent.withValues(alpha: 0.8),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  IconData _weatherIcon(double cloudCover) {
    if (cloudCover < 20) return Icons.wb_sunny;
    if (cloudCover < 50) return Icons.wb_cloudy;
    if (cloudCover < 80) return Icons.cloud;
    return Icons.cloud_queue;
  }

  Color _weatherColor(double cloudCover) {
    if (cloudCover < 20) return Colors.amber;
    if (cloudCover < 50) return Colors.orangeAccent;
    if (cloudCover < 80) return Colors.blueGrey;
    return Colors.grey;
  }
}

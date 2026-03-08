import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:intl/intl.dart';

/// 7 günlük saatlik rüzgar hızı — sinüs dalga görünümlü LineChart.
class WindSpeedChart extends StatelessWidget {
  final List<CityWeatherData> hourlyData;
  final ThemeViewModel theme;

  const WindSpeedChart({
    super.key,
    required this.hourlyData,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (hourlyData.isEmpty) return const SizedBox.shrink();

    final sorted = List<CityWeatherData>.from(hourlyData)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].windSpeed));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    // Gün sınır indeksleri
    final dayLabels = <int, String>{};
    String? lastDay;
    for (int i = 0; i < sorted.length; i++) {
      final dayStr = DateFormat('EEE', 'tr_TR').format(sorted[i].timestamp);
      if (dayStr != lastDay) {
        dayLabels[i] = dayStr;
        lastDay = dayStr;
      }
    }

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.air, size: 14, color: Colors.cyanAccent),
              const SizedBox(width: 6),
              Text(
                'Rüzgar Hızı (7 Gün)',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 3).clamp(1, 10),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.secondaryTextColor.withValues(alpha: 0.1),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        final label = dayLabels[idx];
                        if (label == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (maxY / 3).clamp(1, 10),
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => theme.cardColor.withValues(alpha: 0.9),
                    getTooltipItems: (spots) => spots.map((s) {
                      final idx = s.x.toInt().clamp(0, sorted.length - 1);
                      final time = DateFormat('dd MMM HH:mm', 'tr_TR')
                          .format(sorted[idx].timestamp);
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} m/s\n$time',
                        TextStyle(color: theme.textColor, fontSize: 10),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: Colors.cyanAccent,
                    barWidth: 1.8,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.cyanAccent.withValues(alpha: 0.3),
                          Colors.cyanAccent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                minY: 0,
                maxY: maxY * 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

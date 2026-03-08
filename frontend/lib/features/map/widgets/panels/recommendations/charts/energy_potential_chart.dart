import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/recommendation_model.dart';

/// Rüzgar vs Güneş enerji potansiyeli karşılaştırma bar chart.
class EnergyPotentialChart extends StatelessWidget {
  final RecommendedCity city;
  final ThemeViewModel theme;

  const EnergyPotentialChart({
    super.key,
    required this.city,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Rüzgar potansiyeli: basit tahmin (P = 0.5 * rho * A * v^3 * Cp)
    // Simplified: kWh/m²/yıl ≈ windSpeed^3 * 0.15
    final windSpeed = city.avgWindSpeed ?? 0;
    final windPotential = windSpeed * windSpeed * windSpeed * 0.15;
    final solarPotential = city.totalRadiationKwh ?? 0;

    if (windPotential == 0 && solarPotential == 0) return const SizedBox.shrink();

    final maxVal = [windPotential, solarPotential].reduce((a, b) => a > b ? a : b);

    return Container(
      height: 130,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 14, color: Colors.amberAccent),
              const SizedBox(width: 6),
              Text(
                'Enerji Potansiyeli',
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
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.cardColor.withValues(alpha: 0.9),
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      final label = gIdx == 0 ? 'Rüzgar' : 'Güneş';
                      return BarTooltipItem(
                        '$label\n${rod.toY.toStringAsFixed(1)} kWh',
                        TextStyle(color: theme.textColor, fontSize: 10),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = ['💨 Rüzgar', '☀️ Güneş'];
                        if (value.toInt() >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            labels[value.toInt()],
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(
                      toY: windPotential,
                      color: Colors.cyanAccent,
                      width: 24,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                      toY: solarPotential,
                      color: Colors.orangeAccent,
                      width: 24,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

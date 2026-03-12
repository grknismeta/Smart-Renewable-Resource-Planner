import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

// CO₂ emisyon faktörü: Türkiye karma kaynak (kg CO₂/kWh)
const double _kCo2PerKwh = 0.433;

class ScenarioResultPanel extends StatelessWidget {
  final int scenarioId;

  const ScenarioResultPanel({super.key, required this.scenarioId});

  @override
  Widget build(BuildContext context) {
    final scenarioViewModel = Provider.of<ScenarioViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);
    final scenario = scenarioViewModel.scenarios.firstWhere(
      (s) => s.id == scenarioId,
      orElse: () => scenarioViewModel.scenarios.first,
    );

    final scenarioPins = mapViewModel.pins
        .where((p) => scenario.pinIds.contains(p.id))
        .toList();

    // Sonuç verisini parse et
    final resultData = scenario.resultData;
    final totalSolarKwh = (resultData?['total_solar_kwh'] as num?)?.toDouble() ?? 0.0;
    final totalWindKwh  = (resultData?['total_wind_kwh']  as num?)?.toDouble() ?? 0.0;
    final totalHydroKwh = (resultData?['total_hydro_kwh'] as num?)?.toDouble() ?? 0.0;
    final totalKwh      = (resultData?['total_kwh']       as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Senaryo Sonucu (7 Gün)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (scenario.startDate != null)
                Text(
                  '${scenario.startDate?.day}/${scenario.startDate?.month} - ${scenario.endDate?.day}/${scenario.endDate?.month}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(height: 12),

              if (resultData != null)
                Column(
                  children: [
                    ResultCard(
                      label: 'Toplam Üretim',
                      value: FormatUtils.formatEnergy(totalKwh),
                      icon: Icons.flash_on,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ResultCard(
                            label: 'Güneş',
                            value: FormatUtils.formatEnergy(totalSolarKwh),
                            icon: Icons.wb_sunny,
                            color: Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ResultCard(
                            label: 'Rüzgar',
                            value: FormatUtils.formatEnergy(totalWindKwh),
                            icon: Icons.wind_power,
                            color: Colors.lightBlueAccent,
                          ),
                        ),
                      ],
                    ),
                    if (totalHydroKwh > 0) ...[
                      const SizedBox(height: 8),
                      ResultCard(
                        label: 'Hidroelektrik',
                        value: FormatUtils.formatEnergy(totalHydroKwh),
                        icon: Icons.water_drop,
                        color: Colors.cyanAccent,
                      ),
                    ],
                    const SizedBox(height: 12),
                    // CO₂ tasarrufu
                    ResultCard(
                      label: 'CO₂ Tasarrufu',
                      value: '${FormatUtils.formatDec1(totalKwh * _kCo2PerKwh / 1000)} ton/yıl',
                      icon: Icons.eco,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(height: 12),
                    // Aylık üretim grafiği
                    _MonthlyProductionChart(resultData: resultData),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'Bu senaryo için henüz hesaplanmış sonuç yok.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: scenarioPins.length,
            itemBuilder: (context, index) {
              final pin = scenarioPins[index];
              final isHes = pin.type == 'Hidroelektrik';
              final isSolar = pin.type == 'Güneş Paneli';
              final color = isHes
                  ? Colors.cyanAccent
                  : isSolar
                      ? Colors.orangeAccent
                      : Colors.blueAccent;
              final icon = isHes
                  ? Icons.water_drop
                  : isSolar
                      ? Icons.wb_sunny
                      : Icons.wind_power;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pin.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${pin.capacityMw.toStringAsFixed(2)} MW · ${pin.type}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          if (isHes && pin.headHeight != null)
                            Text(
                              'Düşü: ${pin.headHeight!.toStringAsFixed(0)} m  ·  Debi: ${pin.flowRate?.toStringAsFixed(2) ?? '?'} m³/s',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Aylık Üretim Grafiği ────────────────────────────────────────────────────
class _MonthlyProductionChart extends StatelessWidget {
  final Map<String, dynamic> resultData;

  const _MonthlyProductionChart({required this.resultData});

  /// pin_results[].history [{ds: "2024-01-15", y: 456.7}] → aylık toplam kWh
  List<double> _buildMonthlyTotals() {
    final monthly = List<double>.filled(12, 0.0);
    final pinResults = resultData['pin_results'];
    if (pinResults is! List) return monthly;

    for (final pin in pinResults) {
      final history = pin['history'];
      if (history is! List) continue;
      for (final entry in history) {
        final ds = entry['ds'] as String?;
        final y  = (entry['y']  as num?)?.toDouble() ?? 0.0;
        if (ds == null || ds.length < 7) continue;
        final monthIdx = (int.tryParse(ds.substring(5, 7)) ?? 1) - 1;
        if (monthIdx >= 0 && monthIdx < 12) monthly[monthIdx] += y;
      }
    }
    return monthly;
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _buildMonthlyTotals();
    final maxVal = monthly.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    const monthLabels = ['O','Ş','M','N','M','H','T','A','E','E','K','A'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aylık Üretim Dağılımı',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1C2533),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final kwh = rod.toY;
                    final label = kwh >= 1000
                        ? '${(kwh / 1000).toStringAsFixed(1)} MWh'
                        : '${kwh.toStringAsFixed(0)} kWh';
                    return BarTooltipItem(
                      label,
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                      return Text(
                        monthLabels[idx],
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      );
                    },
                    reservedSize: 16,
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: Colors.white10,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(12, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: monthly[i],
                      width: 10,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.greenAccent.withValues(alpha: 0.9),
                          Colors.tealAccent.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class ResultCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const ResultCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

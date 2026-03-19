// lib/features/reports/widgets/tabs/monthly_trend_tab.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';

/// Tab 4 — Aylık / Günlük Trend
/// Şehir + metrik seçici  |  LineChart  |  Özet kartlar
class MonthlyTrendTab extends StatelessWidget {
  const MonthlyTrendTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    context.watch<ThemeViewModel>();
    final provinces = vm.provinceSummaries;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Seçiciler ─────────────────────────────────────────────────────
          _Selectors(vm: vm, provinces: provinces),
          const SizedBox(height: 14),

          // ── Grafik ─────────────────────────────────────────────────────────
          Expanded(child: _TrendChart(vm: vm)),
        ],
      ),
    );
  }
}

// ── Selectors ─────────────────────────────────────────────────────────────────

class _Selectors extends StatelessWidget {
  final ReportViewModel vm;
  final List<ProvinceSummary> provinces;

  const _Selectors({required this.vm, required this.provinces});

  static const _metrics = ['solar', 'wind', 'temperature'];
  static const _metricLabels = {
    'solar': 'Güneş (W/m²)',
    'wind': 'Rüzgar (m/s)',
    'temperature': 'Sıcaklık (°C)',
  };

  @override
  Widget build(BuildContext context) {
    final cityList = provinces.map((p) => p.provinceName).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Şehir seçici
        if (cityList.isNotEmpty)
          _SelectorBox(
            label: 'Şehir',
            icon: Icons.location_city_rounded,
            child: DropdownButton<String>(
              value: cityList.contains(vm.trendCity)
                  ? vm.trendCity
                  : cityList.first,
              isDense: true,
              dropdownColor: const Color(0xFF1C2533),
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white60, size: 16),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: cityList
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) vm.setTrendCity(v);
              },
            ),
          ),

        // Metrik seçici
        _SelectorBox(
          label: 'Metrik',
          icon: Icons.show_chart_rounded,
          child: DropdownButton<String>(
            value: vm.trendMetric,
            isDense: true,
            dropdownColor: const Color(0xFF1C2533),
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white60, size: 16),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: _metrics
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(_metricLabels[m] ?? m,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) vm.setTrendMetric(v);
            },
          ),
        ),

        // Yıl + Mod bilgisi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 12, color: Colors.cyanAccent),
              const SizedBox(width: 6),
              Text(
                _periodLabel(vm),
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _periodLabel(ReportViewModel vm) {
    if (vm.dateRangeMode == DateRangeMode.custom &&
        vm.customRangeStart != null) {
      final s = vm.customRangeStart!;
      final e = vm.customRangeEnd!;
      return '${s.day}.${s.month}.${s.year} – ${e.day}.${e.month}.${e.year}';
    }
    if (vm.selectedYear != null) {
      if (vm.selectedMonth != null) {
        const months = [
          'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
          'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
        ];
        return '${months[vm.selectedMonth! - 1]} ${vm.selectedYear}';
      }
      return '${vm.selectedYear}';
    }
    return 'Tüm Veri';
  }
}

class _SelectorBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _SelectorBox({
    required this.label,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white38),
          const SizedBox(width: 5),
          child,
        ],
      ),
    );
  }
}

// ── Trend Chart ───────────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final ReportViewModel vm;

  const _TrendChart({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.trendLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    final data = vm.trendData;

    if (data.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded,
                color: Colors.white12, size: 48),
            SizedBox(height: 10),
            Text('Trend verisi bulunamadı.',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    final values = data.map((p) => p.value).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final avgVal =
        values.fold(0.0, (acc, v) => acc + v) / values.length;

    final maxIdx = values.indexOf(maxVal);
    final minIdx = values.indexOf(minVal);

    const lineColor = Colors.cyanAccent;

    return Column(
      children: [
        // ── Özet Kartlar ─────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'En Yüksek',
                value: _fmt(maxVal, vm.trendMetric),
                subtitle:
                    maxIdx < data.length ? data[maxIdx].label : '',
                color: Colors.greenAccent,
                icon: Icons.arrow_upward_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: 'Yıllık Ort.',
                value: _fmt(avgVal, vm.trendMetric),
                subtitle: 'Ortalama',
                color: Colors.cyanAccent,
                icon: Icons.horizontal_rule_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: 'En Düşük',
                value: _fmt(minVal, vm.trendMetric),
                subtitle:
                    minIdx < data.length ? data[minIdx].label : '',
                color: Colors.redAccent,
                icon: Icons.arrow_downward_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── LineChart ─────────────────────────────────────────────────────────
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: LineChart(
              duration: Duration.zero,
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (val, meta) => Text(
                        _fmt(val, vm.trendMetric),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data[idx].label,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        const Color(0xFF1C2533),
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '${data[s.x.toInt()].label}: ${_fmt(s.y, vm.trendMetric)}',
                              const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                minY: minVal > 0 ? minVal * 0.85 : minVal * 1.15,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.value);
                    }).toList(),
                    isCurved: true,
                    color: lineColor,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, idx) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: lineColor,
                        strokeWidth: 1.5,
                        strokeColor: Colors.black,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          lineColor.withValues(alpha: 0.25),
                          lineColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(double v, String metric) {
    switch (metric) {
      case 'temperature':
        return '${v.toStringAsFixed(1)}°';
      case 'wind':
        return '${v.toStringAsFixed(1)}m/s';
      default:
        return '${v.toStringAsFixed(0)}W';
    }
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label, value, subtitle;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          Text(subtitle,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

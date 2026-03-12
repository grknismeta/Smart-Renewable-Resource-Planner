import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:frontend/data/turkey_energy_data.dart';

/// Türkiye 10 yıllık enerji istatistikleri paneli.
/// ReportScreen'e "Türkiye Enerji" sekmesi olarak eklenir.
class TurkeyEnergyPanel extends StatefulWidget {
  const TurkeyEnergyPanel({super.key});

  @override
  State<TurkeyEnergyPanel> createState() => _TurkeyEnergyPanelState();
}

class _TurkeyEnergyPanelState extends State<TurkeyEnergyPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Türkiye Enerji İstatistikleri',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '2014 – 2023',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // Tab bar
        TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white38,
          indicatorColor: Colors.blueAccent,
          labelStyle: const TextStyle(fontSize: 11),
          tabs: const [
            Tab(text: 'Üretim Trendi'),
            Tab(text: '2023 Karışımı'),
            Tab(text: 'Yenilenebilir'),
          ],
        ),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProductionTrend(),
              _buildEnergyMix(),
              _buildRenewableTrend(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Sekme 1: 10 yıllık toplam üretim bar grafiği ──────────────────────────
  Widget _buildProductionTrend() {
    final data = turkeyEnergyHistory;
    final maxVal = data.map((d) => d.totalTwh).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yıllık Toplam Elektrik Üretimi (TWh)',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = data[group.x];
                      return BarTooltipItem(
                        '${d.year}\n${d.totalTwh.toStringAsFixed(1)} TWh',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final year = data[idx].year;
                        return Text(
                          "'${year.toString().substring(2)}",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value % 50 != 0) return const SizedBox.shrink();
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
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
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(data.length, (i) {
                  final d = data[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: d.totalTwh,
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            d.fossilTwh,
                            Colors.orangeAccent.withValues(alpha: 0.7),
                          ),
                          BarChartRodStackItem(
                            d.fossilTwh,
                            d.totalTwh,
                            Colors.greenAccent.withValues(alpha: 0.75),
                          ),
                        ],
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                        color: Colors.transparent,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildLegendRow([
            _LegendItem(color: Colors.greenAccent, label: 'Yenilenebilir'),
            _LegendItem(color: Colors.orangeAccent, label: 'Fosil'),
          ]),
        ],
      ),
    );
  }

  // ─── Sekme 2: 2023 enerji karışımı pasta grafiği ──────────────────────────
  Widget _buildEnergyMix() {
    final mix = turkey2023EnergyMix;
    final colors = turkey2023Colors;
    final entries = mix.entries.toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (response?.touchedSection != null) {
                      setState(
                        () => _touchedIndex =
                            response!.touchedSection!.touchedSectionIndex,
                      );
                    } else {
                      setState(() => _touchedIndex = -1);
                    }
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: List.generate(entries.length, (i) {
                  final e = entries[i];
                  final isTouched = i == _touchedIndex;
                  final color = Color(colors[e.key] ?? 0xFF9E9E9E);
                  final pct =
                      (e.value / 334.1 * 100).toStringAsFixed(1);
                  return PieChartSectionData(
                    color: color,
                    value: e.value,
                    title: isTouched ? '$pct%\n${e.key}' : '$pct%',
                    radius: isTouched ? 60 : 50,
                    titleStyle: TextStyle(
                      fontSize: isTouched ? 11 : 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: entries.map((e) {
              final color = Color(colors[e.key] ?? 0xFF9E9E9E);
              return _buildLegendChip(color: color, label: '${e.key}: ${e.value.toStringAsFixed(1)} TWh');
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Sekme 3: Yenilenebilir enerji büyümesi line chart ────────────────────
  Widget _buildRenewableTrend() {
    final data = turkeyEnergyHistory;

    final windSpots = List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i].windTwh),
    );
    final solarSpots = List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i].solarTwh),
    );
    final hydroSpots = List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i].hydroTwh),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yenilenebilir Kaynaklar Büyümesi (TWh)',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: 110,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final year = data[spot.x.toInt()].year;
                        final names = ['Rüzgar', 'Güneş', 'Hidro'];
                        final name = names[spot.barIndex];
                        return LineTooltipItem(
                          '$year\n$name: ${spot.y.toStringAsFixed(1)} TWh',
                          const TextStyle(color: Colors.white, fontSize: 10),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          "'${data[idx].year.toString().substring(2)}",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value % 25 != 0) return const SizedBox.shrink();
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
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
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _lineData(windSpots, Colors.cyanAccent),
                  _lineData(solarSpots, Colors.amberAccent),
                  _lineData(hydroSpots, Colors.lightBlueAccent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildLegendRow([
            _LegendItem(color: Colors.cyanAccent, label: 'Rüzgar'),
            _LegendItem(color: Colors.amberAccent, label: 'Güneş'),
            _LegendItem(color: Colors.lightBlueAccent, label: 'Hidro'),
          ]),
        ],
      ),
    );
  }

  LineChartBarData _lineData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _buildLegendRow(List<_LegendItem> items) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildLegendChip(color: item.color, label: item.label),
            ),
          )
          .toList(),
    );
  }

  Widget _buildLegendChip({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

class _LegendItem {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
}

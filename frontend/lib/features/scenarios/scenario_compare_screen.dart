// lib/features/scenarios/scenario_compare_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/shared/widgets/app_background.dart';
import 'package:frontend/shared/widgets/custom_app_bar.dart';

class ScenarioCompareScreen extends StatefulWidget {
  const ScenarioCompareScreen({super.key});

  @override
  State<ScenarioCompareScreen> createState() => _ScenarioCompareScreenState();
}

class _ScenarioCompareScreenState extends State<ScenarioCompareScreen> {
  Scenario? _scenarioA;
  Scenario? _scenarioB;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<ScenarioViewModel>(context, listen: false).loadScenarios();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final vm    = Provider.of<ScenarioViewModel>(context);
    final scenarios = vm.scenarios;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomAppBar(
                  title: 'Senaryo Karşılaştırma',
                  textColor: theme.textColor,
                  onBack: () => Navigator.of(context).pushReplacementNamed('/scenarios'),
                ),
              ),
              Expanded(
                child: vm.isBusy
                    ? const Center(child: CircularProgressIndicator())
                    : scenarios.isEmpty
                        ? _emptyState(theme)
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Seçim paneli ─────────────────────────────
                                _SelectorRow(
                                  labelA: 'Senaryo A',
                                  labelB: 'Senaryo B',
                                  scenarios: scenarios,
                                  selectedA: _scenarioA,
                                  selectedB: _scenarioB,
                                  theme: theme,
                                  onChangedA: (s) => setState(() => _scenarioA = s),
                                  onChangedB: (s) => setState(() => _scenarioB = s),
                                ),
                                const SizedBox(height: 24),

                                if (_scenarioA != null && _scenarioB != null) ...[
                                  // ── Bar Chart ────────────────────────────
                                  _CompareBarChart(a: _scenarioA!, b: _scenarioB!, theme: theme),
                                  const SizedBox(height: 24),

                                  // ── Tablo ────────────────────────────────
                                  _CompareTable(a: _scenarioA!, b: _scenarioB!, theme: theme),
                                  const SizedBox(height: 24),

                                  // ── Kazanan banner ───────────────────────
                                  _WinnerBanner(a: _scenarioA!, b: _scenarioB!, theme: theme),
                                  const SizedBox(height: 32),
                                ] else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 48),
                                    child: Text(
                                      'Yukarıdan iki senaryo seçin',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: theme.secondaryTextColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeViewModel theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compare_arrows, size: 80, color: theme.secondaryTextColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Henüz senaryo yok', style: TextStyle(color: theme.secondaryTextColor, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Karşılaştırabilmek için en az 2 senaryo oluşturun',
            style: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.7), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Selector Row ──────────────────────────────────────────────────────────────
class _SelectorRow extends StatelessWidget {
  final String labelA, labelB;
  final List<Scenario> scenarios;
  final Scenario? selectedA, selectedB;
  final ThemeViewModel theme;
  final ValueChanged<Scenario?> onChangedA, onChangedB;

  const _SelectorRow({
    required this.labelA, required this.labelB,
    required this.scenarios, required this.selectedA, required this.selectedB,
    required this.theme, required this.onChangedA, required this.onChangedB,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Dropdown(label: labelA, scenarios: scenarios, selected: selectedA, theme: theme, onChanged: onChangedA)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.compare_arrows, color: theme.secondaryTextColor),
        ),
        Expanded(child: _Dropdown(label: labelB, scenarios: scenarios, selected: selectedB, theme: theme, onChanged: onChangedB)),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final List<Scenario> scenarios;
  final Scenario? selected;
  final ThemeViewModel theme;
  final ValueChanged<Scenario?> onChanged;

  const _Dropdown({
    required this.label, required this.scenarios, required this.selected,
    required this.theme, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderColor),
      ),
      child: DropdownButton<Scenario>(
        value: selected,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: theme.cardColor,
        hint: Text(label, style: TextStyle(color: theme.secondaryTextColor, fontSize: 13)),
        style: TextStyle(color: theme.textColor, fontSize: 13),
        items: scenarios.map((s) => DropdownMenuItem(
          value: s,
          child: Text(s.name, overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────
class _CompareBarChart extends StatelessWidget {
  final Scenario a, b;
  final ThemeViewModel theme;
  const _CompareBarChart({required this.a, required this.b, required this.theme});

  double _val(Scenario s, String key) =>
      (s.resultData?[key] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final aTotal = _val(a, 'total_kwh');
    final bTotal = _val(b, 'total_kwh');
    final aSolar = _val(a, 'total_solar_kwh');
    final bSolar = _val(b, 'total_solar_kwh');
    final aWind  = _val(a, 'total_wind_kwh');
    final bWind  = _val(b, 'total_wind_kwh');
    final aHydro = _val(a, 'total_hydro_kwh');
    final bHydro = _val(b, 'total_hydro_kwh');

    final maxY = [aTotal, bTotal, aSolar, bSolar, aWind, bWind, aHydro, bHydro]
        .reduce((m, v) => v > m ? v : m);
    final effectiveMax = maxY == 0 ? 1.0 : maxY * 1.15;

    final hasResult = aTotal > 0 || bTotal > 0;
    if (!hasResult) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Senaryo sonuçları henüz hesaplanmadı.\nHer iki senaryoyu da "Hesapla" ile çalıştırın.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.secondaryTextColor),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enerji Üretimi Karşılaştırması (kWh)',
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Row(children: [
            _LegendDot(color: Colors.blueAccent, label: a.name),
            const SizedBox(width: 16),
            _LegendDot(color: Colors.orangeAccent, label: b.name),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: effectiveMax,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = ['Toplam', 'Güneş', 'Rüzgar', 'HES'][groupIndex];
                      return BarTooltipItem(
                        '$label\n${FormatUtils.formatEnergy(rod.toY)}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const labels = ['Toplam', 'Güneş', 'Rüzgar', 'HES'];
                        final idx = val.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(labels[idx], style: TextStyle(color: theme.secondaryTextColor, fontSize: 10)),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (val, meta) => Text(
                        FormatUtils.formatEnergyShort(val),
                        style: TextStyle(color: theme.secondaryTextColor, fontSize: 9),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.secondaryTextColor.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _group(0, aTotal, bTotal),
                  _group(1, aSolar, bSolar),
                  _group(2, aWind, bWind),
                  _group(3, aHydro, bHydro),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _group(int x, double vA, double vB) => BarChartGroupData(
    x: x,
    barRods: [
      BarChartRodData(toY: vA, color: Colors.blueAccent, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
      BarChartRodData(toY: vB, color: Colors.orangeAccent, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
    ],
    barsSpace: 4,
  );
}

// ── Comparison Table ──────────────────────────────────────────────────────────
class _CompareTable extends StatelessWidget {
  final Scenario a, b;
  final ThemeViewModel theme;
  const _CompareTable({required this.a, required this.b, required this.theme});

  double _val(Scenario s, String key) =>
      (s.resultData?[key] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Toplam Üretim', _val(a, 'total_kwh'), _val(b, 'total_kwh'), true),
      ('Güneş',  _val(a, 'total_solar_kwh'), _val(b, 'total_solar_kwh'), true),
      ('Rüzgar', _val(a, 'total_wind_kwh'),  _val(b, 'total_wind_kwh'), true),
      ('HES',    _val(a, 'total_hydro_kwh'), _val(b, 'total_hydro_kwh'), true),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Expanded(flex: 2, child: Text('Metrik', style: TextStyle(color: theme.secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(flex: 2, child: Text(a.name, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: Text(b.name, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 32),
            ]),
          ),
          const Divider(height: 1),
          ...rows.map((r) => _TableRow(
            label: r.$1, valA: r.$2, valB: r.$3, theme: theme,
          )),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final String label;
  final double valA, valB;
  final ThemeViewModel theme;
  const _TableRow({required this.label, required this.valA, required this.valB, required this.theme});

  @override
  Widget build(BuildContext context) {
    final aWins = valA > valB;
    final same  = valA == valB;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.borderColor.withValues(alpha: 0.3))),
      ),
      child: Row(children: [
        Expanded(flex: 2, child: Text(label, style: TextStyle(color: theme.textColor, fontSize: 13))),
        Expanded(flex: 2, child: Text(
          FormatUtils.formatEnergy(valA),
          style: TextStyle(
            color: same ? theme.textColor : (aWins ? Colors.greenAccent : theme.secondaryTextColor),
            fontWeight: aWins && !same ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        )),
        Expanded(flex: 2, child: Text(
          FormatUtils.formatEnergy(valB),
          style: TextStyle(
            color: same ? theme.textColor : (!aWins ? Colors.greenAccent : theme.secondaryTextColor),
            fontWeight: !aWins && !same ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        )),
        Icon(
          same ? Icons.remove : (aWins ? Icons.arrow_back : Icons.arrow_forward),
          size: 18,
          color: same ? theme.secondaryTextColor : Colors.greenAccent,
        ),
      ]),
    );
  }
}

// ── Winner Banner ─────────────────────────────────────────────────────────────
class _WinnerBanner extends StatelessWidget {
  final Scenario a, b;
  final ThemeViewModel theme;
  const _WinnerBanner({required this.a, required this.b, required this.theme});

  @override
  Widget build(BuildContext context) {
    final aTotal = (a.resultData?['total_kwh'] as num?)?.toDouble() ?? 0;
    final bTotal = (b.resultData?['total_kwh'] as num?)?.toDouble() ?? 0;

    if (aTotal == 0 && bTotal == 0) return const SizedBox();

    final aWins = aTotal >= bTotal;
    final winner = aWins ? a : b;
    final winnerColor = aWins ? Colors.blueAccent : Colors.orangeAccent;
    final diff = (aTotal - bTotal).abs();
    final pct = (aTotal + bTotal) > 0 ? diff / ((aTotal + bTotal) / 2) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [winnerColor.withValues(alpha: 0.15), winnerColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: winnerColor.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.emoji_events_rounded, color: winnerColor, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daha Verimli Senaryo', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
              Text(winner.name, style: TextStyle(color: winnerColor, fontWeight: FontWeight.bold, fontSize: 18)),
              if (diff > 0)
                Text(
                  '+${FormatUtils.formatEnergy(diff)} fazla (%${pct.toStringAsFixed(1)})',
                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Yardımcı ─────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis),
    ]);
  }
}

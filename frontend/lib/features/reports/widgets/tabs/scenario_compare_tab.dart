// lib/features/reports/widgets/tabs/scenario_compare_tab.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

/// Tab 3 — Senaryo Karşılaştırma
/// A vs B seçici + metrik grid + RadarChart
class ScenarioCompareTab extends StatefulWidget {
  const ScenarioCompareTab({super.key});

  @override
  State<ScenarioCompareTab> createState() => _ScenarioCompareTabState();
}

class _ScenarioCompareTabState extends State<ScenarioCompareTab> {
  int? _idA;
  int? _idB;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scenarios =
        Provider.of<ScenarioViewModel>(context, listen: false).scenarios;
    if (scenarios.length >= 2 && _idA == null) {
      _idA = scenarios[0].id;
      _idB = scenarios[1].id;
    } else if (scenarios.length == 1 && _idA == null) {
      _idA = scenarios[0].id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScenarioViewModel>();
    context.watch<ThemeViewModel>();
    final scenarios = vm.scenarios;

    if (scenarios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_arrows_rounded,
                color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'Henüz senaryo oluşturulmadı.\nSenaryo sayfasından yeni senaryo ekleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final scenA = scenarios.cast<Scenario?>().firstWhere(
        (s) => s?.id == _idA,
        orElse: () => null);
    final scenB = scenarios.cast<Scenario?>().firstWhere(
        (s) => s?.id == _idB,
        orElse: () => null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Senaryo Seçici ────────────────────────────────────────────────
          _ScenarioPicker(
            scenarios: scenarios,
            idA: _idA,
            idB: _idB,
            onChangeA: (id) => setState(() => _idA = id),
            onChangeB: (id) => setState(() => _idB = id),
          ),
          const SizedBox(height: 16),

          // ── Metrik Karşılaştırma ───────────────────────────────────────────
          if (scenA != null || scenB != null) ...[
            _MetricGrid(scenA: scenA, scenB: scenB),
            const SizedBox(height: 16),
          ],

          // ── Radar Karşılaştırma ────────────────────────────────────────────
          if (scenA != null && scenB != null) ...[
            _CompareRadarChart(scenA: scenA, scenB: scenB),
          ],
        ],
      ),
    );
  }
}

// ── Senaryo Seçici ────────────────────────────────────────────────────────────

class _ScenarioPicker extends StatelessWidget {
  final List<Scenario> scenarios;
  final int? idA, idB;
  final ValueChanged<int?> onChangeA, onChangeB;

  const _ScenarioPicker({
    required this.scenarios,
    required this.idA,
    required this.idB,
    required this.onChangeA,
    required this.onChangeB,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PickerCard(
            label: 'Senaryo A',
            color: Colors.blueAccent,
            scenarios: scenarios,
            selected: idA,
            onChanged: onChangeA,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const Icon(Icons.compare_arrows_rounded,
                  color: Colors.white38, size: 24),
              const Text(
                'VS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _PickerCard(
            label: 'Senaryo B',
            color: Colors.orangeAccent,
            scenarios: scenarios,
            selected: idB,
            onChanged: onChangeB,
          ),
        ),
      ],
    );
  }
}

class _PickerCard extends StatelessWidget {
  final String label;
  final Color color;
  final List<Scenario> scenarios;
  final int? selected;
  final ValueChanged<int?> onChanged;

  const _PickerCard({
    required this.label,
    required this.color,
    required this.scenarios,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButton<int>(
            value: selected,
            isExpanded: true,
            dropdownColor: const Color(0xFF1C2533),
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.keyboard_arrow_down,
                color: color.withValues(alpha: 0.7), size: 16),
            hint: const Text('Seçiniz',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: scenarios
                .map((s) => DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(
                        s.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Metrik Grid ───────────────────────────────────────────────────────────────

class _MetricGrid extends StatelessWidget {
  final Scenario? scenA;
  final Scenario? scenB;

  const _MetricGrid({required this.scenA, required this.scenB});

  @override
  Widget build(BuildContext context) {
    final aData = scenA?.resultData ?? {};
    final bData = scenB?.resultData ?? {};

    final metrics = [
      _Metric(
        label: 'Güneş Üretimi',
        icon: Icons.wb_sunny_rounded,
        aVal: (aData['total_solar_kwh'] as num?)?.toDouble() ?? 0,
        bVal: (bData['total_solar_kwh'] as num?)?.toDouble() ?? 0,
        unit: 'kWh',
        higherIsBetter: true,
        format: FormatUtils.formatEnergy,
      ),
      _Metric(
        label: 'Rüzgar Üretimi',
        icon: Icons.air_rounded,
        aVal: (aData['total_wind_kwh'] as num?)?.toDouble() ?? 0,
        bVal: (bData['total_wind_kwh'] as num?)?.toDouble() ?? 0,
        unit: 'kWh',
        higherIsBetter: true,
        format: FormatUtils.formatEnergy,
      ),
      _Metric(
        label: 'HES Üretimi',
        icon: Icons.water_rounded,
        aVal: (aData['total_hydro_kwh'] as num?)?.toDouble() ?? 0,
        bVal: (bData['total_hydro_kwh'] as num?)?.toDouble() ?? 0,
        unit: 'kWh',
        higherIsBetter: true,
        format: FormatUtils.formatEnergy,
      ),
      _Metric(
        label: 'Toplam Üretim',
        icon: Icons.bolt_rounded,
        aVal: _totalKwh(aData),
        bVal: _totalKwh(bData),
        unit: 'kWh',
        higherIsBetter: true,
        format: FormatUtils.formatEnergy,
      ),
      _Metric(
        label: 'Pin Sayısı',
        icon: Icons.push_pin_rounded,
        aVal: (scenA?.pinIds.length ?? 0).toDouble(),
        bVal: (scenB?.pinIds.length ?? 0).toDouble(),
        unit: 'adet',
        higherIsBetter: true,
        format: (v) => v.toStringAsFixed(0),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_rounded,
                  size: 14, color: Colors.white54),
              SizedBox(width: 6),
              Text(
                'Metrik Karşılaştırması',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Header
          _MetricRow(
            label: 'Metrik',
            aText: scenA?.name ?? 'A',
            bText: scenB?.name ?? 'B',
            isHeader: true,
          ),
          const Divider(height: 12, color: Colors.white12),
          ...metrics.map((m) => _MetricRow(
                label: m.label,
                aText: scenA != null ? m.format(m.aVal) : '-',
                bText: scenB != null ? m.format(m.bVal) : '-',
                isHeader: false,
                aIsBetter: scenA != null &&
                    scenB != null &&
                    m.higherIsBetter
                    ? m.aVal > m.bVal
                    : m.aVal < m.bVal,
                bIsBetter: scenA != null &&
                    scenB != null &&
                    m.higherIsBetter
                    ? m.bVal > m.aVal
                    : m.bVal < m.aVal,
              )),
        ],
      ),
    );
  }

  static double _totalKwh(Map<String, dynamic> d) {
    return ((d['total_solar_kwh'] as num?)?.toDouble() ?? 0) +
        ((d['total_wind_kwh'] as num?)?.toDouble() ?? 0) +
        ((d['total_hydro_kwh'] as num?)?.toDouble() ?? 0);
  }
}

class _Metric {
  final String label;
  final IconData icon;
  final double aVal, bVal;
  final String unit;
  final bool higherIsBetter;
  final String Function(double) format;

  const _Metric({
    required this.label,
    required this.icon,
    required this.aVal,
    required this.bVal,
    required this.unit,
    required this.higherIsBetter,
    required this.format,
  });
}

class _MetricRow extends StatelessWidget {
  final String label, aText, bText;
  final bool isHeader;
  final bool aIsBetter, bIsBetter;

  const _MetricRow({
    required this.label,
    required this.aText,
    required this.bText,
    this.isHeader = false,
    this.aIsBetter = false,
    this.bIsBetter = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHeader) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
                flex: 3,
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w700))),
            Expanded(
                flex: 2,
                child: Text(aText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700))),
            Expanded(
                flex: 2,
                child: Text(bText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700))),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: _ValueCell(
                text: aText,
                isBetter: aIsBetter,
                baseColor: Colors.blueAccent),
          ),
          Expanded(
            flex: 2,
            child: _ValueCell(
                text: bText,
                isBetter: bIsBetter,
                baseColor: Colors.orangeAccent),
          ),
        ],
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  final String text;
  final bool isBetter;
  final Color baseColor;

  const _ValueCell(
      {required this.text,
      required this.isBetter,
      required this.baseColor});

  @override
  Widget build(BuildContext context) {
    final color = isBetter ? Colors.greenAccent : baseColor;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: isBetter
            ? Border.all(color: Colors.greenAccent.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isBetter) ...[
            const Icon(Icons.arrow_upward_rounded,
                size: 10, color: Colors.greenAccent),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight:
                    isBetter ? FontWeight.w700 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compare Radar Chart ───────────────────────────────────────────────────────

class _CompareRadarChart extends StatelessWidget {
  final Scenario scenA;
  final Scenario scenB;

  const _CompareRadarChart(
      {required this.scenA, required this.scenB});

  @override
  Widget build(BuildContext context) {
    final aData = scenA.resultData ?? {};
    final bData = scenB.resultData ?? {};

    double norm(double v, double max) => (v / max).clamp(0.0, 1.0) * 5;

    final aTotal = _total(aData);
    final bTotal = _total(bData);
    final maxTotal = (aTotal > bTotal ? aTotal : bTotal).clamp(1.0, double.infinity);

    final aSolar = (aData['total_solar_kwh'] as num?)?.toDouble() ?? 0;
    final bSolar = (bData['total_solar_kwh'] as num?)?.toDouble() ?? 0;
    final maxSolar =
        (aSolar > bSolar ? aSolar : bSolar).clamp(1.0, double.infinity);

    final aWind = (aData['total_wind_kwh'] as num?)?.toDouble() ?? 0;
    final bWind = (bData['total_wind_kwh'] as num?)?.toDouble() ?? 0;
    final maxWind =
        (aWind > bWind ? aWind : bWind).clamp(1.0, double.infinity);

    final aHydro = (aData['total_hydro_kwh'] as num?)?.toDouble() ?? 0;
    final bHydro = (bData['total_hydro_kwh'] as num?)?.toDouble() ?? 0;
    final maxHydro =
        (aHydro > bHydro ? aHydro : bHydro).clamp(1.0, double.infinity);

    final aPins = scenA.pinIds.length.toDouble();
    final bPins = scenB.pinIds.length.toDouble();
    final maxPins =
        (aPins > bPins ? aPins : bPins).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded,
                  size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              const Text(
                'Radar Karşılaştırması',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Legend
              _LegendDot(color: Colors.blueAccent, label: scenA.name),
              const SizedBox(width: 12),
              _LegendDot(color: Colors.orangeAccent, label: scenB.name),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: RadarChart(
              duration: Duration.zero,
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor: Colors.blueAccent.withValues(alpha: 0.15),
                    borderColor: Colors.blueAccent,
                    borderWidth: 2,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: norm(aTotal, maxTotal)),
                      RadarEntry(value: norm(aSolar, maxSolar)),
                      RadarEntry(value: norm(aWind, maxWind)),
                      RadarEntry(value: norm(aHydro, maxHydro)),
                      RadarEntry(value: norm(aPins, maxPins)),
                    ],
                  ),
                  RadarDataSet(
                    fillColor:
                        Colors.orangeAccent.withValues(alpha: 0.15),
                    borderColor: Colors.orangeAccent,
                    borderWidth: 2,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: norm(bTotal, maxTotal)),
                      RadarEntry(value: norm(bSolar, maxSolar)),
                      RadarEntry(value: norm(bWind, maxWind)),
                      RadarEntry(value: norm(bHydro, maxHydro)),
                      RadarEntry(value: norm(bPins, maxPins)),
                    ],
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(
                    color: Colors.white12, width: 1),
                tickBorderData: const BorderSide(
                    color: Colors.white10, width: 0.5),
                gridBorderData: const BorderSide(
                    color: Colors.white12, width: 0.5),
                tickCount: 5,
                ticksTextStyle: const TextStyle(
                    color: Colors.transparent, fontSize: 0),
                getTitle: (index, angle) {
                  const labels = [
                    'Toplam',
                    'Güneş',
                    'Rüzgar',
                    'HES',
                    'Pin',
                  ];
                  return RadarChartTitle(
                    text: labels[index],
                    angle: angle,
                  );
                },
                titleTextStyle: const TextStyle(
                    color: Colors.white60, fontSize: 11),
                titlePositionPercentageOffset: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _total(Map<String, dynamic> d) {
    return ((d['total_solar_kwh'] as num?)?.toDouble() ?? 0) +
        ((d['total_wind_kwh'] as num?)?.toDouble() ?? 0) +
        ((d['total_hydro_kwh'] as num?)?.toDouble() ?? 0);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: color, fontSize: 10),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

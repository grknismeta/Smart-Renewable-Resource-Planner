import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

/// Harita üzerinde kayan mini senaryo rapor paneli.
/// Seçili senaryolar varken görünür; hesaplama yoksa Calculate butonu,
/// hesaplama varsa aylık bar grafik + CO₂ + finansal özet gösterir.
class ScenarioMiniReportPanel extends StatefulWidget {
  final ThemeViewModel theme;
  final ScenarioViewModel scenarioVM;

  const ScenarioMiniReportPanel({
    super.key,
    required this.theme,
    required this.scenarioVM,
  });

  @override
  State<ScenarioMiniReportPanel> createState() =>
      _ScenarioMiniReportPanelState();
}

class _ScenarioMiniReportPanelState extends State<ScenarioMiniReportPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _calculating = false;

  // Karbondioksit tasarrufu sabiti (Türkiye karma kaynak faktörü ~0.433 kg/kWh)
  static const double _co2PerKwh = 0.433;

  // Basit yatırım maliyeti sabitleri ($/MW)
  static const double _solarCostPerMw = 800000;
  static const double _windCostPerMw = 1200000;
  static const double _hydroCostPerMw = 2000000;

  // YEKDEM fiyatı $/kWh
  static const double _yekdemUsdPerKwh = 0.07;

  @override
  Widget build(BuildContext context) {
    final scenarioVM = widget.scenarioVM;
    final selectedIds = scenarioVM.selectedScenarioIds;
    if (selectedIds.isEmpty) return const SizedBox.shrink();

    final selectedScenarios = scenarioVM.scenarios
        .where((s) => selectedIds.contains(s.id))
        .toList();

    final hasResults = selectedScenarios.any(
      (s) =>
          s.resultData != null &&
          ((s.resultData!['total_kwh'] as num?)?.toDouble() ?? 0) > 0,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: _expanded ? 340 : 210,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: widget.theme.cardColor.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _expanded
                ? _buildExpanded(selectedScenarios, hasResults)
                : _buildCollapsed(selectedScenarios, hasResults),
          ),
        ),
      ),
    );
  }

  // ─── Collapsed (mini) görünüm ────────────────────────────────────────────
  Widget _buildCollapsed(List<Scenario> scenarios, bool hasResults) {
    final count = scenarios.length;
    final totalKwh = _sumTotalKwh(scenarios);
    final label = count == 1 ? 'Senaryo Raporu' : '$count Senaryo';

    return InkWell(
      onTap: () => setState(() => _expanded = true),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, color: Colors.blueAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (hasResults && totalKwh > 0)
                    Text(
                      FormatUtils.formatEnergy(totalKwh),
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.expand_less,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Expanded görünüm ─────────────────────────────────────────────────────
  Widget _buildExpanded(List<Scenario> scenarios, bool hasResults) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(scenarios),
        const Divider(height: 1, color: Colors.white12),
        if (!hasResults)
          _buildNoResultsBody(scenarios)
        else
          _buildResultsBody(scenarios),
      ],
    );
  }

  Widget _buildHeader(List<Scenario> scenarios) {
    final count = scenarios.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, color: Colors.blueAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1
                  ? (scenarios.first.name.length > 20
                      ? '${scenarios.first.name.substring(0, 18)}…'
                      : scenarios.first.name)
                  : '$count Senaryo Raporu',
              style: TextStyle(
                color: widget.theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          // Geniş Ekran
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/reports'),
            icon: const Icon(Icons.open_in_full, size: 16, color: Colors.white54),
            tooltip: 'Geniş Ekran',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          // Kapat
          IconButton(
            onPressed: () => setState(() => _expanded = false),
            icon: const Icon(Icons.expand_more, size: 16, color: Colors.white54),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsBody(List<Scenario> scenarios) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calculate_outlined,
            size: 36,
            color: Colors.blueAccent.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'Henüz hesaplanmamış',
            style: TextStyle(
              color: widget.theme.secondaryTextColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          // Hesapla butonu (ilk senaryo için)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: _calculating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.calculate, size: 16),
              label: Text(
                _calculating ? 'Hesaplanıyor…' : 'Hesapla',
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: _calculating
                  ? null
                  : () => _calculateAll(scenarios),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/reports'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white54,
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: const Text('Rapor Sayfasına Git →'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsBody(List<Scenario> scenarios) {
    final totalKwh = _sumTotalKwh(scenarios);
    final totalSolar = _sumField(scenarios, 'total_solar_kwh');
    final totalWind = _sumField(scenarios, 'total_wind_kwh');
    final totalHydro = _sumField(scenarios, 'total_hydro_kwh');
    final co2Saved = totalKwh * _co2PerKwh / 1000; // ton
    final monthlyBars = _buildMonthlyData(scenarios);
    final financials = _calcFinancials(scenarios);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toplam üretim
          _MetricRow(
            icon: Icons.flash_on,
            color: Colors.greenAccent,
            label: 'Yıllık Üretim',
            value: FormatUtils.formatEnergy(totalKwh),
          ),
          const SizedBox(height: 4),
          // Kaynak dağılımı
          Row(
            children: [
              if (totalSolar > 0)
                _MiniChip(
                  icon: Icons.wb_sunny,
                  color: Colors.orange,
                  value: FormatUtils.formatEnergy(totalSolar),
                ),
              if (totalWind > 0) ...[
                const SizedBox(width: 4),
                _MiniChip(
                  icon: Icons.wind_power,
                  color: Colors.cyan,
                  value: FormatUtils.formatEnergy(totalWind),
                ),
              ],
              if (totalHydro > 0) ...[
                const SizedBox(width: 4),
                _MiniChip(
                  icon: Icons.water_drop,
                  color: Colors.lightBlue,
                  value: FormatUtils.formatEnergy(totalHydro),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Aylık bar grafik
          if (monthlyBars.isNotEmpty) ...[
            Text(
              'Aylık Üretim',
              style: TextStyle(
                color: widget.theme.secondaryTextColor,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 80,
              child: _MonthlyBarChart(data: monthlyBars),
            ),
            const SizedBox(height: 10),
          ],

          // CO₂ tasarrufu
          _MetricRow(
            icon: Icons.eco,
            color: Colors.greenAccent,
            label: 'CO₂ Tasarrufu',
            value: '${FormatUtils.formatDec1(co2Saved)} ton/yıl',
          ),
          const Divider(height: 12, color: Colors.white12),

          // Finansal özet
          _MetricRow(
            icon: Icons.attach_money,
            color: Colors.amberAccent,
            label: 'Tahmini Yatırım',
            value: FormatUtils.formatUsd(financials['investment']!),
          ),
          const SizedBox(height: 4),
          _MetricRow(
            icon: Icons.trending_up,
            color: Colors.lightGreenAccent,
            label: 'Geri Ödeme',
            value: '~${FormatUtils.formatYears(financials['payback']!)}',
          ),
          const SizedBox(height: 4),
          _MetricRow(
            icon: Icons.account_balance,
            color: Colors.blueAccent,
            label: 'Tahmini NPV (25y)',
            value: FormatUtils.formatUsd(financials['npv']!),
          ),

          // Depolama bilgisi
          if (_hasBattery(scenarios)) ...[
            const Divider(height: 12, color: Colors.white12),
            _MetricRow(
              icon: Icons.battery_charging_full,
              color: Colors.greenAccent,
              label: 'Depolama Kapasitesi',
              value: '${_totalBatteryKwh(scenarios).toStringAsFixed(0)} kWh',
            ),
          ],

          const SizedBox(height: 10),
          // Hesapla / Yeniden Hesapla
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: _calculating
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blueAccent,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 14),
                  label: Text(
                    _calculating ? '…' : 'Yenile',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _calculating
                      ? null
                      : () => _calculateAll(scenarios),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.open_in_full, size: 14),
                  label: const Text('Tam Rapor', style: TextStyle(fontSize: 12)),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/reports'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Yardımcı hesaplamalar ────────────────────────────────────────────────

  double _sumTotalKwh(List<Scenario> scenarios) =>
      _sumField(scenarios, 'total_kwh');

  double _sumField(List<Scenario> scenarios, String key) => scenarios.fold(
        0.0,
        (sum, s) =>
            sum + ((s.resultData?[key] as num?)?.toDouble() ?? 0.0),
      );

  /// Aylık üretim verisini tüm seçili senaryolardan toplar.
  /// pin_results[].history[{ds, y}] formatından Month 1-12 dizisine dönüştürür.
  List<double> _buildMonthlyData(List<Scenario> scenarios) {
    final monthly = List<double>.filled(12, 0.0);
    for (final s in scenarios) {
      final pinResults = s.resultData?['pin_results'] as List?;
      if (pinResults == null) continue;
      for (final pinResult in pinResults) {
        final history = pinResult['history'] as List?;
        if (history == null) continue;
        for (final entry in history) {
          final ds = entry['ds'] as String?;
          final y = (entry['y'] as num?)?.toDouble() ?? 0.0;
          if (ds != null && ds.length >= 7) {
            final month = int.tryParse(ds.substring(5, 7));
            if (month != null && month >= 1 && month <= 12) {
              monthly[month - 1] += y;
            }
          }
        }
      }
    }
    // Tüm aylar 0 ise sabit dağılım uygula (grafik boş görünmesin)
    if (monthly.every((v) => v == 0)) {
      final total = _sumTotalKwh(scenarios);
      if (total > 0) {
        for (int i = 0; i < 12; i++) {
          monthly[i] = total / 12;
        }
      }
    }
    return monthly;
  }

  /// Basit finansal tahmin (client-side, gerçek hesap değil)
  Map<String, double> _calcFinancials(List<Scenario> scenarios) {
    double investment = 0.0;
    double annualKwh = 0.0;

    for (final s in scenarios) {
      final pinResults = s.resultData?['pin_results'] as List?;
      if (pinResults == null) continue;
      for (final pr in pinResults) {
        final type = pr['type'] as String? ?? '';
        final kwh = (pr['total_prediction_value'] as num?)?.toDouble() ?? 0.0;
        annualKwh += kwh;
        // Kapasite tahmini: kwh / 8760 (saat) = kW → / 1000 = MW
        // Ama güneşte CF düşük, rüzgarda yüksek — burada sadece maliyet katsayısı
        // Yaklaşık: solar 1600 kWh/kW/y → cap_kw = kwh/1600
        //            wind  2500 kWh/kW/y → cap_kw = kwh/2500
        if (type.contains('Güneş') || type.contains('Solar')) {
          final capMw = kwh / 1600000; // 1600 kWh/kW/y → kWh to MW
          investment += capMw * _solarCostPerMw;
        } else if (type.contains('Rüzgar') || type.contains('Wind')) {
          final capMw = kwh / 2500000;
          investment += capMw * _windCostPerMw;
        } else if (type.contains('Hidroelektrik') || type.contains('Hydro')) {
          final capMw = kwh / 4000000;
          investment += capMw * _hydroCostPerMw;
        }
      }
    }

    // Batarya maliyetini ekle
    for (final s in scenarios) {
      final battCap = s.batteryCapacityKwh ?? 0;
      final battCost = s.batteryCostUsdPerKwh ?? 300;
      investment += battCap * battCost;
    }

    final annualRevenue = annualKwh * _yekdemUsdPerKwh;
    final omCostRate = 0.02; // O&M %2
    final netAnnualRevenue = annualRevenue - (investment * omCostRate);
    final payback = netAnnualRevenue > 0 ? investment / netAnnualRevenue : 0.0;

    // NPV: sum over 25 years with 8% discount rate
    const discount = 0.08;
    const years = 25;
    double npv = -investment;
    for (int y = 1; y <= years; y++) {
      npv += netAnnualRevenue / (1 + discount) .pow(y);
    }

    return {
      'investment': investment,
      'payback': payback,
      'npv': npv,
    };
  }

  bool _hasBattery(List<Scenario> scenarios) =>
      scenarios.any((s) => (s.batteryCapacityKwh ?? 0) > 0);

  double _totalBatteryKwh(List<Scenario> scenarios) => scenarios.fold(
        0.0,
        (sum, s) => sum + (s.batteryCapacityKwh ?? 0),
      );

  Future<void> _calculateAll(List<Scenario> scenarios) async {
    if (_calculating) return;
    setState(() => _calculating = true);
    final vm = widget.scenarioVM;
    try {
      for (final s in scenarios) {
        if (!mounted) break;
        await vm.calculateScenario(s.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesaplama hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }
}

// ─── Yardımcı widget'lar ────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MetricRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;

  const _MiniChip({
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Aylık üretim bar grafiği (12 çubuk).
class _MonthlyBarChart extends StatelessWidget {
  final List<double> data; // 12 eleman

  const _MonthlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = group.x + 1;
              final label = '$month. Ay\n${FormatUtils.formatEnergyShort(rod.toY)} kWh';
              return BarTooltipItem(
                label,
                const TextStyle(color: Colors.white, fontSize: 10),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 14,
              getTitlesWidget: (value, meta) {
                const months = [
                  'O', 'Ş', 'M', 'N', 'M', 'H',
                  'T', 'A', 'E', 'E', 'K', 'A',
                ];
                final idx = value.toInt();
                if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                return Text(
                  months[idx],
                  style: const TextStyle(color: Colors.white38, fontSize: 8),
                );
              },
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
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(12, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.withValues(alpha: 0.9),
                    Colors.cyanAccent.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

extension _DoublePow on double {
  double pow(int exp) {
    double result = 1.0;
    for (int i = 0; i < exp; i++) {
      result *= this;
    }
    return result;
  }
}

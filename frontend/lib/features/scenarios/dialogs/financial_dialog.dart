// lib/features/scenarios/dialogs/financial_dialog.dart
//
// Aşama 3.A — Senaryonun finansal projeksiyonu (LCOE, payback, NPV, IRR,
// CO₂ avoidance, 25 yıllık nakit akışı).
//
// Backend `/scenarios/{id}/financials` endpoint'inden veri çeker; UI'da
// 4 ana metrik kartı + nakit akışı line chart + pin bazlı tablo gösterir.
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/financial_metrics.dart';

class FinancialProjectionDialog extends StatefulWidget {
  final int scenarioId;
  final String scenarioName;
  final ThemeViewModel theme;
  final ApiService apiService;

  const FinancialProjectionDialog({
    super.key,
    required this.scenarioId,
    required this.scenarioName,
    required this.theme,
    required this.apiService,
  });

  @override
  State<FinancialProjectionDialog> createState() =>
      _FinancialProjectionDialogState();
}

class _FinancialProjectionDialogState extends State<FinancialProjectionDialog> {
  FinancialMetrics? _metrics;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await widget.apiService.scenario.fetchScenarioFinancials(
        widget.scenarioId,
      );
      if (!mounted) return;
      setState(() {
        _metrics = m;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(theme),
              const SizedBox(height: 12),
              Expanded(child: _body(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeViewModel theme) {
    return Row(
      children: [
        const Icon(Icons.payments_outlined, color: Colors.amberAccent, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finansal Projeksiyon',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.scenarioName,
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: theme.secondaryTextColor, size: 20),
          tooltip: 'Yenile',
          onPressed: _loading ? null : _fetch,
        ),
        IconButton(
          icon: Icon(Icons.close, color: theme.secondaryTextColor),
          tooltip: 'Kapat',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _body(ThemeViewModel theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Bilinmeyen hata',
                style: TextStyle(color: theme.secondaryTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Yeniden Dene'),
              ),
            ],
          ),
        ),
      );
    }
    final m = _metrics;
    if (m == null) return const SizedBox.shrink();

    final usdToTry = m.assumptionsUsed.usdToTry;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 4 metrik kartı (responsive grid) ─────────────────────────
          LayoutBuilder(builder: (ctx, constraints) {
            final twoCol = constraints.maxWidth >= 600;
            final cards = [
              _MetricCard(
                theme: theme,
                title: 'CAPEX (Yatırım)',
                value: _money(m.capexTotal, usdToTry),
                subtitle: '\$${_compact(m.capexTotal)} USD',
                icon: Icons.account_balance_outlined,
                color: Colors.amberAccent,
              ),
              _MetricCard(
                theme: theme,
                title: 'LCOE',
                value: '${(m.lcoeUsdPerKwh * 100).toStringAsFixed(2)} ¢/kWh',
                subtitle: '${(m.lcoeUsdPerKwh * usdToTry).toStringAsFixed(3)} ₺/kWh',
                icon: Icons.show_chart_rounded,
                color: Colors.cyanAccent,
              ),
              _MetricCard(
                theme: theme,
                title: 'Geri Ödeme',
                value: m.isPaybackInfinite
                    ? 'Geri ödenmez'
                    : '${m.paybackPeriodYears.toStringAsFixed(1)} yıl',
                subtitle: m.isPaybackInfinite
                    ? 'OPEX > Gelir'
                    : 'NPV: \$${_compact(m.npvUsd)}',
                icon: Icons.timer_outlined,
                color: m.isPaybackInfinite
                    ? Colors.redAccent
                    : Colors.lightGreenAccent,
              ),
              _MetricCard(
                theme: theme,
                title: 'CO₂ Avoidance',
                value: '${m.annualCo2AvoidedTons.toStringAsFixed(0)} t/yıl',
                subtitle:
                    '${(m.annualCo2AvoidedTons * m.projectLifetimeYears).toStringAsFixed(0)} t (proje ömrü)',
                icon: Icons.eco_outlined,
                color: Colors.greenAccent,
              ),
            ];
            if (twoCol) {
              return Column(
                children: [
                  Row(children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[1]),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[3]),
                  ]),
                ],
              );
            }
            return Column(
              children: cards
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: c,
                      ))
                  .toList(),
            );
          }),

          const SizedBox(height: 16),

          // ── Yıllık üretim & gelir özeti ─────────────────────────────
          _summaryRow(theme, [
            ('Yıllık Üretim', '${_compact(m.annualProductionKwh / 1000)} GWh'),
            ('Yıllık Gelir', '\$${_compact(m.annualRevenue)} USD'),
            ('Yıllık OPEX', '\$${_compact(m.opexYearly)} USD'),
            (
              'IRR',
              m.irrPct == null ? 'N/A' : '${m.irrPct!.toStringAsFixed(2)} %',
            ),
            ('Proje Ömrü', '${m.projectLifetimeYears} yıl'),
          ]),

          const SizedBox(height: 16),

          // ── Kümülatif nakit akışı line chart ────────────────────────
          if (m.cumulativeCashflows.length > 1) ...[
            Text(
              'Kümülatif Nakit Akışı (USD)',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: _CashflowChart(
                cumulative: m.cumulativeCashflows,
                paybackYear: m.isPaybackInfinite
                    ? null
                    : m.paybackPeriodYears,
                theme: theme,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Pin bazlı detay (expandable) ────────────────────────────
          if (m.perPin.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Pin Detayları (${m.perPin.length})',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              iconColor: theme.secondaryTextColor,
              collapsedIconColor: theme.secondaryTextColor,
              children: m.perPin.map((p) => _pinRow(theme, p)).toList(),
            ),

          const SizedBox(height: 8),
          Text(
            'Varsayımlar: \$${m.assumptionsUsed.electricityPriceUsdPerKwh.toStringAsFixed(3)}/kWh elektrik fiyatı, '
            '%${(m.assumptionsUsed.discountRate * 100).toStringAsFixed(0)} iskonto, '
            '${m.assumptionsUsed.co2IntensityGPerKwh.toStringAsFixed(0)} g CO₂/kWh şebeke yoğunluğu.',
            style: TextStyle(
              color: theme.secondaryTextColor.withValues(alpha: 0.7),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(ThemeViewModel theme, List<(String, String)> items) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.15)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        children: items
            .map((item) => SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1,
                          style: TextStyle(
                              color: theme.secondaryTextColor, fontSize: 10)),
                      Text(item.$2,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _pinRow(ThemeViewModel theme, PinFinanceDetail p) {
    final usdToTry = _metrics?.assumptionsUsed.usdToTry ?? 33.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(_iconFor(p.type), size: 14, color: _colorFor(p.type)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${p.type} #${p.pinId}  ·  ${p.capacityMw.toStringAsFixed(1)} MW'
              '${p.capacityFactor != null ? "  ·  CF ${(p.capacityFactor! * 100).toStringAsFixed(0)}%" : ""}',
              style: TextStyle(color: theme.textColor, fontSize: 11),
            ),
          ),
          Text(
            '${(p.lcoeUsdPerKwh * usdToTry).toStringAsFixed(3)} ₺/kWh',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'Güneş Paneli': return Icons.wb_sunny_outlined;
      case 'Rüzgar Türbini': return Icons.air;
      case 'Hidroelektrik': return Icons.water_drop_outlined;
      default: return Icons.bolt_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'Güneş Paneli': return Colors.amberAccent;
      case 'Rüzgar Türbini': return Colors.cyanAccent;
      case 'Hidroelektrik': return Colors.lightBlueAccent;
      default: return Colors.grey;
    }
  }

  String _compact(double v) {
    final abs = v.abs();
    if (abs >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (abs >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (abs >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _money(double usd, double usdToTry) {
    final tl = usd * usdToTry;
    return '${_compact(tl)} ₺';
  }
}

// ─── Yardımcı widget'lar ─────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final ThemeViewModel theme;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.theme,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.secondaryTextColor.withValues(alpha: 0.85),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowChart extends StatelessWidget {
  final List<double> cumulative;
  final double? paybackYear;
  final ThemeViewModel theme;

  const _CashflowChart({
    required this.cumulative,
    required this.paybackYear,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < cumulative.length; i++) {
      spots.add(FlSpot(i.toDouble(), cumulative[i] / 1e6)); // M USD
    }
    final maxY = cumulative.reduce((a, b) => a > b ? a : b) / 1e6;
    final minY = cumulative.reduce((a, b) => a < b ? a : b) / 1e6;
    final range = (maxY - minY).abs();
    final pad = range > 0 ? range * 0.1 : 1.0;

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.secondaryTextColor.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                '${v.toStringAsFixed(0)}M',
                style: TextStyle(
                    color: theme.secondaryTextColor, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (cumulative.length / 6).ceilToDouble().clamp(1, 10),
              getTitlesWidget: (v, _) => Text(
                'Y${v.toInt()}',
                style: TextStyle(
                    color: theme.secondaryTextColor, fontSize: 9),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: theme.secondaryTextColor.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: [4, 3],
            ),
          ],
          verticalLines: paybackYear != null
              ? [
                  VerticalLine(
                    x: paybackYear!,
                    color: Colors.lightGreenAccent.withValues(alpha: 0.6),
                    strokeWidth: 2,
                    dashArray: [3, 3],
                    label: VerticalLineLabel(
                      show: true,
                      labelResolver: (_) =>
                          'Payback ${paybackYear!.toStringAsFixed(1)}y',
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]
              : const [],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: Colors.cyanAccent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.cyanAccent.withValues(alpha: 0.25),
                  Colors.cyanAccent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      'Y${s.x.toInt()}: \$${s.y.toStringAsFixed(2)}M',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

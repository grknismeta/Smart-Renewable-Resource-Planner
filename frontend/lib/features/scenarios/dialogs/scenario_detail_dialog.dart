import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/features/scenarios/dialogs/financial_dialog.dart';
import 'package:frontend/core/theme/app_theme.dart';

class ScenarioDetailDialog extends StatefulWidget {
  final Scenario scenario;
  final ThemeViewModel theme;
  final VoidCallback onEdit;

  const ScenarioDetailDialog({
    super.key,
    required this.scenario,
    required this.theme,
    required this.onEdit,
  });

  @override
  State<ScenarioDetailDialog> createState() => _ScenarioDetailDialogState();
}

class _ScenarioDetailDialogState extends State<ScenarioDetailDialog> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final scenario = widget.scenario;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              scenario.name,
              style: TextStyle(color: theme.textColor),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: theme.secondaryTextColor),
            onPressed: () {
              Navigator.pop(context);
              widget.onEdit();
            },
            tooltip: "Düzenle",
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scenario.description != null) ...[
              Text(
                scenario.description!,
                style: TextStyle(color: theme.secondaryTextColor),
              ),
              const SizedBox(height: 16),
            ],
            if (scenario.startDate != null)
              _InfoRow(
                'Başlangıç',
                '${scenario.startDate!.day}/${scenario.startDate!.month}/${scenario.startDate!.year}',
                theme,
              ),
            if (scenario.endDate != null)
              _InfoRow(
                'Bitiş',
                '${scenario.endDate!.day}/${scenario.endDate!.month}/${scenario.endDate!.year}',
                theme,
              ),
            _InfoRow('Pin Sayısı', '${scenario.pinIds.length}', theme),
            if (scenario.pinIds.isNotEmpty)
              _InfoRow('Pin IDler', scenario.pinIds.join(', '), theme),
            if (scenario.resultData != null) ...[
              const SizedBox(height: 20),
              Text(
                'Enerji Üretim Analizi',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _buildResultSummary(scenario.resultData!, theme),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        // Aşama 3.A — Finansal Projeksiyon (LCOE/Payback/NPV/CO₂)
        ElevatedButton.icon(
          icon: const Icon(Icons.payments_outlined, size: 16),
          label: const Text('Finansal'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amberAccent,
            foregroundColor: Colors.black87,
          ),
          onPressed: () {
            final api = Provider.of<ApiService>(context, listen: false);
            showDialog(
              context: context,
              builder: (_) => FinancialProjectionDialog(
                scenarioId: scenario.id,
                scenarioName: scenario.name,
                theme: widget.theme,
                apiService: api,
              ),
            );
          },
        ),
        if (scenario.startDate != null && scenario.endDate != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final sp = Provider.of<ScenarioViewModel>(context, listen: false);
                // ignore: use_build_context_synchronously
                await sp.calculateScenario(scenario.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Senaryo hesaplandı!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hesaplama hatası: $e')),
                  );
                }
              }
            },
            child: const Text('Hesapla', style: TextStyle(color: Colors.white)),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context).pushReplacementNamed('/reports');
          },
          child: const Text('Rapora Git'),
        ),
      ],
    );
  }

  // ── Sonuç Özeti ─────────────────────────────────────────────────────────────
  Widget _buildResultSummary(Map<String, dynamic> data, ThemeViewModel theme) {
    final double totalSolar = (data['total_solar_kwh'] as num?)?.toDouble() ?? 0;
    final double totalWind  = (data['total_wind_kwh']  as num?)?.toDouble() ?? 0;
    final double totalHydro = (data['total_hydro_kwh'] as num?)?.toDouble() ?? 0;
    final double totalEnergy = (data['total_kwh']      as num?)?.toDouble() ?? 0;
    final int solarCount = (data['solar_count'] as num?)?.toInt() ?? 0;
    final int windCount  = (data['wind_count']  as num?)?.toInt() ?? 0;
    final int hydroCount = (data['hydro_count'] as num?)?.toInt() ?? 0;

    final bool hasPie = totalEnergy > 0;

    return Column(
      children: [
        // Toplam üretim
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOPLAM ÜRETİM', style: TextStyle(color: theme.secondaryTextColor, fontSize: 11)),
                  Text(
                    FormatUtils.formatEnergy(totalEnergy),
                    style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pasta grafik
        if (hasPie) ...[
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                      sections: _buildPieSections(totalSolar, totalWind, totalHydro, totalEnergy),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _buildLegend(
                    solarCount: solarCount, windCount: windCount, hydroCount: hydroCount,
                    totalSolar: totalSolar, totalWind: totalWind, totalHydro: totalHydro,
                    totalEnergy: totalEnergy, theme: theme,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Kaynak kartları
        Row(
          children: [
            Expanded(
              child: _buildSourceCard('Güneş ($solarCount)', FormatUtils.formatEnergy(totalSolar), Icons.wb_sunny, Colors.orangeAccent, theme),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSourceCard('Rüzgar ($windCount)', FormatUtils.formatEnergy(totalWind), Icons.air, Colors.lightBlueAccent, theme),
            ),
          ],
        ),
        if (totalHydro > 0 || hydroCount > 0) ...[
          const SizedBox(height: 10),
          _buildSourceCard('HES ($hydroCount)', FormatUtils.formatEnergy(totalHydro), Icons.water_drop, Colors.cyanAccent, theme),
        ],
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections(
    double solar, double wind, double hydro, double total,
  ) {
    if (total == 0) return [];
    final sources = [
      (solar, Colors.orangeAccent, 'Güneş', 0),
      (wind, Colors.lightBlueAccent, 'Rüzgar', 1),
      if (hydro > 0) (hydro, Colors.cyanAccent, 'HES', 2),
    ];

    return sources.map((s) {
      final value = s.$1;
      final color = s.$2;
      final isTouched = s.$4 == _touchedIndex;
      final radius = isTouched ? 64.0 : 52.0;
      final pct = total > 0 ? (value / total * 100) : 0.0;

      return PieChartSectionData(
        color: color,
        value: value,
        radius: radius,
        showTitle: isTouched,
        title: '${pct.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: isTouched ? null : null,
      );
    }).toList();
  }

  Widget _buildLegend({
    required int solarCount, required int windCount, required int hydroCount,
    required double totalSolar, required double totalWind, required double totalHydro,
    required double totalEnergy, required ThemeViewModel theme,
  }) {
    final items = [
      (Colors.orangeAccent, 'Güneş', totalSolar, totalEnergy),
      (Colors.lightBlueAccent, 'Rüzgar', totalWind, totalEnergy),
      if (totalHydro > 0) (Colors.cyanAccent, 'HES', totalHydro, totalEnergy),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final pct = item.$4 > 0 ? (item.$3 / item.$4 * 100) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: item.$1, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${item.$2}  ${pct.toStringAsFixed(1)}%',
                  style: TextStyle(color: theme.textColor, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSourceCard(
    String title, String value, IconData icon, Color color, ThemeViewModel theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(color: theme.secondaryTextColor, fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: theme.textColor, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeViewModel theme;

  const _InfoRow(this.label, this.value, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.secondaryTextColor, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(color: theme.textColor, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

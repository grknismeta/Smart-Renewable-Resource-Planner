import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';

class ReportListPanel extends StatelessWidget {
  final ValueChanged<RegionalSite> onSiteSelected;

  const ReportListPanel({super.key, required this.onSiteSelected});

  @override
  Widget build(BuildContext context) {
    final reportViewModel = Provider.of<ReportViewModel>(context);
    final report = reportViewModel.report;

    if (reportViewModel.isBusy && report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (report == null || report.items.isEmpty) {
      return const Center(
        child: Text(
          'Bu bölge için veri bulunamadı.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${report.region} Özet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (report.stats != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatChip(
                      'Maks Skor',
                      report.stats!.maxScore.toStringAsFixed(1),
                    ),
                    StatChip(
                      'Ortalama',
                      report.stats!.avgScore.toStringAsFixed(1),
                    ),
                    StatChip(
                      'Min Skor',
                      report.stats!.minScore.toStringAsFixed(1),
                    ),
                    StatChip('Alan', report.stats!.siteCount.toString()),
                  ],
                ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: report.items.length,
            itemBuilder: (context, index) {
              final site = report.items[index];
              final t = report.items.length > 1
                  ? index / (report.items.length - 1)
                  : 0.0;
              final color =
                  Color.lerp(Colors.greenAccent, Colors.redAccent, t) ??
                  Colors.greenAccent;

              return GestureDetector(
                onTap: () {
                  Provider.of<ReportViewModel>(
                    context,
                    listen: false,
                  ).setFocusedSite(site);
                  onSiteSelected(site);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${site.city}${site.district != null ? ' / ${site.district}' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'Skor ${site.overallScore.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (site.displayValue != null)
                            MetricChip(
                              label: site.displayUnit ?? 'Değer',
                              value: site.displayValue!.toStringAsFixed(
                                site.displayUnit == 'm/s' ? 1 : 0,
                              ),
                            )
                          else ...[
                            if (site.annualSolarIrradianceKwhM2 != null)
                              MetricChip(
                                label: 'Güneş (kWh/m²-yıl)',
                                value: site.annualSolarIrradianceKwhM2!
                                    .toStringAsFixed(0),
                              ),
                            if (site.avgWindSpeedMs != null)
                              MetricChip(
                                label: 'Rüzgar (m/s)',
                                value: site.avgWindSpeedMs!.toStringAsFixed(1),
                              ),
                          ],
                          MetricChip(label: 'Tip', value: site.type),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class StatChip extends StatelessWidget {
  final String label;
  final String value;

  const StatChip(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const MetricChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

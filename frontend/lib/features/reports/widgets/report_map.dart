import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';

class ReportMap extends StatelessWidget {
  final String type;
  final ValueChanged<RegionalSite> onSiteFocused;

  const ReportMap({
    super.key,
    required this.type,
    required this.onSiteFocused,
  });

  Color _colorForRank(int index, int total) {
    if (total <= 1) return Colors.greenAccent;
    final t = index / (total - 1);
    return Color.lerp(Colors.greenAccent, Colors.redAccent, t) ?? Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final reportViewModel = Provider.of<ReportViewModel>(context);
    final report = reportViewModel.report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text(
                report != null ? '${report.region} • ${report.type}' : 'Yükleniyor...',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (reportViewModel.isBusy)
                const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        Expanded(
          child: report == null || report.items.isEmpty
              ? const Center(
                  child: Text('Veri bulunamadı', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: report.items.length,
                  itemBuilder: (context, i) {
                    final site = report.items[i];
                    final color = _colorForRank(i, report.items.length);
                    return InkWell(
                      onTap: () => onSiteFocused(site),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${site.city}${site.district != null ? ' / ${site.district}' : ''}',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                            Text(
                              site.overallScore.toStringAsFixed(1),
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
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

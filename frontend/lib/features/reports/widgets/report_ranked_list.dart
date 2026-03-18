import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';

/// Skor sıralamalı lokasyon listesi.
/// Her satır: [Sıra] [İsim + progress bar] [Değer / Puan]
class ReportRankedList extends StatelessWidget {
  final ValueChanged<RegionalSite> onSiteSelected;
  final String type; // 'Wind' | 'Solar'

  const ReportRankedList({
    super.key,
    required this.onSiteSelected,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<ReportViewModel>(context);
    final report = vm.report;

    // Yükleniyor
    if (vm.isBusy && report == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
            color: Colors.cyanAccent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Boş / hata
    if (report == null || report.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 42,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bu bölge için veri bulunamadı.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final maxScore = report.stats?.maxScore ?? report.items.first.overallScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık satırı
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Row(
            children: [
              const Icon(
                Icons.format_list_numbered_rounded,
                size: 14,
                color: Colors.cyanAccent,
              ),
              const SizedBox(width: 6),
              Text(
                'Top ${report.items.length} Lokasyon',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Arka planda güncelleme spinner'ı
              if (vm.isBusy)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.cyanAccent,
                  ),
                ),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: report.items.length,
            itemBuilder: (ctx, i) {
              final site = report.items[i];
              return _SiteRow(
                site: site,
                rank: i + 1,
                maxScore: maxScore,
                onTap: () => onSiteSelected(site),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Tek Satır ───────────────────────────────────────────────────────────────

class _SiteRow extends StatelessWidget {
  final RegionalSite site;
  final int rank;
  final double maxScore;
  final VoidCallback onTap;

  const _SiteRow({
    required this.site,
    required this.rank,
    required this.maxScore,
    required this.onTap,
  });

  Color get _rankColor {
    if (rank == 1) return Colors.amberAccent;
    if (rank == 2) return const Color(0xFFB0BEC5); // gümüş
    if (rank == 3) return const Color(0xFFFF8A65); // bronz
    return Colors.white.withValues(alpha: 0.35);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = maxScore > 0
        ? (site.overallScore / maxScore).clamp(0.0, 1.0)
        : 0.0;

    // Bar rengi: kötü=kırmızı → iyi=yeşil
    final barColor =
        Color.lerp(Colors.redAccent, Colors.greenAccent, ratio) ??
            Colors.greenAccent;

    final name = (site.district?.isNotEmpty ?? false)
        ? '${site.city} / ${site.district}'
        : site.city;

    // Gösterilecek değer
    final valText = (site.displayValue != null && site.displayUnit != null)
        ? '${FormatUtils.formatDec1(site.displayValue!)} ${site.displayUnit}'
        : FormatUtils.formatDec1(site.overallScore);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            // Sıra
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: _rankColor,
                  fontSize: rank <= 3 ? 12 : 11,
                  fontWeight:
                      rank <= 3 ? FontWeight.w700 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),

            // İsim + progress bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  LayoutBuilder(
                    builder: (ctx, constraints) => Stack(
                      children: [
                        // Arka plan
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Değer barı
                        Container(
                          height: 3,
                          width: constraints.maxWidth * ratio,
                          decoration: BoxDecoration(
                            color: barColor.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Değer + puan
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  valText,
                  style: TextStyle(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  FormatUtils.formatDec1(site.overallScore),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

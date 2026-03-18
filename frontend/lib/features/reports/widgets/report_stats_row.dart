import 'package:flutter/material.dart';

import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/data/models/system_data_models.dart';

/// Raporun üst kısmında 4 özet kart gösterir:
/// En İyi Lokasyon · Ortalama Puan · Toplam Nokta · Maks Puan
class ReportStatsRow extends StatelessWidget {
  final RegionalReport report;
  final String type; // 'Wind' | 'Solar'

  const ReportStatsRow({
    super.key,
    required this.report,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final items = report.items;
    final stats = report.stats;
    if (items.isEmpty) return const SizedBox.shrink();

    final best = items.first; // zaten puana göre sıralı

    // En iyi lokasyon için değer metni
    String bestVal;
    if (best.displayValue != null && best.displayUnit != null) {
      bestVal = '${FormatUtils.formatDec1(best.displayValue!)} ${best.displayUnit}';
    } else if (type == 'Wind' && best.avgWindSpeedMs != null) {
      bestVal = '${FormatUtils.formatDec1(best.avgWindSpeedMs!)} m/s';
    } else if (type == 'Solar' && best.annualSolarIrradianceKwhM2 != null) {
      bestVal = '${FormatUtils.formatDec1(best.annualSolarIrradianceKwhM2!)} kWh/m²';
    } else {
      bestVal = 'Puan ${FormatUtils.formatDec1(best.overallScore)}';
    }

    final bestName = (best.district?.isNotEmpty ?? false)
        ? '${best.city} / ${best.district}'
        : best.city;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatCard(
            icon: type == 'Wind'
                ? Icons.air_rounded
                : Icons.wb_sunny_rounded,
            color: type == 'Wind' ? Colors.cyanAccent : Colors.orangeAccent,
            title: 'En İyi Lokasyon',
            value: bestName,
            sub: bestVal,
          ),
          if (stats != null)
            _StatCard(
              icon: Icons.analytics_rounded,
              color: Colors.greenAccent,
              title: 'Ortalama Puan',
              value: FormatUtils.formatDec1(stats.avgScore),
              sub: '${stats.siteCount} nokta',
            ),
          _StatCard(
            icon: Icons.location_city_rounded,
            color: Colors.purpleAccent,
            title: 'Bölge',
            value: report.region,
            sub: '${items.length} lokasyon',
          ),
          if (stats != null)
            _StatCard(
              icon: Icons.star_rounded,
              color: Colors.amberAccent,
              title: 'Maks. Puan',
              value: FormatUtils.formatDec1(stats.maxScore),
              sub: 'Min: ${FormatUtils.formatDec1(stats.minScore)}',
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String sub;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

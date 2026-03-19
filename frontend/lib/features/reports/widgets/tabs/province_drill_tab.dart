// lib/features/reports/widgets/tabs/province_drill_tab.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';

/// Tab 2 — İl Analizi
/// Sol: Kaydırmalı il listesi  |  Sağ: Detay paneli + RadarChart
class ProvinceDrillTab extends StatelessWidget {
  const ProvinceDrillTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    final theme = context.watch<ThemeViewModel>();
    final provinces = vm.provinceSummaries;

    if (vm.isBusy && provinces.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (provinces.isEmpty) {
      return const Center(
        child: Text(
          'İl verisi bulunamadı.',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 650;
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 220,
              child: _ProvinceList(vm: vm, theme: theme),
            ),
            const SizedBox(width: 12),
            Expanded(child: _ProvinceDetail(vm: vm, theme: theme)),
          ],
        );
      }
      // Dar ekran — liste üstte, detay altta
      return Column(
        children: [
          SizedBox(
            height: 180,
            child: _ProvinceList(vm: vm, theme: theme),
          ),
          const SizedBox(height: 8),
          Expanded(child: _ProvinceDetail(vm: vm, theme: theme)),
        ],
      );
    });
  }
}

// ── Province List ────────────────────────────────────────────────────────────

class _ProvinceList extends StatelessWidget {
  final ReportViewModel vm;
  final ThemeViewModel theme;

  const _ProvinceList({required this.vm, required this.theme});

  @override
  Widget build(BuildContext context) {
    final provinces = vm.provinceSummaries;
    final selected = vm.selectedProvinceIndex ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.location_city_rounded,
                    size: 14, color: Colors.cyanAccent),
                const SizedBox(width: 6),
                Text(
                  'İller (${provinces.length})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: provinces.length,
              itemBuilder: (context, idx) {
                final p = provinces[idx];
                final isActive = idx == selected;
                final score = _computeScore(p);
                return _ProvinceListItem(
                  name: p.provinceName,
                  score: score,
                  isActive: isActive,
                  onTap: () => vm.setSelectedProvinceIndex(idx),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvinceListItem extends StatelessWidget {
  final String name;
  final double score;
  final bool isActive;
  final VoidCallback onTap;

  const _ProvinceListItem({
    required this.name,
    required this.score,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.4))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isActive ? Colors.cyanAccent : Colors.white70,
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _scoreColor(score).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  color: _scoreColor(score),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Province Detail ───────────────────────────────────────────────────────────

class _ProvinceDetail extends StatelessWidget {
  final ReportViewModel vm;
  final ThemeViewModel theme;

  const _ProvinceDetail({required this.vm, required this.theme});

  @override
  Widget build(BuildContext context) {
    final p = vm.selectedProvinceSummary;
    if (p == null) {
      return const Center(
        child: Text(
          'Sol listeden bir il seçin.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    final score = _computeScore(p);
    final lcoe = (2.8 - (score / 100) * 1.2);
    final roi = (10 + (score / 100) * 20);
    final amort = (8 - (score / 100) * 5);
    final irr = (8 + (score / 100) * 16);

    final solarVal = p.avgRadiation ?? 0;
    final windVal = p.avgWindSpeed ?? 0;
    final tempVal = p.avgTemperature ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık ─────────────────────────────────────────────────────────
          _DetailHeader(name: p.provinceName, score: score),
          const SizedBox(height: 12),

          // ── Stat Chip'leri ─────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.wb_sunny_rounded,
                label: 'Güneş',
                value: '${solarVal.toStringAsFixed(1)} W/m²',
                color: Colors.orangeAccent,
              ),
              _StatChip(
                icon: Icons.air_rounded,
                label: 'Rüzgar',
                value: '${windVal.toStringAsFixed(1)} m/s',
                color: Colors.blueAccent,
              ),
              _StatChip(
                icon: Icons.thermostat_rounded,
                label: 'Sıcaklık',
                value: '${tempVal.toStringAsFixed(1)} °C',
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── ROI Grid ───────────────────────────────────────────────────────
          _RoiGrid(lcoe: lcoe, roi: roi, amort: amort, irr: irr),
          const SizedBox(height: 14),

          // ── Radar Chart ────────────────────────────────────────────────────
          _ProvinceRadarChart(province: p, score: score),
          const SizedBox(height: 14),

          // ── Haritada Görüntüle ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // Rapor tab 5'e (Harita) geç
                DefaultTabController.of(context).animateTo(4);
              },
              icon: const Icon(Icons.map_outlined,
                  size: 16, color: Colors.cyanAccent),
              label: const Text(
                'Haritada Görüntüle',
                style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: Colors.cyanAccent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail Header ─────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  final String name;
  final double score;

  const _DetailHeader({required this.name, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.cyanAccent.withValues(alpha: 0.08),
            Colors.blueAccent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Türkiye',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          _ScoreBadge(score: score),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        color: color.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              score.toStringAsFixed(0),
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'puan',
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.7), fontSize: 10)),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── ROI Grid ──────────────────────────────────────────────────────────────────

class _RoiGrid extends StatelessWidget {
  final double lcoe, roi, amort, irr;
  const _RoiGrid(
      {required this.lcoe,
      required this.roi,
      required this.amort,
      required this.irr});

  @override
  Widget build(BuildContext context) {
    final items = [
      _RoiItem(
          label: 'LCOE',
          value: '${lcoe.toStringAsFixed(2)} ₺/kWh',
          icon: Icons.bolt_rounded,
          color: Colors.amberAccent),
      _RoiItem(
          label: 'ROI',
          value: '${roi.toStringAsFixed(1)} %',
          icon: Icons.trending_up_rounded,
          color: Colors.greenAccent),
      _RoiItem(
          label: 'Amortisman',
          value: '${amort.toStringAsFixed(1)} yıl',
          icon: Icons.timeline_rounded,
          color: Colors.purpleAccent),
      _RoiItem(
          label: 'IRR',
          value: '${irr.toStringAsFixed(1)} %',
          icon: Icons.account_balance_rounded,
          color: Colors.cyanAccent),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: items.map((i) => _RoiCard(item: i)).toList(),
    );
  }
}

class _RoiItem {
  final String label, value;
  final IconData icon;
  final Color color;
  _RoiItem(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
}

class _RoiCard extends StatelessWidget {
  final _RoiItem item;
  const _RoiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.label,
                    style: TextStyle(
                        color: item.color.withValues(alpha: 0.7),
                        fontSize: 10)),
                Text(item.value,
                    style: TextStyle(
                        color: item.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Radar Chart ───────────────────────────────────────────────────────────────

class _ProvinceRadarChart extends StatelessWidget {
  final ProvinceSummary province;
  final double score;

  const _ProvinceRadarChart(
      {required this.province, required this.score});

  @override
  Widget build(BuildContext context) {
    final solar = ((province.avgRadiation ?? 0) / 800).clamp(0.0, 1.0);
    final wind = ((province.avgWindSpeed ?? 0) / 10).clamp(0.0, 1.0);
    final temp = ((province.avgTemperature ?? 0 + 10) / 50).clamp(0.0, 1.0);
    final cost = (1.0 - score / 100).clamp(0.0, 1.0);
    final land = (score / 100).clamp(0.0, 1.0);

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
                'Potansiyel Radar',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: RadarChart(
              duration: Duration.zero,
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor:
                        Colors.cyanAccent.withValues(alpha: 0.2),
                    borderColor: Colors.cyanAccent,
                    borderWidth: 2,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: solar * 5),
                      RadarEntry(value: wind * 5),
                      RadarEntry(value: temp * 5),
                      RadarEntry(value: cost * 5),
                      RadarEntry(value: land * 5),
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
                    'Güneş',
                    'Rüzgar',
                    'HES',
                    'Maliyet Av.',
                    'Arazi',
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
}

// ── Helpers ───────────────────────────────────────────────────────────────────

double _computeScore(ProvinceSummary p) {
  final solarScore = ((p.avgRadiation ?? 0) / 800 * 50).clamp(0.0, 50.0);
  final windScore = ((p.avgWindSpeed ?? 0) / 10 * 30).clamp(0.0, 30.0);
  final tempScore = ((p.avgTemperature ?? 15 - 20).abs() < 20 ? 20.0 : 10.0);
  return (solarScore + windScore + tempScore).clamp(0.0, 100.0);
}

Color _scoreColor(double score) {
  if (score >= 70) return Colors.greenAccent;
  if (score >= 45) return Colors.orangeAccent;
  return Colors.redAccent;
}

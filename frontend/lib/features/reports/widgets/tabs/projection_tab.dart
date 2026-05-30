// lib/features/reports/widgets/tabs/projection_tab.dart
//
// Sprint P2 — ML Projeksiyon tab'ı (7. tab).
//
// İçerik:
//   • Mod sekmeleri: Pin (santral) vs İl (climatology)
//   • Pin modu: pin dropdown + horizon slider (1-10 yıl)
//   • İl modu: il dropdown + kaynak/metric chip'ler + horizon slider
//   • Chart: historical + forecast line + 95% CI bandı (fl_chart)
//   • Yıllık KPI grid: her yıl için toplam
//   • Footer: order/mape/method rozeti + disclaimer
//
// Backend: /ml/project/pin/{id} | /ml/project/province/{name}

import 'dart:ui' show ImageFilter;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/reports/viewmodels/projection_viewmodel.dart';
import 'package:frontend/features/reports/widgets/common/report_ui.dart';

class ProjectionTab extends StatelessWidget {
  /// Pin "Detaylı Rapor" ile gelirse projeksiyon o pin'le açılır.
  final int? initialPinId;

  /// İl seçilerek gelirse projeksiyon İl moduna o ille açılır.
  final String? initialProvince;

  const ProjectionTab({super.key, this.initialPinId, this.initialProvince});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ProjectionViewModel(
        Provider.of<ApiService>(ctx, listen: false),
      )..init(
          initialPinId: initialPinId,
          initialProvince: initialProvince,
        ),
      child: const _ProjectionBody(),
    );
  }
}

class _ProjectionBody extends StatelessWidget {
  const _ProjectionBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProjectionViewModel>();

    if (vm.isBusy && vm.pins.isEmpty && vm.provinces.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.cyanAccent,
          strokeWidth: 2,
        ),
      );
    }

    if (vm.health != null && !vm.health!.ready) {
      return _MlNotReadyView(health: vm.health!);
    }

    // Mission Control tema: koyu lacivert zemin + glassmorphism paneller.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1124), Color(0xFF0F172A), Color(0xFF111B30)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Üst kontrol şeridi (glass) ────────────────────────────
            _GlassPanel(
              accent: const Color(0xFF22D3EE),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  _ModeBar(vm: vm),
                  const SizedBox(height: 10),
                  _Toolbar(vm: vm),
                  const SizedBox(height: 8),
                  _HorizonSlider(vm: vm),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Ana panel: sol chart + sağ AI KPI sidebar ──────────────
            LayoutBuilder(
              builder: (ctx, c) {
                final wide = c.maxWidth >= 900;
                final chart = _NeonProjectionChart(vm: vm);
                final sidebar = _AiKpiSidebar(vm: vm);
                if (wide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 67, child: chart),
                        const SizedBox(width: 14),
                        Expanded(flex: 33, child: sidebar),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 380, child: chart),
                    const SizedBox(height: 14),
                    sidebar,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            // ── Detay paneller (glass-wrapped) ─────────────────────────
            _GlassPanel(child: _AnnualKpiGrid(vm: vm)),
            const SizedBox(height: 12),
            _GlassPanel(child: _MetadataCard(vm: vm)),
            if (vm.mode == ProjectionMode.pin && vm.selectedPin != null) ...[
              const SizedBox(height: 12),
              PinFinancialCard(pinId: vm.selectedPin!.id),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Mode Bar ─────────────────────────────────────────────────────────────────

class _ModeBar extends StatelessWidget {
  final ProjectionViewModel vm;
  const _ModeBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            label: 'Santral',
            icon: Icons.factory_rounded,
            active: vm.mode == ProjectionMode.pin,
            onTap: () => vm.setMode(ProjectionMode.pin),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            label: 'İl İklim',
            icon: Icons.location_city_rounded,
            active: vm.mode == ProjectionMode.province,
            onTap: () => vm.setMode(ProjectionMode.province),
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? Colors.cyanAccent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? Colors.cyanAccent : Colors.white60,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.cyanAccent : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toolbar (mod-spesifik seçiciler) ─────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final ProjectionViewModel vm;
  const _Toolbar({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.mode == ProjectionMode.pin) {
      return _PinSelector(vm: vm);
    }
    return _ProvinceSelector(vm: vm);
  }
}

class _PinSelector extends StatelessWidget {
  final ProjectionViewModel vm;
  const _PinSelector({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.pins.isEmpty) {
      return ReportCard(
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.orange, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Henüz pin eklenmemiş. Haritadan santral pin\'i ekleyerek '
                'projeksiyon alabilirsin.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return ReportCard(
      child: Row(
        children: [
          const Icon(Icons.factory_rounded,
              color: Colors.cyanAccent, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Santral:',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: vm.selectedPin?.id,
                isExpanded: true,
                dropdownColor: const Color(0xFF1F2937),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                iconEnabledColor: Colors.white54,
                hint: const Text(
                  'Pin seç…',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                items: vm.pins.map<DropdownMenuItem<int>>((Pin p) {
                  final loc = p.locationLabel;
                  return DropdownMenuItem<int>(
                    value: p.id,
                    child: Text(
                      loc.isNotEmpty ? '${p.name} • $loc' : p.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final pin = vm.pins.firstWhere((p) => p.id == id);
                  vm.selectPin(pin);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvinceSelector extends StatelessWidget {
  final ProjectionViewModel vm;
  const _ProvinceSelector({required this.vm});

  static const _resourceMetrics = <String, List<MapEntry<String, String>>>{
    'solar': [
      MapEntry('sunshine', 'Güneşlenme (saat)'),
      MapEntry('cloud', 'Bulutluluk'),
    ],
    'wind': [
      MapEntry('cloud', 'Bulutluluk'),
      MapEntry('precipitation', 'Yağış'),
    ],
    'hydro': [
      MapEntry('discharge', 'Nehir debisi'),
      MapEntry('precipitation', 'Yağış'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    if (vm.provinces.isEmpty) {
      return ReportCard(
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.orange, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'İl listesi yüklenemedi. Bağlantıyı kontrol et.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    final metrics = _resourceMetrics[vm.provinceResource] ?? const [];
    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── İl seçici
          Row(
            children: [
              const Icon(Icons.location_city_rounded,
                  color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 8),
              const Text(
                'İl:',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: vm.selectedProvince,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1F2937),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    iconEnabledColor: Colors.white54,
                    hint: const Text(
                      'İl seç…',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    items: vm.provinces
                        .map((p) => DropdownMenuItem<String>(
                              value: p,
                              child: Text(p, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) vm.selectProvince(v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Kaynak rozetleri
          Row(
            children: [
              _ResourceChip(
                label: 'Solar',
                color: ReportColors.solar,
                active: vm.provinceResource == 'solar',
                onTap: () => vm.setProvinceResource('solar'),
              ),
              const SizedBox(width: 6),
              _ResourceChip(
                label: 'Wind',
                color: ReportColors.wind,
                active: vm.provinceResource == 'wind',
                onTap: () => vm.setProvinceResource('wind'),
              ),
              const SizedBox(width: 6),
              _ResourceChip(
                label: 'Hydro',
                color: ReportColors.hydro,
                active: vm.provinceResource == 'hydro',
                onTap: () => vm.setProvinceResource('hydro'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Metrik (kaynağa göre)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in metrics)
                _MetricChip(
                  label: m.value,
                  active: vm.provinceMetric == m.key,
                  onTap: () => vm.setProvinceMetric(m.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ResourceChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _MetricChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? Colors.cyanAccent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active
                ? Colors.cyanAccent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.cyanAccent : Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Horizon slider ───────────────────────────────────────────────────────────

class _HorizonSlider extends StatelessWidget {
  final ProjectionViewModel vm;
  const _HorizonSlider({required this.vm});

  @override
  Widget build(BuildContext context) {
    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  color: Colors.cyanAccent, size: 14),
              const SizedBox(width: 6),
              const Text(
                'Tahmin ufku',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '${vm.years} yıl',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.cyanAccent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
              thumbColor: Colors.cyanAccent,
              overlayColor: Colors.cyanAccent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: vm.years.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '${vm.years} yıl',
              onChanged: (v) => vm.setYears(v.toInt()),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart Card ───────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final ProjectionViewModel vm;
  const _ChartCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    return ReportCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Geçmiş + Tahmin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (vm.forecastLoading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.cyanAccent,
                  ),
                )
              else
                IconButton(
                  tooltip: 'Yenile',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: Colors.white54,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => vm.refresh(),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _LegendRow(),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: _buildChart(vm)),
        ],
      ),
    );
  }

  Widget _buildChart(ProjectionViewModel vm) {
    if (vm.forecastError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            vm.forecastError!.replaceFirst('Exception: ', ''),
            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final f = vm.forecast;
    if (f == null) {
      return Center(
        child: Text(
          vm.forecastLoading
              ? 'Tahmin hesaplanıyor…'
              : 'Tahmin için seçim yap',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
    if (f.points.isEmpty && f.historical.isEmpty) {
      return const Center(
        child: Text(
          'Yeterli veri yok',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }

    final histSpots = <FlSpot>[];
    final fcSpots = <FlSpot>[];
    final lower = <FlSpot>[];
    final upper = <FlSpot>[];

    // Tek X ekseni: tüm noktaları sırala (historical + points).
    final histLen = f.historical.length;
    for (var i = 0; i < f.historical.length; i++) {
      histSpots.add(FlSpot(i.toDouble(), f.historical[i].value));
    }
    for (var i = 0; i < f.points.length; i++) {
      final x = (histLen + i).toDouble();
      fcSpots.add(FlSpot(x, f.points[i].value));
      lower.add(FlSpot(x, f.points[i].lower));
      upper.add(FlSpot(x, f.points[i].upper));
    }

    final (minVal, maxVal) = f.valueRange();
    var minY = minVal;
    var maxY = maxVal;
    if (maxY - minY < 1e-3) maxY = minY + 1;
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;

    final totalLen = histLen + f.points.length;
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (totalLen - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(0.001, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: ((maxY - minY) / 4).clamp(0.001, double.infinity),
              getTitlesWidget: (v, _) => Text(
                _fmtTick(v),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (totalLen / 5).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0) return const SizedBox.shrink();
                DateTime? d;
                if (idx < histLen) {
                  d = f.historical[idx].date;
                } else if (idx - histLen < f.points.length) {
                  d = f.points[idx - histLen].date;
                }
                if (d == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${d.month.toString().padLeft(2, '0')}.${d.year % 100}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1F2937),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((s) {
                return LineTooltipItem(
                  '${s.y.toStringAsFixed(2)}\n',
                  const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          // CI band — alt sınır + above fill
          if (lower.isNotEmpty)
            LineChartBarData(
              spots: upper,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 0,
              color: Colors.transparent,
              dotData: const FlDotData(show: false),
            ),
          if (lower.isNotEmpty)
            LineChartBarData(
              spots: lower,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 0,
              color: Colors.transparent,
              dotData: const FlDotData(show: false),
              aboveBarData: BarAreaData(
                show: true,
                color: Colors.cyanAccent.withValues(alpha: 0.10),
              ),
            ),
          // Historical (gri)
          if (histSpots.isNotEmpty)
            LineChartBarData(
              spots: histSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 1.8,
              color: Colors.white60,
              dotData: const FlDotData(show: false),
            ),
          // Forecast (cyan)
          if (fcSpots.isNotEmpty)
            LineChartBarData(
              spots: fcSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 2.2,
              color: Colors.cyanAccent,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  String _fmtTick(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v.abs() >= 10) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: const [
        _LegendItem(color: Colors.white60, label: 'Geçmiş'),
        _LegendItem(color: Colors.cyanAccent, label: 'Tahmin'),
        _LegendItem(
          color: Colors.cyanAccent,
          label: '95% güven aralığı',
          fill: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool fill;
  const _LegendItem({
    required this.color,
    required this.label,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: fill ? 10 : 2,
          decoration: BoxDecoration(
            color: fill ? color.withValues(alpha: 0.15) : color,
            borderRadius: BorderRadius.circular(2),
            border: fill
                ? Border.all(color: color.withValues(alpha: 0.4), width: 0.5)
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Annual KPI Grid ──────────────────────────────────────────────────────────

class _AnnualKpiGrid extends StatelessWidget {
  final ProjectionViewModel vm;
  const _AnnualKpiGrid({required this.vm});

  @override
  Widget build(BuildContext context) {
    final f = vm.forecast;
    if (f == null || f.points.isEmpty) return const SizedBox.shrink();
    final totals = f.annualTotals().entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (totals.isEmpty) return const SizedBox.shrink();

    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_view_month_rounded,
                  color: Colors.cyanAccent, size: 14),
              SizedBox(width: 6),
              Text(
                'Yıllık Toplam',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (ctx, c) {
              final cardWidth = (c.maxWidth - 8 * (totals.length - 1)) /
                  totals.length.clamp(1, 6);
              final useWrap = cardWidth < 70 || totals.length > 6;
              if (useWrap) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: totals
                      .map((e) => SizedBox(
                            width: (c.maxWidth - 16) / 3,
                            child: _YearKpiCard(year: e.key, total: e.value),
                          ))
                      .toList(),
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < totals.length; i++) ...[
                    Expanded(
                      child: _YearKpiCard(
                        year: totals[i].key,
                        total: totals[i].value,
                      ),
                    ),
                    if (i < totals.length - 1) const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _YearKpiCard extends StatelessWidget {
  final int year;
  final double total;
  const _YearKpiCard({required this.year, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Text(
            '$year',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _fmt(total),
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ── Metadata footer ──────────────────────────────────────────────────────────

class _MetadataCard extends StatelessWidget {
  final ProjectionViewModel vm;
  const _MetadataCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final f = vm.forecast;
    if (f == null) return const SizedBox.shrink();

    final orderStr = f.order.isEmpty ? '—' : '(${f.order.join(',')})';
    final seasStr =
        f.seasonalOrder.isEmpty ? '—' : '(${f.seasonalOrder.join(',')})';
    final mapeStr =
        f.mape == null ? '—' : '${(f.mape! * 100).toStringAsFixed(2)}%';
    final trendStr = f.annualTrendPct == null
        ? '—'
        : '${f.annualTrendPct!.toStringAsFixed(2)}%/yıl';

    return ReportCard(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Colors.white38, size: 13),
              const SizedBox(width: 6),
              Text(
                'Model parametreleri',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _MetaChip(label: 'Yöntem', value: f.method),
              _MetaChip(label: 'Order', value: orderStr),
              _MetaChip(label: 'Mevsim', value: seasStr),
              _MetaChip(label: 'MAPE', value: mapeStr),
              _MetaChip(label: 'Yıllık trend', value: trendStr),
              _MetaChip(label: 'Geçmiş', value: '${f.historyMonths} ay'),
              _MetaChip(label: 'Ufuk', value: '${f.horizonMonths} ay'),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.25),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.amberAccent, size: 13),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Bu projeksiyon mevsimsel ARIMA modeli ile geçmiş '
                    'veriden çıkarılan trendi yansıtır; yatırım kararı '
                    'için tek başına kullanılmamalıdır.',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 10),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white38),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProvinceProjectionView — İl Analizi tab'ında inline kullanım (P2.5).
// Kendi minimal state'iyle çalışır; il dışarıdan gelir, kullanıcı kaynak+metric
// +horizon seçer. Mod toggle/dropdown yoktur.
// ─────────────────────────────────────────────────────────────────────────────

class ProvinceProjectionView extends StatefulWidget {
  final String province;
  const ProvinceProjectionView({super.key, required this.province});

  @override
  State<ProvinceProjectionView> createState() => _ProvinceProjectionViewState();
}

class _ProvinceProjectionViewState extends State<ProvinceProjectionView> {
  String _resource = 'solar';
  String _metric = 'sunshine';
  int _years = 5;
  MlForecastResponse? _data;
  String? _error;
  bool _loading = false;

  static const _resourceMetrics = <String, List<MapEntry<String, String>>>{
    'solar': [
      MapEntry('sunshine', 'Güneşlenme (saat)'),
      MapEntry('cloud', 'Bulutluluk'),
    ],
    'wind': [
      MapEntry('cloud', 'Bulutluluk'),
      MapEntry('precipitation', 'Yağış'),
    ],
    'hydro': [
      MapEntry('discharge', 'Nehir debisi'),
      MapEntry('precipitation', 'Yağış'),
    ],
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant ProvinceProjectionView old) {
    super.didUpdateWidget(old);
    if (old.province != widget.province) {
      _data = null;
      _error = null;
      Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final resp = await api.ml.forecastProvince(
        province: widget.province,
        resource: _resource,
        metric: _metric,
        years: _years,
      );
      if (!mounted) return;
      setState(() {
        _data = resp;
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

  void _setResource(String r) {
    final metrics = _resourceMetrics[r] ?? const [];
    setState(() {
      _resource = r;
      if (metrics.isNotEmpty &&
          !metrics.any((m) => m.key == _metric)) {
        _metric = metrics.first.key;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _resourceMetrics[_resource] ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.province} · İklim Projeksiyonu',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'SARIMAX modeli ile aylık iklim trend tahmini · '
            'climatology kaynaklı 10 yıllık seri',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),

          // Kaynak chip'leri
          ReportCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _ResourceChip(
                      label: 'Solar',
                      color: ReportColors.solar,
                      active: _resource == 'solar',
                      onTap: () => _setResource('solar'),
                    ),
                    const SizedBox(width: 6),
                    _ResourceChip(
                      label: 'Wind',
                      color: ReportColors.wind,
                      active: _resource == 'wind',
                      onTap: () => _setResource('wind'),
                    ),
                    const SizedBox(width: 6),
                    _ResourceChip(
                      label: 'Hydro',
                      color: ReportColors.hydro,
                      active: _resource == 'hydro',
                      onTap: () => _setResource('hydro'),
                    ),
                    const Spacer(),
                    if (_loading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.cyanAccent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in metrics)
                      _MetricChip(
                        label: m.value,
                        active: _metric == m.key,
                        onTap: () {
                          setState(() => _metric = m.key);
                          _load();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.timeline_rounded,
                        color: Colors.cyanAccent, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'Ufuk',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '$_years yıl',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape:
                              const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: Colors.cyanAccent,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
                          thumbColor: Colors.cyanAccent,
                          overlayColor:
                              Colors.cyanAccent.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: _years.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          onChanged: (v) {
                            setState(() => _years = v.toInt());
                          },
                          onChangeEnd: (_) => _load(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Chart
          ReportCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Icon(Icons.show_chart_rounded,
                        color: Colors.cyanAccent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Geçmiş + Tahmin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _LegendRow(),
                const SizedBox(height: 12),
                SizedBox(height: 220, child: _buildChart()),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Annual KPI grid
          if (_data != null && _data!.points.isNotEmpty)
            _InlineAnnualGrid(data: _data!),

          const SizedBox(height: 12),

          if (_data != null)
            _InlineMeta(data: _data!),

          const SizedBox(height: 12),

          // P3: İklim senaryosu karşılaştırması (on-demand)
          ClimateScenarioCard(
            province: widget.province,
            resource: _resource,
            metric: _metric,
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final f = _data;
    if (f == null) {
      return Center(
        child: Text(
          _loading ? 'Tahmin hesaplanıyor…' : 'Tahmin için seçim yap',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
    if (f.points.isEmpty && f.historical.isEmpty) {
      return const Center(
        child: Text(
          'Yeterli veri yok',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }

    final histSpots = <FlSpot>[];
    final fcSpots = <FlSpot>[];
    final lower = <FlSpot>[];
    final upper = <FlSpot>[];
    final histLen = f.historical.length;
    for (var i = 0; i < f.historical.length; i++) {
      histSpots.add(FlSpot(i.toDouble(), f.historical[i].value));
    }
    for (var i = 0; i < f.points.length; i++) {
      final x = (histLen + i).toDouble();
      fcSpots.add(FlSpot(x, f.points[i].value));
      lower.add(FlSpot(x, f.points[i].lower));
      upper.add(FlSpot(x, f.points[i].upper));
    }

    final (minVal, maxVal) = f.valueRange();
    var minY = minVal;
    var maxY = maxVal;
    if (maxY - minY < 1e-3) maxY = minY + 1;
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;
    final totalLen = histLen + f.points.length;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (totalLen - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(0.001, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: ((maxY - minY) / 4).clamp(0.001, double.infinity),
              getTitlesWidget: (v, _) => Text(
                _fmtTick(v),
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (totalLen / 5).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0) return const SizedBox.shrink();
                DateTime? d;
                if (idx < histLen) {
                  d = f.historical[idx].date;
                } else if (idx - histLen < f.points.length) {
                  d = f.points[idx - histLen].date;
                }
                if (d == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${d.month.toString().padLeft(2, '0')}.${d.year % 100}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          if (lower.isNotEmpty)
            LineChartBarData(
              spots: upper,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 0,
              color: Colors.transparent,
              dotData: const FlDotData(show: false),
            ),
          if (lower.isNotEmpty)
            LineChartBarData(
              spots: lower,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 0,
              color: Colors.transparent,
              dotData: const FlDotData(show: false),
              aboveBarData: BarAreaData(
                show: true,
                color: Colors.cyanAccent.withValues(alpha: 0.10),
              ),
            ),
          if (histSpots.isNotEmpty)
            LineChartBarData(
              spots: histSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 1.8,
              color: Colors.white60,
              dotData: const FlDotData(show: false),
            ),
          if (fcSpots.isNotEmpty)
            LineChartBarData(
              spots: fcSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 2.2,
              color: Colors.cyanAccent,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  String _fmtTick(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v.abs() >= 10) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _InlineAnnualGrid extends StatelessWidget {
  final MlForecastResponse data;
  const _InlineAnnualGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final totals = data.annualTotals().entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (totals.isEmpty) return const SizedBox.shrink();
    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_view_month_rounded,
                  color: Colors.cyanAccent, size: 14),
              SizedBox(width: 6),
              Text(
                'Yıllık Toplam',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (ctx, c) {
            final cardWidth = (c.maxWidth - 8 * (totals.length - 1)) /
                totals.length.clamp(1, 6);
            final useWrap = cardWidth < 70 || totals.length > 6;
            if (useWrap) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: totals
                    .map((e) => SizedBox(
                          width: (c.maxWidth - 16) / 3,
                          child: _YearKpiCard(year: e.key, total: e.value),
                        ))
                    .toList(),
              );
            }
            return Row(
              children: [
                for (var i = 0; i < totals.length; i++) ...[
                  Expanded(
                    child: _YearKpiCard(
                      year: totals[i].key,
                      total: totals[i].value,
                    ),
                  ),
                  if (i < totals.length - 1) const SizedBox(width: 8),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final MlForecastResponse data;
  const _InlineMeta({required this.data});

  @override
  Widget build(BuildContext context) {
    final orderStr =
        data.order.isEmpty ? '—' : '(${data.order.join(',')})';
    final seasStr = data.seasonalOrder.isEmpty
        ? '—'
        : '(${data.seasonalOrder.join(',')})';
    final mapeStr = data.mape == null
        ? '—'
        : '${(data.mape! * 100).toStringAsFixed(2)}%';
    final trendStr = data.annualTrendPct == null
        ? '—'
        : '${data.annualTrendPct!.toStringAsFixed(2)}%/yıl';
    return ReportCard(
      padding: const EdgeInsets.all(11),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          _MetaChip(label: 'Yöntem', value: data.method),
          _MetaChip(label: 'Order', value: orderStr),
          _MetaChip(label: 'Mevsim', value: seasStr),
          _MetaChip(label: 'MAPE', value: mapeStr),
          _MetaChip(label: 'Yıllık trend', value: trendStr),
        ],
      ),
    );
  }
}

// ── ML Not Ready (statsmodels yok) ───────────────────────────────────────────

class _MlNotReadyView extends StatelessWidget {
  final MlHealth health;
  const _MlNotReadyView({required this.health});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ReportCard(
          padding: const EdgeInsets.all(18),
          accentBorder: Colors.orange,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: Colors.orange, size: 32),
              const SizedBox(height: 10),
              const Text(
                'ML servisi hazır değil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Backend\'de statsmodels/pmdarima yüklü değil. '
                'Sunucuya pip install statsmodels pmdarima ile kurulmalı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 12),
              for (final e in health.dependencies.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ClimateScenarioCard — P3: RCP4.5/8.5 iklim senaryosu karşılaştırması.
// On-demand: kullanıcı "Senaryoları Göster" deyince /ml/scenario'yu çağırır.
// 3 çizgi (baseline + RCP4.5 + RCP8.5) overlay + delta rozetleri.
// ─────────────────────────────────────────────────────────────────────────────

class ClimateScenarioCard extends StatefulWidget {
  final String province;
  final String resource;
  final String metric;

  const ClimateScenarioCard({
    super.key,
    required this.province,
    required this.resource,
    required this.metric,
  });

  @override
  State<ClimateScenarioCard> createState() => _ClimateScenarioCardState();
}

class _ClimateScenarioCardState extends State<ClimateScenarioCard> {
  bool _expanded = false;
  bool _loading = false;
  String? _error;
  MlScenarioResponse? _data;

  @override
  void didUpdateWidget(covariant ClimateScenarioCard old) {
    super.didUpdateWidget(old);
    // Seçim değişti + zaten açık → yeniden yükle
    if (_expanded &&
        (old.province != widget.province ||
            old.resource != widget.resource ||
            old.metric != widget.metric)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final resp = await api.ml.scenarioProvince(
        province: widget.province,
        resource: widget.resource,
        metric: widget.metric,
        years: 10,
      );
      if (!mounted) return;
      setState(() {
        _data = resp;
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

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded && _data == null && !_loading) {
      _load();
    }
  }

  static Color _hex(String h) {
    var s = h.replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    return Color(int.parse(s, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return ReportCard(
      accentBorder: const Color(0xFFEF4444),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            child: Row(
              children: [
                const Icon(Icons.thermostat_rounded,
                    color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'İklim Senaryoları (RCP 4.5 / 8.5)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFFEF4444),
                    ),
                  )
                else
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
              ],
            ),
          ),
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'IPCC emisyon senaryolarına göre uzun-vade trend. '
                'Göstermek için dokun.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
            ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              )
            else if (_data == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Senaryolar hesaplanıyor…',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              )
            else ...[
              SizedBox(height: 200, child: _buildChart(_data!)),
              const SizedBox(height: 12),
              ..._data!.scenarios.map(_scenarioLegendRow),
            ],
          ],
        ],
      ),
    );
  }

  Widget _scenarioLegendRow(MlScenarioSeries s) {
    final color = _hex(s.color);
    final deltaStr = s.scenario == 'baseline'
        ? 'referans'
        : '${s.endDeltaPct > 0 ? '+' : ''}${s.endDeltaPct.toStringAsFixed(1)}% (ufuk sonu)';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      s.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        deltaStr,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  s.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(MlScenarioResponse data) {
    if (data.scenarios.isEmpty) {
      return const Center(
        child: Text('Veri yok',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
      );
    }
    final (minVal, maxVal) = data.valueRange();
    var minY = minVal;
    var maxY = maxVal;
    if (maxY - minY < 1e-3) maxY = minY + 1;
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;

    final ref = data.scenarios.first.points;
    final totalLen = ref.length;
    if (totalLen == 0) {
      return const Center(
        child: Text('Veri yok',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
      );
    }

    final bars = <LineChartBarData>[];
    for (final s in data.scenarios) {
      final color = _hex(s.color);
      final spots = <FlSpot>[];
      for (var i = 0; i < s.points.length; i++) {
        spots.add(FlSpot(i.toDouble(), s.points[i].value));
      }
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.2,
        barWidth: s.scenario == 'baseline' ? 2.4 : 1.8,
        color: color,
        dashArray: s.scenario == 'baseline' ? null : [5, 3],
        dotData: const FlDotData(show: false),
      ));
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (totalLen - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(0.001, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: ((maxY - minY) / 4).clamp(0.001, double.infinity),
              getTitlesWidget: (v, _) => Text(
                _fmtTick(v),
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (totalLen / 5).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= ref.length) {
                  return const SizedBox.shrink();
                }
                final d = ref[idx].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${d.year}',
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: bars,
      ),
    );
  }

  String _fmtTick(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v.abs() >= 10) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PinFinancialCard — M-C: Pin finansal projeksiyon (gelir/gider/net/payback/CO₂).
// On-demand: /ml/project/pin/{id}/financial. Kümülatif net line chart + yıllık tablo.
// ─────────────────────────────────────────────────────────────────────────────

class PinFinancialCard extends StatefulWidget {
  final int pinId;
  const PinFinancialCard({super.key, required this.pinId});

  @override
  State<PinFinancialCard> createState() => _PinFinancialCardState();
}

class _PinFinancialCardState extends State<PinFinancialCard> {
  bool _expanded = false;
  bool _loading = false;
  String? _error;
  MlPinFinancial? _data;
  bool _showTry = false; // USD ↔ TL toggle

  @override
  void didUpdateWidget(covariant PinFinancialCard old) {
    super.didUpdateWidget(old);
    if (_expanded && old.pinId != widget.pinId) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final resp = await api.ml.pinFinancial(pinId: widget.pinId, years: 10);
      if (!mounted) return;
      setState(() {
        _data = resp;
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

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded && _data == null && !_loading) _load();
  }

  static const _green = Color(0xFF10B981);

  String _money(double usd, double rate) {
    final v = _showTry ? usd * rate : usd;
    final suffix = _showTry ? '₺' : '\$';
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M$suffix';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}k$suffix';
    return '${v.toStringAsFixed(0)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return ReportCard(
      accentBorder: _green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            child: Row(
              children: [
                const Icon(Icons.savings_rounded, color: _green, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Finansal Projeksiyon (10 yıl)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _green,
                    ),
                  )
                else
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
              ],
            ),
          ),
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Üretim tahmini × tarife → gelir, gider, geri ödeme. Göstermek için dokun.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
            ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              )
            else if (_data == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Hesaplanıyor…',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              )
            else
              _buildContent(_data!),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(MlPinFinancial d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              d.pinType,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const Spacer(),
            _CurrencyToggle(
              showTry: _showTry,
              onChanged: (v) => setState(() => _showTry = v),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _kpi('Yatırım (CAPEX)', _money(d.capexUsd, d.usdToTry), Colors.white70)),
            const SizedBox(width: 8),
            Expanded(child: _kpi('Geri ödeme', d.paybackYear?.toString() ?? '—', d.paybackYear != null ? _green : ReportColors.bad)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _kpi('Toplam gelir', _money(d.totalRevenueUsd, d.usdToTry), ReportColors.solar)),
            const SizedBox(width: 8),
            Expanded(child: _kpi('Net (10y)', _money(d.totalNetUsd, d.usdToTry), d.totalNetUsd >= 0 ? _green : ReportColors.bad)),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Kümülatif Net Nakit Akışı',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(height: 140, child: _cumulativeChart(d)),
        const SizedBox(height: 12),
        _yearlyTable(d),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.amberAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.25)),
          ),
          child: Text(
            d.disclaimer,
            style: const TextStyle(color: Colors.amberAccent, fontSize: 9.5, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _cumulativeChart(MlPinFinancial d) {
    if (d.yearly.isEmpty) {
      return const Center(child: Text('Veri yok', style: TextStyle(color: Colors.white38, fontSize: 11)));
    }
    final rate = _showTry ? d.usdToTry : 1.0;
    final spots = <FlSpot>[];
    for (var i = 0; i < d.yearly.length; i++) {
      spots.add(FlSpot(i.toDouble(), d.yearly[i].cumulativeNetUsd * rate));
    }
    var minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    var maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY - minY < 1e-3) maxY = minY + 1;
    final pad = (maxY - minY) * 0.1;
    minY -= pad;
    maxY += pad;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (d.yearly.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(0.001, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: ((maxY - minY) / 4).clamp(0.001, double.infinity),
              getTitlesWidget: (v, _) => Text(
                _moneyTick(v),
                style: const TextStyle(color: Colors.white38, fontSize: 8),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              interval: (d.yearly.length / 5).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= d.yearly.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${d.yearly[idx].year}',
                      style: const TextStyle(color: Colors.white38, fontSize: 8)),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: 0,
            color: Colors.white.withValues(alpha: 0.25),
            strokeWidth: 1,
            dashArray: [4, 3],
          ),
        ]),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            barWidth: 2.2,
            color: _green,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: _green.withValues(alpha: 0.10)),
          ),
        ],
      ),
    );
  }

  String _moneyTick(double v) {
    final a = v.abs();
    final sign = v < 0 ? '-' : '';
    if (a >= 1e6) return '$sign${(a / 1e6).toStringAsFixed(1)}M';
    if (a >= 1e3) return '$sign${(a / 1e3).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  Widget _yearlyTable(MlPinFinancial d) {
    final rate = _showTry ? d.usdToTry : 1.0;
    final cur = _showTry ? '₺' : '\$';
    return Column(
      children: [
        Row(
          children: const [
            Expanded(flex: 2, child: Text('Yıl', style: TextStyle(color: Colors.white38, fontSize: 9.5))),
            Expanded(flex: 3, child: Text('Üretim', style: TextStyle(color: Colors.white38, fontSize: 9.5))),
            Expanded(flex: 3, child: Text('Gelir', style: TextStyle(color: Colors.white38, fontSize: 9.5))),
            Expanded(flex: 3, child: Text('Net', style: TextStyle(color: Colors.white38, fontSize: 9.5))),
          ],
        ),
        const SizedBox(height: 4),
        ...d.yearly.take(6).map((y) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('${y.year}', style: const TextStyle(color: Colors.white70, fontSize: 10))),
                  Expanded(flex: 3, child: Text('${(y.kwh / 1e6).toStringAsFixed(2)}M kWh', style: const TextStyle(color: Colors.white60, fontSize: 10))),
                  Expanded(flex: 3, child: Text('${((y.revenueUsd * rate) / 1e3).toStringAsFixed(0)}k$cur', style: const TextStyle(color: ReportColors.solar, fontSize: 10))),
                  Expanded(flex: 3, child: Text('${((y.netUsd * rate) / 1e3).toStringAsFixed(0)}k$cur', style: TextStyle(color: y.netUsd >= 0 ? _green : ReportColors.bad, fontSize: 10))),
                ],
              ),
            )),
        if (d.yearly.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('… +${d.yearly.length - 6} yıl daha',
                style: const TextStyle(color: Colors.white38, fontSize: 9)),
          ),
      ],
    );
  }
}

class _CurrencyToggle extends StatelessWidget {
  final bool showTry;
  final ValueChanged<bool> onChanged;
  const _CurrencyToggle({required this.showTry, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('USD', !showTry, () => onChanged(false)),
          _seg('TL', showTry, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _seg(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF10B981).withValues(alpha: 0.7) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : Colors.white54,
          fontSize: 9.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    );
  }
}

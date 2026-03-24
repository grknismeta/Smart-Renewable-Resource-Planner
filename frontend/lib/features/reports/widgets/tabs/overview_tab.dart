// lib/features/reports/widgets/tabs/overview_tab.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';

// ── Statik Türkiye YEK kurulu güç verisi (EPDK / TEİAŞ) ──────────────────────
// Kaynak: EPDK Strateji Belgesi, TEİAŞ APK 2025 — GW (installed capacity)
const List<int> _kYears = [
  2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025
];
const List<double> _kHesGW = [
  25.9, 27.0, 28.0, 28.5, 30.5, 31.5, 32.0, 32.0, 32.5, 32.0, 33.0
];
const List<double> _kWindGW = [
  3.7, 6.0, 7.0, 7.8, 8.0, 9.5, 10.2, 10.8, 11.5, 12.0, 13.0
];
const List<double> _kSolGW = [
  0.2, 0.8, 3.5, 5.1, 6.0, 6.7, 7.8, 9.0, 10.5, 11.0, 12.0
];
const List<double> _kTotGW = [
  75.2, 79.2, 84.5, 88.8, 91.3, 96.3, 100.4, 104.3, 108.1, 110.5, 115.0
];

// Stacked cumulative values computed at build time
List<double> get _kWindHesGW =>
    List.generate(_kYears.length, (i) => _kHesGW[i] + _kWindGW[i]);
List<double> get _kResGW =>
    List.generate(_kYears.length, (i) => _kHesGW[i] + _kWindGW[i] + _kSolGW[i]);

// ── Renk paleti ───────────────────────────────────────────────────────────────
const _cHes  = Color(0xFF4FC3F7);
const _cWind = Color(0xFF66BB6A);
const _cSol  = Color(0xFFFFCA28);
const _cTot  = Color(0xFF78909C);
const _cRes  = Color(0xFF26C6DA);

// ── 2024 Türkiye elektrik üretimi enerji karması ──────────────────────────────
// Kaynak: TEİAŞ 2024 yıllık üretim raporu (GWh bazında oranlar), ~330 TWh toplam
const _kDonut = <(String, double, Color)>[
  ('HES',       20.4, _cHes),
  ('Rüzgar',    12.1, _cWind),
  ('Güneş',      6.7, _cSol),
  ('Doğal Gaz', 28.5, Color(0xFFFF8A65)),
  ('Kömür',     22.1, Color(0xFF90A4AE)),
  ('Diğer',     10.2, Color(0xFFCE93D8)),
];

// Donut için 2024 TWh değerleri (toplam ~330 TWh)
const _kDonutTWh2024 = <double>[67.3, 39.9, 22.1, 94.1, 72.9, 33.7];
// Donut için 2023 TWh değerleri (karşılaştırma, ~325 TWh)
const _kDonutTWh2023 = <double>[72.4, 37.6, 18.5, 84.6, 75.0, 37.0];

// ─────────────────────────────────────────────────────────────────────────────
// Ana widget (StatefulWidget — info panel + hybrid sliders için)
// ─────────────────────────────────────────────────────────────────────────────

/// Tab 1 — Genel Bakış
class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  int? _infoIdx;          // açık bilgi paneli indeksi (null = kapalı)
  double _hybSolar = 40;  // Karma profil: güneş %
  double _hybWind  = 35;  // Karma profil: rüzgar %
  double get _hybHes => (100 - _hybSolar - _hybWind).clamp(0.0, 100.0);

  // Tahmini yıllık YEK üretimi (TWh)
  double get _calcAnnualTWh {
    const totalCapGW = 58.0; // ~2025 TR toplam YEK kurulu güç (GW)
    const sCF = 0.18; // güneş kapasite faktörü
    const wCF = 0.28; // rüzgar kapasite faktörü
    const hCF = 0.35; // HES kapasite faktörü
    return (_hybSolar / 100 * totalCapGW * sCF +
            _hybWind  / 100 * totalCapGW * wCF +
            _hybHes   / 100 * totalCapGW * hCF) *
        8.76; // 8760 saat / 1000 = 8.76
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    context.watch<ThemeViewModel>();
    final top5 = (vm.report?.items ?? []).take(5).toList();

    // Yükleniyor
    if (vm.isBusy && vm.report == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
      );
    }

    // Hata durumu
    if (vm.hasError && vm.report == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 36),
            const SizedBox(height: 10),
            Text(
              vm.errorMessage ?? 'Rapor yüklenemedi',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => vm.fetchReport(),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Yeniden Dene'),
              style: TextButton.styleFrom(foregroundColor: Colors.cyanAccent),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Enerji modu chip'leri ──────────────────────────────────────
          _EnergyChips(vm: vm),
          const SizedBox(height: 14),

          // ── 2. YEK hero stat kartları ─────────────────────────────────────
          const _HeroRow(),
          const SizedBox(height: 14),

          // ── 3. Büyüme grafiği + Donut + Top 5 (responsive) ────────────────
          LayoutBuilder(builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 640;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 50,
                    child: _GrowthChart(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _DonutChart(),
                        const SizedBox(height: 12),
                        _TopLocations(
                          top5: top5,
                          provinceSummaries: vm.provinceSummaries,
                          infoIdx: _infoIdx,
                          onTap: (i) => setState(
                              () => _infoIdx = (_infoIdx == i) ? null : i),
                          onClose: () => setState(() => _infoIdx = null),
                          onGoToTab2: (provinceIdx) {
                            vm.setSelectedProvinceIndex(provinceIdx);
                            DefaultTabController.of(context).animateTo(1);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            // Dar ekran
            return Column(
              children: [
                const _DonutChart(),
                const SizedBox(height: 12),
                _GrowthChart(),
                const SizedBox(height: 12),
                _TopLocations(
                  top5: top5,
                  provinceSummaries: vm.provinceSummaries,
                  infoIdx: _infoIdx,
                  onTap: (i) =>
                      setState(() => _infoIdx = (_infoIdx == i) ? null : i),
                  onClose: () => setState(() => _infoIdx = null),
                  onGoToTab2: (provinceIdx) {
                    vm.setSelectedProvinceIndex(provinceIdx);
                    DefaultTabController.of(context).animateTo(1);
                  },
                ),
              ],
            );
          }),
          const SizedBox(height: 14),

          // ── 4. Mini harita + Karma profil (responsive) ────────────────────
          LayoutBuilder(builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 640;
            final hybrid = _HybridProfile(
              hybSolar: _hybSolar,
              hybWind: _hybWind,
              hybHes: _hybHes,
              annualTWh: _calcAnnualTWh,
              onSolarChanged: (v) => setState(() {
                _hybSolar = v;
                if (_hybSolar + _hybWind > 100) {
                  _hybWind = (100 - _hybSolar).clamp(0, 100);
                }
              }),
              onWindChanged: (v) => setState(() {
                _hybWind = v;
                if (_hybSolar + _hybWind > 100) {
                  _hybSolar = (100 - _hybWind).clamp(0, 100);
                }
              }),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 50, child: _MiniMap(items: top5)),
                  const SizedBox(width: 12),
                  Expanded(flex: 50, child: hybrid),
                ],
              );
            }
            return Column(children: [
              _MiniMap(items: top5),
              const SizedBox(height: 12),
              hybrid,
            ]);
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enerji modu chip'leri
// ─────────────────────────────────────────────────────────────────────────────

class _EnergyChips extends StatelessWidget {
  final ReportViewModel vm;
  const _EnergyChips({required this.vm});

  static const _modes = <(String, String, Color)>[
    ('hepsi',  'Tümü',   Color(0xFF378ADD)),
    ('gunes',  'Güneş',  _cSol),
    ('ruzgar', 'Rüzgar', _cWind),
    ('hes',    'HES',    _cHes),
    ('hibrit', 'Hibrit', Color(0xFFAB47BC)),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _modes.map((m) {
        final (key, label, color) = m;
        final active = vm.energyMode == key;
        return GestureDetector(
          onTap: () => vm.setEnergyMode(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? color.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12),
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: active ? color : Colors.white54,
                    fontSize: 12,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero stat kartları (Türkiye YEK kurulu güç — 2024 EPDK)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroRow extends StatelessWidget {
  const _HeroRow();

  static const _cards = <(String, String, String, Color, IconData)>[
    ('Güneş',  '11',  'GW kurulu', _cSol,  Icons.wb_sunny_rounded),
    ('Rüzgar', '12',  'GW kurulu', _cWind, Icons.air_rounded),
    ('HES',    '32',  'GW kurulu', _cHes,  Icons.water_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _cards.asMap().entries.map((entry) {
        final (label, value, unit, color, icon) = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: entry.key > 0 ? 8 : 0),
            child: _HeroCard(
              label: label,
              value: value,
              unit: unit,
              color: color,
              icon: icon,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  const _HeroCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: color.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Büyüme grafiği — Yıllık kurulu güç (GW) stacked area + line
// ─────────────────────────────────────────────────────────────────────────────

class _GrowthChart extends StatelessWidget {
  const _GrowthChart();

  LineChartBarData _areaLine({
    required List<double> ys,
    required Color lineColor,
    required Color fillColor,
    double barWidth = 0,
    List<int>? dashArray,
  }) {
    return LineChartBarData(
      spots: List.generate(ys.length, (i) => FlSpot(i.toDouble(), ys[i])),
      isCurved: true,
      curveSmoothness: 0.3,
      color: lineColor,
      barWidth: barWidth,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: dashArray,
      belowBarData: BarAreaData(
        show: true,
        color: fillColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resGW     = _kResGW;
    final windHesGW = _kWindHesGW;

    return _Panel(
      title: 'Türkiye YEK Kurulu Güç Büyümesi',
      subtitle: '2015–2025  •  GW',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            child: LineChart(
              duration: Duration.zero,
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                clipData: const FlClipData.all(),
                minY: 0,
                maxY: 125,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 25,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 2,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= _kYears.length) {
                          return const SizedBox.shrink();
                        }
                        if (idx % 2 != 0) return const SizedBox.shrink();
                        final res = _kHesGW[idx] + _kWindGW[idx] + _kSolGW[idx];
                        final pct = (res / _kTotGW[idx] * 100).toStringAsFixed(0);
                        return Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_kYears[idx]}',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 9),
                              ),
                              Text(
                                '$pct%',
                                style: const TextStyle(
                                    color: _cRes, fontSize: 8),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1C2533),
                    getTooltipItems: (spots) {
                      return spots.map((s) {
                        final idx = s.x.toInt();
                        if (idx < 0 || idx >= _kYears.length) return null;
                        final res = _kHesGW[idx] + _kWindGW[idx] + _kSolGW[idx];
                        final pct = (res / _kTotGW[idx] * 100).toStringAsFixed(0);
                        String? label;
                        Color? color;
                        switch (s.barIndex) {
                          case 0:
                            label = 'Toplam: ${_kTotGW[idx].toStringAsFixed(0)} GW';
                            color = _cTot;
                          case 4:
                            label = 'YEK: ${res.toStringAsFixed(1)} GW ($pct%)';
                            color = _cRes;
                          default:
                            return null;
                        }
                        return LineTooltipItem(
                          label,
                          TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                // Çizim sırası:
                // 0 = Toplam (gri kesik çizgi, dolgu yok)
                // 1 = Güneş/RES fill (sarı, en geniş alan)
                // 2 = Rüzgar+HES fill (yeşil, sarı üzerine çizilir)
                // 3 = HES fill (mavi, yeşil üzerine çizilir)
                // 4 = YEK toplam çizgisi (cyan, en üstte)
                lineBarsData: [
                  _areaLine(
                    ys: _kTotGW,
                    lineColor: _cTot.withValues(alpha: 0.50),
                    fillColor: Colors.transparent,
                    barWidth: 1.5,
                    dashArray: [5, 4],
                  ),
                  _areaLine(
                    ys: resGW,
                    lineColor: Colors.transparent,
                    fillColor: _cSol.withValues(alpha: 0.60),
                  ),
                  _areaLine(
                    ys: windHesGW,
                    lineColor: Colors.transparent,
                    fillColor: _cWind.withValues(alpha: 0.65),
                  ),
                  _areaLine(
                    ys: _kHesGW,
                    lineColor: Colors.transparent,
                    fillColor: _cHes.withValues(alpha: 0.70),
                  ),
                  LineChartBarData(
                    spots: List.generate(
                        resGW.length, (i) => FlSpot(i.toDouble(), resGW[i])),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: _cRes,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, i) => FlDotCirclePainter(
                        radius: 2.5,
                        color: _cRes,
                        strokeWidth: 1,
                        strokeColor: Colors.black,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Legend ──────────────────────────────────────────────────────────
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: const [
              _LegendItem(color: _cHes,  label: 'HES'),
              _LegendItem(color: _cWind, label: 'Rüzgar'),
              _LegendItem(color: _cSol,  label: 'Güneş'),
              _LegendItem(color: _cRes,  label: 'Toplam YEK', isLine: true),
              _LegendItem(color: _cTot,  label: 'TR Toplam',  isLine: true, dashed: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isLine;
  final bool dashed;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isLine = false,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          SizedBox(
            width: 16,
            height: 2,
            child: CustomPaint(
              painter: _DashedLinePainter(
                  color: color.withValues(alpha: dashed ? 0.6 : 0.9),
                  dashed: dashed),
            ),
          )
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 9),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _DashedLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    if (!dashed) {
      canvas.drawLine(
          Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    } else {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
            Offset(x, size.height / 2),
            Offset((x + 4).clamp(0, size.width), size.height / 2),
            paint);
        x += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Donut grafiği — 2024 Türkiye enerji karması
// ─────────────────────────────────────────────────────────────────────────────

class _DonutChart extends StatefulWidget {
  const _DonutChart();

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart> {
  int _touchedIdx = -1;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Türkiye Enerji Karması',
      subtitle: '2024  •  üretim bazında',
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: Row(
              children: [
                // Donut
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        duration: Duration.zero,
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIdx = -1;
                                  return;
                                }
                                _touchedIdx = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sections: _kDonut.asMap().entries.map((entry) {
                            final i = entry.key;
                            final (label, pct, color) = entry.value;
                            final isTouched = i == _touchedIdx;
                            return PieChartSectionData(
                              value: pct,
                              color: isTouched
                                  ? color
                                  : color.withValues(alpha: 0.85),
                              radius: isTouched ? 54 : 44,
                              title: pct >= 10
                                  ? '${pct.toStringAsFixed(0)}%'
                                  : '',
                              titleStyle: TextStyle(
                                color: Colors.black87,
                                fontSize: isTouched ? 10 : 9,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Merkez — dokunulan bölge bilgisi
                      if (_touchedIdx >= 0 && _touchedIdx < _kDonut.length)
                        _DonutCenter(idx: _touchedIdx)
                      else
                        const _DonutCenter(idx: -1),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Legend
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _kDonut.asMap().entries.map((entry) {
                      final i = entry.key;
                      final (label, pct, color) = entry.value;
                      final isTouched = i == _touchedIdx;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _touchedIdx = isTouched ? -1 : i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 3),
                          decoration: BoxDecoration(
                            color: isTouched
                                ? color.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isTouched
                                        ? Colors.white
                                        : Colors.white60,
                                    fontSize: 10,
                                    fontWeight: isTouched
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: isTouched ? color : Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Dokunulan bölme detay satırı
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _touchedIdx >= 0
                ? _DonutDetailRow(idx: _touchedIdx)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DonutCenter extends StatelessWidget {
  final int idx;
  const _DonutCenter({required this.idx});

  @override
  Widget build(BuildContext context) {
    if (idx < 0) {
      return const Text(
        '2024',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      );
    }
    final (label, pct, color) = _kDonut[idx];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${pct.toStringAsFixed(0)}%',
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 9),
        ),
      ],
    );
  }
}

class _DonutDetailRow extends StatelessWidget {
  final int idx;
  const _DonutDetailRow({required this.idx});

  @override
  Widget build(BuildContext context) {
    final (label, pct, color) = _kDonut[idx];
    final twh2024 = _kDonutTWh2024[idx];
    final twh2023 = _kDonutTWh2023[idx];
    final diff = twh2024 - twh2023;
    final diffStr = diff >= 0 ? '+${diff.toStringAsFixed(1)}' : diff.toStringAsFixed(1);
    final diffColor = diff >= 0 ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '2024: ${twh2024.toStringAsFixed(1)} TWh',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(width: 10),
          Text(
            '$diffStr TWh',
            style: TextStyle(
                color: diffColor, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Text(
            'vs 2023',
            style: const TextStyle(color: Colors.white30, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top 5 lokasyonlar
// ─────────────────────────────────────────────────────────────────────────────

class _TopLocations extends StatelessWidget {
  final List<RegionalSite> top5;
  final List<ProvinceSummary> provinceSummaries;
  final int? infoIdx;
  final void Function(int) onTap;
  final VoidCallback onClose;
  final void Function(int) onGoToTab2;

  const _TopLocations({
    required this.top5,
    required this.provinceSummaries,
    required this.infoIdx,
    required this.onTap,
    required this.onClose,
    required this.onGoToTab2,
  });

  ProvinceSummary? _matchProvince(String city) {
    final lower = city.toLowerCase();
    for (final p in provinceSummaries) {
      if (p.provinceName.toLowerCase().contains(lower) ||
          lower.contains(p.provinceName.toLowerCase())) {
        return p;
      }
    }
    return null;
  }

  // Province summary list index for the city (for Tab 2 navigation)
  int _provinceIdx(String city) {
    final lower = city.toLowerCase();
    for (var i = 0; i < provinceSummaries.length; i++) {
      final p = provinceSummaries[i];
      if (p.provinceName.toLowerCase().contains(lower) ||
          lower.contains(p.provinceName.toLowerCase())) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'En İyi Lokasyonlar',
      subtitle: 'skor bazında top 5',
      child: top5.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Veri yükleniyor…',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            )
          : Column(
              children: [
                // Liste
                ...top5.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final site = entry.value;
                  final prov = _matchProvince(site.city);
                  final isSelected = infoIdx == idx;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () => onTap(idx),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.cyanAccent.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              // Sıra numarası
                              SizedBox(
                                width: 20,
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    color: idx == 0
                                        ? Colors.amber
                                        : Colors.white38,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              // Şehir adı
                              Expanded(
                                child: Text(
                                  site.city,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Hava durumu chip'leri
                              if (prov != null) ...[
                                _WeatherChip(
                                  icon: '🌡️',
                                  value: prov.avgTemperature != null
                                      ? '${prov.avgTemperature!.toStringAsFixed(0)}°C'
                                      : '—',
                                ),
                                const SizedBox(width: 4),
                                _WeatherChip(
                                  icon: '💨',
                                  value: prov.avgWindSpeed != null
                                      ? '${prov.avgWindSpeed!.toStringAsFixed(1)}m/s'
                                      : '—',
                                ),
                                const SizedBox(width: 4),
                                _WeatherChip(
                                  icon: '☀️',
                                  value: prov.avgRadiation != null
                                      ? '${prov.avgRadiation!.toStringAsFixed(0)}W'
                                      : '—',
                                ),
                                const SizedBox(width: 6),
                              ],
                              // Skor
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  site.overallScore.toStringAsFixed(0),
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bilgi paneli (seçiliyse)
                      if (isSelected)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: _LocationInfoPanel(
                            site: site,
                            province: prov,
                            onClose: onClose,
                            onGoToTab2: () =>
                                onGoToTab2(_provinceIdx(site.city)),
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  final String icon;
  final String value;

  const _WeatherChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$icon $value',
        style: const TextStyle(fontSize: 9, color: Colors.white60),
      ),
    );
  }
}

class _LocationInfoPanel extends StatelessWidget {
  final RegionalSite site;
  final ProvinceSummary? province;
  final VoidCallback onClose;
  final VoidCallback onGoToTab2;

  const _LocationInfoPanel({
    required this.site,
    required this.province,
    required this.onClose,
    required this.onGoToTab2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 13, color: Colors.cyanAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  site.city,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white38),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Skor + koordinat
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _InfoChip(
                  label: 'Skor',
                  value: site.overallScore.toStringAsFixed(1),
                  color: Colors.cyanAccent),
              _InfoChip(
                  label: 'Tür',
                  value: site.type,
                  color: Colors.white54),
              if (site.avgWindSpeedMs != null)
                _InfoChip(
                    label: 'Rüzgar',
                    value:
                        '${site.avgWindSpeedMs!.toStringAsFixed(1)} m/s',
                    color: _cWind),
              if (site.annualSolarIrradianceKwhM2 != null)
                _InfoChip(
                    label: 'Güneş',
                    value:
                        '${site.annualSolarIrradianceKwhM2!.toStringAsFixed(0)} kWh/m²',
                    color: _cSol),
              if (province?.avgTemperature != null)
                _InfoChip(
                    label: 'Sıcaklık',
                    value:
                        '${province!.avgTemperature!.toStringAsFixed(1)}°C',
                    color: Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 10),
          // Navigasyon butonu
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onGoToTab2,
              icon: const Icon(Icons.analytics_outlined,
                  size: 14, color: Colors.cyanAccent),
              label: const Text(
                'İl Analizine Git',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor:
                    Colors.cyanAccent.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                  color: color.withValues(alpha: 0.6), fontSize: 10),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 10,
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
// Top 5 lokasyon listesi
// ─────────────────────────────────────────────────────────────────────────────

class _MiniMap extends StatelessWidget {
  final List<RegionalSite> items;
  const _MiniMap({required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = [_cRes, _cSol, _cWind, _cHes, Colors.purpleAccent];
    return _Panel(
      title: 'Top 5 Lokasyon',
      subtitle: '${items.length} alan',
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final site = entry.value;
          final color = colors[i % colors.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.9)),
                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(site.city, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
              Text(site.overallScore.toStringAsFixed(1), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Karma (Hibrit) Profil — Slider bazlı YEK mix
// ─────────────────────────────────────────────────────────────────────────────

class _HybridProfile extends StatelessWidget {
  final double hybSolar;
  final double hybWind;
  final double hybHes;
  final double annualTWh;
  final ValueChanged<double> onSolarChanged;
  final ValueChanged<double> onWindChanged;

  const _HybridProfile({
    required this.hybSolar,
    required this.hybWind,
    required this.hybHes,
    required this.annualTWh,
    required this.onSolarChanged,
    required this.onWindChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Karma Enerji Profili',
      subtitle: 'YEK karma simülasyonu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Açıklama
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 12, color: Colors.amber),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Türkiye\'nin toplam YEK kurulu gücünü (~58 GW) '
                    'bu karışım oranlarıyla değerlendirdiğinizdeki tahmini '
                    'yıllık üretimi hesaplar. Sliderlar toplamlı olarak çalışır '
                    '(Güneş + Rüzgar + HES = %100).',
                    style: TextStyle(color: Colors.amber, fontSize: 9.5),
                  ),
                ),
              ],
            ),
          ),
          // Sliders
          _HybSlider(
            label: 'Güneş',
            icon: Icons.wb_sunny_rounded,
            color: _cSol,
            value: hybSolar,
            onChanged: onSolarChanged,
          ),
          _HybSlider(
            label: 'Rüzgar',
            icon: Icons.air_rounded,
            color: _cWind,
            value: hybWind,
            onChanged: onWindChanged,
          ),
          // HES otomatik (read-only)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.water_rounded, size: 13, color: _cHes),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'HES',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                  ),
                ),
                Text(
                  '${hybHes.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: _cHes,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 10),
          // Tahmini üretim çıktısı
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tahmini Yıllık YEK Üretimi',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                    Text(
                      '${annualTWh.toStringAsFixed(1)} TWh / yıl',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '* Ortalama kapasite faktörleri kullanılmıştır (Güneş %18, Rüzgar %28, HES %35). '
            'ML tabanlı bölgesel projeksiyon Sprint 7\'de eklenecektir.',
            style: const TextStyle(
                color: Colors.white30, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _HybSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;

  const _HybSlider({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.2),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${value.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ortak panel kapsayıcı
// ─────────────────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Panel({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                      color: Colors.white30, fontSize: 10),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

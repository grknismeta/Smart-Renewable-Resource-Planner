// lib/features/reports/pages/scenario_compare_page.dart
//
// 2026-05-25 (G7): Gerçek senaryo karşılaştırma sayfası — eski "ekranı 2'ye
// böl" (CompareView) davranışını değiştirdi. Bu sayfa **gerçek diff** verir:
//   - KPI delta tablosu (Senaryo A vs B): toplam kWh, kaynak kırılımı, NPV,
//     IRR, LCOE, payback farkı.
//   - Aylık üretim delta bar chart (A - B her ay).
//   - Pin overlap analizi (ortak pin sayısı, A-only, B-only).
//
// Kullanım: Senaryo tab'taki "Kıyasla" butonu Navigator.push ile bu sayfaya
// gider; geri tuşu otomatik. ScenarioReportViewModel parent context'ten
// alınır (Provider).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/models/financial_metrics.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/reports/viewmodels/scenario_report_viewmodel.dart';
import 'package:frontend/features/reports/widgets/common/report_ui.dart';
import 'package:frontend/shared/widgets/app_background.dart';

class ScenarioComparePage extends StatelessWidget {
  /// Sayfa açılınca ön-seçili senaryoları belirlemek için (caller verir).
  final int? initialIdA;
  final int? initialIdB;

  const ScenarioComparePage({
    super.key,
    this.initialIdA,
    this.initialIdB,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: _CompareBody(initialIdA: initialIdA, initialIdB: initialIdB),
        ),
      ),
    );
  }
}

class _CompareBody extends StatefulWidget {
  final int? initialIdA;
  final int? initialIdB;
  const _CompareBody({this.initialIdA, this.initialIdB});

  @override
  State<_CompareBody> createState() => _CompareBodyState();
}

class _CompareBodyState extends State<_CompareBody> {
  int? _idA;
  int? _idB;

  @override
  void initState() {
    super.initState();
    _idA = widget.initialIdA;
    _idB = widget.initialIdB;
  }

  Scenario? _resolve(ScenarioReportViewModel vm, int? id) {
    if (id == null) return null;
    if (vm.scenarioA?.id == id) return vm.scenarioA;
    if (vm.scenarioB?.id == id) return vm.scenarioB;
    return vm.scenarios.cast<Scenario?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScenarioReportViewModel>();
    // İkinci senaryo otomatik seç (idA ile aynı değilse)
    if (_idB == null && vm.scenarios.length >= 2) {
      _idB = vm.scenarios.firstWhere((s) => s.id != _idA).id;
      // Financials yüklemesini tetikle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_idB != null) vm.selectB(_idB!);
      });
    }

    final a = _resolve(vm, _idA);
    final b = _resolve(vm, _idB);
    final finA = _idA != null ? vm.financialsFor(_idA!) : null;
    final finB = _idB != null ? vm.financialsFor(_idB!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(),
        const Divider(color: Colors.white12, height: 1),
        _PickerBar(
          scenarios: vm.scenarios,
          idA: _idA,
          idB: _idB,
          onChangeA: (id) {
            setState(() => _idA = id);
            vm.selectA(id);
          },
          onChangeB: (id) {
            setState(() => _idB = id);
            vm.selectB(id);
          },
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: (a == null || b == null)
              ? const ReportEmptyState(
                  message:
                      'Karşılaştırmak için 2 senaryo seç.\nKıyaslama aşağıdaki dropdown\'lardan yapılır.',
                  icon: Icons.compare_arrows_rounded,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KpiDeltaTable(
                        a: a,
                        b: b,
                        finA: finA,
                        finB: finB,
                      ),
                      const SizedBox(height: 12),
                      _MonthlyDeltaChart(a: a, b: b),
                      const SizedBox(height: 12),
                      _PinOverlapCard(a: a, b: b),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.white70),
            tooltip: 'Geri',
            onPressed: () => Navigator.of(context).pop(),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.compare_arrows_rounded,
              size: 18, color: Colors.cyanAccent),
          const SizedBox(width: 6),
          const Text(
            'Senaryo Karşılaştırma',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerBar extends StatelessWidget {
  final List<Scenario> scenarios;
  final int? idA;
  final int? idB;
  final ValueChanged<int> onChangeA;
  final ValueChanged<int> onChangeB;

  const _PickerBar({
    required this.scenarios,
    required this.idA,
    required this.idB,
    required this.onChangeA,
    required this.onChangeB,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(builder: (ctx, c) {
        final stacked = c.maxWidth < 540;
        if (stacked) {
          return Column(
            children: [
              _drop('A', idA, onChangeA, Colors.cyanAccent),
              const SizedBox(height: 8),
              _drop('B', idB, onChangeB, const Color(0xFFF59E0B)),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _drop('A', idA, onChangeA, Colors.cyanAccent)),
            const SizedBox(width: 10),
            Expanded(
                child:
                    _drop('B', idB, onChangeB, const Color(0xFFF59E0B))),
          ],
        );
      }),
    );
  }

  Widget _drop(
    String label,
    int? selected,
    ValueChanged<int> onChange,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: DropdownButton<int>(
              value: selected,
              isDense: true,
              isExpanded: true,
              dropdownColor: const Color(0xFF1C2533),
              underline: const SizedBox.shrink(),
              icon: Icon(Icons.keyboard_arrow_down,
                  color: color, size: 18),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              items: scenarios
                  .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id != null) onChange(id);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── KPI delta tablosu ───────────────────────────────────────────────────────

class _KpiDeltaTable extends StatelessWidget {
  final Scenario a;
  final Scenario b;
  final FinancialMetrics? finA;
  final FinancialMetrics? finB;

  const _KpiDeltaTable({
    required this.a,
    required this.b,
    required this.finA,
    required this.finB,
  });

  double _d(Map<String, dynamic>? m, String k) =>
      (m?[k] as num?)?.toDouble() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final resA = a.resultData;
    final resB = b.resultData;
    final rows = <_DeltaRow>[
      _DeltaRow(
        label: 'Toplam Üretim',
        unit: 'kWh',
        a: _d(resA, 'total_kwh'),
        b: _d(resB, 'total_kwh'),
        fmt: _fmtEnergy,
      ),
      _DeltaRow(
        label: 'Güneş',
        unit: 'kWh',
        a: _d(resA, 'total_solar_kwh'),
        b: _d(resB, 'total_solar_kwh'),
        fmt: _fmtEnergy,
        color: const Color(0xFFF59E0B),
      ),
      _DeltaRow(
        label: 'Rüzgar',
        unit: 'kWh',
        a: _d(resA, 'total_wind_kwh'),
        b: _d(resB, 'total_wind_kwh'),
        fmt: _fmtEnergy,
        color: const Color(0xFF3B82F6),
      ),
      _DeltaRow(
        label: 'Hidro',
        unit: 'kWh',
        a: _d(resA, 'total_hydro_kwh'),
        b: _d(resB, 'total_hydro_kwh'),
        fmt: _fmtEnergy,
        color: const Color(0xFF06B6D4),
      ),
      if (finA != null && finB != null) ...[
        _DeltaRow(
          label: 'CAPEX',
          unit: '\$',
          a: finA!.capexTotal,
          b: finB!.capexTotal,
          fmt: _fmtMoney,
          // Daha düşük = daha iyi
          lowerIsBetter: true,
        ),
        _DeltaRow(
          label: 'NPV',
          unit: '\$',
          a: finA!.npvUsd,
          b: finB!.npvUsd,
          fmt: _fmtMoney,
        ),
        _DeltaRow(
          label: 'IRR',
          unit: '%',
          a: (finA!.irrPct ?? 0),
          b: (finB!.irrPct ?? 0),
          fmt: (v) => v.toStringAsFixed(1),
        ),
        _DeltaRow(
          label: 'LCOE',
          unit: '\$/kWh',
          a: finA!.lcoeUsdPerKwh,
          b: finB!.lcoeUsdPerKwh,
          fmt: (v) => v.toStringAsFixed(3),
          lowerIsBetter: true,
        ),
        _DeltaRow(
          label: 'Geri Ödeme',
          unit: 'yıl',
          a: finA!.paybackPeriodYears,
          b: finB!.paybackPeriodYears,
          fmt: (v) => v.toStringAsFixed(1),
          lowerIsBetter: true,
        ),
      ],
    ];

    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReportSectionHeader(
            title: 'KPI Farkları',
            subtitle:
                'Senaryo A → B fark. Yeşil: A daha iyi, kırmızı: A daha kötü.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  flex: 4,
                  child: _headerCell('Metrik', alignLeft: true)),
              Expanded(flex: 3, child: _headerCell('A')),
              Expanded(flex: 3, child: _headerCell('B')),
              Expanded(flex: 3, child: _headerCell('Fark')),
            ],
          ),
          const SizedBox(height: 4),
          ...rows.map((r) => r.build()),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {bool alignLeft = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text.toUpperCase(),
          textAlign: alignLeft ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _DeltaRow {
  final String label;
  final String unit;
  final double a;
  final double b;
  final String Function(double) fmt;
  final Color? color;
  final bool lowerIsBetter;

  _DeltaRow({
    required this.label,
    required this.unit,
    required this.a,
    required this.b,
    required this.fmt,
    this.color,
    this.lowerIsBetter = false,
  });

  Widget build() {
    final delta = a - b;
    // A daha iyi mi? higherIsBetter ise delta > 0 iyi, lowerIsBetter ise tersine.
    final aIsBetter = lowerIsBetter ? delta < 0 : delta > 0;
    final deltaColor = delta.abs() < 1e-6
        ? Colors.white38
        : (aIsBetter ? const Color(0xFF10B981) : const Color(0xFFEF4444));
    final sign = delta > 0 ? '+' : (delta < 0 ? '−' : '');
    final pctVs = b.abs() > 1e-6 ? (delta / b * 100) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                if (color != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              fmt(a),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              fmt(b),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$sign${fmt(delta.abs())}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: deltaColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (pctVs != null && pctVs.abs() > 0.1)
                  Text(
                    '$sign${pctVs.abs().toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: deltaColor.withValues(alpha: 0.65),
                      fontSize: 9,
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

// ── Aylık delta bar chart ──────────────────────────────────────────────────

class _MonthlyDeltaChart extends StatelessWidget {
  final Scenario a;
  final Scenario b;
  const _MonthlyDeltaChart({required this.a, required this.b});

  List<double>? _monthly(Scenario s) {
    final r = s.resultData;
    if (r == null) return null;
    final mb = r['monthly_breakdown'];
    if (mb is! List) return null;
    final out = <double>[];
    for (final m in mb) {
      if (m is Map) {
        out.add((m['total_kwh'] as num?)?.toDouble() ?? 0);
      }
    }
    return out.length == 12 ? out : null;
  }

  @override
  Widget build(BuildContext context) {
    final ma = _monthly(a);
    final mb = _monthly(b);
    if (ma == null || mb == null) {
      return ReportCard(
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: Colors.white.withValues(alpha: 0.40)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aylık veri eksik — senaryolar için "Yeniden Hesapla" gerek.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReportSectionHeader(
            title: 'Aylık Üretim Farkı',
            subtitle: 'Yeşil bar: A>B (A daha çok üretiyor) · Kırmızı: A<B',
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 2.8,
            child: CustomPaint(
              painter: _DeltaPainter(monthlyA: ma, monthlyB: mb),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaPainter extends CustomPainter {
  final List<double> monthlyA;
  final List<double> monthlyB;
  _DeltaPainter({required this.monthlyA, required this.monthlyB});

  static const _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final deltas = <double>[];
    for (var i = 0; i < 12; i++) {
      deltas.add(monthlyA[i] - monthlyB[i]);
    }
    final maxAbs = deltas.map((d) => d.abs()).fold<double>(0, math.max);
    if (maxAbs == 0) return;

    const padBottom = 14.0;
    final w = size.width;
    final h = size.height - padBottom;
    final midY = h / 2;

    // Orta çizgi (0 referansı)
    canvas.drawLine(
      Offset(0, midY),
      Offset(w, midY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 1,
    );

    final barW = w / 12;
    for (var i = 0; i < 12; i++) {
      final d = deltas[i];
      if (d == 0) {
        _paintLabel(canvas, size, i, barW, padBottom);
        continue;
      }
      final barH = (d.abs() / maxAbs * (h / 2 - 2)).clamp(2.0, h / 2);
      final x = i * barW + barW * 0.20;
      final bw = barW * 0.60;
      final isPositive = d > 0;
      final rect = isPositive
          ? Rect.fromLTWH(x, midY - barH, bw, barH)
          : Rect.fromLTWH(x, midY, bw, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..color = (isPositive
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444))
              .withValues(alpha: 0.85),
      );
      _paintLabel(canvas, size, i, barW, padBottom);
    }
  }

  void _paintLabel(
      Canvas canvas, Size size, int i, double barW, double padBottom) {
    final tp = TextPainter(
      text: TextSpan(
        text: _months[i],
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.50),
          fontSize: 8.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(i * barW + barW / 2 - tp.width / 2, size.height - padBottom + 1),
    );
  }

  @override
  bool shouldRepaint(covariant _DeltaPainter old) =>
      old.monthlyA != monthlyA || old.monthlyB != monthlyB;
}

// ── Pin overlap card ───────────────────────────────────────────────────────

class _PinOverlapCard extends StatelessWidget {
  final Scenario a;
  final Scenario b;
  const _PinOverlapCard({required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    final setA = a.pinIds.toSet();
    final setB = b.pinIds.toSet();
    final common = setA.intersection(setB);
    final onlyA = setA.difference(setB);
    final onlyB = setB.difference(setA);

    return ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReportSectionHeader(
            title: 'Pin Örtüşmesi',
            subtitle: 'A ve B senaryolarındaki santral kümeleri.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statTile(
                  'Sadece A', onlyA.length, Colors.cyanAccent)),
              const SizedBox(width: 8),
              Expanded(
                  child: _statTile('Ortak', common.length,
                      const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _statTile(
                  'Sadece B', onlyB.length, const Color(0xFFF59E0B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 9,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formatters ─────────────────────────────────────────────────────────────

String _fmtEnergy(double kwh) {
  final abs = kwh.abs();
  final sign = kwh < 0 ? '-' : '';
  if (abs >= 1e9) return '$sign${(abs / 1e9).toStringAsFixed(2)}T';
  if (abs >= 1e6) return '$sign${(abs / 1e6).toStringAsFixed(1)}G';
  if (abs >= 1e3) return '$sign${(abs / 1e3).toStringAsFixed(1)}M';
  return '$sign${abs.toStringAsFixed(0)}';
}

String _fmtMoney(double usd) {
  final abs = usd.abs();
  final sign = usd < 0 ? '-' : '';
  if (abs >= 1e6) return '$sign\$${(abs / 1e6).toStringAsFixed(2)}M';
  if (abs >= 1e3) return '$sign\$${(abs / 1e3).toStringAsFixed(0)}K';
  return '$sign\$${abs.toStringAsFixed(0)}';
}

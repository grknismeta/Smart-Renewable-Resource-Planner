// lib/features/reports/widgets/tabs/scenario_compare_tab.dart
//
// SENARYO TAB — Sprint R4 v3
//
// Davranış:
//   • Default: tek senaryo detay (üretim + finans + pin listesi)
//   • "Kıyasla" butonu → compareMode → ekran 2'ye bölünür, 2 senaryo yan yana
//
// Veri:
//   - GET /scenarios                  → liste
//   - POST /scenarios/{id}/calculate  → result_data (üretim breakdown)
//   - GET /scenarios/{id}/financials  → CAPEX/NPV/IRR/LCOE/payback/cashflow
//
// Senaryolar "Senaryo" sayfasından oluşturulur; bu tab onları raporlar.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:maplibre/maplibre.dart' as ml;

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/data/models/financial_metrics.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/reports/pages/scenario_compare_page.dart';
import 'package:frontend/features/reports/viewmodels/report_nav_controller.dart';
import 'package:frontend/features/reports/viewmodels/scenario_report_viewmodel.dart';
import 'package:frontend/features/reports/widgets/common/report_mini_map.dart';
import 'package:frontend/features/reports/widgets/dialogs/scenario_edit_dialog.dart';

class ScenarioCompareTab extends StatelessWidget {
  /// Senaryo panelinden açıldığında otomatik seçilecek senaryo.
  final int? initialScenarioId;
  const ScenarioCompareTab({super.key, this.initialScenarioId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ScenarioReportViewModel(
        Provider.of<ApiService>(ctx, listen: false),
      )..init(initialScenarioId: initialScenarioId),
      child: const _ScenarioBody(),
    );
  }
}

class _ScenarioBody extends StatelessWidget {
  const _ScenarioBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScenarioReportViewModel>();

    if (vm.isBusy && vm.scenarios.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
      );
    }
    if (vm.scenarios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_arrows_rounded, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'Henüz senaryo oluşturulmadı.\nSenaryo sayfasından yeni senaryo ekleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(vm: vm),
        Expanded(
          // G7: compareMode kaldırıldı; tek panel + "Kıyasla" → ayrı sayfa.
          child: _SinglePanelScroll(vm: vm, scenarioId: vm.idA),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOOLBAR
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final ScenarioReportViewModel vm;
  const _Toolbar({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      // 2026-05-25 (G7): Eski compareMode toggle (ekran 2'ye böl) kaldırıldı.
      // "Kıyasla" butonu artık doğrudan ScenarioComparePage'i push eder —
      // gerçek diff sayfası açılır, geri tuşu çalışır.
      child: Row(
        children: [
          Expanded(
            child: _ScenarioDropdown(
              label: 'Senaryo',
              color: Colors.cyanAccent,
              scenarios: vm.scenarios,
              selectedId: vm.idA,
              onChanged: (id) => vm.selectA(id),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (vm.idA == null) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: vm,
                    child: ScenarioComparePage(
                      initialIdA: vm.idA,
                      initialIdB: vm.idB,
                    ),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compare_arrows_rounded,
                      size: 14, color: Colors.white70),
                  SizedBox(width: 5),
                  Text(
                    'Kıyasla',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 2026-05-25 (Fix3): Eski tek-Row toolbar yapısı LayoutBuilder ile değişti
// — compact (mobile compareMode) Column halinde stacklenir.

class _ScenarioDropdown extends StatelessWidget {
  final String label;
  final Color color;
  final List<Scenario> scenarios;
  final int? selectedId;
  final ValueChanged<int> onChanged;

  const _ScenarioDropdown({
    required this.label,
    required this.color,
    required this.scenarios,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: DropdownButton<int>(
            value: selectedId,
            isDense: true,
            dropdownColor: const Color(0xFF1C2533),
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.keyboard_arrow_down, color: color, size: 16),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            items: scenarios
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        s.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (id) {
              if (id != null) onChanged(id);
            },
          ),
        ),
      ],
    );
  }
}

// 2026-05-25 (G7): Eski `_CompareView` (ekran 2'ye böl) silindi. Karşılaştırma
// artık ayrı sayfada (ScenarioComparePage) — gerçek diff görselleştirme.

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _SinglePanelScroll extends StatelessWidget {
  final ScenarioReportViewModel vm;
  final int? scenarioId;
  // 2026-05-25 (G7): compareMode silindi → accent default cyanAccent;
  // _CompareView'da kullanılan A/B renk ayrımı artık ScenarioComparePage'de.
  final Color accent;

  const _SinglePanelScroll({
    required this.vm,
    required this.scenarioId,
    // ignore: unused_element_parameter
    this.accent = Colors.cyanAccent,
  });

  @override
  Widget build(BuildContext context) {
    if (scenarioId == null) {
      return const Center(
        child: Text('Senaryo seç', style: TextStyle(color: Colors.white38)),
      );
    }
    final scenario = scenarioId == vm.idA ? vm.scenarioA : vm.scenarioB;
    if (scenario == null) {
      return const Center(
        child: Text('Senaryo bulunamadı', style: TextStyle(color: Colors.white38)),
      );
    }
    final financials = vm.financialsFor(scenarioId!);
    final loadingFin = vm.isLoadingFinancials(scenarioId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: _ScenarioDetailPanel(
        scenario: scenario,
        financials: financials,
        loadingFinancials: loadingFin,
        accent: accent,
        busy: vm.isBusy,
        // 2026-05-27 (Q1): Hata yakala → SnackBar ile kullanıcıya net mesaj
        // göster. Eski hâl: setError sessiz, kullanıcı "Hesapla"ya bastıktan
        // sonra hiçbir feedback yok, neden hesaplanmadığı belirsiz.
        onRecalculate: () async {
          try {
            await vm.recalculate(scenarioId!);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Senaryo hesaplanamadı: $e'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class _ScenarioDetailPanel extends StatelessWidget {
  final Scenario scenario;
  final FinancialMetrics? financials;
  final bool loadingFinancials;
  final Color accent;
  final bool busy;
  final VoidCallback onRecalculate;

  const _ScenarioDetailPanel({
    required this.scenario,
    required this.financials,
    required this.loadingFinancials,
    required this.accent,
    required this.busy,
    required this.onRecalculate,
  });

  @override
  Widget build(BuildContext context) {
    final result = scenario.resultData;
    final hasResult = result != null && result.isNotEmpty;

    // Sol kolon: harita + üretim özeti. Sağ kolon: finans + nakit akışı + pin.
    final leftCol = <Widget>[
      // 2026-05-25 (Fix6): Senaryo pin'lerinin mini haritası — coğrafi dağılım
      // görsel olarak anlaşılsın. Pin tıklayınca Santral tab'ı (4) açılır.
      _ScenarioPinMap(scenarioId: scenario.id, accent: accent),
      const SizedBox(height: 12),
      if (hasResult)
        _ProductionSummary(result: result, accent: accent)
      else
        _NotCalculated(busy: busy, onRecalculate: onRecalculate),
    ];
    final rightCol = <Widget>[
      if (loadingFinancials)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.cyanAccent),
            ),
          ),
        )
      else if (financials != null) ...[
        _FinancialCards(metrics: financials!),
        const SizedBox(height: 12),
        _CashflowChart(metrics: financials!, accent: accent),
        const SizedBox(height: 12),
        _PinList(metrics: financials!),
      ],
    ];

    // 2026-06-01: İl Analizi gibi geniş ekranda (≥1100) iki kolon yan yana
    // (sol: harita+üretim, sağ: finans). Dar/mobilde tek kolon üst üste.
    // Kolonlar içeriğe göre boyutlanır (dikey Expanded yok) → scroll içinde
    // güvenli, "unbounded height" hatası oluşmaz.
    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth >= 1100;
      if (wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(scenario: scenario, accent: accent),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: leftCol,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rightCol,
                  ),
                ),
              ],
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(scenario: scenario, accent: accent),
          const SizedBox(height: 12),
          ...leftCol,
          const SizedBox(height: 12),
          ...rightCol,
        ],
      );
    });
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Scenario scenario;
  final Color accent;
  const _Header({required this.scenario, required this.accent});

  // 2026-05-25 (G5+G6): Senaryoyu düzenle dialog'u — name, description, start/
  // end date, pin listesi (checkbox). Submit → ScenarioReportViewModel.update.
  Future<void> _openEdit(BuildContext context) async {
    final vm = context.read<ScenarioReportViewModel>();
    final allPins = vm.allPins;
    final result = await showDialog<ScenarioEditResult>(
      context: context,
      builder: (_) => ScenarioEditDialog(
        scenario: scenario,
        allPins: allPins,
      ),
    );
    if (result != null) {
      await vm.updateScenarioFields(
        scenario.id,
        name: result.name,
        description: result.description,
        startDate: result.startDate,
        endDate: result.endDate,
        pinIds: result.pinIds,
      );
    }
  }

  String _fmtDate(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.10), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_month_rounded, color: accent, size: 16),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  scenario.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // 2026-05-25 (G5+G6): Düzenle butonu — dialog ile name/date/pin
              // hepsi düzenlenebilir, submit sonrası otomatik recalculate.
              InkWell(
                onTap: () => _openEdit(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 12, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        'Düzenle',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (scenario.description != null &&
              scenario.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              scenario.description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // 2026-05-25 (G6): metaChip'ler tıklanabilir → düzenle dialog'unu açar.
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _metaChip(
                Icons.push_pin_outlined,
                '${scenario.pinIds.length} santral',
                onTap: () => _openEdit(context),
              ),
              _metaChip(
                Icons.date_range_rounded,
                // N1 (2026-05-26): end_date null → "Süresiz" → senaryo
                // bugüne kadar üretmeye devam ediyor.
                scenario.endDate == null
                    ? '${_fmtDate(scenario.startDate)} – Süresiz'
                    : '${_fmtDate(scenario.startDate)} – ${_fmtDate(scenario.endDate)}',
                onTap: () => _openEdit(context),
              ),
              if (scenario.batteryCapacityKwh != null &&
                  scenario.batteryCapacityKwh! > 0)
                _metaChip(
                  Icons.battery_charging_full_rounded,
                  '${scenario.batteryCapacityKwh!.toStringAsFixed(0)} kWh depolama',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text, {VoidCallback? onTap}) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.45)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 10.5,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 3),
          Icon(Icons.edit_outlined,
              size: 10, color: Colors.white.withValues(alpha: 0.35)),
        ],
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: content,
      ),
    );
  }
}

// ── Üretim özeti ─────────────────────────────────────────────────────────────

class _ProductionSummary extends StatelessWidget {
  final Map<String, dynamic> result;
  final Color accent;
  const _ProductionSummary({required this.result, required this.accent});

  double _d(String k) => (result[k] as num?)?.toDouble() ?? 0;
  int _i(String k) => (result[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final totalKwh = _d('total_kwh');
    final solar = _d('total_solar_kwh');
    final wind = _d('total_wind_kwh');
    final hydro = _d('total_hydro_kwh');
    final total = solar + wind + hydro;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAHMİNİ YILLIK ÜRETİM',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmtEnergy(totalKwh),
                style: TextStyle(
                  color: accent,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _energyUnit(totalKwh),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 3 kaynak breakdown bar
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (solar > 0)
                      Expanded(
                        flex: (solar / total * 1000).round(),
                        child: Container(color: const Color(0xFFF59E0B)),
                      ),
                    if (wind > 0)
                      Expanded(
                        flex: (wind / total * 1000).round(),
                        child: Container(color: const Color(0xFF3B82F6)),
                      ),
                    if (hydro > 0)
                      Expanded(
                        flex: (hydro / total * 1000).round(),
                        child: Container(color: const Color(0xFF06B6D4)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _resLegend('Güneş', solar, _i('solar_count'),
                    const Color(0xFFF59E0B)),
                _resLegend('Rüzgar', wind, _i('wind_count'),
                    const Color(0xFF3B82F6)),
                _resLegend('Hidro', hydro, _i('hydro_count'),
                    const Color(0xFF06B6D4)),
              ],
            ),
            // 2026-05-25 (P1/4): Aylık breakdown bar chart — backend monthly_
            // breakdown alanı varsa göster.
            if (result['monthly_breakdown'] is List) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              _MonthlyBreakdownChart(
                breakdown: List<Map<String, dynamic>>.from(
                  (result['monthly_breakdown'] as List).map(
                    (e) => Map<String, dynamic>.from(e as Map),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _resLegend(String label, double kwh, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ($count) · ${_fmtEnergy(kwh)} ${_energyUnit(kwh)}',
          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
        ),
      ],
    );
  }
}

// ── Hesaplanmamış senaryo ────────────────────────────────────────────────────

class _NotCalculated extends StatelessWidget {
  final bool busy;
  final VoidCallback onRecalculate;
  const _NotCalculated({required this.busy, required this.onRecalculate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.calculate_outlined, color: Colors.orange, size: 28),
          const SizedBox(height: 8),
          const Text(
            'Bu senaryo henüz hesaplanmamış',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: busy ? null : onRecalculate,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black54),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 16),
            label: Text(busy ? 'Hesaplanıyor...' : 'Şimdi Hesapla'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Finans kartları ──────────────────────────────────────────────────────────

class _FinancialCards extends StatelessWidget {
  final FinancialMetrics metrics;
  const _FinancialCards({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('CAPEX', _fmtMoney(metrics.capexTotal), 'Toplam yatırım',
          const Color(0xFFF59E0B)),
      ('NPV (25y)', _fmtMoney(metrics.npvUsd),
          metrics.npvUsd >= 0 ? 'Pozitif — kârlı' : 'Negatif',
          metrics.npvUsd >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
      ('IRR', metrics.irrPct != null
          ? '%${metrics.irrPct!.toStringAsFixed(1)}'
          : '—', 'İç verim oranı', Colors.cyanAccent),
      ('LCOE', '\$${metrics.lcoeUsdPerKwh.toStringAsFixed(3)}', 'Birim maliyet/kWh',
          const Color(0xFFA855F7)),
      ('Geri Ödeme', '${metrics.paybackPeriodYears.toStringAsFixed(1)} yıl',
          'Yatırım amortismanı', const Color(0xFF3B82F6)),
      ('CO₂ Önleme', '${metrics.annualCo2AvoidedTons.toStringAsFixed(0)} t/yıl',
          'Yıllık emisyon', const Color(0xFF34D399)),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      final cross = c.maxWidth >= 480 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cross,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.55,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: cards
            .map((c) => _finCard(c.$1, c.$2, c.$3, c.$4))
            .toList(),
      );
    });
  }

  Widget _finCard(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sub,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Cashflow chart ───────────────────────────────────────────────────────────

class _CashflowChart extends StatelessWidget {
  final FinancialMetrics metrics;
  final Color accent;
  const _CashflowChart({required this.metrics, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cum = metrics.cumulativeCashflows;
    if (cum.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kümülatif Nakit Akışı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${metrics.projectLifetimeYears} yıl · başabaş ${metrics.paybackPeriodYears.toStringAsFixed(1)}. yıl',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 2.6,
            child: CustomPaint(
              painter: _CashflowPainter(cumulative: cum, accent: accent),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowPainter extends CustomPainter {
  final List<double> cumulative;
  final Color accent;
  _CashflowPainter({required this.cumulative, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (cumulative.length < 2) return;
    const padL = 36.0, padR = 8.0, padT = 8.0, padB = 18.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    final minV = math.min(0.0, cumulative.reduce(math.min));
    final maxV = math.max(0.0, cumulative.reduce(math.max));
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);

    double xFor(int i) => padL + i / (cumulative.length - 1) * w;
    double yFor(double v) => padT + h - (v - minV) / range * h;

    // Sıfır çizgisi
    final zeroY = yFor(0);
    canvas.drawLine(
      Offset(padL, zeroY),
      Offset(size.width - padR, zeroY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..strokeWidth = 1,
    );

    // Çizgi
    final path = Path();
    for (var i = 0; i < cumulative.length; i++) {
      final x = xFor(i);
      final y = yFor(cumulative[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Başabaş noktası (sıfırı geçtiği yer)
    for (var i = 1; i < cumulative.length; i++) {
      if (cumulative[i - 1] < 0 && cumulative[i] >= 0) {
        canvas.drawCircle(
          Offset(xFor(i), yFor(cumulative[i])),
          3.5,
          Paint()..color = const Color(0xFF10B981),
        );
        break;
      }
    }

    // Y ekseni etiketleri (min / 0 / max)
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.40),
      fontSize: 8,
    );
    void yLabel(double v) {
      final tp = TextPainter(
        text: TextSpan(text: _fmtMoneyShort(v), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - tp.width - 3, yFor(v) - 5));
    }

    yLabel(maxV);
    if (minV < 0) yLabel(minV);

    // X ekseni — yıl etiketleri (her 5 yıl)
    for (var i = 0; i < cumulative.length; i += 5) {
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xFor(i) - tp.width / 2, size.height - padB + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _CashflowPainter old) =>
      old.cumulative != cumulative || old.accent != accent;
}

// ── Pin listesi ──────────────────────────────────────────────────────────────

class _PinList extends StatelessWidget {
  final FinancialMetrics metrics;
  const _PinList({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.perPin.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Santraller (${metrics.perPin.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...metrics.perPin.map((p) => _PinRow(detail: p)),
        ],
      ),
    );
  }
}

/// 2026-05-25 (G5): Pin satırı tıklanabilir — Santral tab'a drill-down.
/// `ReportNavController.requestPin` ile pin id taşır, sonra tab 4'e geçer.
class _PinRow extends StatelessWidget {
  final PinFinanceDetail detail;
  const _PinRow({required this.detail});

  Color get _color => switch (detail.type.toLowerCase()) {
        'güneş paneli' || 'solar' => const Color(0xFFF59E0B),
        'rüzgar türbini' || 'wind' => const Color(0xFF3B82F6),
        'hidroelektrik' || 'hydro' => const Color(0xFF06B6D4),
        _ => Colors.white54,
      };

  void _openSantral(BuildContext context) {
    context.read<ReportNavController>().requestPin(detail.pinId);
    DefaultTabController.of(context).animateTo(4);
  }

  @override
  Widget build(BuildContext context) {
    // VM'den pin adını/şehrini bulmaya çalış (PinFinanceDetail sadece id +
    // type + capacity verir). Yoksa "Pin #N" fallback.
    final vm = context.watch<ScenarioReportViewModel>();
    final pin = vm.allPins.cast<dynamic>().firstWhere(
          (p) => p.id == detail.pinId,
          orElse: () => null,
        );
    final displayName = pin == null
        ? 'Pin #${detail.pinId}'
        : (pin.name as String? ?? 'Pin #${detail.pinId}');
    final city = pin?.city as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _openSantral(context),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _color.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (city != null && city.isNotEmpty)
                      Text(
                        city,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 9.5,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${detail.capacityMw.toStringAsFixed(1)} MW',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_fmtEnergy(detail.annualKwh)} ${_energyUnit(detail.annualKwh)}',
                style: TextStyle(
                  color: _color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Format helper'ları
// ─────────────────────────────────────────────────────────────────────────────

String _fmtEnergy(double kwh) {
  if (kwh >= 1e9) return (kwh / 1e9).toStringAsFixed(2);
  if (kwh >= 1e6) return (kwh / 1e6).toStringAsFixed(1);
  if (kwh >= 1e3) return (kwh / 1e3).toStringAsFixed(1);
  return kwh.toStringAsFixed(0);
}

String _energyUnit(double kwh) {
  if (kwh >= 1e9) return 'TWh';
  if (kwh >= 1e6) return 'GWh';
  if (kwh >= 1e3) return 'MWh';
  return 'kWh';
}

String _fmtMoney(double usd) {
  final abs = usd.abs();
  final sign = usd < 0 ? '-' : '';
  if (abs >= 1e6) return '$sign\$${(abs / 1e6).toStringAsFixed(1)}M';
  if (abs >= 1e3) return '$sign\$${(abs / 1e3).toStringAsFixed(0)}K';
  return '$sign\$${abs.toStringAsFixed(0)}';
}

String _fmtMoneyShort(double usd) {
  final abs = usd.abs();
  final sign = usd < 0 ? '-' : '';
  if (abs >= 1e6) return '$sign${(abs / 1e6).toStringAsFixed(0)}M';
  if (abs >= 1e3) return '$sign${(abs / 1e3).toStringAsFixed(0)}K';
  return '$sign${abs.toStringAsFixed(0)}';
}

// ── Senaryo pin haritası ────────────────────────────────────────────────────

/// 2026-05-25 (Fix6): ScenarioReportViewModel'dan senaryo pin'lerini lat/lon
/// ile alır ve ReportMiniMap üzerinde tipine göre renkli marker olarak gösterir.
/// Pin'in bbox'una hapsedilir (bounds), tıklayınca Santral tab'ına yönlendirir.
class _ScenarioPinMap extends StatelessWidget {
  final int scenarioId;
  final Color accent;
  const _ScenarioPinMap({required this.scenarioId, required this.accent});

  // 2026-05-25 (Fix6): Marker rengini pin tipinden alma yardımcısı —
  // şimdilik ReportMiniMap score-based renk kullandığı için kullanılmıyor;
  // ilerde marker.color desteği eklenince devreye alınacak.
  // ignore: unused_element
  Color _colorFor(String type) {
    switch (type) {
      case 'Güneş Paneli':
        return const Color(0xFFF59E0B);
      case 'Rüzgar Türbini':
        return const Color(0xFF3B82F6);
      case 'Hidroelektrik':
        return const Color(0xFF06B6D4);
      default:
        return accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScenarioReportViewModel>();
    final pins = vm.pinsForScenario(scenarioId);
    if (pins.isEmpty) {
      // 2026-05-25 (Polish2): pinsLoaded=false ise loading; true ise gerçekten
      // empty. Eskiden ikisi de "Bu senaryoya bağlı pin yok" gösteriyordu.
      final isLoading = !vm.pinsLoaded;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.cyanAccent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Pin lokasyonları yükleniyor...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
            ] else ...[
              Icon(Icons.map_outlined,
                  size: 14, color: Colors.white.withValues(alpha: 0.40)),
              const SizedBox(width: 8),
              Text(
                'Bu senaryoya bağlı pin yok',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    }
    // Tipe göre renkli marker'lar — score her marker için 70 sabit
    // (skor değil tip vurgusu önemli; renk type'tan geliyor zaten).
    final markers = pins
        .map((p) => ReportMapMarker(
              lat: p.latitude,
              lon: p.longitude,
              label: p.name,
              score: 70,
            ))
        .toList();
    // Bbox = pin koordinatları, Türkiye sınırlarına CLAMP'li.
    // Sınır/bozuk koordinatlı bir pin (ör. "Yurtdışı" RES) bbox'ı Bulgaristan'a
    // taşıyordu → harita Türkiye dışını gösteriyordu. Clamp ile harita hep
    // Türkiye'de kalır (web+mobil aynı). TR bbox ~ [25.5..45.0]E, [35.7..42.3]N.
    const trW = 25.5, trE = 45.0, trS = 35.7, trN = 42.3;
    double cl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
    ml.LngLatBounds? bounds;
    if (pins.isNotEmpty) {
      double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
      for (final p in pins) {
        final la = cl(p.latitude, trS, trN);
        final lo = cl(p.longitude, trW, trE);
        if (la < minLat) minLat = la;
        if (la > maxLat) maxLat = la;
        if (lo < minLon) minLon = lo;
        if (lo > maxLon) maxLon = lo;
      }
      // Tek pin / aynı konum → dejenere bbox'a minimum açıklık ver.
      if ((maxLat - minLat) < 0.15) { minLat -= 0.1; maxLat += 0.1; }
      if ((maxLon - minLon) < 0.15) { minLon -= 0.1; maxLon += 0.1; }
      bounds = ml.LngLatBounds(
        longitudeWest: minLon,
        latitudeSouth: minLat,
        longitudeEast: maxLon,
        latitudeNorth: maxLat,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on_rounded, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(
              'Pin Dağılımı (${pins.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            // Mini lejant — kaynak tiplerinin renkleri
            _typeChip('Güneş', const Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            _typeChip('Rüzgar', const Color(0xFF3B82F6)),
            const SizedBox(width: 4),
            _typeChip('Hidro', const Color(0xFF06B6D4)),
          ],
        ),
        const SizedBox(height: 8),
        ReportMiniMap(
          // 2026-06-01: maxBounds pin bbox'una bağlıyken web'de pan kilitleniyor
          // + tüm Türkiye görünmüyordu, mobilde de boundary tutmuyordu. Çözüm:
          // maxBounds = TÜM TÜRKİYE (her yere pan + ülke geneli görünür), kamera
          // yine pin'lere fit (bounds). İl + pin illerinin ilçe sınırları çizilir.
          height: 320,
          markers: markers,
          bounds: bounds,
          maxBoundsOverride: ml.LngLatBounds(
            longitudeWest: trW - 0.3,
            latitudeSouth: trS - 0.3,
            longitudeEast: trE + 0.3,
            latitudeNorth: trN + 0.3,
          ),
          showProvinceBorders: true,
          districtProvinceFilters: pins
              .map((p) => p.city)
              .whereType<String>()
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList(),
          // Pin tipini renge yansıtmak için fixedColor değil, score-color hili.
          // Daha doğru renklendirme için marker tipini score değil renge map'le:
          // ReportMiniMap'in _colorFor 0-100 score üstünden renk veriyor — biz
          // tipe göre renkli istiyoruz. Quick hack: type listemden çek ve
          // fixedColor null olsun (skor bazlı palette). İlerde tipe-göre renk
          // için ReportMiniMap'e marker.color desteği eklenebilir.
          onMarkerTap: (m) {
            // 2026-05-25 (Polish1): Marker tıkla → ReportNavController.requestPin
            // ile Santral tab'a id yaz + tab 4'e geç → SantralBody pendingPinId'yi
            // tüketip pin'i seçer.
            final tapped = pins.firstWhere(
              (p) =>
                  (p.latitude - m.lat).abs() < 1e-6 &&
                  (p.longitude - m.lon).abs() < 1e-6,
              orElse: () => pins.first,
            );
            context.read<ReportNavController>().requestPin(tapped.id);
            DefaultTabController.of(context).animateTo(4);
          },
        ),
      ],
    );
  }

  Widget _typeChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

// ── Aylık üretim breakdown ──────────────────────────────────────────────────

/// 2026-05-25 (P1/4): Stacked bar chart — 12 ay × 3 kaynak (solar/wind/hydro).
/// Backend `monthly_breakdown` listesinden çizilir; climatology profilinden
/// türetilmiş orantısal dağılım (kesin değil — yıllık toplamı 12 aya bölmek
/// için kullanışlı yaklaşım).
class _MonthlyBreakdownChart extends StatelessWidget {
  final List<Map<String, dynamic>> breakdown;
  const _MonthlyBreakdownChart({required this.breakdown});

  static const _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 13, color: Colors.cyanAccent),
            const SizedBox(width: 6),
            Text(
              'Aylık Üretim Dağılımı',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'climatology profilinden',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 3.0,
          child: CustomPaint(
            painter: _MonthlyBreakdownPainter(
              breakdown: breakdown,
              months: _months,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _MonthlyBreakdownPainter extends CustomPainter {
  final List<Map<String, dynamic>> breakdown;
  final List<String> months;
  _MonthlyBreakdownPainter({required this.breakdown, required this.months});

  static const _colSolar = Color(0xFFF59E0B);
  static const _colWind = Color(0xFF3B82F6);
  static const _colHydro = Color(0xFF06B6D4);

  double _d(Map<String, dynamic> m, String k) =>
      (m[k] as num?)?.toDouble() ?? 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (breakdown.isEmpty) return;
    const padBottom = 14.0;
    const padTop = 8.0;
    final w = size.width;
    final h = size.height - padBottom - padTop;

    // Max toplam aylık üretim — bar yüksekliği için referans
    double maxTotal = 0;
    for (final m in breakdown) {
      final t = _d(m, 'total_kwh');
      if (t > maxTotal) maxTotal = t;
    }
    if (maxTotal <= 0) return;

    final barW = w / 12;
    for (var i = 0; i < math.min(breakdown.length, 12); i++) {
      final m = breakdown[i];
      final solar = _d(m, 'solar_kwh');
      final wind = _d(m, 'wind_kwh');
      final hydro = _d(m, 'hydro_kwh');
      final total = solar + wind + hydro;
      if (total <= 0) {
        // Sadece ay etiketi
        _paintMonthLabel(canvas, size, i, barW, padBottom);
        continue;
      }
      final barH = (total / maxTotal * h).clamp(2.0, h);
      final x = i * barW + barW * 0.18;
      final bw = barW * 0.64;
      // Stack: hydro alt, wind orta, solar üst (renk vurgusu için)
      double yStart = padTop + h - barH;
      final segments = <(double, Color)>[
        (hydro / total * barH, _colHydro),
        (wind / total * barH, _colWind),
        (solar / total * barH, _colSolar),
      ];
      for (final seg in segments) {
        if (seg.$1 <= 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(x, yStart, bw, seg.$1),
          Paint()..color = seg.$2,
        );
        yStart += seg.$1;
      }
      _paintMonthLabel(canvas, size, i, barW, padBottom);
    }
  }

  void _paintMonthLabel(
      Canvas canvas, Size size, int i, double barW, double padBottom) {
    final tp = TextPainter(
      text: TextSpan(
        text: months[i],
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.50),
          fontSize: 8.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = i * barW + barW / 2 - tp.width / 2;
    tp.paint(canvas, Offset(x, size.height - padBottom + 1));
  }

  @override
  bool shouldRepaint(covariant _MonthlyBreakdownPainter old) =>
      old.breakdown != breakdown;
}

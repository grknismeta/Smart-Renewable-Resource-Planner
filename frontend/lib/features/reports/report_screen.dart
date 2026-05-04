// lib/features/reports/report_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/system_data_models.dart' show RegionalSite;
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/features/reports/widgets/tabs/province_drill_tab.dart';
import 'package:frontend/features/reports/widgets/tabs/scenario_compare_tab.dart';
import 'package:frontend/features/reports/widgets/tabs/monthly_trend_tab.dart';
import 'package:frontend/features/reports/widgets/tabs/export_tab.dart';
import 'package:frontend/features/reports/widgets/report_map.dart';
import 'package:frontend/features/reports/widgets/report_map_view.dart';
import 'package:frontend/shared/widgets/app_background.dart';

/// Raporlar ekranı — Sprint 6 yeniden tasarım
///
/// 5 tab (Aşama 2 — "Genel Bakış" sekmesi kaldırıldı):
///   0 İl Analizi  1 Senaryo  2 Trend  3 Harita  4 Export
class ReportScreen extends StatefulWidget {
  /// Haritadan doğrudan bir il seçilerek açıldığında ön yükleme için.
  final String? initialProvince;

  /// Senaryo panelinden açıldığında ilgili senaryo otomatik seçilsin diye.
  /// null ise normal akış (default tab: 0).
  final int? initialScenarioId;

  const ReportScreen({super.key, this.initialProvince, this.initialScenarioId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const int _kTabCount = 5;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final reportVM = Provider.of<ReportViewModel>(context, listen: false);
      await reportVM.init();
      if (!mounted) return;
      if (widget.initialProvince != null) {
        reportVM.fetchReport(province: widget.initialProvince);
        // Summaries yüklendikten sonra ili otomatik seç
        reportVM.selectProvinceByName(widget.initialProvince!);
      }
      if (!mounted) return;
      final scenarioVM = Provider.of<ScenarioViewModel>(context, listen: false);
      await scenarioVM.loadScenarios();
      if (!mounted) return;
      if (widget.initialScenarioId != null) {
        scenarioVM.selectOnly(widget.initialScenarioId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeViewModel>();
    return DefaultTabController(
      length: _kTabCount,
      // Haritadan il seçilerek açıldıysa İl Analizi (0), senaryo ile
      // açıldıysa Senaryo Karşılaştır (1) tab'ına git.
      // Genel Bakış tab kaldırıldıktan sonra index'ler 1 azaldı.
      initialIndex: widget.initialScenarioId != null
          ? 1
          : 0,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                const _AppBar(),
                Expanded(
                  child: TabBarView(
                    children: [
                      const ProvinceDrillTab(),
                      const ScenarioCompareTab(),
                      const MonthlyTrendTab(),
                      // Tab 3 — Harita (tam ekran MapScreen embed)
                      const _MapTabWrapper(),
                      const ExportTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık Satırı ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                // Geri butonu
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/');
                    }
                  },
                  tooltip: 'Haritaya Dön',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Raporlar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                // Zaman aralığı seçici — dar ekranda yatay kaydırılabilir.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: const _TimeRangeSelector(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── TabBar ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: Colors.cyanAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.4),
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(vertical: 3),
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  icon: Icon(Icons.location_city_rounded, size: 15),
                  text: 'İl Analizi',
                ),
                Tab(
                  icon: Icon(Icons.compare_arrows_rounded, size: 15),
                  text: 'Senaryo',
                ),
                Tab(
                  icon: Icon(Icons.show_chart_rounded, size: 15),
                  text: 'Trend',
                ),
                Tab(icon: Icon(Icons.map_rounded, size: 15), text: 'Harita'),
                Tab(
                  icon: Icon(Icons.picture_as_pdf_outlined, size: 15),
                  text: 'Export',
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
            thickness: 1,
          ),
        ],
      ),
    );
  }
}

// ── Zaman Aralığı Seçici ───────────────────────────────────────────────────────

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector();

  static const _months = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mod seçici
        _ModeChip(
          label: 'Yıllık',
          active: vm.dateRangeMode == DateRangeMode.yearly,
          onTap: () => vm.setDateRangeMode(DateRangeMode.yearly),
        ),
        const SizedBox(width: 4),
        _ModeChip(
          label: 'Aylık',
          active: vm.dateRangeMode == DateRangeMode.monthly,
          onTap: () => vm.setDateRangeMode(DateRangeMode.monthly),
        ),
        const SizedBox(width: 4),
        _ModeChip(
          label: 'Özel',
          active: vm.dateRangeMode == DateRangeMode.custom,
          onTap: () => _pickCustomRange(context, vm),
        ),
        const SizedBox(width: 4),

        // Yıl seçici (yearly/monthly modunda)
        if (vm.dateRangeMode != DateRangeMode.custom &&
            vm.availableYears.isNotEmpty) ...[
          _SmallDropdown<int>(
            value: vm.selectedYear,
            items: vm.availableYears,
            label: (y) => '$y',
            onChanged: (y) {
              if (y != null) vm.setYear(y);
            },
          ),
        ],

        // Ay seçici (monthly modunda)
        if (vm.dateRangeMode == DateRangeMode.monthly) ...[
          const SizedBox(width: 4),
          _SmallDropdown<int>(
            value: vm.selectedMonth,
            items: List.generate(12, (i) => i + 1),
            label: (m) => _months[m - 1],
            hint: 'Ay',
            onChanged: (m) => vm.setMonth(m),
          ),
        ],

        // Özel aralık göstergesi
        if (vm.dateRangeMode == DateRangeMode.custom &&
            vm.customRangeStart != null) ...[
          GestureDetector(
            onTap: () => _pickCustomRange(context, vm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '${_fmtDate(vm.customRangeStart!)} – ${_fmtDate(vm.customRangeEnd!)}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    ReportViewModel vm,
  ) async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: vm.customRangeStart != null
          ? DateTimeRange(start: vm.customRangeStart!, end: vm.customRangeEnd!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 365)),
              end: now,
            ),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.cyanAccent,
            onPrimary: Colors.black,
            surface: Color(0xFF1C2533),
          ),
        ),
        child: child!,
      ),
    );
    if (result != null) {
      vm.setCustomRange(result.start, result.end);
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active
                ? Colors.cyanAccent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.cyanAccent : Colors.white38,
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SmallDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) label;
  final String? hint;
  final ValueChanged<T?> onChanged;

  const _SmallDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButton<T>(
        value: items.contains(value) ? value : null,
        isDense: true,
        dropdownColor: const Color(0xFF1C2533),
        underline: const SizedBox.shrink(),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white38,
          size: 14,
        ),
        hint: hint != null
            ? Text(
                hint!,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              )
            : null,
        style: const TextStyle(color: Colors.white, fontSize: 11),
        items: items
            .map(
              (e) => DropdownMenuItem<T>(
                value: e,
                child: Text(
                  label(e),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Harita Tab Sarmalayıcı ────────────────────────────────────────────────────

/// Tab 3 (eski 5) — MapLibre harita (sol) + Bölge listesi (sağ) yan yana.
///
/// Aşama 2: İl listesinden site tıklamasında harita seçili site'a flyTo yapar
/// (`_focusedSite` state ile bağlı).
class _MapTabWrapper extends StatefulWidget {
  const _MapTabWrapper();

  @override
  State<_MapTabWrapper> createState() => _MapTabWrapperState();
}

class _MapTabWrapperState extends State<_MapTabWrapper> {
  RegionalSite? _focusedSite;

  void _onSiteFocused(RegionalSite site) {
    setState(() => _focusedSite = site);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    final screenWidth = MediaQuery.of(context).size.width;
    // Dar ekranda sadece harita (liste tıklaması için aşağıda mini liste yok;
    // sağ panel olmadığı için focus akışı geniş ekrana özgü)
    if (screenWidth < 800) {
      return ReportMapView(
        onSiteFocused: _onSiteFocused,
        focusedSite: _focusedSite,
      );
    }
    return Row(
      children: [
        // Sol: MapLibre harita
        Expanded(
          flex: 3,
          child: ReportMapView(
            onSiteFocused: _onSiteFocused,
            focusedSite: _focusedSite,
          ),
        ),
        // Sağ: Bölge listesi — tıklama → harita zoom
        SizedBox(
          width: 320,
          child: ReportMap(
            type: vm.selectedType,
            onSiteFocused: _onSiteFocused,
          ),
        ),
      ],
    );
  }
}

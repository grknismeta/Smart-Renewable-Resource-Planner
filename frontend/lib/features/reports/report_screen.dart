import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/shared/widgets/app_background.dart';
import 'package:frontend/shared/widgets/glass_container.dart';
import 'package:frontend/features/reports/widgets/report_map.dart';
import 'package:frontend/features/reports/widgets/scenario_map_in_report.dart';
import 'package:frontend/features/reports/widgets/scenario_result_panel.dart';
import 'package:frontend/features/reports/widgets/turkey_energy_panel.dart';
import 'package:frontend/features/reports/widgets/report_stats_row.dart';
import 'package:frontend/features/reports/widgets/report_ranked_list.dart';

/// Raporlar sekmesi — yeniden tasarım (Sprint 2)
///
/// Layout:
/// ┌───────────────────────────────────────────────────────────────────┐
/// │  ← Raporlar   [Bölge▼] [Solar/Wind▼] [Yıllık▼]  [Senaryo▼] [PDF]│
/// ├─────────────────────────────┬─────────────────────────────────────┤
/// │  Harita                     │  Özet Kartlar (4 adet)              │
/// │  (flutter_map / senaryo)    │  ──────────────────────────         │
/// │                             │  Sıralanmış Lokasyon Listesi         │
/// │                             │  (progress bar + değer)              │
/// │                             │  ──────────────────────────         │
/// │                             │  [Türkiye İstatistikleri ▼]         │
/// └─────────────────────────────┴─────────────────────────────────────┘
///
/// Dar (<900px): Tab bar → Harita | Sıralama | İstatistikler
class ReportScreen extends StatefulWidget {
  /// Haritadan doğrudan bir il seçilerek açıldığında ön yükleme için.
  final String? initialProvince;

  const ReportScreen({super.key, this.initialProvince});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  // ── Harita ─────────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();

  // ── Filtreler ───────────────────────────────────────────────────────────────
  String _region = 'Tümü';
  String _type = 'Wind';
  String _timeInterval = 'Yıllık';
  String? _province;
  int? _selectedScenarioId;

  // ── Türkiye istatistikleri accordion ────────────────────────────────────────
  bool _turkeyExpanded = false;

  // ── Dar ekran sekme kontrolü ─────────────────────────────────────────────
  late TabController _tabController;

  // ── PDF export ──────────────────────────────────────────────────────────────
  bool _exportingPdf = false;

  // ── Seçenekler ─────────────────────────────────────────────────────────────
  static const _regions = [
    'Tümü', 'Marmara', 'Ege', 'Akdeniz',
    'İç Anadolu', 'Karadeniz', 'Doğu Anadolu', 'Güneydoğu Anadolu',
  ];
  static const _types = ['Wind', 'Solar'];
  static const _intervals = ['Yıllık', 'Aylık', 'Anlık'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _province = widget.initialProvince;
    Future.microtask(() {
      if (!mounted) return;
      _fetchReport();
      Provider.of<ScenarioViewModel>(context, listen: false).loadScenarios();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _fetchReport({bool clearProvince = false}) {
    Provider.of<ReportViewModel>(context, listen: false).fetchReport(
      region: _region,
      type: _type,
      interval: _timeInterval,
      province: clearProvince ? null : _province,
      clearProvince: clearProvince,
    );
  }

  void _onSiteFocused(RegionalSite site) {
    _mapController.move(LatLng(site.latitude, site.longitude), 8.0);
    // Dar ekranda harita sekmesine geç
    if (_tabController.index != 0) _tabController.animateTo(0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Provider.of<ThemeViewModel>(context); // tema değişikliklerini dinle
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                Expanded(
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    return isWide
                        ? _buildWideLayout()
                        : _buildNarrowLayout();
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Başlık ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final scenarios = Provider.of<ScenarioViewModel>(context).scenarios;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AppBar satırı
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white70),
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/map'),
              tooltip: 'Haritaya Dön',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Raporlar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // PDF export
            if (_exportingPdf)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.redAccent),
                ),
              )
            else
              Tooltip(
                message: 'PDF olarak indir',
                child: IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      color: Colors.redAccent, size: 20),
                  onPressed: _exportPdf,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Filtre çipleri
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Senaryo seçici (varsa)
              if (scenarios.isNotEmpty) ...[
                _buildDropdown(
                  value: _selectedScenarioId?.toString() ?? 'regional',
                  items: ['regional', ...scenarios.map((s) => s.id.toString())],
                  displayFn: (v) {
                    if (v == 'regional') return 'Bölgesel Rapor';
                    try {
                      return scenarios
                          .firstWhere((s) => s.id.toString() == v)
                          .name;
                    } catch (_) {
                      return 'Senaryo';
                    }
                  },
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedScenarioId =
                          v == 'regional' ? null : int.tryParse(v);
                    });
                    if (v == 'regional') _fetchReport();
                  },
                ),
                const SizedBox(width: 8),
              ],

              // Zaman aralığı
              _buildDropdown(
                value: _timeInterval,
                items: _intervals,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _timeInterval = v);
                  _fetchReport();
                },
              ),
              const SizedBox(width: 8),

              // Bölge
              _buildDropdown(
                value: _region,
                items: _regions,
                onChanged: (v) {
                  if (v == null || _selectedScenarioId != null) return;
                  setState(() {
                    _region = v;
                    _province = null;
                  });
                  _fetchReport(clearProvince: true);
                },
              ),
              const SizedBox(width: 8),

              // Kaynak tipi
              _buildDropdown(
                value: _type,
                items: _types,
                onChanged: (v) {
                  if (v == null || _selectedScenarioId != null) return;
                  setState(() => _type = v);
                  _fetchReport();
                },
              ),

              // Aktif il filtresi chip
              if (_province != null) ...[
                const SizedBox(width: 8),
                _ProvinceChip(
                  province: _province!,
                  onClear: () {
                    setState(() => _province = null);
                    _fetchReport(clearProvince: true);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Geniş layout (>900px) ──────────────────────────────────────────────────

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 55,
          child: GlassContainer(child: _buildMapPanel()),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 45,
          child: GlassContainer(child: _buildInfoPanel()),
        ),
      ],
    );
  }

  // ── Dar layout (<900px) ────────────────────────────────────────────────────

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white54,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.map_rounded, size: 16), text: 'Harita'),
              Tab(
                  icon: Icon(Icons.format_list_numbered_rounded, size: 16),
                  text: 'Sıralama'),
              Tab(
                  icon: Icon(Icons.bar_chart_rounded, size: 16),
                  text: 'İstatistikler'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              GlassContainer(child: _buildMapPanel()),
              GlassContainer(child: _buildInfoPanel()),
              const GlassContainer(child: TurkeyEnergyPanel()),
            ],
          ),
        ),
      ],
    );
  }

  // ── Harita paneli ──────────────────────────────────────────────────────────

  Widget _buildMapPanel() {
    if (_selectedScenarioId != null) {
      return ScenarioMapInReport(
        mapController: _mapController,
        scenarioId: _selectedScenarioId!,
      );
    }
    return ReportMap(
      mapController: _mapController,
      type: _type,
      onSiteFocused: _onSiteFocused,
    );
  }

  // ── Bilgi paneli ──────────────────────────────────────────────────────────

  Widget _buildInfoPanel() {
    // Senaryo modu
    if (_selectedScenarioId != null) {
      return ScenarioResultPanel(scenarioId: _selectedScenarioId!);
    }

    final report = Provider.of<ReportViewModel>(context).report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Özet kartlar
        if (report != null && report.items.isNotEmpty) ...[
          const SizedBox(height: 4),
          ReportStatsRow(report: report, type: _type),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 12),
        ],

        // Sıralama listesi
        Expanded(
          child: ReportRankedList(
            onSiteSelected: _onSiteFocused,
            type: _type,
          ),
        ),

        // Türkiye istatistikleri accordion
        _TurkeyAccordion(
          expanded: _turkeyExpanded,
          onToggle: () =>
              setState(() => _turkeyExpanded = !_turkeyExpanded),
        ),
      ],
    );
  }

  // ── Dropdown yardımcısı ────────────────────────────────────────────────────

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayFn,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        dropdownColor: const Color(0xFF1C2533),
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down,
            color: Colors.white60, size: 16),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        items: items
            .map((e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(
                    displayFn != null ? displayFn(e) : e,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ── PDF Export ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);

    try {
      final pdf = pw.Document();
      final dateStr =
          DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.now());

      if (_selectedScenarioId != null) {
        final vm = Provider.of<ScenarioViewModel>(context, listen: false);
        final scenario = vm.scenarios.firstWhere(
          (s) => s.id == _selectedScenarioId,
          orElse: () => vm.scenarios.first,
        );
        pdf.addPage(_buildScenarioPdfPage(scenario, dateStr));
      } else {
        final rp = Provider.of<ReportViewModel>(context, listen: false);
        pdf.addPage(_buildRegionalPdfPage(rp.report, dateStr));
      }

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'SRRP_Rapor_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF oluşturulamadı: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  pw.Page _buildScenarioPdfPage(Scenario scenario, String dateStr) {
    final summary = scenario.resultData ?? {};
    final totalSolar = (summary['total_solar_kwh'] as num?)?.toDouble() ?? 0;
    final totalWind = (summary['total_wind_kwh'] as num?)?.toDouble() ?? 0;
    final totalHydro = (summary['total_hydro_kwh'] as num?)?.toDouble() ?? 0;
    final totalKwh = totalSolar + totalWind + totalHydro;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _pdfHeader('Senaryo Analiz Raporu', dateStr),
          pw.SizedBox(height: 16),
          _pdfSection('Senaryo Bilgileri', [
            ['Senaryo Adı', scenario.name],
            ['Açıklama', scenario.description ?? '-'],
            ['Rapor Tarihi', dateStr],
          ]),
          pw.SizedBox(height: 12),
          _pdfSection('Enerji Üretim Özeti', [
            ['Güneş', FormatUtils.formatEnergy(totalSolar)],
            ['Rüzgar', FormatUtils.formatEnergy(totalWind)],
            ['Hidroelektrik', FormatUtils.formatEnergy(totalHydro)],
            ['TOPLAM', FormatUtils.formatEnergy(totalKwh)],
          ]),
          pw.Spacer(),
          _pdfFooter(),
        ],
      ),
    );
  }

  pw.Page _buildRegionalPdfPage(RegionalReport? report, String dateStr) {
    final sites = report?.items ?? [];
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _pdfHeader('Bölgesel Potansiyel Raporu', dateStr),
          pw.SizedBox(height: 16),
          _pdfSection('Filtreler', [
            ['Bölge', _region],
            ['Kaynak Tipi', _type],
            ['Zaman Aralığı', _timeInterval],
            ['Rapor Tarihi', dateStr],
          ]),
          pw.SizedBox(height: 12),
          pw.Text('Lokasyon Listesi (İlk 25)',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (sites.isEmpty)
            pw.Text('Veri bulunamadı.',
                style: const pw.TextStyle(fontSize: 11))
          else
            pw.Table(
              border:
                  pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: ['Lokasyon', 'Puan', 'Değer']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold)),
                          ))
                      .toList(),
                ),
                ...sites.take(25).map((site) {
                  final loc = (site.district?.isNotEmpty ?? false)
                      ? '${site.district}, ${site.city}'
                      : site.city;
                  final val = (site.displayValue != null &&
                          site.displayUnit != null)
                      ? '${FormatUtils.formatDec1(site.displayValue!)} ${site.displayUnit}'
                      : FormatUtils.formatDec1(site.overallScore);
                  return pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(loc,
                            style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                            FormatUtils.formatDec1(site.overallScore),
                            style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(val,
                            style: const pw.TextStyle(fontSize: 9))),
                  ]);
                }),
              ],
            ),
          pw.Spacer(),
          _pdfFooter(),
        ],
      ),
    );
  }

  pw.Widget _pdfHeader(String title, String dateStr) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SRRP — Akıllı Yenilenebilir Kaynak Planlayıcısı',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Divider(color: PdfColors.blueGrey300),
        ],
      );

  pw.Widget _pdfSection(String title, List<List<String>> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...rows.map((row) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(children: [
                  pw.SizedBox(
                    width: 160,
                    child: pw.Text(row[0],
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                  ),
                  pw.Text(row[1],
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]),
              )),
        ],
      );

  pw.Widget _pdfFooter() => pw.Column(children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Text(
          'Bu rapor SRRP tarafından oluşturulmuştur.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
      ]);
}

// ── Türkiye istatistikleri accordion ────────────────────────────────────────

class _TurkeyAccordion extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _TurkeyAccordion({
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.flag_rounded,
                    color: Colors.redAccent, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'Türkiye Enerji İstatistikleri',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          const SizedBox(
            height: 260,
            child: TurkeyEnergyPanel(),
          ),
      ],
    );
  }
}

// ── Aktif il filtresi chip ───────────────────────────────────────────────────

class _ProvinceChip extends StatelessWidget {
  final String province;
  final VoidCallback onClear;

  const _ProvinceChip({required this.province, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClear,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.tealAccent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_city_rounded,
                size: 12, color: Colors.tealAccent),
            const SizedBox(width: 5),
            Text(
              province,
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.close_rounded,
                size: 12, color: Colors.tealAccent),
          ],
        ),
      ),
    );
  }
}

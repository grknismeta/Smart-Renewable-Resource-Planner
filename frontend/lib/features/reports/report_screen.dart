import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/shared/widgets/app_background.dart';
import 'package:frontend/shared/widgets/custom_app_bar.dart';
import 'package:frontend/shared/widgets/glass_container.dart';
import 'package:frontend/features/reports/widgets/report_list_panel.dart';
import 'package:frontend/features/reports/widgets/report_map.dart';
import 'package:frontend/features/reports/widgets/scenario_map.dart';
import 'package:frontend/features/reports/widgets/scenario_result_panel.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final MapController _mapController = MapController();
  String _region = 'Tümü';
  String _type = 'Wind';
  String _timeInterval = 'Yıllık'; // Varsayılan: Yıllık
  int? _selectedScenarioId; // Yeni: Seçili senaryo

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final rp = Provider.of<ReportViewModel>(context, listen: false);
      rp.fetchReport(region: _region, type: _type);
      // Senaryoları da yükle
      Provider.of<ScenarioViewModel>(context, listen: false).loadScenarios();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = Provider.of<ThemeViewModel>(context);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildHeader(themeViewModel),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 1100;
                      return Row(
                        children: [
                          Expanded(
                            flex: isWide ? 2 : 1,
                            child: GlassContainer(
                              child: _selectedScenarioId == null
                                  ? ReportMap(
                                      mapController: _mapController,
                                      type: _type,
                                      onSiteFocused: _onSiteFocused,
                                    )
                                  : ScenarioMapInReport(
                                      mapController: _mapController,
                                      scenarioId: _selectedScenarioId!,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: GlassContainer(
                              child: _selectedScenarioId == null
                                  ? ReportListPanel(
                                      onSiteSelected: _onSiteFocused,
                                    )
                                  : ScenarioResultPanel(
                                      scenarioId: _selectedScenarioId!,
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeViewModel theme) {
    final scenarioViewModel = Provider.of<ScenarioViewModel>(context);
    final scenarios = scenarioViewModel.scenarios;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomAppBar(
          title: 'Bölgesel Potansiyel Raporu',
          textColor: theme.textColor,
          onBack: () => Navigator.of(context).pushReplacementNamed('/map'),
          actions: [
            Tooltip(
              message: 'PDF olarak indir',
              child: _exportingPdf
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
                      onPressed: _exportPdf,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Yeni: Senaryo seçici
              if (scenarios.isNotEmpty) ...[
                _buildDropdown(
                  value: _selectedScenarioId?.toString() ?? 'Bölgesel',
                  items: ['Bölgesel', ...scenarios.map((s) => s.id.toString())],
                  displayBuilder: (val) {
                    if (val == 'Bölgesel') return 'Bölgesel Rapor';
                    // Check if scenario exists
                    try {
                      final sc = scenarios.firstWhere((s) => s.id.toString() == val);
                      return sc.name;
                    } catch (e) {
                      return 'Bilinmeyen Senaryo';
                    }
                  },
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      if (val == 'Bölgesel') {
                        _selectedScenarioId = null;
                        // Bölgesel raporu yükle
                        Provider.of<ReportViewModel>(
                          context,
                          listen: false,
                        ).fetchReport(region: _region, type: _type);
                      } else {
                        _selectedScenarioId = int.parse(val);
                        // Senaryo seçildi - rapor ekranı güncellenir
                      }
                    });
                  },
                ),
                const SizedBox(width: 12),
              ],
              // Yeni: Zaman Aralığı Seçici (Yıllık/Aylık/Anlık)
              _buildDropdown(
                value: _timeInterval,
                items: const ['Yıllık', 'Aylık', 'Anlık'],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _timeInterval = val);
                  
                  // ViewModel üzerinden veriyi güncelle
                  Provider.of<ReportViewModel>(
                    context,
                    listen: false,
                  ).fetchReport(region: _region, type: _type, interval: val);
                },
              ),
              const SizedBox(width: 12),
              _buildDropdown(
                value: _region,
                items: const [
                  'Tümü',
                  'Marmara',
                  'Ege',
                  'Akdeniz',
                  'İç Anadolu',
                  'Karadeniz',
                  'Doğu Anadolu',
                  'Güneydoğu Anadolu',
                ],
                onChanged: (val) {
                  if (val == null || _selectedScenarioId != null) return;
                  setState(() => _region = val);
                  Provider.of<ReportViewModel>(
                    context,
                    listen: false,
                  ).fetchReport(region: val, type: _type);
                },
              ),
              const SizedBox(width: 12),
              _buildDropdown(
                value: _type,
                items: const ['Wind', 'Solar'],
                onChanged: (val) {
                  if (val == null || _selectedScenarioId != null) return;
                  setState(() => _type = val);
                  Provider.of<ReportViewModel>(
                    context,
                    listen: false,
                  ).fetchReport(region: _region, type: val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButton<String>(
        value: value,
        dropdownColor: const Color(0xFF1C2533),
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        style: const TextStyle(color: Colors.white),
        onChanged: onChanged,
        items: items
            .map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(displayBuilder != null ? displayBuilder(e) : e),
              ),
            )
            .toList(),
      ),
    );
  }

  void _onSiteFocused(RegionalSite site) {
    _mapController.move(LatLng(site.latitude, site.longitude), 8.0);
  }

  // -----------------------------------------------------------------------
  // PDF EXPORT
  // -----------------------------------------------------------------------

  bool _exportingPdf = false;

  Future<void> _exportPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);

    try {
      final pdf = pw.Document();
      final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.now());

      if (_selectedScenarioId != null) {
        // --- SENARYO RAPORU ---
        final vm = Provider.of<ScenarioViewModel>(context, listen: false);
        final scenario = vm.scenarios.firstWhere(
          (s) => s.id == _selectedScenarioId,
          orElse: () => vm.scenarios.first,
        );
        pdf.addPage(_buildScenarioPdfPage(scenario, dateStr));
      } else {
        // --- BÖLGESEL RAPOR ---
        final rp = Provider.of<ReportViewModel>(context, listen: false);
        final report = rp.report;
        pdf.addPage(_buildRegionalPdfPage(report, dateStr));
      }

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'SRRP_Rapor_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulamadı: $e'), backgroundColor: Colors.red),
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
      build: (ctx) => pw.Column(
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
            ['Güneş Enerjisi', FormatUtils.formatEnergy(totalSolar)],
            ['Rüzgar Enerjisi', FormatUtils.formatEnergy(totalWind)],
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
      build: (ctx) => pw.Column(
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
          pw.Text('Lokasyon Listesi (İlk 25)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (sites.isEmpty)
            pw.Text('Veri bulunamadı.', style: const pw.TextStyle(fontSize: 11))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: ['Lokasyon', 'Puan', 'Rüzgar / Işınım']
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
                  final metric = site.avgWindSpeedMs != null
                      ? '${FormatUtils.formatDec1(site.avgWindSpeedMs!)} m/s'
                      : site.annualSolarIrradianceKwhM2 != null
                          ? '${FormatUtils.formatDec1(site.annualSolarIrradianceKwhM2!)} kWh/m²'
                          : '-';
                  return pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(loc, style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(FormatUtils.formatDec1(site.overallScore), style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(metric, style: const pw.TextStyle(fontSize: 9))),
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
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Divider(color: PdfColors.blueGrey300),
        ],
      );

  pw.Widget _pdfSection(String title, List<List<String>> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
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
          'Bu rapor SRRP (Smart Renewable Resource Planner) tarafından oluşturulmuştur.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
      ]);
}

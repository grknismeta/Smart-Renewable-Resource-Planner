// lib/features/reports/widgets/tabs/export_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/format_utils.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

/// Tab 6 — PDF Export
/// 4 export tipi kartı + içerik seçimi + export butonu
class ExportTab extends StatefulWidget {
  const ExportTab({super.key});

  @override
  State<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<ExportTab> {
  _ExportType _selectedType = _ExportType.executive;
  bool _exporting = false;

  // İçerik seçenekleri
  bool _inclKpi = true;
  bool _inclSites = true;
  bool _inclProvince = true;
  bool _inclScenario = false;
  bool _inclMap = false;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeViewModel>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Rapor Türü ────────────────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.description_outlined,
            title: 'Rapor Türü',
          ),
          const SizedBox(height: 10),
          _ExportTypeGrid(
            selected: _selectedType,
            onChanged: (t) => setState(() => _selectedType = t),
          ),
          const SizedBox(height: 20),

          // ── İçerik Seçimi ─────────────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.checklist_rounded,
            title: 'İçerik Seçimi',
          ),
          const SizedBox(height: 10),
          _ContentCheckboxes(
            inclKpi: _inclKpi,
            inclSites: _inclSites,
            inclProvince: _inclProvince,
            inclScenario: _inclScenario,
            inclMap: _inclMap,
            onKpi: (v) => setState(() => _inclKpi = v ?? true),
            onSites: (v) => setState(() => _inclSites = v ?? true),
            onProvince: (v) => setState(() => _inclProvince = v ?? true),
            onScenario: (v) => setState(() => _inclScenario = v ?? false),
            onMap: (v) => setState(() => _inclMap = v ?? false),
          ),
          const SizedBox(height: 24),

          // ── Export Butonu ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _exporting ? null : _doExport,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(
                _exporting ? 'Oluşturuluyor...' : 'PDF İndir',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'PDF dosyası cihazınıza indirilecek veya paylaşım menüsü açılacak.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _doExport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final pdf = pw.Document();
      final reportVM =
          Provider.of<ReportViewModel>(context, listen: false);
      final scenVM =
          Provider.of<ScenarioViewModel>(context, listen: false);
      final dateStr =
          DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.now());

      pdf.addPage(_buildPage(reportVM, scenVM, dateStr));

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'SRRP_${_selectedType.filename}_${DateTime.now().millisecondsSinceEpoch}.pdf',
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
      if (mounted) setState(() => _exporting = false);
    }
  }

  pw.Page _buildPage(
      ReportViewModel reportVM, ScenarioViewModel scenVM, String dateStr) {
    final report = reportVM.report;
    final sites = report?.items ?? [];

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Text(
            'SRRP — Akıllı Yenilenebilir Kaynak Planlayıcısı',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _selectedType.title,
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(color: PdfColors.blueGrey300),
          pw.SizedBox(height: 12),

          // Tarih + Filtreler
          pw.Text('Rapor Tarihi: $dateStr',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
              'Bölge: ${reportVM.selectedRegion}  |  Kaynak: ${reportVM.selectedType}',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),

          // KPI Özeti
          if (_inclKpi && report != null) ...[
            pw.Text('Özet İstatistikler',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(
                'Toplam Lokasyon: ${report.items.length}  |  Ort. Skor: '
                '${report.items.isNotEmpty ? (report.items.fold(0.0, (s, i) => s + i.overallScore) / report.items.length).toStringAsFixed(1) : "-"}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
          ],

          // Lokasyon Listesi
          if (_inclSites && sites.isNotEmpty) ...[
            pw.Text('Lokasyon Listesi (İlk 20)',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey800),
                  children: ['Lokasyon', 'Puan', 'Değer']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ))
                      .toList(),
                ),
                ...sites.take(20).map((site) {
                  final loc = (site.district?.isNotEmpty ?? false)
                      ? '${site.district}, ${site.city}'
                      : site.city;
                  final val =
                      (site.displayValue != null && site.displayUnit != null)
                          ? '${FormatUtils.formatDec1(site.displayValue!)} ${site.displayUnit}'
                          : FormatUtils.formatDec1(site.overallScore);
                  return pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(loc,
                            style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                            FormatUtils.formatDec1(site.overallScore),
                            style:
                                const pw.TextStyle(fontSize: 9))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(val,
                            style: const pw.TextStyle(fontSize: 9))),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 12),
          ],

          // Senaryo
          if (_inclScenario && scenVM.scenarios.isNotEmpty) ...[
            pw.Text('Senaryo Listesi',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...scenVM.scenarios.take(10).map((s) {
              final total = _totalKwh(s.resultData ?? {});
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text(
                    '${s.name}: ${FormatUtils.formatEnergy(total)} toplam',
                    style: const pw.TextStyle(fontSize: 10)),
              );
            }),
            pw.SizedBox(height: 12),
          ],

          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'Bu rapor SRRP — Akıllı Yenilenebilir Kaynak Planlayıcısı tarafından oluşturulmuştur.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  static double _totalKwh(Map<String, dynamic> d) {
    return ((d['total_solar_kwh'] as num?)?.toDouble() ?? 0) +
        ((d['total_wind_kwh'] as num?)?.toDouble() ?? 0) +
        ((d['total_hydro_kwh'] as num?)?.toDouble() ?? 0);
  }
}

// ── Export Type Grid ──────────────────────────────────────────────────────────

enum _ExportType {
  executive('Yönetici Özeti', Icons.business_center_rounded, 'Yonetici_Ozeti',
      'Üst yönetim için kısa ve öz sunum formatı'),
  technical('Teknik Rapor', Icons.engineering_rounded, 'Teknik_Rapor',
      'Detaylı teknik analiz ve metrikler'),
  province('İl Bazında', Icons.map_rounded, 'Il_Bazli',
      'İl bazında potansiyel karşılaştırması'),
  scenario('Senaryo Analizi', Icons.compare_arrows_rounded, 'Senaryo_Analizi',
      'Senaryo karşılaştırmalı çıktı');

  final String title;
  final IconData icon;
  final String filename;
  final String description;

  const _ExportType(
      this.title, this.icon, this.filename, this.description);
}

class _ExportTypeGrid extends StatelessWidget {
  final _ExportType selected;
  final ValueChanged<_ExportType> onChanged;

  const _ExportTypeGrid(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: _ExportType.values
          .map((t) => _TypeCard(
                type: t,
                isSelected: t == selected,
                onTap: () => onChanged(t),
              ))
          .toList(),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final _ExportType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard(
      {required this.type,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.redAccent : Colors.white24;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.redAccent.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.redAccent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(type.icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    type.title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    type.description,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 9),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Content Checkboxes ────────────────────────────────────────────────────────

class _ContentCheckboxes extends StatelessWidget {
  final bool inclKpi, inclSites, inclProvince, inclScenario, inclMap;
  final ValueChanged<bool?> onKpi, onSites, onProvince, onScenario, onMap;

  const _ContentCheckboxes({
    required this.inclKpi,
    required this.inclSites,
    required this.inclProvince,
    required this.inclScenario,
    required this.inclMap,
    required this.onKpi,
    required this.onSites,
    required this.onProvince,
    required this.onScenario,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _CheckItem('KPI ve Özet İstatistikler', inclKpi, onKpi,
          Icons.analytics_rounded),
      _CheckItem('Lokasyon Listesi (İlk 20)', inclSites, onSites,
          Icons.place_rounded),
      _CheckItem('İl Bazında Özet', inclProvince, onProvince,
          Icons.location_city_rounded),
      _CheckItem('Senaryo Listesi', inclScenario, onScenario,
          Icons.compare_arrows_rounded),
      _CheckItem('Harita Görseli (yakında)', inclMap, onMap,
          Icons.map_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: items
            .map((i) => _CheckRow(item: i))
            .toList(),
      ),
    );
  }
}

class _CheckItem {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final IconData icon;

  const _CheckItem(this.label, this.value, this.onChanged, this.icon);
}

class _CheckRow extends StatelessWidget {
  final _CheckItem item;
  const _CheckRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => item.onChanged(!item.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Checkbox(
              value: item.value,
              onChanged: item.onChanged,
              activeColor: Colors.redAccent,
              checkColor: Colors.white,
              side:
                  const BorderSide(color: Colors.white38, width: 1.5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Icon(item.icon, size: 14, color: Colors.white38),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white54),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

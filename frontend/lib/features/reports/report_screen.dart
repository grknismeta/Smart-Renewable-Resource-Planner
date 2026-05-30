// lib/features/reports/report_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';
import 'package:frontend/features/reports/viewmodels/report_nav_controller.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/features/reports/widgets/tabs/landing_tab.dart';
import 'package:frontend/features/reports/widgets/tabs/region_tab.dart';
import 'package:frontend/features/reports/widgets/tabs/province_drill_tab.dart';
import 'package:frontend/features/reports/widgets/tabs/scenario_compare_tab.dart';
import 'package:frontend/features/reports/widgets/tabs/santral_tab.dart';
import 'package:frontend/features/reports/widgets/tabs/projection_tab.dart';
import 'package:frontend/features/reports/widgets/tabs/export_tab.dart';
import 'package:frontend/shared/widgets/app_background.dart';

/// 2026-05-08 Madde 4: Raporlar ekranına animasyonlu geçiş için custom route.
/// Slide-up + fade kombo — kullanıcı "buton bastım → rapor yukarı kayarak
/// geldi" hissi alır. Default `MaterialPageRoute` sağdan kayan platform-default
/// pattern; rapor için daha "dashboard'tan ekran açılıyor" hissi vermek için
/// slide-up tercih edildi (Google Maps "Place card" pattern).
Route<T> createReportRoute<T>({
  String? initialProvince,
  int? initialScenarioId,
  int? initialPinId,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => ReportScreen(
      initialProvince: initialProvince,
      initialScenarioId: initialScenarioId,
      initialPinId: initialPinId,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Raporlar ekranı — Sprint R1 v3 (Landing-first hiyerarşi)
///
/// 6 tab (v3 mockup'a uyum, eski "Trend" ve "Harita" tab'ları kaldırıldı —
/// Trend Landing'in 10-yıl grafiğine, Harita ise Landing/Bölge/İl haritalarına
/// eridi):
///
///   0 Landing  1 Bölge  2 İl Analizi  3 Senaryo  4 Santral  5 Export
///
/// Hiyerarşi: Türkiye → Bölge (7 coğrafi) → İl → İlçe → Pin
/// Senaryo: senaryo-driven gösterim (pin seçimi, üretim, maliyet, hava)
/// Santral: Pin Extended raporu (production timeline, type deep-dive, TR finans)
class ReportScreen extends StatefulWidget {
  /// Haritadan doğrudan bir il seçilerek açıldığında ön yükleme için.
  final String? initialProvince;

  /// Senaryo panelinden açıldığında ilgili senaryo otomatik seçilsin diye.
  /// null ise normal akış (default tab: 0).
  final int? initialScenarioId;

  /// Pin detail dialog'undan "Detaylı Rapor" ile açıldığında — Santral
  /// tab'ı (4) açılır, bu pin otomatik seçilir.
  final int? initialPinId;

  const ReportScreen({
    super.key,
    this.initialProvince,
    this.initialScenarioId,
    this.initialPinId,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const int _kTabCount = 7;

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
    return ChangeNotifierProvider(
      create: (_) => ReportNavController(),
      child: DefaultTabController(
        length: _kTabCount,
        // v3 sıralaması: Landing(0) / Bölge(1) / İl(2) / Senaryo(3) / Santral(4) / Export(5)
        // - Pin "Detaylı Rapor" ile açıldıysa → Santral (4)
        // - Senaryo panelinden açıldıysa → Senaryo (3)
        // - Haritadan il seçilerek açıldıysa → İl Analizi (2)
        // - Default → Landing (0)
        initialIndex: widget.initialPinId != null
            ? 4
            : widget.initialScenarioId != null
                ? 3
                : (widget.initialProvince != null ? 2 : 0),
        child: Scaffold(
          body: AppBackground(
            child: SafeArea(
              child: Column(
                children: [
                  const _AppBar(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        const LandingTab(),
                        const RegionTab(),
                        ProvinceDrillTab(initialProvince: widget.initialProvince),
                        ScenarioCompareTab(
                            initialScenarioId: widget.initialScenarioId),
                        SantralTab(initialPinId: widget.initialPinId),
                        ProjectionTab(
                          initialPinId: widget.initialPinId,
                          initialProvince: widget.initialProvince,
                        ),
                        const ExportTab(),
                      ],
                    ),
                  ),
                ],
              ),
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
          // 2026-05-25 (F1 rework): Yıllık/Aylık/Özel TimeRangeSelector kaldırıldı.
          // Çoğu tab'da hiçbir etkisi yoktu (ölü kontrol). Yerine her tab kendi
          // içinde ihtiyacı olan range chip'lerini gösteriyor (F2).
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
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
                  icon: Icon(Icons.public_rounded, size: 15),
                  text: 'Genel Bakış',
                ),
                Tab(
                  icon: Icon(Icons.layers_rounded, size: 15),
                  text: 'Bölge',
                ),
                Tab(
                  icon: Icon(Icons.location_city_rounded, size: 15),
                  text: 'İl Analizi',
                ),
                Tab(
                  icon: Icon(Icons.compare_arrows_rounded, size: 15),
                  text: 'Senaryo',
                ),
                Tab(
                  icon: Icon(Icons.factory_rounded, size: 15),
                  text: 'Santral',
                ),
                Tab(
                  icon: Icon(Icons.auto_graph_rounded, size: 15),
                  text: 'Projeksiyon',
                ),
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

// NOT: Eski `_TimeRangeSelector`/`_ModeChip`/`_SmallDropdown` (Yıllık/Aylık/Özel
// AppBar toggle'ı) 2026-05-25 F1 rework'te silindi — ölü kontrol idi. Range
// seçimi artık her tab'ın kendi içinde (Senaryo: ufuk yılı, İl Analizi: 12/24/36
// ay, Santral: 7G/30G/12A) yapılıyor. ReportViewModel'daki state alanları
// (dateRangeMode/selectedYear/customRange…) geriye dönük uyumluluk için duruyor
// — başka bir tüketici varsa diye dokunulmadı.

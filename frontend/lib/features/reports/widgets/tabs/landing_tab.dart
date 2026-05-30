// lib/features/reports/widgets/tabs/landing_tab.dart
//
// LANDING TAB — Sprint R1 (v3 mockup'a uygun)
//
// İçerik (yukarıdan aşağıya):
//   1. HERO: 4 KPI (toplam kurulu, yenilenebilir pay, yıllık üretim, CO₂)
//   2. Kaynak dağılım mix bar (Hidro/Güneş/Rüzgar/Diğer)
//   3. Resource filter chips (Tümü/Güneş/Rüzgar/Hidro) — top liste filtresi
//   4. 7 bölge kartı grid (Marmara, Ege, Akdeniz, ...)
//   5. Top 10 il listesi (climatology score barlı)
//   6. 10-yıl kurulu güç trendi (sparkline)
//   7. Potansiyel vs gerçekleşen 3 kolon (GES/RES/HES)
//
// Veri kaynağı: GET /analysis/landing → LandingData
//
// Mockup ref: designhtml/reports-landing.jsx
// Veri: backend/data/tr_stats.json (TEİAŞ 2024) + climatology

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/reports/viewmodels/landing_viewmodel.dart';
import 'package:frontend/features/reports/viewmodels/report_nav_controller.dart';

class LandingTab extends StatelessWidget {
  const LandingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          LandingViewModel(Provider.of<ApiService>(ctx, listen: false))..init(),
      child: const _LandingBody(),
    );
  }
}

class _LandingBody extends StatelessWidget {
  const _LandingBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LandingViewModel>();

    if (vm.isBusy && vm.data == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
      );
    }
    if (vm.hasError && vm.data == null) {
      return _ErrorView(
        message: vm.errorMessage ?? 'Yüklenemedi',
        onRetry: () => vm.refresh(),
      );
    }
    final data = vm.data;
    if (data == null) {
      return const Center(child: Text('Veri yok', style: TextStyle(color: Colors.white54)));
    }

    // 2026-05-25 (F3): Çok geniş ekranda (ör 1920px) içerik ekranı dolduruyor
    // → kartlar şişiyor, "boş büyük" hissi. maxWidth 1400 cap + ortalama.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1-2. HERO + Mix bar
          _HeroSection(stats: data.trStats),
          const SizedBox(height: 22),

          // 3-4. Filter chips + bölge kartları
          _SectionHeader(
            title: 'Coğrafi Bölgeler',
            subtitle: '7 bölge · Bölge → İl → İlçe hiyerarşisi',
            trailing: _ResourceFilterChips(
              active: vm.resourceFilter,
              onChange: vm.setResourceFilter,
            ),
          ),
          const SizedBox(height: 12),
          _RegionGrid(regions: data.regions, filter: vm.resourceFilter),
          const SizedBox(height: 24),

          // 5-6. Top 10 + Trend (geniş ekranda yan yana, dar tek sütun)
          LayoutBuilder(
            builder: (ctx, c) {
              final wide = c.maxWidth >= 760;
              final top = _TopProvincesCard(
                items: vm.filteredTop,
                filter: vm.resourceFilter,
              );
              final trend = _TrendChartCard(trend: data.trStats.capacityTrend);
              if (wide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: top),
                      const SizedBox(width: 12),
                      Expanded(child: trend),
                    ],
                  ),
                );
              }
              return Column(children: [top, const SizedBox(height: 12), trend]);
            },
          ),
          const SizedBox(height: 24),

          // 7. Potential vs Actual
          _PotentialVsActual(stats: data.trStats),
          const SizedBox(height: 24),

          _Footer(stats: data.trStats),
        ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final TrStats stats;
  const _HeroSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.cyanAccent.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.25)),
      ),
      child: LayoutBuilder(
        builder: (ctx, c) {
          // 4 KPI grid — geniş ekranda 4 kolon, dar 2 kolon
          // 2026-05-25 (F3): Çok geniş ekranda (≥1400) kartlar devasa boş alan
          // yaratıyordu; aspectRatio'yu yükseltip kartları kısaltıyoruz.
          final crossCount = c.maxWidth < 600 ? 2 : 4;
          double aspect;
          if (c.maxWidth < 600) {
            aspect = 1.7;
          } else if (c.maxWidth >= 1400) {
            aspect = 2.4; // çok geniş — kart bas
          } else if (c.maxWidth >= 1000) {
            aspect = 2.0;
          } else {
            aspect = 1.5;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CANLI · TEİAŞ + EPDK',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Türkiye Yenilenebilir Enerji Potansiyeli',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: aspect,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _KpiCard(
                    label: 'Toplam Kurulu Güç',
                    value: (stats.totalInstalledMw / 1000).toStringAsFixed(1),
                    unit: 'GW',
                    color: Colors.cyanAccent,
                    sub: 'Yenil. pay: %${(stats.renewableShare * 100).toStringAsFixed(1)}',
                  ),
                  _KpiCard(
                    label: 'Yenilenebilir Kurulu',
                    value: (stats.renewableMw / 1000).toStringAsFixed(1),
                    unit: 'GW',
                    color: const Color(0xFF10B981),
                    sub: '${(stats.target2035RenewableShare * 100).toStringAsFixed(0)}% hedef 2035',
                  ),
                  _KpiCard(
                    label: 'Yıllık Üretim',
                    value: (stats.annualProductionGwh / 1000).toStringAsFixed(0),
                    unit: 'TWh',
                    color: const Color(0xFFF59E0B),
                    sub: 'Yenil.: ${(stats.renewableProductionGwh / 1000).toStringAsFixed(0)} TWh',
                  ),
                  _KpiCard(
                    label: 'CO₂ Önlemesi',
                    value: (stats.co2AvoidedKtPerYear / 1000).toStringAsFixed(0),
                    unit: 'Mt/yıl',
                    color: const Color(0xFF34D399),
                    sub: '≈12.5M araç eşdeğeri',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MixBar(stats: stats),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final String sub;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 10,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Yenilenebilir kaynak dağılımı — donut (pasta) grafiği + legend.
class _MixBar extends StatelessWidget {
  final TrStats stats;
  const _MixBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final segments = <(String, int, Color)>[
      ('Hidro', stats.hydroMw, const Color(0xFF06B6D4)),
      ('Güneş', stats.solarMw, const Color(0xFFF59E0B)),
      ('Rüzgar', stats.windMw, const Color(0xFF3B82F6)),
      ('Jeo.+Biyo.', stats.geothermalMw + stats.biomassMw,
          const Color(0xFFA855F7)),
    ];
    final total = segments.fold<int>(0, (s, e) => s + e.$2);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YENİLENEBİLİR KAYNAK DAĞILIMI',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Donut pasta grafiği
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: [for (final s in segments) (s.$2.toDouble(), s.$3)],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (total / 1000).toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'GW',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: segments.map((s) {
                    final pct = total > 0 ? (s.$2 / total * 100) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s.$3,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.$1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${(s.$2 / 1000).toStringAsFixed(1)} GW',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '%${pct.toStringAsFixed(0)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: s.$3,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Donut (halka) pasta grafiği painter.
class _DonutPainter extends CustomPainter {
  final List<(double, Color)> segments;
  _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, e) => s + e.$1);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 18.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    var startAngle = -math.pi / 2; // tepeden başla
    const gap = 0.04; // segmentler arası küçük boşluk
    for (final seg in segments) {
      if (seg.$1 <= 0) continue;
      final sweep = (seg.$1 / total) * (2 * math.pi) - gap;
      canvas.drawArc(
        rect,
        startAngle + gap / 2,
        sweep,
        false,
        Paint()
          ..color = seg.$2
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt
          ..style = PaintingStyle.stroke,
      );
      startAngle += (seg.$1 / total) * (2 * math.pi);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.segments != segments;
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER + RESOURCE FILTER CHIPS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ResourceFilterChips extends StatelessWidget {
  final String active;
  final ValueChanged<String> onChange;
  const _ResourceFilterChips({required this.active, required this.onChange});

  static const _items = [
    ('all', 'Tümü', Colors.white),
    ('solar', 'Güneş', Color(0xFFF59E0B)),
    ('wind', 'Rüzgar', Color(0xFF3B82F6)),
    ('hydro', 'Hidro', Color(0xFF06B6D4)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _items.map((it) {
          final isActive = active == it.$1;
          return GestureDetector(
            onTap: () => onChange(it.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? it.$3.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (it.$1 != 'all')
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: it.$3,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  Text(
                    it.$2,
                    style: TextStyle(
                      color: isActive ? it.$3 : Colors.white60,
                      fontSize: 10.5,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGION GRID
// ─────────────────────────────────────────────────────────────────────────────

class _RegionGrid extends StatelessWidget {
  final List<RegionMeta> regions;
  final String filter;
  const _RegionGrid({required this.regions, required this.filter});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        // 2026-05-25 (Fix2): Mobile'da aspect 1.5 → içerik yüksekliği yetmiyor,
        // RegionCard'ın description + miniScore satırı pixel overflow yapıyordu.
        // Geniş ekranda kart yatay; mobile'da kareye yakın.
        final cross = c.maxWidth >= 1000
            ? 4
            : c.maxWidth >= 640
                ? 3
                : 2;
        double aspect;
        if (c.maxWidth >= 1000) {
          aspect = 1.55;
        } else if (c.maxWidth >= 640) {
          aspect = 1.35;
        } else {
          // 393dp ekranda 2 kart × ~190dp / 0.9 = ~210dp yükseklik — sığar.
          aspect = 0.9;
        }
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspect,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: regions.map((r) => _RegionCard(region: r, filter: filter)).toList(),
        );
      },
    );
  }
}

class _RegionCard extends StatelessWidget {
  final RegionMeta region;
  final String filter;
  const _RegionCard({required this.region, required this.filter});

  Color get _color {
    final hex = region.color.replaceAll('#', '');
    return Color(int.parse('ff$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    // Filter aktif ise bölge bu kaynakta lider değilse soluk göster
    final dim = filter != 'all' && region.topResource != filter;

    return Opacity(
      opacity: dim ? 0.40 : 1.0,
      child: GestureDetector(
        onTap: () {
          // Bölge tab'ına geç + bu bölgeyi seç
          context.read<ReportNavController>().requestRegion(region.id);
          DefaultTabController.of(context).animateTo(1);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: dim
                  ? Colors.white.withValues(alpha: 0.08)
                  : _color.withValues(alpha: 0.22),
            ),
          ),
          child: Stack(
            children: [
              // Sol renk şeridi
              Positioned(
                left: -6,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık + lider rozet
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          region.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      _ResourceBadge(type: region.topResource),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Meta — il / kapasite / üretim. 2026-05-25 (Fix2): Wrap ile
                  // dar ekranda taşma yerine alt satıra geç.
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _metaItem(Icons.location_city_rounded,
                          '${region.provincesCount} il'),
                      _metaItem(Icons.bolt_rounded,
                          '${(region.capacityMw / 1000).toStringAsFixed(1)} GW'),
                      _metaItem(Icons.trending_up_rounded,
                          '${(region.annualGwh / 1000).toStringAsFixed(1)} TWh'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Açıklama
                  Text(
                    region.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 11,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.07),
                    height: 14,
                  ),
                  // 3 kaynak climatology skoru mini-bar
                  Row(
                    children: [
                      _miniScore('Güneş', region.avgScores['solar'],
                          const Color(0xFFF59E0B), filter == 'solar'),
                      const SizedBox(width: 5),
                      _miniScore('Rüzgar', region.avgScores['wind'],
                          const Color(0xFF3B82F6), filter == 'wind'),
                      const SizedBox(width: 5),
                      _miniScore('Hidro', region.avgScores['hydro'],
                          const Color(0xFF06B6D4), filter == 'hydro'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.40)),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// Bir kaynak için climatology skoru mini-bar (label + bar + değer).
  /// 2026-05-25 (H2): Eski Row(label+Spacer+value) + bar Column'u dar kartta
  /// taşıyordu (3 score Expanded yan yana, kart yüksekliği yetmiyor →
  /// dikey overflow). Yeni: kompakt rozet — ikon + sayı, tek satır.
  /// Bar kaldırıldı (görsel olarak sayı + renk yeterli vurguyu veriyor).
  Widget _miniScore(String label, double? value, Color color, bool highlight) {
    final v = value ?? 0;
    final hasData = value != null && value > 0;
    final icon = switch (label.toLowerCase()) {
      'güneş' => Icons.wb_sunny_rounded,
      'rüzgar' => Icons.air_rounded,
      'hidro' => Icons.water_drop_rounded,
      _ => Icons.circle,
    };
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: highlight
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: highlight
                ? color.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: hasData ? color : Colors.white24,
            ),
            const SizedBox(width: 3),
            Text(
              hasData ? v.toStringAsFixed(0) : '—',
              style: TextStyle(
                color: hasData ? color : Colors.white24,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceBadge extends StatelessWidget {
  final String type;
  const _ResourceBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (type) {
      'solar' => ('Güneş', const Color(0xFFF59E0B), Icons.wb_sunny_rounded),
      'wind' => ('Rüzgar', const Color(0xFF3B82F6), Icons.air_rounded),
      'hydro' => ('Hidro', const Color(0xFF06B6D4), Icons.water_drop_rounded),
      _ => ('?', Colors.white54, Icons.help_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 9),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP 10 PROVINCES
// ─────────────────────────────────────────────────────────────────────────────

class _TopProvincesCard extends StatelessWidget {
  final List<dynamic> items; // OverallTopItem ya da TopProvinceItem
  final String filter;
  const _TopProvincesCard({required this.items, required this.filter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2026-05-25 (Fix): Dar ekranda başlık + uzun filter text
          // ("Tüm kaynaklar (en yüksek skor)") taşıyordu — Flexible + ellipsis.
          Row(
            children: [
              const Text(
                'En Verimli 10 İl',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  filter == 'all'
                      ? 'Tüm kaynaklar (en yüksek skor)'
                      : 'Filtre: ${_labelFor(filter)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Bu filtreye uygun kayıt yok.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            ...items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final name = item is OverallTopItem
                  ? item.provinceName
                  : (item as TopProvinceItem).provinceName;
              final score = item is OverallTopItem ? item.score : (item as TopProvinceItem).score;
              final res = item is OverallTopItem ? item.topResource : filter;
              return _TopProvinceRow(rank: i + 1, name: name, score: score, resource: res);
            }),
        ],
      ),
    );
  }

  String _labelFor(String r) => switch (r) {
        'solar' => 'Güneş',
        'wind' => 'Rüzgar',
        'hydro' => 'Hidro',
        _ => r,
      };
}

class _TopProvinceRow extends StatelessWidget {
  final int rank;
  final String name;
  final double score;
  final String resource;

  const _TopProvinceRow({
    required this.rank,
    required this.name,
    required this.score,
    required this.resource,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (resource) {
      'solar' => const Color(0xFFF59E0B),
      'wind' => const Color(0xFF3B82F6),
      'hydro' => const Color(0xFF06B6D4),
      _ => Colors.cyanAccent,
    };
    final topThree = rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: topThree
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: topThree ? 0.10 : 0.05),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: topThree ? color : Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _ResourceBadge(type: resource),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Stack(
              children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (score / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            child: Text(
              score.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TREND CHART (10-yıl)
// ─────────────────────────────────────────────────────────────────────────────

class _TrendChartCard extends StatelessWidget {
  final List<LandingTrendPoint> trend;
  const _TrendChartCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '10 Yıllık Kurulu Güç Trendi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _LegendDot(color: Colors.white70, label: 'Toplam', dashed: true),
              const SizedBox(width: 12),
              _LegendDot(color: Colors.cyanAccent, label: 'Yenilenebilir'),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 2.2,
            child: CustomPaint(painter: _TrendPainter(trend: trend)),
          ),
          const SizedBox(height: 10),
          if (trend.length >= 2) ...[
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TrendSummaryItem(
                    label: '10 yıl artış',
                    value:
                        '+%${((trend.last.renewable / trend.first.renewable - 1) * 100).toStringAsFixed(0)}',
                    color: Colors.cyanAccent,
                  ),
                ),
                Expanded(
                  child: _TrendSummaryItem(
                    label: 'Yıllık ort.',
                    value:
                        '+%${(((trend.last.renewable / trend.first.renewable) - 1) * 100 / (trend.length - 1)).toStringAsFixed(1)}',
                    color: Colors.white70,
                  ),
                ),
                Expanded(
                  child: _TrendSummaryItem(
                    label: '2024 yenil.',
                    value: '${trend.last.renewable.toStringAsFixed(1)} GW',
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: dashed ? 0 : 2.5,
          decoration: BoxDecoration(
            color: dashed ? null : color,
            border: dashed
                ? Border(top: BorderSide(color: color, style: BorderStyle.solid, width: 1.4))
                : null,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TrendSummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TrendSummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<LandingTrendPoint> trend;
  _TrendPainter({required this.trend});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.length < 2) return;

    const padL = 28.0, padR = 8.0, padT = 8.0, padB = 22.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    final maxV = trend.map((t) => t.total).reduce((a, b) => a > b ? a : b) * 1.05;
    final xStep = w / (trend.length - 1);
    double xFor(int i) => padL + i * xStep;
    double yFor(double v) => padT + h - (v / maxV) * h;

    // Grid lines (her 30 GW)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.40),
      fontSize: 8,
    );
    for (var v = 0.0; v <= maxV; v += 30) {
      final y = yFor(v);
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
      _drawText(canvas, '${v.toInt()}', Offset(padL - 4, y - 5),
          labelStyle, align: TextAlign.right, maxWidth: 22);
    }

    // Renewable area + line
    final renPath = Path();
    final areaPath = Path();
    for (var i = 0; i < trend.length; i++) {
      final x = xFor(i);
      final y = yFor(trend[i].renewable);
      if (i == 0) {
        renPath.moveTo(x, y);
        areaPath.moveTo(x, padT + h);
        areaPath.lineTo(x, y);
      } else {
        renPath.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
    }
    areaPath.lineTo(xFor(trend.length - 1), padT + h);
    areaPath.close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.cyanAccent.withValues(alpha: 0.35),
            Colors.cyanAccent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      renPath,
      Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Total dashed line
    _drawDashed(
      canvas,
      [
        for (var i = 0; i < trend.length; i++)
          Offset(xFor(i), yFor(trend[i].total))
      ],
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    // Son nokta etiketi
    final last = trend.last;
    canvas.drawCircle(
      Offset(xFor(trend.length - 1), yFor(last.renewable)),
      3.5,
      Paint()..color = Colors.cyanAccent,
    );

    // X labels (her 2 yılda bir)
    for (var i = 0; i < trend.length; i++) {
      if (i % 2 != 0 && i != trend.length - 1) continue;
      _drawText(
        canvas,
        '${trend[i].year}',
        Offset(xFor(i), size.height - padB + 4),
        labelStyle.copyWith(fontSize: 9),
        align: TextAlign.center,
        maxWidth: 30,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos,
    TextStyle style, {
    TextAlign align = TextAlign.left,
    double maxWidth = 100,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    final dx = switch (align) {
      TextAlign.center => pos.dx - tp.width / 2,
      TextAlign.right => pos.dx - tp.width,
      _ => pos.dx,
    };
    tp.paint(canvas, Offset(dx, pos.dy));
  }

  void _drawDashed(Canvas canvas, List<Offset> points, Paint paint) {
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      const dashLen = 4.0, gapLen = 3.0;
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final segLen = math.sqrt(dx * dx + dy * dy);
      if (segLen <= 0) continue;
      final ux = dx / segLen, uy = dy / segLen;
      var travelled = 0.0;
      var draw = true;
      while (travelled < segLen) {
        final step = draw ? dashLen : gapLen;
        final from = Offset(p1.dx + ux * travelled, p1.dy + uy * travelled);
        final toLen = (travelled + step).clamp(0.0, segLen);
        final to = Offset(p1.dx + ux * toLen, p1.dy + uy * toLen);
        if (draw) canvas.drawLine(from, to, paint);
        travelled += step;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.trend != trend;
}

// ─────────────────────────────────────────────────────────────────────────────
// POTENTIAL VS ACTUAL
// ─────────────────────────────────────────────────────────────────────────────

class _PotentialVsActual extends StatelessWidget {
  final TrStats stats;
  const _PotentialVsActual({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Güneş',
        stats.solarMw,
        stats.solarPotentialMw,
        const Color(0xFFF59E0B),
        Icons.wb_sunny_rounded,
      ),
      (
        'Rüzgar',
        stats.windMw,
        stats.windPotentialMw,
        const Color(0xFF3B82F6),
        Icons.air_rounded,
      ),
      (
        'Hidro',
        stats.hydroMw,
        stats.hydroPotentialMw,
        const Color(0xFF06B6D4),
        Icons.water_drop_rounded,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.cyanAccent.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Teknik Potansiyel vs Gerçekleşen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '· toplam yenil. kapasitenin %${(stats.renewableMw / stats.technicalPotentialMw * 100).toStringAsFixed(0)}\'i kullanıldı',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, c) {
              final cross = c.maxWidth >= 700 ? 3 : 1;
              return GridView.count(
                crossAxisCount: cross,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: cross == 3 ? 1.7 : 3.5,
                children: items.map((it) {
                  final cur = it.$2, pot = it.$3, color = it.$4;
                  final pct = (cur / pot * 100).clamp(0, 100);
                  return Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(it.$5, color: color, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              it.$1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '%${pct.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct / 100,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(cur / 1000).toStringAsFixed(1)}GW / ${(pot / 1000).toStringAsFixed(0)}GW',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER / ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final TrStats stats;
  const _Footer({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(
            'Veri kaynakları: TEİAŞ · EPDK · PVGIS · MGM',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 10,
            ),
          ),
          const Spacer(),
          Text(
            '2024 sonu · ${stats.totalInstalledMw} MW',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 10,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Veriler yüklenemedi',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tekrar dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
                foregroundColor: Colors.cyanAccent,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

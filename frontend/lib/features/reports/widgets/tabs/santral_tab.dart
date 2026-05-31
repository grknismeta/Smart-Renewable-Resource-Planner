// lib/features/reports/widgets/tabs/santral_tab.dart
//
// SANTRAL TAB — Sprint R3 v1 (finans-dışı)
//
// İçerik:
//   • Pin seçici (kullanıcının santralleri)
//   • HERO: tip + lokasyon + KPI (kurulu güç, dönem üretim, karşılaştırma)
//   • Dönem seçici (Bugün/Hafta/Ay/Yıl/Toplam)
//   • Üretim grafiği (günlük breakdown bar) + veri kaynağı rozeti
//   • Type deep-dive: GES/RES/HES için teknik parametre kartı
//
// TR Finans paneli (YEKDEM/NPV/manuel override) → araştırma sonrası eklenecek.
//
// Veri: GET /pins/ + GET /pins/{id}/generation
// Mockup ref: designhtml/reports-pin-extended.jsx

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/map/widgets/map_view_maplibre.dart';
import 'package:frontend/features/reports/viewmodels/report_nav_controller.dart';
import 'package:frontend/features/reports/viewmodels/santral_viewmodel.dart';
import 'package:frontend/features/reports/widgets/climate/climate_widgets.dart';
import 'package:frontend/features/reports/widgets/common/report_ui.dart';

// CO₂ emisyon faktörü — Türkiye grid ortalaması (kg CO₂/kWh)
const double _kCo2PerKwh = 0.442;

class SantralTab extends StatelessWidget {
  /// Pin detail dialog'undan "Detaylı Rapor" ile açıldığında bu pin seçilir.
  final int? initialPinId;
  const SantralTab({super.key, this.initialPinId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => SantralViewModel(
        Provider.of<ApiService>(ctx, listen: false),
      )..init(initialPinId: initialPinId),
      child: const _SantralBody(),
    );
  }
}

class _SantralBody extends StatelessWidget {
  const _SantralBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SantralViewModel>();

    // 2026-05-25 (Polish1): Senaryo pin haritasından gelen pendingPinId varsa
    // o pin'i seç (cross-tab drill-down).
    final nav = context.watch<ReportNavController>();
    final pendingId = nav.pendingPinId;
    if (pendingId != null && vm.pins.isNotEmpty) {
      final match = vm.pins.cast<dynamic>().firstWhere(
            (p) => p.id == pendingId,
            orElse: () => null,
          );
      if (match != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          nav.consumePin();
          vm.selectPin(match);
        });
      }
    }

    if (vm.isBusy && vm.pins.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
      );
    }
    if (vm.pins.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.factory_outlined, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text(
              'Henüz santral (pin) eklenmemiş.\nHaritadan pin ekleyin.',
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
          child: vm.selectedPin == null
              ? const Center(
                  child: Text('Santral seç',
                      style: TextStyle(color: Colors.white54)))
              : _PinDetail(vm: vm),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOOLBAR — pin seçici
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final SantralViewModel vm;
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
      // 2026-05-25 (Fix4): Eski Row(icon + Dropdown(intrinsic) + Spacer +
      // TextButton). Pin adı uzun olunca Dropdown genişliyor, TextButton ile
      // iç içe geçiyordu. Şimdi Dropdown Expanded ile sınırlı + TextButton
      // ikon-only fallback (dar ekranda label gizli).
      child: Row(
        children: [
          const Icon(Icons.factory_rounded, size: 16, color: Colors.cyanAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.cyanAccent.withValues(alpha: 0.30)),
              ),
              child: DropdownButton<int>(
                value: vm.selectedPin?.id,
                isDense: true,
                isExpanded: true, // Container genişliğini doldur
                dropdownColor: const Color(0xFF1C2533),
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: Colors.cyanAccent, size: 18),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                items: vm.pins
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final pin = vm.pins.firstWhere((p) => p.id == id);
                  vm.selectPin(pin);
                },
              ),
            ),
          ),
          if (vm.selectedPin != null) ...[
            const SizedBox(width: 6),
            LayoutBuilder(builder: (lctx, c) {
              // Dar ekranda (Toolbar genişliği < 380) sadece ikon, geniş
              // ekranda ikon + label.
              final compact = MediaQuery.of(lctx).size.width < 420;
              void onPressed() {
                final pin = vm.selectedPin!;
                Navigator.of(context).popUntil((r) => r.isFirst);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  MapViewMapLibre.flyTo(
                    pin.latitude,
                    pin.longitude,
                    zoom: 11.0,
                  );
                });
              }
              if (compact) {
                return IconButton(
                  tooltip: 'Haritada Göster',
                  onPressed: onPressed,
                  icon: const Icon(Icons.map_rounded,
                      size: 18, color: Colors.cyanAccent),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                );
              }
              return TextButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.map_rounded, size: 14),
                label: const Text('Haritada Göster'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN DETAIL
// ─────────────────────────────────────────────────────────────────────────────

class _PinDetail extends StatelessWidget {
  final SantralViewModel vm;
  const _PinDetail({required this.vm});

  @override
  Widget build(BuildContext context) {
    final pin = vm.selectedPin!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(pin: pin, generation: vm.generation),
          const SizedBox(height: 12),
          // 2026-05-25 (F2): Eski _PeriodSelector Row.Expanded ile sabit 5
          // segment idi; dar ekranda Bugün/Hafta/Ay/Yıl/Toplam sığmıyor +
          // diğer tab'larla tutarsız görünüyordu. Shared ReportRangeSelector
          // ile değişti — yatay kaydırılabilir chip, taşmaz.
          ReportRangeSelector<String>(
            label: 'Dönem',
            icon: Icons.bar_chart_rounded,
            value: vm.period,
            items: const [
              ('today', 'Bugün'),
              ('week', 'Hafta'),
              ('month', 'Ay'),
              ('year', 'Yıl'),
              ('total', 'Toplam'),
            ],
            onChanged: vm.setPeriod,
          ),
          const SizedBox(height: 12),
          _ProductionSection(vm: vm),
          const SizedBox(height: 12),
          _TypeDeepDive(pin: pin),
          const SizedBox(height: 12),
          _InteractiveSimulator(pin: pin, climate: vm.climate),
          const SizedBox(height: 12),
          _ClimateProfile(vm: vm),
          const SizedBox(height: 12),
          _FinancePlaceholder(),
        ],
      ),
    );
  }
}

// ── Type meta helper ─────────────────────────────────────────────────────────

({String label, Color color, IconData icon}) _typeMeta(String type) {
  switch (type) {
    case 'Güneş Paneli':
      return (label: 'Güneş Paneli', color: const Color(0xFFF59E0B),
          icon: Icons.wb_sunny_rounded);
    case 'Rüzgar Türbini':
      return (label: 'Rüzgar Türbini', color: const Color(0xFF3B82F6),
          icon: Icons.air_rounded);
    case 'Hidroelektrik':
      return (label: 'Hidroelektrik', color: const Color(0xFF06B6D4),
          icon: Icons.water_drop_rounded);
    default:
      return (label: type, color: Colors.white54, icon: Icons.help_outline);
  }
}

// ── HERO ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final Pin pin;
  final PinGeneration? generation;
  const _Hero({required this.pin, required this.generation});

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta(pin.type);
    final loc = [pin.district, pin.city]
        .where((e) => e != null && e.isNotEmpty)
        .join(' / ');
    final periodKwh = generation?.totalKwh ?? 0;
    final co2 = periodKwh * _kCo2PerKwh / 1000; // ton

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [meta.color.withValues(alpha: 0.12), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: meta.color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: meta.color.withValues(alpha: 0.40)),
                ),
                child: Icon(meta.icon, color: meta.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pin.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${meta.label}${loc.isNotEmpty ? ' · $loc' : ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // KPI satırı — 2026-05-25 (Fix4): mobilde 3 Expanded KPI çok sıkışıp
          // value/unit iç içe geçiyordu. LayoutBuilder ile dar ekranda 2×2
          // (last KPI tam genişlik), geniş ekranda eski 3'lü Row.
          LayoutBuilder(builder: (lctx, c) {
            final kKurulu = _HeroKpiItem(
              label: 'Kurulu Güç',
              value: pin.capacityMw.toStringAsFixed(2),
              unit: 'MW',
              color: meta.color,
            );
            final kUretim = _HeroKpiItem(
              label:
                  'Üretim (${SantralViewModel.periodLabels[generation?.period] ?? '—'})',
              value: _fmtKwh(periodKwh),
              unit: _kwhUnit(periodKwh),
              color: Colors.cyanAccent,
            );
            final kCo2 = _HeroKpiItem(
              label: 'CO₂ Önleme',
              value: co2.toStringAsFixed(1),
              unit: 'ton',
              color: const Color(0xFF34D399),
            );
            if (c.maxWidth >= 380) {
              return Row(
                children: [
                  Expanded(child: kKurulu),
                  Expanded(child: kUretim),
                  Expanded(child: kCo2),
                ],
              );
            }
            return Column(
              children: [
                Row(children: [
                  Expanded(child: kKurulu),
                  Expanded(child: kUretim),
                ]),
                const SizedBox(height: 8),
                kCo2,
              ],
            );
          }),
        ],
      ),
    );
  }

}

/// Hero KPI tile — 2026-05-25 (Fix4): standalone widget'a çıktı, mobilde
/// Wrap/Row alternatifleri için tekrar kullanılabilir.
class _HeroKpiItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _HeroKpiItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
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
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Period selector ──────────────────────────────────────────────────────────

// 2026-05-25 (F2): Eski `_PeriodSelector` ReportRangeSelector ile değişti.

// ── Production section ───────────────────────────────────────────────────────

class _ProductionSection extends StatelessWidget {
  final SantralViewModel vm;
  const _ProductionSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.generationLoading) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              color: Colors.cyanAccent, strokeWidth: 2),
        ),
      );
    }
    final gen = vm.generation;
    if (gen == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Center(
          child: Text(
            'Üretim verisi hesaplanamadı',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }

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
          Row(
            children: [
              const Text(
                'Üretim Geçmişi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _DataSourceBadge(source: gen.dataSource),
            ],
          ),
          const SizedBox(height: 4),
          // Karşılaştırma
          if (gen.comparisonPctChange != null)
            Row(
              children: [
                Icon(
                  gen.comparisonPctChange! >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 13,
                  color: gen.comparisonPctChange! >= 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 4),
                Text(
                  'Önceki döneme göre %${gen.comparisonPctChange!.abs().toStringAsFixed(1)} '
                  '${gen.comparisonPctChange! >= 0 ? 'artış' : 'azalış'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (gen.dailyBreakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Bu dönem için günlük kırılım yok',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 2.8,
              child: CustomPaint(
                painter: _DailyBarPainter(points: gen.dailyBreakdown),
                size: Size.infinite,
              ),
            ),
        ],
      ),
    );
  }
}

class _DataSourceBadge extends StatelessWidget {
  final String source;
  const _DataSourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'hourly_actual' => ('Gerçek saatlik veri', const Color(0xFF10B981)),
      'climatology_interpolated' => ('İklim interpolasyonu', Colors.orange),
      'hybrid' => ('Hibrit (gerçek + iklim)', Colors.cyanAccent),
      _ => ('Bilinmiyor', Colors.white38),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DailyBarPainter extends CustomPainter {
  final List<GenerationPoint> points;
  _DailyBarPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const padBottom = 16.0;
    final w = size.width;
    final h = size.height - padBottom;
    final maxV = points.map((p) => p.kwh).fold<double>(0, math.max);
    if (maxV <= 0) return;

    final n = points.length;
    final barW = w / n;
    for (var i = 0; i < n; i++) {
      final v = points[i].kwh;
      final barH = (v / maxV * h).clamp(0.0, h);
      final x = i * barW + barW * 0.15;
      final bw = barW * 0.70;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h - barH, bw, barH),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.cyanAccent.withValues(alpha: 0.80),
      );
    }

    // İlk / orta / son tarih etiketi
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.40),
      fontSize: 8.5,
    );
    void dateLabel(int idx, TextAlign align) {
      if (idx < 0 || idx >= n) return;
      final d = points[idx].date;
      final short = d.length >= 10 ? d.substring(5) : d; // MM-DD
      final tp = TextPainter(
        text: TextSpan(text: short, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = idx * barW + barW / 2;
      final dx = switch (align) {
        TextAlign.center => cx - tp.width / 2,
        TextAlign.right => w - tp.width,
        _ => 0.0,
      };
      tp.paint(canvas, Offset(dx, size.height - padBottom + 3));
    }

    dateLabel(0, TextAlign.left);
    if (n > 2) dateLabel(n ~/ 2, TextAlign.center);
    dateLabel(n - 1, TextAlign.right);
  }

  @override
  bool shouldRepaint(covariant _DailyBarPainter old) => old.points != points;
}

// ── Type deep-dive ───────────────────────────────────────────────────────────

class _TypeDeepDive extends StatelessWidget {
  final Pin pin;
  const _TypeDeepDive({required this.pin});

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta(pin.type);
    final rows = <(String, String)>[];

    switch (pin.type) {
      case 'Güneş Paneli':
        rows.addAll([
          ('Panel Alanı', pin.panelArea != null
              ? '${pin.panelArea!.toStringAsFixed(0)} m²' : '—'),
          ('Panel Eğimi (Tilt)', pin.panelTilt != null
              ? '${pin.panelTilt!.toStringAsFixed(0)}°' : '—'),
          ('Yönelim (Azimuth)', pin.panelAzimuth != null
              ? '${pin.panelAzimuth!.toStringAsFixed(0)}°' : '—'),
          ('Ekipman', pin.equipmentName ?? '—'),
        ]);
      case 'Rüzgar Türbini':
        rows.addAll([
          ('Kurulu Güç', '${pin.capacityMw.toStringAsFixed(2)} MW'),
          ('Türbin Modeli', pin.equipmentName ?? '—'),
          ('Koordinat',
              '${pin.latitude.toStringAsFixed(3)}, ${pin.longitude.toStringAsFixed(3)}'),
        ]);
      case 'Hidroelektrik':
        rows.addAll([
          ('Debi (Q)', pin.flowRate != null
              ? '${pin.flowRate!.toStringAsFixed(1)} m³/s' : '—'),
          ('Düşü Yüksekliği (H)', pin.headHeight != null
              ? '${pin.headHeight!.toStringAsFixed(0)} m' : '—'),
          ('Havza Alanı', pin.basinAreaKm2 != null
              ? '${pin.basinAreaKm2!.toStringAsFixed(0)} km²' : '—'),
          ('Su Kaynağı', pin.waterBodyName ?? '—'),
          if (pin.flowRate != null && pin.headHeight != null)
            ('Türbin Önerisi', _turbineRec(pin.headHeight!)),
        ]);
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: meta.color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.icon, color: meta.color, size: 15),
              const SizedBox(width: 7),
              Text(
                '${meta.label} · Teknik Detay',
                style: TextStyle(
                  color: meta.color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        r.$1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        r.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// Düşü yüksekliğine göre türbin tipi önerisi.
  String _turbineRec(double head) {
    if (head > 200) return 'Pelton (yüksek düşü)';
    if (head > 50) return 'Francis (orta düşü)';
    return 'Kaplan (düşük düşü)';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// İNTERAKTİF SİMÜLATÖR — GES tilt/azimuth, RES power curve
// ─────────────────────────────────────────────────────────────────────────────

class _InteractiveSimulator extends StatefulWidget {
  final Pin pin;
  final ClimateSeries? climate;
  const _InteractiveSimulator({required this.pin, required this.climate});

  @override
  State<_InteractiveSimulator> createState() => _InteractiveSimulatorState();
}

class _InteractiveSimulatorState extends State<_InteractiveSimulator> {
  // GES — tilt / azimuth
  late double _tilt;
  late double _azimuth;
  // RES — hub yüksekliği
  double _hubHeight = 120;

  @override
  void initState() {
    super.initState();
    _tilt = widget.pin.panelTilt ?? 32;
    _azimuth = widget.pin.panelAzimuth ?? 180;
  }

  @override
  void didUpdateWidget(_InteractiveSimulator old) {
    super.didUpdateWidget(old);
    if (old.pin.id != widget.pin.id) {
      _tilt = widget.pin.panelTilt ?? 32;
      _azimuth = widget.pin.panelAzimuth ?? 180;
      _hubHeight = 120;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.pin.type) {
      case 'Güneş Paneli':
        return _buildSolar();
      case 'Rüzgar Türbini':
        return _buildWind();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── GES: Tilt + Azimuth ────────────────────────────────────────────────────

  Widget _buildSolar() {
    // Optimal tilt ≈ enlem; optimal azimuth = 180° (güney)
    final optimalTilt = widget.pin.latitude.abs();
    final tiltFactor = math.cos((_tilt - optimalTilt) * math.pi / 180);
    final azimuthFactor = math.cos((_azimuth - 180) * math.pi / 180);
    final combined = (tiltFactor * azimuthFactor).clamp(0.0, 1.0);

    // Baseline = optimal yerleşim (tilt=enlem, azimuth=180)
    const baseFactor = 1.0;
    final deltaPct = (combined - baseFactor) / baseFactor * 100;

    const color = Color(0xFFF59E0B);
    return _simCard(
      icon: Icons.wb_sunny_rounded,
      color: color,
      title: 'GES Simülatörü · Panel Yerleşimi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _slider(
            label: 'Panel Eğimi (Tilt)',
            value: _tilt,
            min: 0,
            max: 90,
            display: '${_tilt.toStringAsFixed(0)}°',
            color: color,
            onChanged: (v) => setState(() => _tilt = v),
          ),
          _slider(
            label: 'Yönelim (Azimuth)',
            value: _azimuth,
            min: 90,
            max: 270,
            display: '${_azimuth.toStringAsFixed(0)}° ${_azimuthDir(_azimuth)}',
            color: color,
            onChanged: (v) => setState(() => _azimuth = v),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: combined >= 0.97
                  ? const Color(0xFF10B981).withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: combined >= 0.97
                    ? const Color(0xFF10B981).withValues(alpha: 0.30)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VERİM FAKTÖRÜ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '%${(combined * 100).toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'OPTİMALE GÖRE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${deltaPct >= -0.05 ? '' : ''}${deltaPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: deltaPct >= -2
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Optimal: ${optimalTilt.toStringAsFixed(0)}° eğim · 180° güney '
            '(enleme göre hesaplandı)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  String _azimuthDir(double az) {
    if (az < 112) return '(Doğu)';
    if (az < 157) return '(GD)';
    if (az < 202) return '(Güney)';
    if (az < 247) return '(GB)';
    return '(Batı)';
  }

  // ── RES: Power curve + hub height ──────────────────────────────────────────

  Widget _buildWind() {
    // Pin lokasyonunun ortalama rüzgar hızı (climate'ten, yoksa varsayım)
    final ws = widget.climate?.windSpeed ?? const [];
    final baseSpeed = ws.isEmpty
        ? 7.0
        : ws.reduce((a, b) => a + b) / ws.length;
    // Wind shear — log/power law (α=0.143), referans 100m
    final adjustedSpeed = baseSpeed * math.pow(_hubHeight / 100, 0.143);
    final speedDelta = (adjustedSpeed - baseSpeed) / baseSpeed * 100;

    // Türbin rated gücü — capacity_mw'den kW
    final ratedKw = widget.pin.capacityMw * 1000;

    const color = Color(0xFF3B82F6);
    return _simCard(
      icon: Icons.air_rounded,
      color: color,
      title: 'RES Simülatörü · Power Curve & Hub Yüksekliği',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Power curve grafiği
          Text(
            'Güç Eğrisi · ${ratedKw.toStringAsFixed(0)} kW rated',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 2.6,
            child: CustomPaint(
              painter: _PowerCurvePainter(
                ratedKw: ratedKw,
                operatingSpeed: adjustedSpeed.toDouble(),
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 10),
          _slider(
            label: 'Hub Yüksekliği',
            value: _hubHeight,
            min: 80,
            max: 180,
            display: '${_hubHeight.toStringAsFixed(0)} m',
            color: color,
            onChanged: (v) => setState(() => _hubHeight = v),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ETKİLİ RÜZGAR HIZI',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            adjustedSpeed.toStringAsFixed(2),
                            style: const TextStyle(
                              color: color,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'm/s @${_hubHeight.toStringAsFixed(0)}m',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '100m REFERANSA GÖRE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${speedDelta >= 0 ? '+' : ''}${speedDelta.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: speedDelta >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Baz hız: ${baseSpeed.toStringAsFixed(2)} m/s (lokasyon ort.) · '
            'wind shear üs yasası α=0.143',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ortak widget'lar ───────────────────────────────────────────────────────

  Widget _simCard({
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'İNTERAKTİF',
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                display,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rüzgar türbini power curve painter — cut-in 3.5, rated 12, cut-out 25.
class _PowerCurvePainter extends CustomPainter {
  final double ratedKw;
  final double operatingSpeed;
  _PowerCurvePainter({required this.ratedKw, required this.operatingSpeed});

  static const cutIn = 3.5, rated = 12.0, cutOut = 25.0;

  double _power(double v) {
    if (v < cutIn || v >= cutOut) return 0;
    if (v >= rated) return ratedKw;
    return ratedKw * math.pow((v - cutIn) / (rated - cutIn), 2.5).toDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 38.0, padR = 8.0, padT = 8.0, padB = 18.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    // 2026-05-26 (M1): Pin capacity_mw 0 ise ratedKw=0 → division by zero
    // → NaN → Canvas crash. Rüzgar pinleri her seferinde çöküyordu (santral
    // tab kullanıcı raporu). Guard: ratedKw <= 0 ise yScale=1 (boş eğri).
    final safeRatedKw = ratedKw > 0 ? ratedKw : 1.0;
    double xFor(double v) => padL + (v / cutOut) * w;
    double yFor(double p) => padT + h - (p / safeRatedKw) * h;

    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = padT + h * i / 4;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
    }

    // Eğri
    final path = Path();
    var first = true;
    for (var v = 0.0; v <= cutOut; v += 0.5) {
      final x = xFor(v);
      final y = yFor(_power(v));
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Operating point — NaN/Inf koruması (M1)
    double sanitizeSpeed(double v) {
      if (v.isNaN || v.isInfinite) return 0.0;
      return v.clamp(0.0, cutOut);
    }
    final opV = sanitizeSpeed(operatingSpeed);
    final opX = xFor(opV);
    final opY = yFor(_power(opV));
    canvas.drawLine(
      Offset(opX, padT),
      Offset(opX, padT + h),
      Paint()
        ..color = const Color(0xFF2DD4BF)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(opX, opY),
      4,
      Paint()..color = const Color(0xFF2DD4BF),
    );

    // Etiketler
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.40),
      fontSize: 8,
    );
    void txt(String s, Offset o, {TextAlign a = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = a == TextAlign.center ? o.dx - tp.width / 2 : o.dx;
      tp.paint(canvas, Offset(dx, o.dy));
    }

    txt('${(ratedKw / 1000).toStringAsFixed(1)}MW', Offset(2, padT - 2));
    txt('0', Offset(padL - 10, padT + h - 5));
    for (final v in [0, 5, 10, 15, 20, 25]) {
      txt('$v', Offset(xFor(v.toDouble()), size.height - padB + 3),
          a: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant _PowerCurvePainter old) =>
      old.ratedKw != ratedKw || old.operatingSpeed != operatingSpeed;
}

// ── Climate profili — pin lokasyonunun aylık iklim grafikleri ────────────────

class _ClimateProfile extends StatelessWidget {
  final SantralViewModel vm;
  const _ClimateProfile({required this.vm});

  @override
  Widget build(BuildContext context) {
    final pin = vm.selectedPin!;
    if (pin.city == null || pin.city!.isEmpty) {
      return const SizedBox.shrink();
    }
    if (vm.climateLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.cyanAccent),
          ),
        ),
      );
    }
    final c = vm.climate;
    if (c == null) return const SizedBox.shrink();

    final meta = _typeMeta(pin.type);

    // Type'a göre uygun climate widget'ı
    Widget chart;
    switch (pin.type) {
      case 'Güneş Paneli':
        chart = WeatherStripCard(
          label: 'Aylık Güneş Işınımı',
          unit: 'kWh/m²·gün',
          data: c.irradiance,
          color: const Color(0xFFF59E0B),
        );
      case 'Rüzgar Türbini':
        chart = LayoutBuilder(builder: (ctx, cc) {
          final wide = cc.maxWidth >= 620;
          final strip = WeatherStripCard(
            label: 'Aylık Rüzgar Hızı',
            unit: 'm/s @100m',
            data: c.windSpeed,
            color: const Color(0xFF3B82F6),
          );
          final rose = WindRoseCard(rose: c.windRose);
          if (wide) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: strip),
                  const SizedBox(width: 10),
                  Expanded(child: rose),
                ],
              ),
            );
          }
          // Dar (mobil): dikey dizilim. strip (WeatherStripCard) içinde Column+
          // Expanded var → dış SizedBox(height:null) ile sınırsız yükseklikte
          // "non-zero flex unbounded height" çökmesi yapıyordu (web'de
          // IntrinsicHeight önlüyordu, mobilde değil) → iç içe geçme bug'ı.
          // BOUNDED yükseklik şart. rose (WindRoseCard) AspectRatio → kendi
          // boyutlanır, bound gerekmez.
          return Column(
            children: [
              SizedBox(height: 132, child: strip),
              const SizedBox(height: 10),
              rose,
            ],
          );
        });
      case 'Hidroelektrik':
        chart = RiverDischargeCard(discharge: c.riverDischarge);
      default:
        chart = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights_rounded, size: 14, color: meta.color),
            const SizedBox(width: 6),
            Text(
              'Lokasyon İklim Profili · ${pin.city}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            // Q3: Santral climate profili — aylık 10-yıl ortalama.
            ReportSourceBadge(
              source: c.source,
              freq: c.source.startsWith('mock')
                  ? ReportDataFreq.mockTypical
                  : ReportDataFreq.monthly10y,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: pin.type == 'Güneş Paneli' ? 130 : null,
          child: chart,
        ),
      ],
    );
  }
}

// 2026-05-25 (P2/7): Eski inline `_ClimateSourceBadge` shared `ReportSourceBadge`
// ile değişti — 3 tab'da tek widget.

// ── Finans placeholder ───────────────────────────────────────────────────────

class _FinancePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.construction_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TR Finansal Model',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'YEKDEM tarifeleri + CAPEX + NPV/IRR + manuel override — '
                  'TR finans araştırması tamamlanınca eklenecek.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10.5,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtKwh(double kwh) {
  if (kwh >= 1e9) return (kwh / 1e9).toStringAsFixed(2);
  if (kwh >= 1e6) return (kwh / 1e6).toStringAsFixed(1);
  if (kwh >= 1e3) return (kwh / 1e3).toStringAsFixed(1);
  return kwh.toStringAsFixed(0);
}

String _kwhUnit(double kwh) {
  if (kwh >= 1e9) return 'TWh';
  if (kwh >= 1e6) return 'GWh';
  if (kwh >= 1e3) return 'MWh';
  return 'kWh';
}

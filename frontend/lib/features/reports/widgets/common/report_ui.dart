// lib/features/reports/widgets/common/report_ui.dart
//
// Raporlar v3 — ortak UI primitifleri (design system).
//
// 6 tab farklı zamanlarda yazıldı; her biri kendi inline kart/başlık/KPI
// widget'ını üretiyordu → padding/renk/tipografi tutarsızlığı. Bu dosya
// tek kaynak: tüm tab'lar buradan tüketir.
//
// Renk paleti:
//   accent (cyan)  · solar #F59E0B · wind #3B82F6 · hydro #06B6D4
//   yüksek #10B981 · orta #F59E0B · düşük #EF4444

import 'package:flutter/material.dart';

/// Raporlar renk sabitleri — tek kaynak.
abstract final class ReportColors {
  static const accent = Colors.cyanAccent;
  static const solar = Color(0xFFF59E0B);
  static const wind = Color(0xFF3B82F6);
  static const hydro = Color(0xFF06B6D4);
  static const good = Color(0xFF10B981);
  static const mid = Color(0xFFF59E0B);
  static const bad = Color(0xFFEF4444);

  /// Kaynak tipi → renk. "solar"/"wind"/"hydro" (TR adlar da tolere edilir).
  static Color forResource(String type) => switch (type.toLowerCase()) {
        'solar' || 'güneş paneli' || 'güneş' => solar,
        'wind' || 'rüzgar türbini' || 'rüzgar' => wind,
        'hydro' || 'hidroelektrik' || 'hidro' => hydro,
        _ => Colors.white54,
      };

  /// 0-100 skor → renk (yüksek/orta/düşük).
  static Color forScore(double score) {
    if (score >= 65) return good;
    if (score >= 45) return mid;
    return bad;
  }
}

/// Standart Raporlar kartı — tüm tab'larda tutarlı container.
class ReportCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Verilirse kenarlık bu renkten (vurgu); yoksa nötr beyaz.
  final Color? accentBorder;

  /// Hafif gradyan arka plan (HERO benzeri kartlar için).
  final bool gradient;

  const ReportCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(13),
    this.accentBorder,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = accentBorder ?? Colors.white.withValues(alpha: 0.08);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient ? null : Colors.white.withValues(alpha: 0.03),
        gradient: gradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (accentBorder ?? ReportColors.accent)
                      .withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: accentBorder != null
              ? accentBorder!.withValues(alpha: 0.30)
              : border,
        ),
      ),
      child: child,
    );
  }
}

/// Bölüm başlığı — title + opsiyonel subtitle + trailing.
class ReportSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ReportSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

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
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

/// KPI kutusu — label (küçük uppercase) + value (büyük renkli) + sub.
class ReportKpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final Color color;

  const ReportKpiTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.color = ReportColors.accent,
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
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 10,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Veri kaynağı rozeti — mock (turuncu) vs gerçek (yeşil).
///
/// 2026-05-27 (Q3): Opsiyonel `freq` parametresi ile veri sıklığı bilgisi
/// gösterilir ("Saatlik 2y", "Aylık 10y", "Yıllık CF"). Kullanıcı hangi
/// granülerlik kullandığını anlasın — bkz. GRANULARITY-FORMULAS.md.
class ReportSourceBadge extends StatelessWidget {
  final String source; // "db" | "mock_region:..." | "hybrid_..."
  final ReportDataFreq? freq; // opsiyonel: veri sıklığı

  const ReportSourceBadge({super.key, required this.source, this.freq});

  @override
  Widget build(BuildContext context) {
    final isMock = source.startsWith('mock');
    final isHybrid = source.startsWith('hybrid');
    final (label, color) = isMock
        ? ('mock veri', ReportColors.mid)
        : isHybrid
            ? ('kısmi gerçek', ReportColors.accent)
            : ('gerçek veri', ReportColors.good);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMock
                    ? Icons.construction_rounded
                    : Icons.cloud_done_rounded,
                size: 10,
                color: color,
              ),
              const SizedBox(width: 4),
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
        ),
        if (freq != null) ...[
          const SizedBox(width: 4),
          ReportDataFreqBadge(freq: freq!),
        ],
      ],
    );
  }
}

/// 2026-05-27 (Q3): Veri sıklığı/dönem rozeti — hangi katmandan beslendiğini
/// gösterir. Bkz. `GRANULARITY-FORMULAS.md` vault dokümanı.
enum ReportDataFreq {
  /// `hourly_weather_data` (son 2 yıl, gerçek ölçüm)
  hourly2y,
  /// `climatology.monthly_*` JSON kolonları (10 yıl ortalaması)
  monthly10y,
  /// `climatology.capacity_factor` × 8760 (statik yıllık tahmin)
  yearlyCf,
  /// Mock veya climatology mock fallback
  mockTypical,
}

class ReportDataFreqBadge extends StatelessWidget {
  final ReportDataFreq freq;
  const ReportDataFreqBadge({super.key, required this.freq});

  @override
  Widget build(BuildContext context) {
    final (label, icon, tooltip) = switch (freq) {
      ReportDataFreq.hourly2y => (
          'Saatlik 2y',
          Icons.access_time_rounded,
          'Saatlik gerçek veri, son 2 yıl (hourly_weather_data)',
        ),
      ReportDataFreq.monthly10y => (
          'Aylık 10y',
          Icons.calendar_month_rounded,
          'Aylık ortalama, son 10 yıl (climatology.monthly_*)',
        ),
      ReportDataFreq.yearlyCf => (
          'Yıllık CF',
          Icons.bolt_rounded,
          'Kapasite faktörü × 8760 (climatology.capacity_factor)',
        ),
      ReportDataFreq.mockTypical => (
          'Tipik',
          Icons.science_outlined,
          'Mock/tipik profil (gerçek veri yok)',
        ),
    };
    final color = freq == ReportDataFreq.mockTypical
        ? ReportColors.mid
        : Colors.white.withValues(alpha: 0.55);
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2026-05-25 (F2): Tab-içi aralık seçici — AppBar'dan kaldırılan global
/// "Yıllık/Aylık" toggle'ın yerine her tab kendi range'ini yönetir. Yatay
/// kaydırılabilir chip listesi; dar ekranda taşmaz.
///
/// Kullanım:
///   `ReportRangeSelector\<int\>(value: vm.windowDays, items: const [(7, '7G'),
///   (30, '30G'), (90, '3A'), (365, '12A')], onChanged: vm.setWindowDays,
///   label: 'Aralık',
///   )
class ReportRangeSelector<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items; // (value, label)
  final ValueChanged<T> onChanged;
  final String? label;
  final IconData? icon;

  const ReportRangeSelector({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null || label != null) ...[
            Icon(
              icon ?? Icons.calendar_today_rounded,
              size: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(
                label!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
            const SizedBox(width: 8),
          ],
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            _RangeChip<T>(
              value: items[i].$1,
              label: items[i].$2,
              active: items[i].$1 == value,
              onTap: () => onChanged(items[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeChip<T> extends StatelessWidget {
  final T value;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RangeChip({
    required this.value,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? ReportColors.accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? ReportColors.accent.withValues(alpha: 0.50)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? ReportColors.accent : Colors.white60,
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// Renk noktası + etiket — lejant satırı.
Widget reportLegendDot(Color color, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 10,
        ),
      ),
    ],
  );
}

/// Yükleniyor görünümü — ortalanmış cyan spinner.
class ReportLoadingView extends StatelessWidget {
  const ReportLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: ReportColors.accent,
        strokeWidth: 2,
      ),
    );
  }
}

/// Boş durum — ikon + mesaj.
class ReportEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const ReportEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 44),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Hata durumu — ikon + mesaj + "Tekrar dene" butonu.
class ReportErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ReportErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

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
                backgroundColor: ReportColors.accent.withValues(alpha: 0.15),
                foregroundColor: ReportColors.accent,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/features/reports/pages/compare_page.dart
//
// 2026-05-25 (G4): Genel amaçlı karşılaştırma sayfası — il veya ilçe gibi
// çoklu öğeyi yan yana karşılaştırır. Tablodan "Karşılaştır (N)" butonu ile
// `Navigator.push` ile açılır; back tuşu otomatik çalışır.
//
// Veri modeli `CompareItem` — kullanım yerinin model dönüştürme yapması yeter.
// Henüz iklim verisi (monthly profile vs.) çekmiyor — sadece skor + best
// resource + estimated MW. İlerde daha zengin metrik eklenebilir.

import 'package:flutter/material.dart';
import 'package:frontend/features/reports/widgets/common/report_ui.dart';
import 'package:frontend/shared/widgets/app_background.dart';

/// Karşılaştırılacak tek bir öğe (il veya ilçe).
class CompareItem {
  final String name;
  final String subtitle; // örn. il adı (ilçe için), ya da bölge (il için)
  final String bestResource; // 'solar' | 'wind' | 'hydro'
  final double bestScore;
  final double? solarScore;
  final double? windScore;
  final double? hydroScore;
  final double estimatedMw;

  const CompareItem({
    required this.name,
    required this.subtitle,
    required this.bestResource,
    required this.bestScore,
    this.solarScore,
    this.windScore,
    this.hydroScore,
    required this.estimatedMw,
  });
}

class ComparePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<CompareItem> items;

  const ComparePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: title, subtitle: subtitle, count: items.length),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: items.isEmpty
                    ? const ReportEmptyState(
                        message: 'Karşılaştırılacak öğe seçilmedi.',
                      )
                    : _CompareBody(items: items),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  const _Header({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Colors.white70,
            ),
            tooltip: 'Geri',
            onPressed: () => Navigator.of(context).pop(),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.40),
              ),
            ),
            child: Text(
              '$count öğe',
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareBody extends StatelessWidget {
  final List<CompareItem> items;
  const _CompareBody({required this.items});

  @override
  Widget build(BuildContext context) {
    // 2026-05-25 (I1): İlk öğe **referans** — diğer öğelerin barlarının
    // yanında "ilk öğeye göre" delta etiketi (+yeşil / -kırmızı) görünür.
    // 2 öğe karşılaştırmada her iki tarafta da görünür: i=0'da delta yok,
    // i=1'de "ilke göre" deltası var. 3+ öğe: hepsinde referans yine ilk.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(builder: (ctx, c) {
        // Geniş ekran ≥ 900: 2+ kolon yan yana, dar ekran: tek kolon scroll.
        final wide = c.maxWidth >= 900;
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  Expanded(
                    child: _CompareColumn(
                      item: items[i],
                      rank: i + 1,
                      reference: i == 0 ? null : items[0],
                    ),
                  ),
                  if (i != items.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
        }
        // Dar: tek kolon
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _CompareColumn(
                item: items[i],
                rank: i + 1,
                reference: i == 0 ? null : items[0],
              ),
              if (i != items.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      }),
    );
  }
}

class _CompareColumn extends StatelessWidget {
  final CompareItem item;
  final int rank;
  /// 2026-05-25 (I1): null değilse skor barlarının yanında "referans'a göre
  /// fark" etiketi (+yeşil / -kırmızı) görünür. İlk öğe (rank=1) için null.
  final CompareItem? reference;
  const _CompareColumn({
    required this.item,
    required this.rank,
    this.reference,
  });

  Color _resColor(String r) => switch (r) {
        'solar' => const Color(0xFFF59E0B),
        'wind' => const Color(0xFF3B82F6),
        'hydro' => const Color(0xFF06B6D4),
        _ => Colors.white54,
      };

  String _resLabel(String r) => switch (r) {
        'solar' => 'Güneş',
        'wind' => 'Rüzgar',
        'hydro' => 'Hidro',
        _ => '?',
      };

  @override
  Widget build(BuildContext context) {
    final bestColor = _resColor(item.bestResource);
    return ReportCard(
      accentBorder: bestColor,
      gradient: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header — rank rozet + ad + best resource rozet
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bestColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: bestColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Best resource summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: bestColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Text(
                  'En İyi · ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
                Text(
                  _resLabel(item.bestResource),
                  style: TextStyle(
                    color: bestColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  item.bestScore.toStringAsFixed(0),
                  style: TextStyle(
                    color: bestColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  ' /100',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                  ),
                ),
                // I1: En iyi skor delta'sı — referans varsa
                if (reference != null) ...[
                  const SizedBox(width: 6),
                  _deltaChip(item.bestScore - reference!.bestScore, suffix: ''),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 3 kaynak skor satırı — referans varsa delta gösterilir
          _scoreBar(
            'Güneş',
            item.solarScore,
            const Color(0xFFF59E0B),
            referenceValue: reference?.solarScore,
          ),
          const SizedBox(height: 8),
          _scoreBar(
            'Rüzgar',
            item.windScore,
            const Color(0xFF3B82F6),
            referenceValue: reference?.windScore,
          ),
          const SizedBox(height: 8),
          _scoreBar(
            'Hidro',
            item.hydroScore,
            const Color(0xFF06B6D4),
            referenceValue: reference?.hydroScore,
          ),
          const SizedBox(height: 12),
          // Estimated MW
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded,
                    size: 13, color: Colors.white.withValues(alpha: 0.55)),
                const SizedBox(width: 6),
                Text(
                  'Tahmini Kurulu Güç',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  '${item.estimatedMw.toStringAsFixed(0)} MW',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (reference != null) ...[
                  const SizedBox(width: 6),
                  _deltaChip(
                    item.estimatedMw - reference!.estimatedMw,
                    suffix: ' MW',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBar(
    String label,
    double? value,
    Color color, {
    double? referenceValue,
  }) {
    final v = value ?? 0;
    final hasData = value != null && value > 0;
    final delta = (referenceValue != null) ? v - referenceValue : null;
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: hasData ? 0.65 : 0.30),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              if (hasData)
                FractionallySizedBox(
                  widthFactor: (v / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              // I1: Referans varsa bar üzerinde referans değerinin pozisyonu
              // küçük dikey tick olarak gösterilir — FractionallySizedBox +
              // Align ile (context-bağımsız, herhangi bir genişlikte çalışır).
              if (referenceValue != null && referenceValue > 0)
                FractionallySizedBox(
                  widthFactor: (referenceValue / 100).clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 2,
                      height: 14,
                      margin: const EdgeInsets.only(top: 1),
                      color: Colors.white.withValues(alpha: 0.50),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            hasData ? v.toStringAsFixed(0) : '—',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: hasData ? color : Colors.white24,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        // I1: Bar sonu delta etiketi
        if (delta != null) ...[
          const SizedBox(width: 4),
          _deltaChip(delta, suffix: ''),
        ],
      ],
    );
  }

  /// I1: +yeşil / -kırmızı delta etiketi (fotoğraftaki bar üstü gösterge).
  /// |delta| < 0.5 → "≈ 0" küçük gri etiket.
  Widget _deltaChip(double delta, {String suffix = ''}) {
    if (delta.abs() < 0.5) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '≈',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    final positive = delta > 0;
    final color = positive
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final sign = positive ? '+' : '−';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$sign${delta.abs().toStringAsFixed(0)}$suffix',
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

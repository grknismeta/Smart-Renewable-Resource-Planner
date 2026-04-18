import 'package:flutter/material.dart';

/// Dünya enerji verileri — Türkiye vurgulu karşılaştırma
class LandingWorldDataSection extends StatelessWidget {
  final bool isDark;

  const LandingWorldDataSection({
    super.key,
    required this.isDark,
  });

  // Ülke verileri (kaynak: IRENA, 2024 tahminleri)
  static const _countries = <_CountryData>[
    _CountryData('Çin', 1340, false),
    _CountryData('ABD', 420, false),
    _CountryData('Almanya', 165, false),
    _CountryData('Hindistan', 180, false),
    _CountryData('Türkiye', 115, true), // Vurgulu
    _CountryData('Brezilya', 95, false),
    _CountryData('İspanya', 75, false),
    _CountryData('İngiltere', 65, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dünya\'da Yenilenebilir Enerji',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kurulu güç karşılaştırması (GW) — IRENA 2024',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 28),

          // Yatay bar grafik
          ..._countries.map((c) => _buildBar(c)),

          const SizedBox(height: 32),

          // Alt bilgi kartları
          LayoutBuilder(
            builder: (context, constraints) {
              final cardW = constraints.maxWidth > 800
                  ? (constraints.maxWidth - 24) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _buildHighlightCard(
                    width: cardW,
                    title: 'Türkiye\'nin Yükselişi',
                    desc:
                        'Türkiye, yenilenebilir enerji kurulu gücünde son 10 yılda %200+ büyüme kaydetti. '
                        'Özellikle rüzgar ve güneş enerjisinde hızlı ilerleme devam ediyor.',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF22C55E),
                  ),
                  _buildHighlightCard(
                    width: cardW,
                    title: 'Hedef 2035',
                    desc:
                        'Türkiye, 2035 yılına kadar toplam elektrik üretiminin %50\'sini '
                        'yenilenebilir kaynaklardan sağlamayı hedefliyor.',
                    icon: Icons.flag_rounded,
                    color: const Color(0xFF3B82F6),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBar(_CountryData c) {
    final maxVal = _countries.fold<double>(0, (m, e) => e.gw > m ? e.gw : m);
    final ratio = c.gw / maxVal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              c.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: c.isTurkey ? FontWeight.w800 : FontWeight.w500,
                color: c.isTurkey
                    ? const Color(0xFF22C55E)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                return Stack(
                  children: [
                    // Arka plan
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Doluluk
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      height: 28,
                      width: constraints.maxWidth * ratio,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: c.isTurkey
                              ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                              : [
                                  const Color(0xFF3B82F6)
                                      .withValues(alpha: 0.6),
                                  const Color(0xFF3B82F6)
                                      .withValues(alpha: 0.3),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 55,
            child: Text(
              '${c.gw.toInt()} GW',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: c.isTurkey ? FontWeight.w800 : FontWeight.w500,
                color: c.isTurkey
                    ? const Color(0xFF22C55E)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard({
    required double width,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white60 : Colors.black54,
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

class _CountryData {
  final String name;
  final double gw;
  final bool isTurkey;
  const _CountryData(this.name, num gw, this.isTurkey) : gw = gw * 1.0;
}

import 'package:flutter/material.dart';

/// Uygulama özellikleri tanıtımı — hover efektli kartlar
class LandingFeaturesSection extends StatelessWidget {
  final bool isDark;
  final bool compact;

  const LandingFeaturesSection({
    super.key,
    required this.isDark,
    this.compact = false,
  });

  static const _features = <_Feature>[
    _Feature(
      Icons.air,
      Color(0xFF06B6D4),
      'Rüzgar Analizi',
      'Weibull dağılımı ile rüzgar potansiyeli hesaplama ve kapasite faktörü analizi.',
    ),
    _Feature(
      Icons.wb_sunny_rounded,
      Color(0xFFF59E0B),
      'Güneş Haritası',
      'Işınım yoğunluğu heatmap ve bölgesel güneş enerjisi potansiyel analizi.',
    ),
    _Feature(
      Icons.auto_awesome,
      Color(0xFF8B5CF6),
      'Akıllı Öneriler',
      '3 kategoride en verimli bölgeleri Weibull k, ortalama hız ve ışınım bazında sıralama.',
    ),
    _Feature(
      Icons.terrain_rounded,
      Color(0xFF10B981),
      '3D Arazi & Binalar',
      'Yükseklik modeli, gökyüzü efekti ve 3D bina görselleştirme.',
    ),
    _Feature(
      Icons.description_rounded,
      Color(0xFFEF4444),
      'Rapor & Export',
      'Bölgesel analiz raporları, grafik karşılaştırma ve PDF export.',
    ),
    _Feature(
      Icons.public_rounded,
      Color(0xFF3B82F6),
      'Global Projeksiyon',
      'Dünya genelinde enerji yatırımı planlama ve karşılaştırma.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();
    return _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Özellikler',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Harita üzerinde tüm analiz araçları',
            style: TextStyle(
              fontSize: 17,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1000
                  ? 3
                  : constraints.maxWidth > 600
                  ? 2
                  : 1;
              final cardWidth = (constraints.maxWidth - (cols - 1) * 20) / cols;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: _features
                    .map(
                      (f) => _FeatureCard(
                        feature: f,
                        width: cardWidth,
                        isDark: isDark,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Özellikler',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _features.map((f) => _buildChip(f)).toList(),
        ),
      ],
    );
  }

  Widget _buildChip(_Feature f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: f.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: f.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(f.icon, size: 14, color: f.color),
          const SizedBox(width: 6),
          Text(
            f.title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  final double width;
  final bool isDark;

  const _FeatureCard({
    required this.feature,
    required this.width,
    required this.isDark,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: widget.width,
        padding: const EdgeInsets.all(22),
        transform: Matrix4.identity()..scale(_hovering ? 1.04 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: _hovering ? 0.08 : 0.04,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovering
                ? f.color.withValues(alpha: 0.3)
                : (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.06,
                  ),
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: f.color.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: f.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(f.icon, color: f.color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              f.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              f.desc,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _Feature(this.icon, this.color, this.title, this.desc);
}

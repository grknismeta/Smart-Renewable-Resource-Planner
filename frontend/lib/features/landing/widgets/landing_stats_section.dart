import 'package:flutter/material.dart';

/// Canlı İstatistikler — CountUp animasyonlu sayaçlar
class LandingStatsSection extends StatefulWidget {
  final bool isDark;
  final bool compact;

  const LandingStatsSection({
    super.key,
    required this.isDark,
    this.compact = false,
  });

  @override
  State<LandingStatsSection> createState() => _LandingStatsSectionState();
}

class _LandingStatsSectionState extends State<LandingStatsSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _stats = <_Stat>[
    _Stat(Icons.location_city, 81, 'İl Analiz Edildi', '', 0,
        Color(0xFF3B82F6)),
    _Stat(Icons.map_outlined, 950, 'İlçe Verisi', '+', 0,
        Color(0xFF8B5CF6)),
    _Stat(Icons.air, 3.4, 'Ort. Rüzgar', ' m/s', 1,
        Color(0xFF06B6D4)),
    _Stat(Icons.wb_sunny, 195, 'Ort. Işınım', ' W/m²', 0,
        Color(0xFFF59E0B)),
    _Stat(Icons.data_usage, 12450, 'Veri Noktası', '+', 0,
        Color(0xFF22C55E)),
    _Stat(Icons.schedule, 168, 'Saatlik Tahmin', ' saat', 0,
        Color(0xFFEF4444)),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 0 : 32,
        vertical: widget.compact ? 0 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.compact) ...[
            Text(
              'Türkiye Enerji Verileri',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anlık hesaplanan istatistikler',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 24),
          ],
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Wrap(
              spacing: 14,
              runSpacing: 14,
              children: List.generate(_stats.length, (i) {
                final delay = i * 0.12;
                final raw =
                    ((_controller.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                final progress = Curves.easeOut.transform(raw);
                return _buildCard(_stats[i], progress, isDark);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_Stat stat, double progress, bool isDark) {
    final w = widget.compact ? 140.0 : 180.0;
    final val = stat.value * progress;
    final display = stat.decimals > 0
        ? val.toStringAsFixed(stat.decimals)
        : val.toInt().toString();

    return SizedBox(
      width: w,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: stat.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(stat.icon, size: 20, color: stat.color),
            ),
            const SizedBox(height: 12),
            Text(
              '$display${stat.suffix}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stat.label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat {
  final IconData icon;
  final double value;
  final String label;
  final String suffix;
  final int decimals;
  final Color color;

  const _Stat(
      this.icon, num value, this.label, this.suffix, this.decimals, this.color)
      : value = value * 1.0;
}

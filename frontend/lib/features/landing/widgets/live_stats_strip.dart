import 'package:flutter/material.dart';

/// Canlı istatistik şeridi — animasyonlu sayaçlar
class LiveStatsStrip extends StatefulWidget {
  final bool isDark;
  const LiveStatsStrip({super.key, required this.isDark});

  @override
  State<LiveStatsStrip> createState() => _LiveStatsStripState();
}

class _LiveStatsStripState extends State<LiveStatsStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = <_StatItem>[
      _StatItem(icon: Icons.location_city, value: 81, label: 'Il', suffix: ''),
      _StatItem(
          icon: Icons.air,
          value: 3.4,
          label: 'Ort. Ruzgar',
          suffix: ' m/s',
          decimals: 1),
      _StatItem(
          icon: Icons.wb_sunny,
          value: 195,
          label: 'Ort. Isinim',
          suffix: ' W/m\u00B2'),
      _StatItem(
          icon: Icons.data_usage,
          value: 12450,
          label: 'Veri Noktasi',
          suffix: '+'),
    ];

    return SizedBox(
      height: 72,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: stats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            // Her item biraz gecikmeli başlar
            final delay = i * 0.15;
            final progress = (_controller.value - delay).clamp(0.0, 1.0) /
                (1.0 - delay).clamp(0.01, 1.0);
            final curved = Curves.easeOut.transform(progress.clamp(0.0, 1.0));

            return _buildStatCard(stats[i], curved);
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(_StatItem stat, double progress) {
    final bgColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF333333);
    final subColor = widget.isDark ? Colors.white60 : const Color(0xFF777777);
    final iconColor = const Color(0xFF3B82F6);

    final currentValue = stat.value * progress;
    final display = stat.decimals > 0
        ? currentValue.toStringAsFixed(stat.decimals)
        : currentValue.toInt().toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (widget.isDark ? Colors.white : Colors.black)
              .withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$display${stat.suffix}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                stat.label,
                style: TextStyle(fontSize: 11, color: subColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final double value;
  final String label;
  final String suffix;
  final int decimals;

  _StatItem({
    required this.icon,
    required num value,
    required this.label,
    required this.suffix,
    this.decimals = 0,
  }) : value = value.toDouble();
}

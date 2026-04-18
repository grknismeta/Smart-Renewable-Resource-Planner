import 'package:flutter/material.dart';

/// Alt bar — daraltılabilir mini dashboard
class LandingBottomBar extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final bool isDark;

  const LandingBottomBar({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? const Color(0xFF1E232F).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);
    final borderColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
    final textColor = isDark ? Colors.white : const Color(0xFF333333);
    final subColor = isDark ? Colors.white60 : const Color(0xFF777777);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: expanded ? 180 : 56,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Handle + başlık
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  Icon(Icons.bolt_rounded,
                      color: const Color(0xFF22C55E), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Turkiye Enerji Ozeti',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),

          // Genişletilmiş içerik
          if (expanded)
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    _buildMiniStat(
                      'Ruzgar Potansiyeli',
                      'Canakkale, Kirklareli, Tekirdag',
                      Icons.air,
                      const Color(0xFF06B6D4),
                      textColor,
                      subColor,
                    ),
                    const SizedBox(width: 12),
                    _buildMiniStat(
                      'Gunes Potansiyeli',
                      'Aksaray, Nigde, Izmir',
                      Icons.wb_sunny_rounded,
                      const Color(0xFFF59E0B),
                      textColor,
                      subColor,
                    ),
                    const SizedBox(width: 12),
                    _buildMiniStat(
                      'En Verimli',
                      'Canakkale (k:3.9, 3.6 m/s)',
                      Icons.trending_up_rounded,
                      const Color(0xFF22C55E),
                      textColor,
                      subColor,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    Color textColor,
    Color subColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 11, color: subColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

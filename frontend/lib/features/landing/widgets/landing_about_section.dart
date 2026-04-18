import 'package:flutter/material.dart';

/// Proje hakkında bölümü — amaç, enerji verimliliği, karbon
class LandingAboutSection extends StatelessWidget {
  final bool isDark;
  final bool compact;

  const LandingAboutSection({
    super.key,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 32,
        vertical: compact ? 16 : 40,
      ),
      child: compact ? _buildCompact() : _buildFull(),
    );
  }

  Widget _buildFull() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        Text(
          'Neden SRRP?',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Türkiye\'nin yenilenebilir enerji potansiyelini veriye dayalı analiz edin.',
          style: TextStyle(
            fontSize: 17,
            color: isDark ? Colors.white60 : Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // 3 kart — enerji, maliyet, karbon
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 900
                ? (constraints.maxWidth - 48) / 3
                : constraints.maxWidth > 600
                    ? (constraints.maxWidth - 24) / 2
                    : constraints.maxWidth;

            return Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _buildInfoCard(
                  width: cardWidth,
                  icon: Icons.flash_on_rounded,
                  color: const Color(0xFFF59E0B),
                  title: 'Enerji Verimliliği',
                  desc:
                      'Rüzgar ve güneş verilerini analiz ederek en verimli bölgeleri tespit edin. Weibull dağılımı ve ışınım haritaları ile doğru yatırım kararları alın.',
                  stat: '%23',
                  statLabel: 'daha yüksek verim potansiyeli',
                ),
                _buildInfoCard(
                  width: cardWidth,
                  icon: Icons.savings_rounded,
                  color: const Color(0xFF22C55E),
                  title: 'Maliyet Avantajı',
                  desc:
                      'Doğru konum seçimi ile kurulum ve işletme maliyetlerini optimize edin. '
                      'Kapasite faktörü analizi ile yatırım geri dönüş süresini kısaltın.',
                  stat: '%35',
                  statLabel: 'maliyet tasarrufu potansiyeli',
                ),
                _buildInfoCard(
                  width: cardWidth,
                  icon: Icons.eco_rounded,
                  color: const Color(0xFF06B6D4),
                  title: 'Karbon Azaltımı',
                  desc:
                      'Yenilenebilir enerji yatırımları ile karbon emisyonunu azaltın. '
                      'Her pin, potansiyel karbon tasarrufunu otomatik hesaplar.',
                  stat: '↓CO₂',
                  statLabel: 'emisyon azaltma hedefi',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Neden SRRP?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        _buildCompactItem(Icons.flash_on_rounded, const Color(0xFFF59E0B),
            'Enerji Verimliliği', '%23 daha yüksek verim'),
        const SizedBox(height: 8),
        _buildCompactItem(Icons.savings_rounded, const Color(0xFF22C55E),
            'Maliyet Avantajı', '%35 tasarruf potansiyeli'),
        const SizedBox(height: 8),
        _buildCompactItem(Icons.eco_rounded, const Color(0xFF06B6D4),
            'Karbon Azaltımı', 'CO₂ emisyon takibi'),
      ],
    );
  }

  Widget _buildCompactItem(
      IconData icon, Color color, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    )),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required double width,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required String stat,
    required String statLabel,
  }) {
    return _HoverCard(
      width: width,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                stat,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hover efektli kart (mouse gelince büyür, gidince küçülür)
class _HoverCard extends StatefulWidget {
  final double width;
  final bool isDark;
  final Widget child;

  const _HoverCard({
    required this.width,
    required this.isDark,
    required this.child,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: widget.width,
        padding: const EdgeInsets.all(24),
        transform: Matrix4.identity()..scale(_hovering ? 1.03 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: (widget.isDark ? Colors.white : Colors.black)
              .withValues(alpha: _hovering ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (widget.isDark ? Colors.white : Colors.black)
                .withValues(alpha: _hovering ? 0.12 : 0.06),
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}

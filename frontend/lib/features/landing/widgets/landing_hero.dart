import 'package:flutter/material.dart';

/// Hero bölümü: Logo + slogan + Giriş butonu
class LandingHero extends StatefulWidget {
  final VoidCallback onAuthTap;
  final VoidCallback onGuestTap;
  final bool isDark;
  final bool isWide;

  const LandingHero({
    super.key,
    required this.onAuthTap,
    required this.onGuestTap,
    required this.isDark,
    required this.isWide,
  });

  @override
  State<LandingHero> createState() => _LandingHeroState();
}

class _LandingHeroState extends State<LandingHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subtitleColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF555555);

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideUp,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: widget.isWide
              ? _buildWideLayout(textColor, subtitleColor)
              : _buildNarrowLayout(textColor, subtitleColor),
        ),
      ),
    );
  }

  Widget _buildWideLayout(Color textColor, Color subtitleColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Sol: Logo + başlık
        Expanded(child: _buildBranding(textColor, subtitleColor)),
        // Sağ: Butonlar
        _buildAuthButtons(),
      ],
    );
  }

  Widget _buildNarrowLayout(Color textColor, Color subtitleColor) {
    return Column(
      children: [
        _buildBranding(textColor, subtitleColor),
        const SizedBox(height: 16),
        _buildAuthButtons(),
      ],
    );
  }

  Widget _buildBranding(Color textColor, Color subtitleColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo ikonu
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SRRP',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: 2,
              ),
            ),
            Text(
              "Turkiye'nin enerji haritasi",
              style: TextStyle(fontSize: 13, color: subtitleColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Misafir butonu
        TextButton(
          onPressed: widget.onGuestTap,
          style: TextButton.styleFrom(
            foregroundColor:
                widget.isDark ? Colors.white70 : const Color(0xFF666666),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Kesfet', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        // Giriş yap butonu
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onAuthTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.login_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Giris Yap',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

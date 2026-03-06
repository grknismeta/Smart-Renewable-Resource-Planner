import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingDone = 'onboarding_done';

/// Uygulama ilk açılışında gösterilen 3-sayfalık karşılama ekranı.
/// SharedPreferences'a `onboarding_done=true` yazarak bir daha gösterilmesini önler.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _iconController;
  late final Animation<double> _iconAnimation;

  // ── Sayfa tanımları ─────────────────────────────────────────────────────────
  static const _pages = [
    _OnboardingPage(
      icon: Icons.bolt_rounded,
      iconColor: Color(0xFFFFD700),
      title: 'Enerjiyi Planlayın',
      subtitle:
          'Güneş, rüzgar ve HES potansiyelini tek platformda analiz edin. '
          'Türkiye genelinde enerji kaynaklarını harita üzerinde görselleştirin.',
      gradient: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    ),
    _OnboardingPage(
      icon: Icons.map_rounded,
      iconColor: Color(0xFF4ECDC4),
      title: 'Akıllı Harita',
      subtitle:
          'İnteraktif haritada pinler ekleyin, bölge seçin, '
          'enerji koridorlarını keşfedin. Gerçek zamanlı hava ve '
          'ışınım verilerini anlık takip edin.',
      gradient: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
    ),
    _OnboardingPage(
      icon: Icons.insights_rounded,
      iconColor: Color(0xFF56CCF2),
      title: 'Senaryo & Rapor',
      subtitle:
          'Farklı enerji senaryolarını karşılaştırın, '
          'üretim tahminleri oluşturun ve bölgesel raporlarınızı '
          'PDF olarak dışa aktarın.',
      gradient: [Color(0xFF1A1A2E), Color(0xFF2D1B69)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _iconAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
    if (!mounted) return;
    // Ana akışa dön — main.dart'taki HomeRouter yeniden build eder
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _skipOnboarding() => _finishOnboarding();

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: page.gradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Arka plan parçacıkları ─────────────────────────────────────
              const _FloatingParticles(),

              // ── İçerik ────────────────────────────────────────────────────
              Column(
                children: [
                  // Skip butonu
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _skipOnboarding,
                      child: const Text(
                        'Geç',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                  // PageView
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemBuilder: (ctx, i) => _buildPageContent(_pages[i]),
                    ),
                  ),

                  // Dot indikatörler
                  _DotIndicator(
                    count: _pages.length,
                    current: _currentPage,
                  ),

                  const SizedBox(height: 32),

                  // İleri / Başla butonu
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            colors: isLast
                                ? [const Color(0xFF56CCF2), const Color(0xFF2F80ED)]
                                : [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isLast
                                      ? const Color(0xFF56CCF2)
                                      : const Color(0xFF4ECDC4))
                                  .withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: _nextPage,
                          child: Text(
                            isLast ? '🚀  Hemen Başla' : 'Devam Et  →',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animasyonlu ikon
          ScaleTransition(
            scale: _iconAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: page.iconColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: page.iconColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                page.icon,
                size: 72,
                color: page.iconColor,
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Başlık
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 20),

          // Açıklama
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sayfa verisi ─────────────────────────────────────────────────────────────
class _OnboardingPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}

// ── Dot indikatör ─────────────────────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? const Color(0xFF4ECDC4)
                : Colors.white.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}

// ── Arka plan parçacıkları (dekoratif) ────────────────────────────────────────
class _FloatingParticles extends StatefulWidget {
  const _FloatingParticles();

  @override
  State<_FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<_FloatingParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static final _rand = math.Random(42);
  // Pre-compute particle positions so they don't change every build
  static final _particles = List.generate(12, (_) {
    return _Particle(
      x: _rand.nextDouble(),
      y: _rand.nextDouble(),
      size: 2 + _rand.nextDouble() * 4,
      speed: 0.2 + _rand.nextDouble() * 0.3,
      opacity: 0.08 + _rand.nextDouble() * 0.12,
    );
  });

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ParticlePainter(_ctrl.value, _particles),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Particle {
  final double x, y, size, speed, opacity;
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _ParticlePainter(this.progress, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dy = (p.y + progress * p.speed) % 1.0;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(p.x * size.width, dy * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/landing/widgets/auth_dropdown.dart';
import 'package:frontend/features/landing/widgets/landing_stats_section.dart';
import 'package:frontend/features/landing/widgets/landing_features_section.dart';
import 'package:frontend/features/landing/widgets/landing_world_data_section.dart';
import 'package:frontend/features/landing/widgets/landing_about_section.dart';
import 'package:frontend/features/landing/showcase_pins.dart';
import 'package:frontend/features/map/widgets/map_view_maplibre.dart';

/// SRRP Giriş Sayfası — bağımsız sayfa olarak çalışır.
/// Auth başarılı → /map sayfasına yönlendirir.
/// Keşfet → /map sayfasına misafir olarak yönlendirir.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _authOpen = false;
  int _authPage = 0;

  // Mobil swipe
  late final PageController _mobilePageCtrl;

  @override
  void initState() {
    super.initState();
    _mobilePageCtrl = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _mobilePageCtrl.dispose();
    super.dispose();
  }

  void _openAuth({int page = 0}) {
    setState(() {
      _authOpen = true;
      _authPage = page;
    });
  }

  void _closeAuth() => setState(() => _authOpen = false);

  void _onAuthSuccess() {
    setState(() => _authOpen = false);
    if (!mounted) return;
    _resetMapStateForMain();
    Navigator.of(context).pushReplacementNamed('/map');
  }

  void _continueAsGuest() {
    if (!mounted) return;
    // 2026-06-04: Keşfet = misafir salt-okunur keşif modu. pushReplacement YERİNE
    // push → landing stack'te kalır → geri tuşu landing'e döner (eskiden root'a
    // düşüp boş kalıyordu). Türkiye sınırı + etkileşim MapScreen'de misafire göre
    // ayarlanır; burada landing'in kilidini kaldırMA (keşif de Türkiye-kilitli).
    Navigator.of(context).pushNamed('/map', arguments: {'guest': true});
  }

  /// 2026-06-02: /map'e geçmeden ÖNCE landing'in kapattığı ETKİLEŞİMİ aç.
  /// Landing dekoratif arka planda `setInteractive(false)` yapıyor; ana haritaya
  /// geçerken açılmalı (pushReplacement landing'i geç dispose ettiği için
  /// navigasyondan ÖNCE yapılır).
  /// 2026-06-05: maxBounds ARTIK her zaman Türkiye (JS default) → clearMaxBounds
  /// çağrısı kaldırıldı; ana harita da Türkiye-kilitli (Türkiye-only uygulama).
  void _resetMapStateForMain() {
    MapViewMapLibre.setInteractive(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;
    final isDark = theme.isDarkMode;

    return Material(
      color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
      child: Stack(
        children: [
          // ═══ Katman 0: MapLibre — sabit, sayfanın üst kısmı ═══
          if (isWide)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.82,
              child: const _LandingMap(),
            ),

          // ═══ Katman 1: Scroll içerik ═══
          Positioned.fill(
            child: isWide
                ? _buildWebOverlay(isDark, size)
                : _buildMobileOverlay(isDark),
          ),

          // ═══ Katman 2: Üst bar ═══
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: isWide
                ? _buildTopBar(isDark)
                : _buildMobileTopBar(isDark),
          ),

          // ═══ Katman 3: Auth dropdown ═══
          if (_authOpen)
            AuthDropdown(
              isDark: isDark,
              initialPage: _authPage,
              onClose: _closeAuth,
              onAuthSuccess: _onAuthSuccess,
              onGuestContinue: _continueAsGuest,
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEB — Geniş ekran düzeni
  // Harita üstte sabit, scroll ile bölümler haritanın üzerine kayar
  // ═══════════════════════════════════════════════════════════════
  Widget _buildWebOverlay(bool isDark, Size size) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ═══ Harita vitrin alanı — saydam, arkadaki MapLibre görünür ═══
          SizedBox(
            height: size.height * 0.78,
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 72,
                left: 40,
                right: 40,
                bottom: 24,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Türkiye Enerji\nPotansiyelini Keşfedin',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            blurRadius: 20,
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Güneş, rüzgar ve hidroelektrik kaynaklarını harita üzerinde inceleyin',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.85),
                        shadows: [
                          Shadow(
                            blurRadius: 12,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ═══ Geçiş gradient — haritadan solid bölüme yumuşak geçiş ═══
          Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  isDark
                      ? const Color(0xFF0F1117)
                      : const Color(0xFFF5F7FA),
                ],
              ),
            ),
          ),

          // ═══ Solid bölümler — scroll ile haritanın üstünü kapatır ═══
          _sectionWrapper(isDark,
              child: LandingStatsSection(isDark: isDark)),
          _sectionWrapper(isDark,
              child: LandingAboutSection(isDark: isDark)),
          _sectionWrapper(isDark,
              child: LandingFeaturesSection(isDark: isDark)),
          _sectionWrapper(isDark,
              child: LandingWorldDataSection(isDark: isDark)),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _sectionWrapper(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
      child: child,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOBİL OVERLAY
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMobileOverlay(bool isDark) {
    return PageView(
      controller: _mobilePageCtrl,
      children: [
        _buildMobileStatsPage(isDark),
        _buildMobileMapPage(isDark),
        _buildMobileAuthPage(isDark),
      ],
    );
  }

  Widget _buildMobileStatsPage(bool isDark) {
    return Container(
      color: (isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA))
          .withValues(alpha: 1.0),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 24),
          child: Column(
            children: [
              LandingStatsSection(isDark: isDark, compact: true),
              const SizedBox(height: 24),
              LandingAboutSection(isDark: isDark, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMapPage(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _swipeHint(Icons.arrow_back_ios, 'İstatistikler', isDark),
                  _swipeHint(Icons.arrow_forward_ios, 'Giriş Yap', isDark),
                ],
              ),
              const SizedBox(height: 16),
              LandingFeaturesSection(isDark: isDark, compact: true),
              const SizedBox(height: 24),
              LandingWorldDataSection(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAuthPage(bool isDark) {
    return Container(
      color: (isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA))
          .withValues(alpha: 1.0),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AuthDropdown(
              isDark: isDark,
              initialPage: _authPage,
              onClose: () => _mobilePageCtrl.animateToPage(1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut),
              onAuthSuccess: _onAuthSuccess,
              onGuestContinue: _continueAsGuest,
              embedded: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeHint(IconData icon, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ÜST BAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 8, 24, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA))
                .withValues(alpha: 0.95),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          _buildLogo(isDark),
          const Spacer(),
          TextButton(
            onPressed: _continueAsGuest,
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Keşfet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          _buildTextButton('Giriş Yap',
              onTap: () => _openAuth(page: 0), isDark: isDark),
          const SizedBox(width: 10),
          _buildPrimaryButton('Kayıt Ol',
              onTap: () => _openAuth(page: 1)),
        ],
      ),
    );
  }

  Widget _buildMobileTopBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 4, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA))
                .withValues(alpha: 0.95),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          _buildLogo(isDark, compact: true),
          const Spacer(),
          _buildTextButton('Giriş', onTap: () {
            _mobilePageCtrl.animateToPage(2,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }, isDark: isDark, compact: true),
          const SizedBox(width: 6),
          _buildPrimaryButton('Kayıt Ol', onTap: () {
            _authPage = 1;
            _mobilePageCtrl.animateToPage(2,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }, compact: true),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ORTAK WIDGET'LAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLogo(bool isDark, {bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 36 : 44,
          height: compact ? 36 : 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF3B82F6)]),
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.bolt_rounded,
              color: Colors.white, size: compact ? 20 : 24),
        ),
        SizedBox(width: compact ? 8 : 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SRRP',
                style: TextStyle(
                  fontSize: compact ? 20 : 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  letterSpacing: 1.5,
                )),
            if (!compact)
              Text('Akıllı Yenilenebilir Kaynak Planlayıcısı',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  )),
          ],
        ),
      ],
    );
  }

  Widget _buildTextButton(String label,
      {required VoidCallback onTap,
      required bool isDark,
      bool compact = false}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: isDark ? Colors.white70 : Colors.black54,
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16, vertical: compact ? 6 : 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.12)),
        ),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: compact ? 13 : 15, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildPrimaryButton(String label,
      {required VoidCallback onTap, bool compact = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 20, vertical: compact ? 8 : 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 13 : 15,
              )),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Landing harita — read-only MapLibre vitrin
// Etkileşim kapalı: sürüklenemez, zoom yapılamaz.
// Gerçekçi YEK tesisleri ve katmanlar ile Türkiye enerji haritası.
// ═══════════════════════════════════════════════════════════════════
class _LandingMap extends StatefulWidget {
  const _LandingMap();

  @override
  State<_LandingMap> createState() => _LandingMapState();
}

class _LandingMapState extends State<_LandingMap> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Harita yüklenene kadar bekle, sonra vitrin modunu kur
    _waitForMapAndSetup();
  }

  @override
  void dispose() {
    // 2026-06-05 (TÜRKİYE-ONLY bounds): Landing harita etkileşimini KAPATIYOR
    // (dekoratif arka plan). /map'e geçerken etkileşim AÇILMALI. Sınır (maxBounds)
    // ARTIK her zaman Türkiye — JS default'u her style.load'da uyguluyor, burada
    // dokunmuyoruz (eski clearMaxBounds kaldırıldı; harita Türkiye-kilitli kalır).
    MapViewMapLibre.setInteractive(true);
    super.dispose();
  }

  /// Harita hazır olana kadar bekler, sonra vitrin modunu kurar.
  void _waitForMapAndSetup() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || _initialized) return;
      _initialized = true;

      // 1. Etkileşimi kapat (dekoratif arka plan — sürüklenemez, zoom yapılamaz)
      MapViewMapLibre.setInteractive(false);

      // 2. (Türkiye sınırı artık JS default'unda — her style.load'da otomatik
      //    uygulanıyor; burada ayrıca setMaxBounds çağırmaya gerek yok.)

      // 3. Vitrin pinlerini yükle (tema-duyarlı renklerle)
      bool isDark = true;
      if (mounted) {
        try {
          isDark = Provider.of<ThemeViewModel>(context, listen: false).isDarkMode;
        } catch (_) {}
      }
      // 2026-06-04: Vitrin pin verisi paylaşımlı showcase_pins.dart'a taşındı
      // (misafir Keşfet modu da aynı kaynağı kullanıyor).
      // 2026-06-10 (çökme fix): Landing dekoratif/misafir yüzey → showcase
      // guard'ını aç (logout→landing sonrası _loggedIn stale-true kalıp vitrini
      // bastırmasın). /map'e geçilince orada auth'a göre tekrar set edilir.
      MapViewMapLibre.setLoggedIn(false);
      MapViewMapLibre.setShowcasePins(buildShowcaseGeoJson(isDark: isDark));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MapViewMapLibre();
  }
}

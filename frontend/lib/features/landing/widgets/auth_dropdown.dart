import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/auth/viewmodels/auth_viewmodel.dart';

/// Sağ üstten açılan Auth paneli — Giriş ↔ Kayıt geçişli.
/// [embedded] = true ise mobil sayfada doğrudan gömülü kullanılır (backdrop yok).
class AuthDropdown extends StatefulWidget {
  final bool isDark;
  final int initialPage;
  final VoidCallback onClose;
  final VoidCallback onAuthSuccess;
  final VoidCallback onGuestContinue;
  final bool embedded;

  const AuthDropdown({
    super.key,
    required this.isDark,
    this.initialPage = 0,
    required this.onClose,
    required this.onAuthSuccess,
    required this.onGuestContinue,
    this.embedded = false,
  });

  @override
  State<AuthDropdown> createState() => _AuthDropdownState();
}

class _AuthDropdownState extends State<AuthDropdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  late final PageController _pageController;
  late int _currentPage;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emailFocus = FocusNode();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideController.forward();

    // Otomatik focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pageController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _switchPage(int page) {
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Lütfen e-posta ve şifre giriniz.');
      return;
    }

    setState(() => _errorMessage = null);
    final auth = Provider.of<AuthViewModel>(context, listen: false);

    try {
      if (_currentPage == 0) {
        await auth.login(email, password);
      } else {
        if (password != _confirmCtrl.text.trim()) {
          setState(() => _errorMessage = 'Şifreler eşleşmiyor.');
          return;
        }
        await auth.register(email, password);
        await auth.login(email, password);
      }
      if (mounted) widget.onAuthSuccess();
    } catch (e) {
      if (!mounted) return;
      final msg = auth.errorMessage ??
          e.toString().replaceAll('Exception:', '').trim();
      setState(() => _errorMessage = msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildCard();
    return _buildOverlay();
  }

  /// Web: Backdrop + sağ üstten kayan panel
  Widget _buildOverlay() {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: widget.onClose,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),

        // Panel — sağ üstten kayar
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          right: 24,
          child: SlideTransition(
            position: _slideAnim,
            child: _buildCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    final isDark = widget.isDark;
    final width = widget.embedded
        ? double.infinity
        : (MediaQuery.of(context).size.width > 600 ? 400.0 : 340.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.embedded ? null : width,
        constraints: widget.embedded
            ? const BoxConstraints(maxWidth: 420)
            : null,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1F2E).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tab bar
                  _buildTabBar(isDark),
                  const SizedBox(height: 20),
                  // Hata mesajı
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.redAccent.shade100
                                    : Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Form sayfaları
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: _currentPage == 0 ? 230 : 290,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      children: [
                        _buildLoginForm(isDark),
                        _buildRegisterForm(isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Misafir
                  TextButton(
                    onPressed: widget.onGuestContinue,
                    child: Text(
                      'Giriş Yapmadan Devam Et',
                      style: TextStyle(
                        color: isDark ? Colors.white30 : Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _buildTab('Giriş Yap', 0, isDark)),
          Expanded(child: _buildTab('Kayıt Ol', 1, isDark)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, bool isDark) {
    final isActive = _currentPage == index;
    final activeColor =
        index == 0 ? const Color(0xFF3B82F6) : const Color(0xFF22C55E);
    return GestureDetector(
      onTap: () => _switchPage(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(bool isDark) {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) => SingleChildScrollView(
        child: Column(
          children: [
            _field(_emailCtrl, 'E-posta', Icons.email_outlined, isDark,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                onSubmit: (_) => _submit()),
            const SizedBox(height: 14),
            _field(_passwordCtrl, 'Şifre', Icons.lock_outline, isDark,
                isPassword: true, onSubmit: (_) => _submit()),
            const SizedBox(height: 24),
            _submitBtn(auth, 'Giriş Yap', const Color(0xFF3B82F6)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text('Şifremi Unuttum',
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 12,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm(bool isDark) {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) => SingleChildScrollView(
        child: Column(
          children: [
            _field(_emailCtrl, 'E-posta', Icons.email_outlined, isDark,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _field(_passwordCtrl, 'Şifre', Icons.lock_outline, isDark,
                isPassword: true),
            const SizedBox(height: 14),
            _field(_confirmCtrl, 'Şifre Tekrar', Icons.lock_reset, isDark,
                isPassword: true, onSubmit: (_) => _submit()),
            const SizedBox(height: 24),
            _submitBtn(auth, 'Kayıt Ol', const Color(0xFF22C55E)),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    bool isDark, {
    bool isPassword = false,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: TextField(
        controller: ctrl,
        focusNode: focusNode,
        obscureText: isPassword,
        keyboardType: keyboardType,
        onSubmitted: onSubmit,
        textInputAction:
            onSubmit != null ? TextInputAction.go : TextInputAction.next,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          prefixIcon:
              Icon(icon, color: isDark ? Colors.white54 : Colors.black45),
          hintText: hint,
          hintStyle:
              TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _submitBtn(AuthViewModel auth, String label, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: auth.isBusy ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: auth.isBusy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:frontend/shared/widgets/glass_container.dart';

/// Glassmorphic auth modal — PageView ile Giriş ↔ Kayıt swipe
class AuthModal extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onAuthSuccess;
  final VoidCallback onGuestContinue;
  final bool isDark;

  const AuthModal({
    super.key,
    required this.onClose,
    required this.onAuthSuccess,
    required this.onGuestContinue,
    required this.isDark,
  });

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  final _pageController = PageController();
  int _currentPage = 0; // 0 = giriş, 1 = kayıt

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Lutfen e-posta ve sifre giriniz.', Colors.orange);
      return;
    }

    final auth = Provider.of<AuthViewModel>(context, listen: false);

    try {
      if (_currentPage == 0) {
        await auth.login(email, password);
      } else {
        if (password != _confirmController.text.trim()) {
          _showSnack('Sifreler eslesmiyor.', Colors.orange);
          return;
        }
        await auth.register(email, password);
        await auth.login(email, password);
      }
      if (mounted) widget.onAuthSuccess();
    } catch (e) {
      if (!mounted) return;
      final msg =
          auth.errorMessage ?? e.toString().replaceAll('Exception:', '').trim();
      _showSnack('Hata: $msg', Colors.red);
    }
  }

  void _showSnack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;
    final modalWidth = isWide ? 420.0 : size.width * 0.92;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // Arka plan blur + tap to close
          GestureDetector(
            onTap: widget.onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),

          // Modal
          Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: GlassContainer(
                width: modalWidth,
                padding: const EdgeInsets.all(28),
                borderRadius: 24,
                blur: 16,
                color: (widget.isDark
                        ? const Color(0xFF1E232F)
                        : Colors.white)
                    .withValues(alpha: 0.85),
                border: Border.all(
                  color: (widget.isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tab bar
                    _buildTabBar(),
                    const SizedBox(height: 24),

                    // PageView
                    SizedBox(
                      height: _currentPage == 0 ? 240 : 300,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        children: [
                          _buildLoginForm(),
                          _buildRegisterForm(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Misafir butonu
                    TextButton(
                      onPressed: widget.onGuestContinue,
                      child: Text(
                        'Giris Yapmadan Devam Et',
                        style: TextStyle(
                          color: widget.isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: (widget.isDark ? Colors.white : Colors.black)
            .withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _buildTab('Giris Yap', 0)),
          Expanded(child: _buildTab('Kayit Ol', 1)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _currentPage == index;
    return GestureDetector(
      onTap: () => _switchPage(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF3B82F6).withValues(alpha: 0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (widget.isDark ? Colors.white60 : Colors.black54),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) => SingleChildScrollView(
        child: Column(
          children: [
            _buildField(_emailController, 'E-posta', Icons.email_outlined),
            const SizedBox(height: 14),
            _buildField(_passwordController, 'Sifre', Icons.lock_outline,
                isPassword: true),
            const SizedBox(height: 24),
            _buildSubmitButton(auth, 'Giris Yap', const Color(0xFF3B82F6)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text(
                  'Sifremi Unuttum',
                  style: TextStyle(
                    color: widget.isDark ? Colors.white30 : Colors.black38,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) => SingleChildScrollView(
        child: Column(
          children: [
            _buildField(_emailController, 'E-posta', Icons.email_outlined),
            const SizedBox(height: 14),
            _buildField(_passwordController, 'Sifre', Icons.lock_outline,
                isPassword: true),
            const SizedBox(height: 14),
            _buildField(
                _confirmController, 'Sifre Tekrar', Icons.lock_reset,
                isPassword: true),
            const SizedBox(height: 24),
            _buildSubmitButton(auth, 'Kayit Ol', const Color(0xFF22C55E)),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: (widget.isDark ? Colors.white : Colors.black)
            .withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (widget.isDark ? Colors.white : Colors.black)
              .withValues(alpha: 0.08),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon,
              color: widget.isDark ? Colors.white54 : Colors.black45),
          hintText: hint,
          hintStyle: TextStyle(
            color: widget.isDark ? Colors.white38 : Colors.black38,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(AuthViewModel auth, String label, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: auth.isBusy ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

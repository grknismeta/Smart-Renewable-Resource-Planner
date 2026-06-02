import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/viewmodels/auth_viewmodel.dart';

/// HESABIM (2026-06-02): Hesap ayarları diyaloğu.
/// - Ad-soyad görüntüle/düzenle (PATCH /users/me)
/// - E-posta (salt-okunur — login anahtarı)
/// - Parola değiştir (POST /users/me/change-password)
/// - Çıkış yap
class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AccountDialog(),
    );
  }

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final _nameCtrl = TextEditingController();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _loading = true;
  bool _savingName = false;
  bool _changingPw = false;
  bool _showPasswordSection = false;
  String? _msg;
  Color _msgColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthViewModel>(context, listen: false);
    await auth.fetchMe();
    if (!mounted) return;
    _nameCtrl.text = auth.fullName ?? '';
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  void _flash(String text, Color color) {
    setState(() {
      _msg = text;
      _msgColor = color;
    });
  }

  Future<void> _saveName() async {
    final auth = Provider.of<AuthViewModel>(context, listen: false);
    setState(() {
      _savingName = true;
      _msg = null;
    });
    try {
      await auth.updateName(_nameCtrl.text.trim());
      _flash('Ad soyad güncellendi.', Colors.green);
    } catch (e) {
      _flash(e.toString().replaceAll('Exception:', '').trim(), Colors.redAccent);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    final auth = Provider.of<AuthViewModel>(context, listen: false);
    final cur = _currentPwCtrl.text;
    final neu = _newPwCtrl.text;
    final conf = _confirmPwCtrl.text;
    if (cur.isEmpty || neu.isEmpty) {
      _flash('Mevcut ve yeni parolayı girin.', Colors.orange);
      return;
    }
    if (neu.length < 8) {
      _flash('Yeni parola en az 8 karakter olmalı.', Colors.orange);
      return;
    }
    if (neu != conf) {
      _flash('Yeni parolalar eşleşmiyor.', Colors.orange);
      return;
    }
    setState(() {
      _changingPw = true;
      _msg = null;
    });
    try {
      await auth.changePassword(cur, neu);
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      _flash('Parola değiştirildi.', Colors.green);
      if (mounted) setState(() => _showPasswordSection = false);
    } catch (e) {
      _flash(e.toString().replaceAll('Exception:', '').trim(), Colors.redAccent);
    } finally {
      if (mounted) setState(() => _changingPw = false);
    }
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthViewModel>(context, listen: false);
    final nav = Navigator.of(context);
    await auth.logout();
    nav.pop(); // diyaloğu kapat
    nav.pushNamedAndRemoveUntil('/landing', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final auth = Provider.of<AuthViewModel>(context);

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                const Color(0xFF22C55E).withValues(alpha: 0.18),
                            child: const Icon(Icons.person,
                                color: Color(0xFF22C55E)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hesabım',
                                    style: TextStyle(
                                        color: theme.textColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                Text(auth.email ?? '',
                                    style: TextStyle(
                                        color: theme.secondaryTextColor,
                                        fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: theme.secondaryTextColor),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Mesaj ──
                      if (_msg != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _msgColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _msgColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(_msg!,
                              style: TextStyle(color: _msgColor, fontSize: 13)),
                        ),
                      ],

                      // ── Ad Soyad ──
                      _label('Ad Soyad', theme),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _field(_nameCtrl, 'Ad Soyad', theme,
                                icon: Icons.badge_outlined),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _savingName ? null : _saveName,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _savingName
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Kaydet'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // ── E-posta (salt-okunur) ──
                      _label('E-posta', theme),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: theme.secondaryTextColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.email_outlined,
                                size: 18, color: theme.secondaryTextColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(auth.email ?? '',
                                  style: TextStyle(color: theme.secondaryTextColor)),
                            ),
                            Icon(Icons.lock_outline,
                                size: 14, color: theme.secondaryTextColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Parola değiştir (katlanır) ──
                      InkWell(
                        onTap: () => setState(
                            () => _showPasswordSection = !_showPasswordSection),
                        child: Row(
                          children: [
                            Icon(Icons.key_outlined,
                                size: 18, color: theme.textColor),
                            const SizedBox(width: 8),
                            Text('Parola Değiştir',
                                style: TextStyle(
                                    color: theme.textColor,
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Icon(
                                _showPasswordSection
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: theme.secondaryTextColor),
                          ],
                        ),
                      ),
                      if (_showPasswordSection) ...[
                        const SizedBox(height: 10),
                        _field(_currentPwCtrl, 'Mevcut parola', theme,
                            icon: Icons.lock_outline, obscure: true),
                        const SizedBox(height: 10),
                        _field(_newPwCtrl, 'Yeni parola (en az 8)', theme,
                            icon: Icons.lock_reset, obscure: true),
                        const SizedBox(height: 10),
                        _field(_confirmPwCtrl, 'Yeni parola (tekrar)', theme,
                            icon: Icons.lock_reset, obscure: true),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _changingPw ? null : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _changingPw
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Parolayı Güncelle'),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Divider(color: theme.borderColor),
                      const SizedBox(height: 4),

                      // ── Çıkış ──
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          label: const Text('Çıkış Yap',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _label(String text, ThemeViewModel theme) => Text(text,
      style: TextStyle(
          color: theme.secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w600));

  Widget _field(
    TextEditingController ctrl,
    String hint,
    ThemeViewModel theme, {
    IconData? icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: theme.secondaryTextColor)
            : null,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        filled: true,
        fillColor: theme.secondaryTextColor.withValues(alpha: 0.07),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }
}

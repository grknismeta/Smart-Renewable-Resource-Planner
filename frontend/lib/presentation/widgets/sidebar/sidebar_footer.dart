import 'package:flutter/material.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';

/// Sidebar alt kısmı - Tema değiştirme, yardım ve çıkış butonları
class SidebarFooter extends StatelessWidget {
  final ThemeProvider theme;
  final AuthProvider authProvider;
  final bool isCollapsed;

  const SidebarFooter({
    super.key,
    required this.theme,
    required this.authProvider,
    required this.isCollapsed,
  });

  bool get isGuest => authProvider.isLoggedIn != true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.secondaryTextColor.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // Tema değiştirme
          _buildThemeToggle(),

          // Yardım
          _buildMenuItem(
            icon: Icons.help_outline,
            label: "Yardım",
            color: theme.secondaryTextColor,
            onTap: () {},
          ),

          // Giriş/Çıkış
          _buildAuthButton(context),
        ],
      ),
    );
  }

  Widget _buildThemeToggle() {
    return InkWell(
      onTap: theme.toggleTheme,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              theme.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: theme.secondaryTextColor,
              size: 22,
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  theme.isDarkMode ? "Karanlık Mod" : "Aydınlık Mod",
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(
                height: 24,
                child: Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: theme.isDarkMode,
                    onChanged: (val) => theme.toggleTheme(),
                    activeColor: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16),
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: isCollapsed
          ? null
          : Text(
              label,
              style: TextStyle(color: color),
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
    );
  }

  Widget _buildAuthButton(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16),
      dense: true,
      leading: Icon(
        isGuest ? Icons.person_add : Icons.logout,
        color: isGuest ? Colors.greenAccent : Colors.redAccent,
        size: 22,
      ),
      title: isCollapsed
          ? null
          : Text(
              isGuest ? "Kayıt Ol" : "Çıkış Yap",
              style: TextStyle(
                color: isGuest ? Colors.greenAccent : Colors.redAccent,
                fontWeight: isGuest ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
      onTap: () {
        if (isGuest) {
          Navigator.of(context).pushReplacementNamed('/auth');
        } else {
          authProvider.logout();
        }
      },
    );
  }
}

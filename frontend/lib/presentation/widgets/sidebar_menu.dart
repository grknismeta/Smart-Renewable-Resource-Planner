import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'sidebar/sidebar_widgets.dart';

/// Ana sidebar menü widget'ı
/// Modüler alt bileşenlerden oluşur:
/// - SidebarHeader: Logo ve menü butonu
/// - ScenarioButton: Senaryo yönetimi butonu
/// - DataPanel: Kaynak verileri paneli
/// - SidebarFooter: Tema, yardım ve çıkış butonları
class SidebarMenu extends StatefulWidget {
  const SidebarMenu({super.key});

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  bool _isCollapsed = true;

  static const double _collapsedWidth = 70.0;
  static const double _expandedWidth = 280.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);
    final bool isGuest = authProvider.isLoggedIn != true;

    return AnimatedContainer(
      duration: _animationDuration,
      width: _isCollapsed ? _collapsedWidth : _expandedWidth,
      color: theme.backgroundColor,
      curve: Curves.easeInOut,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _expandedWidth,
          maxWidth: _expandedWidth,
          child: Column(
            children: [
              // Header
              SidebarHeader(
                theme: theme,
                isCollapsed: _isCollapsed,
                onToggle: () => setState(() => _isCollapsed = !_isCollapsed),
              ),

              // İçerik
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // Senaryo butonu
                    ScenarioButton(
                      theme: theme,
                      isGuest: isGuest,
                      isCollapsed: _isCollapsed,
                    ),

                    // Dar modda divider
                    if (_isCollapsed) ...[
                      const SizedBox(height: 10),
                      Divider(
                        color: theme.secondaryTextColor.withOpacity(0.1),
                        indent: 5,
                        endIndent: 220,
                      ),
                    ],

                    // Veri paneli
                    DataPanel(
                      theme: theme,
                      mapProvider: mapProvider,
                      isCollapsed: _isCollapsed,
                    ),
                  ],
                ),
              ),

              // Footer
              SidebarFooter(
                theme: theme,
                authProvider: authProvider,
                isCollapsed: _isCollapsed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

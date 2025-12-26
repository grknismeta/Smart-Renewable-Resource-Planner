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
  final bool _isCollapsed = true;

  static const double _collapsedWidth = 70.0;
  static const double _expandedWidth = 280.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);
    final bool isGuest = authProvider.isLoggedIn != true;

    void handleMenuPressed() {
      final mq = MediaQuery.of(context);
      final isLandscape = mq.orientation == Orientation.landscape;
      final isNarrow = mq.size.width < 600;

      // For landscape/tablet show a draggable pull-up sheet,
      // for narrow portrait devices show a full-screen bottom sheet.
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          if (isLandscape && !isNarrow) {
            return DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.2,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Small grabber
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: theme.secondaryTextColor.withValues(
                                  alpha: 0.4,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          ScenarioButton(
                            theme: theme,
                            isGuest: isGuest,
                            isCollapsed: false,
                          ),
                          const SizedBox(height: 10),
                          PinsPanel(
                            theme: theme,
                            mapProvider: mapProvider,
                            isCollapsed: false,
                          ),
                          const SizedBox(height: 10),
                          DataPanel(
                            theme: theme,
                            mapProvider: mapProvider,
                            isCollapsed: false,
                          ),
                          const SizedBox(height: 10),
                          SidebarFooter(
                            theme: theme,
                            authProvider: authProvider,
                            isCollapsed: false,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }

          // Narrow portrait: full height modal
          return Container(
            height: mq.size.height * 0.9,
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // grabber
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.secondaryTextColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        ScenarioButton(
                          theme: theme,
                          isGuest: isGuest,
                          isCollapsed: false,
                        ),
                        const SizedBox(height: 10),
                        PinsPanel(
                          theme: theme,
                          mapProvider: mapProvider,
                          isCollapsed: false,
                        ),
                        const SizedBox(height: 10),
                        DataPanel(
                          theme: theme,
                          mapProvider: mapProvider,
                          isCollapsed: false,
                        ),
                        const SizedBox(height: 10),
                        SidebarFooter(
                          theme: theme,
                          authProvider: authProvider,
                          isCollapsed: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

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
                onToggle: handleMenuPressed,
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

                    const SizedBox(height: 10),

                    InkWell(
                      onTap: () => Navigator.of(context).pushNamed('/reports'),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isCollapsed ? 8 : 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.cardColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.secondaryTextColor.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.assessment,
                              color: Colors.lightBlueAccent,
                            ),
                            if (!_isCollapsed) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Raporlar',
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Pinler Paneli
                    PinsPanel(
                      theme: theme,
                      mapProvider: mapProvider,
                      isCollapsed: _isCollapsed,
                    ),

                    // Dar modda divider
                    if (_isCollapsed) ...[
                      const SizedBox(height: 10),
                      Divider(
                        color: theme.secondaryTextColor.withValues(alpha: 0.1),
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

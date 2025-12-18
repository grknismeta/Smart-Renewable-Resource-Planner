import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sidebar_widgets.dart';
import '../../../providers/map_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';

class SidebarLauncher extends StatelessWidget {
  const SidebarLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);
    final bool isGuest = authProvider.isLoggedIn != true;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: const Icon(Icons.menu),
        color: theme.textColor,
        onPressed: () => _openBottomSheet(
          context,
          theme,
          mapProvider,
          authProvider,
          isGuest,
        ),
      ),
    );
  }

  void _openBottomSheet(
    BuildContext context,
    ThemeProvider theme,
    MapProvider mapProvider,
    AuthProvider authProvider,
    bool isGuest,
  ) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final isNarrow = mq.size.width < 600;

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

        return Container(
          height: mq.size.height * 0.9,
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
}

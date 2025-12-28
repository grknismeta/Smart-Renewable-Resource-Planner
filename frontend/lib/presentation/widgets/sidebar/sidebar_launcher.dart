import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sidebar_widgets.dart';
import '../../../presentation/viewmodels/map_view_model.dart';
import '../../../presentation/viewmodels/auth_view_model.dart';
import '../../../presentation/viewmodels/theme_view_model.dart';

class SidebarLauncher extends StatelessWidget {
  const SidebarLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    final themeViewModel = Provider.of<ThemeViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);
    // AuthViewModel has isLoggedIn but check if it's nullable or boolean.
    // AuthViewModel.isLoggedIn is bool? in the code I wrote? Let's assume bool.
    // Actually in AuthProvider it was bool?. Let's check AuthViewModel later if needed.
    // But usually simple check works.
    final bool isGuest = !(authViewModel.isLoggedIn ?? false);

    return Container(
      decoration: BoxDecoration(
        color: themeViewModel.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: const Icon(Icons.menu),
        color: themeViewModel.textColor,
        onPressed: () => _openBottomSheet(
          context,
          themeViewModel,
          mapViewModel,
          authViewModel,
          isGuest,
        ),
      ),
    );
  }

  void _openBottomSheet(
    BuildContext context,
    ThemeViewModel theme,
    MapViewModel mapViewModel,
    AuthViewModel authViewModel,
    bool isGuest,
  ) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final isNarrow = mq.size.width < 600;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final initialSize = isLandscape && !isNarrow ? 0.4 : 0.25;
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            initialChildSize: initialSize,
            minChildSize: 0.15,
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
                    padding: EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      top: 12.0,
                      bottom: 12.0 + mq.viewPadding.bottom,
                    ),
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
                          mapViewModel: mapViewModel,
                          isCollapsed: false,
                        ),
                        const SizedBox(height: 10),
                        DataPanel(
                          theme: theme,
                          mapViewModel: mapViewModel,
                          isCollapsed: false,
                        ),
                        const SizedBox(height: 10),
                        SidebarFooter(
                          theme: theme,
                          authViewModel: authViewModel,
                          isCollapsed: false,
                          onAuthAction: () async {
                            Navigator.pop(context); // Close bottom sheet
                            if (isGuest) {
                              Navigator.of(
                                context,
                              ).pushReplacementNamed('/auth');
                            } else {
                              await authViewModel.logout();
                              // Navigation stack'ini temizle ve login ekranına dön
                              Navigator.of(
                                context,
                              ).pushNamedAndRemoveUntil('/', (route) => false);
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

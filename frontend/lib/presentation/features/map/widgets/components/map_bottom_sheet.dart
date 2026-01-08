import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui; // Import dart:ui
import '../sidebar/sidebar_widgets.dart'; // Barrel export for DataPanel, ScenarioButton etc.
import '../sidebar/report_button.dart'; // Explicit import if not in barrel? Checked: it's not in barrel list I saw (it had sidebar_header, footer, data, scenario, pins, launcher). Wait, sidebar_widgets.dart didn't list report_button.dart.
import '../../viewmodels/map_view_model.dart';
import '../../../../viewmodels/auth_view_model.dart';
import '../../../../viewmodels/theme_view_model.dart';

class MapBottomSheet extends StatelessWidget {
  const MapBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);
    final bool isGuest = !(authViewModel.isLoggedIn ?? false);
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.03, 
      minChildSize: 0.03,
      maxChildSize: 0.6,
      snap: true,
      snapSizes: const [0.03, 0.4, 0.6],
      builder: (context, scrollController) {
        return ScrollConfiguration(
           behavior: ScrollConfiguration.of(context).copyWith(
             dragDevices: {
               ui.PointerDeviceKind.touch,
               ui.PointerDeviceKind.mouse,
               ui.PointerDeviceKind.trackpad,
             },
           ),
           child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.98),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. The "Handle" Area - Draggable
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.secondaryTextColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  
                  // 2. Content
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 4.0,
                      bottom: 12.0 + mq.viewPadding.bottom,
                    ),
                    child: Column(
                      children: [
                        // Top Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ScenarioButton(
                                theme: theme,
                                isGuest: isGuest,
                                isCollapsed: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ReportButton(
                                theme: theme,
                                isCollapsed: false,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        DataPanel(
                          theme: theme,
                          mapViewModel: mapViewModel,
                          isCollapsed: false,
                        ),
                        const SizedBox(height: 16),
                        PinsPanel(
                          theme: theme,
                          mapViewModel: mapViewModel,
                          isCollapsed: false,
                        ),
                        const SizedBox(height: 16),
                        SidebarFooter(
                          theme: theme,
                          authViewModel: authViewModel,
                          isCollapsed: false,
                          onAuthAction: () async {
                            if (isGuest) {
                              Navigator.of(context).pushReplacementNamed('/auth');
                            } else {
                              await authViewModel.logout();
                              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:ui' as ui; // Import dart:ui
import 'package:frontend/features/map/widgets/panels/sidebar/sidebar_widgets.dart'; // Barrel export for DataPanel, ScenarioButton etc.
import 'package:frontend/features/map/widgets/panels/sidebar/report_button.dart'; // Explicit import if not in barrel? Checked: it's not in barrel list I saw (it had sidebar_header, footer, data, scenario, pins, launcher). Wait, sidebar_widgets.dart didn't list report_button.dart.
import 'package:frontend/features/map/viewmodels/map_view_model.dart';
import 'package:frontend/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:frontend/core/theme/theme_view_model.dart';

class MapBottomSheet extends StatefulWidget {
  final VoidCallback? onScenariosTap;

  const MapBottomSheet({super.key, this.onScenariosTap});

  @override
  State<MapBottomSheet> createState() => _MapBottomSheetState();
}

class _MapBottomSheetState extends State<MapBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshSpinController;

  @override
  void initState() {
    super.initState();
    _refreshSpinController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _refreshSpinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);
    final bool isGuest = !(authViewModel.isLoggedIn ?? false);
    final mq = MediaQuery.of(context);

    // Refresh animasyonu senkronize
    if (mapViewModel.isRefreshing) {
      _refreshSpinController.repeat();
    } else {
      _refreshSpinController.stop();
      _refreshSpinController.reset();
    }

    // Mobilde biraz daha büyük başlangıç boyutu (handle görünür olsun)
    final isMobile = mq.size.width < 600;
    final minSize = isMobile ? 0.05 : 0.03;

    return DraggableScrollableSheet(
      initialChildSize: minSize,
      minChildSize: minSize,
      maxChildSize: 0.6,
      snap: true,
      snapSizes: [minSize, 0.4, 0.6],
      builder: (context, scrollController) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              ui.PointerDeviceKind.touch,
              ui.PointerDeviceKind.mouse,
              ui.PointerDeviceKind.trackpad,
            },
          ),
          child: PointerInterceptor(child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.98),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
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
                                onTap: widget.onScenariosTap,
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
                        const SizedBox(height: 12),
                        // Verileri Güncelle butonu
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: mapViewModel.isRefreshing
                                ? null
                                : () => mapViewModel.refreshAllWeatherData(),
                            icon: RotationTransition(
                              turns: _refreshSpinController,
                              child: Icon(
                                Icons.refresh,
                                size: 18,
                                color: mapViewModel.isRefreshing
                                    ? theme.secondaryTextColor
                                    : Colors.blueAccent,
                              ),
                            ),
                            label: Text(
                              mapViewModel.isRefreshing
                                  ? 'Güncelleniyor...'
                                  : 'Verileri Güncelle',
                              style: TextStyle(
                                color: mapViewModel.isRefreshing
                                    ? theme.secondaryTextColor
                                    : Colors.blueAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.blueAccent.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SidebarFooter(
                          theme: theme,
                          authViewModel: authViewModel,
                          isCollapsed: false,
                          onAuthAction: () async {
                            if (!isGuest) {
                              await authViewModel.logout();
                            }
                            if (!context.mounted) return;
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/landing',
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ),
        );
      },
    );
  }
}

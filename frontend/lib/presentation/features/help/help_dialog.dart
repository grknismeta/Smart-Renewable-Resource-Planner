import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/theme_view_model.dart';

// Tab Modules
import 'tabs/overview_tab.dart';
import 'tabs/map_help_tab.dart';
import 'tabs/scenario_help_tab.dart';
import 'tabs/reports_help_tab.dart';

class HelpDialog extends StatefulWidget {
  const HelpDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const HelpDialog(),
    );
  }

  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Tab> _tabs = [
    const Tab(text: 'Genel Bakış'),
    const Tab(text: 'Harita'),
    const Tab(text: 'Senaryolar'),
    const Tab(text: 'Raporlar'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);

    // Dialog içeriği
    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.secondaryTextColor.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.help_outline, color: theme.textColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Yardım Merkezi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: theme.textColor,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: theme.backgroundColor.withOpacity(0.5),
              child: TabBar(
                controller: _tabController,
                tabs: _tabs,
                labelColor: theme.textColor,
                unselectedLabelColor: theme.secondaryTextColor,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  OverviewTab(theme: theme),
                  MapHelpTab(theme: theme),
                  ScenarioHelpTab(theme: theme),
                  ReportsHelpTab(theme: theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

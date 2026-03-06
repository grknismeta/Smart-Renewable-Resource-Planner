import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/shared/widgets/app_background.dart';
import 'package:frontend/shared/widgets/custom_app_bar.dart';
import 'package:frontend/features/scenarios/widgets/scenario_card.dart';
import 'package:frontend/features/scenarios/dialogs/scenario_create_dialog.dart';
import 'package:frontend/features/scenarios/dialogs/scenario_detail_dialog.dart';
import 'package:frontend/shared/widgets/state_widgets.dart';

class ScenarioScreen extends StatefulWidget {
  const ScenarioScreen({super.key});

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final sp = Provider.of<ScenarioViewModel>(context, listen: false);
      sp.loadScenarios();
    });
  }

  void _showCreateDialog(
    BuildContext context,
    ThemeViewModel theme, {
    Scenario? scenarioToEdit,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ScenarioCreateDialog(
        theme: theme,
        scenarioToEdit: scenarioToEdit,
      ),
    );
  }

  void _showScenarioDetail(Scenario scenario, ThemeViewModel theme) {
    showDialog(
      context: context,
      builder: (ctx) => ScenarioDetailDialog(
        scenario: scenario,
        theme: theme,
        onEdit: () {
          _showCreateDialog(context, theme, scenarioToEdit: scenario);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = Provider.of<ThemeViewModel>(context);
    final scenarioViewModel = Provider.of<ScenarioViewModel>(context);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(themeViewModel),
              Expanded(
                child: scenarioViewModel.isBusy
                    ? const Center(child: CircularProgressIndicator())
                    : scenarioViewModel.hasError
                        ? ErrorState(
                            message: scenarioViewModel.errorMessage ?? 'Senaryolar yüklenemedi',
                            onRetry: () => scenarioViewModel.loadScenarios(),
                          )
                        : scenarioViewModel.scenarios.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.science_outlined,
                                      size: 80,
                                      color: themeViewModel.secondaryTextColor.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Henüz senaryo yok',
                                      style: TextStyle(color: themeViewModel.secondaryTextColor, fontSize: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Yeni bir senaryo oluşturmak için + tuşuna basın',
                                      style: TextStyle(
                                        color: themeViewModel.secondaryTextColor.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: scenarioViewModel.scenarios.length,
                                itemBuilder: (context, index) {
                                  final scenario = scenarioViewModel.scenarios[index];
                                  return ScenarioCard(
                                    scenario: scenario,
                                    theme: themeViewModel,
                                    onTap: () => _showScenarioDetail(scenario, themeViewModel),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () => _showCreateDialog(context, themeViewModel),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(ThemeViewModel theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: CustomAppBar(
        title: 'Senaryolar',
        textColor: theme.textColor,
        onBack: () => Navigator.of(context).pushReplacementNamed('/map'),
        actions: [
          Tooltip(
            message: 'Senaryo Karşılaştır',
            child: IconButton(
              icon: const Icon(Icons.compare_arrows_rounded, color: Colors.blueAccent),
              onPressed: () => Navigator.of(context).pushReplacementNamed('/scenarios/compare'),
            ),
          ),
        ],
      ),
    );
  }
}

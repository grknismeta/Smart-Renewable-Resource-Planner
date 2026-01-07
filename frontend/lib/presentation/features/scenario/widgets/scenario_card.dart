import 'package:flutter/material.dart';

import '../../../../data/models/scenario_model.dart';
import '../../../../presentation/viewmodels/theme_view_model.dart';
import '../../../widgets/common/glass_container.dart';

class ScenarioCard extends StatelessWidget {
  final Scenario scenario;
  final ThemeViewModel theme;
  final VoidCallback onTap;

  const ScenarioCard({
    super.key,
    required this.scenario,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = scenario.startDate != null && scenario.endDate != null
        ? scenario.endDate!.difference(scenario.startDate!).inDays
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: 16,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Colors.blueAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.name,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (scenario.description != null)
                      Text(
                        scenario.description!,
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      duration > 0
                          ? '$duration gün · ${scenario.pinIds.length} kaynak'
                          : '${scenario.pinIds.length} kaynak',
                      style: TextStyle(
                        color: theme.secondaryTextColor.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }
}

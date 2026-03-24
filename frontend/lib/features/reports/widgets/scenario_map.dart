import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

class ScenarioMapInReport extends StatelessWidget {
  final int scenarioId;

  const ScenarioMapInReport({
    super.key,
    required this.scenarioId,
  });

  @override
  Widget build(BuildContext context) {
    final scenarioViewModel = Provider.of<ScenarioViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);
    final scenario = scenarioViewModel.scenarios.firstWhere(
      (s) => s.id == scenarioId,
      orElse: () => scenarioViewModel.scenarios.first,
    );
    final scenarioPins = mapViewModel.pins
        .where((p) => scenario.pinIds.contains(p.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text('${scenario.name} - Kaynaklar',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text('${scenarioPins.length} kaynak',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: scenarioPins.isEmpty
              ? const Center(child: Text('Pin bulunamadı', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: scenarioPins.length,
                  itemBuilder: (context, i) {
                    final pin = scenarioPins[i];
                    final color = pin.type == 'Güneş Paneli'
                        ? Colors.orangeAccent
                        : pin.type == 'HES'
                            ? Colors.cyanAccent
                            : Colors.blueAccent;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(pin.type == 'Güneş Paneli' ? Icons.wb_sunny
                              : pin.type == 'HES' ? Icons.waves : Icons.wind_power,
                            color: color, size: 16),
                          const SizedBox(width: 10),
                          Expanded(child: Text(pin.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13))),
                          Text(pin.type,
                              style: TextStyle(color: color, fontSize: 11)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

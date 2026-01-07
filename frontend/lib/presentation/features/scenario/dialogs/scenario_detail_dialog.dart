import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/format_utils.dart';
import '../../../../data/models/scenario_model.dart';
import '../viewmodels/scenario_view_model.dart';
import '../../../../presentation/viewmodels/theme_view_model.dart';

class ScenarioDetailDialog extends StatelessWidget {
  final Scenario scenario;
  final ThemeViewModel theme;
  final VoidCallback onEdit;

  const ScenarioDetailDialog({
    super.key,
    required this.scenario,
    required this.theme,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              scenario.name,
              style: TextStyle(color: theme.textColor),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: theme.secondaryTextColor),
            onPressed: () {
              Navigator.pop(context);
              onEdit();
            },
            tooltip: "Düzenle",
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scenario.description != null) ...[
              Text(
                scenario.description!,
                style: TextStyle(color: theme.secondaryTextColor),
              ),
              const SizedBox(height: 16),
            ],
            if (scenario.startDate != null)
              _InfoRow(
                'Başlangıç',
                '${scenario.startDate!.day}/${scenario.startDate!.month}/${scenario.startDate!.year}',
                theme,
              ),
            if (scenario.endDate != null)
              _InfoRow(
                'Bitiş',
                '${scenario.endDate!.day}/${scenario.endDate!.month}/${scenario.endDate!.year}',
                theme,
              ),
            _InfoRow('Pin Sayısı', '${scenario.pinIds.length}', theme),
            if (scenario.pinIds.isNotEmpty)
              _InfoRow('Pin IDler', scenario.pinIds.join(', '), theme),
            const SizedBox(height: 16),
            if (scenario.resultData != null) ...[
              const SizedBox(height: 16),
              Text(
                'Senaryo Özeti:',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildResultSummary(scenario.resultData!, theme),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        if (scenario.startDate != null && scenario.endDate != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final sp = Provider.of<ScenarioViewModel>(
                  context,
                  listen: false,
                );
                // ignore: use_build_context_synchronously
                await sp.calculateScenario(scenario.id);
                // Note: Showing snackbar here might fail if context is unmounted
                // The caller typically shows snackbars
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Senaryo hesaplandı!')),
                  );
                }
              } catch (e) {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hesaplama hatası: $e')),
                  );
                }
              }
            },
            child: const Text(
              'Hesapla',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context).pushReplacementNamed('/reports');
          },
          child: const Text('Rapora Git'),
        ),
      ],
    );
  }

  Widget _buildResultSummary(Map<String, dynamic> data, ThemeViewModel theme) {
    final double totalSolar = (data['total_solar_kwh'] ?? 0).toDouble();
    final double totalWind = (data['total_wind_kwh'] ?? 0).toDouble();
    final double totalEnergy = (data['total_kwh'] ?? 0).toDouble();
    final int solarCount = (data['solar_count'] ?? 0).toInt();
    final int windCount = (data['wind_count'] ?? 0).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildEnergyCard(
                  'Toplam Üretim',
                  FormatUtils.formatEnergy(totalEnergy),
                  Icons.flash_on,
                  Colors.amber,
                  theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEnergyCard(
                  'Güneş ($solarCount)',
                  FormatUtils.formatEnergy(totalSolar),
                  Icons.wb_sunny,
                  Colors.orangeAccent,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEnergyCard(
                  'Rüzgar ($windCount)',
                  FormatUtils.formatEnergy(totalWind),
                  Icons.air,
                  Colors.lightBlueAccent,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyCard(
    String title,
    String value,
    IconData icon,
    Color color,
    ThemeViewModel theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeViewModel theme;

  const _InfoRow(this.label, this.value, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

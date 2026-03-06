import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/pins/widgets/energy_output_widget.dart';
import 'package:frontend/features/map/widgets/panels/financial_output_widget.dart';
import 'package:frontend/features/map/widgets/panels/energy_info_card.dart';

class AnalysisDialog extends StatelessWidget {
  final PinCalculationResponse result;

  const AnalysisDialog({super.key, required this.result});

  static void show(BuildContext context, PinCalculationResponse result) {
    showDialog(
      context: context,
      builder: (_) => AnalysisDialog(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("AnalysisDialog: Building... Result: ${result.resourceType}");
    final theme = Provider.of<ThemeViewModel>(context);
    debugPrint("AnalysisDialog: Theme loaded. CardColor: ${theme.cardColor}");

    // Using Dialog with transparent bg to match previous style (container handles look)
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern Enerji Çıktı Widget'ı
            EnergyOutputWidget(result: result, theme: theme),
            const SizedBox(height: 16),
            // Finansal Analiz
            FinancialOutputWidget(result: result, theme: theme),
            const SizedBox(height: 16),
            // Bakım & Ömür Bilgi Kartı
            EnergyInfoCard(result: result, theme: theme),
            const SizedBox(height: 16),
            // Kapat butonu
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton.icon(
                onPressed: () {
                  Provider.of<MapViewModel>(context, listen: false)
                      .clearCalculationResult();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close),
                label: const Text('Kapat'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
       ),
      ),
    );
  }
}

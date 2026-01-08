import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/pin_model.dart';
import '../../../viewmodels/theme_view_model.dart';
import '../../map/viewmodels/map_view_model.dart';
import '../widgets/energy_output_widget.dart';

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern Enerji Çıktı Widget'ı
            EnergyOutputWidget(result: result, theme: theme),
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
    );
  }
}

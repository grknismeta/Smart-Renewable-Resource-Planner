import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/theme/theme_view_model.dart';

import 'package:frontend/features/map/widgets/dialogs/add_pin_dialog.dart';
import 'package:frontend/features/map/widgets/dialogs/analysis_dialog.dart';
import 'package:frontend/features/map/widgets/dialogs/pin_details_dialog.dart';
export 'add_pin_dialog.dart';
export 'edit_pin_dialog.dart';
export 'pin_details_dialog.dart';
export 'analysis_dialog.dart';
export 'optimization_dialog.dart';

/// Pin ile ilgili tüm dialog işlemlerini yöneten yardımcı sınıf
class MapDialogs {
  MapDialogs._();

  /// Hata dialog'u gösterir
  static void showErrorDialog(BuildContext context, String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Pin aksiyonları için dialog gösterir (New Details Dialog)
  static Future<void> showPinActionsDialog(BuildContext context, Pin pin) {
    return PinDetailsDialog.show(context, pin);
  }

  /// Yeni pin ekleme dialog'u gösterir
  static void showAddPinDialog(
    BuildContext context,
    LatLng point,
    String pinType,
  ) {
    AddPinDialog.show(context, point, pinType);
  }

  /// Hesaplama sonucu dialog'u gösterir
  static void showCalculationResultDialog(
    BuildContext context,
    PinCalculationResponse result,
    ThemeViewModel theme,
  ) {
    AnalysisDialog.show(context, result);
  }
}

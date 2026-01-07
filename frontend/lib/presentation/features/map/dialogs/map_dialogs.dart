import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../data/models/pin_model.dart';
import '../../../../data/models/system_data_models.dart';
import '../../../viewmodels/theme_view_model.dart';
import '../../map/viewmodels/map_view_model.dart';

// Import modular dialogs
import 'add_pin_dialog.dart';
import 'edit_pin_dialog.dart';
import 'analysis_dialog.dart';
export 'add_pin_dialog.dart';
export 'edit_pin_dialog.dart';
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

  /// Pin aksiyonları için bottom sheet gösterir
  static void showPinActionsDialog(BuildContext context, Pin pin) {
    EditPinDialog.show(context, pin);
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

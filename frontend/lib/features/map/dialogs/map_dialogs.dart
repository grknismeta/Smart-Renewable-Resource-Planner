import 'package:flutter/material.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/theme/app_theme.dart';

import 'package:frontend/features/pins/dialogs/analysis_dialog.dart';
export 'package:frontend/features/pins/dialogs/add_pin_dialog.dart';
export 'package:frontend/features/pins/dialogs/pin_details_dialog.dart';
export 'package:frontend/features/pins/dialogs/analysis_dialog.dart';
export 'package:frontend/features/map/dialogs/optimization_dialog.dart';

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

  // (Kaldırıldı 2026-05-08) Eski `showPinActionsDialog` API'si artık yok.
  // PinDetails V2 bottom card pattern'a geçti — `MapScreen._showPinDialog`
  // doğrudan setState ile overlay açar.

  // (Kaldırıldı 2026-05-08) Eski `showAddPinDialog` API'si artık yok.
  // Pin ekleme V2 bottom card pattern'a geçti — `MapScreen._checkGeoSuitability`
  // doğrudan setState ile overlay açar. AddPinDialog widget'ı `Dialog` değil,
  // `Container` (bottom card) — `showDialog` çağrısı kalmadı.

  /// Hesaplama sonucu dialog'u gösterir
  static void showCalculationResultDialog(
    BuildContext context,
    PinCalculationResponse result,
    ThemeViewModel theme,
  ) {
    AnalysisDialog.show(context, result);
  }
}

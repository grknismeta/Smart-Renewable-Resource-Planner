import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Settings dialog
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text('Ayarlar', style: TextStyle(color: theme.textColor)),
      content: SizedBox(
        width: 360,
        child: Text(
          'Ayarlar yakında eklenecek.',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Kapat', style: TextStyle(color: theme.textColor)),
        ),
      ],
    );
  }
}

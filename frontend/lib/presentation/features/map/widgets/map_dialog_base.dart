import 'package:flutter/material.dart';
import '../../../viewmodels/theme_view_model.dart';

class MapDialogHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onClose;
  final ThemeViewModel theme;

  const MapDialogHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onClose,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            color: theme.secondaryTextColor,
          ),
          onPressed: onClose,
        ),
      ],
    );
  }
}

class MapDialogActionButtons extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final String saveLabel;
  final bool isSaving;
  final ThemeViewModel theme;

  const MapDialogActionButtons({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = 'Kaydet',
    this.isSaving = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: theme.secondaryTextColor.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'İptal',
              style: TextStyle(color: theme.textColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    saveLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}

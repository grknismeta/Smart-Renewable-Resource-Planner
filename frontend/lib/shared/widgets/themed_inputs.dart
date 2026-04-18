import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/theme/app_theme.dart';

/// Tema uyumlu text field widget'ı
class ThemedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ThemeViewModel theme;
  final bool isNumber;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;

  const ThemedTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.theme,
    this.isNumber = false,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: theme.textColor),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: inputFormatters ??
          (isNumber
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null),
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.secondaryTextColor),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.secondaryTextColor.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: theme.backgroundColor.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Tema uyumlu dropdown widget'ı
class ThemedDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final String label;
  final ThemeViewModel theme;
  final void Function(T?) onChanged;

  const ThemedDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: theme.cardColor,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.secondaryTextColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.secondaryTextColor.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
        ),
        filled: true,
        fillColor: theme.backgroundColor.withValues(alpha: 0.5),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

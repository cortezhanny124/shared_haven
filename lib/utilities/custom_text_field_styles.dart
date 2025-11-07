import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class CustomTextFieldStyles {
  static InputDecoration textFieldDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
    Color? borderColor, // Optional custom border color
    Widget? suffixIcon, // ✅ Added suffixIcon support
  }) {
    final defaultBorderColor = AppColors.text(context);
    final focusedBorderColor = borderColor ?? AppColors.primary(context);

    return InputDecoration(
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.auto, // Auto-floating label
      labelStyle: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
        color: AppColors.primary(context),
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.bold,
        color: AppColors.text(context),
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 14.0,
        color: Colors.grey.opaque(0.8),
      ),
      filled: true,
      fillColor: AppColors.gradient(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: defaultBorderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: focusedBorderColor, // Use custom or default border color
          width: 2.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: borderColor ?? defaultBorderColor, // Use custom or default
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2.0,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 18.0,
        horizontal: 16.0,
      ),
      suffixIcon: suffixIcon, // ✅ Now supports suffix icons
    );
  }
}

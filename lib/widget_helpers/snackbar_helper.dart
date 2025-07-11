import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class SnackBarHelper {
  static void show(
    BuildContext context, {
    required String message,
    Color? color,
    Color? textColor,
    Duration duration = const Duration(seconds: 1),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor ?? AppColors.text(context)),
        ),
        backgroundColor: color ?? AppColors.gradient(context),
        duration: duration,
      ),
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    Color? color,
    Color? textColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor ?? AppColors.text(context)),
        ),
        backgroundColor: AppColors.error(context),
        duration: duration,
      ),
    );
  }
}

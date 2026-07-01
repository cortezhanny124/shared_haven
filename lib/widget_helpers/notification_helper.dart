import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:overlay_support/overlay_support.dart';

class NotificationHelper {
  static void show(
    BuildContext context, {
    required String message,
    Color? color,
    Color? textColor,
    Duration duration = const Duration(seconds: 5),
  }) {
    showSimpleNotification(
      Text(
        textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
        message,
        style: TextStyle(color: textColor ?? AppColors.text(context)),
      ),
      background: color ?? AppColors.gradient(context),
      autoDismiss: true,
      duration: duration,
      slideDismissDirection: DismissDirection.up,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    Color? color,
    Color? textColor,
    Duration duration = const Duration(seconds: 6),
  }) {
    showSimpleNotification(
      Text(
        textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
        message,
        style: TextStyle(color: textColor ?? AppColors.text(context)),
      ),
      background: color ?? AppColors.error(context),
      autoDismiss: true,
      duration: duration,
      leading: Icon(Icons.error, color: AppColors.text(context)),
      slideDismissDirection: DismissDirection.up,
    );
  }
}

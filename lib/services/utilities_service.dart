import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';

class UtilitiesService {
  /// Copies text to clipboard and shows a SnackBar notification.
  static void copyToClipboard({
    required BuildContext context,
    required String text,
    String? messageKey, // Localization key for the SnackBar message
  }) {
    Clipboard.setData(ClipboardData(text: text));
    if (messageKey != null) {
      SnackBarHelper.show(
        context,
        message: AppLocalizations.of(context)!.translate(messageKey),
      );
    }
  }

  String getAssistantGreetingForRoute(BuildContext context) {
    String? currentRoute = ModalRoute.of(context)?.settings.name;
    final localization = AppLocalizations.of(context)!;

    switch (currentRoute) {
      case '/wallet_page':
        return localization.translate("assistant_welcome");
      case '/ca_wallet_page':
        return localization.translate("assistant_ca_wallet_page");
      case '/pin_setup_page':
        return localization.translate("assistant_pin_setup_page");
      case '/pin_verification_page':
        return localization.translate("assistant_pin_verification_page");
      case '/shared_wallet':
        return localization.translate("assistant_shared_page");
      case '/create_shared':
        return localization.translate("assistant_create_shared");
      case '/import_shared':
        return localization.translate("assistant_import_shared");
      case '/settings':
        return localization.translate("assistant_settings");

      // Default will be used for the ShareWalletPages since they have multiple parameters required and because of that, don't have a route
      default:
        return localization.translate(
            "assistant_shared_wallet"); // "How can I assist you today?"
    }
  }

  List<String> getAssistantTipsForRoute(BuildContext context) {
    String? currentRoute = ModalRoute.of(context)?.settings.name;
    final localization = AppLocalizations.of(context)!;

    switch (currentRoute) {
      case '/wallet_page':
        return [
          localization.translate("assistant_wallet_page_tip1"),
          localization.translate("assistant_wallet_page_tip2"),
          localization.translate("assistant_wallet_page_tip3"),
        ];
      case '/ca_wallet_page':
        return [
          localization.translate("assistant_ca_wallet_page_tip1"),
          localization.translate("assistant_ca_wallet_page_tip2"),
        ];
      case '/pin_setup_page':
        return [
          localization.translate("assistant_pin_setup_page_tip1"),
          localization.translate("assistant_pin_setup_page_tip2"),
        ];
      case '/pin_verification_page':
        return [
          localization.translate("assistant_pin_verify_page_tip1"),
          // localization.translate("assistant_pin_verify_page_tip2"),
        ];
      case '/create_shared':
        return [
          localization.translate("assistant_create_shared_tip1"),
          // localization.translate("assistant_create_shared_tip2"),
          // localization.translate("assistant_create_shared_tip3"),
        ];
      case '/import_shared':
        return [
          localization.translate("assistant_import_shared_tip1"),
          localization.translate("assistant_import_shared_tip2"),
          localization.translate("assistant_import_shared_tip3"),
        ];
      // Default will be used for the ShareWalletPages,
      // since they have multiple parameters required and because of that, don't have a route
      default:
        return [
          localization.translate("assistant_default_tip1"),
          localization.translate("assistant_default_tip2"),
        ];
    }
  }

  static String formatBitcoinAmount(int sats) {
    if (sats < 1000000) {
      return '$sats';
    } else {
      double btc = sats / 100000000;
      return '${btc.toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '')} BTC';
    }
  }
}

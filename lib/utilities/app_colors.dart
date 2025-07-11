import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';

class AppColors {
  static Network _network(BuildContext context) =>
      Provider.of<SettingsProvider>(context, listen: false).network;

  static bool _isTestnet(BuildContext context) =>
      _network(context) == Network.testnet;

  static Color primary(BuildContext context) {
    if (_isTestnet(context)) return Colors.green;
    return Colors.orange;
  }

  static Color lightPrimary(BuildContext context) {
    if (_isTestnet(context)) return Colors.green;
    return Colors.orangeAccent[400]!;
  }

  static Color black() {
    return Colors.black;
  }

  static Color white() {
    return Colors.white;
  }

  static Color darkPrimary(BuildContext context) {
    if (_isTestnet(context)) return Colors.green[600]!;
    return Colors.deepOrange[700]!;
  }

  static Color lightSecondary(BuildContext context) {
    if (_isTestnet(context)) return Colors.green[300]!;
    return Colors.orange[400]!;
  }

  static Color darkSecondary(BuildContext context) {
    if (_isTestnet(context)) return Colors.green[800]!;
    return Colors.deepOrange[900]!;
  }

  static Color unavailableColor = Colors.grey;
  static Color unconfirmedColor = Colors.yellow;

  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimary(context)
        : lightPrimary(context);
  }

  static Color cardTitle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? lightPrimary(context)
        : darkPrimary(context);
  }

  static Color icon(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? lightSecondary(context)
        : darkSecondary(context);
  }

  static Color dialog(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black87
        : Colors.white;
  }

  static Color container(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[850]!
        : Colors.grey[300]!;
  }

  static Color text(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }

  static Color gradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black87
        : Colors.white;
  }

  static Color error(BuildContext context) {
    return Colors.red;
  }

  static Color accent(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimary(context)
        : lightPrimary(context);
  }
}

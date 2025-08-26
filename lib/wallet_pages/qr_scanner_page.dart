import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';

class QRScannerPage extends StatefulWidget {
  final String title;
  final String errorKey;

  const QRScannerPage({
    super.key,
    required this.title,
    this.errorKey = 'invalid_qr_data',
  });

  @override
  QRScannerPageState createState() => QRScannerPageState();
}

class QRScannerPageState extends State<QRScannerPage> {
  String? _lastLog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          AiBarcodeScanner(
            controller: MobileScannerController(
              formats: [BarcodeFormat.qrCode],
            ),
            validator: (capture) {
              try {
                final raw = capture.barcodes.isNotEmpty
                    ? capture.barcodes.first.rawValue
                    : null;
                if (raw == null) return false;
                // Use existing validation in this file
                final extracted = extractBitcoinAddress(raw);
                return extracted != null;
              } catch (_) {
                return false;
              }
            },
            onDetect: (capture) {
              final raw = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first.rawValue
                  : null;
              final extracted = raw != null ? extractBitcoinAddress(raw) : null;
              if (extracted != null) {
                Navigator.of(context).pop(extracted);
              } else {
                final loc = AppLocalizations.of(context);
                final msg = loc!.translate(widget.errorKey);
                SnackBarHelper.showError(context, message: msg);
              }
            },
          ),
          if (_lastLog != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                _lastLog!,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// === Helpers you provided (with prints) ===

String? extractBitcoinAddress(String scannedData) {
  print("[extractBitcoinAddress] Raw scanned data: $scannedData");

  if (scannedData.startsWith('bitcoin:')) {
    final address = scannedData.split(':')[1].split('?')[0];
    print("[extractBitcoinAddress] Detected Bitcoin URI. Extracted: $address");

    final valid = isValidBitcoinAddress(address);
    print("[extractBitcoinAddress] Address valid? $valid");
    return valid ? address : null;
  }

  print("[extractBitcoinAddress] Not a URI, treating as plain address");
  final valid = isValidBitcoinAddress(scannedData);
  print("[extractBitcoinAddress] Address valid? $valid");
  return valid ? scannedData : null;
}

bool isValidBitcoinAddress(String address) {
  print("[isValidBitcoinAddress] Checking: $address");
  final btcAddressRegex =
      RegExp(r'^(bc1|tb1|bcrt1|1|3|m|n|2)[a-zA-HJ-NP-Z0-9]{25,62}$');
  final match = btcAddressRegex.hasMatch(address);
  print("[isValidBitcoinAddress] Match result: $match");
  return match;
}

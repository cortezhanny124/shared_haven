import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  final String title;
  final String errorKey;
  final bool Function(String) isValid;
  final String Function(String) extractValue;

  const QRScannerPage({
    super.key,
    required this.title,
    required this.isValid,
    required this.extractValue,
    this.errorKey = 'invalid_qr_data',
  });

  @override
  QRScannerPageState createState() => QRScannerPageState();
}

class QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Method to handle QR code scanning and extraction
  void _onDetect(BarcodeCapture barcodeCapture) {
    final barcode = barcodeCapture.barcodes.first;
    final String? rawData = barcode.rawValue;

    if (rawData != null && widget.isValid(rawData)) {
      final extracted = widget.extractValue(rawData);
      controller.stop();
      Navigator.pop(context, extracted);
    } else {
      SnackBarHelper.showError(
        context,
        message: AppLocalizations.of(context)!.translate(widget.errorKey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: _onDetect, // Update to match the new signature
      ),
    );
  }
}

// Helper function to extract the Bitcoin address from a QR code
String? extractBitcoinAddress(String scannedData) {
  // print('ScannedData: $scannedData');
  // Check if the scanned data is a Bitcoin URI (e.g., bitcoin:<address>)
  if (scannedData.startsWith('bitcoin:')) {
    // Extract the address by splitting the string on `:` and `?` (ignore any parameters like amount)
    final address = scannedData.split(':')[1].split('?')[0];
    return isValidBitcoinAddress(address) ? address : null;
  }

  // If it's not a Bitcoin URI, check if it's a plain address
  return isValidBitcoinAddress(scannedData) ? scannedData : null;
}

// Helper function to validate a Bitcoin address
bool isValidBitcoinAddress(String address) {
  // Updated regex to handle:
  // - Mainnet: Legacy (1), P2SH (3), Bech32 (bc1)
  // - Testnet: Legacy (m/n), P2SH (2), Bech32 (tb1)
  final btcAddressRegex = RegExp(
    r'^(bc1|tb1|bcrt1|1|3|m|n|2)[a-zA-HJ-NP-Z0-9]{25,62}$',
  );

  return btcAddressRegex.hasMatch(address);
}

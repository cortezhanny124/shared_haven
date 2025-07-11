import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class WalletReceiveHelpers {
  final BuildContext context;
  final void Function(String newAddress)? onNewAddressGenerated;

  WalletReceiveHelpers({
    required this.context,
    required this.onNewAddressGenerated,
  });

  // Method to display the QR code in a dialog
  void showQRCodeDialog(
    WalletService walletService,
    Wallet wallet,
  ) {
    final rootContext = context;

    String address = walletService.getAddress(wallet);

    onNewAddressGenerated?.call(address);

    DialogHelper.buildCustomDialog(
      context: rootContext,
      titleKey: 'receive_bitcoin',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // QR Code Container
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.white(),
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: AppColors.background(context),
                  blurRadius: 8.0,
                  spreadRadius: 2.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: address,
              version: QrVersions.auto,
              size: 180.0,
              backgroundColor: AppColors.white(),
            ),
          ),
          const SizedBox(height: 16),
          // Display the actual address below the QR code
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: SelectableText(
                  address,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.text(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color: AppColors.cardTitle(context),
                ),
                onPressed: () {
                  UtilitiesService.copyToClipboard(
                    context: rootContext,
                    text: address,
                    messageKey: 'address_clipboard',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

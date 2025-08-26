import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_sendtx_helpers.dart';
import 'package:flutter_wallet/wallet_pages/qr_scanner_page.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_receive_helpers.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';

class WalletButtonsHelper {
  final BuildContext context;
  final String address;
  final bool isSingleWallet;
  final WalletSendtxHelpers sendTxHelper;
  final WalletReceiveHelpers receiveHelper;
  final GlobalKey<BaseScaffoldState> baseScaffoldKey;
  final BigInt avBalance;
  final Wallet wallet;
  final WalletService walletService;
  final Set<String> myAddresses;
  final void Function(String newAddress)? onNewAddressGenerated;
  Future<void> Function() syncWallet;

  WalletButtonsHelper({
    required this.context,
    required this.address,
    required this.isSingleWallet,
    required this.baseScaffoldKey,
    required this.avBalance,
    required this.wallet,
    required this.walletService,
    required this.myAddresses,
    required this.onNewAddressGenerated,
    required this.syncWallet,

    // Common Variables
    required TextEditingController recipientController,
    required TextEditingController amountController,
    required bool mounted,
    required String mnemonic,
    required int currentHeight,

    // SharedWallet Variables
    TextEditingController? psbtController,
    TextEditingController? signingAmountController,
    String? descriptor,
    String? descriptorName,
    List<Map<String, String>>? pubKeysAlias,
    Map<String, dynamic>? policy,
    String? myFingerPrint,
    List<dynamic>? utxos,
    List<Map<String, dynamic>>? mySpendingPaths,
    List<Map<String, dynamic>>? spendingPaths,
    List<String>? signersList,
    String? myAlias,
  })  : sendTxHelper = WalletSendtxHelpers(
          isSingleWallet: isSingleWallet,
          context: context,
          recipientController: recipientController,
          psbtController: psbtController,
          signingAmountController: signingAmountController,
          amountController: amountController,
          walletService: walletService,
          policy: policy ?? {},
          myFingerPrint: myFingerPrint ?? '',
          currentHeight: currentHeight,
          utxos: utxos ?? [],
          spendingPaths: mySpendingPaths ?? [],
          descriptor: descriptor ?? '',
          mnemonic: mnemonic,
          mounted: mounted,
          avBalance: avBalance,
          signersList: signersList ?? [],
          pubKeysAlias: pubKeysAlias ?? [],
          wallet: wallet,
          onNewAddressGenerated: onNewAddressGenerated,
          syncWallet: syncWallet,
        ),
        receiveHelper = WalletReceiveHelpers(
          context: context,
          onNewAddressGenerated: onNewAddressGenerated,
        );

  Widget buildButtons() {
    return SafeArea(
      child: Column(
        children: [
          // _buildTopButtons(),
          const SizedBox(height: 16),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  // Widget _buildTopButtons() {
  //   return Wrap(
  //     alignment:
  //         isSingleWallet ? WrapAlignment.center : WrapAlignment.spaceBetween,
  //     spacing: 8, // Adjusts horizontal space between buttons
  //     runSpacing: 8, // Adjusts vertical space if buttons wrap to the next line
  //     children: [
  //       CustomButton(
  //         onPressed: () {
  //           securityHelper.showPinDialog('Your Private Data',
  //               isSingleWallet: isSingleWallet);
  //         },
  //         backgroundColor: AppColors.background(context),
  //         foregroundColor: AppColors.gradient(context),
  //         icon: Icons.remove_red_eye, // Icon for the new button
  //         iconColor: AppColors.gradient(context),
  //         label: AppLocalizations.of(context)!.translate('private_data'),
  //       ),
  //       if (!isSingleWallet)
  //         CustomButton(
  //           onPressed: spendingPathHelpers!.showPathsDialog,
  //           backgroundColor: AppColors.background(context),
  //           foregroundColor: AppColors.gradient(context),
  //           icon: Icons.pattern,
  //           iconColor: AppColors.gradient(context),
  //           label: AppLocalizations.of(context)!.translate('spending_summary'),
  //         ),
  //     ],
  //   );
  // }

  Widget _buildBottomButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Send Button
        GestureDetector(
          onLongPress: () {
            final BaseScaffoldState? baseScaffoldState =
                baseScaffoldKey.currentState;

            if (baseScaffoldState != null) {
              baseScaffoldState.updateAssistantMessage(
                  context, 'assistant_send_button');
            }
          },
          child: CustomButton(
            onPressed: () => sendTxHelper.sendTx(true),
            backgroundColor: AppColors.background(context),
            foregroundColor: AppColors.text(context),
            icon: Icons.arrow_upward,
            iconColor: AppColors.gradient(context),
          ),
        ),

        // Sign PSBT Button
        if (!isSingleWallet)
          GestureDetector(
            onLongPress: () {
              final BaseScaffoldState? baseScaffoldState =
                  baseScaffoldKey.currentState;

              if (baseScaffoldState != null) {
                baseScaffoldState.updateAssistantMessage(
                    context, 'assistant_sign_button');
              }
            },
            child: CustomButton(
              onPressed: () => sendTxHelper.sendTx(false),
              backgroundColor: AppColors.background(context),
              foregroundColor: AppColors.gradient(context),
              icon: Icons.draw,
              iconColor: AppColors.text(context),
            ),
          ),

        // Scan To Send Button
        GestureDetector(
          onLongPress: () {
            final BaseScaffoldState? baseScaffoldState =
                baseScaffoldKey.currentState;

            if (baseScaffoldState != null) {
              baseScaffoldState.updateAssistantMessage(
                  context, 'assistant_scan_button');
            }
          },
          child: CustomButton(
            onPressed: () async {
              print("[ScanButton] Opening QRScannerPage…");
              final recipientAddressStr = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const QRScannerPage(title: 'Scan Bitcoin Address')),
              );
              debugPrint("[ScanButton] pop result: $recipientAddressStr");

              // If a valid Bitcoin address was scanned, show the transaction dialog
              if (recipientAddressStr != null) {
                sendTxHelper.sendTx(
                  true,
                  recipientAddressQr: recipientAddressStr,
                );
              }
            },
            backgroundColor: AppColors.background(context),
            foregroundColor: AppColors.gradient(context),
            icon: Icons.qr_code,
            iconColor: AppColors.text(context),
          ),
        ),

        // Receive Button
        GestureDetector(
          onLongPress: () {
            final BaseScaffoldState? baseScaffoldState =
                baseScaffoldKey.currentState;

            if (baseScaffoldState != null) {
              baseScaffoldState.updateAssistantMessage(
                  context, 'assistant_receive_button');
            }
          },
          child: CustomButton(
            onPressed: () =>
                receiveHelper.showQRCodeDialog(walletService, wallet),
            backgroundColor: AppColors.background(context),
            foregroundColor: AppColors.text(context),
            icon: Icons.arrow_downward,
            iconColor: AppColors.gradient(context),
          ),
        ),
      ],
    );
  }
}

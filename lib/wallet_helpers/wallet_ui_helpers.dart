import 'dart:convert';
import 'dart:io';

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_security_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_transaction_helpers.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class WalletUiHelpers {
  static bool isPubKeyVisible = false;
  final String address;
  final int avBalance;
  final int ledBalance;
  final bool showInSatoshis;
  final double avCurrencyBalance;
  final double ledCurrencyBalance;
  final int currentHeight;
  String timeStamp;
  final bool isInitialized;
  final TextEditingController pubKeyController;
  final SettingsProvider settingsProvider;
  final DateTime? lastRefreshed;
  final BuildContext context;
  final bool isLoading;
  final List<Map<String, dynamic>> transactions;
  final Wallet wallet;
  final bool isSingleWallet;
  final GlobalKey<BaseScaffoldState> baseScaffoldKey;
  final WalletSecurityHelpers securityHelper;
  final bool isRefreshing;
  final String? descriptor;
  final String? descriptorName;
  final List<Map<String, String>>? pubKeysAlias;
  final Set<String> myAddresses;

  late final WalletService walletService;

  WalletUiHelpers({
    required this.address,
    required this.avBalance,
    required this.ledBalance,
    required this.showInSatoshis,
    required this.avCurrencyBalance,
    required this.ledCurrencyBalance,
    required this.currentHeight,
    required this.timeStamp,
    required this.isInitialized,
    required this.pubKeyController,
    required this.settingsProvider,
    required this.lastRefreshed,
    required this.context,
    required this.isLoading,
    required this.transactions,
    required this.wallet,
    required this.isSingleWallet,
    required this.baseScaffoldKey,
    required this.isRefreshing,
    required this.myAddresses,
    this.descriptor,
    this.descriptorName,
    this.pubKeysAlias,
  })  : securityHelper = WalletSecurityHelpers(
          context: context,
          descriptor: descriptor,
          descriptorName: descriptorName,
          pubKeysAlias: pubKeysAlias,
        ),
        walletService = WalletService(settingsProvider);

  // Box for displaying general wallet info with onTap functionality
  Widget buildWalletInfoBox(
    String title, {
    VoidCallback? onTap,
    bool showCopyButton = false,
    String? subtitle,
  }) {
    // Determine color and sign
    Color balanceColor = ledBalance > 0
        ? AppColors.primary(context)
        : (ledBalance < 0 ? Colors.red : Colors.grey);

    bool isDataAvailable = address.isNotEmpty;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // Rounded corners
          ),
          elevation: 4, // Subtle shadow for depth
          color: AppColors.gradient(context), // Match button background
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isDataAvailable
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onLongPress: () {
                                  final BaseScaffoldState? baseScaffoldState =
                                      baseScaffoldKey.currentState;

                                  if (baseScaffoldState != null) {
                                    baseScaffoldState.updateAssistantMessage(
                                        context, 'assistant_private_data');
                                  }
                                },
                                onTap: () {
                                  securityHelper.showPinDialog(
                                    'Your Private Data',
                                    isSingleWallet: isSingleWallet,
                                  );
                                },
                                child: Icon(
                                  Icons.remove_red_eye,
                                  color: AppColors.cardTitle(context),
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: 10),
                              GestureDetector(
                                onLongPress: () {
                                  final BaseScaffoldState? baseScaffoldState =
                                      baseScaffoldKey.currentState;

                                  if (baseScaffoldState != null) {
                                    baseScaffoldState.updateAssistantMessage(
                                        context, 'assistant_pub_key_data');
                                  }
                                },
                                onTap: () {
                                  _showPubKeyDialog();
                                },
                                child: Icon(
                                  Icons.more_vert,
                                  color: AppColors.cardTitle(context),
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // First Section: Address (with Copy Button)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.text(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showCopyButton) // Display copy button if true
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                color: AppColors.cardTitle(context),
                              ),
                              tooltip: 'Copy to clipboard',
                              onPressed: () {
                                UtilitiesService.copyToClipboard(
                                  context: context,
                                  text: address,
                                  messageKey: 'address_clipboard',
                                );
                              },
                            ),
                        ],
                      ),

                      // Divider Between Sections
                      const Divider(
                        height: 20,
                        thickness: 1,
                        color: Colors.grey,
                      ),

                      // Second Section Balance
                      GestureDetector(
                        onTap: onTap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context)!
                                  .translate('balance'),
                              style: TextStyle(
                                color: AppColors.cardTitle(context),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          showInSatoshis
                                              ? Text(
                                                  UtilitiesService
                                                      .formatBitcoinAmount(
                                                          avBalance),
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.text(context),
                                                    fontSize: 16,
                                                  ),
                                                )
                                              : Text.rich(
                                                  TextSpan(
                                                    text:
                                                        '${avCurrencyBalance.toStringAsFixed(2)} ',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: AppColors.text(
                                                          context),
                                                      decoration: TextDecoration
                                                          .lineThrough,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: settingsProvider
                                                            .currency,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                          const SizedBox(width: 8),
                                          ledBalance != 0
                                              ? showInSatoshis
                                                  ? Text(
                                                      ledBalance > 0
                                                          ? '+ ${UtilitiesService.formatBitcoinAmount(ledBalance)}'
                                                          : UtilitiesService
                                                              .formatBitcoinAmount(
                                                                  ledBalance),
                                                      style: TextStyle(
                                                        color: balanceColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    )
                                                  : Text.rich(
                                                      TextSpan(
                                                        text: ledBalance > 0
                                                            ? '+ ${ledCurrencyBalance.toStringAsFixed(2)}'
                                                            : ledCurrencyBalance
                                                                .toStringAsFixed(
                                                                    2),
                                                        style: TextStyle(
                                                          decoration:
                                                              TextDecoration
                                                                  .lineThrough,
                                                          color: balanceColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                        children: [
                                                          TextSpan(
                                                              text:
                                                                  settingsProvider
                                                                      .currency),
                                                        ],
                                                      ),
                                                    )
                                              : Text(''),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Divider(
                        height: 20,
                        thickness: 1,
                        color: Colors.grey,
                      ),

                      // BlockHeight and TimeStamp

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              '${AppLocalizations.of(context)!.translate('current_height')}: $currentHeight\n'
                              '${AppLocalizations.of(context)!.translate('timestamp')}: $timeStamp',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.text(context),
                              ),
                            ),
                          ),
                          if (isRefreshing) ...[
                            Column(
                              children: [
                                buildMiniRefreshingIndicator(),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!
                                      .translate('refreshing'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.text(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),

                      if (lastRefreshed != null)
                        // RefreshIndicator
                        if (DateTime.now().difference(lastRefreshed!).inHours >=
                            2) ...[
                          const SizedBox(height: 8),
                          Text(
                            getTimeBasedMessage(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error(context),
                            ),
                          ).animate().shake(duration: 800.ms), // Shake effect
                        ]
                    ],
                  )
                : _buildShimmerEffect(),
          ),
        );
      },
    );
  }

  String getTimeBasedMessage() {
    int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return AppLocalizations.of(context)!.translate('morning_check');
    } else if (hour >= 12 && hour < 18) {
      return AppLocalizations.of(context)!.translate('afternoon_check');
    } else {
      return AppLocalizations.of(context)!.translate('night_check');
    }
  }

  Widget buildTransactionsBox() {
    // print('timestamp: $timeStamp');

    final transactionHelpers = WalletTransactionHelpers(
      context: context,
      currentHeight: currentHeight,
      address: address,
      baseScaffoldKey: baseScaffoldKey,
      settingsProvider: settingsProvider,
      myAddresses: myAddresses,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0), // Rounded corners
      ),
      elevation: 4, // Subtle shadow for depth
      color: AppColors.gradient(context), // Match button background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transactions.length} ${AppLocalizations.of(context)!.translate('transactions')}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.cardTitle(context), // Match button text color
              ),
            ),
            const SizedBox(height: 8),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                    ? const Text('No transactions available')
                    : SizedBox(
                        height: 310, // Define the height of the scrollable area
                        child: ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[index];

                            return KeyedSubtree(
                              key: ValueKey(tx['txid']),
                              child: GestureDetector(
                                onTap: () {
                                  transactionHelpers.showTransactionsDialog(
                                    tx,
                                  );
                                },
                                child: transactionHelpers.buildTransactionItem(
                                  tx,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  void _showPubKeyDialog() {
    final rootContext = context;

    DialogHelper.buildCustomDialog(
      context: rootContext,
      titleKey: 'wallet_data',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.container(context),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: AppColors.background(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isSingleWallet) ...[
                  // 🔹 Saved Pub Key Label
                  Text(
                    "${AppLocalizations.of(rootContext)!.translate('saved_pub_key')}: ",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.cardTitle(context),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Public Key Display
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppColors.container(context),
                      borderRadius: BorderRadius.circular(8.0), // Rounded edges
                      border: Border.all(
                        color: AppColors.background(context),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity, // Ensure the Row gets a width
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              pubKeyController.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.text(context),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.copy,
                              color: AppColors.icon(context),
                            ),
                            onPressed: () {
                              UtilitiesService.copyToClipboard(
                                context: context,
                                text: pubKeyController.text,
                                messageKey: 'pub_key_clipboard',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (!isSingleWallet) ...[
                  // 🔹 Saved Descriptor Label
                  Text(
                    "${AppLocalizations.of(rootContext)!.translate('saved_descriptor')}: ",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.cardTitle(context),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Saved Descriptor Display
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppColors.container(context),
                      borderRadius: BorderRadius.circular(8.0), // Rounded edges
                      border: Border.all(
                        color: AppColors.background(context),
                      ),
                    ),
                    child: SizedBox(
                      width:
                          double.infinity, // Ensure Row gets constrained width
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              descriptor.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.text(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.copy,
                              color: AppColors.icon(context),
                            ),
                            onPressed: () {
                              UtilitiesService.copyToClipboard(
                                context: rootContext,
                                text: descriptor.toString(),
                                messageKey: 'descriptor_clipboard',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        Visibility(
          visible: !isSingleWallet,
          child: TextButton(
            onPressed: () async {
              // Serialize data to JSON
              final data = jsonEncode({
                'descriptor': descriptor,
                'publicKeysWithAlias': pubKeysAlias,
                'descriptorName': descriptorName,
              });

              // Request storage permission (required for Android 11 and below)
              if (await Permission.storage.request().isGranted) {
                // Get default Downloads directory
                final directory = Directory('/storage/emulated/0/Download');
                if (!await directory.exists()) {
                  await directory.create(recursive: true);
                }

                String fileName = '$descriptorName.json';
                String filePath = '${directory.path}/$fileName';
                File file = File(filePath);

                // Check if the file already exists
                if (await file.exists()) {
                  final shouldProceed =
                      (await DialogHelper.buildCustomDialog<bool>(
                            context: rootContext,
                            showCloseButton: false,
                            titleKey: 'file_already_exists',
                            content: Text(
                              AppLocalizations.of(rootContext)!
                                  .translate('file_save_prompt'),
                              style: TextStyle(
                                color: AppColors.text(context),
                              ),
                            ),
                            actions: [
                              InkwellButton(
                                onTap: () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop(false);
                                },
                                label: AppLocalizations.of(rootContext)!
                                    .translate('no'),
                                backgroundColor: Colors.white,
                                textColor: Colors.black,
                                icon: Icons.cancel_rounded,
                                iconColor: Colors.redAccent,
                              ),
                              InkwellButton(
                                onTap: () {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop(true);
                                },
                                label: AppLocalizations.of(rootContext)!
                                    .translate('yes'),
                                backgroundColor: Colors.white,
                                textColor: Colors.black,
                                icon: Icons.check_circle,
                                iconColor: AppColors.accent(context),
                              ),
                            ],
                          )) ??
                          false;

                  // If the user chooses not to proceed, exit
                  if (!shouldProceed) {
                    return;
                  }

                  // Increment the file name index until a unique file name is found
                  int index = 1;
                  while (await file.exists()) {
                    fileName = '$descriptorName($index).json';
                    filePath = '${directory.path}/$fileName';
                    file = File(filePath);
                    index++;
                  }
                }
                // Write JSON data to the file
                await file.writeAsString(data);

                SnackBarHelper.show(
                  rootContext,
                  message:
                      '${AppLocalizations.of(rootContext)!.translate('file_saved')} ${directory.path}/$fileName',
                );
              } else {
                SnackBarHelper.showError(
                  rootContext,
                  message: AppLocalizations.of(rootContext)!
                      .translate('storage_permission_needed'),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.cardTitle(context),
            ),
            child: Text(AppLocalizations.of(rootContext)!
                .translate('download_descriptor')),
          ),
        ),
      ],
    );
  }

  /// 🔹 Create a shimmer effect when data is loading
  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Future<void> handleRefresh(
    Future<void> Function() syncWallet,
    List<ConnectivityResult> connectivityResult,
    BuildContext context,
  ) async {
    // print('ConnectivityResult: $connectivityResult');

    if (connectivityResult.contains(ConnectivityResult.none)) {
      SnackBarHelper.showError(
        context,
        message: AppLocalizations.of(context)!.translate('no_internet'),
      );

      return; // Exit early if there's no internet
    }

    try {
      SnackBarHelper.show(
        context,
        message: AppLocalizations.of(context)!.translate('syncing_wallet'),
      );

      await walletService.syncWallet(wallet);
      final newHeight = await walletService.fetchCurrentBlockHeight();

      final walletTransactions = wallet.listTransactions(includeRaw: true);

      // Find new transactions
      List<String> newTransactions = walletService.findNewTransactions(
        transactions, // From API response
        walletTransactions, // From wallet.listTransactions()
      );

      // **Determine the message based on new block and transactions**
      bool newBlockDetected = currentHeight != newHeight;
      bool newTransactionDetected = newTransactions.isNotEmpty;

      String syncMessage =
          AppLocalizations.of(context)!.translate('no_updates_yet');

      if (newBlockDetected && newTransactionDetected) {
        syncMessage = AppLocalizations.of(context)!
            .translate('new_block_transactions_detected');
      } else if (newBlockDetected) {
        syncMessage =
            AppLocalizations.of(context)!.translate('new_block_detected');
      } else if (newTransactionDetected) {
        syncMessage =
            AppLocalizations.of(context)!.translate('new_transaction_detected');
      }

      if (newBlockDetected || newTransactionDetected) {
        // print('syncing');
        SnackBarHelper.show(context, message: syncMessage);

        await syncWallet();
        SnackBarHelper.show(
          context,
          message: AppLocalizations.of(context)!.translate('syncing_complete'),
        );
      } else {
        SnackBarHelper.show(context, message: syncMessage);
      }
    } catch (e, stackTrace) {
      print('Sync error: $e');
      print('Stack trace: $stackTrace'); // Helps debug where the error occurs

      SnackBarHelper.showError(
        context,
        message:
            "${AppLocalizations.of(context)!.translate('syncing_error')} ${e.toString()}",
      );
    }
  }

  Widget buildMiniRefreshingIndicator() {
    return Animate(
      effects: [FadeEffect(duration: 500.ms), ScaleEffect(duration: 600.ms)],
      child: Lottie.asset(
        'assets/animations/loading.json',
        width: 100,
        height: 50,
      ),
    );
  }
}

import 'dart:async';
import 'package:bdk_dart/bdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_sendtx_helpers.dart';
import 'package:flutter_wallet/widget_helpers/custom_bottom_sheet.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:flutter_wallet/widget_helpers/notification_helper.dart';

class WalletSpendingPathHelpers {
  final List<Map<String, String>> pubKeysAlias;
  final List<Map<String, dynamic>> mySpendingPaths;
  final List<Map<String, dynamic>> spendingPaths;
  final List<dynamic> utxos;
  final int currentHeight;
  final WalletService walletService;
  final String myAlias;
  final BuildContext context;
  final Map<String, dynamic> policy;
  final ScrollController _scrollController = ScrollController();
  final WalletSendtxHelpers sendTxHelper;
  final TextEditingController amountController;
  final TextEditingController recipientController;
  final bool mounted;
  final String mnemonic;
  final Wallet wallet;
  final String address;
  final int avBalance;
  final void Function(String newAddress)? onNewAddressGenerated;
  final String? descriptor;
  Future<void> Function() syncWallet;
  Set<String> myAddresses;

  bool _isUserInteracting = false;
  bool _isScrollingForward = true;
  Timer? _scrollTimer;

  WalletSpendingPathHelpers({
    required this.pubKeysAlias,
    required this.mySpendingPaths,
    required this.spendingPaths,
    required this.utxos,
    required this.currentHeight,
    required this.walletService,
    required this.myAlias,
    required this.context,
    required this.policy,
    required this.amountController,
    required this.recipientController,
    required this.mounted,
    required this.mnemonic,
    required this.wallet,
    required this.address,
    required this.avBalance,
    required this.onNewAddressGenerated,
    required this.syncWallet,
    required this.myAddresses,
    this.descriptor,

    // SharedWallet Variables
    String? myFingerPrint,
    List<String>? signersList,
  }) : sendTxHelper = WalletSendtxHelpers(
         isSingleWallet: false,
         context: context,
         recipientController: recipientController,
         amountController: amountController,
         walletService: walletService,
         policy: policy,
         myFingerPrint: myFingerPrint ?? '',
         currentHeight: currentHeight,
         utxos: utxos,
         spendingPaths: mySpendingPaths,
         descriptor: descriptor ?? '',
         signersList: signersList ?? [],
         mnemonic: mnemonic,
         mounted: mounted,
         avBalance: avBalance,
         pubKeysAlias: pubKeysAlias,
         wallet: wallet,
         onNewAddressGenerated: onNewAddressGenerated,
         syncWallet: syncWallet,
         myAddresses: myAddresses,
       ) {
    if (mySpendingPaths.length > 1) {
      _startAutoScroll(); // Start scrolling when the class is initialized
    }
  }

  /// Start auto-scrolling back and forth until the user interacts
  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isUserInteracting) return;

      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double minScroll = _scrollController.position.minScrollExtent;
        double currentScroll = _scrollController.offset;

        if (_isScrollingForward) {
          if (currentScroll >= maxScroll) {
            _isScrollingForward = false;
          } else {
            _scrollController.animateTo(
              currentScroll + 25,
              duration: const Duration(milliseconds: 150),
              curve: Curves.bounceInOut,
            );
          }
        } else {
          if (currentScroll <= minScroll) {
            _isScrollingForward = true;
          } else {
            _scrollController.animateTo(
              currentScroll - 25,
              duration: const Duration(milliseconds: 150),
              curve: Curves.linear,
            );
          }
        }
      }
    });
  }

  /// Stops auto-scroling when user taps
  void _stopAutoScroll() {
    _isUserInteracting = true;
    _scrollTimer?.cancel();
  }

  /// Dispose function to clean up resources
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
  }

  // 🔹 Call this from your main widget
  Widget buildDynamicSpendingPaths(bool isInitialized) {
    return Align(
      alignment: Alignment.center,
      child: isInitialized
          ? mySpendingPaths.isEmpty
                ? const Text(
                    "No spending paths available",
                    style: TextStyle(color: Colors.grey),
                  )
                : Listener(
                    onPointerUp: (event) => _stopAutoScroll(),
                    onPointerDown: (event) => _stopAutoScroll(),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _scrollController,
                        child: Row(
                          children: mySpendingPaths.asMap().entries.map((
                            entry,
                          ) {
                            int index = entry.key;
                            var path = entry.value;

                            return buildSpendingPathBox(
                              path,
                              index,
                              mySpendingPaths.length,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  )
          : CircularProgressIndicator(color: AppColors.primary(context)),
    );
  }

  Widget buildSpendingPathBox(
    Map<String, dynamic> path,
    int index,
    int length,
  ) {
    // Extract aliases for the current pathInfo's fingerprints
    final List<String> pathAliases = (path['fingerprints'] as List<dynamic>)
        .map<String>((fingerprint) {
          final matchedAlias = pubKeysAlias.firstWhere(
            (pubKeyAlias) => pubKeyAlias['publicKey']!.contains(fingerprint),
            orElse: () => {'alias': fingerprint}, // Fallback to fingerprint
          );
          return matchedAlias['alias'] ?? fingerprint;
        })
        .toList();

    // Extract timelock for the path
    final timelock = path['timelock'] ?? 0;
    final String timelockType = path['type'].contains('RELATIVETIMELOCK')
        ? 'older'
        : path['type'].contains('ABSOLUTETIMELOCK')
        ? 'after'
        : 'none';

    String timeRemaining = 'Spendable';

    int totalSpendable = 0;
    int totalUnconfirmed = 0;
    Map<int, int> blockHeightTotals = {};
    List<Widget> transactionDetails = [];

    for (var utxo in utxos) {
      final blockHeight = utxo['status']['block_height'];
      final value = utxo['value'];

      if (blockHeight == null) {
        totalUnconfirmed += int.parse(value.toString());

        continue;
      }

      // Determine if the transaction is spendable
      bool isSpendable;

      if (timelockType == 'older') {
        isSpendable = blockHeight + timelock - 1 <= currentHeight;
      } else if (timelockType == 'after') {
        isSpendable = timelock <= currentHeight;
      } else {
        isSpendable = true;
      }

      // Calculate time remaining if not spendable
      if (isSpendable) {
        totalSpendable += value as int;
      } else {
        if (blockHeightTotals.containsKey(blockHeight)) {
          blockHeightTotals[blockHeight] =
              blockHeightTotals[blockHeight]! + int.parse(value.toString());
        } else {
          blockHeightTotals[blockHeight] = int.parse(value.toString());
        }
      }
    }

    List<MapEntry<int, int>> sortedEntries = blockHeightTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    int futureTotal = 0;

    List<Widget> waitingTransactions = [];

    for (var i = 0; i < sortedEntries.length; i++) {
      int utxoBlockHeight = sortedEntries[i].key;
      int totalValue = sortedEntries[i].value;

      int remainingBlocks;
      if (timelockType == 'older') {
        remainingBlocks =
            (utxoBlockHeight + timelock - 1 - currentHeight) as int;
      } else {
        remainingBlocks = timelock - currentHeight;
      }

      final totalSeconds = remainingBlocks * avgBlockTime;
      timeRemaining = walletService.formatTime(totalSeconds, context);

      if (i == 0) {
        waitingTransactions.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock, color: AppColors.icon(context), size: 16),
              const SizedBox(width: 6),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  "${UtilitiesService.formatBitcoinAmount(totalValue)} ${AppLocalizations.of(context)!.translate('sats_available')} $timeRemaining",
                  style: TextStyle(
                    fontSize: MediaQuery.textScalerOf(context).scale(12),
                    color: AppColors.text(context),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        futureTotal += totalValue;
      }
    }

    if (futureTotal > 0) {
      waitingTransactions.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_empty,
              color: Colors.amberAccent,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                "${UtilitiesService.formatBitcoinAmount(futureTotal)} ${AppLocalizations.of(context)!.translate('future_sats')}",
                style: TextStyle(
                  fontSize: MediaQuery.textScalerOf(context).scale(12),
                  color: AppColors.text(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    transactionDetails.insertAll(0, waitingTransactions);

    // ✅ Add the total unconfirmed amount to the transaction details list
    if (totalUnconfirmed > 0) {
      transactionDetails.add(
        Text(
          AppLocalizations.of(context)!
              .translate('total_unconfirmed')
              .replaceAll(
                '{x}',
                UtilitiesService.formatBitcoinAmount(totalUnconfirmed),
              ),
          style: TextStyle(
            fontSize: MediaQuery.textScalerOf(context).scale(14),
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    // Construct alias string for transaction details
    List<String> otherAliases = List.from(pathAliases)..remove(myAlias);

    String aliasText = totalSpendable > 0
        ? "${AppLocalizations.of(context)!.translate('immediately_spend').replaceAll('{x}', myAlias.toString())} \n${UtilitiesService.formatBitcoinAmount(totalSpendable)}"
        : AppLocalizations.of(
            context,
          )!.translate('cannot_spend').replaceAll('{x}', myAlias.toString());

    if (otherAliases.isNotEmpty) {
      int threshold = path['threshold'];
      int totalKeys = pathAliases.length;

      if (threshold == 1) {
        aliasText +=
            "${AppLocalizations.of(context)!.translate('spend_alone')} \n${otherAliases.join(', ')}";
      } else if (threshold < totalKeys) {
        aliasText +=
            "${AppLocalizations.of(context)!.translate('threshold_required').replaceAll('{x}', threshold.toString()).replaceAll('{y}', totalKeys.toString())} \n${otherAliases.join(', ')}";
      } else {
        aliasText +=
            "${AppLocalizations.of(context)!.translate('spend_together')} \n${otherAliases.join(', ')}";
      }
    }

    return Stack(
      children: [
        // 🌟 Main Card
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 5,
          color: AppColors.gradient(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 **Spending Path Label**
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timelockType == 'older'
                          ? '${AppLocalizations.of(context)!.translate('rel_timelock')}: $timelock ${AppLocalizations.of(context)!.translate('blocks')}'
                          : timelockType == 'after'
                          ? '${AppLocalizations.of(context)!.translate('abs_timelock')}: $timelock ${AppLocalizations.of(context)!.translate('height')}'
                          : 'MULTISIG',
                      style: TextStyle(
                        fontSize: MediaQuery.textScalerOf(context).scale(16),
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardTitle(context),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Icon(
                      totalSpendable > 0 ? Icons.lock_open : Icons.lock_clock,
                      color: AppColors.icon(context),
                      size: 20,
                    ),

                    const SizedBox(width: 10),

                    // Show all available paths
                    GestureDetector(
                      onTap: () {
                        showPathsDialog();
                      },
                      child: Icon(
                        Icons.more_vert,
                        color: AppColors.icon(context),
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Send available balance from spending path
                    GestureDetector(
                      onTap: () async {
                        final rootContext = context;

                        if (totalSpendable == 0) {
                          // Show SnackBar if totalSpendable is 0
                          NotificationHelper.showError(
                            context,
                            message: AppLocalizations.of(
                              rootContext,
                            )!.translate('error_insufficient_funds'),
                          );
                          return; // Stop execution since no funds are available
                        }

                        bool recipientEntered =
                            (await CustomBottomSheet.buildCustomBottomSheet<
                              bool
                            >(
                              context: rootContext,
                              titleKey: 'enter_rec_addr',
                              content: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.7,
                                ),
                                child: TextFormField(
                                  controller: recipientController,
                                  decoration:
                                      CustomTextFieldStyles.textFieldDecoration(
                                        context: context,
                                        labelText: AppLocalizations.of(
                                          rootContext,
                                        )!.translate('recipient_address'),
                                        hintText: AppLocalizations.of(
                                          rootContext,
                                        )!.translate('enter_rec_addr'),
                                      ),
                                ),
                              ),
                              actions: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    InkwellButton(
                                      onTap: () => Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop(false),
                                      label: AppLocalizations.of(
                                        rootContext,
                                      )!.translate('cancel'),
                                      backgroundColor: AppColors.text(context),
                                      textColor: AppColors.gradient(context),
                                      icon: Icons.dangerous,
                                      iconColor: AppColors.error(context),
                                    ),
                                    InkwellButton(
                                      onTap: () => Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop(true),
                                      label: AppLocalizations.of(
                                        rootContext,
                                      )!.translate('confirm'),
                                      backgroundColor: AppColors.text(context),
                                      textColor: AppColors.gradient(context),
                                      icon: Icons.verified,
                                      iconColor: AppColors.icon(context),
                                    ),
                                  ],
                                ),
                              ],
                            )) ??
                            false;

                        if (recipientEntered) {
                          // Show the loading dialog
                          DialogHelper.showLoadingDialog(rootContext);

                          try {
                            await sendTxHelper.sendTx(
                              true,
                              address,
                              isFromSpendingPath: true,
                              index: index,
                              amount: totalSpendable,
                            );
                          } finally {
                            Navigator.of(
                              rootContext,
                              rootNavigator: true,
                            ).pop();
                          }
                        }
                      },
                      child: Icon(
                        Icons.send,
                        color: totalSpendable == 0
                            ? AppColors.unavailableColor
                            : AppColors.icon(context),
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 10),

                    // BACKUP Transaction Creation
                    if ((path['threshold'] == null || path['threshold'] == 1) &&
                        pathAliases.isNotEmpty &&
                        (timelockType == 'older' || timelockType == 'after'))
                      GestureDetector(
                        onTap: () async {
                          final rootContext = context;

                          try {
                            final singleWallet = await walletService
                                .createOrRestoreWallet(mnemonic);

                            final recipient = singleWallet
                                .peekAddress(
                                  keychain: KeychainKind.external_,
                                  index: 0,
                                )
                                .address
                                .toString();

                            int backupSpendable = 0;

                            for (var utxo in utxos) {
                              final status = utxo['status'];
                              final confirmed =
                                  status != null && status['confirmed'] == true;

                              if (confirmed) {
                                backupSpendable += int.parse(
                                  utxo['value'].toString(),
                                );

                                continue;
                              }
                            }

                            final shouldContinue = await showDialog<bool>(
                              context: rootContext,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.dialog(context),
                                title: const Text("Confirm Backup Transaction"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "You are about to create and sign a backup transaction with the following details:",
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Destination Address:\n$recipient",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "This transaction will be signed using the 1-of-N timelock path (older/after).\n\n"
                                      "You can broadcast this transaction later using Bitcoin Core, or other blockchain explorers.",
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Cancel"),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                  ),
                                  ElevatedButton(
                                    child: const Text("Continue"),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                  ),
                                ],
                              ),
                            );

                            // Bail out if user cancels
                            if (shouldContinue != true) return;

                            DialogHelper.showLoadingDialog(rootContext);

                            final result = await walletService.createBackupTx(
                              descriptor.toString(),
                              mnemonic,
                              recipient,
                              backupSpendable,
                              index,
                              avBalance,
                              spendingPaths: mySpendingPaths,
                              isSendAllBalance: true,
                            );

                            final finalResult = await walletService
                                .createBackupTx(
                                  descriptor.toString(),
                                  mnemonic,
                                  recipient,
                                  int.parse(result.toString()),
                                  index,
                                  avBalance,
                                  spendingPaths: mySpendingPaths,
                                );

                            Navigator.of(
                              rootContext,
                              rootNavigator: true,
                            ).pop();

                            sendTxHelper.showHEXDialog(
                              finalResult.toString(),
                              rootContext,
                            );
                          } catch (e) {
                            NotificationHelper.showError(
                              context,
                              message: 'Error: $e',
                            );
                          }
                        },
                        child: Icon(
                          Icons.backup,
                          color: AppColors.icon(context),
                          size: 22,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // 🔹 **Spendable Balance (Big Bold Text)**
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.text(context).opaque(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.icon(context),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          aliasText,
                          style: TextStyle(
                            fontSize: MediaQuery.textScalerOf(
                              context,
                            ).scale(14),
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 🔹 **Transaction Details**
                if (transactionDetails.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.translate('upcoming_funds'),
                        style: TextStyle(
                          fontSize: MediaQuery.textScalerOf(context).scale(14),
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...transactionDetails,
                    ],
                  ),
              ],
            ),
          ),
        ),

        // 🔹 **Index Badge (Top-Right Corner)**
        if (path['threshold'] != null)
          Positioned(
            top: 13,
            right: 13,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.cardTitle(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${path['threshold']}/${pathAliases.length}',
                style: TextStyle(
                  color: AppColors.gradient(context),
                  fontSize: MediaQuery.textScalerOf(context).scale(12),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget sendAvailableBalance(int totalSpendable, int index) {
    return GestureDetector(
      onTap: () async {
        final rootContext = context;

        if (totalSpendable == 0) {
          // Show SnackBar if totalSpendable is 0
          NotificationHelper.showError(
            context,
            message: AppLocalizations.of(
              rootContext,
            )!.translate('error_insufficient_funds'),
          );
          return; // Stop execution since no funds are available
        }

        bool recipientEntered =
            (await CustomBottomSheet.buildCustomBottomSheet<bool>(
              context: rootContext,
              titleKey: 'enter_rec_addr',
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: TextFormField(
                  controller: recipientController,
                  decoration: CustomTextFieldStyles.textFieldDecoration(
                    context: context,
                    labelText: AppLocalizations.of(
                      rootContext,
                    )!.translate('recipient_address'),
                    hintText: AppLocalizations.of(
                      rootContext,
                    )!.translate('enter_rec_addr'),
                  ),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkwellButton(
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pop(false),
                      label: AppLocalizations.of(
                        rootContext,
                      )!.translate('cancel'),
                      backgroundColor: AppColors.text(context),
                      textColor: AppColors.gradient(context),
                      icon: Icons.dangerous,
                      iconColor: AppColors.error(context),
                    ),
                    InkwellButton(
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pop(true),
                      label: AppLocalizations.of(
                        rootContext,
                      )!.translate('confirm'),
                      backgroundColor: AppColors.text(context),
                      textColor: AppColors.gradient(context),
                      icon: Icons.verified,
                      iconColor: AppColors.icon(context),
                    ),
                  ],
                ),
              ],
            )) ??
            false;

        if (recipientEntered) {
          // Show the loading dialog
          DialogHelper.showLoadingDialog(rootContext);

          try {
            await sendTxHelper.sendTx(
              true,
              address,
              isFromSpendingPath: true,
              index: index,
              amount: totalSpendable,
            );
          } finally {
            Navigator.of(rootContext, rootNavigator: true).pop();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.icon(context).opaque(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.send,
          color: totalSpendable == 0
              ? AppColors.unavailableColor
              : AppColors.icon(context),
          size: 22,
        ),
      ),
    );
  }

  Widget spendableBalance(String aliasText) {
    // Store the full text for the bottom sheet
    final String fullAliasText = aliasText;

    // Extract just the first line (the spendable amount)
    final String firstLine = aliasText.split('\n').first;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background(context).opaque(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
              firstLine,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
          ),

          // Show "more..." button only if there's additional content
          if (aliasText.contains('\n'))
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showSpendableDetails(context, fullAliasText);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardTitle(context).opaque(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        textScaler: TextScaler.linear(
                          ScaleSize.textScaleFactor(context),
                        ),
                        'more...',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.cardTitle(context),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppColors.cardTitle(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add this method to your class
  Future<void> _showSpendableDetails(BuildContext context, String fullText) {
    // Parse the full text to extract different sections
    final lines = fullText.split('\n');

    String aliasName = "";
    if (lines.length > 1) {
      final RegExp regex = RegExp(r'\(([^)]+)\)');
      final match = regex.firstMatch(lines[0]);
      if (match != null) {
        aliasName = match.group(1).toString();
      }
    }

    // Build a nicely formatted content widget
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spendable amount section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background(context).opaque(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                textScaler: TextScaler.linear(
                  ScaleSize.textScaleFactor(context),
                ),
                'Spendable Amount',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.text(context).opaque(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                textScaler: TextScaler.linear(
                  ScaleSize.textScaleFactor(context),
                ),
                lines[0], // First line is the spendable amount
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardTitle(context),
                ),
              ),
            ],
          ),
        ),

        // Alias info section (if exists)
        if (lines.length > 1 && lines[1].isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDetailSection(
            context,
            icon: Icons.person_outline_rounded,
            title: 'Your Alias',
            content: aliasName,
          ),
        ],

        // Spending rules section (remaining lines)
        if (lines.length > 2) ...[
          const SizedBox(height: 16),
          _buildDetailSection(
            context,
            icon: Icons.rule_rounded,
            title: 'Spending Rules',
            content: lines.sublist(2).join('\n'),
          ),
        ],
      ],
    );

    return CustomBottomSheet.buildCustomBottomSheet(
      context: context,
      titleKey: 'spending_details', // You'll need to add this translation key
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
            'Close',
            style: TextStyle(color: AppColors.cardTitle(context)),
          ),
        ),
      ],
    );
  }

  // Helper method to create consistent detail sections
  Widget _buildDetailSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background(context).opaque(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.text(context).opaque(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.cardTitle(context)),
              const SizedBox(width: 8),
              Text(
                textScaler: TextScaler.linear(
                  ScaleSize.textScaleFactor(context),
                ),
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.text(context).opaque(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
            content,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: AppColors.text(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget transactionDetailsWidget(List<Widget> transactionDetails) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
          AppLocalizations.of(context)!.translate('upcoming_funds'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 4),
        ...transactionDetails,
      ],
    );
  }

  Widget backupTransaction(int index) {
    return GestureDetector(
      onTap: () async {
        final rootContext = context;

        try {
          final singleWallet = await walletService.createOrRestoreWallet(
            mnemonic,
          );

          final recipient = singleWallet
              .peekAddress(keychain: KeychainKind.external_, index: 0)
              .address
              .toString();

          int backupSpendable = 0;

          for (var utxo in utxos) {
            final status = utxo['status'];
            final confirmed = status != null && status['confirmed'] == true;

            if (confirmed) {
              backupSpendable += int.parse(utxo['value'].toString());

              continue;
            }
          }

          final shouldContinue = await showDialog<bool>(
            context: rootContext,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.dialog(context),
              title: Text(
                textScaler: TextScaler.linear(
                  ScaleSize.textScaleFactor(context),
                ),
                "Confirm Backup Transaction",
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    "You are about to create and sign a backup transaction with the following details:",
                  ),
                  const SizedBox(height: 12),
                  Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    "Destination Address:\n$recipient",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    "This transaction will be signed using the 1-of-N timelock path (older/after).\n\n"
                    "You can broadcast this transaction later using Bitcoin Core, or other blockchain explorers.",
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    "Cancel",
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                ElevatedButton(
                  child: Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    "Continue",
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          );

          // Bail out if user cancels
          if (shouldContinue != true) return;

          DialogHelper.showLoadingDialog(rootContext);

          final result = await walletService.createBackupTx(
            descriptor.toString(),
            mnemonic,
            recipient,
            backupSpendable,
            index,
            avBalance,
            spendingPaths: mySpendingPaths,
            isSendAllBalance: true,
          );

          final finalResult = await walletService.createBackupTx(
            descriptor.toString(),
            mnemonic,
            recipient,
            int.parse(result.toString()),
            index,
            avBalance,
            spendingPaths: mySpendingPaths,
          );

          Navigator.of(rootContext, rootNavigator: true).pop();

          sendTxHelper.showHEXDialog(finalResult.toString(), rootContext);
        } catch (e) {
          NotificationHelper.showError(context, message: 'Error: $e');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.icon(context).opaque(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.backup, color: AppColors.icon(context), size: 22),
      ),
    );
  }

  Widget spendingPathLabel(String timelockType, dynamic timelock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardTitle(context).opaque(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.cardTitle(context).opaque(0.2),
          width: 1,
        ),
      ),
      child: Text(
        textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
        timelockType == 'older'
            ? '${AppLocalizations.of(context)!.translate('rel_timelock')} $timelock ${AppLocalizations.of(context)!.translate('blocks')}'
            : timelockType == 'after'
            ? '${AppLocalizations.of(context)!.translate('abs_timelock')} $timelock ${AppLocalizations.of(context)!.translate('height')}'
            : 'MULTISIG',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.cardTitle(context),
        ),
      ),
    );
  }

  Widget indexBadge(
    Map<String, dynamic> path,
    List<String> pathAliases,
    int totalSpendable,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardTitle(context),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardTitle(context).opaque(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            totalSpendable > 0
                ? Icons.lock_open_rounded
                : Icons.lock_clock_rounded,
            size: 14,
            color: AppColors.gradient(context),
          ),
          const SizedBox(width: 4),
          Text(
            textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
            '${path['threshold']}/${pathAliases.length}',
            style: TextStyle(
              color: AppColors.gradient(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void showPathsDialog() async {
    final rootContext = context;

    CustomBottomSheet.buildCustomBottomSheet(
      context: rootContext,
      titleKey: 'spending_paths_available',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: spendingPaths.map<Widget>((pathInfo) {
          // Extract aliases for the current pathInfo's fingerprints
          final List<String> pathAliases =
              (pathInfo['fingerprints'] as List<dynamic>).map<String>((
                fingerprint,
              ) {
                final matchedAlias = pubKeysAlias.firstWhere(
                  (pubKeyAlias) =>
                      pubKeyAlias['publicKey']!.contains(fingerprint),
                  orElse: () => {
                    'alias': fingerprint,
                  }, // Fallback to fingerprint
                );
                return matchedAlias['alias'] ?? fingerprint;
              }).toList();

          // Extract timelock for the path
          final timelock = pathInfo['timelock'] ?? 0;

          final String timelockType =
              pathInfo['type'].contains('RELATIVETIMELOCK')
              ? 'older'
              : pathInfo['type'].contains('ABSOLUTETIMELOCK')
              ? 'after'
              : 'none';

          String timeRemaining = 'Spendable';

          // Make a copy of utxos to avoid mutating the original list (optional but safe)
          final sortedUtxos = utxos
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();

          // Sort by blocksRemaining (unconfirmed ones go last or first as you prefer)
          sortedUtxos.sort((a, b) {
            final aHeight = a['status']['block_height'];
            final bHeight = b['status']['block_height'];

            // If either is unconfirmed, push them to the end (or adjust as needed)
            if (aHeight == null) return 1;
            if (bHeight == null) return -1;

            final aRemaining = aHeight + timelock - 1 - currentHeight;
            final bRemaining = bHeight + timelock - 1 - currentHeight;

            return aRemaining.compareTo(bRemaining);
          });

          // Gather all transactions for the display
          List<Widget> transactionDetails = sortedUtxos.map<Widget>((utxo) {
            // Access the block_height of the transaction
            final blockHeight = utxo['status']['block_height'];

            final value = utxo['value'];

            if (blockHeight == null) {
              // Handle unconfirmed UTXOs
              return RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    color: AppColors.text(context),
                  ),
                  children: [
                    TextSpan(
                      text:
                          "${AppLocalizations.of(rootContext)!.translate('value')}: ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardTitle(context),
                      ),
                    ),
                    TextSpan(
                      text:
                          "${UtilitiesService.formatBitcoinAmount(int.parse(value.toString()))} - ${AppLocalizations.of(rootContext)!.translate('unconfirmed')}",
                      style: TextStyle(color: AppColors.text(context)),
                    ),
                  ],
                ),
              );
            }

            // Determine if the transaction is spendable
            bool isSpendable;
            if (timelockType == 'older') {
              isSpendable = blockHeight + timelock - 1 <= currentHeight;
            } else if (timelockType == 'after') {
              isSpendable = timelock <= currentHeight;
            } else {
              isSpendable = true;
            }

            int remainingBlocks;
            if (timelockType == 'older') {
              remainingBlocks = blockHeight + timelock - 1 - currentHeight;
            } else {
              remainingBlocks = timelock - currentHeight;
            }
            // Calculate time remaining if not spendable
            if (!isSpendable) {
              final totalSeconds = remainingBlocks * avgBlockTime;
              timeRemaining = walletService.formatTime(
                totalSeconds,
                rootContext,
              );
            }

            return RichText(
              text: TextSpan(
                style: TextStyle(color: AppColors.text(context)),
                children: [
                  if (isSpendable) ...[
                    TextSpan(
                      text:
                          "${UtilitiesService.formatBitcoinAmount(int.parse(value.toString()))} ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: AppLocalizations.of(
                        rootContext,
                      )!.translate('can_be_spent'),
                    ),
                  ] else ...[
                    TextSpan(
                      text:
                          "${AppLocalizations.of(rootContext)!.translate('value')}: ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardTitle(context),
                      ),
                    ),
                    TextSpan(
                      text:
                          "${UtilitiesService.formatBitcoinAmount(int.parse(value.toString()))}\n",
                    ),
                    TextSpan(
                      text:
                          "${AppLocalizations.of(rootContext)!.translate('time_remaining_text')}: ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardTitle(context),
                      ),
                    ),
                    TextSpan(text: "$timeRemaining\n"),
                    TextSpan(
                      text:
                          "${AppLocalizations.of(rootContext)!.translate('blocks_remaining')}: ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardTitle(context),
                      ),
                    ),
                    TextSpan(text: "$remainingBlocks"),
                  ],
                ],
              ),
            );
          }).toList();

          // Display spending path details
          return Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.container(context),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppColors.background(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textScaler: TextScaler.linear(
                    ScaleSize.textScaleFactor(context),
                  ),
                  timelockType == 'older'
                      ? '${AppLocalizations.of(context)!.translate('rel_timelock')}: $timelock ${AppLocalizations.of(context)!.translate('blocks')}'
                      : timelockType == 'after'
                      ? '${AppLocalizations.of(context)!.translate('abs_timelock')}: $timelock ${AppLocalizations.of(context)!.translate('height')}'
                      : 'MULTISIG',
                  style: TextStyle(
                    color: AppColors.cardTitle(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                pathInfo['threshold'] != null
                    ? RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: AppColors.text(context),
                          ),
                          children: [
                            TextSpan(
                              text:
                                  "${AppLocalizations.of(rootContext)!.translate('threshold')}: ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardTitle(context),
                              ),
                            ),
                            TextSpan(
                              text: '${pathInfo['threshold']}',
                              style: TextStyle(color: AppColors.text(context)),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
                Text.rich(
                  TextSpan(
                    children: [
                      for (int i = 0; i < pathAliases.length; i++)
                        TextSpan(
                          text:
                              pathAliases[i] +
                              (i == pathAliases.length - 1
                                  ? ""
                                  : ", "), // Remove comma for last item
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontWeight: pathAliases[i] == myAlias
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  textScaler: TextScaler.linear(
                    ScaleSize.textScaleFactor(context),
                  ),
                  "${AppLocalizations.of(rootContext)!.translate('transaction_info')}: ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardTitle(context),
                  ),
                ),
                transactionDetails.isNotEmpty
                    ? Column(children: transactionDetails)
                    : Text(
                        textScaler: TextScaler.linear(
                          ScaleSize.textScaleFactor(context),
                        ),
                        AppLocalizations.of(
                          rootContext,
                        )!.translate('no_transactions_available'),
                        style: TextStyle(color: AppColors.error(context)),
                      ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:bdk_dart/bdk.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/widget_helpers/custom_bottom_sheet.dart';
import 'package:flutter_wallet/widget_helpers/notification_helper.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_security_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_transaction_helpers.dart';
import 'package:flutter_wallet/widget_helpers/qr_code_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:path_provider/path_provider.dart';

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
  }) : securityHelper = WalletSecurityHelpers(
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
    // Determine color and sign (unchanged)
    Color balanceColor = ledBalance > 0
        ? AppColors.primary(context)
        : (ledBalance < 0 ? Colors.red : Colors.grey);

    bool isDataAvailable = address.isNotEmpty;

    final bool useSatsDisplay = avBalance <= 1000000;

    // Convert to display-friendly string
    String primaryDisplay = useSatsDisplay
        ? '${avBalance.toString()} sats'
        : '${UtilitiesService.formatBitcoinAmount(avBalance)} BTC';

    // Secondary (fiat) value
    String secondaryFiat =
        '${avCurrencyBalance.toStringAsFixed(2)} ${settingsProvider.currency}';

    // Led balance formatted with same sats/BTC logic
    String ledDisplay = "";
    if (ledBalance != 0) {
      if (useSatsDisplay) {
        ledDisplay = ledBalance > 0 ? "+ $ledBalance sats" : "$ledBalance sats";
      } else {
        ledDisplay = ledBalance > 0
            ? "+ ${UtilitiesService.formatBitcoinAmount(ledBalance)} BTC"
            : "${UtilitiesService.formatBitcoinAmount(ledBalance)} BTC";
      }
    }

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: AppColors.cardTitle(context).opaque(0.18),
              width: 1,
            ),
          ),
          elevation: 0,
          color: AppColors.gradient(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isDataAvailable
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------- HEADER ----------
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  textScaler: TextScaler.linear(
                                    ScaleSize.textScaleFactor(context),
                                  ),
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cardTitle(context),
                                  ),
                                ),
                                if (subtitle != null && subtitle.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      textScaler: TextScaler.linear(
                                        ScaleSize.textScaleFactor(context),
                                      ),
                                      subtitle,
                                      style: TextStyle(
                                        color: AppColors.cardTitle(
                                          context,
                                        ).opaque(0.7),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Action icons in a small “toolbar”
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: AppColors.cardTitle(context).opaque(0.08),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onLongPress: () {
                                    final BaseScaffoldState? baseScaffoldState =
                                        baseScaffoldKey.currentState;

                                    if (baseScaffoldState != null) {
                                      baseScaffoldState.updateAssistantMessage(
                                        context,
                                        'assistant_private_data',
                                      );
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
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onLongPress: () {
                                    final BaseScaffoldState? baseScaffoldState =
                                        baseScaffoldKey.currentState;

                                    if (baseScaffoldState != null) {
                                      baseScaffoldState.updateAssistantMessage(
                                        context,
                                        'assistant_pub_key_data',
                                      );
                                    }
                                  },
                                  onTap: () {
                                    _showPubKeyDialog();
                                  },
                                  child: Icon(
                                    Icons.more_vert,
                                    color: AppColors.cardTitle(context),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: AppColors.text(context).opaque(0.12),
                      ),
                      const SizedBox(height: 10),

                      // ---------- ADDRESS ----------
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.text(context).opaque(0.04),
                                border: Border.all(
                                  color: AppColors.text(context).opaque(0.10),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 18,
                                    color: AppColors.text(context).opaque(0.7),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      textScaler: TextScaler.linear(
                                        ScaleSize.textScaleFactor(context),
                                      ),
                                      address,
                                      style: TextStyle(
                                        // monospace-ish feel for addresses
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                        color: AppColors.text(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (showCopyButton) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(8),
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    UtilitiesService.copyToClipboard(
                                      context: context,
                                      text: address,
                                      messageKey: 'address_clipboard',
                                    );
                                  },
                                  icon: Icon(
                                    Icons.copy_rounded,
                                    size: 20,
                                    color: AppColors.cardTitle(context),
                                  ),
                                ),
                                IconButton(
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(8),
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    QrCodeHelper.showQrCodeDialog(
                                      context,
                                      address,
                                    );
                                  },
                                  icon: Icon(
                                    Icons.qr_code_rounded,
                                    size: 20,
                                    color: AppColors.cardTitle(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: AppColors.text(context).opaque(0.08),
                      ),
                      const SizedBox(height: 10),

                      // ---------- BALANCE SECTION ----------
                      GestureDetector(
                        onTap: onTap,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.text(context).opaque(0.05),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ---------------- PRIMARY ROW ----------------
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Left: Main balance (big)
                                  Expanded(
                                    child: Text(
                                      textScaler: TextScaler.linear(
                                        ScaleSize.textScaleFactor(context),
                                      ),
                                      primaryDisplay,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.text(context),
                                      ),
                                    ),
                                  ),

                                  // Right: LED Badge
                                  if (ledBalance != 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: balanceColor.opaque(0.18),
                                      ),
                                      child: Text(
                                        textScaler: TextScaler.linear(
                                          ScaleSize.textScaleFactor(context),
                                        ),
                                        ledDisplay,
                                        style: TextStyle(
                                          color: balanceColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // ---------------- SECONDARY ROW ----------------
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    textScaler: TextScaler.linear(
                                      ScaleSize.textScaleFactor(context),
                                    ),
                                    secondaryFiat,
                                    style: TextStyle(
                                      decoration: settingsProvider.isTestnet
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: AppColors.text(
                                        context,
                                      ).opaque(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: AppColors.text(context).opaque(0.08),
                      ),
                      const SizedBox(height: 10),

                      // ---------- HEIGHT + TIMESTAMP + REFRESH ----------
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.text(context).opaque(0.04),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Height chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: AppColors.text(
                                        context,
                                      ).opaque(0.06),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.dashboard_rounded,
                                          size: 14,
                                          color: AppColors.text(
                                            context,
                                          ).opaque(0.8),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          textScaler: TextScaler.linear(
                                            ScaleSize.textScaleFactor(context),
                                          ),
                                          '${AppLocalizations.of(context)!.translate('block')}: $currentHeight',
                                          style: TextStyle(
                                            color: AppColors.text(
                                              context,
                                            ).opaque(0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: AppColors.text(
                                        context,
                                      ).opaque(0.03),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          textScaler: TextScaler.linear(
                                            ScaleSize.textScaleFactor(context),
                                          ),
                                          timeStamp,
                                          style: TextStyle(
                                            color: AppColors.text(
                                              context,
                                            ).opaque(0.85),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (lastRefreshed != null)
                        if (DateTime.now().difference(lastRefreshed!).inHours >=
                            2) ...[
                          const SizedBox(height: 8),
                          Text(
                            textScaler: TextScaler.linear(
                              ScaleSize.textScaleFactor(context),
                            ),
                            getTimeBasedMessage(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.error(context),
                            ),
                          ).animate().shake(
                            duration: 800.ms,
                          ), // same shake effect
                        ],
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

  Widget buildTransactionsBoxTest() {
    final transactionHelpers = WalletTransactionHelpers(
      context: context,
      currentHeight: currentHeight,
      address: address,
      baseScaffoldKey: baseScaffoldKey,
      settingsProvider: settingsProvider,
      myAddresses: myAddresses,
    );

    final lastTwo = () {
      if (transactions.isEmpty) return <dynamic>[];

      final sorted = List.of(transactions);

      sorted.sort((a, b) {
        final at = a['timestamp'];
        final bt = b['timestamp'];

        final aTime = at is int ? at : int.tryParse(at.toString()) ?? 0;
        final bTime = bt is int ? bt : int.tryParse(bt.toString()) ?? 0;

        return bTime.compareTo(aTime);
      });

      return sorted.take(2).toList();
    }();

    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: AppColors.cardTitle(context).opaque(0.15),
          width: 1,
        ),
      ),
      elevation: 0, // flatter, more modern
      color: AppColors.gradient(context), // keep your brand style
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- HEADER ----------
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Icon(
                      Icons.swap_vert_rounded,
                      size: 20,
                      color: AppColors.cardTitle(context),
                    ),

                    // Count pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: AppColors.cardTitle(context).opaque(0.12),
                      ),
                      child: Text(
                        textScaler: TextScaler.linear(
                          ScaleSize.textScaleFactor(context),
                        ),
                        '${transactions.length}',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.cardTitle(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        textScaler: TextScaler.linear(
                          ScaleSize.textScaleFactor(context),
                        ),
                        AppLocalizations.of(context)!.translate('transactions'),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.cardTitle(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        textScaler: TextScaler.linear(
                          ScaleSize.textScaleFactor(context),
                        ),
                        AppLocalizations.of(
                          context,
                        )!.translate('showing_latest_transactions'),
                        // add this key or replace with a literal like "Latest 2 transactions"
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.cardTitle(context).opaque(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: showTransactionsBottomSheet,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    Icons.open_in_full_rounded,
                    size: 18,
                    color: AppColors.icon(context),
                  ),
                  label: Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    AppLocalizations.of(context)!.translate('view_all'),
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.icon(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: AppColors.cardTitle(context).opaque(0.15),
            ),
            const SizedBox(height: 8),

            // ---------- BODY ----------
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (lastTwo.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  textScaler: TextScaler.linear(
                    ScaleSize.textScaleFactor(context),
                  ),
                  AppLocalizations.of(
                    context,
                  )!.translate('no_transactions_available'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.cardTitle(context).opaque(0.7),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lastTwo.length,
                separatorBuilder: (_, _) => Divider(
                  height: 3,
                  color: AppColors.cardTitle(context).opaque(0.08),
                ),
                itemBuilder: (context, index) {
                  final tx = lastTwo[index];

                  return KeyedSubtree(
                    key: ValueKey(tx['txid']),
                    child: GestureDetector(
                      onTap: () {
                        transactionHelpers.showTransactionsDialog(tx);
                      },
                      child: transactionHelpers.buildTransactionItem(tx),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> showTransactionsBottomSheet() async {
    final transactionHelpers = WalletTransactionHelpers(
      context: context,
      currentHeight: currentHeight,
      address: address,
      baseScaffoldKey: baseScaffoldKey,
      settingsProvider: settingsProvider,
      myAddresses: myAddresses,
    );

    return CustomBottomSheet.buildCustomStatefulBottomSheet(
      context: context,
      titleKey: 'transactions',
      contentBuilder:
          (
            StateSetter setSheetState,
            void Function(BuildContext, String) updateAssistantMessage,
          ) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (transactions.isEmpty) {
              return Text(
                textScaler: TextScaler.linear(
                  ScaleSize.textScaleFactor(context),
                ),
                AppLocalizations.of(
                  context,
                )!.translate('no_transactions_available'),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textScaler: TextScaler.linear(
                    ScaleSize.textScaleFactor(context),
                  ),
                  '${transactions.length} '
                  '${AppLocalizations.of(context)!.translate('transactions')}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardTitle(context),
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];

                    return KeyedSubtree(
                      key: ValueKey(tx['txid']),
                      child: GestureDetector(
                        onTap: () {
                          transactionHelpers.showTransactionsDialog(tx);
                        },
                        child: transactionHelpers.buildTransactionItem(tx),
                      ),
                    );
                  },
                ),
              ],
            );
          },
    );
  }

  void _showPubKeyDialog() {
    final rootContext = context;

    CustomBottomSheet.buildCustomBottomSheet(
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
              border: Border.all(color: AppColors.background(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isSingleWallet) ...[
                  // 🔹 Saved Pub Key Label
                  Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    "${AppLocalizations.of(rootContext)!.translate('saved_pub_key')}: ",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.cardTitle(context)),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Public Key Display
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppColors.container(context),
                      borderRadius: BorderRadius.circular(8.0), // Rounded edges
                      border: Border.all(color: AppColors.background(context)),
                    ),
                    child: SizedBox(
                      width: double.infinity, // Ensure the Row gets a width
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              textScaler: TextScaler.linear(
                                ScaleSize.textScaleFactor(context),
                              ),
                              pubKeyController.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
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
                          const SizedBox(width: 6),
                          IconButton(
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              QrCodeHelper.showQrCodeDialog(
                                context,
                                pubKeyController.text,
                              );
                            },
                            icon: Icon(
                              Icons.qr_code_rounded,
                              size: 20,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (!isSingleWallet) ...[
                  // 🔹 Saved Descriptor Label
                  Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    "${AppLocalizations.of(rootContext)!.translate('saved_descriptor')}: ",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.cardTitle(context)),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Saved Descriptor Display
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppColors.container(context),
                      borderRadius: BorderRadius.circular(8.0), // Rounded edges
                      border: Border.all(color: AppColors.background(context)),
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
                              textScaler: TextScaler.linear(
                                ScaleSize.textScaleFactor(context),
                              ),
                              descriptor.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.text(context)),
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
              final payload = {
                'descriptor': descriptor,
                'publicKeysWithAlias': pubKeysAlias,
                'descriptorName': descriptorName,
              };

              // 1) Serialize to a temp file
              final tmpDir = await getTemporaryDirectory();
              final tmpPath = '${tmpDir.path}/$descriptorName.json';
              final tmpFile = File(tmpPath);
              await tmpFile.writeAsString(jsonEncode(payload), flush: true);

              // 2) Let Android/iOS show the native "Save as…" dialog (no storage perms needed)
              final params = SaveFileDialogParams(
                sourceFilePath: tmpFile.path,
                fileName: '$descriptorName.json',
                mimeTypesFilter: ['application/json'],
              );

              final savedPath = await FlutterFileDialog.saveFile(
                params: params,
              );

              if (savedPath == null) {
                // User canceled
                NotificationHelper.show(
                  rootContext,
                  message: AppLocalizations.of(
                    rootContext,
                  )!.translate('operation_canceled'),
                );
                return;
              }

              NotificationHelper.show(
                rootContext,
                message:
                    '${AppLocalizations.of(rootContext)!.translate('file_saved')} $savedPath',
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.cardTitle(context),
            ),
            child: Text(
              textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
              AppLocalizations.of(
                rootContext,
              )!.translate('download_descriptor'),
            ),
          ),
        ),
        Visibility(
          visible: !isSingleWallet,
          child: TextButton(
            onPressed: () async {
              try {
                // Build the same JSON
                final data = jsonEncode({
                  'descriptor': descriptor,
                  'publicKeysWithAlias': pubKeysAlias,
                  'descriptorName': descriptorName,
                });

                // Write JSON to a temporary file
                final tempDir = await getTemporaryDirectory();
                final fileName = '$descriptorName.json';
                final filePath = '${tempDir.path}/$fileName';
                final file = File(filePath);
                await file.writeAsString(data);

                // Share with new API
                await SharePlus.instance.share(
                  ShareParams(
                    files: [
                      XFile(
                        filePath,
                        mimeType: 'application/json',
                        name: fileName,
                      ),
                    ],
                    subject: descriptorName, // optional
                    text: AppLocalizations.of(rootContext)!.translate(
                      'share_descriptor_message',
                    ), // optional helper text
                  ),
                );
              } catch (e) {
                NotificationHelper.showError(
                  rootContext,
                  message: AppLocalizations.of(
                    rootContext,
                  )!.translate('share_failed'),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.cardTitle(context),
            ),
            child: Text(
              textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
              AppLocalizations.of(rootContext)!.translate('share_descriptor'),
            ),
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
    BuildContext context, {
    required int Function() getCurrentHeight,
    required List<Map<String, dynamic>> Function() getTransactions,
  }) async {
    if (connectivityResult.contains(ConnectivityResult.none)) {
      NotificationHelper.showError(
        context,
        message: AppLocalizations.of(context)!.translate('no_internet'),
      );

      return; // Exit early if there's no internet
    }

    try {
      final oldHeight = currentHeight;
      final oldTxIds = transactions
          .map((tx) => tx['txid'])
          .whereType<String>()
          .toSet();

      NotificationHelper.show(
        context,
        message: AppLocalizations.of(context)!.translate('syncing_wallet'),
      );

      await syncWallet();

      final newHeight = getCurrentHeight();
      final newTxIds = getTransactions()
          .map((tx) => tx['txid'])
          .whereType<String>()
          .toSet();

      // **Determine the message based on new block and transactions**
      final bool newBlockDetected = oldHeight != newHeight;
      final bool newTransactionDetected = newTxIds
          .difference(oldTxIds)
          .isNotEmpty;

      String syncMessage = AppLocalizations.of(
        context,
      )!.translate('no_updates_yet');

      if (newBlockDetected && newTransactionDetected) {
        syncMessage = AppLocalizations.of(
          context,
        )!.translate('new_block_transactions_detected');
      } else if (newBlockDetected) {
        syncMessage = AppLocalizations.of(
          context,
        )!.translate('new_block_detected');
      } else if (newTransactionDetected) {
        syncMessage = AppLocalizations.of(
          context,
        )!.translate('new_transaction_detected');
      }

      if (newBlockDetected || newTransactionDetected) {
        NotificationHelper.show(context, message: syncMessage);

        NotificationHelper.show(
          context,
          message: AppLocalizations.of(context)!.translate('syncing_complete'),
        );
      } else {
        NotificationHelper.show(context, message: syncMessage);
      }
    } catch (e) {
      NotificationHelper.showError(
        context,
        message:
            "${AppLocalizations.of(context)!.translate('syncing_error')} ${e.toString()}",
      );
    }
  }
}

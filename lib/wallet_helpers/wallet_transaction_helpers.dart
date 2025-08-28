import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/widget_helpers/custom_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class WalletTransactionHelpers {
  final BuildContext context;
  final int currentHeight;
  final String address;
  final GlobalKey<BaseScaffoldState> baseScaffoldKey;
  final SettingsProvider settingsProvider;
  final Set<String> myAddresses;

  WalletTransactionHelpers({
    required this.context,
    required this.currentHeight,
    required this.address,
    required this.baseScaffoldKey,
    required this.settingsProvider,
    required this.myAddresses,
  });

  void showTransactionsDialog(Map<String, dynamic> transaction) {
    final String mempoolUrl = settingsProvider.isTestnet
        ? 'https://mempool.space/testnet4'
        : 'https://mempool.space/';

    final txid = transaction['txid'];

    // Extract confirmation details
    final blockHeight = transaction['status']?['block_height'];
    final isConfirmed = blockHeight != null;
    final unformattedBlockTime = transaction['status']['block_time'] ?? 0;

    DateTime formattedTime =
        DateTime.fromMillisecondsSinceEpoch(unformattedBlockTime * 1000);
    if (settingsProvider.isTestnet) {
      formattedTime = formattedTime.subtract(const Duration(hours: 2));
    }

    final blockTime = isConfirmed
        ? formattedTime
            .toString()
            .substring(0, formattedTime.toString().length - 7)
        : 'Unconfirmed';

    // Extract transaction fee
    final fee = transaction['fee'] ?? 0;

    // Extract all input addresses (senders)
    final Set<String> inputAddresses = (transaction['vin'] as List<dynamic>)
        .map((vin) => vin['prevout']['scriptpubkey_address'] as String)
        .toSet();

    // Extract all ouput addresses (receivers
    final Set<String> outputAddresses = (transaction['vout'] as List<dynamic>)
        .map((vout) => vout['scriptpubkey_address'] as String)
        .toSet();

    final int totalOutput = transaction['vout']?.fold<int>(
          0,
          (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
        ) ??
        0;

    // Determine if transaction is sent, received, or internal
    final isSent = inputAddresses.any((addr) => myAddresses.contains(addr));
    final isReceived =
        outputAddresses.any((addr) => myAddresses.contains(addr));
    final isInternal = isSent &&
        isReceived &&
        inputAddresses.any((addr) => myAddresses.contains(addr)) &&
        outputAddresses.any((addr) => myAddresses.contains(addr));

    // Determine the actual amount sent/received
    int amount = 0;

    if (isInternal) {
      amount = totalOutput; // Internal tx stays the same
    } else if (isSent) {
      // Sum outputs *not* belonging to any of your addresses
      amount = transaction['vout']
              ?.where(
                  (vout) => !myAddresses.contains(vout['scriptpubkey_address']))
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    } else if (isReceived) {
      // Sum outputs that *do* belong to any of your addresses
      amount = transaction['vout']
              ?.where(
                  (vout) => myAddresses.contains(vout['scriptpubkey_address']))
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    }

    final rootContext = context;

    CustomBottomSheet.buildCustomStatefulBottomSheet(
      context: context,
      titleKey: 'transaction_details',
      showAssistant: true,
      assistantMessages: [
        'assistant_transactions_dialog1',
        'assistant_transactions_dialog2',
      ],
      contentBuilder: (setDialogState, updateAssistantMessage) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                  // Transaction Type
                  Text(
                    isInternal
                        ? AppLocalizations.of(rootContext)!
                            .translate('internal_tx')
                        : isSent
                            ? AppLocalizations.of(rootContext)!
                                .translate('sent_tx')
                            : AppLocalizations.of(rootContext)!
                                .translate('received_tx'),
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.cardTitle(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sender Addresses
                  Text(
                    AppLocalizations.of(rootContext)!.translate('senders'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardTitle(context),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: inputAddresses.map((sender) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.container(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                sender,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.text(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                color: AppColors.icon(context),
                                size: 20,
                              ),
                              onPressed: () {
                                UtilitiesService.copyToClipboard(
                                  context: rootContext,
                                  text: sender,
                                  messageKey: 'address_clipboard',
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 8),

                  // Receiver Addresses
                  Text(
                    AppLocalizations.of(rootContext)!.translate('receivers'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardTitle(context),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: outputAddresses.map((receiver) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.container(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                receiver,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.text(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                color: AppColors.icon(context),
                                size: 20,
                              ),
                              onPressed: () {
                                UtilitiesService.copyToClipboard(
                                  context: rootContext,
                                  text: receiver,
                                  messageKey: 'address_clipboard',
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 8),

                  // Amount Sent/Received
                  Text(
                    AppLocalizations.of(rootContext)!.translate('amount'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardTitle(context),
                    ),
                  ),
                  Text(
                    UtilitiesService.formatBitcoinAmount(amount),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Transaction Fee
                  if (isSent || isInternal) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(rootContext)!.translate('fee'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardTitle(context),
                          ),
                        ),
                        Text(
                          UtilitiesService.formatBitcoinAmount(fee),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Confirmation Details
                  Text(
                    AppLocalizations.of(rootContext)!
                        .translate('confirmation_details'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardTitle(context),
                    ),
                  ),
                  Text(
                    isConfirmed
                        ? "${AppLocalizations.of(rootContext)!.translate('confirmed_block')}: $blockHeight"
                        : "${AppLocalizations.of(rootContext)!.translate('status')}: ${AppLocalizations.of(rootContext)!.translate('unconfirmed')}",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.text(context),
                    ),
                  ),
                  if (isConfirmed)
                    Text(
                      "${AppLocalizations.of(rootContext)!.translate('timestamp')}: $blockTime",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text(context),
                      ),
                    ),

                  GestureDetector(
                    onTap: () async {
                      final Uri url = Uri.parse("$mempoolUrl/tx/$txid/");

                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      } else {
                        throw "Could not launch $url";
                      }
                    },
                    child: Text(
                      AppLocalizations.of(rootContext)!.translate('mempool'),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.cardTitle(context),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildTransactionItem(Map<String, dynamic> tx) {
    // Extract confirmation details
    final blockHeight = tx['status']?['block_height'];
    final isConfirmed = blockHeight != null;
    final unformattedBlockTime = tx['status']['block_time'] ?? 0;

    DateTime formattedTime =
        DateTime.fromMillisecondsSinceEpoch(unformattedBlockTime * 1000);
    if (settingsProvider.isTestnet) {
      formattedTime = formattedTime.subtract(const Duration(hours: 2));
    }

    final blockTime = isConfirmed
        ? formattedTime
            .toString()
            .substring(0, formattedTime.toString().length - 7)
        : 'Unconfirmed';

    // Transaction fee
    final fee = tx['fee'] ?? 0;

    // Extract all input addresses (senders) and their total input value
    final inputAddresses = (tx['vin'] as List<dynamic>?)
            ?.map((vin) => vin['prevout']?['scriptpubkey_address'] as String?)
            .where((addr) => addr != null)
            .toSet() ??
        <String>{};

    // Extract all output addresses (receivers) and their total output value
    final outputAddresses = (tx['vout'] as List<dynamic>?)
            ?.map((vout) => vout['scriptpubkey_address'] as String?)
            .where((addr) => addr != null)
            .toSet() ??
        {};

    final totalOutput = tx['vout']?.fold<int>(
          0,
          (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
        ) ??
        0;

    // Check if transaction is sent, received, or internal
    final isSent = inputAddresses.any((addr) => myAddresses.contains(addr));
    final isReceived =
        outputAddresses.any((addr) => myAddresses.contains(addr));
    final isInternal = isSent &&
        isReceived &&
        inputAddresses.any((addr) => myAddresses.contains(addr)) &&
        outputAddresses.any((addr) => myAddresses.contains(addr));

    // Determine the amount sent/received
    int amount = 0;

    if (isInternal) {
      amount = totalOutput; // Internal tx stays the same
    } else if (isSent) {
      // Sum outputs *not* belonging to any of your addresses
      amount = tx['vout']
              ?.where(
                  (vout) => !myAddresses.contains(vout['scriptpubkey_address']))
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    } else if (isReceived) {
      // Sum outputs that *do* belong to any of your addresses
      amount = tx['vout']
              ?.where(
                  (vout) => myAddresses.contains(vout['scriptpubkey_address']))
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    }

    // Extract specific sender/recipient address
    String? counterpartyAddress;

    if (isSent) {
      counterpartyAddress = outputAddresses
          .where((addr) => !myAddresses.contains(addr))
          .join(', ');
    } else if (isReceived) {
      // If multiple input addresses exist, the sender is likely the one contributing the most BTC.
      if (inputAddresses.isNotEmpty) {
        counterpartyAddress = inputAddresses
            .where((addr) => !myAddresses.contains(addr))
            .join(', ');

        // Find the input with the highest value (likely the fee payer)
        int highestInputValue = 0;
        String? feePayerAddress;

        for (var vin in tx['vin']) {
          String? inputAddr = vin['prevout']?['scriptpubkey_address'];
          int inputValue = vin['prevout']?['value'] ?? 0;

          if (inputAddr != null && inputValue > highestInputValue) {
            highestInputValue = inputValue;
            feePayerAddress = inputAddr;
          }
        }

        // Use the highest input as the sender if found
        if (feePayerAddress != null) {
          counterpartyAddress = feePayerAddress;
        }
      }
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 2,
      color: isInternal
          ? Colors.amber
          : isSent
              ? Colors.red[900]
              : AppColors.background(context),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  isConfirmed ? Icons.check_circle : Icons.timelapse,
                  color: isConfirmed
                      ? AppColors.text(context)
                      : AppColors.unconfirmedColor,
                ),
                Text(
                  // Show only the fee payed for internal transactions
                  isInternal
                      ? "${AppLocalizations.of(context)!.translate('internal')}: - ${UtilitiesService.formatBitcoinAmount(fee)}"
                      : '${isSent ? "${AppLocalizations.of(context)!.translate('sent')}: - " : "${AppLocalizations.of(context)!.translate('received')}: + "}${UtilitiesService.formatBitcoinAmount(amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.text(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!isInternal)
              Text(
                isSent
                    ? "${AppLocalizations.of(context)!.translate('to')}: $counterpartyAddress"
                    : "${AppLocalizations.of(context)!.translate('from')}: $counterpartyAddress",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.text(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 4),
            if (isSent && !isInternal)
              Text(
                '${AppLocalizations.of(context)!.translate('fee')}: $fee sats',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.text(context),
                ),
              ),
            const SizedBox(height: 4),
            if (isConfirmed)
              Text(
                "${AppLocalizations.of(context)!.translate('confirmed')}: $blockTime",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.text(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

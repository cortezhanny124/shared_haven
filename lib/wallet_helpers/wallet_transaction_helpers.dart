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
        ? 'https://mempool.space/testnet'
        : 'https://mempool.space/';

    int parseAmount(dynamic v) {
      if (v is BigInt) return v.toInt();
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final txid = transaction['txid'] ?? '';

    // ---- BASIC BDK FIELDS ----
    final int received = parseAmount(transaction['received']);
    final int sent = parseAmount(transaction['sent']);
    final int fee = parseAmount(transaction['fee']);

    final Map<String, dynamic>? confirmationTime =
        (transaction['confirmationTime'] as Map?)?.cast<String, dynamic>();

    final bool isConfirmed = confirmationTime != null;
    final int height = parseAmount(confirmationTime?['height']);
    final int timestampSeconds = parseAmount(confirmationTime?['timestamp']);

    // ---- TIME FORMAT ----
    String blockTime = 'Unconfirmed';
    if (isConfirmed && timestampSeconds > 0) {
      DateTime formattedTime = DateTime.fromMillisecondsSinceEpoch(
        timestampSeconds * 1000,
      );
      if (settingsProvider.isTestnet) {
        formattedTime = formattedTime.subtract(const Duration(hours: 2));
      }
      final s = formattedTime.toString(); // yyyy-MM-dd HH:mm:ss.mmm
      blockTime = s.substring(0, s.length - 7); // trim millis
    }

    // ---- DIRECTION & AMOUNT ----
    final int net = received - sent; // >0 incoming, <0 outgoing, 0 ~ internal

    bool isSent = false;
    bool isInternal = false;
    int amount = 0;

    if (net > 0) {
      amount = net;
    } else if (net < 0) {
      isSent = true;
      amount = -net;
    } else {
      // net == 0: likely internal move / self-transfer
      isInternal = true;
      amount = sent != 0 ? sent : received;
    }

    final rootContext = context;

    CustomBottomSheet.buildCustomStatefulBottomSheet(
      context: context,
      titleKey: 'transaction_details',
      showAssistant: true,
      assistantMessages: const [
        'assistant_transactions_dialog1',
        'assistant_transactions_dialog2',
      ],
      contentBuilder: (setDialogState, updateAssistantMessage) {
        final textColor = AppColors.text(context);
        final cardTitleColor = AppColors.cardTitle(context);

        final typeLabel = isInternal
            ? AppLocalizations.of(rootContext)!.translate('internal_tx')
            : isSent
            ? AppLocalizations.of(rootContext)!.translate('sent_tx')
            : AppLocalizations.of(rootContext)!.translate('received_tx');

        final statusLabel = isConfirmed
            ? AppLocalizations.of(rootContext)!.translate('confirmed')
            : AppLocalizations.of(rootContext)!.translate('unconfirmed');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: AppColors.container(context),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: AppColors.background(context).opaque(0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- HEADER ROW ----------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Status icon bubble
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConfirmed
                              ? AppColors.primary(context).opaque(0.15)
                              : AppColors.unconfirmedColor.opaque(0.2),
                        ),
                        child: Icon(
                          isConfirmed ? Icons.check_circle : Icons.timelapse,
                          color: isConfirmed
                              ? AppColors.primary(context)
                              : AppColors.unconfirmedColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Type + small status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              textScaler: TextScaler.linear(
                                ScaleSize.textScaleFactor(context),
                              ),
                              typeLabel,
                              style: TextStyle(
                                color: cardTitleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              textScaler: TextScaler.linear(
                                ScaleSize.textScaleFactor(context),
                              ),
                              statusLabel,
                              style: TextStyle(color: textColor.opaque(0.7)),
                            ),
                          ],
                        ),
                      ),
                      // Amount big on the right
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            textScaler: TextScaler.linear(
                              ScaleSize.textScaleFactor(context),
                            ),
                            (isInternal
                                    ? "${AppLocalizations.of(rootContext)!.translate('internal')}: "
                                    : isSent
                                    ? "- "
                                    : "+ ") +
                                UtilitiesService.formatBitcoinAmount(amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(height: 1, color: textColor.opaque(0.1)),
                  const SizedBox(height: 12),

                  // ---------- META "CHIPS" ----------
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: textColor.opaque(0.04),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isConfirmed
                                  ? Icons.verified_rounded
                                  : Icons.hourglass_top_rounded,
                              size: 14,
                              color: textColor.opaque(0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              textScaler: TextScaler.linear(
                                ScaleSize.textScaleFactor(context),
                              ),
                              statusLabel,
                              style: TextStyle(color: textColor.opaque(0.9)),
                            ),
                          ],
                        ),
                      ),

                      // Block height chip
                      if (isConfirmed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: textColor.opaque(0.04),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers_rounded,
                                size: 14,
                                color: textColor.opaque(0.8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                textScaler: TextScaler.linear(
                                  ScaleSize.textScaleFactor(context),
                                ),
                                "${AppLocalizations.of(rootContext)!.translate('confirmed_block')}: $height",
                                style: TextStyle(
                                  fontSize:
                                      12 *
                                      MediaQuery.of(context).textScaleFactor,
                                  color: textColor.opaque(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Time chip
                      if (isConfirmed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: textColor.opaque(0.04),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: textColor.opaque(0.8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                textScaler: TextScaler.linear(
                                  ScaleSize.textScaleFactor(context),
                                ),
                                blockTime,
                                style: TextStyle(
                                  fontSize:
                                      12 *
                                      MediaQuery.of(context).textScaleFactor,
                                  color: textColor.opaque(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Fee chip
                      if ((isSent || isInternal) && fee > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: textColor.opaque(0.04),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color: textColor.opaque(0.8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                textScaler: TextScaler.linear(
                                  ScaleSize.textScaleFactor(context),
                                ),
                                "${AppLocalizations.of(rootContext)!.translate('fee')}: ${UtilitiesService.formatBitcoinAmount(fee)}",
                                style: TextStyle(
                                  fontSize:
                                      12 *
                                      MediaQuery.of(context).textScaleFactor,
                                  color: textColor.opaque(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ---------- TXID BLOCK ----------
                  Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    "TXID",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cardTitleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: textColor.opaque(0.03),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            textScaler: TextScaler.linear(
                              ScaleSize.textScaleFactor(context),
                            ),
                            txid.toString(),
                            style: TextStyle(
                              color: textColor,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy,
                            size: 18,
                            color: AppColors.icon(context),
                          ),
                          onPressed: () {
                            UtilitiesService.copyToClipboard(
                              context: rootContext,
                              text: txid,
                              messageKey: 'address_clipboard',
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---------- MEMPOOL LINK BUTTON ----------
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () async {
                        final Uri url = Uri.parse("$mempoolUrl/tx/$txid");

                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          throw "Could not launch $url";
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.primary(context).opaque(0.12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: AppColors.primary(context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              textScaler: TextScaler.linear(
                                ScaleSize.textScaleFactor(context),
                              ),
                              AppLocalizations.of(
                                rootContext,
                              )!.translate('mempool'),
                              style: TextStyle(
                                color: AppColors.primary(context),
                              ),
                            ),
                          ],
                        ),
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

  int parseAmount(dynamic v) {
    if (v is BigInt) return v.toInt();
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Widget buildTransactionItem(Map<String, dynamic> tx) {
    // ---- BASIC FIELDS FROM BDK STRUCT ----
    final int received = parseAmount(tx['received']);
    final int sent = parseAmount(tx['sent']);
    final int fee = parseAmount(tx['fee']);

    final dynamic raw = tx['confirmationTime'];

    final Map<String, dynamic>? confirmationTime = (raw is Map)
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : null;

    final bool isConfirmed = confirmationTime != null;
    final int timestampSeconds = parseAmount(confirmationTime?['timestamp']);

    // ---- TIME / DATE ----
    String blockTime = 'Unconfirmed';
    if (isConfirmed && timestampSeconds > 0) {
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(
        timestampSeconds * 1000,
      );
      if (settingsProvider.isTestnet) {
        dt = dt.subtract(const Duration(hours: 2));
      }
      final dtStr = dt.toString(); // e.g. 2025-11-19 17:23:01.124
      blockTime = dtStr.substring(0, dtStr.length - 7); // 2025-11-19 17:23
    }

    // ---- DIRECTION & AMOUNT (wallet-point-of-view) ----
    final int net = received - sent; // >0 incoming, <0 outgoing, 0 internal-ish

    bool isSent = false;
    bool isInternal = false;
    int amount = 0;

    if (net > 0) {
      // More received than sent → net incoming
      amount = net;
    } else if (net < 0) {
      // More sent than received → net outgoing
      isSent = true;
      amount = -net;
    } else {
      // net == 0 → likely internal (change), or weird edge-case
      if (sent > 0 || received > 0) {
        isInternal = true;
        amount = sent; // for display, could also use `received`
      } else {
        // truly zero movement, keep as internal/no-op
        isInternal = true;
        amount = 0;
      }
    }

    // ---- VISUAL ACCENT COLORS ----
    final baseText = AppColors.text(context);
    final receivedColor = AppColors.primary(context);
    final sentColor = Colors.redAccent;
    final internalColor = Colors.amber[700]!;

    final Color accentColor = isInternal
        ? internalColor
        : isSent
        ? sentColor
        : receivedColor;

    final String typeLabel = isInternal
        ? AppLocalizations.of(context)!.translate('internal')
        : isSent
        ? AppLocalizations.of(context)!.translate('sent')
        : AppLocalizations.of(context)!.translate('received');

    final String subtitleLabel = isConfirmed
        ? blockTime
        : AppLocalizations.of(context)!.translate('unconfirmed');

    // ---- UI CARD ----
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.container(context),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            // Accent stripe
            Container(
              width: 4,
              height: 70,
              decoration: BoxDecoration(
                color: accentColor.opaque(0.9),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),

            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: icon + type/time + amount + chevron
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Circle status icon
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.opaque(0.15),
                          ),
                          child: Icon(
                            isConfirmed ? Icons.check_circle : Icons.timelapse,
                            size: 18,
                            color: isConfirmed
                                ? accentColor
                                : AppColors.unconfirmedColor,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Type + subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                textScaler: TextScaler.linear(
                                  ScaleSize.textScaleFactor(context),
                                ),
                                typeLabel,
                                style: TextStyle(
                                  fontSize:
                                      14 *
                                      MediaQuery.of(context).textScaleFactor,
                                  fontWeight: FontWeight.w600,
                                  color: baseText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                textScaler: TextScaler.linear(
                                  ScaleSize.textScaleFactor(context),
                                ),
                                subtitleLabel,
                                style: TextStyle(
                                  fontSize:
                                      11 *
                                      MediaQuery.of(context).textScaleFactor,
                                  color: baseText.opaque(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Amount
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              textScaler: TextScaler.linear(
                                ScaleSize.textScaleFactor(context),
                              ),
                              isInternal
                                  ? "- ${UtilitiesService.formatBitcoinAmount(fee)}"
                                  : (isSent ? "- " : "+ ") +
                                        UtilitiesService.formatBitcoinAmount(
                                          amount,
                                        ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: baseText,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: baseText.opaque(0.8),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Fee chip (for sent / internal)
                    if ((isSent || isInternal) && fee > 0)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: baseText.opaque(0.04),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 12,
                                  color: baseText.opaque(0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  textScaler: TextScaler.linear(
                                    ScaleSize.textScaleFactor(context),
                                  ),
                                  '${AppLocalizations.of(context)!.translate('fee')}: $fee sats',
                                  style: TextStyle(
                                    fontSize:
                                        11 *
                                        MediaQuery.of(context).textScaleFactor,
                                    color: baseText.opaque(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

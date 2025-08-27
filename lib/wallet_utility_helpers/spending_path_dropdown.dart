import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class SpendingPathDropdown extends StatelessWidget {
  final Map<String, dynamic>? selectedPath;
  final List<Map<String, dynamic>> extractedData;
  final Function(Map<String, dynamic>, int) onSelected;
  final WalletService walletService;
  final List<dynamic>? utxos;
  final TextEditingController amountController;
  final int currentHeight;
  final List<Map<String, String>>? pubKeysAlias;
  final BuildContext rootContext;
  final void Function(void Function()) setDialogState;

  const SpendingPathDropdown({
    super.key,
    required this.selectedPath,
    required this.extractedData,
    required this.onSelected,
    required this.walletService,
    required this.utxos,
    required this.amountController,
    required this.currentHeight,
    required this.pubKeysAlias,
    required this.rootContext,
    required this.setDialogState,
  });

  /// Best-effort textual reason based on visible data.
  /// NOTE: This does not know walletService internals; it just infers obvious things.
  String _inferReason(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final timelock = data['timelock'];

    if (type.contains('ABSOLUTETIMELOCK')) {
      if (timelock is int) {
        if (currentHeight < timelock) {
          return "absolute height not reached (current=$currentHeight, needed=$timelock)";
        }
      }
      return "absolute timelock condition may not be satisfied";
    }

    if (type.contains('RELATIVETIMELOCK')) {
      // We don't have UTXO confirmations here to be precise.
      // Provide a generic hint:
      return "relative timelock may not be satisfied (requires OLDER=$timelock blocks)";
    }

    if (type.contains('MULTISIG')) {
      final threshold = data['threshold'];
      final fps = (data['fingerprints'] as List?)?.length ?? 0;
      if (threshold is int && threshold > fps) {
        return "threshold ($threshold) > available keys ($fps)";
      }
      return "multisig condition may not be satisfied";
    }

    return "unknown reason (no explicit rule matched)";
  }

  void _logDecision({
    required Map<String, dynamic> data,
    required bool isSelectable,
    required List<String> aliases,
  }) {
    final type = data['type'];
    final timelock = data['timelock'];
    final threshold = data['threshold'];
    final amountTxt = amountController.text;
    final utxosLen = utxos?.length ?? 0;

    debugPrint("[Dropdown] Decision → selectable=$isSelectable | "
        "type=$type, timelock=$timelock, threshold=$threshold, "
        "aliases=$aliases | amount='$amountTxt', utxos=$utxosLen, height=$currentHeight");

    if (!isSelectable) {
      final inferred = _inferReason(data);
      debugPrint("[Dropdown]  └─ inferred reason (best-effort): $inferred");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Log current selection at build time
    debugPrint(
        "[Dropdown] build() | selectedPath=${selectedPath?['type']} timelock=${selectedPath?['timelock']}");

    return DropdownButtonFormField(
      value: selectedPath,
      items: extractedData.map((data) {
        final isSelectable = walletService.checkCondition(
          data,
          utxos!,
          amountController.text,
          currentHeight,
        );

        final aliases =
            (data['fingerprints'] as List<dynamic>).map<String>((fp) {
          final match = pubKeysAlias!.firstWhere(
            (alias) => alias['publicKey']!.contains(fp),
            orElse: () => {'alias': fp},
          );
          final alias = match['alias'] ?? fp;
          debugPrint("[Dropdown] Fingerprint $fp → alias=$alias");
          return alias;
        }).toList();

        // Centralized decision log (with all inputs)
        _logDecision(data: data, isSelectable: isSelectable, aliases: aliases);

        return DropdownMenuItem<Map<String, dynamic>>(
          value: data,
          enabled: isSelectable,
          child: Text(
            "${AppLocalizations.of(rootContext)!.translate('type')}: "
            "${data['type'].contains('RELATIVETIMELOCK') ? 'OLDER: ${data['timelock']} ${AppLocalizations.of(rootContext)!.translate('blocks')}' : data['type'].contains('ABSOLUTETIMELOCK') ? 'AFTER: ${data['timelock']} ${AppLocalizations.of(rootContext)!.translate('height')}' : 'MULTISIG'}, "
            "${data['threshold'] != null ? '${data['threshold']} of ${aliases.length}, ' : ''} ${AppLocalizations.of(rootContext)!.translate('keys')}: ${aliases.join(', ')}"
            "${isSelectable ? '' : '  (disabled)'}",
            style: TextStyle(
              fontSize: 14,
              color: isSelectable
                  ? AppColors.text(context)
                  : AppColors.unavailableColor,
            ),
          ),
        );
      }).toList(),
      onTap: () {
        setDialogState(() {
          // When the menu opens, dump a summary of enabled/disabled
          final summary = extractedData.map((d) {
            final ok = walletService.checkCondition(
              d,
              utxos!,
              amountController.text,
              currentHeight,
            );
            return {
              'type': d['type'],
              'timelock': d['timelock'],
              'enabled': ok,
              'reason': ok ? 'eligible' : _inferReason(d),
            };
          }).toList();

          debugPrint("[Dropdown] Menu opened – summary (${summary.length}):");
          for (final row in summary) {
            debugPrint(
                "  → type=${row['type']}, timelock=${row['timelock']}, enabled=${row['enabled']} (${row['reason']})");
          }
        });
      },
      onChanged: (value) {
        if (value != null) {
          setDialogState(() {
            final index = extractedData.indexOf(value);
            // Re-evaluate and log at selection time too
            final recheck = walletService.checkCondition(
              value,
              utxos!,
              amountController.text,
              currentHeight,
            );
            debugPrint(
                "[Dropdown] User selected index=$index, type=${value['type']}, timelock=${value['timelock']}, selectableNow=$recheck");
            if (!recheck) {
              debugPrint(
                  "[Dropdown]  └─ selection appears disabled; inferred: ${_inferReason(value)}");
            }
            onSelected(value, index);
          });
        } else {
          debugPrint("[Dropdown] Selection cleared (null)");
        }
      },
      selectedItemBuilder: (context) {
        return extractedData.map((data) {
          debugPrint(
              "[Dropdown] Building selectedItem preview for type=${data['type']}, timelock=${data['timelock']}");
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "${data['type'].contains('RELATIVETIMELOCK') ? 'OLDER: ${data['timelock']} ${AppLocalizations.of(rootContext)!.translate('blocks')}' : data['type'].contains('ABSOLUTETIMELOCK') ? 'AFTER: ${data['timelock']} ${AppLocalizations.of(rootContext)!.translate('height')}' : 'MULTISIG'}, ...",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.text(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList();
      },
      decoration: InputDecoration(
        labelText: AppLocalizations.of(rootContext)!
            .translate('spending_path_required'),
        labelStyle: TextStyle(color: AppColors.text(context)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.text(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary(context)),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dropdownColor: AppColors.gradient(context),
      icon: Icon(Icons.arrow_drop_down, color: AppColors.text(context)),
      style: TextStyle(color: AppColors.text(context)),
    );
  }
}

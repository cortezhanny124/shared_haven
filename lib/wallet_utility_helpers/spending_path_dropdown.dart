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

  @override
  Widget build(BuildContext context) {
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
          return match['alias'] ?? fp;
        }).toList();

        return DropdownMenuItem<Map<String, dynamic>>(
          value: data,
          enabled: isSelectable,
          child: Text(
            "${AppLocalizations.of(rootContext)!.translate('type')}: "
            "${data['type'].contains('RELATIVETIMELOCK') ? 'OLDER: ${data['timelock']} ${AppLocalizations.of(rootContext)!.translate('blocks')}' : data['type'].contains('ABSOLUTETIMELOCK') ? 'AFTER: ${data['timelock']} ${AppLocalizations.of(rootContext)!.translate('height')}' : 'MULTISIG'}, "
            "${data['threshold'] != null ? '${data['threshold']} of ${aliases.length}, ' : ''} ${AppLocalizations.of(rootContext)!.translate('keys')}: ${aliases.join(', ')}",
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
          // print('Rebuilding');
        });
      },
      onChanged: (value) {
        if (value != null) {
          setDialogState(() {
            final index = extractedData.indexOf(value);
            onSelected(value, index);
          });
        }
      },
      selectedItemBuilder: (context) {
        return extractedData.map((data) {
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

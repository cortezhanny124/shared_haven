import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:hive/hive.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class WalletSecurityHelpers {
  final BuildContext context;
  final String? descriptor;
  final String? descriptorName;
  final List<Map<String, String>>? pubKeysAlias;

  WalletSecurityHelpers({
    required this.context,
    this.descriptor,
    this.descriptorName,
    this.pubKeysAlias,
  });

  // Function to show a PIN input dialog
  Future<bool> showPinDialog(
    String dialog, {
    bool isSingleWallet = false,
  }) async {
    TextEditingController pinController =
        TextEditingController(); // Controller for the PIN input

    final rootContext = context;

    return (await DialogHelper.buildCustomDialog<bool>(
          context: rootContext,
          titleKey: 'enter_pin',
          showCloseButton: false,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(rootContext)!
                    .translate('enter_6_digits_pin'),
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.text(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: rootContext,
                  labelText:
                      AppLocalizations.of(rootContext)!.translate('enter_pin'),
                  hintText:
                      AppLocalizations.of(rootContext)!.translate('enter_pin'),
                ),
                style: TextStyle(color: AppColors.text(context)),
              ),
            ],
          ),
          actions: [
            InkwellButton(
              onTap: () =>
                  Navigator.of(rootContext, rootNavigator: true).pop(false),
              backgroundColor: AppColors.text(context),
              textColor: AppColors.gradient(context),
              icon: Icons.cancel_rounded,
              iconColor: AppColors.gradient(context),
            ),
            InkwellButton(
              onTap: () async {
                try {
                  Navigator.of(context, rootNavigator: true).pop(true);

                  await verifyPin(
                    pinController,
                    isSingleWallet: isSingleWallet,
                  );
                } catch (e) {
                  SnackBarHelper.showError(
                    rootContext,
                    message: AppLocalizations.of(rootContext)!
                        .translate('pin_incorrect'),
                  );
                }
              },
              backgroundColor: AppColors.background(context),
              textColor: AppColors.text(context),
              icon: Icons.check_rounded,
              iconColor: AppColors.gradient(context),
            ),
          ],
        )) ??
        false; // Default to `false` if the dialog is dismissed
  }

  Future<bool?> verifyPin(
    TextEditingController pinController, {
    bool isSingleWallet = false,
  }) async {
    var walletBox = Hive.box('walletBox');
    String? savedPin = walletBox.get('userPin');

    String savedMnemonic = walletBox.get('walletMnemonic');

    if (savedPin == pinController.text) {
      privateDataDialog(context, savedMnemonic, isSingleWallet);
    } else {
      SnackBarHelper.showError(
        context,
        message: AppLocalizations.of(context)!.translate('pin_incorrect'),
      );
    }
    return null;
  }

  void privateDataDialog(
    BuildContext context,
    String savedMnemonic,
    bool isSingleWallet,
  ) {
    final rootContext = context;

    DialogHelper.buildCustomDialog(
      context: context,
      titleKey: 'private_data',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(rootContext)!.translate('saved_mnemonic'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.cardTitle(context),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.container(context),
              borderRadius: BorderRadius.circular(8.0), // Rounded edges
              border: Border.all(
                color: AppColors.background(context),
              ),
            ),
            child: Container(
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
                    Expanded(
                      child: Text(
                        savedMnemonic,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // IconButton(
                    //   icon: Icon(
                    //     Icons.copy,
                    //     color: AppColors.icon(context),
                    //   ),
                    //   onPressed: () {
                    //     UtilitiesService.copyToClipboard(
                    //       context: rootContext,
                    //       text: savedMnemonic,
                    //       messageKey: 'mnemonic_clipboard',
                    //     );
                    //   },
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [],
    );
  }
}

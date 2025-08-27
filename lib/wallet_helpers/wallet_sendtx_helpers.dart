import 'dart:io';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/wallet_utility_helpers/spending_path_details_card.dart';
import 'package:flutter_wallet/wallet_utility_helpers/spending_path_dropdown.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:flutter_wallet/widget_helpers/fee_selector.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class WalletSendtxHelpers {
  final bool isSingleWallet;
  final BuildContext context;
  final TextEditingController recipientController;
  final TextEditingController amountController;
  final WalletService walletService;
  final int currentHeight;
  final Wallet wallet;
  final String mnemonic;
  final bool mounted;
  final BigInt avBalance;
  final void Function(String newAddress)? onNewAddressGenerated;
  Future<void> Function() syncWallet;

  TextEditingController? psbtController;
  TextEditingController? signingAmountController;
  Map<String, dynamic>? policy;
  String? myFingerPrint;
  List<dynamic>? utxos;
  List<Map<String, dynamic>>? spendingPaths;
  String? descriptor;
  List<String>? signersList;
  List<Map<String, String>>? pubKeysAlias;
  double? customFeeRate;

  bool isFirstTap = true;
  bool showPSBT = false;

  Map<String, dynamic>? selectedPath;
  int? selectedIndex;

  WalletSendtxHelpers({
    required this.isSingleWallet,
    required this.context,
    required this.recipientController,
    required this.amountController,
    required this.walletService,
    required this.mnemonic,
    required this.wallet,
    required this.currentHeight,
    required this.mounted,
    required this.avBalance,
    required this.onNewAddressGenerated,
    required this.syncWallet,

    // SharedWallet Variables
    this.psbtController,
    this.signingAmountController,
    this.policy,
    this.myFingerPrint,
    this.utxos,
    this.spendingPaths,
    this.descriptor,
    this.signersList,
    this.pubKeysAlias,
  });

  Future<void> sendTx(
    bool isCreating, {
    bool isFromSpendingPath = false,
    int? index,
    int? amount,
  }) async {
    final rootContext = context;

    if (!mounted) {
      return;
    }

    String address = walletService.getAddress(wallet);

    onNewAddressGenerated?.call(address);

    final extractedData =
        walletService.extractDataByFingerprint(policy!, myFingerPrint!);

    if (extractedData.isNotEmpty) {
      selectedPath = index != null ? extractedData[index] : extractedData.first;
      selectedIndex = index ?? 0;
    }

    // print('SelectedIndex: $selectedIndex');
    // print('SelectedPath: $selectedPath');

    showPSBT = isCreating;

    if (isFromSpendingPath) {
      await _handleSendAllViaSpendingPath(
        rootContext,
        amount!,
      );
    }

    await DialogHelper.buildCustomStatefulDialog(
      context: rootContext,
      titleKey: isCreating ? 'sending_menu' : 'signing_menu',
      showAssistant: true,
      assistantMessages: _getAssistantMessages(isCreating),
      contentBuilder: (setDialogState, updateAssistantMessage) {
        return _buildDialogContent(
          isCreating: isCreating,
          setDialogState: setDialogState,
          updateAssistantMessage: updateAssistantMessage,
          extractedData: extractedData,
          customFeeRate: customFeeRate,
          isFromSpendingPath: isFromSpendingPath,
        );
      },
      actionsBuilder: (setDialogState) {
        return [
          _buildSubmitButton(
            isCreating,
            setDialogState,
            extractedData,
            rootContext,
            address,
          ),
        ];
      },
    ).then((_) {
      _resetForm();
      syncWallet();
    });
  }

  Future<void> _handleSendAllViaSpendingPath(
    BuildContext rootContext,
    int amount,
  ) async {
    try {
      final sendAllBalance = int.parse((await walletService.createPartialTx(
        descriptor.toString(),
        mnemonic,
        recipientController.text,
        BigInt.from(amount),
        selectedIndex,
        avBalance,
        isSendAllBalance: true,
        spendingPaths: spendingPaths,
        customFeeRate: customFeeRate,
      ))!);

      amountController.text = sendAllBalance.toString();
    } catch (e, stackTrace) {
      // Navigator.of(rootContext, rootNavigator: true).pop();

      print(stackTrace);

      SnackBarHelper.showError(rootContext, message: e.toString());
    }
  }

  List<String> _getAssistantMessages(bool isCreating) {
    if (isSingleWallet) {
      return ['assistant_send_dialog2'];
    }

    return isCreating
        ? ['assistant_send_sw_dialog1', 'assistant_send_dialog2']
        : ['assistant_psbt_dialog1', 'assistant_psbt_dialog1'];
  }

  void _resetForm() {
    recipientController.clear();
    amountController.clear();
    psbtController?.clear();
    signingAmountController?.clear();
    signersList = [];
  }

  Widget _buildSubmitButton(
    bool isCreating,
    void Function(void Function()) setDialogState,
    List<Map<String, dynamic>> extractedData,
    BuildContext rootContext,
    String address,
  ) {
    return InkwellButton(
      onTap: () async {
        // Validate inputs
        if (!await _validateInputs(isCreating, rootContext)) {
          return;
        }

        // Sign or create/send based on state
        await _handleTransaction(
          isCreating: isCreating,
          rootContext: rootContext,
          extractedData: extractedData,
          setDialogState: setDialogState,
          address: address,
        );
      },
      label: AppLocalizations.of(rootContext)!.translate(
        isCreating ? 'submit' : (isFirstTap ? 'decode' : 'sign'),
      ),
      backgroundColor: AppColors.primary(context),
      textColor: AppColors.text(context),
      icon: isCreating ? Icons.send_to_mobile_outlined : Icons.draw,
      iconColor: AppColors.gradient(context),
    );
  }

  Widget _buildDialogContent({
    required bool isCreating,
    required void Function(void Function()) setDialogState,
    required void Function(BuildContext, String) updateAssistantMessage,
    required List<Map<String, dynamic>> extractedData,
    required double? customFeeRate,
    required bool isFromSpendingPath,
  }) {
    final rootContext = context;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isCreating)
          _buildPsbtField(
            setDialogState,
          ),
        if (isCreating || showPSBT) _buildRecipientField(),
        if (signersList!.isNotEmpty) _buildSignersList(),
        if (isCreating || showPSBT) _buildAmountField(isCreating),
        if (isCreating || isFromSpendingPath) _buildFeeSelector(setDialogState),
        if ((!isCreating && showPSBT) || isFromSpendingPath)
          SpendingPathDetailsCard(
            path: selectedPath,
            pubKeysAlias: pubKeysAlias,
            rootContext: rootContext,
          ),
        if (isCreating && !isSingleWallet && !isFromSpendingPath)
          SpendingPathDropdown(
            selectedPath: selectedPath,
            extractedData: extractedData,
            onSelected: (path, index) {
              setDialogState(() {
                selectedPath = path;
                selectedIndex = index;
              });
            },
            amountController: amountController,
            currentHeight: currentHeight,
            pubKeysAlias: pubKeysAlias,
            utxos: utxos,
            walletService: walletService,
            rootContext: rootContext,
            setDialogState: setDialogState,
          ),
        if (isCreating && !isFromSpendingPath)
          useAvailableBalanceButton(
            onTap: () => _handleAvailableBalanceTap(),
            updateAssistantMessage: updateAssistantMessage,
          ),
      ],
    );
  }

  Future<bool> _validateInputs(
    bool isCreating,
    BuildContext rootContext,
  ) async {
    if (isCreating && recipientController.text.isEmpty) {
      await DialogHelper.showErrorDialog(
        context: rootContext,
        messageKey: 'recipient_address_required',
      );

      return false;
    }

    if (isCreating && recipientController.text.isEmpty) {
      try {
        walletService.validateAddress(recipientController.text);
      } catch (_) {
        await DialogHelper.showErrorDialog(
          context: rootContext,
          messageKey: 'invalid_address',
        );

        return false;
      }
    }

    if (!isSingleWallet && selectedPath == null) {
      await DialogHelper.showErrorDialog(
        context: rootContext,
        messageKey: 'spending_path_required',
      );

      return false;
    }

    return true;
  }

  Future<void> _handleTransaction({
    required bool isCreating,
    required BuildContext rootContext,
    required List<Map<String, dynamic>> extractedData,
    required void Function(void Function()) setDialogState,
    required String address,
  }) async {
    bool userConfirmed = false;

    try {
      String? result;

      if (isCreating) {
        DialogHelper.showLoadingDialog(rootContext);

        final recipientAddress = recipientController.text;
        final int amount = int.parse(amountController.text);

        if (isSingleWallet) {
          await walletService.sendSingleTx(
            recipientAddress,
            BigInt.from(amount),
            wallet,
            address,
            customFeeRate,
          );
        } else {
          result = await walletService.createPartialTx(
            descriptor.toString(),
            mnemonic,
            recipientAddress,
            BigInt.from(amount),
            selectedIndex,
            avBalance,
            spendingPaths: spendingPaths,
            customFeeRate: customFeeRate,
            localUtxos: utxos,
          );
        }

        Navigator.of(rootContext, rootNavigator: true).pop(); // Close loading

        if (result != null) await showPSBTDialog(result, rootContext);

        Navigator.of(rootContext, rootNavigator: true).pop();

        SnackBarHelper.show(
          rootContext,
          message: AppLocalizations.of(rootContext)!
              .translate('transaction_created'),
        );
      } else {
        if (isFirstTap) {
          await _decodePsbt(
            extractedData,
            setDialogState,
            address,
          );

          return;
        }

        // Step 3: Ask for confirmation before signing
        userConfirmed = await DialogHelper.buildCustomDialog(
          context: rootContext,
          titleKey: 'confirm_transaction',
          content: const SizedBox(),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkwellButton(
                  onTap: () =>
                      Navigator.of(context, rootNavigator: true).pop(false),
                  label: AppLocalizations.of(rootContext)!.translate('no'),
                  backgroundColor: AppColors.error(context),
                  textColor: AppColors.text(context),
                  icon: Icons.dangerous,
                  iconColor: AppColors.gradient(context),
                ),
                InkwellButton(
                  onTap: () =>
                      Navigator.of(context, rootNavigator: true).pop(true),
                  label: AppLocalizations.of(rootContext)!.translate('yes'),
                  backgroundColor: AppColors.background(context),
                  textColor: AppColors.text(context),
                  icon: Icons.verified,
                  iconColor: AppColors.gradient(context),
                ),
              ],
            ),
          ],
        );

        if (!userConfirmed) return;

        DialogHelper.showLoadingDialog(rootContext);

        result = await walletService.signBroadcastTx(
          psbtController!.text,
          descriptor.toString(),
          mnemonic,
          selectedIndex,
        );

        Navigator.of(rootContext, rootNavigator: true).pop();

        if (result != null) {
          await showPSBTDialog(result, rootContext);
          SnackBarHelper.show(
            rootContext,
            message: AppLocalizations.of(rootContext)!
                .translate('transaction_signed'),
          );
        } else {
          Navigator.of(rootContext, rootNavigator: true).pop();

          SnackBarHelper.show(
            rootContext,
            message: AppLocalizations.of(rootContext)!
                .translate('transaction_broadcast'),
          );
        }
      }
    } catch (e, stack) {
      Navigator.of(rootContext, rootNavigator: true).pop();

      print(stack);
      print(e);

      SnackBarHelper.showError(rootContext, message: e.toString());
    }
  }

  Future<void> _decodePsbt(
    List<Map<String, dynamic>> extractedData,
    void Function(void Function()) setDialogState,
    String address,
  ) async {
    try {
      final psbt =
          await PartiallySignedTransaction.fromString(psbtController!.text);
      final tx = psbt.extractTx();

      selectedPath = walletService.extractSpendingPathFromPsbt(
        psbt,
        extractedData,
      );

      selectedIndex = extractedData.indexOf(selectedPath!);

      final signers = walletService.extractSignersFromPsbt(psbt);
      final aliases =
          walletService.getAliasesFromFingerprint(pubKeysAlias!, signers);

      final outputs = tx.output();
      Address? receiverAddress;
      int totalSpent = 0;

      for (final output in outputs) {
        receiverAddress =
            await walletService.getAddressFromScriptOutput(output);
        if (receiverAddress.asString() != address) {
          totalSpent += output.value.toInt();
        }
      }

      setDialogState(() {
        signingAmountController!.text = totalSpent.toString();
        signersList = aliases;
        recipientController.text = receiverAddress.toString();
        isFirstTap = false;
        showPSBT = true;
      });
    } catch (e) {
      SnackBarHelper.showError(
        context,
        message: AppLocalizations.of(context)!.translate('invalid_psbt'),
      );

      throw Exception("Invalid PSBT");
    }
  }

  Future<void> _handleAvailableBalanceTap() async {
    try {
      final rootContext = context;

      if (recipientController.text.isEmpty) {
        await DialogHelper.showErrorDialog(
          context: rootContext,
          messageKey: 'recipient_address_required',
        );

        return;
      }

      try {
        walletService.validateAddress(recipientController.text);
      } catch (_) {
        await DialogHelper.showErrorDialog(
          context: rootContext,
          messageKey: 'invalid_address',
        );

        return;
      }

      await walletService.syncWallet(wallet);
      final availableBalance = wallet.getBalance().spendable;

      final recipientAddress = recipientController.text;
      int sendAllBalance = 0;

      if (isSingleWallet) {
        sendAllBalance = await walletService.calculateSendAllBalance(
          recipientAddress: recipientAddress,
          wallet: wallet,
          availableBalance: availableBalance,
          walletService: walletService,
          customFeeRate: customFeeRate,
        );
      } else {
        sendAllBalance = int.parse((await walletService.createPartialTx(
          descriptor.toString(),
          mnemonic,
          recipientAddress,
          availableBalance,
          selectedIndex,
          avBalance,
          isSendAllBalance: true,
          spendingPaths: spendingPaths,
          customFeeRate: customFeeRate,
        ))!);
      }

      amountController.text = sendAllBalance.toString();
    } catch (e) {
      print("Error: $e");

      await DialogHelper.showErrorDialog(
        context: context,
        messageKey:
            "${AppLocalizations.of(context)!.translate('generic_error')}: ${e.toString()}",
      );
    }
  }

  Future<void> showPSBTDialog(
    String result,
    BuildContext context,
  ) async {
    final rootContext = context;

    TextEditingController psbt = TextEditingController();
    psbt.text = result;

    return DialogHelper.buildCustomDialog(
      context: rootContext,
      titleKey: 'psbt_created',
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4, // Limits height
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Prevents unnecessary expansion
          children: [
            Text(
              AppLocalizations.of(rootContext)!.translate('psbt_not_finalized'),
              style: TextStyle(
                color: AppColors.text(context),
              ),
            ),
            // const SizedBox(height: 10),
          ],
        ),
      ),
      actions: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Copy Button
            InkwellButton(
              onTap: () {
                UtilitiesService.copyToClipboard(
                  context: rootContext,
                  text: result,
                  messageKey: 'psbt_clipboard',
                );

                // if (Navigator.of(rootContext).canPop()) {
                //   Navigator.of(rootContext, rootNavigator: true).pop();
                // }
                // if (Navigator.of(rootContext).canPop()) {
                //   Navigator.of(rootContext, rootNavigator: true).pop();
                // }
                // Navigator.of(rootContext, rootNavigator: true).pop();
              },
              label: AppLocalizations.of(rootContext)!.translate('copy'),
              backgroundColor: AppColors.text(context),
              textColor: AppColors.gradient(context),
              icon: Icons.copy,
              iconColor: AppColors.gradient(context),
            ),

            // Save Txt File Button
            InkwellButton(
              onTap: () async {
                if (await Permission.storage.request().isGranted) {
                  try {
                    // Get default Downloads directory
                    final directory = Directory('/storage/emulated/0/Download');
                    if (!await directory.exists()) {
                      await directory.create(recursive: true);
                    }

                    DateTime now = DateTime.now();
                    String formattedDate =
                        DateFormat('yyyyMMdd_HHmmss').format(now);
                    String fileName = 'PSBT_$formattedDate.txt';
                    String filePath = '${directory.path}/$fileName';
                    File file = File(filePath);

                    await file.writeAsString(result);

                    // Optional: Show a success message to the user
                    SnackBarHelper.show(
                      context,
                      message: AppLocalizations.of(context)!
                          .translate('file_saved_successfully'),
                    );
                  } catch (e) {
                    // Handle any error
                    SnackBarHelper.showError(
                      context,
                      message: AppLocalizations.of(context)!
                          .translate('file_save_error'),
                    );
                  }
                }

                // Navigator.of(rootContext, rootNavigator: true).pop();
                // Navigator.of(rootContext, rootNavigator: true).pop();
              },
              label: AppLocalizations.of(rootContext)!.translate('save'),
              backgroundColor: AppColors.text(context),
              textColor: AppColors.gradient(context),
              icon: Icons.save,
              iconColor: AppColors.gradient(context),
            ),

            // Share Button
            InkwellButton(
              onTap: () {
                SharePlus.instance.share(ShareParams(text: result));
              },
              label: AppLocalizations.of(rootContext)!.translate('share'),
              backgroundColor: AppColors.text(context),
              textColor: AppColors.gradient(context),
              icon: Icons.share,
              iconColor: AppColors.gradient(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> showHEXDialog(
    String result,
    BuildContext context,
  ) async {
    final rootContext = context;

    TextEditingController hex = TextEditingController();
    hex.text = result;

    return DialogHelper.buildCustomDialog(
      context: rootContext,
      titleKey: 'Hex created',
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4, // Limits height
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Prevents unnecessary expansion
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: hex,
              readOnly: true,
              decoration: CustomTextFieldStyles.textFieldDecoration(
                context: context,
                labelText: 'psbt_created',
              ),
              style: TextStyle(
                color: AppColors.text(context),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Copy Button
            InkwellButton(
              onTap: () {
                UtilitiesService.copyToClipboard(
                  context: rootContext,
                  text: result,
                  messageKey: 'hex_clipboard',
                );

                // if (Navigator.of(rootContext).canPop()) {
                //   Navigator.of(rootContext, rootNavigator: true).pop();
                // }
                // if (Navigator.of(rootContext).canPop()) {
                //   Navigator.of(rootContext, rootNavigator: true).pop();
                // }
                // Navigator.of(rootContext, rootNavigator: true).pop();
              },
              label: AppLocalizations.of(rootContext)!.translate('copy'),
              backgroundColor: AppColors.text(context),
              textColor: AppColors.gradient(context),
              icon: Icons.copy,
              iconColor: AppColors.gradient(context),
            ),

            // Save Txt File Button
            InkwellButton(
              onTap: () async {
                if (await Permission.storage.request().isGranted) {
                  try {
                    // Get default Downloads directory
                    final directory = Directory('/storage/emulated/0/Download');
                    if (!await directory.exists()) {
                      await directory.create(recursive: true);
                    }

                    DateTime now = DateTime.now();
                    String formattedDate =
                        DateFormat('yyyyMMdd_HHmmss').format(now);
                    String fileName = 'PSBT_$formattedDate.txt';
                    String filePath = '${directory.path}/$fileName';
                    File file = File(filePath);

                    await file.writeAsString(result);

                    // Optional: Show a success message to the user
                    SnackBarHelper.show(
                      context,
                      message: AppLocalizations.of(context)!
                          .translate('file_saved_successfully'),
                    );
                  } catch (e) {
                    // Handle any error
                    SnackBarHelper.showError(
                      context,
                      message: AppLocalizations.of(context)!
                          .translate('file_save_error'),
                    );
                  }
                }

                // Navigator.of(rootContext, rootNavigator: true).pop();
                // Navigator.of(rootContext, rootNavigator: true).pop();
              },
              label: AppLocalizations.of(rootContext)!.translate('save'),
              backgroundColor: AppColors.text(context),
              textColor: AppColors.gradient(context),
              icon: Icons.save,
              iconColor: AppColors.gradient(context),
            ),

            // Share Button
            InkwellButton(
              onTap: () {
                SharePlus.instance.share(ShareParams(text: result));
              },
              label: AppLocalizations.of(rootContext)!.translate('share'),
              backgroundColor: AppColors.text(context),
              textColor: AppColors.gradient(context),
              icon: Icons.share,
              iconColor: AppColors.gradient(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecipientField() {
    return Column(
      children: [
        TextFormField(
          readOnly: false,
          controller: recipientController,
          decoration: CustomTextFieldStyles.textFieldDecoration(
            context: context,
            labelText:
                AppLocalizations.of(context)!.translate('recipient_address'),
            hintText: AppLocalizations.of(context)!.translate('enter_rec_addr'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAmountField(bool isCreating) {
    return Column(
      children: [
        TextFormField(
          controller: isCreating ? amountController : signingAmountController,
          readOnly: !isCreating,
          keyboardType: TextInputType.number,
          decoration: CustomTextFieldStyles.textFieldDecoration(
            context: context,
            labelText:
                "${AppLocalizations.of(context)!.translate('amount')} (sats)",
            hintText:
                AppLocalizations.of(context)!.translate('enter_amount_sats'),
          ),
          style: TextStyle(color: AppColors.text(context)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSignersList() {
    return Column(
      children: [
        Text(
          AppLocalizations.of(context)!.translate('signers'),
          style: TextStyle(
            color: AppColors.cardTitle(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 6.0,
          children: signersList!.map((signer) {
            return Chip(
              label: Text(
                signer,
                style: TextStyle(color: AppColors.text(context)),
              ),
              backgroundColor: AppColors.primary(context),
              avatar: Icon(
                Icons.verified,
                color: AppColors.text(context),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFeeSelector(void Function(void Function()) setDialogState) {
    return Column(
      children: [
        FeeSelector(
          onFeeSelected: (fee) {
            setDialogState(() {
              customFeeRate = fee;
            });
          },
          context: context,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget useAvailableBalanceButton({
    required VoidCallback onTap,
    required void Function(BuildContext, String) updateAssistantMessage,
  }) {
    return GestureDetector(
      onLongPress: () {
        final key = isSingleWallet
            ? 'assistant_personal_available_balance'
            : 'assistant_shared_available_balance';

        updateAssistantMessage(context, key);
      },
      child: InkwellButton(
        onTap: onTap,
        label: AppLocalizations.of(context)!.translate('use_available_balance'),
        icon: Icons.account_balance_wallet_rounded,
        backgroundColor: AppColors.background(context),
        textColor: AppColors.text(context),
        iconColor: AppColors.gradient(context),
      ),
    );
  }

  Widget _buildPsbtField(
    void Function(void Function()) setDialogState,
  ) {
    String? lastValidText = ''; // Store the last valid state
    bool isFull = false;

    return Column(
      children: [
        const SizedBox(height: 16),
        TextFormField(
          controller: psbtController,
          readOnly: isFull,
          onChanged: (value) {
            // Detect paste or clear
            if (lastValidText != null &&
                (value.length > lastValidText!.length + 1 || value.isEmpty)) {
              lastValidText = value;
              isFull = true;
            } else {
              // Prevent manual typing
              psbtController!.text = lastValidText ?? '';
              psbtController!.selection = TextSelection.fromPosition(
                TextPosition(offset: psbtController!.text.length),
              );
            }
          },
          decoration: CustomTextFieldStyles.textFieldDecoration(
            context: context,
            labelText: AppLocalizations.of(context)!.translate('psbt'),
            hintText: AppLocalizations.of(context)!.translate('enter_psbt'),
            suffixIcon:
                (psbtController != null && psbtController!.text.isNotEmpty)
                    ? IconButton(
                        icon: Icon(
                          Icons.cancel,
                          color: AppColors.icon(context),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            psbtController?.clear();
                            lastValidText = '';
                            showPSBT = false;
                            isFirstTap = true;
                            signersList?.clear();
                            isFull = false;
                          });
                        },
                      )
                    : null,
          ),
          style: TextStyle(color: AppColors.text(context)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

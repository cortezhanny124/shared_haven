// import 'dart:io';

// import 'package:bdk_flutter/bdk_flutter.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_wallet/languages/app_localizations.dart';
// import 'package:flutter_wallet/services/utilities_service.dart';
// import 'package:flutter_wallet/services/wallet_service.dart';
// import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
// import 'package:flutter_wallet/utilities/inkwell_button.dart';
// import 'package:flutter_wallet/utilities/app_colors.dart';
// import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
// import 'package:flutter_wallet/widget_helpers/fee_selector.dart';
// import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
// import 'package:intl/intl.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:share_plus/share_plus.dart';

// class WalletSendtxHelpersBackup {
//   final bool isSingleWallet;
//   final BuildContext context;
//   final TextEditingController recipientController;

//   final TextEditingController amountController;
//   final WalletService walletService;
//   final int currentHeight;
//   final Wallet wallet;
//   final String mnemonic;
//   final bool mounted;
//   final String address;
//   final BigInt avBalance;

//   TextEditingController? psbtController;
//   TextEditingController? signingAmountController;
//   Map<String, dynamic>? policy;
//   String? myFingerPrint;
//   List<dynamic>? utxos;
//   List<Map<String, dynamic>>? spendingPaths;
//   String? descriptor;
//   List<String>? signersList;
//   List<Map<String, String>>? pubKeysAlias;

//   WalletSendtxHelpersBackup({
//     required this.isSingleWallet,
//     required this.context,
//     required this.recipientController,
//     required this.amountController,
//     required this.walletService,
//     required this.mnemonic,
//     required this.wallet,
//     required this.address,
//     required this.currentHeight,
//     required this.mounted,
//     required this.avBalance,

//     // SharedWallet Variables
//     this.psbtController,
//     this.signingAmountController,
//     this.policy,
//     this.myFingerPrint,
//     this.utxos,
//     this.spendingPaths,
//     this.descriptor,
//     this.signersList,
//     this.pubKeysAlias,
//   });

//   Future<void> sendTx(
//     bool isCreating, {
//     String? recipientAddressQr,
//     bool isFromSpendingPath = false,
//     int? index,
//     int? amount,
//   }) async {
//     final rootContext = context;

//     if (recipientAddressQr != null) {
//       recipientController.text = recipientAddressQr;
//     }

//     Map<String, dynamic>? selectedPath; // Variable to store the selected path
//     int? selectedIndex; // Variable to store the selected path

//     if (!mounted) return;

//     final extractedData =
//         walletService.extractDataByFingerprint(policy!, myFingerPrint!);

//     // Initially set the first available spending path or the path from the spendingPath box
//     if (extractedData.isNotEmpty) {
//       selectedPath = index != null ? extractedData[index] : extractedData[0];
//       selectedIndex = index ?? 0;
//     }

//     double? customFeeRate;

//     print('selectedPath: $selectedPath');
//     print('selectedIndex: $selectedIndex');

//     print('index: $index');

//     if (isFromSpendingPath == true) {
//       int sendAllBalance = 0;
//       try {
//         sendAllBalance = int.parse((await walletService.createPartialTx(
//           descriptor.toString(),
//           mnemonic,
//           recipientController.text,
//           BigInt.from(amount!),
//           selectedIndex,
//           avBalance,
//           isSendAllBalance: true,
//           spendingPaths: spendingPaths,
//           customFeeRate: customFeeRate,
//         ))!);
//       } catch (e) {
//         Navigator.of(rootContext, rootNavigator: true).pop();

//         SnackBarHelper.showError(
//           rootContext,
//           message: e.toString(),
//         );
//         return;
//       }

//       amountController.text = sendAllBalance.toString();
//     }
//     // print(policy);
//     // print(myFingerPrint);

//     // print(selectedPath);

//     // print('extractedData: $extractedData');

//     List<String>? signers;

//     PartiallySignedTransaction psbt;

//     bool isSelectable = true;
//     bool showPSBT = isCreating;
//     bool isFirstTap =
//         true; // Tracks whether this is the first tap JUST for the signing menu
//     String? lastValidText = ''; // Store the last valid state
//     bool isFull = false;

//     return DialogHelper.buildCustomStatefulDialog(
//       context: rootContext,
//       titleKey: isCreating ? 'sending_menu' : 'signing_menu',
//       showAssistant: true,
//       assistantMessages: isSingleWallet
//           ? ['assistant_send_dialog2']
//           : isCreating
//               ? ['assistant_send_sw_dialog1', 'assistant_send_dialog2']
//               : [
//                   'assistant_psbt_dialog1',
//                   'assistant_psbt_dialog2'
//                 ], // ✅ Custom messages specific to this dialog
//       contentBuilder: (setDialogState, updateAssistantMessage) {
//         return Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Visibility(
//               visible: !isCreating,
//               child: Column(
//                 children: [
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: psbtController,
//                     readOnly: isFull,
//                     onChanged: (value) {
//                       // Detect paste or clear
//                       if (lastValidText != null &&
//                           (value.length > lastValidText!.length + 1 ||
//                               value.isEmpty)) {
//                         lastValidText = value;
//                         isFull = true;
//                       } else {
//                         // Prevent manual typing
//                         psbtController!.text = lastValidText ?? '';
//                         psbtController!.selection = TextSelection.fromPosition(
//                           TextPosition(offset: psbtController!.text.length),
//                         );
//                       }
//                     },
//                     decoration: CustomTextFieldStyles.textFieldDecoration(
//                       context: context,
//                       labelText:
//                           AppLocalizations.of(rootContext)!.translate('psbt'),
//                       hintText: AppLocalizations.of(rootContext)!
//                           .translate('enter_psbt'),
//                       suffixIcon: (psbtController != null &&
//                               psbtController!.text.isNotEmpty)
//                           ? IconButton(
//                               icon: Icon(
//                                 Icons.cancel,
//                                 color: AppColors.icon(context),
//                               ),
//                               onPressed: () {
//                                 setDialogState(() {
//                                   psbtController
//                                       ?.clear(); // Use null-aware operator to avoid errors
//                                   lastValidText = '';
//                                   showPSBT = false;
//                                   isFirstTap = true;
//                                   signersList?.clear();
//                                   isFull = false;
//                                 });
//                               },
//                             )
//                           : null, // Hide button if field is empty
//                     ),
//                     style: TextStyle(color: AppColors.text(context)),
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),

//             Visibility(
//               visible: isCreating || showPSBT,
//               child: Column(
//                 children: [
//                   TextFormField(
//                     readOnly: !isCreating,
//                     controller: recipientController,
//                     decoration: CustomTextFieldStyles.textFieldDecoration(
//                       context: context,
//                       labelText: AppLocalizations.of(rootContext)!
//                           .translate('recipient_address'),
//                       hintText: AppLocalizations.of(rootContext)!
//                           .translate('enter_rec_addr'),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),

//             // Identify who has already signed the PSBT
//             Visibility(
//               visible: signersList!.isNotEmpty,
//               child: Column(
//                 children: [
//                   Text(
//                     AppLocalizations.of(rootContext)!.translate('signers'),
//                     style: TextStyle(
//                       color: AppColors.cardTitle(context),
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   Wrap(
//                     spacing: 8.0,
//                     runSpacing: 6.0,
//                     children: signersList!.map((signer) {
//                       return Chip(
//                         label: Text(
//                           signer,
//                           style: TextStyle(color: AppColors.text(context)),
//                         ),
//                         backgroundColor: AppColors.primary(context),
//                         avatar: Icon(
//                           Icons.verified,
//                           color: AppColors.text(context),
//                         ),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),
//             Visibility(
//               visible: isCreating || showPSBT,
//               child: Column(
//                 children: [
//                   TextFormField(
//                     controller:
//                         isCreating ? amountController : signingAmountController,
//                     readOnly: !isCreating,
//                     onChanged: (value) {
//                       setDialogState(() {
//                         // print('Editing');
//                       });
//                     },
//                     decoration: CustomTextFieldStyles.textFieldDecoration(
//                       context: context,
//                       labelText:
//                           "${AppLocalizations.of(rootContext)!.translate('amount')} (sats)",
//                       hintText: AppLocalizations.of(rootContext)!
//                           .translate('enter_amount_sats'),
//                     ),
//                     style: TextStyle(
//                       color: AppColors.text(context),
//                     ),
//                     keyboardType: TextInputType.number,
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),

//             Visibility(
//               visible: (isCreating) || isFromSpendingPath == true,
//               child: Column(
//                 children: [
//                   FeeSelector(
//                     onFeeSelected: (double selectedFee) {
//                       print("Selected fee: $selectedFee sat/vB");
//                       setDialogState(() {
//                         customFeeRate = selectedFee;
//                       });
//                     },
//                     context: rootContext,
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),

//             Visibility(
//               visible: (!isCreating && showPSBT) || isFromSpendingPath == true,
//               child: selectedPath != null
//                   ? GestureDetector(
//                       onLongPress: () {
//                         updateAssistantMessage(
//                           context,
//                           'assistant_shared_path_selected',
//                         );
//                       },
//                       child: Card(
//                         elevation: 3,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         color: AppColors.background(context),
//                         child: Padding(
//                           padding: const EdgeInsets.all(12.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 AppLocalizations.of(rootContext)!
//                                     .translate('spending_path'),
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                   color: AppColors.text(context),
//                                 ),
//                               ),
//                               SizedBox(height: 8),
//                               RichText(
//                                 text: TextSpan(
//                                   style: TextStyle(
//                                     fontSize: 14,
//                                     color: AppColors.text(context),
//                                   ),
//                                   children: [
//                                     TextSpan(
//                                       text:
//                                           "${AppLocalizations.of(rootContext)!.translate('type')}: ",
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         color: AppColors.text(context),
//                                       ),
//                                     ),
//                                     TextSpan(
//                                       text: selectedPath!['type']
//                                               .contains('RELATIVETIMELOCK')
//                                           ? "TIMELOCK: ${selectedPath!['timelock']} ${AppLocalizations.of(rootContext)!.translate('blocks')}${selectedPath!['fingerprints'].length > 1 ? ", ${selectedPath!['threshold']} of ${(selectedPath!['fingerprints'] as List).length}" : ""}"
//                                           : "MULTISIG ${selectedPath!['threshold']} of ${(selectedPath!['fingerprints'] as List).length}",
//                                     ),
//                                     TextSpan(text: "\n"), // New line
//                                     TextSpan(
//                                       text:
//                                           "${AppLocalizations.of(rootContext)!.translate('keys')}: ",
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         color: AppColors.text(context),
//                                       ),
//                                     ),
//                                     TextSpan(
//                                       text: selectedPath!['fingerprints']
//                                           .map((fingerprint) {
//                                         final matchedAlias =
//                                             pubKeysAlias!.firstWhere(
//                                           (pubKeyAlias) =>
//                                               pubKeyAlias['publicKey']!
//                                                   .contains(fingerprint),
//                                           orElse: () => {
//                                             'alias': fingerprint
//                                           }, // Fallback to fingerprint
//                                         );
//                                         return matchedAlias['alias'] ??
//                                             fingerprint;
//                                       }).join(', '),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     )
//                   : SizedBox(), // Empty widget if no selectedPath
//             ),

//             // Dropdown for selecting the spending path
//             Visibility(
//               visible:
//                   isCreating && !isSingleWallet && isFromSpendingPath == false,
//               child: Column(
//                 children: [
//                   GestureDetector(
//                     onLongPress: () {
//                       updateAssistantMessage(
//                         context,
//                         'assistant_shared_path_dropdown',
//                       );
//                     },
//                     child: DropdownButtonFormField<Map<String, dynamic>>(
//                       value: selectedPath,
//                       items: extractedData.map((data) {
//                         // Check if the item meets the condition
//                         isSelectable = walletService.checkCondition(
//                           data,
//                           utxos!,
//                           isCreating
//                               ? amountController.text
//                               : signingAmountController!.text,
//                           currentHeight,
//                         );

//                         // print(isSelectable);

//                         // Replace fingerprints with aliases
//                         List<String> aliases =
//                             (data['fingerprints'] as List<dynamic>)
//                                 .map<String>((fingerprint) {
//                           final matchedAlias = pubKeysAlias!.firstWhere(
//                             (pubKeyAlias) =>
//                                 pubKeyAlias['publicKey']!.contains(fingerprint),
//                             orElse: () => {
//                               'alias': fingerprint
//                             }, // Fallback to fingerprint
//                           );

//                           return matchedAlias['alias'] ?? fingerprint;
//                         }).toList();

//                         return DropdownMenuItem<Map<String, dynamic>>(
//                           value: data,
//                           enabled:
//                               isSelectable, // Disable interaction for unselectable items
//                           child: Text(
//                             "${AppLocalizations.of(rootContext)!.translate('type')}: ${data['type'].contains('RELATIVETIMELOCK') ? 'TIMELOCK: ${data['timelock']} ${AppLocalizations.of(rootContext)!.translate('blocks')}' : 'MULTISIG'}, "
//                             "${data['threshold'] != null ? '${data['threshold']} of ${aliases.length}, ' : ''} ${AppLocalizations.of(rootContext)!.translate('keys')}: ${aliases.join(', ')}",
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: isSelectable
//                                   ? AppColors.text(context)
//                                   : AppColors.unavailableColor,
//                             ),
//                           ),
//                         );
//                       }).toList(),
//                       onTap: () {
//                         setDialogState(() {
//                           // print('Rebuilding');
//                         });
//                       },
//                       onChanged: (Map<String, dynamic>? newValue) {
//                         if (newValue != null) {
//                           setDialogState(() {
//                             selectedPath = newValue; // Update the selected path
//                             selectedIndex = extractedData
//                                 .indexOf(newValue); // Update the index
//                           });
//                           print(selectedPath);
//                           print(selectedIndex);
//                         } else {
//                           // Optionally handle the selection of unselectable items
//                           print("This item is unavailable.");
//                         }
//                       },
//                       selectedItemBuilder: (BuildContext context) {
//                         return extractedData.map((data) {
//                           isSelectable = walletService.checkCondition(
//                             data,
//                             utxos!,
//                             isCreating
//                                 ? amountController.text
//                                 : signingAmountController!.text,
//                             currentHeight,
//                           );

//                           // print(isSelectable);

//                           return Text(
//                             "${AppLocalizations.of(rootContext)!.translate('type')}: ${data['type'].contains('RELATIVETIMELOCK') ? 'TIMELOCK ${data['timelock']} ${AppLocalizations.of(rootContext)!.translate('blocks')}' : 'MULTISIG'}, ...",
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: isSelectable
//                                   ? AppColors.text(context)
//                                   : AppColors.unavailableColor,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           );
//                         }).toList();
//                       },
//                       decoration: InputDecoration(
//                         labelText: AppLocalizations.of(rootContext)!
//                             .translate('spending_path_required'),
//                         labelStyle: TextStyle(color: AppColors.text(context)),
//                         enabledBorder: OutlineInputBorder(
//                           borderSide:
//                               BorderSide(color: AppColors.text(context)),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderSide: BorderSide(
//                             color: AppColors.primary(context),
//                           ),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       dropdownColor: AppColors.gradient(context),
//                       style: TextStyle(color: AppColors.text(rootContext)),
//                       icon: Icon(
//                         Icons.arrow_drop_down,
//                         color: AppColors.text(context),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                 ],
//               ),
//             ),

//             Visibility(
//               visible: isCreating && isFromSpendingPath == false,
//               child: GestureDetector(
//                 onLongPress: () {
//                   updateAssistantMessage(
//                     context,
//                     isSingleWallet
//                         ? 'assistant_personal_available_balance'
//                         : 'assistant_shared_available_balance',
//                   );
//                 },
//                 child: InkwellButton(
//                   onTap: () async {
//                     try {
//                       // Validate recipient address
//                       if (recipientController.text.isEmpty) {
//                         await DialogHelper.showErrorDialog(
//                           context: rootContext,
//                           messageKey: 'recipient_address_required',
//                         );

//                         return; // Exit the function early if validation fails
//                       }

//                       try {
//                         walletService.validateAddress(recipientController.text);
//                       } catch (e) {
//                         await DialogHelper.showErrorDialog(
//                           context: rootContext,
//                           messageKey: 'invalid_address',
//                         );

//                         return; // Exit the function early if address is invalid
//                       }
//                       if (!isSingleWallet) {
//                         // Validate spending path
//                         if (selectedPath == null) {
//                           await DialogHelper.showErrorDialog(
//                             context: rootContext,
//                             messageKey: 'spending_path_required',
//                           );

//                           return; // Exit the function early if validation fails
//                         }
//                       }

//                       await walletService.syncWallet(wallet);

//                       final availableBalance = wallet.getBalance().spendable;

//                       final String recipientAddress =
//                           recipientController.text.toString();
//                       print('Selected Index: $selectedIndex');

//                       int sendAllBalance = 0;

//                       print(
//                           'Available Balance: ${wallet.getBalance().spendable}');

//                       if (isSingleWallet) {
//                         sendAllBalance =
//                             await walletService.calculateSendAllBalance(
//                           recipientAddress: recipientAddress,
//                           wallet: wallet,
//                           availableBalance: availableBalance,
//                           walletService: walletService,
//                           customFeeRate: customFeeRate,
//                         );
//                       } else {
//                         sendAllBalance =
//                             int.parse((await walletService.createPartialTx(
//                           descriptor.toString(),
//                           mnemonic,
//                           recipientAddress,
//                           availableBalance,
//                           selectedIndex,
//                           avBalance,
//                           isSendAllBalance: true,
//                           spendingPaths: spendingPaths,
//                           customFeeRate: customFeeRate,
//                         ))!);
//                       }

//                       amountController.text = sendAllBalance.toString();
//                     } catch (e) {
//                       print('Error: $e');

//                       await DialogHelper.showErrorDialog(
//                         context: rootContext,
//                         messageKey:
//                             "${AppLocalizations.of(rootContext)!.translate('generic_error')}: ${e.toString()}",
//                       );
//                     }
//                   },
//                   label: AppLocalizations.of(rootContext)!
//                       .translate('use_available_balance'),
//                   icon: Icons.account_balance_wallet_rounded,
//                   backgroundColor: AppColors.background(context),
//                   textColor: AppColors.text(context),
//                   iconColor: AppColors.gradient(context),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//       actionsBuilder: (setDialogState) {
//         return [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               InkwellButton(
//                 onTap: () async {
//                   FocusScope.of(context)
//                       .requestFocus(FocusNode()); // Remove focus

//                   bool userConfirmed = false;
//                   try {
//                     // Step 1: Ensure psbtController is not empty
//                     if (!isCreating) {
//                       if (psbtController == null ||
//                           psbtController!.text.isEmpty) {
//                         SnackBarHelper.showError(
//                           rootContext,
//                           message: AppLocalizations.of(rootContext)!
//                               .translate('invalid_psbt'),
//                         );
//                         return;
//                       }

//                       // Step 2: Extract and process PSBT
//                       if (isFirstTap) {
//                         try {
//                           psbt = await PartiallySignedTransaction.fromString(
//                               psbtController!.text);
//                           Transaction result = psbt.extractTx();

//                           selectedPath =
//                               walletService.extractSpendingPathFromPsbt(
//                             psbt,
//                             extractedData,
//                           );

//                           selectedIndex = extractedData.indexOf(selectedPath!);

//                           final outputs = result.output();
//                           signers = walletService.extractSignersFromPsbt(psbt);
//                           final signersAliases =
//                               walletService.getAliasesFromFingerprint(
//                                   pubKeysAlias!, signers!);

//                           bool isInternalTransaction =
//                               await walletService.areEqualAddresses(outputs);
//                           Address? receiverAddress;
//                           int totalSpent = 0;

//                           for (final output in outputs) {
//                             receiverAddress = await walletService
//                                 .getAddressFromScriptOutput(output);

//                             if (isInternalTransaction) {
//                               totalSpent += output.value.toInt();
//                             } else if (receiverAddress.asString() != address) {
//                               totalSpent += output.value.toInt();
//                             }
//                           }

//                           setDialogState(() {
//                             showPSBT = true;
//                             signingAmountController!.text =
//                                 totalSpent.toString();
//                             signersList = signersAliases;
//                             recipientController.text =
//                                 receiverAddress.toString();
//                             isFirstTap = false;
//                           });
//                         } catch (e) {
//                           SnackBarHelper.showError(
//                             rootContext,
//                             message: AppLocalizations.of(rootContext)!
//                                 .translate('invalid_psbt'),
//                           );
//                           return;
//                         }
//                       } else {
//                         // Step 3: Ask for confirmation before signing
//                         userConfirmed = await DialogHelper.buildCustomDialog(
//                           context: rootContext,
//                           titleKey: 'confirm_transaction',
//                           content: const SizedBox(),
//                           actions: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 InkwellButton(
//                                   onTap: () =>
//                                       Navigator.of(context, rootNavigator: true)
//                                           .pop(false),
//                                   label: AppLocalizations.of(rootContext)!
//                                       .translate('no'),
//                                   backgroundColor: AppColors.error(context),
//                                   textColor: AppColors.text(context),
//                                   icon: Icons.dangerous,
//                                   iconColor: AppColors.gradient(context),
//                                 ),
//                                 InkwellButton(
//                                   onTap: () =>
//                                       Navigator.of(context, rootNavigator: true)
//                                           .pop(true),
//                                   label: AppLocalizations.of(rootContext)!
//                                       .translate('yes'),
//                                   backgroundColor:
//                                       AppColors.background(context),
//                                   textColor: AppColors.text(context),
//                                   icon: Icons.verified,
//                                   iconColor: AppColors.gradient(context),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         );

//                         if (!userConfirmed) return;
//                       }
//                     }
//                     if (isCreating || userConfirmed) {
//                       final dialogContext = context;
//                       DialogHelper.closeDialog(dialogContext);

//                       // Show the loading dialog before starting the process
//                       DialogHelper.showLoadingDialog(rootContext);

//                       // Step 4: Execute the transaction signing
//                       String? result;
//                       // await walletService.syncWallet(wallet);

//                       if (isCreating) {
//                         String recipientAddressStr = recipientController.text;

//                         // Now, attempt to parse
//                         int? amount = int.parse(amountController.text);

//                         print('Amount: $amount');

//                         if (isSingleWallet) {
//                           await walletService.sendSingleTx(
//                             recipientAddressStr,
//                             BigInt.from(amount),
//                             wallet,
//                             address,
//                             customFeeRate,
//                           );

//                           Navigator.of(rootContext, rootNavigator: true).pop();
//                         } else {
//                           result = await walletService.createPartialTx(
//                             descriptor.toString(),
//                             mnemonic,
//                             recipientAddressStr,
//                             BigInt.from(amount),
//                             selectedIndex,
//                             avBalance,
//                             spendingPaths: spendingPaths,
//                             customFeeRate: customFeeRate,
//                             localUtxos: utxos,
//                           );
//                         }
//                       } else {
//                         print('selectedPath: $selectedPath');
//                         print('selectedIndex: $selectedIndex');

//                         print('index: $index');
//                         result = await walletService.signBroadcastTx(
//                           psbtController!.text,
//                           descriptor.toString(),
//                           mnemonic,
//                           selectedIndex,
//                         );
//                       }

//                       if (result != null) {
//                         await showPSBTDialog(result, rootContext);
//                       }

//                       SnackBarHelper.show(
//                         rootContext,
//                         message: isCreating
//                             ? AppLocalizations.of(rootContext)!
//                                 .translate('transaction_created')
//                             : result == null
//                                 ? AppLocalizations.of(rootContext)!
//                                     .translate('transaction_broadcast')
//                                 : AppLocalizations.of(rootContext)!
//                                     .translate('transaction_signed'),
//                       );
//                       if (!isSingleWallet) {
//                         Navigator.of(rootContext, rootNavigator: true).pop();
//                       }
//                     }
//                   } catch (e, stackTrace) {
//                     Navigator.of(rootContext, rootNavigator: true).pop();
//                     print(stackTrace);
//                     print(e);

//                     SnackBarHelper.showError(
//                       rootContext,
//                       message: e.toString(),
//                     );
//                   }
//                 },
//                 label: AppLocalizations.of(rootContext)!.translate(isCreating
//                     ? 'submit'
//                     : AppLocalizations.of(rootContext)!
//                         .translate(isFirstTap ? 'decode' : 'sign')),
//                 backgroundColor: AppColors.primary(context),
//                 textColor: AppColors.text(context),
//                 icon: isCreating ? Icons.send_to_mobile_outlined : Icons.draw,
//                 iconColor: AppColors.gradient(context),
//               ),
//             ],
//           ),
//         ];
//       },
//     ).then(
//       (_) {
//         recipientController.clear();
//         if (!isSingleWallet) {
//           if (psbtController != null) {
//             psbtController!.clear();
//           }
//           if (signingAmountController != null) {
//             signingAmountController!.clear();
//           }
//         }
//         amountController.clear();

//         signersList = [];

//         selectedPath = null; // Reset the dropdown selection
//         selectedIndex = null; // Reset the selected index
//       },
//     );
//   }

//   Future<void> showPSBTDialog(
//     String result,
//     BuildContext context,
//   ) async {
//     final rootContext = context;

//     TextEditingController psbt = TextEditingController();
//     psbt.text = result;

//     return DialogHelper.buildCustomDialog(
//       context: rootContext,
//       titleKey: 'psbt_created',
//       content: ConstrainedBox(
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.4, // Limits height
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min, // Prevents unnecessary expansion
//           children: [
//             Text(
//               AppLocalizations.of(rootContext)!.translate('psbt_not_finalized'),
//               style: TextStyle(
//                 color: AppColors.text(context),
//               ),
//             ),
//             const SizedBox(height: 10),
//             TextField(
//               controller: psbt,
//               readOnly: true,
//               decoration: CustomTextFieldStyles.textFieldDecoration(
//                 context: context,
//                 labelText: AppLocalizations.of(rootContext)!.translate('psbt'),
//               ),
//               style: TextStyle(
//                 color: AppColors.text(context),
//               ),
//             ),
//           ],
//         ),
//       ),
//       actions: <Widget>[
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             // Copy Button
//             InkwellButton(
//               onTap: () {
//                 UtilitiesService.copyToClipboard(
//                   context: rootContext,
//                   text: result,
//                   messageKey: 'psbt_clipboard',
//                 );
//               },
//               label: AppLocalizations.of(rootContext)!.translate('copy'),
//               backgroundColor: AppColors.text(context),
//               textColor: AppColors.gradient(context),
//               icon: Icons.copy,
//               iconColor: AppColors.gradient(context),
//             ),

//             // Save Txt File Button
//             InkwellButton(
//               onTap: () async {
//                 if (await Permission.storage.request().isGranted) {
//                   try {
//                     // Get default Downloads directory
//                     final directory = Directory('/storage/emulated/0/Download');
//                     if (!await directory.exists()) {
//                       await directory.create(recursive: true);
//                     }

//                     DateTime now = DateTime.now();
//                     String formattedDate =
//                         DateFormat('yyyyMMdd_HHmmss').format(now);
//                     String fileName = 'PSBT_$formattedDate.txt';
//                     String filePath = '${directory.path}/$fileName';
//                     File file = File(filePath);

//                     await file.writeAsString(result);

//                     // Optional: Show a success message to the user
//                     SnackBarHelper.show(
//                       context,
//                       message: AppLocalizations.of(context)!
//                           .translate('file_saved_successfully'),
//                     );
//                   } catch (e) {
//                     // Handle any error
//                     SnackBarHelper.showError(
//                       context,
//                       message: AppLocalizations.of(context)!
//                           .translate('file_save_error'),
//                     );
//                   }
//                 }
//               },
//               label: AppLocalizations.of(rootContext)!.translate('save'),
//               backgroundColor: AppColors.text(context),
//               textColor: AppColors.gradient(context),
//               icon: Icons.save,
//               iconColor: AppColors.gradient(context),
//             ),

//             // Share Button
//             InkwellButton(
//               onTap: () {
//                 Share.share(result);
//               },
//               label: AppLocalizations.of(rootContext)!.translate('share'),
//               backgroundColor: AppColors.text(context),
//               textColor: AppColors.gradient(context),
//               icon: Icons.share,
//               iconColor: AppColors.gradient(context),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }

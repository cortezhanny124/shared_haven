import 'dart:convert';
import 'dart:io';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/exceptions/validation_result.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/wallet_pages/qr_scanner_page.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class CreateAssistedSharedWalletPage extends StatefulWidget {
  const CreateAssistedSharedWalletPage({super.key});

  @override
  State<CreateAssistedSharedWalletPage> createState() =>
      CreateAssistedSharedWalletPageState();
}

class CreateAssistedSharedWalletPageState
    extends State<CreateAssistedSharedWalletPage> {
  final GlobalKey<BaseScaffoldState> baseScaffoldKey =
      GlobalKey<BaseScaffoldState>();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, String>> publicKeysWithAlias = [];
  List<Map<String, String>> publicKeysWithAliasMultisig = [];

  late final SettingsProvider settingsProvider;
  late final WalletService walletService;

  final TextEditingController _descriptorNameController =
      TextEditingController();

  String? _mnemonic;
  String _finalDescriptor = "";
  String? _publicKey = "";
  bool isLoading = false;
  String? initialPubKey;
  String _descriptorName = "";
  List<Map<String, dynamic>> timelockConditions = [];

  // bool _isDuplicateDescriptor = false;
  final bool _isDescriptorNameMissing = false;
  bool _isYourPubKeyMissing = false;
  bool _arePublicKeysMissing = false;

  @override
  void initState() {
    super.initState();

    // // Add a listner to the TextEditingController
    // _descriptorController.addListener(() {
    //   if (_descriptorController.text.isNotEmpty) {
    //     _descriptor = _descriptorController.text;
    //     _validateDescriptor(_descriptor.toString());
    //   }
    // });

    settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    walletService = WalletService(settingsProvider);

    _generatePublicKey(isGenerating: false);
  }

  Future<void> _generatePublicKey({bool isGenerating = true}) async {
    setState(() => isLoading = true);
    try {
      final walletBox = Hive.box('walletBox');
      final savedMnemonic = walletBox.get('walletMnemonic');
      final mnemonic = await Mnemonic.fromString(savedMnemonic);

      // print('Mnemonic: $savedMnemonic');

      final hardenedDerivationPath =
          await DerivationPath.create(path: "m/86h/1h/0h");
      final receivingDerivationPath = await DerivationPath.create(path: "m/0");

      final (_, receivingPublicKey) = await walletService.deriveDescriptorKeys(
        hardenedDerivationPath,
        receivingDerivationPath,
        mnemonic,
      );

      // print(receivingPublicKey
      //     .toString()
      //     .substring(0, receivingPublicKey.toString().length - 2));

      setState(() {
        if (isGenerating) {
          _publicKey = receivingPublicKey.toString();
        }
        initialPubKey = receivingPublicKey.toString();
        _mnemonic = savedMnemonic;
      });
    } catch (e) {
      print("Error generating public key: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // bool _isDuplicateDescriptorName(String descriptorName) {
  //   final descriptorBox = Hive.box('descriptorBox');

  //   // Iterate through all keys and check if any key contains the same descriptor name
  //   for (var key in descriptorBox.keys) {
  //     // print('Key: $key');
  //     if (key.toString().contains(descriptorName.trim())) {
  //       return true; // Duplicate found
  //     }
  //   }
  //   return false; // No duplicate found
  // }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      key: baseScaffoldKey,
      title:
          Text(AppLocalizations.of(context)!.translate('create_shared_wallet')),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: MediaQuery.of(context).size.height),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _descriptorNameController,
                    onChanged: (value) {
                      setState(() {
                        _descriptorName = _descriptorNameController.text.trim();

                        // _isDuplicateDescriptor =
                        //     _isDuplicateDescriptorName(_descriptorName);
                      });
                    },
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(context)!
                          .translate('enter_descriptor_name'),
                      hintText: 'E.g., MySharedWallet',
                      borderColor: _isDescriptorNameMissing
                          ? AppColors.error(context)
                          : AppColors.text(context),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.translate('public_keys'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...publicKeysWithAlias.asMap().entries.map((entry) {
                    final index = entry.key;
                    final keyData = entry.value;
                    return Card(
                      child: ListTile(
                        title: Text(keyData['alias'] ?? 'Unnamed'),
                        subtitle: Text(keyData['publicKey'] ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                _showAddPublicKeyDialog(
                                  key: keyData,
                                  isUpdating: true,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  publicKeysWithAlias.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onLongPress: () {
                      final BaseScaffoldState? baseScaffoldState =
                          baseScaffoldKey.currentState;

                      if (baseScaffoldState != null) {
                        baseScaffoldState.updateAssistantMessage(
                            context, 'assistant_generate_pub_key');
                      }
                    },
                    child: CustomButton(
                      onPressed: _generatePublicKey,
                      backgroundColor: AppColors.background(context),
                      foregroundColor: AppColors.gradient(context),
                      icon: Icons.vpn_key,
                      iconColor: AppColors.text(context),
                      label: AppLocalizations.of(context)!
                          .translate('generate_public_key'),
                      padding: 16.0,
                      iconSize: 24.0,
                    ),
                  ),
                  if (_publicKey != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${AppLocalizations.of(context)!.translate('pub_key')}: $_publicKey',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.text(context),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy,
                            color: AppColors.icon(context),
                          ),
                          tooltip: AppLocalizations.of(context)!
                              .translate('copy_to_clipboard'),
                          onPressed: () {
                            UtilitiesService.copyToClipboard(
                              context: context,
                              text: _publicKey.toString(),
                              messageKey: 'pub_key_clipboard',
                            );
                          },
                        ),
                      ],
                    ),
                    // Text('Generated Public Key: $_publicKey'),
                  ],
                  const SizedBox(height: 8),
                  CustomButton(
                    onPressed: publicKeysWithAlias.length >= 6
                        ? null
                        : () => _showAddPublicKeyDialog(),
                    backgroundColor: AppColors.background(context),
                    foregroundColor: AppColors.text(context),
                    icon: Icons.add,
                    iconColor: AppColors.gradient(context),
                    label: AppLocalizations.of(context)!
                        .translate('add_public_key'),
                  ),
                  const SizedBox(height: 8),
                  CustomButton(
                    onPressed: () => _createDescriptor(),
                    backgroundColor: AppColors.background(context),
                    foregroundColor: AppColors.text(context),
                    icon: Icons.create,
                    iconColor: AppColors.gradient(context),
                    label: AppLocalizations.of(context)!
                        .translate('create_descriptor'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPublicKeyDialog({Map<String, String>? key, isUpdating = false}) {
    final TextEditingController publicKeyController = TextEditingController();
    final TextEditingController aliasController = TextEditingController();

    String? currentPublicKey;
    String? currentAlias;
    String? errorMessage;

    if (isUpdating && key != null) {
      currentPublicKey = key['publicKey'];
      currentAlias = key['alias'];
      publicKeyController.text = currentPublicKey ?? '';
      aliasController.text = currentAlias ?? '';
    }

    final rootContext = context;

    DialogHelper.buildCustomStatefulDialog(
      context: rootContext,
      titleKey: isUpdating ? 'edit_public_key' : 'add_public_key',
      showAssistant: true,
      assistantMessages: [
        'assistant_add_pub_key_tip1',
        'assistant_add_pub_key_tip2',
      ],
      contentBuilder: (setDialogState, updateAssistantMessage) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: publicKeyController,
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(rootContext)!
                          .translate('enter_pub_key'),
                      hintText: AppLocalizations.of(rootContext)!
                          .translate('enter_pub_key'),
                      borderColor: AppColors.background(context),
                    ),
                    style: TextStyle(
                      color: AppColors.text(context),
                    ),
                  ),
                ),
                InkwellButton(
                  onTap: () async {
                    final result =
                        await Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => QRScannerPage(
                          title: 'Scan PubKey',
                          isValid: (data) => true,
                          // data.startsWith('cHUB') || data.startsWith('psbt'),
                          extractValue: (data) => data,
                          errorKey: 'invalid_pub_key',
                        ),
                      ),
                    );

                    if (result != null) {
                      // ✅ If needed, reopen the dialog here with updated data
                      publicKeyController.text = result;
                    }
                  },
                  backgroundColor: AppColors.gradient(context),
                  textColor: AppColors.text(context),
                  icon: Icons.qr_code_scanner,
                  iconColor: AppColors.icon(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: aliasController,
              decoration: CustomTextFieldStyles.textFieldDecoration(
                context: context,
                labelText:
                    AppLocalizations.of(rootContext)!.translate('enter_alias'),
                hintText:
                    AppLocalizations.of(rootContext)!.translate('enter_alias'),
                borderColor: AppColors.background(context),
              ),
              style: TextStyle(
                color: AppColors.text(context),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage!,
                style: TextStyle(
                  color: AppColors.error(context),
                ),
              ),
            ],
          ],
        );
      },
      actionsBuilder: (setDialogState) {
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkwellButton(
                onTap: () {
                  final String newPublicKey = publicKeyController.text.trim();
                  final String newAlias = aliasController.text.trim();

                  if (newPublicKey.isEmpty || newAlias.isEmpty) {
                    setDialogState(() {
                      errorMessage = AppLocalizations.of(rootContext)!
                          .translate('both_fields_required');
                    });
                    return;
                  }

                  // Exclude the current key when checking for duplicates
                  bool publicKeyExists = publicKeysWithAlias.any((entry) =>
                      entry['publicKey']?.toLowerCase() ==
                          newPublicKey.toLowerCase() &&
                      entry['publicKey']?.toLowerCase() !=
                          currentPublicKey?.toLowerCase());

                  bool aliasExists = publicKeysWithAlias.any((entry) =>
                      entry['alias']?.toLowerCase() == newAlias.toLowerCase() &&
                      entry['alias']?.toLowerCase() !=
                          currentAlias?.toLowerCase());

                  if (publicKeyExists) {
                    setDialogState(() {
                      errorMessage = AppLocalizations.of(rootContext)!
                          .translate('pub_key_exists');
                    });
                  } else if (aliasExists) {
                    setDialogState(() {
                      errorMessage = AppLocalizations.of(rootContext)!
                          .translate('alias_exists');
                    });
                  } else {
                    if (isUpdating) {
                      setState(() {
                        key!['publicKey'] = newPublicKey;
                        key['alias'] = newAlias;
                      });
                      Navigator.of(context, rootNavigator: true).pop();

                      SnackBarHelper.show(
                        rootContext,
                        message: AppLocalizations.of(rootContext)!
                            .translate('multisig_updated'),
                      );
                    } else {
                      setState(() {
                        publicKeysWithAlias.add({
                          'publicKey': newPublicKey,
                          'alias': newAlias,
                        });
                      });
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  }
                },
                label: AppLocalizations.of(rootContext)!
                    .translate(isUpdating ? 'save' : 'add'),
                backgroundColor: AppColors.background(context),
                textColor: AppColors.text(context),
                icon: isUpdating ? Icons.save : Icons.add_task,
                iconColor: AppColors.gradient(context),
              ),
            ],
          ),
        ];
      },
    );
  }

  void _validateInputs() {
    setState(() {
      // print(_publicKey);
      // print(publicKeysWithAlias);
      _isYourPubKeyMissing = !publicKeysWithAlias.any((entry) {
        return entry['publicKey'] == initialPubKey;
      });
      _arePublicKeysMissing = publicKeysWithAlias.isEmpty;
    });
  }

  void _createDescriptor() async {
    // print('🚀 Starting descriptor creation...');

    // Step 1: Validate inputs
    // print('🧪 Validating inputs...');
    _validateInputs();

    if (_arePublicKeysMissing || _isYourPubKeyMissing) {
      // print('❌ Validation failed: Missing descriptor fields.');
      return;
    }
    // print('✅ Validation passed.');

    // Step 2: Extract and sort public keys
    // print('🔍 Extracting public keys from user input...');
    List<String> extractedPublicKeys = publicKeysWithAliasMultisig
        .map((entry) => entry['publicKey']!)
        .toList()
      ..sort();

    // print('📋 Sorted Public Keys: $extractedPublicKeys');

    String formattedKeys =
        extractedPublicKeys.toString().replaceAll(RegExp(r'^\[|\]$'), '');
    // print('🔧 Formatted keys string for descriptor: $formattedKeys');

    // ⚠️ Fixed: Do not prepend a key outside of multi_a
    String multi =
        'multi_a(${publicKeysWithAliasMultisig.length},$formattedKeys)';
    // print('🔗 Multi_a expression: $multi');

    String finalDescriptor;

    _handleTimelocks(); // Optional: Add debug log inside that method if needed
    // print('Timelock conditions after handling: $timelockConditions');

    final deadKey = await mutateXpubUntilAccepted(extractedPublicKeys.first);

    // Step 3: Handle optional timelocks
    if (timelockConditions.isNotEmpty) {
      // print('⏱ Handling timelock conditions...');

      // Sort timelocks by block/time
      timelockConditions.sort((a, b) {
        int getTimeLock(Map cond) =>
            int.tryParse(cond['older'] ?? cond['after'] ?? '0') ?? 0;
        return getTimeLock(a).compareTo(getTimeLock(b));
      });

      // print('📋 Sorted timelock conditions: $timelockConditions');

      // Format each timelock into Miniscript
      List<String> formattedTimelocks = timelockConditions.map((condition) {
        String threshold = condition['threshold'];
        String older = condition['older'] ?? '';
        String after = condition['after'] ?? '';

        // print('⏳ Processing timelock condition:');
        // print('  🔐 Threshold: $threshold');
        // print('  🔁 Older: $older');
        // print('  📆 After: $after');

        String timeCondition = older.isNotEmpty
            ? 'older($older)'
            : after.isNotEmpty
                ? 'after($after)'
                : throw Exception(
                    '⚠️ Timelock condition missing `older` or `after` value');

        List<String> pubkeys = (condition['pubkeys'] as List)
            .map((key) => key['publicKey'] as String)
            .toList()
          ..sort();

        // print('  🔑 Sorted pubkeys for this condition: $pubkeys');

        String pubkeysString = pubkeys.join(',');
        String multiCondition = pubkeys.length > 1
            ? 'multi_a($threshold,$pubkeysString)'
            : 'pk(${pubkeys.first})';

        // print('  🔧 Script expression: $multiCondition');

        String result = 'and_v(v:$timeCondition,$multiCondition)';
        // print('  🧱 Final formatted timelock expression: $result');

        return result;
      }).toList();

      // Combine the timelocks and the multi_a base
      String timelockCondition = buildTimelockCondition(formattedTimelocks);
      // print('🧩 Combined timelock condition: $timelockCondition');

      // Use nested logic for final tr() descriptor
      finalDescriptor =
          'tr($deadKey, ${nestConditions(multi, [timelockCondition])})';

      // print('🧬 Final descriptor with timelocks: $finalDescriptor');
    } else {
      // No timelocks, just use multi_a in tr()
      // print('🟢 No timelock conditions. Using only multisig policy.');
      finalDescriptor = 'tr($deadKey,$multi)';
      // print('🧬 Final descriptor: $finalDescriptor');
    }

    // Clean and store descriptor
    finalDescriptor = finalDescriptor.replaceAll(' ', '');
    // print('✅ Final descriptor after cleaning: $finalDescriptor');

    setState(() {
      _finalDescriptor = finalDescriptor;
    });

    // print('📦 Descriptor stored to state.');

    _createDescriptorDialog(context);
  }

  String nestConditions(String base, List<String> conditions) {
    for (final cond in conditions) {
      base = 'or_d($base,$cond)';
    }
    return base;
  }

  Future<String> mutateXpubUntilAccepted(String xpub) async {
    // print('🧪 Starting xpub mutation process...');
    final chars = xpub.split('');

    for (int i = 0; i < chars.length; i++) {
      final original = chars[i];

      for (final replacement in ['A', 'B', 'C', 'D']) {
        if (replacement == original) continue;

        chars[i] = replacement;
        final mutated = chars.join();

        // Log mutation attempt
        // print('🔄 Trying mutation at index $i: "$original" → "$replacement"');
        // print('📦 Mutated xpub: $mutated');

        final descriptorStr =
            'tr($mutated,pk(0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798))';

        try {
          await Descriptor.create(
            descriptor: descriptorStr,
            network: settingsProvider.network,
          );
          // print('✅ Descriptor accepted with mutated xpub.');
          return mutated;
        } catch (e) {
          print('❌ Rejected: $e');
          // Restore original and continue
        }
      }

      chars[i] = original;
    }

    print('🚫 No valid mutation found.');
    throw Exception(
        'Unable to generate a valid mutated xpub that Descriptor accepts.');
  }

  void _createDescriptorDialog(BuildContext context) {
    final rootContext = context;

    DialogHelper.buildCustomDialog(
      context: context,
      titleKey: 'descriptor_created',
      titleParams: {'x': _descriptorName},
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display descriptor
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.container(context),
              border: Border.all(
                color: AppColors.background(context),
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _finalDescriptor,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: AppColors.primary(context)),
                  tooltip: AppLocalizations.of(rootContext)!
                      .translate('copy_to_clipboard'),
                  onPressed: () {
                    UtilitiesService.copyToClipboard(
                      context: rootContext,
                      text: _finalDescriptor,
                      messageKey: 'descriptor_clipboard',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Display conditions
          Text(
            AppLocalizations.of(rootContext)!.translate('conditions'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.cardTitle(context),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: timelockConditions.map((condition) {
              // Retrieve aliases for the selected public keys
              List<String> aliases =
                  (condition['pubkeys'] as List<Map<String, String>>)
                      .map((key) => key['alias']!)
                      .toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 10.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: AppColors.primary(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text(context),
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('threshold')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: '${condition['threshold']}',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text(context),
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('older')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: '${condition['older']}',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('after')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: '${condition['after']}',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('aliases')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: aliases.join(', '),
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Display public keys with aliases
          Text(
            AppLocalizations.of(rootContext)!.translate('pub_keys'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.cardTitle(context),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: publicKeysWithAlias.map((key) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: AppColors.primary(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('pub_key')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: '${key['publicKey']}',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('alias')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: '${key['alias']}',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Serialize data to JSON
            final data = jsonEncode({
              'descriptor': _finalDescriptor,
              'publicKeysWithAlias': publicKeysWithAlias,
              'descriptorName': _descriptorName,
            });

            // Request storage permission (required for Android 11 and below)
            if (await Permission.storage.request().isGranted) {
              // Get default Downloads directory
              final directory = Directory('/storage/emulated/0/Download');
              if (!await directory.exists()) {
                await directory.create(recursive: true);
              }

              String fileName = '$_descriptorName.json';
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
                              backgroundColor: AppColors.gradient(context),
                              textColor: AppColors.text(context),
                              icon: Icons.cancel_rounded,
                              iconColor: AppColors.icon(context),
                            ),
                            InkwellButton(
                              onTap: () {
                                Navigator.of(context, rootNavigator: true)
                                    .pop(true);
                              },
                              label: AppLocalizations.of(rootContext)!
                                  .translate('yes'),
                              backgroundColor: AppColors.text(context),
                              textColor: AppColors.gradient(context),
                              icon: Icons.check_circle,
                              iconColor: AppColors.icon(context),
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
                  fileName = '$_descriptorName($index).json';
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
            foregroundColor: AppColors.primary(context),
          ),
          child: Text(
            AppLocalizations.of(rootContext)!.translate('download_descriptor'),
            style: TextStyle(
              color: AppColors.background(context),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            // print('_mnemonic: $_mnemonic');
            Navigator.of(context, rootNavigator: true).pop();

            _navigateToSharedWallet();
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary(context),
          ),
          child: Text(
            AppLocalizations.of(rootContext)!.translate('navigate_wallet'),
            style: TextStyle(
              color: AppColors.background(context),
            ),
          ),
        ),
      ],
      actionsLayout: Axis.vertical,
    );
  }

  void _navigateToSharedWallet() async {
    bool isValid = await _validateDescriptor(_finalDescriptor);
    // print(isValid);
    // setState(() {
    //   _status = 'Loading';
    // });

    if (isValid) {
      // setState(() {
      //   _status = 'Success';
      // });

      // walletService.printInChunks(_finalDescriptor.toString());

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SharedWallet(
            descriptor: _finalDescriptor,
            mnemonic: _mnemonic!,
            pubKeysAlias: publicKeysWithAlias,
            descriptorName: _descriptorName,
          ),
        ),
      );
    } else {
      print('Cannot navigate: Invalid Descriptor');
      // setState(() {
      //   _status = 'Cannot navigate: Invalid Descriptor';
      // });
    }
  }

  // Asynchronous method to validate the descriptor
  Future<bool> _validateDescriptor(String descriptor) async {
    try {
      ValidationResult result = await walletService.isValidDescriptor(
        descriptor,
        initialPubKey.toString(),
        context,
      );

      // print(result.toString());

      // setState(() {
      //   _isDescriptorValid = result.isValid;
      //   _status = result.isValid
      //       ? 'Descriptor is valid'
      //       : result.errorMessage ?? 'Invalid Descriptor';
      // });
      return result.isValid;
    } catch (e) {
      // setState(() {
      //   _isDescriptorValid = false;
      //   _status = 'Error validating Descriptor: $e';
      // });
      return false;
    }
  }

  void _handleTimelocks() {
    final regex = RegExp(
        r'\/(\d+)(?=\/\*)'); // Matches the last number in the derivation path before '/*'

    setState(() {
      Set<String> seenPubKeys = {}; // Track already-seen public keys

      // Add already-used public keys to the set
      seenPubKeys
          .addAll(publicKeysWithAlias.map((entry) => entry['publicKey']!));

      // Process each timelock condition
      timelockConditions = timelockConditions.map((condition) {
        // print('ConditionHandling: ${condition['pubkeys']}');

        // Extract and process pubkeys while preserving aliases
        List<Map<String, String>> updatedPubKeys =
            (condition['pubkeys'] is String
                    ? List<Map<String, dynamic>>.from(
                        jsonDecode(condition['pubkeys']))
                    : List<Map<String, dynamic>>.from(
                        condition['pubkeys'] as List<dynamic>))
                .map((key) {
          // Extract the original key and alias
          String originalKey = key['publicKey'] as String;
          String alias = key['alias'] as String;

          // Resolve duplicate public keys
          while (seenPubKeys.contains(originalKey)) {
            // Modify the key by incrementing the last number in the derivation path
            originalKey = originalKey.replaceFirstMapped(regex, (match) {
              int currentValue = int.parse(match.group(1)!);
              return '/${currentValue + 1}';
            });
          }

          // Add the (possibly modified) key to the set of seen keys
          seenPubKeys.add(originalKey);

          // Return the updated key with its alias
          return {
            'publicKey': originalKey,
            'alias': alias,
          };
        }).toList();

        // Update the condition with the resolved pubkeys
        return {
          ...condition,
          'pubkeys': updatedPubKeys,
        };
      }).toList();
    });

    // print('Updated Timelock Conditions: $timelockConditions');
  }

  String buildTimelockCondition(List<String> formattedTimelocks) {
    String combineConditions(List<String> conditions) {
      while (conditions.length > 1) {
        List<String> combined = [];
        for (int i = 0; i < conditions.length; i += 2) {
          if (i + 1 < conditions.length) {
            combined.add('or_i(${conditions[i]},${conditions[i + 1]})');
          } else {
            combined.add(conditions[i]);
          }
        }
        conditions = combined;
      }
      return conditions.first;
    }

    return combineConditions(formattedTimelocks);
  }
}

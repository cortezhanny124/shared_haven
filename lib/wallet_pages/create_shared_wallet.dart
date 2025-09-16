import 'dart:convert';
import 'dart:io';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/exceptions/validation_result.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/widget_helpers/custom_bottom_sheet.dart';
import 'package:flutter_wallet/widget_helpers/notification_helper.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class CreateSharedWallet extends StatefulWidget {
  const CreateSharedWallet({super.key});

  @override
  CreateSharedWalletState createState() => CreateSharedWalletState();
}

class CreateSharedWalletState extends State<CreateSharedWallet> {
  late final WalletService _walletService;

  List<TextEditingController> additionalPublicKeyControllers = [
    TextEditingController()
  ];
  final TextEditingController _descriptorNameController =
      TextEditingController();

  String? threshold;
  List<Map<String, String>> publicKeysWithAlias = [];
  List<Map<String, String>> publicKeysWithAliasMultisig = [];

  List<Map<String, dynamic>> timelockConditions = [];

  // List<String> publicKeys = [];
  // List<String> timelocks = [];

  String? _mnemonic;
  String _finalDescriptor = "";
  String? _publicKey = "";
  String _descriptorName = "";
  bool isLoading = false;

  String? initialPubKey;

  bool _isDuplicateDescriptor = false;
  bool _isDescriptorNameMissing = false;
  bool _isThresholdMissing = false;
  bool _isYourPubKeyMissing = false;
  bool _arePublicKeysMissing = false;
  bool multisigAdded = false;

  final GlobalKey<BaseScaffoldState> baseScaffoldKey =
      GlobalKey<BaseScaffoldState>();

  @override
  void initState() {
    super.initState();

    _walletService =
        WalletService(Provider.of<SettingsProvider>(context, listen: false));

    _generatePublicKey(isGenerating: false);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _validateInputs() {
    setState(() {
      // print(_publicKey);
      // print(publicKeysWithAlias);
      // print(threshold);
      _isYourPubKeyMissing = !publicKeysWithAlias.any((entry) {
        return entry['publicKey'] == initialPubKey;
      });
      _isDescriptorNameMissing = _descriptorNameController.text.isEmpty;
      _isThresholdMissing = threshold == null;
      _arePublicKeysMissing = publicKeysWithAlias.isEmpty;
    });
  }

  Future<void> _generatePublicKey({bool isGenerating = true}) async {
    setState(() => isLoading = true);
    try {
      final walletBox = Hive.box('walletBox');
      final savedMnemonic = walletBox.get('walletMnemonic');
      final mnemonic = await Mnemonic.fromString(savedMnemonic);

      // print('Mnemonic: $savedMnemonic');

      final hardenedDerivationPath =
          await DerivationPath.create(path: "m/84h/1h/0h");
      final receivingDerivationPath = await DerivationPath.create(path: "m/0");

      final (_, receivingPublicKey) = await _walletService.deriveDescriptorKeys(
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

  // Asynchronous method to validate the descriptor
  Future<bool> _validateDescriptor(String descriptor) async {
    try {
      ValidationResult result = await _walletService.isValidDescriptor(
        descriptor,
        initialPubKey.toString(),
        context,
      );

      // print(result.toString());

      return result.isValid;
    } catch (e) {
      return false;
    }
  }

  void _navigateToSharedWallet() async {
    bool isValid = await _validateDescriptor(_finalDescriptor);
    // print(isValid);

    if (isValid) {
      // _walletService.printInChunks(_finalDescriptor.toString());

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
    }
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

  bool _isDuplicateDescriptorName(String descriptorName) {
    final descriptorBox = Hive.box('descriptorBox');

    // Iterate through all keys and check if any key contains the same descriptor name
    for (var key in descriptorBox.keys) {
      // print('Key: $key');
      if (key.toString().contains(descriptorName.trim())) {
        return true; // Duplicate found
      }
    }
    return false; // No duplicate found
  }

  String _generateSectionErrorMessage(List<Map<String, dynamic>> conditions) {
    List<String> errors = [];

    for (var condition in conditions) {
      if (condition['condition'] as bool) {
        errors.add(condition['message'] as String);
      }
    }

    return errors.join('. ') + (errors.isNotEmpty ? '.' : '');
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.translate('create_shared_wallet'),
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      key: baseScaffoldKey,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section: Descriptor Name
            Text(
              AppLocalizations.of(context)!.translate('descriptor_name'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _isDescriptorNameMissing
                    ? AppColors.error(context)
                    : AppColors.text(context),
              ),
            ),
            // Error Message
            if (_isDescriptorNameMissing || _isDuplicateDescriptor)
              Text(
                _generateSectionErrorMessage([
                  {
                    'condition': _isDescriptorNameMissing,
                    'message': AppLocalizations.of(context)!
                        .translate('descriptor_name_missing')
                  },
                  {
                    'condition': _isDuplicateDescriptor,
                    'message': AppLocalizations.of(context)!
                        .translate('descriptor_name_exists')
                  },
                ]),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: AppColors.error(context),
                ),
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptorNameController,
              onChanged: (value) {
                setState(() {
                  _descriptorName = _descriptorNameController.text.trim();

                  _isDuplicateDescriptor =
                      _isDuplicateDescriptorName(_descriptorName);
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
            const SizedBox(height: 20),
            // Section 1: Generate Public Key
            Text(
              '1. ${AppLocalizations.of(context)!.translate('generate_public_key')}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.text(context)),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _generatePublicKey,
                  icon: Icon(Icons.autorenew),
                ),
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

            Divider(height: 40, color: AppColors.text(context)),

            // Section 2: Enter Public Keys
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Title

                Text(
                  '2. ${AppLocalizations.of(context)!.translate('enter_pub_keys')}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: (_isThresholdMissing ||
                            _arePublicKeysMissing ||
                            _isYourPubKeyMissing)
                        ? AppColors.error(context)
                        : AppColors.text(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.person_add_alt_sharp,
                    size: 40,
                    color: AppColors.icon(context),
                  ),
                  onPressed: _showAddPublicKeyDialog,
                ),
                const SizedBox(width: 10),
                const SizedBox(height: 10),
                if (publicKeysWithAlias.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: publicKeysWithAlias.map((key) {
                      return Dismissible(
                        key: ValueKey(
                            key['publicKey']), // Unique key for each item
                        direction: DismissDirection
                            .horizontal, // Allow swipe to the left and righty
                        onDismissed: (direction) {
                          setState(() {
                            // print(key['publicKey']);

                            publicKeysWithAlias.remove(key); // Remove the key

                            for (var condition in timelockConditions) {
                              condition['pubkeys'].removeWhere((pubKeyEntry) {
                                return pubKeyEntry['publicKey'] ==
                                    key['publicKey'];
                              });
                            }

                            // Remove the entire condition if no pubkeys remain in it
                            timelockConditions.removeWhere(
                                (condition) => condition['pubkeys'].isEmpty);
                          });

                          NotificationHelper.showError(
                            context,
                            message:
                                "${key['alias']} ${AppLocalizations.of(context)!.translate('alias_removed')}",
                          );
                        },
                        background: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.error(context),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Icon(
                            Icons.delete,
                            color: AppColors.text(context),
                            size: 24,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            _showAddPublicKeyDialog(key: key, isUpdating: true);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: AppColors.background(context)
                                  .withAlpha((0.2 * 255).toInt()),
                              borderRadius: BorderRadius.circular(8.0),
                              border:
                                  Border.all(color: AppColors.primary(context)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  key['alias']!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),

            Divider(height: 40, color: AppColors.text(context)),

            // Section 3: Enter Multisig condition
            if (publicKeysWithAlias.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Title

                  Text(
                    '3. ${AppLocalizations.of(context)!.translate('enter_multisig')}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: (_isThresholdMissing ||
                              _arePublicKeysMissing ||
                              _isYourPubKeyMissing)
                          ? AppColors.error(context)
                          : AppColors.text(context),
                    ),
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!multisigAdded)
                        IconButton(
                          onPressed: () => _showAddMultisigDialog(false),
                          icon: Icon(
                            Icons.add_link,
                            color: AppColors.icon(context),
                            size: 40,
                          ),
                        ),
                      if (multisigAdded)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showAddMultisigDialog(true),
                            child: Card(
                              color: AppColors.background(context),
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(6), // smaller padding
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize
                                      .min, // don't expand vertically
                                  children: [
                                    Text(
                                      "Threshold: $threshold",
                                      style: TextStyle(
                                        fontSize: 13, // smaller text
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...publicKeysWithAliasMultisig.map(
                                      (pk) => ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity
                                            .compact, // tighter vertical space
                                        contentPadding: EdgeInsets
                                            .zero, // remove side padding
                                        leading:
                                            const Icon(Icons.vpn_key, size: 16),
                                        title: Text(
                                          pk['alias'] ?? "Unknown",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.text(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Error Message
                  if (_isThresholdMissing ||
                      _arePublicKeysMissing ||
                      _isYourPubKeyMissing)
                    Text(
                      _generateSectionErrorMessage([
                        {
                          'condition': _isThresholdMissing,
                          'message': AppLocalizations.of(context)!
                              .translate('threshold_missing')
                        },
                        {
                          'condition': _arePublicKeysMissing,
                          'message': AppLocalizations.of(context)!
                              .translate('public_keys_missing')
                        },
                        {
                          'condition': _isYourPubKeyMissing,
                          'message': AppLocalizations.of(context)!
                              .translate('your_public_key_missing')
                        },
                      ]),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        color: AppColors.error(context),
                      ),
                    ),
                ],
              ),

              Divider(height: 40, color: AppColors.text(context)),

              // Section 4: Enter Timelock Conditions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4. ${AppLocalizations.of(context)!.translate('enter_timelock_conditions')}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.text(context)),
                  ),
                  const SizedBox(height: 10),
                  IconButton(
                    icon: Icon(
                      Icons.lock_clock,
                      size: 40,
                      color: AppColors.icon(context),
                    ),
                    onPressed: _showAddTimelockDialog,
                  ),
                  const SizedBox(height: 10),
                  if (timelockConditions.isNotEmpty)
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: timelockConditions.map((condition) {
                        // print('condition: $condition');

                        // Retrieve aliases for the selected public keys
                        List<dynamic> aliases = (condition['pubkeys'] is String
                                ? jsonDecode(condition['pubkeys'])
                                : condition['pubkeys'])
                            .map((pubkeyEntry) {
                          // Extract the publicKey from the current entry
                          String publicKey = pubkeyEntry['publicKey'];

                          // print('Searching for publicKey: $publicKey');

                          // Debugging: Log all available public keys
                          // publicKeysWithAlias.forEach((entry) {
                          //   print('Available publicKey: ${entry['publicKey']}');
                          // });

                          // Find the alias for the publicKey in publicKeysWithAlias
                          return publicKeysWithAlias.firstWhere(
                            (entry) =>
                                entry['publicKey']!.trim().substring(
                                    0, entry['publicKey']!.length - 3) ==
                                publicKey
                                    .trim()
                                    .substring(0, publicKey.length - 3),
                            orElse: () => {'alias': 'Unknown'},
                          )['alias'];
                        }).toList();

                        // print('aliases: $aliases');

                        return Dismissible(
                          key: ValueKey(condition),
                          direction: DismissDirection.horizontal,
                          onDismissed: (direction) {
                            setState(() {
                              // print(condition);
                              timelockConditions.remove(condition);
                            });

                            NotificationHelper.show(
                              context,
                              message: AppLocalizations.of(context)!
                                  .translate('timelock_condition_removed')
                                  .replaceAll('{x}', condition['threshold']),
                              color: AppColors.error(context),
                            );
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16.0),
                            decoration: BoxDecoration(
                              color: AppColors.error(context),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Icon(
                              Icons.delete,
                              color: AppColors.text(context),
                              size: 24,
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16.0),
                            decoration: BoxDecoration(
                              color: AppColors.error(context),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Icon(
                              Icons.delete,
                              color: AppColors.text(context),
                              size: 24,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () {
                              _showAddTimelockDialog(
                                  condition: condition, isUpdating: true);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: AppColors.primary(context)
                                    .withAlpha((0.2 * 255).toInt()),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                    color: AppColors.primary(context)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${AppLocalizations.of(context)!.translate('threshold')}: ${condition['threshold']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    '${AppLocalizations.of(context)!.translate('older')}: ${condition['older']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    '${AppLocalizations.of(context)!.translate('after')}: ${condition['after']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    '${AppLocalizations.of(context)!.translate('pub_keys')}: ${aliases.join(', ')}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  Divider(height: 40, color: AppColors.text(context)),
                ],
              ),

              // Section 5: Create Descriptor
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '5. ${AppLocalizations.of(context)!.translate('create_descriptor')}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.text(context)),
                      ),
                      IconButton(
                        onPressed: () {
                          final BaseScaffoldState? baseScaffoldState =
                              baseScaffoldKey.currentState;

                          if (baseScaffoldState != null) {
                            baseScaffoldState.updateAssistantMessage(
                                context, 'assistant_create_descriptor');
                          }
                        },
                        icon: Icon(
                          Icons.help,
                          color: AppColors.icon(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    onPressed: () {
                      print(threshold);

                      print(publicKeysWithAliasMultisig);

                      _createDescriptor();
                    },
                    backgroundColor: AppColors.background(context),
                    foregroundColor: AppColors.text(context),
                    icon: Icons.create,
                    iconColor: AppColors.gradient(context),
                    label: AppLocalizations.of(context)!
                        .translate('create_descriptor'),
                  ),
                ],
              ),
            ],
          ],
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

    CustomBottomSheet.buildCustomStatefulBottomSheet(
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

                      NotificationHelper.show(
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

  void _showAddMultisigDialog(bool isUpdating) {
    final TextEditingController thresholdController = TextEditingController();

    List<Map<String, String>> selectedPubKeys = publicKeysWithAliasMultisig;
    if (threshold != null) {
      thresholdController.text = threshold!;
    }

    print(publicKeysWithAliasMultisig);
    print(selectedPubKeys);
    final rootContext = context;

    CustomBottomSheet.buildCustomStatefulBottomSheet(
      context: rootContext,
      titleKey: 'add_multisig',
      showAssistant: true,
      assistantMessages: [
        'assistant_add_multisig_tip1',
        'assistant_add_multisig_tip2',
        'assistant_add_multisig_tip3',
      ],
      contentBuilder: (setDialogState, updateAssistantMessage) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (publicKeysWithAlias.isNotEmpty)
              Wrap(
                spacing: 8.0,
                children: publicKeysWithAlias.map((key) {
                  bool isSelected = selectedPubKeys.any((selectedKey) =>
                      selectedKey['publicKey'] == key['publicKey']);
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        if (isSelected) {
                          selectedPubKeys.removeWhere((selectedKey) =>
                              selectedKey['publicKey'] == key['publicKey']);
                        } else {
                          selectedPubKeys.add({
                            'publicKey': key['publicKey']!,
                            'alias': key['alias']!
                          });
                        }
                        // print(selectedPubKeys);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.background(context)
                                .withAlpha((0.8 * 255).toInt())
                            : AppColors.background(context)
                                .withAlpha((0.2 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: AppColors.primary(context),
                        ),
                      ),
                      child: Text(
                        key['alias']!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 10),
            if (selectedPubKeys.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: thresholdController,
                    onChanged: (value) {
                      setDialogState(() {
                        if (int.tryParse(value) != null &&
                            int.parse(value) > selectedPubKeys.length) {
                          // If the entered value exceeds the max, reset it to the max
                          thresholdController.text =
                              selectedPubKeys.length.toString();
                          thresholdController.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                              offset: thresholdController.text.length,
                            ),
                          );
                        } else {
                          thresholdController.text = value;
                        }
                      });
                    },
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(rootContext)!
                          .translate('threshold'),
                      hintText: AppLocalizations.of(rootContext)!
                          .translate('threshold'),
                      borderColor: AppColors.background(context),
                    ),
                    style: TextStyle(
                      color: AppColors.text(context),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
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
                  final converted = selectedPubKeys
                      .map<Map<String, String>>(
                        (e) => e.map((k, v) => MapEntry(k, v.toString())),
                      )
                      .toList(growable: false); // <-- eager snapshot

                  final toAdd = converted.where(
                    (m) => !publicKeysWithAliasMultisig
                        .any((x) => x['pubkey'] == m['pubkey']),
                  );
                  publicKeysWithAliasMultisig.addAll(toAdd);

                  setState(() {
                    threshold = thresholdController.text;
                    multisigAdded = true;
                  });

                  Navigator.of(context, rootNavigator: true).pop();
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

  void _showAddTimelockDialog(
      {Map<String, dynamic>? condition, isUpdating = false}) {
    final TextEditingController thresholdController = TextEditingController();
    final TextEditingController olderController = TextEditingController();
    final TextEditingController afterController = TextEditingController();

    List<Map<String, dynamic>> selectedPubKeys =
        []; // Store both pubkey and alias

    String? currentThreshold;
    String? currentOlder;
    List<Map<String, dynamic>> updatedPubkeys = [];

    if (isUpdating && condition != null) {
      currentThreshold = condition['threshold']?.toString();
      currentOlder = condition['older']?.toString();
      thresholdController.text = currentThreshold ?? '';
      olderController.text = currentOlder ?? '';

      // Ensure pubkeys is correctly extracted as a list
      if (condition['pubkeys'] is String) {
        // Decode JSON string if needed
        updatedPubkeys =
            List<Map<String, dynamic>>.from(jsonDecode(condition['pubkeys']));
      } else if (condition['pubkeys'] is List) {
        updatedPubkeys =
            List<Map<String, dynamic>>.from(condition['pubkeys'] as List);
      }

      selectedPubKeys = updatedPubkeys.map((entry) {
        return {
          'publicKey': entry['publicKey']!,
          'alias': entry['alias']!,
        };
      }).toList();
    }

    final rootContext = context;

    CustomBottomSheet.buildCustomStatefulBottomSheet(
      context: rootContext,
      titleKey: isUpdating ? 'edit_timelock' : 'add_timelock',
      showAssistant: true,
      assistantMessages: [
        'assistant_add_timelock_tip1',
        'assistant_add_timelock_tip2',
        'assistant_add_timelock_tip3',
      ],
      contentBuilder: (setDialogState, updateAssistantMessage) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (publicKeysWithAlias.isNotEmpty)
              Wrap(
                spacing: 8.0,
                children: publicKeysWithAlias.map((key) {
                  bool isSelected = selectedPubKeys.any((selectedKey) =>
                      selectedKey['publicKey'] == key['publicKey']);
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        if (isSelected) {
                          selectedPubKeys.removeWhere((selectedKey) =>
                              selectedKey['publicKey'] == key['publicKey']);
                        } else {
                          selectedPubKeys.add({
                            'publicKey': key['publicKey']!,
                            'alias': key['alias']!
                          });
                        }
                        // print(selectedPubKeys);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.background(context)
                                .withAlpha((0.8 * 255).toInt())
                            : AppColors.background(context)
                                .withAlpha((0.2 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: AppColors.primary(context),
                        ),
                      ),
                      child: Text(
                        key['alias']!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 10),
            if (selectedPubKeys.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: thresholdController,
                    onChanged: (value) {
                      setDialogState(() {
                        if (int.tryParse(value) != null &&
                            int.parse(value) > selectedPubKeys.length) {
                          // If the entered value exceeds the max, reset it to the max
                          thresholdController.text =
                              selectedPubKeys.length.toString();
                          thresholdController.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                              offset: thresholdController.text.length,
                            ),
                          );
                        } else {
                          thresholdController.text = value;
                        }
                      });
                    },
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(rootContext)!
                          .translate('threshold'),
                      hintText: AppLocalizations.of(rootContext)!
                          .translate('threshold'),
                      borderColor: AppColors.background(context),
                    ),
                    style: TextStyle(
                      color: AppColors.text(context),
                    ),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 10),

                  // Older condition
                  TextFormField(
                    controller: olderController,
                    onChanged: (value) {
                      setDialogState(() {
                        final n = int.tryParse(value);
                        if (n != null && n > 65535) {
                          olderController.text = '65535';
                          olderController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: olderController.text.length),
                          );
                        } else {
                          // keep what the user typed; no extra formatting here
                        }
                      });

                      setDialogState(() {
                        // Clear the 'after' field if 'older' is filled
                        if (value.isNotEmpty) {
                          afterController.clear();
                        }
                      });
                    },
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(rootContext)!
                          .translate('enter_older'),
                      hintText:
                          AppLocalizations.of(rootContext)!.translate('older'),
                      borderColor: AppColors.background(context),
                    ).copyWith(
                      // add a time-picker button on the right
                      suffixIcon: IconButton(
                        tooltip: AppLocalizations.of(rootContext)!
                            .translate('pick_time'),
                        icon: const Icon(Icons.schedule),
                        color: AppColors.icon(context),
                        onPressed: () async {
                          // initial from current blocks (if any)
                          final currentBlocks =
                              int.tryParse(olderController.text) ?? 0;
                          final pickedBlocks =
                              await _pickBlocksFromTime(context, currentBlocks);
                          if (pickedBlocks != null) {
                            setDialogState(() {
                              final blocks = pickedBlocks.clamp(0, 65535);
                              olderController.text = blocks.toString();
                              olderController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: olderController.text.length),
                              );
                              // mirror your existing rule: filling 'older' clears 'after'
                              afterController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    style: TextStyle(
                      color: AppColors.text(context),
                    ),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 10),

                  // After condition
                  TextFormField(
                    controller: afterController,
                    onChanged: (value) async {
                      final settingsProvider =
                          Provider.of<SettingsProvider>(context, listen: false);

                      final WalletService wallServ =
                          WalletService(settingsProvider);
                      final String blockApiUrl =
                          '${wallServ.baseUrl}/blocks/tip/height';

                      try {
                        final response = await http.get(Uri.parse(blockApiUrl));
                        final int currHeight = json.decode(response.body);

                        int yearLimit5 = currHeight + 262800;

                        setDialogState(() {
                          int? enteredValue = int.tryParse(value);

                          if (enteredValue != null) {
                            if (enteredValue > yearLimit5) {
                              afterController.text = yearLimit5.toString();
                              afterController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: afterController.text.length),
                              );
                            } else {
                              afterController.text = enteredValue.toString();
                            }

                            // Clear 'older' if 'after' is set
                            olderController.clear();
                          }
                        });
                      } catch (e) {
                        // Handle network or parse error gracefully
                        print("Error fetching block height: $e");
                      }
                    },
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(rootContext)!
                          .translate('enter_after'),
                      hintText:
                          AppLocalizations.of(rootContext)!.translate('after'),
                      borderColor: AppColors.background(context),
                    ).copyWith(
                      suffixIcon: IconButton(
                        tooltip: AppLocalizations.of(rootContext)!
                            .translate('pick_time'),
                        icon: const Icon(Icons.schedule),
                        color: AppColors.icon(context),
                        onPressed: () async {
                          // Pass current target height (if any) so picker can prefill a duration
                          final int? currentTarget =
                              int.tryParse(afterController.text.trim());
                          final pickedTargetHeight =
                              await _pickAfterHeightFromTime(context,
                                  currentTargetHeight: currentTarget);

                          if (pickedTargetHeight != null) {
                            setDialogState(() {
                              afterController.text =
                                  pickedTargetHeight.toString();
                              afterController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: afterController.text.length),
                              );
                              // Mirror your rule: setting 'after' clears 'older'
                              olderController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    style: TextStyle(
                      color: AppColors.text(context),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
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
                  if (thresholdController.text.isNotEmpty &&
                      selectedPubKeys.isNotEmpty &&
                      (olderController.text.isNotEmpty ||
                          afterController.text.isNotEmpty) &&
                      !(olderController.text.isNotEmpty &&
                          afterController.text.isNotEmpty)) {
                    // Convert input to integer for accurate comparison
                    int newOlder = int.tryParse(olderController.text) ?? -1;
                    final newPubkeys = selectedPubKeys;
                    final String newThreshold = thresholdController.text.trim();

                    // Check if older value already exists in the list
                    bool isDuplicateOlder = timelockConditions.any(
                      (existingCondition) =>
                          int.tryParse(existingCondition['older'].toString()) ==
                              newOlder &&
                          existingCondition['older'].toString() != currentOlder,
                    );

                    if (isDuplicateOlder) {
                      NotificationHelper.show(
                        rootContext,
                        message: AppLocalizations.of(rootContext)!
                            .translate('error_older'),
                        color: AppColors.error(rootContext),
                      );
                    } else {
                      if (isUpdating) {
                        setState(() {
                          // Update the condition with new values
                          condition!['threshold'] = newThreshold;
                          condition['older'] = newOlder.toString();
                          condition['pubkeys'] = jsonEncode(newPubkeys);
                        });

                        Navigator.of(context, rootNavigator: true).pop();

                        NotificationHelper.show(
                          rootContext,
                          message: AppLocalizations.of(rootContext)!
                              .translate('timelock_updated'),
                        );
                      } else {
                        setState(() {
                          // Add the new timelock condition to the list
                          timelockConditions.add({
                            'threshold': thresholdController.text,
                            'older': olderController.text,
                            'after': afterController.text,
                            'pubkeys': jsonEncode(newPubkeys),
                          });
                          print(timelockConditions);
                        });

                        // Close the dialog after adding the condition
                        Navigator.of(context, rootNavigator: true).pop();
                      }
                    }
                  } else {
                    // print('Validation Failed: One or more fields are empty');
                    throw ('Validation Failed: One or more fields are empty');
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

  void _createDescriptor() {
    // print('Starting descriptor creation...');

    // Validate inputs
    _validateInputs();

    if (_isDescriptorNameMissing ||
        _isThresholdMissing ||
        _arePublicKeysMissing ||
        _isYourPubKeyMissing) {
      // print('Validation failed: Missing descriptor fields.');
      return;
    }

    // Extract and sort public keys
    List<String> extractedPublicKeys = publicKeysWithAliasMultisig
        .map((entry) => entry['publicKey']!)
        .toList()
      ..sort();

    // print('Extracted public keys: $extractedPublicKeys');

    String formattedKeys =
        extractedPublicKeys.toString().replaceAll(RegExp(r'^\[|\]$'), '');

    String multi = 'multi($threshold,$formattedKeys)';
    // print('Multi condition: $multi');

    String finalDescriptor;

    _handleTimelocks(); // Optional: Add debug log inside that method if needed
    // print('Timelock conditions after handling: $timelockConditions');

    if (timelockConditions.isNotEmpty) {
      timelockConditions.sort((a, b) {
        int getTimeLock(Map cond) =>
            int.tryParse(cond['older'] ?? cond['after'] ?? '0') ?? 0;
        return getTimeLock(a).compareTo(getTimeLock(b));
      });

      // print('Sorted timelock conditions: $timelockConditions');

      List<String> formattedTimelocks = timelockConditions.map((condition) {
        String threshold = condition['threshold'];
        String older = condition['older'];
        String after = condition['after'];

        // print('olderCondition: $older');
        // print('afterCondition: $after');

        String timeCondition = older.isNotEmpty
            ? 'older($older)'
            : after.isNotEmpty
                ? 'after($after)'
                : throw Exception('Missing TimeLock condition');

        List<String> pubkeys = (condition['pubkeys'] as List)
            .map((key) => key['publicKey'] as String)
            .toList()
          ..sort();

        String pubkeysString = pubkeys.join(',');
        String multiCondition = pubkeys.length > 1
            ? 'multi($threshold,$pubkeysString)'
            : 'pk(${pubkeys.first})';

        String result = 'and_v(v:$timeCondition,$multiCondition)';
        // print('Formatted timelock: $result');

        return result;
      }).toList();

      String timelockCondition = buildTimelockCondition(formattedTimelocks);
      // print('Combined timelock condition: $timelockCondition');

      finalDescriptor = 'wsh(or_d($multi,$timelockCondition))';
    } else {
      finalDescriptor = 'wsh($multi)';
    }

    // print('Final descriptor before cleaning: $finalDescriptor');

    setState(() {
      _finalDescriptor = finalDescriptor.replaceAll(' ', '');
    });

    // print('Final descriptor stored: $_finalDescriptor');

    _createDescriptorDialog(context);
  }

  void _createDescriptorDialog(BuildContext context) {
    final rootContext = context;

    CustomBottomSheet.buildCustomBottomSheet(
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
                    (await CustomBottomSheet.buildCustomBottomSheet<bool>(
                          context: rootContext,
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

              NotificationHelper.show(
                rootContext,
                message:
                    '${AppLocalizations.of(rootContext)!.translate('file_saved')} ${directory.path}/$fileName',
              );
            } else {
              NotificationHelper.showError(
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

  /// Lets the user pick a relative time and converts it to blocks (≈10 min per block).
  /// Returns the computed number of blocks, or null if cancelled.
  Future<int?> _pickBlocksFromTime(
      BuildContext context, int initialBlocks) async {
    final maxBlocks = 65535;
    final initial =
        Duration(minutes: (initialBlocks * 10).clamp(0, maxBlocks * 10));
    final max = Duration(minutes: maxBlocks * 10);

    final dur = await _pickRelativeDuration(
      context,
      initial: initial,
      max: max,
      minuteStep: 5,
    );
    if (dur == null) return null;

    final estBlocks = (dur.inMinutes / 10).round().clamp(0, maxBlocks);
    return estBlocks;
  }

  Future<int?> _pickAfterHeightFromTime(
    BuildContext context, {
    int? currentTargetHeight,
  }) async {
    try {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final wallServ = WalletService(settingsProvider);
      final url = '${wallServ.baseUrl}/blocks/tip/height';

      final resp = await http.get(Uri.parse(url));
      final int currHeight = json.decode(resp.body);

      const int maxBlocksAhead = 262800; // ~5 years
      final int initialBlocksAhead = (() {
        if (currentTargetHeight == null) return 0;
        final d = (currentTargetHeight - currHeight);
        if (d < 0) return 0;
        return d.clamp(0, maxBlocksAhead);
      })();

      final initial = Duration(minutes: initialBlocksAhead * 10);
      final max = Duration(minutes: maxBlocksAhead * 10);

      final dur = await _pickRelativeDuration(
        context,
        initial: initial,
        max: max,
        minuteStep: 5,
      );
      if (dur == null) return null;

      final estBlocks = (dur.inMinutes / 10).round().clamp(0, maxBlocksAhead);
      final estTargetHeight = currHeight + estBlocks;
      return estTargetHeight;
    } catch (e) {
      print('Error in _pickAfterHeightFromTime: $e');
      return null;
    }
  }

  Future<Duration?> _pickRelativeDuration(
    BuildContext context, {
    required Duration initial,
    required Duration max,
    int minuteStep = 5,
  }) {
    // normalize initial within [0, max]
    if (initial.isNegative) initial = Duration.zero;
    if (initial > max) initial = max;

    // --- decompose initial into y/d/h/m (approx 365d per year) ---
    int initTotalDays = initial.inDays;
    int years = initTotalDays ~/ 365;
    int days = initTotalDays % 365;
    int hours = initial.inHours % 24;
    int minutes = initial.inMinutes % 60;
    minutes = (minutes ~/ minuteStep) * minuteStep; // snap to step

    // --- limits derived from max ---
    final int maxTotalDays = max.inDays;
    final int maxYears = maxTotalDays ~/ 365;

    Duration buildDuration() =>
        Duration(days: years * 365 + days, hours: hours, minutes: minutes);

    // Given current `years`, how many days are allowed for that year selection
    int daysCapForYears(int y) {
      final usedDaysByYears = y * 365;
      final remainingDays = maxTotalDays - usedDaysByYears;
      if (remainingDays <= 0) return 0;
      // If we're at the final year bucket, days cap equals remainingDays (could be <365)
      // Otherwise we can scroll a full 0..364 range.
      return y == maxYears ? remainingDays : 365;
    }

    // Ensure initial days fit for the initial years
    days = days.clamp(
        0, daysCapForYears(years) == 0 ? 0 : daysCapForYears(years) - 1);

    return showModalBottomSheet<Duration>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final bg = AppColors.dialog(sheetCtx);

        return StatefulBuilder(
          builder: (ctx, setState) {
            // live compute and cap
            Duration chosen = buildDuration();
            if (chosen > max) chosen = max;

            final textStyle = Theme.of(sheetCtx).textTheme.bodyMedium;

            Widget col({
              required int itemCount,
              required int selected,
              required ValueChanged<int> onSelected,
              required String Function(int) label,
              double width = 90,
            }) {
              // guard selected bounds
              final safeSelected =
                  selected.clamp(0, (itemCount - 1).clamp(0, itemCount - 1));
              return SizedBox(
                width: width,
                height: 200,
                child: CupertinoPicker(
                  itemExtent: 34,
                  scrollController:
                      FixedExtentScrollController(initialItem: safeSelected),
                  useMagnifier: true,
                  magnification: 1.08,
                  onSelectedItemChanged: onSelected,
                  children: List.generate(
                    itemCount,
                    (i) => Center(
                      child: Text(
                        label(i),
                        style: textStyle,
                      ),
                    ),
                  ),
                ),
              );
            }

            // dynamic cap for days based on current years
            final int daysCap = daysCapForYears(years);
            final int daysCount =
                daysCap == 0 ? 1 : (years == maxYears ? daysCap + 0 : 365);
            // if user scrolled years so days is now out of range, clamp it
            if (daysCount > 0 && days >= daysCount) {
              days = daysCount - 1;
            }

            // compute live blocks (10 minutes per block)
            final int estBlocks = (chosen.inMinutes / 10).round();

            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 24,
                      offset: Offset(0, -6),
                      color: Colors.black38,
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(sheetCtx)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.opaque(0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // pickers: Years / Days / Hours / Minutes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Years
                        col(
                          itemCount: maxYears + 1,
                          selected: years,
                          onSelected: (i) {
                            setState(() {
                              years = i;
                              // clamp days to the new cap
                              final cap = daysCapForYears(years);
                              final newCount = cap == 0
                                  ? 1
                                  : (years == maxYears ? cap : 365);
                              if (days >= newCount) {
                                days = (newCount - 1).clamp(0, newCount - 1);
                              }
                            });
                          },
                          label: (i) => '$i y',
                          width: 76,
                        ),
                        // Days (0..364 normally; shortened if in last year bucket)
                        col(
                          itemCount: daysCount, // dynamic
                          selected: daysCount == 0 ? 0 : days,
                          onSelected: (i) => setState(() => days = i),
                          label: (i) => '$i d',
                          width: 76,
                        ),
                        // Hours
                        col(
                          itemCount: 24,
                          selected: hours,
                          onSelected: (i) => setState(() => hours = i),
                          label: (i) => '$i h',
                          width: 72,
                        ),
                        // Minutes (stepped)
                        col(
                          itemCount: (60 ~/ minuteStep),
                          selected: (minutes ~/ minuteStep)
                              .clamp(0, (60 ~/ minuteStep) - 1),
                          onSelected: (i) =>
                              setState(() => minutes = i * minuteStep),
                          label: (i) => '${i * minuteStep} m',
                          width: 78,
                        ),
                      ],
                    ),

                    // live hint: Y D H M  + ≈ blocks
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        '${chosen.inDays ~/ 365}y ${(chosen.inDays % 365)}d '
                        '${chosen.inHours % 24}h ${chosen.inMinutes % 60}m   '
                        '≈ $estBlocks blocks',
                        style: textStyle,
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(sheetCtx, rootNavigator: true)
                                  .pop(null),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(sheetCtx, rootNavigator: true)
                                  .pop(chosen > max ? max : chosen),
                          child: const Text('Confirm'),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/exceptions/validation_result.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/wallet_pages/qr_scanner_page.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:provider/provider.dart';

class ImportSharedWallet extends StatefulWidget {
  const ImportSharedWallet({super.key});

  @override
  ImportSharedWalletState createState() => ImportSharedWalletState();
}

class ImportSharedWalletState extends State<ImportSharedWallet> {
  String? publicKey;
  String? _descriptor;
  String? _mnemonic;
  String changeKey = "";
  String privKey = "";
  String _status = 'Idle';

  String? initialPubKey;

  late Box<dynamic> descriptorBox;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _descriptorController = TextEditingController();

  late final WalletService _walletService;

  List<Map<String, String>> _pubKeysAlias = [];
  String _descriptorName = "";

  bool _isDescriptorValid = true;

  final GlobalKey<BaseScaffoldState> baseScaffoldKey =
      GlobalKey<BaseScaffoldState>();

  @override
  void initState() {
    super.initState();

    _walletService =
        WalletService(Provider.of<SettingsProvider>(context, listen: false));

    print(Provider.of<SettingsProvider>(context, listen: false).network);

    // Add a listner to the TextEditingController
    _descriptorController.addListener(() {
      if (_descriptorController.text.isNotEmpty) {
        _descriptor = _descriptorController.text;
        _validateDescriptor(_descriptor.toString());
      }
    });

    _generatePublicKey(isGenerating: false);
  }

  @override
  void dispose() {
    // Dispose of the controller to avoid memory leaks
    _descriptorController.dispose();
    super.dispose();
  }

  Future<void> _generatePublicKey({bool isGenerating = true}) async {
    var walletBox = Hive.box('walletBox');

    String savedMnemonic = walletBox.get('walletMnemonic');

    final mnemonic = await Mnemonic.fromString(savedMnemonic);

    final hardenedDerivationPath =
        await DerivationPath.create(path: "m/84h/1h/0h");

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");
    final changeDerivationPath = await DerivationPath.create(path: "m/1");

    final (receivingSecretKey, receivingPublicKey) =
        await _walletService.deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      mnemonic,
    );
    final (changeSecretKey, changePublicKey) =
        await _walletService.deriveDescriptorKeys(
      hardenedDerivationPath,
      changeDerivationPath,
      mnemonic,
    );

    _mnemonic = savedMnemonic;

    setState(() {
      if (isGenerating) {
        publicKey = receivingPublicKey.toString();
      }
      initialPubKey = receivingPublicKey.toString();
      changeKey = changePublicKey.toString();
    });
  }

  void _uploadFile() async {
    // Resetting the initial values
    _descriptorController.clear();
    _pubKeysAlias.clear();

    setState(() {
      _status = 'Idle';
      _isDescriptorValid = true;
    });
    try {
      // Open the file picker for JSON files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'], // Allow only JSON files
      );

      if (result != null && result.files.single.path != null) {
        // Get the file path
        final filePath = result.files.single.path!;

        // Read the file
        final file = File(filePath);
        final fileContents = await file.readAsString();

        // Decode the JSON data
        final Map<String, dynamic> jsonData = jsonDecode(fileContents);

        // Extract the information you need
        final String descriptor =
            jsonData['descriptor'] ?? 'No descriptor found';

        // Ensure the type is List<Map<String, String>>
        final List<Map<String, String>> publicKeysWithAlias =
            (jsonData['publicKeysWithAlias'] as List)
                .map((item) => Map<String, String>.from(item))
                .toList();

        final String descriptorName =
            jsonData['descriptorName'] ?? 'No Descriptor found';

        setState(() {
          _descriptorController.text = descriptor;
          _descriptor = descriptor;
          _pubKeysAlias = publicKeysWithAlias;
          _descriptorName = descriptorName;
        });

        // Use the extracted data
        // print('Descriptor: $descriptor');
        // print('Public Keys With Alias: $publicKeysWithAlias');

        SnackBarHelper.show(
          context,
          message: AppLocalizations.of(context)!.translate('file_uploaded'),
        );
      } else {
        // User canceled the file picker
        // print('File picking canceled');
        throw ('File picking canceled');
      }
    } catch (e) {
      // print('Error uploading file: $e');
      SnackBarHelper.showError(
        context,
        message: AppLocalizations.of(context)!.translate('failed_upload'),
      );
    }
  }

  void _navigateToSharedWallet() async {
    if (_descriptor == null || _descriptor!.isEmpty) {
      setState(() {
        _status = 'Descriptor cannot be empty';
      });
      return;
    }

    bool isValid = await _validateDescriptor(_descriptor!);
    setState(() {
      _status = 'Loading';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (isValid) {
      setState(() {
        _status = 'Success';
      });

      await Future.delayed(const Duration(seconds: 1));

      // _walletService.printInChunks(_descriptor.toString());

      if (_pubKeysAlias.isEmpty) {
        setState(() {
          _pubKeysAlias = _walletService
              .extractPublicKeysWithAliases(_descriptor.toString());
        });
      }

      // print('_pubKeysAlias: $_pubKeysAlias');

      // print('descriptor: $_descriptor');
      // print('mnemonic: $_mnemonic');
      // print('pubKeysAlias: $_pubKeysAlias');
      // print('descriptorName: $_descriptorName');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SharedWallet(
            descriptor: _descriptor!,
            mnemonic: _mnemonic!,
            pubKeysAlias: _pubKeysAlias,
            descriptorName: _descriptorName,
          ),
        ),
      );
    } else {
      setState(() {
        _status = 'Cannot navigate: Invalid Descriptor';
      });
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

      setState(() {
        _isDescriptorValid = result.isValid;
        _status = result.isValid
            ? 'Descriptor is valid'
            : result.errorMessage ?? 'Invalid Descriptor';
      });
      return result.isValid;
    } catch (e) {
      setState(() {
        _isDescriptorValid = false;
        _status = 'Error validating Descriptor: $e';
      });
      return false;
    }
  }

  Widget _buildStatusBar() {
    String lottieAnimation;
    String statusText;

    // print('_status: $_status');

    if (_status.startsWith('Idle')) {
      lottieAnimation = 'assets/animations/idle.json';
      statusText = AppLocalizations.of(context)!.translate('idle_ready_import');
    } else if (_status.startsWith('Descriptor is valid')) {
      lottieAnimation = 'assets/animations/creating_wallet.json';
      statusText =
          AppLocalizations.of(context)!.translate('descriptor_valid_proceed');
    } else if (_status.contains('Invalid Descriptor') ||
        _status.contains('Error') ||
        _status.contains('Please enter a valid descriptor!')) {
      lottieAnimation = 'assets/animations/error_cross.json';
      statusText =
          "${AppLocalizations.of(context)!.translate('invalid_descriptor_status')} $_status";
    } else if (_status.contains('Success')) {
      lottieAnimation = 'assets/animations/success.json';
      statusText = AppLocalizations.of(context)!.translate('navigating_wallet');
    } else {
      lottieAnimation = 'assets/animations/loading.json';
      statusText = AppLocalizations.of(context)!.translate('loading');
    }

    // print(_status);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey<String>(_status), // Use a unique key for each status
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 50,
              width: 50,
              child: Lottie.asset(
                lottieAnimation,
                fit: BoxFit.contain,
              ),
            ),
            Expanded(
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(AppLocalizations.of(context)!.translate('import_wallet')),
      key: baseScaffoldKey,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusBar(),
                const SizedBox(height: 16),
                // Form and descriptor field
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _descriptorController,
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText:
                          AppLocalizations.of(context)!.translate('descriptor'),
                      hintText:
                          AppLocalizations.of(context)!.translate('descriptor'),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !_isDescriptorValid) {
                        return AppLocalizations.of(context)!
                            .translate('invalid_descriptor');
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Public Key display with copy functionality
                if (publicKey != null)
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
                            "${AppLocalizations.of(context)!.translate('pub_key')}: $publicKey",
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.text(context),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon:
                              Icon(Icons.copy, color: AppColors.icon(context)),
                          onPressed: () {
                            UtilitiesService.copyToClipboard(
                              context: context,
                              text: publicKey.toString(),
                              messageKey: 'pub_key_clipboard',
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Generate Public Key Button
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
                    foregroundColor: AppColors.text(context),
                    icon: Icons.generating_tokens,
                    iconColor: AppColors.gradient(context),
                    label: AppLocalizations.of(context)!
                        .translate('generate_public_key'),
                  ),
                ),

                const SizedBox(height: 16),

                // Select File Button
                GestureDetector(
                  onLongPress: () {
                    final BaseScaffoldState? baseScaffoldState =
                        baseScaffoldKey.currentState;

                    if (baseScaffoldState != null) {
                      baseScaffoldState.updateAssistantMessage(
                          context, 'assistant_scan_qr_descriptor');
                    }
                  },
                  child: CustomButton(
                    onPressed: () async {
                      final result =
                          await Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                            builder: (_) => const QRScannerPage(
                                title: 'Scan Bitcoin Address')),
                      );

                      if (result != null) {
                        // ✅ If needed, reopen the dialog here with updated data
                        _descriptorController.text = result;
                      }
                    },
                    backgroundColor: AppColors.background(context),
                    foregroundColor: AppColors.gradient(context),
                    icon: Icons.qr_code_scanner,
                    iconColor: AppColors.text(context),
                    label: AppLocalizations.of(context)!
                        .translate('scan_qr_descriptor'),
                  ),
                ),

                const SizedBox(height: 16),

                // Select File Button
                GestureDetector(
                  onLongPress: () {
                    final BaseScaffoldState? baseScaffoldState =
                        baseScaffoldKey.currentState;

                    if (baseScaffoldState != null) {
                      baseScaffoldState.updateAssistantMessage(
                          context, 'assistant_select_file');
                    }
                  },
                  child: CustomButton(
                    onPressed: _uploadFile,
                    backgroundColor: AppColors.background(context),
                    foregroundColor: AppColors.gradient(context),
                    icon: Icons.file_upload,
                    iconColor: AppColors.text(context),
                    label:
                        AppLocalizations.of(context)!.translate('select_file'),
                  ),
                ),

                const SizedBox(height: 16),

                // Import Shared Wallet Button
                GestureDetector(
                  onLongPress: () {
                    final BaseScaffoldState? baseScaffoldState =
                        baseScaffoldKey.currentState;

                    if (baseScaffoldState != null) {
                      baseScaffoldState.updateAssistantMessage(
                          context, 'assistant_import_sw_button');
                    }
                  },
                  child: CustomButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate() ||
                          (_status.contains('Success') ||
                              _status.startsWith('Descriptor is valid'))) {
                        await Future.delayed(const Duration(milliseconds: 500));

                        _navigateToSharedWallet();
                      } else {
                        setState(() {
                          _status = 'Please enter a valid descriptor';
                        });
                      }
                    },
                    backgroundColor: AppColors.background(context),
                    foregroundColor: AppColors.text(context),
                    icon: Icons.account_balance_wallet,
                    iconColor: AppColors.gradient(context),
                    label: AppLocalizations.of(context)!
                        .translate('import_wallet'),
                  ),
                ),

                const SizedBox(height: 16),

                // Display Aliases and Public Keys
                if (_pubKeysAlias.isNotEmpty) ...[
                  Text(
                    AppLocalizations.of(context)!
                        .translate('aliases_and_pubkeys'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardTitle(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._pubKeysAlias.map(
                    (keyAlias) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.container(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
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
                                        "${AppLocalizations.of(context)!.translate('alias')}: ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardTitle(context),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${keyAlias['alias']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: AppColors.text(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
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
                                        "${AppLocalizations.of(context)!.translate('pub_key')}: ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardTitle(context),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${keyAlias['publicKey']}',
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
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

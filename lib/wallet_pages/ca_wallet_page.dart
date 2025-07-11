import 'dart:async';

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:hive/hive.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:provider/provider.dart';

class CAWalletPage extends StatefulWidget {
  const CAWalletPage({super.key});

  @override
  CAWalletPageState createState() => CAWalletPageState();
}

class CAWalletPageState extends State<CAWalletPage> {
  String? _mnemonic;
  String _status = 'Idle';

  Wallet? _wallet;

  final TextEditingController _mnemonicController = TextEditingController();

  late final WalletService _walletService;

  bool _isMnemonicEntered = false;

  final FocusNode _mnemonicFocusNode = FocusNode();
  Timer? _debounceTimer;

  static Network _network(BuildContext context) =>
      Provider.of<SettingsProvider>(context, listen: false).network;

  @override
  void initState() {
    super.initState();

    _walletService =
        WalletService(Provider.of<SettingsProvider>(context, listen: false));

    _mnemonicController.addListener(() {
      _mnemonic = _mnemonicController.text;
      _validateMnemonic(_mnemonic.toString());
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mnemonicController.dispose();
    _mnemonicFocusNode.dispose();
    super.dispose();
  }

  Future<void> _createWallet() async {
    setState(() {
      _status = 'Creating wallet...';
    });

    final connectivityResult = await Connectivity().checkConnectivity();
    Wallet wallet;

    if (!connectivityResult.contains(ConnectivityResult.none)) {
      wallet = await _walletService.loadSavedWallet(mnemonic: _mnemonic!);

      setState(() {
        _wallet = wallet;
        _status = 'Wallet loaded successfully!';
      });
    } else {
      wallet = await _walletService.createOrRestoreWallet(_mnemonic!);
      setState(() {
        _wallet = wallet;
        _status = 'Wallet created successfully';
      });
    }

    var walletBox = Hive.box('walletBox');
    walletBox.put('walletMnemonic', _mnemonic);
    walletBox.put('walletNetwork', _network.toString());

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/wallet_page',
      arguments: _wallet,
    );
  }

  Future<void> _generateMnemonic() async {
    final res = await Mnemonic.create(WordCount.words12);

    setState(() {
      _mnemonicController.text = res.asString();
      _mnemonic = res.asString();
      _status = 'New mnemonic generated!';
    });
  }

  String _getAnimationPath() {
    if (_status.contains('successfully')) {
      return 'assets/animations/success.json';
    } else if (_status.contains('Creating')) {
      return 'assets/animations/creating_wallet.json';
    } else {
      return 'assets/animations/idle.json';
    }
  }

  void _validateMnemonic(String value) {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Start a new one
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final isValid =
          value.trim().isNotEmpty && await _walletService.checkMnemonic(value);

      // print('Value: $value');

      if (_isMnemonicEntered != isValid) {
        if (mounted) {
          setState(() {
            _isMnemonicEntered = isValid;
          });
        }
      }
    });
  }

  Widget _buildStatusIndicator() {
    String statusText;

    if (_status.startsWith('Idle')) {
      statusText = AppLocalizations.of(context)!.translate('idle_ready_import');
    } else if (_status == 'New mnemonic generated!') {
      statusText = AppLocalizations.of(context)!.translate('new_mnemonic');
    } else if (_status == 'Creating wallet...') {
      statusText = AppLocalizations.of(context)!.translate('creating_wallet');
    } else if (_status == 'Wallet loaded successfully!') {
      statusText = AppLocalizations.of(context)!.translate('wallet_loaded');
    } else if (_status == 'Wallet created successfully') {
      statusText = AppLocalizations.of(context)!.translate('wallet_created');
    } else if (_status.contains('Success')) {
      statusText = AppLocalizations.of(context)!.translate('navigating_wallet');
    } else {
      statusText = AppLocalizations.of(context)!.translate('loading');
    }

    return Column(
      children: [
        // Lottie Animation
        Lottie.asset(
          _getAnimationPath(),
          height: 100,
          width: 100,
          repeat:
              !_status.contains('successfully'), // Loop only for non-success
        ),
        const SizedBox(height: 10),
        // Status Text
        Text(
          statusText,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _status.contains('successfully')
                ? AppColors.primary(context)
                : _status.contains('Creating')
                    ? AppColors.accent(context)
                    : AppColors.text(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<BaseScaffoldState> baseScaffoldKey =
        GlobalKey<BaseScaffoldState>();

    return BaseScaffold(
      title: Text(AppLocalizations.of(context)!.translate('create_restore')),
      key: baseScaffoldKey,
      showDrawer: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cool Status Indicator with Animation
                  _buildStatusIndicator(),

                  const SizedBox(height: 20),

                  // Mnemonic Input Field
                  TextFormField(
                    focusNode: _mnemonicFocusNode,
                    controller: _mnemonicController,
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(context)!
                          .translate('enter_mnemonic'),
                      hintText:
                          AppLocalizations.of(context)!.translate('enter_12'),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Create Wallet Button
                  GestureDetector(
                    onLongPress: () {
                      final BaseScaffoldState? baseScaffoldState =
                          baseScaffoldKey.currentState;

                      if (baseScaffoldState != null) {
                        baseScaffoldState.updateAssistantMessage(
                            context, 'assistant_create_wallet');
                      }
                    },
                    child: CustomButton(
                      onPressed: _isMnemonicEntered ? _createWallet : null,
                      backgroundColor: AppColors.background(context),
                      foregroundColor: AppColors.text(context),
                      icon: Icons.wallet,
                      iconColor: AppColors.gradient(context),
                      label: AppLocalizations.of(context)!
                          .translate('create_wallet'),
                      padding: 16.0,
                      iconSize: 28.0,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Generate Mnemonic Button
                  GestureDetector(
                    onLongPress: () {
                      final BaseScaffoldState? baseScaffoldState =
                          baseScaffoldKey.currentState;

                      if (baseScaffoldState != null) {
                        baseScaffoldState.updateAssistantMessage(
                            context, 'assistant_generate_mnemonic');
                      }
                    },
                    child: CustomButton(
                      onPressed: _generateMnemonic,
                      backgroundColor: AppColors.background(context),
                      foregroundColor: AppColors.gradient(context),
                      icon: Icons.create,
                      iconColor: AppColors.text(context),
                      label: AppLocalizations.of(context)!
                          .translate('generate_mnemonic'),
                      padding: 16.0,
                      iconSize: 28.0,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

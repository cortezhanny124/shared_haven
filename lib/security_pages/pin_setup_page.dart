import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  PinSetupPageState createState() => PinSetupPageState();
}

class PinSetupPageState extends State<PinSetupPage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _networkFieldKey = GlobalKey<FormFieldState<Network>>();

  String _status = '';

  @override
  void initState() {
    super.initState();

    // Wait until the first frame is rendered before showing the dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLegalDisclaimerDialog();
    });
  }

  void _savePin(String pin) async {
    var walletBox = Hive.box('walletBox');
    await walletBox.put('userPin', pin);

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/ca_wallet_page');
  }

  void _validateAndSave() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _status = 'PIN successfully set!';
      });
      _savePin(_pinController.text);
    } else {
      setState(() {
        _status = 'Please correct the errors and try again';
      });
    }
  }

  void _showLegalDisclaimerDialog() {
    final rootContext = context;
    final scrollController = ScrollController();
    bool isAtBottom = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            scrollController.addListener(() {
              final reachedBottom = scrollController.offset >=
                  scrollController.position.maxScrollExtent;

              if (reachedBottom != isAtBottom) {
                setState(() => isAtBottom = reachedBottom);
              }
            });

            void handleNextPressed() {
              if (!isAtBottom) {
                // Scroll to bottom instead of closing
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else {
                // Already at bottom ==> proceed
                Navigator.pop(context);
                _showInitialInstructionsDialog();
              }
            }

            return AlertDialog(
              title: Text(
                AppLocalizations.of(rootContext)!
                    .translate('legal_disclaimer_title'),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                height: 350, // so that scrolling is possible
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    '''
1. Risks related to the use of SharedHaven Wallet
SharedHaven will not be responsible for any losses, damages or claims arising from events falling within the scope of the following five categories:

Mistakes made by the user of any cryptocurrency-related software or service, e.g., forgotten passwords, payments sent to wrong coin addresses, and accidental deletion of wallets.
Software problems of the wallet and/or any cryptocurrency-related software or service, e.g., corrupted wallet file, incorrectly constructed transactions, unsafe cryptographic libraries, malware affecting the wallet and/or any cryptocurrency-related software or service.
Technical failures in the hardware of the user of any cryptocurrency-related software or service, e.g., data loss due to a faulty or damaged storage device.
Security problems experienced by the user of any cryptocurrency-related software or service, e.g., unauthorized access to users' wallets and/or accounts.
Actions or inactions of third parties and/or events experienced by third parties, e.g., bankruptcy of service providers, information security attacks on service providers, and fraud conducted by third parties.

2. Compliance with tax obligations
The users of the wallet are solely responsible to determinate what, if any, taxes apply to their crypto-currency transactions. The owners of, or contributors to, the wallet are NOT responsible for determining the taxes that apply to crypto-currency transactions.

3. No warranties
The wallet is provided on an "as is" basis without any warranties of any kind regarding the wallet and/or any content, data, materials and/or services provided on the wallet.

4. Limitation of liability
Unless otherwise required by law, in no event shall the owners of, or contributors to, the wallet be liable for any damages of any kind, including, but not limited to, loss of use, loss of profits, or loss of data arising out of or in any way connected with the use of the wallet. In no way are the owners of, or contributors to, the wallet responsible for the actions, decisions, or other behavior taken or not taken by you in reliance upon the wallet.

5. Arbitration
The user of the wallet agrees to arbitrate any dispute arising from or in connection with the wallet or this disclaimer, except for disputes related to copyrights, logos, trademarks, trade names, trade secrets or patents.

6. Last amendment
This disclaimer was amended for the last time on October 1st, 2025 ''',
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: handleNextPressed,
                  child: Text(
                    AppLocalizations.of(rootContext)!.translate(
                      isAtBottom ? 'next' : 'scroll_to_continue',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInitialInstructionsDialog() {
    final rootContext = context;

    final rawText =
        AppLocalizations.of(rootContext)!.translate('initial_instructions');

    // Split the text around the {x} placeholder
    final parts = rawText.split('{x}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(rootContext)!
              .translate('initial_instructions_title'),
          textAlign: TextAlign.center,
        ),
        content: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: AppColors.text(context),
              fontSize: 16,
              height: 1.5,
            ),
            children: [
              TextSpan(text: parts[0]), // before the URL
              TextSpan(
                text: 'https://github.com/cortezhanny124/shared_haven',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    final url = Uri.parse(
                        'https://github.com/cortezhanny124/shared_haven');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
              ),
              if (parts.length > 1) TextSpan(text: parts[1]), // after the URL
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(rootContext)!.translate('got_it'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    String statusText;

    if (_status.isEmpty) return const SizedBox.shrink();

    if (_status == 'Please correct the errors and try again') {
      statusText = AppLocalizations.of(context)!.translate('correct_errors');
    } else {
      statusText = AppLocalizations.of(context)!.translate('pin_set_success');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _status.contains('successfully')
            ? AppColors.primary(context)
            : AppColors.error(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: AppColors.text(context),
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final rootContext = context;

    return BaseScaffold(
      title: Text(AppLocalizations.of(context)!.translate('set_pin')),
      showDrawer: false,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Add an icon/illustration
              Center(
                child: Icon(
                  Icons.lock,
                  size: 100,
                  color: AppColors.icon(context),
                ),
              ),
              const SizedBox(height: 20),
              // Status Banner
              _buildStatusBanner(),
              // PIN Entry Field
              TextFormField(
                controller: _pinController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText:
                      AppLocalizations.of(context)!.translate('enter_pin'),
                  hintText: AppLocalizations.of(context)!
                      .translate('enter_6_digits_pin'),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length != 6) {
                    return AppLocalizations.of(context)!
                        .translate('pin_must_be_six');
                  }
                  return null;
                },
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 16),
              // Confirm PIN Entry Field
              TextFormField(
                controller: _confirmPinController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText:
                      AppLocalizations.of(context)!.translate('confirm_pin'),
                  hintText:
                      AppLocalizations.of(context)!.translate('re_enter_pin'),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value != _pinController.text) {
                    return AppLocalizations.of(context)!
                        .translate('pin_mismatch');
                  }
                  return null;
                },
                style: TextStyle(
                  color: AppColors.text(context),
                ),
              ),

              const SizedBox(height: 20),
              // Set PIN Button
              CustomButton(
                onPressed: _validateAndSave,
                backgroundColor: AppColors.background(context),
                foregroundColor: AppColors.gradient(context),
                icon: Icons.pin,
                iconColor: AppColors.text(context),
                label: AppLocalizations.of(context)!.translate('set_pin'),
                padding: 16.0,
                iconSize: 28.0,
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<Network>(
                key: _networkFieldKey,
                value: settingsProvider.network,
                items: Network.values.where((network) {
                  return network == Network.bitcoin ||
                      network == Network.testnet;
                }).map((network) {
                  final displayName = network == Network.bitcoin
                      ? 'Mainnet'
                      : network.name.capitalize();

                  return DropdownMenuItem(
                    value: network,
                    child: Text(displayName),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == null) return;

                  if (value == Network.bitcoin) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          AppLocalizations.of(rootContext)!
                              .translate('mainnet_switch'),
                        ),
                        content: Text(
                          AppLocalizations.of(rootContext)!
                              .translate('mainnet_switch_text'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              AppLocalizations.of(rootContext)!
                                  .translate('cancel'),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              AppLocalizations.of(rootContext)!
                                  .translate('continue'),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      settingsProvider.setNetwork(value);
                    } else {
                      // Visually revert the dropdown to the provider's current value
                      _networkFieldKey.currentState
                          ?.didChange(settingsProvider.network);
                    }
                  } else {
                    settingsProvider.setNetwork(value);
                  }
                },
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.background(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                ),
                dropdownColor: AppColors.gradient(context),
                isExpanded: true,
                menuMaxHeight: 250,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

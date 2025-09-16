import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/widget_helpers/notification_helper.dart';
import 'package:provider/provider.dart';

class FeeSelector extends StatefulWidget {
  final void Function(double feeValue) onFeeSelected;
  final BuildContext context;

  const FeeSelector({
    super.key,
    required this.onFeeSelected,
    required this.context,
  });

  @override
  State<FeeSelector> createState() => _FeeSelectorState();
}

class _FeeSelectorState extends State<FeeSelector> {
  Map<String, dynamic>? recommendedFees;
  String? selectedOption;
  final TextEditingController customFeeController = TextEditingController();
  bool isLoading = true;
  bool showFallbackCustomFee = false;

  late SettingsProvider settingsProvider;
  late WalletService walletService;

  @override
  void initState() {
    super.initState();
    settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    walletService = WalletService(settingsProvider);

    // Start a fallback timer for recommended fees
    // Future.delayed(const Duration(seconds: 4), () {
    //   if (mounted && recommendedFees == null) {
    //     setState(() {
    //       showFallbackCustomFee = true;

    //       // 💡 Force 'custom' selection if nothing was selected
    //       if (selectedOption != 'custom') {
    //         selectedOption = 'custom';
    //       }
    //     });
    //   }
    // });

    _fetchFees();
  }

  Future<void> _fetchFees() async {
    // Start loading and hide the custom UI unless/until needed
    if (mounted) {
      setState(() {
        isLoading = true;
        // Only show custom if the user already selected it
        showFallbackCustomFee = (selectedOption == 'custom');
      });
    }

    try {
      final recFees = await walletService.fetchRecommendedFees();

      // Treat null as an error → fall back to custom
      if (recFees == null) {
        throw Exception('No fee data returned');
      }

      if (mounted) {
        setState(() {
          recommendedFees = recFees;
          isLoading = false;

          // If the user had NOT chosen custom, default to halfHourFee.
          if (selectedOption != 'custom') {
            selectedOption = 'halfHourFee';
            // Trigger callback with the default only in the success path
            final v = recFees['halfHourFee'];
            if (v != null) {
              widget.onFeeSelected(v);
            }
            // Hide custom input on success unless user explicitly picks it later
            showFallbackCustomFee = false;
          } else {
            // User had custom selected: keep it; keep custom UI visible
            showFallbackCustomFee = true;
          }
        });
      }
    } catch (e, st) {
      // Log the failure and switch to custom only because the API failed
      debugPrint('Failed to load fees: $e\n$st');

      if (mounted) {
        setState(() {
          isLoading = false;
          selectedOption = 'custom';
          showFallbackCustomFee = true; // show custom UI due to failure
        });

        NotificationHelper.showError(context,
            message: 'Unable to load network fees. Please enter a custom fee.');
      }
    }
  }

  void _onOptionSelected(String key) {
    setState(() {
      selectedOption = key;
    });

    if (key != 'custom') {
      widget.onFeeSelected(recommendedFees![key]);
    }
  }

  void _onCustomFeeChanged(String value) {
    final customValue = double.tryParse(value);
    if (customValue != null) {
      widget.onFeeSelected(customValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rootContext = widget.context;

    if (isLoading && !showFallbackCustomFee) {
      return const Center(child: CircularProgressIndicator());
    }

    if (recommendedFees == null && !showFallbackCustomFee) {
      return const Text("Failed to fetch fee recommendations.");
    }

    final dropdownItems = [
      if (recommendedFees != null) ...[
        DropdownMenuItem(
          value: 'fastestFee',
          child: Text('⚡ ${recommendedFees!['fastestFee']} sat/vB'),
        ),
        DropdownMenuItem(
          value: 'halfHourFee',
          child: Text('🚗 ${recommendedFees!['halfHourFee']} sat/vB'),
        ),
        DropdownMenuItem(
          value: 'hourFee',
          child: Text('🐢 ${recommendedFees!['hourFee']} sat/vB'),
        ),
      ],
      const DropdownMenuItem(
        value: 'custom',
        child: Text('✏️ Custom'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(rootContext)!.translate('select_custom_fee'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.cardTitle(context),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButton<String>(
          value: selectedOption,
          items: dropdownItems,
          onChanged: (value) {
            _onOptionSelected(value!);
          },
          isExpanded: true,
          underline: Container(height: 1, color: AppColors.text(context)),
        ),

        // Show input only if "Custom" is selected
        if (selectedOption == 'custom' || showFallbackCustomFee)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: SizedBox(
              height: 40,
              child: TextFormField(
                controller: customFeeController,
                onChanged: _onCustomFeeChanged,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText:
                      "${AppLocalizations.of(rootContext)!.translate('amount')} (sats/vb)",
                  hintText: AppLocalizations.of(rootContext)!
                      .translate('enter_amount_sats'),
                ),
                style: TextStyle(fontSize: 13, color: AppColors.text(context)),
                keyboardType: TextInputType.number,
              ),
            ),
          ),
      ],
    );
  }
}

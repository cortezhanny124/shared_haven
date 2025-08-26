import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
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
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && recommendedFees == null) {
        setState(() {
          showFallbackCustomFee = true;

          // 💡 Force 'custom' selection if nothing was selected
          if (selectedOption != 'custom') {
            selectedOption = 'custom';
          }
        });
      }
    });

    _fetchFees();
  }

  Future<void> _fetchFees() async {
    final recFees = await walletService.fetchRecommendedFees();
    if (recFees != null) {
      setState(() {
        recommendedFees = recFees;
        selectedOption = 'halfHourFee'; // default
        isLoading = false;
      });

      // Trigger the callback with default
      widget.onFeeSelected(recFees['halfHourFee']);
    } else {
      throw Exception('Failed to load fees');
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
                      "${AppLocalizations.of(rootContext)!.translate('amount')} (sats)",
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

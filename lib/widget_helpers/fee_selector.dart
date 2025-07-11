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

    final options = {
      'fastestFee': '⚡',
      'halfHourFee': '🚗',
      'hourFee': '🐢',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(rootContext)!.translate('select_custom_fee'),
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.cardTitle(context)),
        ),
        const SizedBox(height: 8),

        if (recommendedFees != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: entry.key,
                        groupValue: selectedOption,
                        activeColor: AppColors.background(context),
                        onChanged: (value) => _onOptionSelected(value!),
                      ),
                      Text(
                        '${entry.value} (${recommendedFees![entry.key]} sat/vB)',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        if (recommendedFees != null) const SizedBox(height: 12),

        // Always show the custom fee option
        Row(
          children: [
            Radio<String>(
              value: 'custom',
              groupValue: selectedOption,
              activeColor: AppColors.background(context),
              onChanged: (value) => _onOptionSelected(value!),
            ),
            const Text('✏️ Custom'),
          ],
        ),

        // Show custom field if 'custom' is selected OR fallback is triggered
        if (selectedOption == 'custom' || showFallbackCustomFee)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
              style: TextStyle(
                color: AppColors.text(context),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
      ],
    );
  }
}

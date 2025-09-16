import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/widget_helpers/notification_helper.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final languages = [
      'en',
      'es',
      'it',
      'fr',
      'ru',
    ];

    final currencies = [
      'ARS',
      'AUD',
      'BRL',
      'CAD',
      'CHF',
      'CLP',
      'CNY',
      'CZK',
      'DKK',
      'EUR',
      'GBP',
      'HKD',
      'HRK',
      'HUF',
      'INR',
      'ISK',
      'JPY',
      'KRW',
      'NGN',
      'NZD',
      'PLN',
      'RON',
      'RUB',
      'SEK',
      'SGD',
      'THB',
      'TRY',
      'TWD',
      'USD',
    ];

    return BaseScaffold(
      title: Text(AppLocalizations.of(context)!.translate('settings')),
      showDrawer: false,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header icon or illustration
                  Center(
                    child: SizedBox(
                      height: 150,
                      width: 150,
                      child: Lottie.asset(
                        'assets/animations/bitcoin_splash.json',
                        repeat: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Description
                  Text(
                    AppLocalizations.of(context)!.translate('settings_message'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.text(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Currency Selection
                  Text(
                    AppLocalizations.of(context)!.translate('currency'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardTitle(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: settingsProvider.currency,
                    items: currencies.map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        settingsProvider.setCurrency(value);
                      }
                    },
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: AppColors.background(context)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: AppColors.primary(context)),
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
                    isExpanded: true, // Ensure dropdown spans the full width
                    menuMaxHeight:
                        250, // Limit the dropdown's height to fit 5 items
                  ),

                  const SizedBox(height: 20),

                  // Language Selection
                  Text(
                    AppLocalizations.of(context)!.translate('language'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardTitle(context),
                    ),
                  ),

                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: settingsProvider.languageCode,
                    items: languages.map((language) {
                      return DropdownMenuItem(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        settingsProvider.setLanguage(value);
                      }
                    },
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: AppColors.background(context)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: AppColors.primary(context)),
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
                    isExpanded: true, // Ensure dropdown spans the full width
                    menuMaxHeight:
                        250, // Limit the dropdown's height to fit 5 items
                  ),

                  const SizedBox(height: 40),

                  // Save Button
                  CustomButton(
                    onPressed: () {
                      settingsProvider.resetSettings();

                      NotificationHelper.show(
                        context,
                        message: AppLocalizations.of(context)!
                            .translate('reset_settings_scaffold'),
                      );
                    },
                    backgroundColor: AppColors.background(context),
                    foregroundColor: AppColors.text(context),
                    icon: Icons.restart_alt,
                    iconColor: AppColors.gradient(context),
                    label: AppLocalizations.of(context)!
                        .translate('reset_settings'),
                    padding: 10.0,
                    iconSize: 28.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

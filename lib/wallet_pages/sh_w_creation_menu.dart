import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class ShWCreationMenu extends StatefulWidget {
  const ShWCreationMenu({super.key});

  @override
  ShWCreationMenuState createState() => ShWCreationMenuState();
}

class ShWCreationMenuState extends State<ShWCreationMenu> {
  final GlobalKey<BaseScaffoldState> baseScaffoldKey =
      GlobalKey<BaseScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      key: baseScaffoldKey,
      title: Text(
        AppLocalizations.of(context)!.translate('shared_wallet'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Add a header icon or illustration
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
          // Add a description
          Text(
            AppLocalizations.of(context)!.translate('create_import_message'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.text(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onLongPress: () {
              final BaseScaffoldState? baseScaffoldState =
                  baseScaffoldKey.currentState;

              if (baseScaffoldState != null) {
                baseScaffoldState.updateAssistantMessage(
                    context, 'assistant_create_shared');
              }
            },
            child: CustomButton(
              onPressed: () {
                Navigator.pushNamed(context, '/create_shared_wallet');
              },
              backgroundColor: AppColors.background(context),
              foregroundColor: AppColors.gradient(context),
              icon: Icons.add_circle,
              iconColor: AppColors.text(context),
              label: AppLocalizations.of(context)!
                  .translate('create_shared_wallet'),
              padding: 16.0,
              iconSize: 28.0,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onLongPress: () {
              final BaseScaffoldState? baseScaffoldState =
                  baseScaffoldKey.currentState;

              if (baseScaffoldState != null) {
                baseScaffoldState.updateAssistantMessage(
                    context, 'assistant_import_shared');
              }
            },
            child: CustomButton(
              onPressed: () {
                Navigator.pushNamed(context, '/import_shared');
              },
              backgroundColor: AppColors.background(context),
              foregroundColor: AppColors.text(context),
              icon: Icons.download,
              iconColor: AppColors.gradient(context),
              label: AppLocalizations.of(context)!.translate('import_wallet'),
              padding: 16.0,
              iconSize: 28.0,
            ),
          ),
        ],
      ),
    );
  }
}

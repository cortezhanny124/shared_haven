import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:hive/hive.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class PinVerificationPage extends StatefulWidget {
  const PinVerificationPage({super.key});

  @override
  PinVerificationPageState createState() => PinVerificationPageState();
}

class PinVerificationPageState extends State<PinVerificationPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _status = '';

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _verifyPin() async {
    var walletBox = Hive.box('walletBox');
    String? savedPin = walletBox.get('userPin');

    if (savedPin == _pinController.text) {
      setState(() {
        _status = 'PIN verified successfully.';
      });

      // Play the unlock animation
      _animationController.reset();
      _animationController.forward();

      // Navigate to wallet page after a delay
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.popAndPushNamed(context, '/wallet_page', arguments: true);
      });
    } else {
      setState(() {
        _status = 'Incorrect PIN. Try again.';
      });
    }
  }

  Widget _buildStatusBanner() {
    String statusText;

    if (_status.isEmpty) return const SizedBox.shrink();

    if (_status.contains('Incorrect')) {
      statusText = AppLocalizations.of(context)!.translate('pin_incorrect');
    } else {
      statusText = AppLocalizations.of(context)!.translate('pin_verified');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _status.contains('success')
            ? AppColors.background(context)
            : AppColors.error(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAnimation() {
    return Lottie.asset(
      'assets/animations/lock_unlock.json', // Replace with your Lottie file path
      controller: _animationController,
      repeat: false,
      onLoaded: (composition) {
        _animationController.duration = composition.duration;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(AppLocalizations.of(context)!.translate('verify_pin')),
      showDrawer: false,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Lock Animation
              Center(
                child: SizedBox(
                  height: 150,
                  child: _buildAnimation(),
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
                style: TextStyle(
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 20),
              // Verify PIN Button
              CustomButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _verifyPin();
                  }
                },
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                icon: Icons.check_circle,
                iconColor: Colors.white,
                label: AppLocalizations.of(context)!.translate('verify_pin'),
                padding: 16.0,
                iconSize: 28.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

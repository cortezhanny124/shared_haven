import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/security_pages/pin_setup_page.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class DisclaimerPage extends StatefulWidget {
  const DisclaimerPage({super.key});

  @override
  State<DisclaimerPage> createState() => _DisclaimerPageState();
}

class _DisclaimerPageState extends State<DisclaimerPage> {
  bool _accepted = false;
  String _status = '';

  // --- Bitcoin palette ---
  static const Color _btcOrange = Color(0xFFF7931A);
  static const Color _btcOrangeLight = Color(0xFFF9A93F);
  static const Color _btcCharcoal = Color(0xFF0E0E0E);

  String get _legalText => '''
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
This disclaimer was amended for the last time on October 1st, 2025 
''';

  Future<void> _showLegalDisclaimer() async {
    final scrollController = ScrollController();
    bool isAtBottom = false;

    final agreed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // for rounded corners+shadow
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Listen once
            scrollController.addListener(() {
              final reachedBottom =
                  scrollController.position.extentAfter == 0; // robust check
              if (reachedBottom != isAtBottom) {
                setSheetState(() => isAtBottom = reachedBottom);
              }
            });

            return SafeArea(
              top: false,
              child: Container(
                // Card-like bottom sheet with BTC styling
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1A1A1A),
                      Color(0xFF2B1A00),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10 + 6, // handle + spacing
                  bottom: 16 + MediaQuery.of(ctx).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grab handle
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.opaque(0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.currency_bitcoin, color: Color(0xFFF7931A)),
                        SizedBox(width: 8),
                        Text(
                          'Legal Disclaimer',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Scrollable content
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        // about 70% height sheet; grows on small screens
                        maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212).opaque(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x33F7931A)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Text(
                            _legalText,
                            style: TextStyle(
                              color: AppColors.gradient(context),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFF7931A)),
                              foregroundColor: const Color(0xFFF7931A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isAtBottom
                                ? () => Navigator.pop(ctx, true)
                                : () {
                                    // nudge user to bottom
                                    scrollController.animateTo(
                                      scrollController.position.maxScrollExtent,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF7931A),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: isAtBottom ? 6 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isAtBottom ? 'Agree' : 'Scroll to Continue',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // If agreed, check the checkbox in the parent state
    if (agreed == true && mounted) {
      setState(() => _accepted = true);
    }
  }

  void _continue() {
    if (!_accepted) {
      setState(() {
        _status =
            'Please accept the Terms of Service & Privacy Policy before proceeding';
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PinSetupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textOnGradient = Colors.white.opaque(0.95);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _btcCharcoal, // deep base
              Color(0xFF2B1A00), // dark orange tint
              _btcOrange, // BTC highlight near bottom
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ---------- TOP GROUP ----------
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo with subtle orange glow
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _btcOrange.opaque(0.35),
                                  blurRadius: 50,
                                  spreadRadius: 18,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icon/shared_haven_icon.png',
                              height: 320,
                              width: 320,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Headers with BTC coloring
                        Text(
                          'Shared Haven',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _btcOrange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bitcoin Wallet\nwith secure \nmultisig features',
                          style: TextStyle(
                            fontSize: 40,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            color: textOnGradient,
                            shadows: [
                              Shadow(
                                color: Colors.black.opaque(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ---------- BOTTOM GROUP ----------
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Checkbox + RichText links
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _accepted,
                                  onChanged: (v) =>
                                      setState(() => _accepted = v ?? false),
                                  shape: const CircleBorder(),
                                  side: const BorderSide(color: _btcOrange),
                                  activeColor: _btcOrange,
                                  checkColor: Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: textOnGradient,
                                        fontSize: 15,
                                        height: 1.35,
                                      ),
                                      children: [
                                        const TextSpan(
                                            text:
                                                'I have read and agreed to the '),
                                        TextSpan(
                                          text: 'Terms of Service',
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            color: _btcOrangeLight,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap =
                                                () => _showLegalDisclaimer(),
                                        ),
                                        const TextSpan(text: ' & '),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            color: _btcOrangeLight,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap =
                                                () => _showLegalDisclaimer(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _continue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _btcOrange,
                              foregroundColor: Colors.black,
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _status.isEmpty
                              ? const SizedBox.shrink()
                              : Container(
                                  key: const ValueKey('errorBanner'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB00020),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

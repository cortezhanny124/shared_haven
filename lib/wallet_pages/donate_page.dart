import 'dart:math';

import 'package:bdk_dart/bdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:provider/provider.dart';

class DonatePage extends StatefulWidget {
  const DonatePage({super.key});

  @override
  State<DonatePage> createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _innerRotateController;
  late AnimationController _outerRotateController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _innerRotateAnimation;
  late Animation<double> _outerRotateAnimation;

  late WalletService walletService;
  late SettingsProvider settingsProvider;

  String btcAddress = "";
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();

    settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    walletService = WalletService(settingsProvider);
    btcAddress = walletService.generateDonationAddress();

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotation animation for outer ring
    _innerRotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _outerRotateController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    _innerRotateAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _innerRotateController, curve: Curves.linear),
    );

    _outerRotateAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _outerRotateController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _innerRotateController.dispose();
    _outerRotateController.dispose();

    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _isCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isCopied = false);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
          'Address copied to clipboard',
          style: TextStyle(color: AppColors.gradient(context)),
        ),
        backgroundColor: AppColors.background(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.icon(context)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBitcoin = settingsProvider.network == Network.bitcoin;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.icon(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
              'Support Development',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.icon(context).opaque(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                textScaler: TextScaler.linear(
                  ScaleSize.textScaleFactor(context),
                ),
                isBitcoin ? 'BITCOIN' : 'TESTNET',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: AppColors.icon(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: AppColors.gradient(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.icon(context)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.icon(context).opaque(0.2),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.gradient(context),
              AppColors.background(context),
            ],
            stops: const [0.0, 0.6],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                // Animated Logo Section with decorative rings and orbiting dots
                SizedBox(
                  height: 220, // Fixed height
                  width: 220, // Fixed width
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer rotating ring
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.icon(context).opaque(0.3),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.icon(context).opaque(0.2),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Orbiting dots outer layer
                      AnimatedBuilder(
                        animation: _outerRotateAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: List.generate(16, (index) {
                              // Calculate position with rotation applied to each dot's position
                              final baseAngle = (index * 30) * pi / 180;
                              final rotatedAngle =
                                  baseAngle + _outerRotateAnimation.value;
                              final radius = 100.0;

                              return Positioned(
                                left: 100 + radius * cos(rotatedAngle) + 7,
                                top: 100 + radius * sin(rotatedAngle) + 7,
                                child: Container(
                                  width: index.isEven ? 6 : 8,
                                  height: index.isEven ? 6 : 8,
                                  decoration: BoxDecoration(
                                    color: index.isEven
                                        ? AppColors.icon(context).opaque(0.6)
                                        : AppColors.icon(context),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.icon(
                                          context,
                                        ).opaque(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      // Orbiting dots inner layer
                      AnimatedBuilder(
                        animation: _innerRotateAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: List.generate(8, (index) {
                              // Calculate position with rotation applied to each dot's position
                              final baseAngle = (index * 45) * pi / 180;
                              final rotatedAngle =
                                  baseAngle + _innerRotateAnimation.value;
                              final radius = 85.0;

                              return Positioned(
                                left: 100 + radius * cos(rotatedAngle) + 7,
                                top: 100 + radius * sin(rotatedAngle) + 7,
                                child: Container(
                                  width: index.isEven ? 8 : 6,
                                  height: index.isEven ? 8 : 6,
                                  decoration: BoxDecoration(
                                    color: index.isEven
                                        ? AppColors.icon(context)
                                        : AppColors.icon(context).opaque(0.6),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.icon(
                                          context,
                                        ).opaque(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      // Pulsing logo
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.background(context),
                                    AppColors.icon(context),
                                  ],
                                  stops: const [0.3, 0.9],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.icon(context).opaque(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.currency_bitcoin,
                                size: 65,
                                color: AppColors.gradient(context),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Header with decorative elements
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gradient(context).opaque(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.text(context)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        textScaler: TextScaler.linear(
                          ScaleSize.textScaleFactor(context),
                        ),
                        isBitcoin
                            ? 'Make a Donation'
                            : 'Make a Testnet Donation',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.icon(context),
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 40,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.transaparent(),
                                  AppColors.icon(context),
                                  AppColors.transaparent(),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Support text with container
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gradient(context).opaque(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.text(context)),
                  ),
                  child: Text(
                    textScaler: TextScaler.linear(
                      ScaleSize.textScaleFactor(context),
                    ),
                    'Support the Bitcoin ecosystem with a direct on-chain donation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text(context).opaque(0.8),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Main Address Card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.icon(context).opaque(0.2),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.gradient(context),
                        border: Border.all(
                          color: AppColors.icon(context).opaque(0.2),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Card Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.icon(context).opaque(0.1),
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.text(context),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppColors.icon(context),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  textScaler: TextScaler.linear(
                                    ScaleSize.textScaleFactor(context),
                                  ),
                                  'Donation Address',
                                  style: TextStyle(
                                    color: AppColors.text(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.icon(context).opaque(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    textScaler: TextScaler.linear(
                                      ScaleSize.textScaleFactor(context),
                                    ),
                                    isBitcoin ? 'BTC' : 'tBTC',
                                    style: TextStyle(
                                      color: AppColors.icon(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Address Content
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Address Display
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.background(
                                      context,
                                    ).opaque(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.text(context),
                                    ),
                                  ),
                                  child: SelectableText(
                                    btcAddress,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      color: AppColors.text(context),
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Copy Button
                                GestureDetector(
                                  onTap: () => _copyToClipboard(btcAddress),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.icon(context),
                                          AppColors.lightSecondary(context),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.icon(
                                            context,
                                          ).opaque(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isCopied ? Icons.check : Icons.copy,
                                          color: AppColors.gradient(context),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          textScaler: TextScaler.linear(
                                            ScaleSize.textScaleFactor(context),
                                          ),
                                          _isCopied
                                              ? 'Copied!'
                                              : 'Copy Address',
                                          style: TextStyle(
                                            color: AppColors.gradient(context),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer with hearts
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left heart
                      Icon(
                        Icons.favorite,
                        color: AppColors.icon(context).opaque(0.6),
                        size: 14,
                      ),

                      const SizedBox(width: 8),

                      // Text
                      Text(
                        textScaler: TextScaler.linear(
                          ScaleSize.textScaleFactor(context),
                        ),
                        'Thank you for your support',
                        style: TextStyle(
                          color: AppColors.text(context).opaque(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Right heart
                      Icon(
                        Icons.favorite,
                        color: AppColors.icon(context).opaque(0.6),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DashedCirclePainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Calculate the circumference
    final circumference = 2 * 3.14159 * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashWidth + dashSpace) / radius);
      final endAngle = startAngle + (dashWidth / radius);

      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

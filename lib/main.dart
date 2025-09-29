import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/loading_screens/splash_screen.dart';
import 'package:flutter_wallet/wallet_pages/ca_wallet_page.dart';
import 'package:flutter_wallet/wallet_pages/create_shared_wallet.dart';
import 'package:flutter_wallet/wallet_pages/import_shared_wallet.dart';
import 'package:flutter_wallet/security_pages/pin_setup_page.dart';
import 'package:flutter_wallet/security_pages/pin_verification_page.dart';
import 'package:flutter_wallet/settings/settings_page.dart';
import 'package:flutter_wallet/wallet_pages/sh_w_creation_menu.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/wallet_pages/wallet_page.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';

void main() async {
  // Ensure all Flutter bindings are initialized before running Hive
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter(); // Initialize Hive

  // Register the generated Hive adapter for WalletData
  Hive.registerAdapter(WalletDataAdapter());

  // Retrieve or generate encryption key
  final encryptionKey = await _getEncryptionKey();

  // Open the encrypted boxes
  await Hive.openBox(
    'walletBox',
    encryptionCipher: HiveAesCipher(Uint8List.fromList(encryptionKey)),
  );

  await Hive.openBox(
    'descriptorBox',
    encryptionCipher: HiveAesCipher(Uint8List.fromList(encryptionKey)),
  );

  await Hive.openBox<WalletData>(
    'walletDataBox',
    encryptionCipher: HiveAesCipher(Uint8List.fromList(encryptionKey)),
  );

  await Hive.openBox(
    'settingsBox',
    encryptionCipher: HiveAesCipher(Uint8List.fromList(encryptionKey)),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(
          create: (context) => WalletService(
            Provider.of<SettingsProvider>(context, listen: false),
          ),
        ),
      ],
      child: OverlaySupport.global(
        child: const MyAppWrapper(),
      ),
    ),
  );
}

// FlutterSecureStorage for encryption key management
final secureStorage = FlutterSecureStorage();

// 🔹 Secure storage for encryption key management
Future<List<int>> _getEncryptionKey() async {
  String? encodedKey = await secureStorage.read(key: 'encryptionKey');

  if (encodedKey != null) {
    return base64Url.decode(encodedKey);
  } else {
    var key = Hive.generateSecureKey();
    await secureStorage.write(
        key: 'encryptionKey', value: base64UrlEncode(key));
    return key;
  }
}

// 🔹 Wrapper to Ensure SettingsProvider Loads Before UI

class MyAppWrapper extends StatefulWidget {
  const MyAppWrapper({super.key});

  @override
  State<MyAppWrapper> createState() => MyAppWrapperState();
}

class MyAppWrapperState extends State<MyAppWrapper> {
  bool _isSettingsLoaded = false;
  bool _isSplashDone = false;

  @override
  void initState() {
    super.initState();
    _startSplashScreenTimer();
    _loadSettings();
  }

  // ⏳ Ensures SplashScreen is shown for at least 3 seconds
  void _startSplashScreenTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isSplashDone = true;
      });
    });
  }

  // 🔄 Loads settings asynchronously
  Future<void> _loadSettings() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    await settingsProvider.loadSettings();
    setState(() {
      _isSettingsLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: (_isSettingsLoaded && _isSplashDone)
          ? const MyApp() // ✅ Show Main App Only After Splash Duration Ends
          : const SplashScreen(), // ✅ Always Show Splash Screen for 3 Secs
    );
  }
}

// 🔹 Main Application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'Wallet',
      theme: settingsProvider.themeData,
      debugShowCheckedModeBanner: false,
      locale: Locale(settingsProvider.languageCode),
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
        Locale('it', ''),
        Locale('fr', ''),
        Locale('ru', ''),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate, // Custom translation delegate
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute:
          // '/example_nfc',
          _determineInitialRoute(),
      routes: {
        '/wallet_page': (context) => const WalletPage(),
        '/ca_wallet_page': (context) => const CAWalletPage(),
        '/pin_setup_page': (context) => const PinSetupPage(),
        '/pin_verification_page': (context) => const PinVerificationPage(),
        '/shared_wallet': (context) => const ShWCreationMenu(),
        '/create_shared_wallet': (context) => const CreateSharedWallet(),
        '/import_shared': (context) => const ImportSharedWallet(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }

  String _determineInitialRoute() {
    var walletBox = Hive.box('walletBox');

    if (!walletBox.containsKey('userPin')) {
      // If the user hasn't set a PIN yet
      return '/pin_setup_page';
    } else if (walletBox.containsKey('walletMnemonic')) {
      // If the wallet mnemonic exists, navigate to PIN verification
      return '/pin_verification_page';
    } else {
      // If no wallet mnemonic, navigate to wallet creation
      return '/ca_wallet_page';
    }
  }
}

// 🔹 Splash Screen Wrapper to Properly Initialize the App
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  SplashScreenWrapperState createState() => SplashScreenWrapperState();
}

class SplashScreenWrapperState extends State<SplashScreenWrapper> {
  @override
  void initState() {
    super.initState();

    // Use addPostFrameCallback to navigate AFTER the build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          // Check if widget is still active before navigating
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MyApp()),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

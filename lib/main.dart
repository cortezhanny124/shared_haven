import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_wallet/wallet_pages/disclaimer_page.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/security_pages/auth_guard.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/loading_screens/splash_screen.dart';
import 'package:flutter_wallet/wallet_pages/create_shared_wallet.dart';
import 'package:flutter_wallet/wallet_pages/create_wallet_page.dart';
import 'package:flutter_wallet/wallet_pages/donate_page.dart';
import 'package:flutter_wallet/wallet_pages/import_shared_wallet.dart';
import 'package:flutter_wallet/security_pages/pin_setup_page.dart';
import 'package:flutter_wallet/security_pages/pin_verification_page.dart';
import 'package:flutter_wallet/settings/settings_page.dart';
import 'package:flutter_wallet/wallet_pages/import_shared_wallet_ro.dart';
import 'package:flutter_wallet/wallet_pages/import_wallet_page.dart';
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
      child: OverlaySupport.global(child: const MyAppWrapper()),
    ),
  );
}

// FlutterSecureStorage for encryption key management
final secureStorage = FlutterSecureStorage();

Future<List<int>> _getEncryptionKey() async {
  String? encodedKey = await secureStorage.read(key: 'encryptionKey');

  if (encodedKey != null) {
    return base64Url.decode(encodedKey);
  } else {
    var key = Hive.generateSecureKey();
    await secureStorage.write(
      key: 'encryptionKey',
      value: base64UrlEncode(key),
    );
    return key;
  }
}

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

  void _startSplashScreenTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isSplashDone = true;
      });
    });
  }

  Future<void> _loadSettings() async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    await settingsProvider.loadSettings();
    setState(() {
      _isSettingsLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen while loading
    if (!_isSettingsLoaded || !_isSplashDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      );
    }

    return const MyApp();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AuthGuard.saveLastActiveTimestamp();
    } else if (state == AppLifecycleState.resumed) {
      // Use the navigation service with the global key
      AuthGuard.checkAuthenticationOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
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
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: _determineInitialRoute(),
      routes: {
        '/wallet_page': (context) => const WalletPage(),
        '/pin_setup_page': (context) => const PinSetupPage(),
        '/pin_verification_page': (context) => const PinVerificationPage(),
        '/shared_wallet': (context) => const ShWCreationMenu(),
        '/create_shared_wallet': (context) => const CreateSharedWallet(),
        '/import_shared': (context) => const ImportSharedWallet(),
        '/import_shared_ro': (context) => const ImportSharedWalletRo(),
        '/settings': (context) => const SettingsPage(),
        '/disclaimer': (context) => const DisclaimerPage(),
        '/import_wallet': (context) => const ImportWalletPage(),
        '/create_wallet': (context) => const CreateWalletPage(),
        '/donate_page': (context) => const DonatePage(),
      },
    );
  }

  String _determineInitialRoute() {
    var walletBox = Hive.box('walletBox');

    if (!walletBox.containsKey('userPin')) {
      return '/disclaimer';
    } else if (walletBox.containsKey('walletMnemonic')) {
      return '/pin_verification_page';
    } else {
      return '/create_wallet';
    }
  }
}

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

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> navigateToPinVerification() async {
    // Check current route
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      return;
    }

    final context = navigatorState.context;
    final currentRoute = ModalRoute.of(context);
    final currentRouteName = currentRoute?.settings.name;

    if (currentRouteName != '/pin_verification_page') {
      navigatorState.pushReplacementNamed('/pin_verification_page');
    }
  }

  // Helper to check if we're on PIN page
  static bool get isOnPinPage {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final route = ModalRoute.of(context);
    return route?.settings.name == '/pin_verification_page';
  }
}

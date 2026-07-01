import 'dart:async';
import 'package:bdk_dart/bdk.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_buttons_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_ui_helpers.dart';
import 'package:flutter_wallet/widget_helpers/custom_bottom_sheet.dart';
import 'package:flutter_wallet/widget_helpers/notification_helper.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  WalletPageState createState() => WalletPageState();
}

class WalletPageState extends State<WalletPage> {
  // Services and Providers
  late WalletService walletService;
  late Wallet wallet;
  late WalletData? _walletData;
  final WalletStorageService _walletStorageService = WalletStorageService();
  late SettingsProvider settingsProvider;

  // Controllers
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _pubKeyController = TextEditingController();

  // UI Elements and State Management
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool showInSatoshis = true; // Toggle display state
  bool _isLoading = true;
  bool isInitialized = false;
  bool isWalletInitialized = false;
  bool _isRefreshing = false;
  bool _isSyncing = false;

  // Wallet and Transaction Data
  String address = '';
  String myPubKey = '';
  String myMnemonic = '';
  int balance = 0;
  int ledBalance = 0;
  int avBalance = 0;
  List<Map<String, dynamic>> _transactions = [];
  Set<String> myAddresses = {};

  // Currency and Ledger Balances
  double ledCurrencyBalance = 0.0;
  double avCurrencyBalance = 0.0;

  // Blockchain Data
  int _currentHeight = 0;
  String _timeStamp = "";

  // Timer and Refresh Logic
  DateTime? _lastRefreshed;

  // Storage
  var walletBox = Hive.box('walletBox');

  @override
  void initState() {
    super.initState();

    setState(() {
      _isLoading = true;
    });

    // Initialize WalletService
    settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    walletService = WalletService(settingsProvider);

    // Load wallet data and fetch the block height only once when the widget is initialized
    _loadWalletFromHive().then((_) {
      _initializePage();
    });
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Helper method to extract wallet policies and spending paths
  Future<void> _initializePage() async {
    try {
      String savedMnemonic = walletBox.get('walletMnemonic');

      // Convert mnemonic to object
      Mnemonic trueMnemonic = Mnemonic.fromString(mnemonic: savedMnemonic);

      // Define derivation paths
      DerivationPath hardenedDerivationPath;

      if (settingsProvider.network == Network.bitcoin) {
        hardenedDerivationPath = DerivationPath(path: "m/84h/0h/0h");
      } else {
        hardenedDerivationPath = DerivationPath(path: "m/84h/1h/0h");
      }
      final receivingDerivationPath = DerivationPath(path: "m/0");

      // Derive descriptor keys
      final (receivingSecretKey, receivingPublicKey) = walletService
          .deriveDescriptorKeys(
            hardenedDerivationPath,
            receivingDerivationPath,
            trueMnemonic,
          );

      _convertCurrency();

      // Extract spending paths
      setState(() {
        myMnemonic = savedMnemonic;
        myPubKey = receivingPublicKey.toString();
        _pubKeyController.text = myPubKey;

        isInitialized = true; // Mark as loaded
      });
    } catch (e) {
      throw ("Error initializing spending paths: $e");
    }
  }

  Future<void> _loadWalletFromHive() async {
    // Restore wallet from the saved mnemonic
    wallet = await walletService.loadSavedWallet();

    final List<AddressInfo> addressList = wallet.revealAddressesTo(
      keychain: KeychainKind.external_,
      index: 100,
    );

    myAddresses.addAll(addressList.map((ai) => ai.address.toString()));

    setState(() {
      isWalletInitialized = true;
    });

    await _loadWalletData();

    setState(() {
      _isLoading = false; // Mark loading as complete
    });
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _lastRefreshed = DateTime.now();
    });

    String walletId = wallet
        .peekAddress(keychain: KeychainKind.external_, index: 0)
        .address
        .toString();

    _walletData = await _walletStorageService.loadWalletData(walletId);

    if (_walletData != null) {
      // If offline data is available, use it to update the UI
      setState(() {
        address = _walletData!.address;
        ledBalance = _walletData!.ledgerBalance;
        avBalance = _walletData!.availableBalance;
        _transactions = _walletData!.transactions;
        _currentHeight = _walletData!.currentHeight;
        _timeStamp = _walletData!.timeStamp;
        _lastRefreshed = _walletData!.lastRefreshed;
        myAddresses = _walletData!.myAddresses!;

        _isLoading = false;
      });
    } else {
      await _checkInternetAndSync();
    }
  }

  Future<void> _checkInternetAndSync() async {
    final List<ConnectivityResult> connectivityResult = await (Connectivity()
        .checkConnectivity());

    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showNetworkDialog();
    } else {
      _syncWallet();
    }
  }

  void _showNetworkDialog() {
    final rootContext = context;

    CustomBottomSheet.buildCustomBottomSheet(
      context: context,
      titleKey: 'no_connection',
      content: Text(
        textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
        AppLocalizations.of(rootContext)!.translate('connect_internet'),
        style: TextStyle(color: AppColors.text(context)),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            _checkInternetAndSync();
          },
          child: Text(
            textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
            AppLocalizations.of(rootContext)!.translate('retry'),
            style: TextStyle(color: AppColors.text(context)),
          ),
        ),
      ],
    );
  }

  bool isAddressinTransaction(Map<String, dynamic> tx, String address) {
    return (tx['vin'] as List).any((vin) {
          final prevout = vin['prevout'];
          return prevout != null && prevout['scriptpubkey_address'] == address;
        }) ||
        (tx['vout'] as List).any(
          (vout) => vout['scriptpubkey_address'] == address,
        );
  }

  Future<void> _syncWallet() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;

    try {
      final w = wallet;
      final syncStart = DateTime.now();

      await walletService.syncWallet(w);

      final currentHeight = await walletService.fetchCurrentBlockHeight();

      final blockTimestamp = await walletService.fetchBlockTimestamp(
        currentHeight,
      );

      String nextAddress = w
          .listUnusedAddresses(keychain: KeychainKind.external_)
          .first
          .address
          .toString();

      final balance = await walletService.getBitcoinBalance(nextAddress);

      List<Map<String, dynamic>> transactions = await walletService
          .getTransactions();

      transactions = walletService.sortTransactionsByConfirmations(
        transactions,
        currentHeight,
      );

      if (!myAddresses.contains(address)) {
        myAddresses.add(address);
      }

      if (!mounted) {
        return;
      }

      _convertCurrency();

      setState(() {
        _currentHeight = currentHeight;
        _timeStamp = blockTimestamp;
        address = nextAddress;
        avBalance = balance['confirmedBalance'] ?? 0;
        ledBalance = balance['pendingBalance'] ?? 0;
        _transactions = transactions;
        _lastRefreshed = syncStart;
        _isSyncing = false;
      });

      await walletService.saveLocalData(
        wallet: w,
        address: nextAddress,
        currentHeight: currentHeight,
        timestamp: blockTimestamp,
        availableBalance: balance['confirmedBalance'] ?? 0,
        ledgerBalance: balance['pendingBalance'] ?? 0,
        transactions: transactions,
        lastRefreshed: syncStart,
        myAddresses: myAddresses,
      );
    } catch (e) {
      setState(() => _isSyncing = false);
      throw Exception("Sync Error: $e");
    }
  }

  void _convertCurrency() async {
    final currencyLedUsd = await walletService.convertSatoshisToCurrency(
      ledBalance,
      settingsProvider.currency,
    );
    final currencyAvUsd = await walletService.convertSatoshisToCurrency(
      avBalance,
      settingsProvider.currency,
    );

    setState(() {
      ledCurrencyBalance = currencyLedUsd;
      avCurrencyBalance = currencyAvUsd;
      showInSatoshis = !showInSatoshis;
    });
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<BaseScaffoldState> baseScaffoldKey =
        GlobalKey<BaseScaffoldState>();

    if (!isWalletInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCircle(color: Colors.blue, size: 50.0),
              SizedBox(height: 20),
              Text(
                textScaler: TextScaler.linear(
                  ScaleSize.textScaleFactor(context),
                ),
                AppLocalizations.of(context)!.translate('setting_wallet'),
              ),
            ],
          ),
        ),
      );
    }

    final walletUiHelpers = WalletUiHelpers(
      address: address,
      avBalance: avBalance,
      ledBalance: ledBalance,
      showInSatoshis: showInSatoshis,
      avCurrencyBalance: avCurrencyBalance,
      ledCurrencyBalance: ledCurrencyBalance,
      currentHeight: _currentHeight,
      timeStamp: _timeStamp,
      isInitialized: isInitialized,
      pubKeyController: _pubKeyController,
      settingsProvider: settingsProvider,
      lastRefreshed: _lastRefreshed,
      context: context,
      isLoading: _isLoading,
      transactions: _transactions,
      wallet: wallet,
      isSingleWallet: true,
      baseScaffoldKey: baseScaffoldKey,
      isRefreshing: _isRefreshing,
      myAddresses: myAddresses,
    );

    final walletButtonsHelper = WalletButtonsHelper(
      context: context,
      address: address,
      mnemonic: myMnemonic,
      isSingleWallet: true,
      recipientController: _recipientController,
      amountController: _amountController,
      walletService: walletService,
      currentHeight: _currentHeight,
      mounted: mounted,
      wallet: wallet,
      baseScaffoldKey: baseScaffoldKey,
      avBalance: avBalance,
      myAddresses: myAddresses,
      onNewAddressGenerated: (newAddr) {
        setState(() {
          address = newAddr;
        });
      },
      syncWallet: _syncWallet,
    );

    return BaseScaffold(
      title: Text(
        textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
        AppLocalizations.of(context)!.translate('personal_wallet'),
      ),
      key: baseScaffoldKey,
      body: Stack(
        children: [
          RefreshIndicator(
            key:
                _refreshIndicatorKey, // Assign the GlobalKey to RefreshIndicator
            onRefresh: () async {
              final List<ConnectivityResult> connectivityResult =
                  await (Connectivity().checkConnectivity());

              setState(() {
                _isRefreshing = true;
              });

              try {
                await walletUiHelpers.handleRefresh(
                  _syncWallet,
                  connectivityResult,
                  context,
                  getCurrentHeight: () => _currentHeight,
                  getTransactions: () => _transactions,
                );
              } catch (e) {
                NotificationHelper.showError(context, message: 'syncing_error');
              } finally {
                // Ensure animation is visible for at least 500ms
                await Future.delayed(Duration(milliseconds: 500));

                setState(() {
                  _isRefreshing = false;
                });
              }
            },
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(2.0),
                    children: [
                      GestureDetector(
                        onLongPress: () {
                          final BaseScaffoldState? baseScaffoldState =
                              baseScaffoldKey.currentState;

                          if (baseScaffoldState != null) {
                            baseScaffoldState.updateAssistantMessage(
                              context,
                              'assistant_personal_info_box',
                            );
                          }
                        },
                        child: walletUiHelpers.buildWalletInfoBox(
                          AppLocalizations.of(context)!.translate('info_box'),
                          onTap: () {
                            _convertCurrency();
                          },
                          showCopyButton: true,
                        ),
                      ),
                      GestureDetector(
                        onLongPress: () {
                          final BaseScaffoldState? baseScaffoldState =
                              baseScaffoldKey.currentState;

                          if (baseScaffoldState != null) {
                            baseScaffoldState.updateAssistantMessage(
                              context,
                              'assistant_personal_transactions_box',
                            );
                          }
                        },
                        child: walletUiHelpers.buildTransactionsBoxTest(),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Column(
                      children: [walletButtonsHelper.buildButtons()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

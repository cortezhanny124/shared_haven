import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:bdk_dart/bdk.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_buttons_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_spending_path_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_ui_helpers.dart';
import 'package:flutter_wallet/widget_helpers/custom_bottom_sheet.dart';
import 'package:flutter_wallet/widget_helpers/notification_helper.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

/// SharedWallet Page
///
/// This class represents a shared Bitcoin wallet page where users can:
/// - View wallet details such as address, balance, and transactions.
/// - Create and sign multi-signature transactions.
/// - Explore spending paths and check available UTXOs.
///
/// ### Features and Functionalities:
///
/// #### Wallet Initialization
/// - **`openBoxAndCheckWallet`**: Opens the Hive box and checks if the wallet already exists.
/// - **`createWalletFromDescriptor`**: Creates a wallet from a given descriptor and saves it locally.
/// - **`loadWallet`**: Loads an existing wallet and syncs it with the blockchain.
///
/// #### Wallet Sync and Data Management
/// - **`_syncWallet`**: Synchronizes the wallet with the blockchain, fetching balances and transactions.
/// - **`_fetchCurrentBlockHeight`**: Retrieves the current blockchain height for transaction management.
///
/// #### Transaction Management
/// - **`_sendTx`**: Handles transaction creation and signing, including multi-signature paths and time-locked transactions.
/// - **`_sortTransactionsByConfirmations`**: Sorts transactions by block confirmation time.
///
/// #### User Interaction and Dialogs
/// - **`_showPinDialog`**: Prompts the user to enter their PIN for accessing private data.
/// - **`_showPathsDialog`**: Displays all available spending paths, including multi-signature and time-locked options.
/// - **`_showTransactionsDialog`**: Displays detailed information about a specific transaction.
///
/// #### Utilities
/// - **`verifyPin`**: Verifies the entered PIN and displays the user's private data (e.g., mnemonic and descriptor).
/// - **`_buildInfoBox`**: Creates reusable UI elements for displaying wallet details.
/// - **`_buildTransactionsBox`**: Builds a scrollable view of the wallet's transactions.
/// - **`_buildTransactionItem`**: Formats and displays individual transaction items.
///
/// ### Widgets
/// - **`BaseScaffold`**: Provides a consistent layout with a gradient background and navigation bar.
/// - **`CustomButton`**: Styled button used throughout the app for actions like sending, receiving, and viewing data.
/// - **`InkwellButton`**: Alternative button style for dialog actions.
///
/// ### Interaction Flow
/// 1. **Initialization**:
///    - The page initializes by checking if the wallet exists and syncing it with the blockchain.
///    - If the wallet doesn't exist, it is created using the provided descriptor and mnemonic.
/// 2. **Display Wallet Details**:
///    - The UI displays wallet details such as the address, balance, and transactions.
/// 3. **Transaction Management**:
///    - Users can create transactions, explore spending paths, and sign multi-signature transactions.
/// 4. **Spending Paths**:
///    - Users can view all available paths for spending UTXOs, including conditions like time-locks and multi-signature thresholds.
/// 5. **Receive and Send Bitcoin**:
///    - Users can receive and send Bitcoin by specifying an address and amount.
///
/// ### Notes:
/// - The class heavily relies on the `bdk_flutter` library for Bitcoin wallet functionalities.
/// - Hive is used for local data storage, ensuring offline availability.
/// - Connectivity checks are performed to handle both online and offline use cases.
///
/// ### Dependencies:
/// - `bdk_flutter`: For wallet management and transaction creation.
/// - `hive_flutter`: For local data storage.
/// - `connectivity_plus`: To check the network connectivity status.
/// - `flutter_secure_storage`: For securely storing sensitive user data.
///
/// ### UI Highlights:
/// - A clean, consistent design with rounded cards and a gradient background.
/// - Dynamic updates to the UI based on wallet data and user interactions.
/// - Accessibility features such as copy-to-clipboard functionality and scrollable transaction lists.

class SharedWallet extends StatefulWidget {
  final String descriptor;
  final String? mnemonic;
  final List<Map<String, String>> pubKeysAlias;
  final String? descriptorName;

  const SharedWallet({
    super.key,
    required this.descriptor,
    this.mnemonic,
    required this.pubKeysAlias,
    this.descriptorName,
  });

  @override
  SharedWalletState createState() => SharedWalletState();
}

class SharedWalletState extends State<SharedWallet> {
  // Services and Providers
  late WalletService walletService;
  late Wallet wallet;
  late WalletData? _walletData;
  late SettingsProvider settingsProvider;
  final WalletStorageService _walletStorageService = WalletStorageService();

  // Controllers
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _psbtController = TextEditingController();
  final TextEditingController _signingAmountController =
      TextEditingController();
  final TextEditingController _pubKeyController = TextEditingController();

  // UI Elements and State Management
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool _isLoading = true;
  bool isInitialized = false;
  bool isWalletInitialized = false;
  bool showInSatoshis = true; // Toggle display state
  bool _isRefreshing = false;
  bool _isSyncing = false;

  // Wallet and Transaction Data
  String address = '';
  String? _descriptor = 'Descriptor here';
  String _descriptorName = '';
  String myFingerPrint = '';
  String myAlias = '';
  late String myPubKey;

  // Balances
  int ledBalance = 0;
  int avBalance = 0;
  double ledCurrencyBalance = 0.0;
  double avCurrencyBalance = 0.0;

  // Blockchain Data
  int _currentHeight = 0;
  String _timeStamp = "";

  // Storage
  late Box<dynamic> descriptorBox;

  // Transaction and Policy Data
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> spendingPaths = [];
  List<Map<String, dynamic>> mySpendingPaths = [];
  List<String> signersList = [];
  List<dynamic> utxos = [];
  Map<String, dynamic> policy = {};
  Set<String> myAddresses = {};
  late Policy externalWalletPolicy;

  // Timer and Refresh Logic
  DateTime? _lastRefreshed;

  @override
  void initState() {
    super.initState();
    settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    walletService = WalletService(settingsProvider);

    openBoxAndCheckWallet().then((_) {
      _initializePage();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// METHODS
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  Future<void> openBoxAndCheckWallet() async {
    // Open the box
    descriptorBox = Hive.box('descriptorBox');

    String? existingDescriptor;

    for (var i = 0; i < descriptorBox.length; i++) {
      final key = descriptorBox.keyAt(i); // Get the key
      final value = descriptorBox.getAt(i); // Get the value

      if (value != null) {
        try {
          // Decode the JSON string into a Map
          Map<String, dynamic> valueMap = jsonDecode(value);

          // Check if the "descriptor" matches
          if (valueMap['descriptor'] == widget.descriptor) {
            setState(() {
              final newName = walletService.generateRandomName();

              _descriptorName = widget.descriptorName!.isNotEmpty
                  ? widget.descriptorName!
                  : newName;
            });

            final newKey = key.replaceFirst(
              RegExp(r'_descriptor_.+'),
              '_descriptor_$_descriptorName',
            );

            final Map<String, dynamic> newValueMap = {
              'descriptor': widget.descriptor,
              'pubKeysAlias': widget.pubKeysAlias,
            };

            final String newValue = jsonEncode(newValueMap);

            // Remove the old record and insert the updated one
            descriptorBox.delete(key); // Remove the old key-value pair

            descriptorBox.put(newKey, newValue); // Add the new key-value pair

            existingDescriptor = valueMap['descriptor'];
            break; // Stop iterating if a match is found
          }
        } catch (e) {
          throw ('Error decoding value for key $key: $e');
        }
      } else {
        throw ('Value for key $key is null.');
      }
    }

    if (existingDescriptor != null) {
      await loadWallet();
    } else {
      await createWalletFromDescriptor();
    }
  }

  Future<void> loadWallet() async {
    try {
      wallet = await walletService.createSharedWallet(widget.descriptor);

      setState(() {
        isWalletInitialized = true;
      });

      setState(() {
        _descriptor = widget.descriptor;
      });

      final List<AddressInfo> addressList = wallet.revealAddressesTo(
        keychain: KeychainKind.external_,
        index: 100,
      );

      myAddresses.addAll(addressList.map((ai) => ai.address.toString()));

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
          utxos = _walletData!.utxos!;
          _lastRefreshed = _walletData!.lastRefreshed;
          myAddresses = _walletData!.myAddresses!;

          _isLoading = false;
        });
      } else {
        await _checkInternetAndSync();
      }
    } catch (e) {
      throw ("Error creating or fetching balance for wallet: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> createWalletFromDescriptor() async {
    try {
      wallet = await walletService.createSharedWallet(widget.descriptor);

      final List<AddressInfo> addressList = wallet.revealAddressesTo(
        keychain: KeychainKind.external_,
        index: 100,
      );

      myAddresses.addAll(addressList.map((ai) => ai.address.toString()));

      setState(() {
        isWalletInitialized = true;
      });

      // Combine descriptor and pubKeysAlias
      final combinedValue = jsonEncode({
        'descriptor': widget.descriptor,
        'pubKeysAlias': widget.pubKeysAlias,
      });

      setState(() {
        final newName = walletService.generateRandomName();

        _descriptorName = widget.descriptorName!.isNotEmpty
            ? widget.descriptorName!
            : newName;
      });

      String compositeKey = "";

      if (widget.mnemonic != null && widget.mnemonic!.isNotEmpty) {
        compositeKey = '${widget.mnemonic}_descriptor_$_descriptorName';
      } else {
        compositeKey = await _generateReadOnlyKey();
      }

      descriptorBox.put(compositeKey, combinedValue);

      // Check internet before syncing
      _checkInternetAndSync();
    } catch (e) {
      throw ("Error creating or fetching balance for wallet: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _generateReadOnlyKey() async {
    final allKeys = descriptorBox.keys.toList();

    final readOnlyNumbers = <int>[];

    for (final key in allKeys) {
      if (key is String && key.startsWith('read_only')) {
        final parts = key.split('_');
        if (parts.length >= 3) {
          try {
            final number = int.parse(parts[2]);
            readOnlyNumbers.add(number);
          } catch (e) {
            throw Exception('Error parsing read-only key number: $e');
          }
        }
      }
    }

    int nextNumber = 1;
    if (readOnlyNumbers.isNotEmpty) {
      readOnlyNumbers.sort();
      nextNumber = readOnlyNumbers.last + 1;
    }

    final readOnlyKey = 'read_only_${nextNumber}_descriptor_$_descriptorName';

    return readOnlyKey;
  }

  /// Helper method to extract wallet policies and spending paths
  Future<void> _initializePage() async {
    try {
      // Initialize variables outside the if block

      if (widget.mnemonic != null && widget.mnemonic!.isNotEmpty) {
        // Extract wallet policies
        externalWalletPolicy = wallet.policies(
          keychain: KeychainKind.external_,
        )!;
        policy = jsonDecode(externalWalletPolicy.asString());

        // Convert mnemonic to object
        Mnemonic trueMnemonic = Mnemonic.fromString(mnemonic: widget.mnemonic!);

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

        // Extract fingerprint from receiving public key
        final RegExp regex = RegExp(r'\[([^\]]+)\]');
        final Match? match = regex.firstMatch(receivingPublicKey.toString());

        if (match != null) {
          myFingerPrint = match.group(1)!.split('/')[0];
          myPubKey = receivingPublicKey.toString();

          // Get spending paths and alias
          spendingPaths = walletService.extractAllPaths(policy);
          mySpendingPaths = walletService.extractDataByFingerprint(
            policy,
            myFingerPrint,
          );

          myAlias = walletService.getAliasesFromFingerprint(
            widget.pubKeysAlias,
            [myFingerPrint],
          ).first;

          _pubKeyController.text = myPubKey;
        } else {
          throw Exception("Could not extract fingerprint from public key");
        }
      }

      _convertCurrency();

      // Update state with all variables
      setState(() {
        if (widget.mnemonic != null && widget.mnemonic!.isNotEmpty) {
          myFingerPrint = myFingerPrint;
          myAlias = myAlias;
          mySpendingPaths = mySpendingPaths;
          myPubKey = myPubKey;
        }
        isInitialized = true;
      });
    } catch (e) {
      throw Exception("Error initializing spending paths: $e");
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
    if (_isSyncing) return; // guard against overlap

    setState(() => _isSyncing = true);
    try {
      // Read-only props/state to locals
      final descriptor = widget.descriptor;
      final w = wallet;

      // 1) Do all async work first
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

      final walletUtxos = await walletService.getUtxos();

      if (!myAddresses.contains(address)) {
        myAddresses.add(address);
      }

      // 2) Bail out safely if disposed
      if (!mounted) return;

      _convertCurrency();

      // 3) Single, batched setState
      setState(() {
        _descriptor = descriptor;
        _currentHeight = currentHeight;
        _timeStamp = blockTimestamp;
        address = nextAddress;
        avBalance = balance['confirmedBalance'] ?? 0;
        ledBalance = balance['pendingBalance'] ?? 0;
        _transactions = transactions;
        utxos = walletUtxos;
        _lastRefreshed = DateTime.now();
        _isSyncing = false;
      });

      // 4) Persist after UI update (or before, if you prefer atomic success)
      await walletService.saveLocalData(
        wallet: w,
        address: nextAddress,
        currentHeight: currentHeight,
        timestamp: blockTimestamp,
        availableBalance: balance['confirmedBalance'] ?? 0,
        ledgerBalance: balance['pendingBalance'] ?? 0,
        transactions: transactions,
        utxos: walletUtxos,
        lastRefreshed: _lastRefreshed!,
        myAddresses: myAddresses,
      );
    } catch (e) {
      setState(() {
        _isSyncing = false;
      });
      throw Exception("Sync Error: ${e.toString()}");
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

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// MAIN WIDGET
  ///
  ///
  ///
  ///
  ///
  ///
  ///

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

    WalletButtonsHelper? walletButtonsHelper;
    WalletSpendingPathHelpers? spendingHelper;

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
      isSingleWallet: false,
      descriptor: _descriptor,
      descriptorName: _descriptorName,
      baseScaffoldKey: baseScaffoldKey,
      isRefreshing: _isRefreshing,
      myAddresses: myAddresses,
      pubKeysAlias: widget.pubKeysAlias,
    );

    if (widget.mnemonic != null && widget.mnemonic!.isNotEmpty) {
      spendingHelper = WalletSpendingPathHelpers(
        pubKeysAlias: widget.pubKeysAlias,
        mySpendingPaths: mySpendingPaths,
        spendingPaths: spendingPaths,
        utxos: utxos,
        currentHeight: _currentHeight,
        walletService: walletService,
        myAlias: myAlias,
        context: context,
        policy: policy,
        amountController: _amountController,
        recipientController: _recipientController,
        mounted: mounted,
        mnemonic: widget.mnemonic!,
        wallet: wallet,
        address: address,
        myFingerPrint: myFingerPrint,
        descriptor: _descriptor,
        avBalance: avBalance,
        onNewAddressGenerated: (newAddr) {
          setState(() {
            address = newAddr;
          });
        },
        syncWallet: _syncWallet,
        myAddresses: myAddresses,
      );
    }
    if (widget.mnemonic != null && widget.mnemonic!.isNotEmpty) {
      walletButtonsHelper = WalletButtonsHelper(
        context: context,
        address: address,
        isSingleWallet: false,
        descriptor: _descriptor.toString(),
        descriptorName: _descriptorName,
        pubKeysAlias: widget.pubKeysAlias,
        recipientController: _recipientController,
        psbtController: _psbtController,
        signingAmountController: _signingAmountController,
        amountController: _amountController,
        walletService: walletService,
        policy: policy,
        myFingerPrint: myFingerPrint,
        currentHeight: _currentHeight,
        utxos: utxos,
        mySpendingPaths: mySpendingPaths,
        spendingPaths: spendingPaths,
        mnemonic: widget.mnemonic!,
        mounted: mounted,
        signersList: signersList,
        wallet: wallet,
        myAlias: myAlias,
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
    }

    return BaseScaffold(
      title: Text(
        textScaler: TextScaler.linear(ScaleSize.textScaleFactor(context)),
        _descriptorName,
      ),
      key: baseScaffoldKey,
      body: Stack(
        children: [
          RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: () async {
              // await walletService.getBitcoinBalance(address);

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
                    padding: const EdgeInsets.all(8.0),
                    children: [
                      // WalletInfo Box
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
                          AppLocalizations.of(context)!.translate('address'),
                          onTap: () {
                            _convertCurrency();
                          },
                          showCopyButton: true,
                        ),
                      ),

                      // Dynamic Spending Paths Box
                      if (widget.mnemonic != null &&
                          widget.mnemonic!.isNotEmpty &&
                          spendingHelper != null)
                        GestureDetector(
                          onLongPress: () {
                            final BaseScaffoldState? baseScaffoldState =
                                baseScaffoldKey.currentState;

                            if (baseScaffoldState != null) {
                              baseScaffoldState.updateAssistantMessage(
                                context,
                                'assistant_shared_spending_path_box',
                              );
                            }
                          },
                          child: spendingHelper.buildDynamicSpendingPaths(
                            isInitialized,
                          ),
                        ),

                      // Transactions Box
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
                // Buttons section pinned at the bottom
                if (widget.mnemonic != null &&
                    widget.mnemonic!.isNotEmpty &&
                    walletButtonsHelper != null)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
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

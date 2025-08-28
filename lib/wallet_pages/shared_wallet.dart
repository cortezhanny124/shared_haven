import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
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
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
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
  final String mnemonic;
  final List<Map<String, String>> pubKeysAlias;
  final String? descriptorName;

  const SharedWallet({
    super.key,
    required this.descriptor,
    required this.mnemonic,
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

    // print('Widget list: ${widget.pubKeysAlias}');
    // print(widget.descriptorName);

    for (var i = 0; i < descriptorBox.length; i++) {
      final key = descriptorBox.keyAt(i); // Get the key
      final value = descriptorBox.getAt(i); // Get the value

      if (value != null) {
        try {
          // Decode the JSON string into a Map
          Map<String, dynamic> valueMap = jsonDecode(value);

          // Check if the "descriptor" matches
          if (valueMap['descriptor'] == widget.descriptor) {
            // print('Match found for key: $key');
            // walletService.printInChunks('Matching Value: $value');

            // final keyParts = key.split('_descriptor');
            // final descriptorName = keyParts.length > 1
            //     ? keyParts[1].replaceFirst('_', '')
            //     : 'Unnamed Descriptor';

            setState(() {
              final newName = walletService.generateRandomName();

              _descriptorName = widget.descriptorName!.isNotEmpty
                  ? widget.descriptorName!
                  : newName;
            });

            final newKey = key.replaceFirst(
                RegExp(r'_descriptor_.+'), '_descriptor_$_descriptorName');

            final Map<String, dynamic> newValueMap = {
              'descriptor': widget.descriptor,
              'pubKeysAlias': widget.pubKeysAlias,
            };

            // walletService.printInChunks(newValueMap.toString());

            // print('_descriptorName: $_descriptorName');

            final String newValue = jsonEncode(newValueMap);

            // Remove the old record and insert the updated one
            descriptorBox.delete(key); // Remove the old key-value pair

            descriptorBox.put(newKey, newValue); // Add the new key-value pair

            // print('Updated key: $newKey');
            // print('New value stored: $newValue');

            existingDescriptor = valueMap['descriptor'];
            break; // Stop iterating if a match is found
          }
        } catch (e) {
          // print('Error decoding value for key $key: $e');
          throw ('Error decoding value for key $key: $e');
        }
      } else {
        // print('Value for key $key is null.');
        throw ('Value for key $key is null.');
      }
    }

    // walletService.printInChunks(
    //     'Retrieved descriptor: ${existingDescriptor!['descriptor']}');

    if (existingDescriptor != null) {
      // print('Wallet with this mnemonic already exists.');
      await loadWallet();
    } else {
      await createWalletFromDescriptor();
    }
  }

  Future<void> loadWallet() async {
    // print('Loading');
    try {
      wallet = await walletService.createSharedWallet(widget.descriptor);

      setState(() {
        isWalletInitialized = true;
      });

      setState(() {
        _descriptor = widget.descriptor;
      });

      for (int i = 0; i < 100; i++) {
        final addressInfo = wallet.getAddress(
          addressIndex: AddressIndex.peek(index: i),
        );
        myAddresses.add(addressInfo.address.toString());
      }

      String walletId = wallet
          .getAddress(addressIndex: AddressIndex.peek(index: 0))
          .address
          .asString();

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
      }
    } catch (e, stackTrace) {
      print("Error creating or fetching balance for wallet: $stackTrace");
      throw ("Error creating or fetching balance for wallet: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> createWalletFromDescriptor() async {
    try {
      // print('Creating');
      // print('DescriptorWidget: ${widget.descriptor}');

      wallet = await walletService.createSharedWallet(widget.descriptor);

      for (int i = 0; i < 100; i++) {
        final addressInfo = wallet.getAddress(
          addressIndex: AddressIndex.peek(index: i),
        );
        myAddresses.add(addressInfo.address.toString());
      }

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

      final compositeKey = '${widget.mnemonic}_descriptor_$_descriptorName';

      descriptorBox.put(compositeKey, combinedValue);

      // Check internet before syncing
      _checkInternetAndSync();
    } catch (e) {
      // print("Error creating or fetching balance for wallet: $e");
      throw ("Error creating or fetching balance for wallet: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Helper method to extract wallet policies and spending paths
  Future<void> _initializePage() async {
    try {
      // Extract wallet policies
      externalWalletPolicy = wallet.policies(KeychainKind.externalChain)!;
      policy = jsonDecode(externalWalletPolicy.asString());

      // print('ciao');
      // walletService.printInChunks(externalWalletPolicy.toString());

      // Convert mnemonic to object
      Mnemonic trueMnemonic = await Mnemonic.fromString(widget.mnemonic);

      // Define derivation paths
      final hardenedDerivationPath =
          await DerivationPath.create(path: "m/84h/1h/0h");
      final receivingDerivationPath = await DerivationPath.create(path: "m/0");

      // Derive descriptor keys
      final (receivingSecretKey, receivingPublicKey) =
          await walletService.deriveDescriptorKeys(
        hardenedDerivationPath,
        receivingDerivationPath,
        trueMnemonic,
      );

      // print('pubkey: $receivingPublicKey');

      // Extract fingerprint
      final RegExp regex = RegExp(r'\[([^\]]+)\]');
      final Match? match = regex.firstMatch(receivingPublicKey.asString());

      // Extract spending paths
      setState(() {
        spendingPaths = walletService.extractAllPaths(policy);
        myFingerPrint = match!.group(1)!.split('/')[0];
        myAlias = walletService.getAliasesFromFingerprint(
            widget.pubKeysAlias, [myFingerPrint]).first;
        mySpendingPaths =
            walletService.extractDataByFingerprint(policy, myFingerPrint);
        myPubKey = receivingPublicKey.toString();
        _pubKeyController.text = myPubKey;

        isInitialized = true; // Mark as loaded
      });

      // print('myAlias: $myAlias');
    } catch (e) {
      // print("Error initializing spending paths: $e");
      throw ("Error initializing spending paths: $e");
    }
  }

  Future<void> _fetchCurrentBlockHeight() async {
    try {
      int currentHeight = await walletService.fetchCurrentBlockHeight();
      // print('currentHeight: $currentHeight');

      String blockTimestamp =
          await walletService.fetchBlockTimestamp(currentHeight);

      // print('blockTimestamp: $blockTimestamp');

      setState(() {
        _currentHeight = currentHeight;
        _timeStamp = blockTimestamp;
      });
    } catch (e) {
      print('Syncing error: $e'); // Debugging log
      throw Exception('Syncing error: $e'); // Properly throw an error
    }
  }

  Future<void> _checkInternetAndSync() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

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
        AppLocalizations.of(rootContext)!.translate('connect_internet'),
        style: TextStyle(
          color: AppColors.text(context),
          fontSize: 16,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            _checkInternetAndSync();
          },
          child: Text(
            AppLocalizations.of(rootContext)!.translate('retry'),
            style: TextStyle(
              color: AppColors.text(context),
            ),
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
        (tx['vout'] as List)
            .any((vout) => vout['scriptpubkey_address'] == address);
  }

  Future<void> _syncWallet() async {
    setState(() {
      _lastRefreshed = DateTime.now();
    });

    _descriptor = widget.descriptor;

    await walletService.syncWallet(wallet);

    await _fetchCurrentBlockHeight();

    setState(() {
      if (address.isEmpty) {
        address = wallet
            .getAddress(addressIndex: AddressIndex.peek(index: 0))
            .address
            .asString();
      }
    });

    Map<String, int> balance = await walletService.getBitcoinBalance(address);

    setState(() {
      avBalance = balance['confirmedBalance']!;
      ledBalance = balance['pendingBalance']!;
    });

    // Fetch and set the transactions
    List<Map<String, dynamic>> transactions =
        await walletService.getTransactions(address);

    transactions = walletService.sortTransactionsByConfirmations(
      transactions,
      _currentHeight,
    );

    setState(() {
      _transactions = transactions;
    });

    // Fetch all transactions for the wallet
    final walletUtxos = await walletService.getUtxos();

    setState(() {
      utxos = walletUtxos;
    });

    bool isAddressUsed =
        transactions.any((tx) => isAddressinTransaction(tx, address));

    if (isAddressUsed && !myAddresses.contains(address)) {
      myAddresses.add(address);
    }

    // print('myaddresses: $myAddresses');

    await walletService.saveLocalData(
      wallet,
      _lastRefreshed!,
      myAddresses,
    );
  }

  void _convertCurrency() async {
    final currencyLedUsd = await walletService.convertSatoshisToCurrency(
        ledBalance, settingsProvider.currency);
    final currencyAvUsd = await walletService.convertSatoshisToCurrency(
        avBalance, settingsProvider.currency);

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
              SpinKitFadingCircle(
                color: Colors.blue,
                size: 50.0,
              ),
              SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.translate('setting_wallet'),
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    // print('avBalance: $avBalance');
    // print('ledBalance: $ledBalance');

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
    );

    final spendingHelper = WalletSpendingPathHelpers(
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
      mnemonic: widget.mnemonic,
      wallet: wallet,
      address: address,
      myFingerPrint: myFingerPrint,
      descriptor: _descriptor,
      avBalance: BigInt.from(avBalance),
      onNewAddressGenerated: (newAddr) {
        setState(() {
          address = newAddr;
        });
      },
      syncWallet: _syncWallet,
    );

    final walletButtonsHelper = WalletButtonsHelper(
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
      mnemonic: widget.mnemonic,
      mounted: mounted,
      signersList: signersList,
      wallet: wallet,
      myAlias: myAlias,
      baseScaffoldKey: baseScaffoldKey,
      avBalance: BigInt.from(avBalance),
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
        _descriptorName,
        style: TextStyle(fontSize: 18),
      ),
      key: baseScaffoldKey,
      body: Stack(
        children: [
          RefreshIndicator(
            key:
                _refreshIndicatorKey, // Assign the GlobalKey to RefreshIndicator
            onRefresh: () async {
              // await walletService.getBitcoinBalance(address);

              final List<ConnectivityResult> connectivityResult =
                  await (Connectivity().checkConnectivity());

              // print('Myaddresses: $myAddresses');

              setState(() {
                _isRefreshing = true;
              });

              try {
                await walletUiHelpers.handleRefresh(
                  _syncWallet,
                  connectivityResult,
                  context,
                );
              } catch (e) {
                SnackBarHelper.showError(context, message: 'syncing_error');
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
                                context, 'assistant_personal_info_box');
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
                      GestureDetector(
                        onLongPress: () {
                          final BaseScaffoldState? baseScaffoldState =
                              baseScaffoldKey.currentState;

                          if (baseScaffoldState != null) {
                            baseScaffoldState.updateAssistantMessage(
                                context, 'assistant_shared_spending_path_box');
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
                                context, 'assistant_personal_transactions_box');
                          }
                        },
                        child: walletUiHelpers.buildTransactionsBox(),
                      ),

                      const SizedBox(height: 8),

                      // // Multisig Box
                      // walletUiHelpers.buildInfoBoxMultisig(
                      //   AppLocalizations.of(context)!.translate('multisig_tx'),
                      //   _txToSend != null
                      //       ? _txToSend.toString()
                      //       : AppLocalizations.of(context)!
                      //           .translate('no_transactions_to_sign'),
                      //   onTap: () {
                      //     sendTxHelper.sendTx(false);
                      //   },
                      //   showCopyButton: true,
                      // ),
                    ],
                  ),
                ),
                // Buttons section pinned at the bottom
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        walletButtonsHelper.buildButtons(),
                      ],
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

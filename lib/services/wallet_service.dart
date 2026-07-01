// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:bdk_dart/bdk.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/exceptions/validation_result.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:english_words/english_words.dart';
import 'package:convert/convert.dart';
import 'package:collection/collection.dart';

/// WalletService Class
///
/// A comprehensive service class for managing Bitcoin wallets using the BDK (Bitcoin Dev Kit)
/// library. This service handles both single-signature and multi-signature wallet operations,
/// descriptor-based wallet management, transaction creation, blockchain synchronization,
/// and interaction with various blockchain APIs (Electrum, Esplora, Mempool.space).
///
/// The class supports multiple Bitcoin networks (testnet/mainnet) and provides extensive
/// functionality for wallet creation, transaction building, signing, broadcasting, and
/// UTXO management. It also includes utilities for multi-signature wallets with timelock
/// conditions and policy-based spending paths.
///
/// Key Features:
/// - Single and multi-signature wallet creation/restoration
/// - Descriptor-based wallet management with BIP84 support
/// - Transaction building with custom fee rates and change addresses
/// - PSBT (Partially Signed Bitcoin Transaction) creation and signing
/// - Multi-signature support with timelock conditions (CLTV/CSV)
/// - Blockchain synchronization via Electrum servers
/// - UTXO management and balance tracking
/// - Fee rate estimation from multiple sources
/// - Transaction history and status tracking
/// - Offline transaction creation support
///
/// **INDEX**
///
/// **Initialization & Connection**
/// - `getWorkingEndpoint`: Finds a working blockchain API endpoint
/// - `get baseUrl`: Returns the base URL for blockchain API calls
/// - `get electrumServers`: Returns Electrum servers based on network
/// - `blockchainInit`: Initializes connection to blockchain via Electrum
/// - `syncWallet`: Synchronizes wallet with the blockchain
///
/// **Wallet Creation & Management**
/// - `createOrRestoreWallet`: Creates or restores a single-signature wallet
/// - `createSharedWallet`: Creates a multi-signature wallet from descriptor
/// - `loadSavedWallet`: Loads a previously saved wallet from storage
/// - `checkMnemonic`: Validates if a mnemonic can create a valid wallet
/// - `getDescriptors`: Generates BIP84 descriptors from mnemonic
/// - `isValidDescriptor`: Validates a wallet descriptor against a public key
/// - `saveLocalData`: Persists wallet data to local storage
///
/// **Balance & Address Operations**
/// - `getBalance`: Retrieves total wallet balance
/// - `getBitcoinBalance`: Fetches confirmed and pending balances
/// - `getAddress`: Gets current receiving address
/// - `getAddressFromScriptOutput`: Extracts address from transaction output
/// - `getAddressFromScriptInput`: Extracts address from transaction input
/// - `validateAddress`: Validates a Bitcoin address format
/// - `areEqualAddresses`: Checks if all outputs have same address
///
/// **Transaction Operations**
/// - `sendSingleTx`: Creates, signs, and broadcasts single-signature transaction
/// - `createPartialTx`: Creates a PSBT for multi-signature transaction
/// - `signBroadcastTx`: Signs a PSBT and broadcasts to network
/// - `createBackupTx`: Creates backup transaction (similar to createPartialTx)
/// - `calculateSendAllBalance`: Calculates maximum spendable amount after fees
/// - `getUtxos`: Fetches UTXOs with confirmation status
/// - `checkCondition`: Checks if UTXOs meet spending conditions
///
/// **Fee Management**
/// - `getFeeRate`: Gets current recommended fee rate
/// - `fetchRecommendedFees`: Fetches complete fee estimates (fastest, half-hour, hour)
///
/// **Blockchain Data**
/// - `fetchCurrentBlockHeight`: Gets current blockchain height
/// - `fetchBlockTimestamp`: Gets timestamp for a specific block
/// - `getTransactions`: Fetches wallet transaction history
/// - `calculateRemainingTimeInSeconds`: Calculates time for block confirmations
/// - `formatTime`: Formats duration in human-readable form
/// - `sortTransactionsByConfirmations`: Sorts transactions by confirmation count
///
/// **Multi-signature Utilities**
/// - `replacePubKeyWithPrivKeyMultiSig`: Replaces public keys with private in multisig descriptor
/// - `replacePubKeyWithPrivKeyOlder`: Replaces public keys with private in timelocked descriptors
/// - `extractOlderWithPrivateKey`: Extracts "older" value with private keys
/// - `deriveDescriptorKeys`: Derives secret and public keys from mnemonic
/// - `makeChangeDescriptor`: Creates change descriptor from receive descriptor
/// - `extractPublicKeysWithAliases`: Extracts public keys with their aliases
/// - `getAliasesFromFingerprint`: Gets aliases from fingerprints
///
/// **Policy & Path Extraction**
/// - `extractAllPathsToFingerprint`: Extracts all policy paths for a fingerprint
/// - `extractDataByFingerprint`: Extracts data related to a specific fingerprint
/// - `extractAllPaths`: Extracts all policy paths from wallet descriptor
/// - `extractSpendingPathFromPsbt`: Determines spending path used in PSBT
/// - `extractSignersFromPsbt`: Identifies signers from PSBT
///
/// **Utilities & Helpers**
/// - `printInChunks`: Prints long strings in manageable chunks
/// - `printPrettyJson`: Pretty-prints JSON for debugging
/// - `printPsbtJson`: Pretty-prints PSBT JSON structure
/// - `generateRandomName`: Generates random wallet name
/// - `formatDuration`: Formats duration for display
/// - `convertSatoshisToCurrency`: Converts satoshis to fiat currency
/// - `stripChecksum`: Removes checksum from descriptor
/// - `_isImmediateMultisig`: Checks if path is immediate multisig
/// - `_pathAt`: Safely gets path at index

const int avgBlockTime = 600;
bool oldCase = false;

class WalletService extends ChangeNotifier {
  final WalletStorageService _walletStorageService = WalletStorageService();
  final SettingsProvider settingsProvider;

  WalletService(this.settingsProvider);

  late Wallet wallet;
  late Persister persister;
  // late Blockchain blockchain;

  final List<String> testnetEndpoints = [
    // 'https://mempool.space/testnet4/api',
    'https://blockstream.info/testnet/api/',
    'https://mempool.space/testnet/api/',
  ];

  final List<String> mainnetEndpoints = [
    'https://mempool.space/api/',
    // Add another if you want
  ];

  Future<String> getWorkingEndpoint(Network network) async {
    final endpoints = network == Network.testnet
        ? testnetEndpoints
        : mainnetEndpoints;

    for (final endpoint in endpoints) {
      try {
        // Quick health check(HEAD or simple GET)
        final response = await http
            .get(Uri.parse('${endpoint}blocks/tip/height'))
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          return endpoint;
        }
      } catch (e) {
        throw Exception("⚠️ Failed endpoint: $endpoint → $e");
      }
    }

    throw Exception("No available endpoint for $network");
  }

  Future<String> get baseUrl async {
    return await getWorkingEndpoint(settingsProvider.network);
  }

  // TESTNET3
  List<String> get electrumServers {
    switch (settingsProvider.network) {
      case Network.testnet:
        return ["ssl://electrum.blockstream.info:60002"];
      case Network.bitcoin:
        return ["ssl://electrum.blockstream.info:50002"];
      default:
        return [""];
    }
  }

  // TESTNET4
  // List<String> get electrumServers {
  //   switch (settingsProvider.network) {
  //     case Network.testnet:
  //       return ["ssl://mempool.space:40002"];
  //     case Network.bitcoin:
  //       return ["ssl://electrum.blockstream.info:50002"];
  //     default:
  //       return [""];
  //   }
  // }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// Common Methods
  ///
  ///
  ///
  ///
  ///
  ///

  Future<ValidationResult> isValidDescriptor(
    String descriptorStr,
    String? publicKey,
    BuildContext context,
  ) async {
    final startTime = DateTime.now();

    try {
      if (publicKey != null) {
        // Get last 3 characters of publicKey
        final last3 = publicKey.substring(0, publicKey.length - 3);

        if (descriptorStr.contains(last3)) {
          try {
            await createSharedWallet(descriptorStr);
            return ValidationResult(isValid: true);
          } catch (e) {
            rethrow;
          }
        } else {
          final errorMessage = AppLocalizations.of(
            context,
          )!.translate('error_public_key_not_contained');
          return ValidationResult(isValid: false, errorMessage: errorMessage);
        }
      } else {
        try {
          await createSharedWallet(descriptorStr);
          return ValidationResult(isValid: true);
        } catch (e) {
          rethrow;
        }
      }
    } catch (e) {
      // Check if it's a specific error or generic
      String errorMessage;
      try {
        errorMessage = AppLocalizations.of(
          context,
        )!.translate('error_wallet_descriptor');
      } catch (localizationError) {
        errorMessage = 'Invalid wallet descriptor';
      }

      return ValidationResult(isValid: false, errorMessage: errorMessage);
    }
  }

  BigInt getBalance(Wallet wallet) {
    Balance balance = wallet.balance();

    return BigInt.from(balance.total.toSat());
  }

  Future<bool> checkMnemonic(String mnemonic) async {
    try {
      final descriptors = getDescriptors(mnemonic);

      persister = Persister.newInMemory();

      wallet = Wallet(
        descriptor: descriptors[0],
        changeDescriptor: descriptors[1],
        network: settingsProvider.network,
        persister: persister,
        lookahead: 100,
      );

      wallet.persist(persister: persister);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Wallet> loadSavedWallet({String? mnemonic}) async {
    var walletBox = Hive.box('walletBox');
    String? savedMnemonic = walletBox.get('walletMnemonic');

    if (savedMnemonic != null) {
      // Restore the wallet using the saved mnemonic
      wallet = await createOrRestoreWallet(savedMnemonic);
      return wallet;
    } else {
      wallet = await createOrRestoreWallet(mnemonic!);
    }
    return wallet;
  }

  Future<void> syncWallet(Wallet wallet) async {
    try {
      await blockchainInit(
        wallet: wallet,
        persister: persister,
      ); // Ensure blockchain is initialized before usage
    } catch (e) {
      throw Exception("Blockchain initialization failed: ${e.toString()}");
    }
  }

  String getAddress(Wallet wallet) {
    var addressInfo = wallet.revealNextAddress(
      keychain: KeychainKind.external_,
    );

    return addressInfo.address.toString();
  }

  /// Fetches and calculates confirmed & pending balance
  Future<Map<String, int>> getBitcoinBalance(String address) async {
    try {
      final int confirmedBalance = wallet.balance().trustedSpendable.toSat();

      final int pendingBalance = wallet.balance().untrustedPending.toSat();

      return {
        "confirmedBalance": confirmedBalance,
        "pendingBalance": pendingBalance,
      };
    } catch (e) {
      return {"confirmedBalance": 0, "pendingBalance": 0};
    }
  }

  Future<int> calculateSendAllBalance({
    required String recipientAddress,
    required Wallet wallet,
    required Amount availableBalance,
    required WalletService walletService,
    double? customFeeRate,
  }) async {
    try {
      final feeRate = customFeeRate ?? await getFeeRate();

      final recipient = Address(
        address: recipientAddress,
        network: settingsProvider.network,
      );
      final recipientScript = recipient.scriptPubkey();

      final txBuilder = TxBuilder();

      txBuilder
          .addRecipient(script: recipientScript, amount: availableBalance)
          .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()))
          .finish(wallet: wallet);

      return availableBalance.toSat();
    } catch (e) {
      // Handle insufficient funds
      if (e.toString().contains("Insufficient funds:")) {
        // More flexible regex that extracts both BTC amounts
        final RegExp regex = RegExp(
          r'([\d.]+)\s*BTC\s+available.*?([\d.]+)\s*BTC\s+needed',
        );
        final match = regex.firstMatch(e.toString());

        if (match != null) {
          final double availableBTC = double.parse(match.group(1)!);
          final double neededBTC = double.parse(match.group(2)!);

          final int availableAmount = (availableBTC * 100000000).round();
          final int neededAmount = (neededBTC * 100000000).round();

          final int fee = neededAmount - availableAmount;
          final int sendAllBalance = availableBalance.toSat() - fee;

          if (sendAllBalance > 0) {
            return sendAllBalance;
          } else {
            throw Exception('No balance available after fee deduction');
          }
        } else {
          throw Exception(
            'Failed to extract amounts from exception: ${e.toString()}',
          );
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> blockchainInit({
    required Wallet wallet,
    required Persister persister,
  }) async {
    for (final server in electrumServers) {
      try {
        /**
         * startFullScan() makes synchronous FFI calls into rust,
         * so they block whatever dart thread they run on.
         * If that's the main/UI isolate, your app freezes until the call returns.
         * 
         * Isolate.run() moves the heavy network + chain-scan work to a background isolate so the UI stays responsive.
         */

        final update = await Isolate.run(() {
          final client = ElectrumClient(
            url: server,
            socks5: null,
            timeout: null,
            retry: null,
            validateDomain: true,
          );
          try {
            final syncRequest = wallet.startFullScan().build();

            final Update result = client.fullScan(
              request: syncRequest,
              stopGap: 50,
              batchSize: 100,
              fetchPrevTxouts: true,
            );

            return result;
          } finally {
            client.dispose();
          }
        });

        wallet.applyUpdate(update: update);

        wallet.persist(persister: persister);

        return;
      } catch (e) {
        throw Exception('[SYNC][ERROR] $e');
      }
    }

    throw Exception("Failed to connect to any Electrum server.");
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final results = <Map<String, dynamic>>[];

      final canonical = wallet.transactions();

      for (final c in canonical) {
        final transaction = c.transaction;
        final chainPosition = c.chainPosition;

        final txid = transaction.computeTxid();

        // Get transaction details including sent, received, and fee
        final txDetails = wallet.txDetails(txid: txid);

        // Build transaction details map from the available data
        final Map<String, dynamic> txMap = {
          'txid': txid.toString(),
          'confirmationTime': _getConfirmationTimeFromChainPosition(
            chainPosition,
          ),
          'sent': txDetails!.sent.toSat(),
          'received': txDetails.received.toSat(),
          'fee': txDetails.fee?.toSat(),
          'feeRate': txDetails.feeRate?.toSatPerVbCeil(),
        };

        results.add(txMap);
      }

      return results;
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  Map<String, dynamic>? _getConfirmationTimeFromChainPosition(
    ChainPosition chainPosition,
  ) {
    // Check the actual runtime type
    if (chainPosition is ConfirmedChainPosition) {
      final confirmationBlockTime = chainPosition.confirmationBlockTime;

      return {
        'height': confirmationBlockTime.blockId.height,
        'timestamp': confirmationBlockTime.confirmationTime,
        'transitively': chainPosition.transitively?.toString(),
      };
    } else if (chainPosition is UnconfirmedChainPosition) {
      return {
        'height': null,
        'timestamp': chainPosition.timestamp,
        'unconfirmed': true,
      };
    } else {
      return null;
    }
  }

  List<Map<String, dynamic>> sortTransactionsByConfirmations(
    List<Map<String, dynamic>> transactions,
    int currentHeight,
  ) {
    // Create a copy to avoid modifying the original list
    final sortedTransactions = List<Map<String, dynamic>>.from(transactions);

    sortedTransactions.sort((a, b) {
      // Extract block heights from transaction data
      final blockHeightA = a['confirmationTime']?['height'];
      final blockHeightB = b['confirmationTime']?['height'];

      // Compute confirmations
      final confirmationsA = (blockHeightA != null && blockHeightA is int)
          ? currentHeight - blockHeightA
          : -1;

      final confirmationsB = (blockHeightB != null && blockHeightB is int)
          ? currentHeight - blockHeightB
          : -1;

      // Lower confirmations should come FIRST (unconfirmed at the top)
      return confirmationsA.compareTo(confirmationsB);
    });

    // Log the final sorted order
    for (var i = 0; i < sortedTransactions.length; i++) {
      final tx = sortedTransactions[i];
      final blockHeight = tx['confirmationTime']?['height'];
      final confirmations = (blockHeight != null && blockHeight is int)
          ? currentHeight - blockHeight
          : -1;
      final isUnconfirmed = tx['confirmationTime']?['unconfirmed'] == true;
      final txid = tx['txid']?.toString();
      final shortTxid = txid != null ? '${txid.substring(0, 8)}...' : 'unknown';

      String status;
      if (isUnconfirmed) {
        status = 'UNCONFIRMED';
      } else if (blockHeight != null) {
        status = '$confirmations confirmations';
      } else {
        status = 'unknown';
      }
    }

    return sortedTransactions;
  }

  Future<int> fetchCurrentBlockHeight() async {
    final client = EsploraClient(url: await baseUrl, proxy: null);
    try {
      return client.getHeight();
    } finally {
      client.dispose();
    }
  }

  Future<String> fetchBlockTimestamp(int height) async {
    try {
      String currentHash = "";

      final client = EsploraClient(url: await baseUrl, proxy: null);
      try {
        currentHash = client
            .getBlockHash(blockHeight: client.getHeight())
            .toString();
      } finally {
        client.dispose();
      }

      // API endpoint to fetch block details
      final String blockApiUrl = '${await baseUrl}/block/$currentHash';

      // Make GET request to fetch block details
      final response = await http.get(Uri.parse(blockApiUrl));

      if (response.statusCode == 200) {
        // Decode JSON response
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Check if data contains the `time` field
        if (jsonData.containsKey('timestamp')) {
          int timestamp = jsonData['timestamp']; // Extract timestamp

          DateTime formattedTime = DateTime.fromMillisecondsSinceEpoch(
            timestamp * 1000,
          );
          if (settingsProvider.isTestnet) {
            formattedTime = formattedTime.subtract(const Duration(hours: 2));
          }

          return formattedTime.toString().substring(
            0,
            formattedTime.toString().length - 7,
          );
        } else {
          throw Exception('Block API response missing timestamp field.');
        }
      } else {
        // Handle HTTP errors for block details API
        throw Exception('HTTP Error (Block API): ${response.statusCode}');
      }
    } catch (e) {
      // Handle any unexpected exceptions
      throw Exception('Failed to fetch block timestamp: $e');
    }
  }

  Future<int> calculateRemainingTimeInSeconds(int remainingBlocks) async {
    if (avgBlockTime > 0) {
      // Calculate remaining time in seconds
      return remainingBlocks * avgBlockTime;
    } else {
      throw Exception('Invalid average block time.');
    }
  }

  String formatTime(int totalSeconds, BuildContext context) {
    if (totalSeconds <= 0) {
      return AppLocalizations.of(context)!.translate('zero_seconds');
    }

    const secondsInYear = 31536000;
    const secondsInMonth = 2592000;
    const secondsInDay = 86400;
    const secondsInHour = 3600;
    const secondsInMinute = 60;

    final years = totalSeconds ~/ secondsInYear;
    totalSeconds %= secondsInYear;

    final months = totalSeconds ~/ secondsInMonth;
    totalSeconds %= secondsInMonth;

    final days = totalSeconds ~/ secondsInDay;
    totalSeconds %= secondsInDay;

    final hours = totalSeconds ~/ secondsInHour;
    totalSeconds %= secondsInHour;

    final minutes = totalSeconds ~/ secondsInMinute;
    final seconds = totalSeconds % secondsInMinute;

    final loc = AppLocalizations.of(context)!;

    String formatUnit(int value, String singularKey, String pluralKey) {
      if (value == 0) return '';
      final label = loc.translate(value == 1 ? singularKey : pluralKey);
      return '$value $label';
    }

    List<String> parts = [];

    parts.addAll([
      formatUnit(years, 'year', 'years'),
      formatUnit(months, 'month', 'months'),
      formatUnit(days, 'day', 'days'),
      formatUnit(hours, 'hour', 'hours'),
      formatUnit(minutes, 'minute', 'minutes'),
      formatUnit(seconds, 'second', 'seconds'),
    ]);

    // Filter out empty parts and join with commas
    return parts.where((p) => p.isNotEmpty).join(', ');
  }

  Future<List<dynamic>> getUtxos() async {
    List<dynamic> finalUtxos = [];

    final walletUtxos = wallet.listUnspent();

    for (var i = 0; i < walletUtxos.length; i++) {
      final utxo = walletUtxos[i];
      final txid = utxo.outpoint.txid.toString();
      final vout = utxo.outpoint.vout;
      final value = utxo.txout.value;
      final keychain = utxo.keychain;
      final isSpent = utxo.isSpent;
      final derivationIndex = utxo.derivationIndex;
      final chainPosition = utxo.chainPosition;

      // Build status from chain position (reusing our existing method)
      final confirmationInfo = _getConfirmationTimeFromChainPosition(
        chainPosition,
      );

      final status = {
        'confirmed':
            confirmationInfo != null && confirmationInfo['height'] != null,
        'block_height': confirmationInfo?['height'],
        'block_time': confirmationInfo?['timestamp'],
        'unconfirmed': confirmationInfo?['unconfirmed'] == true,
      };

      // You can optionally still fetch additional data from the API if needed
      // But the chainPosition already has confirmation info
      if (status['confirmed'] == true) {
        finalUtxos.add({
          'txid': txid,
          'vout': vout,
          'status': status,
          'value': value.toSat(),
          'keychain': keychain.toString(),
          'derivationIndex': derivationIndex,
          'isSpent': isSpent,
        });
      } else {
        finalUtxos.add({
          'txid': txid,
          'vout': vout,
          'status': status,
          'value': value.toSat(),
          'keychain': keychain.toString(),
          'derivationIndex': derivationIndex,
          'isSpent': isSpent,
        });
      }
    }

    return finalUtxos;
  }

  bool checkCondition(
    Map<String, dynamic> data,
    List<dynamic> utxos,
    String amount,
    int currentHeight,
  ) {
    final type = (data['type'] ?? '').toString();
    final rawTimelock = data['timelock'];
    final int timelock = (rawTimelock is int) ? rawTimelock : 0;

    final requiredAmount = double.tryParse(amount) ?? 0.0;

    // MULTISIG with no timelock: keep your original short-circuit
    final isMultisigNoTimelock =
        type.contains('MULTISIG') && rawTimelock == null;
    if (isMultisigNoTimelock) {
      return true;
    }

    final isAbsolute = type.contains(
      'ABSOLUTETIMELOCK',
    ); // CLTV / AFTER <height>
    final isRelative = type.contains(
      'RELATIVETIMELOCK',
    ); // CSV / OLDER <blocks>

    double totalSpendable = 0.0;

    if (isAbsolute) {
      // CLTV: path is unlocked iff chain height reached/passed absolute height
      final pathUnlocked = (timelock == 0) || (currentHeight >= timelock);

      if (!pathUnlocked) {
        return false;
      }

      // If unlocked, all UTXOs are eligible (no per-UTXO CSV needed)
      for (var i = 0; i < utxos.length; i++) {
        final utxoValueRaw = utxos[i]['value'] ?? 0.0;
        final v = double.tryParse(utxoValueRaw.toString()) ?? 0.0;
        totalSpendable += v;
      }
    } else if (isRelative) {
      // CSV: per-UTXO confirmations must reach 'timelock'
      for (var i = 0; i < utxos.length; i++) {
        final status = (utxos[i]['status'] is Map)
            ? utxos[i]['status'] as Map
            : const {};
        final blockHeight = status['block_height'] ?? 0; // 0 → unconfirmed
        final utxoValueRaw = utxos[i]['value'] ?? 0.0;
        final v = double.tryParse(utxoValueRaw.toString()) ?? 0.0;

        final hasHeight = blockHeight is int && blockHeight > 0;
        final confirmations = hasHeight ? (currentHeight - blockHeight) : 0;
        final spendable = (timelock == 0)
            ? true
            : (hasHeight && confirmations >= timelock);

        if (spendable) {
          totalSpendable += v;
        }
      }
    } else {
      // Fallback (unknown type): keep old conservative per-UTXO rule
      for (var i = 0; i < utxos.length; i++) {
        final status = (utxos[i]['status'] is Map)
            ? utxos[i]['status'] as Map
            : const {};
        final blockHeight = status['block_height'] ?? 0;
        final utxoValueRaw = utxos[i]['value'] ?? 0.0;
        final v = double.tryParse(utxoValueRaw.toString()) ?? 0.0;

        final spendable =
            (timelock == 0) || (blockHeight + timelock <= currentHeight);
        if (spendable) {
          totalSpendable += v;
        }
      }
    }

    final decision = totalSpendable >= requiredAmount;
    return decision;
  }

  Future<bool> areEqualAddresses(List<TxOut> outputs) async {
    Address? firstAddress;

    for (final output in outputs) {
      final testAddress = Address.fromScript(
        script: Script(rawOutputScript: output.scriptPubkey.toBytes()),
        network: settingsProvider.network,
      );

      if (firstAddress == null) {
        // Store the first address for comparison
        firstAddress = testAddress;
      } else if (testAddress.toString() != firstAddress.toString()) {
        // If an address does not match the first one, set the flag to false
        return false;
      }
    }
    return true;
  }

  Address getAddressFromScriptOutput(TxOut output) {
    return Address.fromScript(
      script: Script(rawOutputScript: output.scriptPubkey.toBytes()),
      network: settingsProvider.network,
    );
  }

  Address getAddressFromScriptInput(TxIn input) {
    return Address.fromScript(
      script: Script(rawOutputScript: input.scriptSig.toBytes()),
      network: settingsProvider.network,
    );
  }

  void validateAddress(String address) async {
    try {
      Address(address: address, network: settingsProvider.network);
    } on Exception catch (e) {
      throw Exception('Invalid address format: $e');
    } catch (e) {
      throw Exception('Unknown error while validating address: $e');
    }
  }

  List<Map<String, String>> extractPublicKeysWithAliases(String descriptor) {
    // Regular expression to extract public keys (tpub) and their fingerprints with paths
    final publicKeyRegex = RegExp(r"\[([^\]]+)\]([tvxyz]pub[A-Za-z0-9]+)");

    // Extract matches
    final matches = publicKeyRegex.allMatches(descriptor);

    // Use a Set to ensure uniqueness
    final Set<String> seenKeys = {};
    List<Map<String, String>> result = [];

    for (var match in matches) {
      // Extract alias (fingerprint) and full public key
      final fingerprint = match.group(1)!.split('/')[0]; // Extract fingerprint
      final publicKey =
          "[${match.group(1)!}]${match.group(2)!}"; // Full public key with path

      // Avoid duplicates
      if (!seenKeys.contains(fingerprint)) {
        seenKeys.add(fingerprint);
        result.add({'publicKey': publicKey, 'alias': fingerprint});
      }
    }

    return result;
  }

  Future<double> convertSatoshisToCurrency(
    int satoshis,
    String currency,
  ) async {
    final url = 'https://blockchain.info/ticker';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final btcToCurrency = data[currency]['buy'];
      final satoshiToCurrency = (btcToCurrency / 100000000) * satoshis;

      return double.parse(satoshiToCurrency.toStringAsFixed(2));
    } else {
      throw Exception('Failed to fetch conversion rate');
    }
  }

  Future<DescriptorPublicKey?> getPubKey(
    Map<String, Future<DescriptorPublicKey?>> pubKeyFutures,
    String? mnemonic,
  ) {
    // Always return a Future, never null
    if (mnemonic == null || mnemonic.isEmpty) {
      return Future.value(null); // Return a Future that completes with null
    }

    if (!pubKeyFutures.containsKey(mnemonic)) {
      pubKeyFutures[mnemonic] = fetchPubKey(mnemonic).catchError((error) {
        // Remove from cache on error to allow retry
        pubKeyFutures.remove(mnemonic);
        throw error; // Re-throw to be caught by FutureBuilder
      });
    }

    return pubKeyFutures[mnemonic]!;
  }

  Future<DescriptorPublicKey?> fetchPubKey(String mnemonic) async {
    final trueMnemonic = Mnemonic.fromString(mnemonic: mnemonic);

    DerivationPath hardenedDerivationPath;

    if (settingsProvider.network == Network.bitcoin) {
      hardenedDerivationPath = DerivationPath(path: "m/84h/0h/0h");
    } else {
      hardenedDerivationPath = DerivationPath(path: "m/84h/1h/0h");
    }
    final receivingDerivationPath = DerivationPath(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    return receivingPublicKey;
  }

  Future<Map<String, double>?> fetchRecommendedFees() async {
    final client = EsploraClient(url: await baseUrl, proxy: null);

    try {
      final feeEstimates = client.getFeeEstimates();

      if (feeEstimates.isEmpty) {
        return null;
      }

      // Get all available block targets and sort them
      final blockTargets = feeEstimates.keys.toList()..sort();

      if (blockTargets.isEmpty) {
        return null;
      }

      final lowestTarget = blockTargets.last;
      final highestTarget = blockTargets.first;

      final middleIndex = blockTargets.length ~/ 2;
      final middleTarget = blockTargets[middleIndex];

      final lowestFee = (feeEstimates[lowestTarget]! * 10).ceilToDouble() / 10;
      final middleFee = (feeEstimates[middleTarget]! * 10).ceilToDouble() / 10;
      final highestFee =
          (feeEstimates[highestTarget]! * 10).ceilToDouble() / 10;

      return {
        'fastestFee': highestFee,
        'halfHourFee': middleFee,
        'hourFee': lowestFee,
      };
    } catch (e) {
      return null;
    } finally {
      client.dispose();
    }
  }

  Future<double> getFeeRate() async {
    final client = EsploraClient(url: await baseUrl, proxy: null);

    try {
      final feeEstimates = client.getFeeEstimates();

      if (feeEstimates.isEmpty) {
        throw Exception('No fee estimates available');
      }

      final blockTargets = feeEstimates.keys.toList()..sort();

      if (blockTargets.isEmpty) {
        throw Exception('No block targets available');
      }

      final middleIndex = blockTargets.length ~/ 2;
      final middleTarget = blockTargets[middleIndex];

      final feeRate = feeEstimates[middleTarget]!;

      return feeRate.ceilToDouble();
    } catch (e) {
      rethrow;
    } finally {
      client.dispose();
    }
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// Single Wallet
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  Future<Wallet> createOrRestoreWallet(String mnemonic) async {
    try {
      final descriptors = getDescriptors(mnemonic);

      final List<ConnectivityResult> connectivityResult = await Connectivity()
          .checkConnectivity();

      persister = Persister.newInMemory();
      wallet = Wallet(
        descriptor: descriptors[0],
        changeDescriptor: descriptors[1],
        network: settingsProvider.network,
        persister: persister,
        lookahead: 100,
      );
      final persisted = wallet.persist(persister: persister);

      return wallet;
    } catch (e) {
      throw Exception('Failed to create wallet (Error: $e)');
    }
  }

  List<Descriptor> getDescriptors(String mnemonic) {
    final descriptors = <Descriptor>[];
    try {
      for (var e in [KeychainKind.external_, KeychainKind.internal]) {
        final mnemonicObj = Mnemonic.fromString(mnemonic: mnemonic);

        final descriptorSecretKey = DescriptorSecretKey(
          networkKind: settingsProvider.networkKind,
          mnemonic: mnemonicObj,
          password: null,
        );

        final descriptor = Descriptor.newBip84(
          secretKey: descriptorSecretKey,
          keychainKind: e,
          networkKind: settingsProvider.networkKind,
        );

        descriptors.add(descriptor);
      }
      return descriptors;
    } on Exception catch (e) {
      throw ("Error: ${e.toString()}");
    }
  }

  String generateDonationAddress() {
    String address = "";

    final publicKey = settingsProvider.network == Network.bitcoin
        ? DescriptorPublicKey.fromString(
            publicKey:
                "[98a2af72/84'/0'/0']xpub6DMymVxGHgvA6yMn9CcMFXAJfWremKeogbF2uoxCiCazHa5XT3vTPeZirsPsgoxTRZxES1nAVZ9fjJUMB2N4afU3WWAwc4Qe6Ry5c5UbTLc/0/*",
          )
        : DescriptorPublicKey.fromString(
            publicKey:
                "[f31c4a3b/84'/1'/0']tpubDDeWSeMbdTfhgWkR5WfXNXtgfrWDNh7CtEojp7rp7Jq3Rxc641XE9gaZEyfzmnCadaLu5VXdxRiFucSF4j25GeaASmw6ZbXgecqokn5jPPN/0/*",
          );

    final fingerPrint = settingsProvider.network == Network.bitcoin
        ? "98a2af72"
        : "f31c4a3b";

    final descriptor = Descriptor.newBip84Public(
      publicKey: publicKey,
      fingerprint: fingerPrint,
      keychainKind: KeychainKind.external_,
      networkKind: settingsProvider.networkKind,
    );
    final changeDescriptor = Descriptor.newBip84Public(
      publicKey: publicKey,
      fingerprint: fingerPrint,
      keychainKind: KeychainKind.internal,
      networkKind: settingsProvider.networkKind,
    );

    persister = Persister.newInMemory();

    final donationWallet = Wallet(
      descriptor: descriptor,
      changeDescriptor: changeDescriptor,
      network: settingsProvider.network,
      persister: persister,
      lookahead: 100,
    );

    final persisted = donationWallet.persist(persister: persister);

    address = donationWallet
        .nextUnusedAddress(keychain: KeychainKind.external_)
        .address
        .toString();

    return address;
  }

  // Method to create, sign and broadcast a single user transaction
  Future<void> sendSingleTx(
    String recipientAddressStr,
    Amount amount,
    Wallet wallet,
    String changeAddressStr,
    double? customFeeRate,
  ) async {
    await syncWallet(wallet);

    try {
      // Build the transaction
      final txBuilder = TxBuilder();

      final recipientAddress = Address(
        address: recipientAddressStr,
        network: wallet.network(),
      );
      final recipientScript = recipientAddress.scriptPubkey();

      final changeAddress = Address(
        address: changeAddressStr,
        network: wallet.network(),
      );
      final changeScript = changeAddress.scriptPubkey();

      final feeRate = customFeeRate ?? await getFeeRate();

      // Build the transaction:
      // - Send `amount` to the recipient
      // - Any remaining funds (change) will be sent to the change address
      final txBuilderResult = txBuilder
          .addRecipient(
            script: recipientScript,
            amount: amount,
          ) // Send to recipient
          .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
          .feeRate(
            feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()),
          ) // Set the fee rate (in satoshis per byte)
          .drainTo(
            script: changeScript,
          ) // Specify the custom address to send the change
          .finish(
            wallet: wallet,
          ); // Finalize the transaction with wallet's UTXOs

      // Sign the transaction
      final isFinalized = wallet.sign(
        psbt: txBuilderResult,
        signOptions: SignOptions(
          trustWitnessUtxo: true,
          allowAllSighashes: false,
          tryFinalize: true,
          signWithTapInternalKey: false,
          allowGrinding: false,
        ),
      );

      // Broadcast the transaction only if it is finalized
      if (isFinalized) {
        // Broadcast the transaction to the network only if it is finalized

        ElectrumClient? client;
        final tx = txBuilderResult.extractTx();

        for (final server in electrumServers) {
          try {
            // Pick the right server for the network you're on
            client = ElectrumClient(
              url: server,
              socks5: null,
              retry: null,
              timeout: null,
              validateDomain: true,
            );

            final txid = client.transactionBroadcast(tx: tx);
          } catch (e) {
            rethrow;
          } finally {
            client?.dispose();
          }
        }
      }
    } on Exception catch (e) {
      throw Exception('Failed to send Transaction (Error: ${e.toString()})');
    }
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// Shared Wallet
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  String stripChecksum(String d) => d.split('#').first;

  String makeChangeDescriptor(String receiveDescriptor) {
    final d = stripChecksum(receiveDescriptor);

    // Shift chains to avoid overlap:
    // 0->10, 1->11, 2->12
    // Use a careful replacement order so we don't double-replace.
    return d
        .replaceAll('/2', '/__TMP2__')
        .replaceAll('/1', '/__TMP1__')
        .replaceAll('/0', '/__TMP0__')
        .replaceAll('/__TMP0__', '/10')
        .replaceAll('/__TMP1__', '/11')
        .replaceAll('/__TMP2__', '/12');
  }

  Future<Wallet> createSharedWallet(String descriptor) async {
    try {
      final receiveDesc = Descriptor(
        descriptor: descriptor,
        networkKind: settingsProvider.networkKind,
      );

      final changeDescStr = makeChangeDescriptor(descriptor);

      final changeDesc = Descriptor(
        descriptor: changeDescStr,
        networkKind: settingsProvider.networkKind,
      );

      persister = Persister.newInMemory();

      // bdk-dart
      wallet = Wallet(
        descriptor: receiveDesc,
        changeDescriptor: changeDesc,
        network: settingsProvider.network,
        persister: persister,
        lookahead: 100,
      );

      return wallet;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> saveLocalData({
    required Wallet wallet,
    required String address,
    required int currentHeight,
    required String timestamp,
    required int availableBalance,
    required int ledgerBalance,
    required List<Map<String, dynamic>> transactions,
    List<dynamic>? utxos,
    required DateTime lastRefreshed,
    required Set<String> myAddresses,
  }) async {
    final methodStart = DateTime.now();

    final walletId = wallet
        .peekAddress(keychain: KeychainKind.external_, index: 0)
        .address
        .toString();

    final totalWalletBalance = int.parse(getBalance(wallet).toString());

    final walletData = WalletData(
      address: address,
      balance: totalWalletBalance,
      ledgerBalance: ledgerBalance,
      availableBalance: availableBalance,
      transactions: transactions,
      currentHeight: currentHeight,
      timeStamp: timestamp,
      utxos: utxos,
      lastRefreshed: lastRefreshed,
      myAddresses: myAddresses,
    );

    await _walletStorageService.saveWalletData(walletId, walletData);

    final totalMs = DateTime.now().difference(methodStart).inMilliseconds;
  }

  String replacePubKeyWithPrivKeyMultiSig(
    String descriptor,
    String pubKey,
    String privKey,
  ) {
    // Extract the derivation path and pubkey portion for dynamic matching
    final regexPathPub = RegExp(
      RegExp.escape('${pubKey.split(']')[0]}]') +
          r'[tvxyz]pub[A-Za-z0-9]+\/\d+\/\*',
    ); // tpub for testnet and xpub for mainnet

    // Replace only the matching public key with the private key
    return descriptor.replaceFirstMapped(regexPathPub, (match) {
      return privKey;
    });
  }

  String replacePubKeyWithPrivKeyOlder(
    int? chosenPath, // The specific index to target
    String descriptor,
    String pubKey,
    String privKey,
  ) {
    // Extract the derivation path prefix and ensure we match tpub/xpub keys with trailing paths
    final regexPathPub = RegExp(
      RegExp.escape('${pubKey.split(']')[0]}]') +
          r'[tvxyz]pub[A-Za-z0-9]+\/(\d+)\/\*',
    ); // Matches tpub for testnet and xpub for mainnet

    int currentIndex = 0; // Tracks the current match index

    // Replace only the match at the specified `chosenPath` index
    final result = descriptor.replaceAllMapped(regexPathPub, (match) {
      final trailingPath = match.group(
        1,
      ); // Extract the trailing path (e.g., "0", "1", "2")

      if (currentIndex == chosenPath) {
        currentIndex++; // Increment the index for the next match
        return '${privKey.substring(0, privKey.length - 4)}/$trailingPath/*';
      } else {
        currentIndex++; // Increment the index for the next match
        return match.group(
          0,
        )!; // Keep the original matched string for other paths
      }
    });

    return result;
  }

  (DescriptorSecretKey, DescriptorPublicKey) deriveDescriptorKeys(
    DerivationPath hardenedPath,
    DerivationPath unHardenedPath,
    Mnemonic mnemonic,
  ) {
    // Create the root secret key from the mnemonic
    final secretKey = DescriptorSecretKey(
      networkKind: settingsProvider.networkKind,
      mnemonic: mnemonic,
      password: null,
    );

    // Derive the key at the hardened path
    final derivedSecretKey = secretKey.derive(path: hardenedPath);

    // Extend the derived secret key further using the unhardened path
    final derivedExtendedSecretKey = derivedSecretKey.extend(
      path: unHardenedPath,
    );

    // Convert the derived secret key to its public counterpart
    final publicKey = derivedSecretKey.asPublic();

    // Extend the public key using the same unhardened path
    final derivedExtendedPublicKey = publicKey.extend(path: unHardenedPath);

    return (
      DescriptorSecretKey.fromString(privateKey: "$derivedExtendedSecretKey/*"),
      DescriptorPublicKey.fromString(publicKey: "$derivedExtendedPublicKey/*"),
    );
  }

  // Function to traverse and extract both the id and the path to the fingerprint
  List<Map<String, dynamic>> extractAllPathsToFingerprint(
    Map<String, dynamic> policy,
    String targetFingerprint,
  ) {
    List<Map<String, dynamic>> result = [];

    void traverse(dynamic node, List<int> currentPath, List<String> idPath) {
      if (node == null) return;

      // Check if the node itself has a matching fingerprint
      if (node['fingerprint'] == targetFingerprint) {
        result.add({
          'ids': [...idPath, node['id']],
          'indexes': currentPath,
        });
      }

      // Check if the node contains `keys` with matching fingerprints
      if (node['keys'] != null) {
        for (var key in node['keys']) {
          if (key['fingerprint'] == targetFingerprint) {
            result.add({
              'ids': [...idPath, node['id']],
              'indexes': currentPath,
            });
          }
        }
      }

      // Recursively traverse children if the node has `items`
      if (node['items'] != null) {
        for (int i = 0; i < node['items'].length; i++) {
          traverse(
            node['items'][i],
            [...currentPath, i],
            [...idPath, node['id']],
          );
        }
      }
    }

    // Start traversing from the root policy
    traverse(policy, [], []);

    return result;
  }

  List<Map<String, dynamic>> extractDataByFingerprint(
    Map<String, dynamic> json,
    String fingerprint,
  ) {
    List<Map<String, dynamic>> result = [];

    void traverse(
      Map<String, dynamic> node,
      List<String> path,
      List<dynamic>? parentItems,
    ) {
      // === Check for keys ===
      if (node['keys'] != null) {
        List<dynamic> keys = node['keys'];
        final matchingKeys = keys
            .where((key) => key['fingerprint'] == fingerprint)
            .toList();

        if (matchingKeys.isNotEmpty) {
          String type = node['type'];
          int? timelockValue;

          if (node['threshold'] != null) {
            type = "THRESH > $type";
          }

          // === Check sibling constraints ===
          if (parentItems != null) {
            for (var sibling in parentItems) {
              if (sibling['type'] == 'RELATIVETIMELOCK') {
                type = "RELATIVETIMELOCK > $type";

                timelockValue = sibling['value']['Blocks'];
              } else if (sibling['type'] == 'ABSOLUTETIMELOCK') {
                type = "ABSOLUTETIMELOCK > $type";
                timelockValue = sibling['value'];
              }
            }
          }

          final entry = {
            'type': type,
            'threshold': node['threshold'],
            'fingerprints': keys.map((key) => key['fingerprint']).toList(),
            'path': path.join(' > '),
            'timelock': timelockValue,
          };

          result.add(entry);
        }
      }

      // === Check for direct fingerprint match in ECDSASIGNATURE ===
      if (node['type'] == 'ECDSASIGNATURE' &&
          node['fingerprint'] == fingerprint) {
        String type = node['type'];
        int? timelockValue;

        if (parentItems != null) {
          for (var sibling in parentItems) {
            if (sibling['type'] == 'RELATIVETIMELOCK') {
              type = "RELATIVETIMELOCK > $type";

              timelockValue = sibling['value']['Blocks'];
            } else if (sibling['type'] == 'ABSOLUTETIMELOCK') {
              type = "ABSOLUTETIMELOCK > $type";
              timelockValue = sibling['value'];
            }
          }
        }

        final entry = {
          'type': type,
          'threshold': null,
          'fingerprints': [fingerprint],
          'path': path.join(' > '),
          'timelock': timelockValue,
        };

        result.add(entry);
      }

      // === Traverse child nodes ===
      if (node['items'] != null) {
        List<dynamic> items = node['items'];
        for (int i = 0; i < items.length; i++) {
          traverse(items[i], [...path, '${node['type']}[$i]'], items);
        }
      }
    }

    traverse(json, [], null);
    return result;
  }

  List<Map<String, dynamic>> extractAllPaths(Map<String, dynamic> json) {
    List<Map<String, dynamic>> result = [];

    void traverse(
      Map<String, dynamic> node,
      List<String> path,
      List<dynamic>? parentItems,
    ) {
      // Check if this node has keys
      if (node['keys'] != null) {
        List<dynamic> keys = node['keys'];
        List<String> fingerprints = keys
            .map((key) => key['fingerprint'] as String)
            .toList();

        // Determine the type and additional constraints
        String type = node['type'];
        int? timelockValue;

        if (node['threshold'] != null) {
          type = "THRESH > $type";
        }

        // Look for sibling constraints (e.g., RELATIVETIMELOCK)
        if (parentItems != null) {
          for (var sibling in parentItems) {
            if (sibling['type'] == 'RELATIVETIMELOCK') {
              type = "RELATIVETIMELOCK > $type";
              timelockValue = sibling['value']['Blocks'];
            } else if (sibling['type'] == 'ABSOLUTETIMELOCK') {
              type = "ABSOLUTETIMELOCK > $type";

              timelockValue = sibling['value'];
            }
          }
        }

        result.add({
          'type': type,
          'threshold': node['threshold'],
          'fingerprints': fingerprints,
          'path': path.join(' > '),
          'timelock': timelockValue,
        });
      }

      // Check if this node has a direct fingerprint reference (e.g., ECDSASIGNATURE)
      if (node['type'] == 'ECDSASIGNATURE') {
        String type = "ECDSASIGNATURE";
        int? timelockValue;

        // Look for sibling constraints (e.g., RELATIVETIMELOCK)
        if (parentItems != null) {
          for (var sibling in parentItems) {
            if (sibling['type'] == 'RELATIVETIMELOCK') {
              type = "RELATIVETIMELOCK > $type";

              timelockValue = sibling['value']['Blocks'];
            } else if (sibling['type'] == 'ABSOLUTETIMELOCK') {
              type = "ABSOLUTETIMELOCK > $type";

              timelockValue = sibling['value'];
            }
          }
        }

        result.add({
          'type': type,
          'threshold': null,
          'fingerprints': [node['fingerprint']],
          'path': path.join(' > '),
          'timelock': timelockValue,
        });
      }

      // Recursively traverse child nodes in "items"
      if (node['items'] != null) {
        List<dynamic> items = node['items'];

        for (int i = 0; i < items.length; i++) {
          traverse(
            {...items[i], 'parentItems': items},
            [...path, '${node['type']}[$i]'],
            items,
          );
        }
      }
    }

    traverse(json, [], null);

    return result;
  }

  List<String> extractSignersFromPsbt(Psbt psbt) {
    final serializedPsbt = psbt.jsonSerialize();

    // Parse JSON
    Map<String, dynamic> psbtDecoded = jsonDecode(serializedPsbt);

    // Map to store public key -> fingerprint
    Map<String, String> pubKeyToFingerprint = {};

    // Extract fingerprints from bip32_derivation
    if (psbtDecoded.containsKey('inputs')) {
      for (var input in psbtDecoded['inputs']) {
        if (input.containsKey('bip32_derivation')) {
          List<dynamic> bip32Derivations = input['bip32_derivation'];

          for (var derivation in bip32Derivations) {
            if (derivation.length >= 2) {
              String pubKey = derivation[0]; // Public Key
              String fingerprint =
                  derivation[1][0]; // First 4 bytes (fingerprint)

              // Store mapping
              pubKeyToFingerprint[pubKey] = fingerprint;
            }
          }
        }
      }
    }

    // List to store fingerprints of signing keys
    List<String> signingFingerprints = [];

    // Extract public keys from partial_sigs
    if (psbtDecoded.containsKey('inputs')) {
      for (var input in psbtDecoded['inputs']) {
        if (input.containsKey('partial_sigs')) {
          Map<String, dynamic> partialSigs = input['partial_sigs'];

          partialSigs.forEach((pubKey, sigData) {
            if (pubKeyToFingerprint.containsKey(pubKey)) {
              // Store fingerprint if the pubKey has signed
              signingFingerprints.add(pubKeyToFingerprint[pubKey]!);
            }
          });
        }
      }
    }

    return signingFingerprints.toSet().toList();
  }

  Map<String, dynamic> extractSpendingPathFromPsbt(
    Psbt psbt,
    List<Map<String, dynamic>> spendingPaths,
  ) {
    final serializedPsbt = psbt.jsonSerialize();

    // Parse JSON
    final Map<String, dynamic> psbtDecoded = jsonDecode(serializedPsbt);

    if (!psbtDecoded.containsKey("unsigned_tx") ||
        !psbtDecoded["unsigned_tx"].containsKey("input")) {
      throw Exception("Invalid PSBT format or missing inputs.");
    }

    final inputs = (psbtDecoded["unsigned_tx"]["input"] as List).cast<Map>();

    final sequenceValues = inputs.map((i) => i["sequence"] as int).toSet();

    if (sequenceValues.length != 1) {
      throw Exception("Mismatched sequence values in inputs.");
    }

    final sequence = sequenceValues.first;

    // --- NEW: Inspect partial_sigs and map to derivation paths (for debug) ---
    final inputObjs = (psbtDecoded["inputs"] as List?) ?? const [];
    for (var idx = 0; idx < inputObjs.length; idx++) {
      final inp = inputObjs[idx] as Map;
      final derivs = (inp["bip32_derivation"] as List?) ?? const [];
      final derivMap = <String, String>{}; // pubkey -> path
      for (final d in derivs) {
        try {
          final pub = d[0] as String;
          final path = (d[1] as List)[1] as String;
          derivMap[pub] = path;
        } catch (_) {}
      }
    }

    if (sequence == 4294967294) {
      // 1) Collect signer derivation 'change' values from partial_sigs ↔ bip32_derivation
      final inputObjs = (psbtDecoded["inputs"] as List?) ?? const [];
      final signerChanges = <int>{};

      for (var inIdx = 0; inIdx < inputObjs.length; inIdx++) {
        final inp = inputObjs[inIdx] as Map;
        final derivs = (inp["bip32_derivation"] as List?) ?? const [];
        final derivMap =
            <String, String>{}; // pubkey -> "m/.../<change>/<index>"
        for (final d in derivs) {
          try {
            final pub = d[0] as String;
            final path = (d[1] as List)[1] as String;
            derivMap[pub] = path;
          } catch (_) {}
        }

        final sigs =
            (inp["partial_sigs"] as Map?)?.cast<String, dynamic>() ?? const {};
        sigs.forEach((pubkey, _) {
          final path = derivMap[pubkey];
          if (path != null) {
            try {
              final segs = path.split('/');
              // BIP84: m / 84' / coin' / acct' / change / index
              if (segs.length >= 6) {
                final changeStr = segs[4].replaceAll("'", "");
                final change = int.parse(changeStr);
                signerChanges.add(change);
              }
            } catch (_) {}
          }
        });
      }

      // 2) If exactly one change value, try to use it as spendingPaths index
      if (signerChanges.length == 1) {
        final changeVal = signerChanges.first;
        if (changeVal >= 0 && changeVal < spendingPaths.length) {
          final candidate = spendingPaths[changeVal];
          return candidate;
        }
      }

      // 3) Fallback: original MULTISIG heuristic
      return spendingPaths.firstWhere(
        (path) {
          return path["type"].toString().toUpperCase().contains("MULTISIG");
        },
        orElse: () =>
            throw Exception("No matching multisig spending path found."),
      );
    } else {
      return spendingPaths.firstWhere(
        (path) {
          return path["timelock"] != null && path["timelock"] == sequence;
        },
        orElse: () {
          throw Exception("No matching timelock spending path found.");
        },
      );
    }
  }

  List<String> getAliasesFromFingerprint(
    List<Map<String, String>> pubKeysAlias,
    List<String> signers,
  ) {
    // Initialize an empty map for public key aliases
    Map<String, String> pubKeysAliasMap = {};

    // Flatten the list of maps into a single map
    for (var map in pubKeysAlias) {
      if (map.containsKey("publicKey") && map.containsKey("alias")) {
        String publicKeyRaw = map["publicKey"]
            .toString(); // e.g. "[42e5d2a0/84'/1'/0']tpubDC..."
        String alias = map["alias"].toString();

        // Extract fingerprint (inside brackets)
        RegExp regex = RegExp(r"\[(.*?)\]");
        Match? match = regex.firstMatch(publicKeyRaw);

        if (match != null) {
          String fingerprint = match
              .group(1)!
              .split("/")[0]; // Extract first part (fingerprint)

          pubKeysAliasMap[fingerprint] = alias; // Store the mapping
        }
      }
    }

    // Initialize list for signer aliases
    List<String> signersAliases = [];

    // Match fingerprints to aliases
    for (String fingerprint in signers) {
      if (pubKeysAliasMap.containsKey(fingerprint)) {
        String alias = pubKeysAliasMap[fingerprint]!;
        signersAliases.add(alias);
      } else {
        signersAliases.add("Unknown ($fingerprint)");
      }
    }

    return signersAliases;
  }

  bool _isImmediateMultisig(Map<String, dynamic>? p) {
    if (p == null) {
      return false;
    }

    final type = (p['type'] as String?) ?? '';
    final hasTimelock = p['timelock'] != null;
    final threshold = p['threshold'] is int ? p['threshold'] as int : null;

    final looksMulti =
        type.contains('MULTISIG') || (threshold != null && threshold > 1);

    final result = looksMulti && !hasTimelock;

    return result;
  }

  Map<String, dynamic>? _pathAt(List paths, int i) {
    if (i < 0 || i >= paths.length) return null;
    final v = paths[i];
    return (v is Map<String, dynamic>) ? v : null;
  }

  Future<String?> createPartialTx(
    String descriptor,
    String mnemonic,
    String recipientAddressStr,
    int amount,
    int? chosenPath,
    int avBalance, {
    bool isSendAllBalance = false,
    List<Map<String, dynamic>>? spendingPaths,
    double? customFeeRate,
    List<dynamic>? localUtxos,
  }) async {
    Map<String, Uint32List>? multiSigPath;
    Map<String, Uint32List>? timeLockPath;

    Mnemonic trueMnemonic = Mnemonic.fromString(mnemonic: mnemonic);

    DerivationPath hardenedDerivationPath;

    if (settingsProvider.network == Network.bitcoin) {
      if (oldCase) {
        hardenedDerivationPath = DerivationPath(path: "m/84h/1h/0h");
      } else {
        hardenedDerivationPath = DerivationPath(path: "m/84h/0h/0h");
      }
    } else {
      hardenedDerivationPath = DerivationPath(path: "m/84h/1h/0h");
    }

    final receivingDerivationPath = DerivationPath(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    // Extract the content inside square brackets
    final RegExp regex = RegExp(r'\[([^\]]+)\]');
    final Match? match = regex.firstMatch(receivingPublicKey.toString());
    final String targetFingerprint = match!.group(1)!.split('/')[0];

    final correctPath = _pathAt(spendingPaths!, chosenPath!);

    descriptor = _isImmediateMultisig(correctPath)
        ? replacePubKeyWithPrivKeyMultiSig(
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          )
        : replacePubKeyWithPrivKeyOlder(
            chosenPath,
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          );

    wallet = await createSharedWallet(descriptor);

    final List<ConnectivityResult> connectivityResult = await (Connectivity()
        .checkConnectivity());

    final Balance utxos;
    int totalSpending;

    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (!isSendAllBalance) {
        totalSpending = amount;

        if (avBalance < totalSpending) {
          throw Exception(
            "Not enough confirmed funds available. Please wait until your transactions confirm.",
          );
        }
      }
    } else {
      await syncWallet(wallet);

      utxos = wallet.balance();

      if (!isSendAllBalance) {
        totalSpending = amount;

        if (utxos.trustedSpendable.toSat() < totalSpending) {
          throw Exception(
            "Not enough confirmed funds available. Please wait until your transactions confirm.",
          );
        }
      }
    }

    final feeRate = customFeeRate ?? await getFeeRate();

    List<OutPoint> spendableOutpoints = [];

    try {
      var txBuilder = TxBuilder();

      final recipientAddress = Address(
        address: recipientAddressStr,
        network: wallet.network(),
      );
      final recipientScript = recipientAddress.scriptPubkey();

      var internalChangeAddress = wallet.peekAddress(
        keychain: KeychainKind.external_,
        index: 0,
      );
      final changeScript = internalChangeAddress.address.scriptPubkey();

      final Policy externalWalletPolicy = wallet.policies(
        keychain: KeychainKind.external_,
      )!;

      final Map<String, dynamic> policy = jsonDecode(
        externalWalletPolicy.asString(),
      );

      final path = extractAllPathsToFingerprint(policy, targetFingerprint);

      if (_isImmediateMultisig(correctPath)) {
        multiSigPath = {
          for (int i = 0; i < path[0]["ids"].length - 1; i++)
            path[0]["ids"][i]: Uint32List.fromList([path[0]["indexes"][i]]),
        };
      } else {
        timeLockPath = {
          for (int i = 0; i < path[chosenPath]["ids"].length - 1; i++)
            path[chosenPath]["ids"][i]: Uint32List.fromList(
              i == path[chosenPath]["ids"].length - 2
                  ? [0, 1]
                  : [path[chosenPath]["indexes"][i]],
            ),
        };
      }

      final Psbt txBuilderResult;

      if (isSendAllBalance) {
        try {
          if (_isImmediateMultisig(correctPath)) {
            txBuilder
                .addRecipient(
                  script: recipientScript,
                  amount: Amount.fromSat(satoshi: amount),
                )
                .policyPath(
                  policyPath: multiSigPath!,
                  keychain: KeychainKind.internal,
                )
                .policyPath(
                  policyPath: multiSigPath,
                  keychain: KeychainKind.external_,
                )
                .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()))
                .finish(wallet: wallet);
          } else {
            txBuilder
                .addRecipient(
                  script: recipientScript,
                  amount: Amount.fromSat(satoshi: amount),
                )
                .policyPath(
                  policyPath: timeLockPath!,
                  keychain: KeychainKind.internal,
                )
                .policyPath(
                  policyPath: timeLockPath,
                  keychain: KeychainKind.external_,
                )
                .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()))
                .finish(wallet: wallet);
          }
          return amount.toString();
        } catch (e) {
          final utxos = await getUtxos();

          List<dynamic> spendableUtxos = [];

          if (_isImmediateMultisig(correctPath)) {
            spendableUtxos = utxos;
          } else {
            final timelock = spendingPaths[chosenPath]['timelock'];

            int currentHeight = await fetchCurrentBlockHeight();

            final type = spendingPaths[chosenPath]['type']
                .toString()
                .toLowerCase();

            spendableUtxos = utxos.where((utxo) {
              final blockHeight = utxo['status']['block_height'];

              bool isSpendable = false;
              if (type.contains('relativetimelock')) {
                isSpendable =
                    blockHeight != null &&
                    (blockHeight + timelock - 1 <= currentHeight ||
                        timelock == 0);
              } else if (type.contains('absolutetimelock')) {
                isSpendable = timelock <= currentHeight;
              } else {
                isSpendable = true;
              }

              return isSpendable;
            }).toList();
          }

          final totalSpendableBalance = spendableUtxos.fold<int>(
            0,
            (sum, utxo) => sum + (int.parse(utxo['value'].toString())),
          );

          if (e.toString().contains("Insufficient funds:")) {
            // More flexible regex that extracts both BTC amounts
            final RegExp regex = RegExp(
              r'([\d.]+)\s*BTC\s+available.*?([\d.]+)\s*BTC\s+needed',
            );
            final match = regex.firstMatch(e.toString());

            if (match != null) {
              final double availableBTC = double.parse(match.group(1)!);
              final double neededBTC = double.parse(match.group(2)!);

              final int availableAmount = (availableBTC * 100000000).round();
              final int neededAmount = (neededBTC * 100000000).round();

              final int fee = neededAmount - availableAmount;
              final int sendAllBalance = totalSpendableBalance - fee;

              if (sendAllBalance > 0) {
                return sendAllBalance.toString();
              } else {
                throw Exception('No balance available after fee deduction');
              }
            } else {
              throw Exception(
                'Failed to extract amounts from exception: ${e.toString()}',
              );
            }
          } else {
            rethrow;
          }
        }
      }

      final utxos = localUtxos ?? await getUtxos();

      if (_isImmediateMultisig(correctPath)) {
        spendableOutpoints = utxos
            .map(
              (utxo) => OutPoint(
                txid: Txid.fromString(hex: utxo['txid']),
                vout: utxo['vout'],
              ),
            )
            .toList();
      } else {
        final timelock = spendingPaths[chosenPath]['timelock'];

        final type = spendingPaths[chosenPath]['type'].toString().toLowerCase();

        int currentHeight = await fetchCurrentBlockHeight();

        spendableOutpoints = utxos
            .where((utxo) {
              final blockHeight = utxo['status']['block_height'];

              bool isSpendable = false;
              if (type.contains('relativetimelock')) {
                isSpendable =
                    blockHeight != null &&
                    (blockHeight + timelock - 1 <= currentHeight ||
                        timelock == 0);
              } else if (type.contains('absolutetimelock')) {
                isSpendable = timelock <= currentHeight;
              } else {
                isSpendable = true;
              }

              return isSpendable;
            })
            .map(
              (utxo) => OutPoint(
                txid: Txid.fromString(hex: utxo['txid']),
                vout: utxo['vout'],
              ),
            )
            .toList();
      }

      if (_isImmediateMultisig(correctPath)) {
        try {
          txBuilderResult = txBuilder
              .addRecipient(
                script: recipientScript,
                amount: Amount.fromSat(satoshi: amount),
              )
              .drainWallet()
              .policyPath(
                policyPath: multiSigPath!,
                keychain: KeychainKind.internal,
              )
              .policyPath(
                policyPath: multiSigPath,
                keychain: KeychainKind.external_,
              )
              .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()))
              .drainTo(script: changeScript)
              .finish(wallet: wallet);
        } catch (e) {
          rethrow;
        }
      } else {
        txBuilderResult = txBuilder
            .addRecipient(
              script: recipientScript,
              amount: Amount.fromSat(satoshi: amount),
            )
            .drainWallet()
            .policyPath(
              policyPath: timeLockPath!,
              keychain: KeychainKind.internal,
            )
            .policyPath(
              policyPath: timeLockPath,
              keychain: KeychainKind.external_,
            )
            .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()))
            .drainTo(script: changeScript)
            .finish(wallet: wallet);
      }

      try {
        final signed = wallet.sign(
          psbt: txBuilderResult,
          signOptions: SignOptions(
            trustWitnessUtxo: false,
            allowAllSighashes: true,
            tryFinalize: true,
            signWithTapInternalKey: true,
            allowGrinding: true,
          ),
        );

        if (signed) {
          final tx = txBuilderResult.extractTx();

          ElectrumClient? client;
          bool broadcastSuccess = false;

          for (final server in electrumServers) {
            try {
              client = ElectrumClient(
                url: server,
                retry: null,
                socks5: null,
                timeout: null,
                validateDomain: true,
              );
              client.transactionBroadcast(tx: tx);
              broadcastSuccess = true;
              break;
            } catch (e) {
              throw Exception("Broadcast failed for $server: $e");
            } finally {
              client?.dispose();
            }
          }

          if (!broadcastSuccess) {
            throw Exception("Failed to broadcast to any Electrum server");
          }

          return null;
        } else {
          final psbtString = txBuilderResult.serialize();

          final jsonContent = {
            "psbt": psbtString,
            "spending_path": correctPath,
          };

          final jsonString = jsonEncode(jsonContent);

          return jsonString;
        }
      } catch (broadcastError) {
        throw Exception("Broadcasting error: ${broadcastError.toString()}");
      }
    } on Exception catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  Future<String?> createBackupTx(
    String descriptor,
    String mnemonic,
    String recipientAddressStr,
    int amount,
    int? chosenPath,
    int avBalance, {
    bool isSendAllBalance = false,
    List<Map<String, dynamic>>? spendingPaths,
    double? customFeeRate,
    List<dynamic>? localUtxos,
  }) async {
    Map<String, Uint32List>? multiSigPath;
    Map<String, Uint32List>? timeLockPath;

    Mnemonic trueMnemonic = Mnemonic.fromString(mnemonic: mnemonic);
    DerivationPath hardenedDerivationPath;

    if (settingsProvider.network == Network.bitcoin) {
      if (oldCase) {
        hardenedDerivationPath = DerivationPath(path: "m/84h/1h/0h");
      } else {
        hardenedDerivationPath = DerivationPath(path: "m/84h/0h/0h");
      }
    } else {
      hardenedDerivationPath = DerivationPath(path: "m/84h/1h/0h");
    }
    final receivingDerivationPath = DerivationPath(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    // Extract the content inside square brackets
    final RegExp regex = RegExp(r'\[([^\]]+)\]');
    final Match? match = regex.firstMatch(receivingPublicKey.toString());

    final String targetFingerprint = match!.group(1)!.split('/')[0];

    final correctPath = _pathAt(spendingPaths!, chosenPath!);

    descriptor = (_isImmediateMultisig(correctPath))
        ? replacePubKeyWithPrivKeyMultiSig(
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          )
        : replacePubKeyWithPrivKeyOlder(
            chosenPath,
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          );

    wallet = await createSharedWallet(descriptor);

    final List<ConnectivityResult> connectivityResult = await (Connectivity()
        .checkConnectivity());

    final Balance utxos;

    int totalSpending;

    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (!isSendAllBalance) {
        totalSpending = amount;
        // Check If there are enough funds available
        if (avBalance < totalSpending) {
          // Exit early if no confirmed UTXOs are available
          throw Exception(
            "Not enough confirmed funds available. Please wait until your transactions confirm.",
          );
        }
      }
    } else {
      await syncWallet(wallet);
      utxos = wallet.balance();

      if (!isSendAllBalance) {
        totalSpending = amount;
        // Check If there are enough funds available
        if (utxos.trustedSpendable.toSat() < totalSpending) {
          // Exit early if no confirmed UTXOs are available
          throw Exception(
            "Not enough confirmed funds available. Please wait until your transactions confirm.",
          );
        }
      }
    }

    final feeRate = customFeeRate ?? await getFeeRate();

    List<OutPoint> spendableOutpoints = [];

    try {
      // Build the transaction
      var txBuilder = TxBuilder();

      final recipientAddress = Address(
        address: recipientAddressStr,
        network: wallet.network(),
      );
      final recipientScript = recipientAddress.scriptPubkey();

      var internalChangeAddress = wallet.peekAddress(
        keychain: KeychainKind.internal,
        index: 0,
      );

      final changeScript = internalChangeAddress.address.scriptPubkey();

      final Policy externalWalletPolicy = wallet.policies(
        keychain: KeychainKind.external_,
      )!;

      final Map<String, dynamic> policy = jsonDecode(
        externalWalletPolicy.asString(),
      );

      final path = extractAllPathsToFingerprint(policy, targetFingerprint);

      if (_isImmediateMultisig(correctPath)) {
        // First Path: Direct MULTISIG
        multiSigPath = {
          for (int i = 0; i < path[0]["ids"].length - 1; i++)
            path[0]["ids"][i]: Uint32List.fromList([path[0]["indexes"][i]]),
        };
      } else {
        timeLockPath = {
          for (int i = 0; i < path[chosenPath]["ids"].length - 1; i++)
            path[chosenPath]["ids"][i]: Uint32List.fromList(
              i ==
                      path[chosenPath]["ids"].length -
                          2 // Check if it's the second-to-last item
                  ? [0, 1] // Select both indexes for the last `THRESH` node
                  : [path[chosenPath]["indexes"][i]],
            ),
        };
      }

      // Build the transaction:
      final Psbt txBuilderResult;

      if (isSendAllBalance) {
        try {
          if (_isImmediateMultisig(correctPath)) {
            txBuilder
                .addRecipient(
                  script: recipientScript,
                  amount: Amount.fromSat(satoshi: amount),
                )
                .policyPath(
                  policyPath: multiSigPath!,
                  keychain: KeychainKind.internal,
                )
                .policyPath(
                  policyPath: multiSigPath,
                  keychain: KeychainKind.external_,
                )
                .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()))
                .finish(wallet: wallet);
          } else {
            txBuilder
                .addRecipient(
                  script: recipientScript,
                  amount: Amount.fromSat(satoshi: amount),
                )
                .policyPath(
                  policyPath: timeLockPath!,
                  keychain: KeychainKind.internal,
                )
                .policyPath(
                  policyPath: timeLockPath,
                  keychain: KeychainKind.external_,
                )
                .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()))
                .finish(wallet: wallet);
          }

          return amount.toString();
        } catch (e) {
          final utxos = await getUtxos();

          List<dynamic> spendableUtxos = [];

          if (_isImmediateMultisig(correctPath)) {
            spendableUtxos = utxos;
          } else {
            spendableUtxos = utxos.where((utxo) {
              final status = utxo['status'];
              final confirmed = status != null && status['confirmed'] == true;

              return confirmed;
            }).toList();
          }

          // Sum the value of spendable UTXOs
          final totalSpendableBalance = spendableUtxos.fold<int>(
            0,
            (sum, utxo) => sum + (int.parse(utxo['value'].toString())),
          );

          // Handle insufficient funds
          if (e.toString().contains("Insufficient funds:")) {
            // More flexible regex that extracts both BTC amounts
            final RegExp regex = RegExp(
              r'([\d.]+)\s*BTC\s+available.*?([\d.]+)\s*BTC\s+needed',
            );
            final match = regex.firstMatch(e.toString());

            if (match != null) {
              final double availableBTC = double.parse(match.group(1)!);
              final double neededBTC = double.parse(match.group(2)!);

              final int availableAmount = (availableBTC * 100000000).round();
              final int neededAmount = (neededBTC * 100000000).round();

              final int fee = neededAmount - availableAmount;
              final int sendAllBalance = totalSpendableBalance - fee;

              if (sendAllBalance > 0) {
                return sendAllBalance.toString();
              } else {
                throw Exception('No balance available after fee deduction');
              }
            } else {
              throw Exception(
                'Failed to extract amounts from exception: ${e.toString()}',
              );
            }
          } else {
            rethrow;
          }
        }
      }

      final utxos = localUtxos ?? await getUtxos();

      if (_isImmediateMultisig(correctPath)) {
        spendableOutpoints = utxos
            .map(
              (utxo) => OutPoint(
                txid: Txid.fromString(hex: utxo['txid']),
                vout: utxo['vout'],
              ),
            )
            .toList();
      } else {
        final timelock = spendingPaths[chosenPath]['timelock'];

        final type = spendingPaths[chosenPath]['type'].toString().toLowerCase();

        int currentHeight = await fetchCurrentBlockHeight();

        // Filter spendable UTXOs
        spendableOutpoints = utxos
            .where((utxo) {
              final blockHeight = utxo['status']['block_height'];

              bool isSpendable = false;

              if (type.contains('relativetimelock')) {
                isSpendable =
                    blockHeight != null &&
                    (blockHeight + timelock - 1 <= currentHeight ||
                        timelock == 0);
              } else if (type.contains('absolutetimelock')) {
                isSpendable = timelock <= currentHeight;
              } else {
                // No timelock type; assume spendable
                isSpendable = true;
              }

              return isSpendable;
            })
            .map(
              (utxo) => OutPoint(
                txid: Txid.fromString(hex: utxo['txid']),
                vout: utxo['vout'],
              ),
            )
            .toList();
      }

      if (_isImmediateMultisig(correctPath)) {
        try {
          txBuilderResult = txBuilder
              .addRecipient(
                script: recipientScript,
                amount: Amount.fromSat(satoshi: amount),
              )
              .drainWallet()
              .policyPath(
                policyPath: multiSigPath!,
                keychain: KeychainKind.internal,
              )
              .policyPath(
                policyPath: multiSigPath,
                keychain: KeychainKind.external_,
              )
              .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()))
              .drainTo(script: changeScript)
              .finish(wallet: wallet);
        } catch (e) {
          rethrow;
        }
      } else {
        txBuilderResult = txBuilder
            .addRecipient(
              script: recipientScript,
              amount: Amount.fromSat(satoshi: amount),
            ) // Send to recipient
            .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
            .policyPath(
              policyPath: timeLockPath!,
              keychain: KeychainKind.internal,
            )
            .policyPath(
              policyPath: timeLockPath,
              keychain: KeychainKind.external_,
            )
            .feeRate(
              feeRate: FeeRate.fromSatPerVb(satVb: feeRate.toInt()),
            ) // Set the fee rate (in satoshis per byte)
            .drainTo(
              script: changeScript,
            ) // Specify the address to send the change
            .finish(
              wallet: wallet,
            ); // Finalize the transaction with wallet's UTXOs
      }

      try {
        wallet.sign(
          psbt: txBuilderResult,
          signOptions: SignOptions(
            trustWitnessUtxo: false,
            allowAllSighashes: true,
            tryFinalize: true,
            signWithTapInternalKey: true,
            allowGrinding: true,
          ),
        );

        final tx = txBuilderResult.extractTx();

        final serialized = tx.serialize();

        // Convert bytes to hex string
        final rawHex = hex.encode(serialized);

        return rawHex;
      } catch (broadcastError) {
        throw Exception("Broadcasting error: ${broadcastError.toString()}");
      }
    } on Exception catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  // This method takes a PSBT, signs it with the second user and then broadcasts it
  Future<String?> signBroadcastTx(
    String psbtString,
    String descriptor,
    String mnemonic,
    Map<String, dynamic> correctPath,
    List<Map<String, dynamic>>? spendingPaths,
  ) async {
    Mnemonic trueMnemonic = Mnemonic.fromString(mnemonic: mnemonic);
    DerivationPath hardenedDerivationPath;

    if (settingsProvider.network == Network.bitcoin) {
      if (oldCase) {
        hardenedDerivationPath = DerivationPath(path: "m/84h/1h/0h");
      } else {
        hardenedDerivationPath = DerivationPath(path: "m/84h/0h/0h");
      }
    } else {
      hardenedDerivationPath = DerivationPath(path: "m/84h/1h/0h");
    }
    final receivingDerivationPath = DerivationPath(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    final index = spendingPaths!.indexWhere(
      (path) => const DeepCollectionEquality().equals(path, correctPath),
    );

    descriptor = (_isImmediateMultisig(correctPath))
        ? replacePubKeyWithPrivKeyMultiSig(
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          )
        : replacePubKeyWithPrivKeyOlder(
            index,
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          );

    wallet = await createSharedWallet(descriptor);

    await syncWallet(wallet);

    // Convert the psbt String to a PartiallySignedTransaction
    final psbt = Psbt(psbtBase64: psbtString);

    try {
      final signed = wallet.sign(
        psbt: psbt,
        signOptions: SignOptions(
          trustWitnessUtxo: false,
          allowAllSighashes: true,
          tryFinalize: true,
          signWithTapInternalKey: true,
          allowGrinding: true,
        ),
      );

      if (signed) {
        final tx = psbt.extractTx();

        ElectrumClient? client;

        for (final server in electrumServers) {
          try {
            // Pick the right server for the network you're on
            client = ElectrumClient(
              url: server,
              socks5: null,
              timeout: null,
              retry: null,
              validateDomain: true,
            );

            final txid = client.transactionBroadcast(tx: tx);
          } catch (e) {
            rethrow;
          } finally {
            client?.dispose();
          }
        }
      } else {
        final jsonContent = {
          "psbt": psbt.serialize(),
          "spending_path": correctPath,
        };

        final jsonString = jsonEncode(jsonContent);

        return jsonString;
      }

      return null;
    } on Exception catch (e) {
      throw Exception("Error: ${e.toString()} psbt: $psbt");
    }
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// UTILITIES
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  void printInChunks(String text, {int chunkSize = 800}) {
    for (int i = 0; i < text.length; i += chunkSize) {
      print(
        text.substring(
          i,
          i + chunkSize > text.length ? text.length : i + chunkSize,
        ),
      );
    }
  }

  void printPrettyJson(String jsonString) {
    final jsonObject = json.decode(jsonString);
    const encoder = JsonEncoder.withIndent('  ');
    printInChunks(encoder.convert(jsonObject));
  }

  void printPsbtJson(String serializedPsbt) {
    final jsonObject = json.decode(serializedPsbt);

    // Pretty-print JSON with indentation
    final prettyJson = JsonEncoder.withIndent('  ').convert(jsonObject);

    print(prettyJson);
  }

  String generateRandomName() {
    final random = Random();

    // Get random nouns and adjectives from the package
    final adjective = WordPair.random().first;
    final noun = WordPair.random().second;

    return '${adjective.capitalize()}${noun.capitalize()}${random.nextInt(1000)}';
  }

  String formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds} seconds';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} minutes';
    } else {
      return '${duration.inHours} hours';
    }
  }
}

// Used to generate a random SharedWallet descriptorName
extension StringExtension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
}

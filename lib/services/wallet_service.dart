import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:bdk_flutter/bdk_flutter.dart';
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
/// This class provides a comprehensive suite of tools for managing Bitcoin wallets
/// using the `bdk_flutter` library. It supports both single and shared wallet functionalities,
/// descriptor-based wallet management, transaction creation, and interaction with blockchain
/// APIs like Mempool.space. The class also handles wallet synchronization, balance retrieval,
/// and multi-signature (multisig) wallets.
///
/// **INDEX**
///
/// **Common Methods**
/// - **`isValidDescriptor`**: Validates a wallet descriptor.
/// - **`getBalance`**: Retrieves the total balance from a wallet.
/// - **`getLedgerBalance`**: Fetches the ledger balance for a given address.
/// - **`getAvailableBalance`**: Fetches the available balance for a given address.
/// - **`loadSavedWallet`**: Restores a wallet using a saved mnemonic.
/// - **`syncWallet`**: Synchronizes a wallet with the blockchain.
/// - **`getAddress`**: Retrieves the current receiving address from a wallet.
/// - **`blockchainInit`**: Initializes a connection to the blockchain via an Electrum server.
/// - **`fetchCurrentBlockHeight`**: Fetches the current block height from the blockchain.
/// - **`calculateRemainingTimeInSeconds`**: Calculates the remaining time for a specific number of blocks.
/// - **`formatTime`**: Formats a duration in seconds into a human-readable format.
/// - **`getUtxos`**: Fetches the unspent transaction outputs (UTXOs) for a given address.
///
/// **Single Wallet**
/// - **`createOrRestoreWallet`**: Creates or restores a single-user wallet from a mnemonic.
/// - **`calculateSendAllBalance`**: Computes the maximum amount that can be sent after deducting fees.
/// - **`sendSingleTx`**: Creates, signs, and broadcasts a single-user transaction.
///
/// **Shared Wallet**
/// - **`createSharedWallet`**: Creates a wallet for multi-signature use.
/// - **`createWalletDescriptor`**: Generates a descriptor for shared wallets with time-lock and multisig conditions.
/// - **`createPartialTx`**: Creates a partially signed Bitcoin transaction (PSBT) for shared wallets.
/// - **`signBroadcastTx`**: Signs a PSBT with the second user and broadcasts it to the blockchain.
///
/// **Utilities**
/// - **`printInChunks`**: Prints long strings in chunks for readability.
/// - **`printPrettyJson`**: Pretty-prints JSON strings for debugging.
/// - **`checkCondition`**: Checks whether a specific condition is met for UTXO spending.
///
/// **Blockchain Interaction**
/// - **`getFeeRate`**: Retrieves the current recommended fee rate for transactions.
/// - **`getTransactions`**: Fetches transaction history for a given address.
///
/// **Multi-signature Utilities**
/// - **`replacePubKeyWithPrivKeyMultiSig`**: Replaces public keys with private keys in a multisig descriptor.
/// - **`replacePubKeyWithPrivKeyOlder`**: Replaces public keys with private keys in timelocked descriptors.
/// - **`extractOlderWithPrivateKey`**: Extracts the "older" value from a descriptor and associates it with private keys.
///
/// **Descriptor Key Derivation**
/// - **`deriveDescriptorKeys`**: Derives descriptor secret and public keys based on a derivation path and mnemonic.
///
/// **Policy and Path Extraction**
/// - **`extractAllPathsToFingerprint`**: Extracts all policy paths to a specific fingerprint.
/// - **`extractDataByFingerprint`**: Extracts data related to a specific fingerprint from the wallet policy.
/// - **`extractAllPaths`**: Extracts all policy paths from a wallet descriptor.
///
/// **Data Storage**
/// - **`saveLocalData`**: Saves wallet-related data, such as balances and transactions, to local storage.

const int avgBlockTime = 600;

// const bool isTest = true;

class WalletService extends ChangeNotifier {
  final WalletStorageService _walletStorageService = WalletStorageService();
  final SettingsProvider settingsProvider;

  WalletService(this.settingsProvider);

  late Wallet wallet;
  late Blockchain blockchain;

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
    final endpoints =
        network == Network.testnet ? testnetEndpoints : mainnetEndpoints;

    for (final endpoint in endpoints) {
      try {
        // Quick health check(HEAD or simple GET)
        final response = await http
            .get(Uri.parse('${endpoint}blocks/tip/height'))
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          // print("✅ Using endpoint: $endpoint");
          return endpoint;
        }
      } catch (e) {
        print("⚠️ Failed endpoint: $endpoint → $e");
      }
    }

    throw Exception("No available endpoint for $network");
  }

  Future<String> get baseUrl async {
    return await getWorkingEndpoint(settingsProvider.network);
  }

  // TODO: TESTNET3
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

  // TODO: TESTNET4
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
    String publicKey,
    BuildContext context,
  ) async {
    try {
      // print('🔐 Validating descriptor...');
      // print('📬 Public Key: $publicKey');
      // print('🧾 Descriptor (full):');
      // printInChunks(descriptorStr);

      final last3 = publicKey.substring(0, publicKey.length - 3);
      // print('🔍 Checking if descriptor contains pubkey: "$last3"');

      if (descriptorStr.contains(last3)) {
        // print('✅ Match found. Attempting to create descriptor...');

        final descriptor = await Descriptor.create(
          descriptor: descriptorStr,
          network: settingsProvider.network,
        );

        // print('🏗️ Descriptor created successfully.');

        // print('💾 Attempting to create wallet in memory...');
        await Wallet.create(
          descriptor: descriptor,
          network: settingsProvider.network,
          databaseConfig: const DatabaseConfig.memory(),
        );
        // print('🎉 Wallet creation successful.');

        return ValidationResult(isValid: true);
      } else {
        // print('❌ Descriptor does NOT contain expected public key fragment.');
        return ValidationResult(
          isValid: false,
          errorMessage: AppLocalizations.of(
            context,
          )!
              .translate('error_public_key_not_contained'),
        );
      }
    } catch (e) {
      print('💥 Error during descriptor/wallet creation: $e');
      return ValidationResult(
        isValid: false,
        errorMessage: AppLocalizations.of(
          context,
        )!
            .translate('error_wallet_descriptor'),
      );
    }
  }

  BigInt getBalance(Wallet wallet) {
    // await syncWallet(wallet);
    Balance balance = wallet.getBalance();

    // print(balance.total);

    return balance.total;
  }

  Future<bool> checkMnemonic(String mnemonic) async {
    try {
      final descriptors = await getDescriptors(mnemonic);

      await Wallet.create(
        descriptor: descriptors[0],
        changeDescriptor: descriptors[1],
        network: settingsProvider.network,
        databaseConfig: const DatabaseConfig.memory(),
      );

      return true;
    } catch (e) {
      // print("Error: ${e.toString()}");
      return false;
    }
  }

  Future<Wallet> loadSavedWallet({String? mnemonic}) async {
    var walletBox = Hive.box('walletBox');
    String? savedMnemonic = walletBox.get('walletMnemonic');

    // print(savedMnemonic);

    if (savedMnemonic != null) {
      // Restore the wallet using the saved mnemonic
      wallet = await createOrRestoreWallet(savedMnemonic);
      // print(wallet);
      return wallet;
    } else {
      wallet = await createOrRestoreWallet(mnemonic!);
    }
    return wallet;
  }

  Future<void> syncWallet(Wallet wallet) async {
    try {
      await blockchainInit(); // Ensure blockchain is initialized before usage

      // print('Blockchain initialized');

      await wallet.sync(blockchain: blockchain);
    } catch (e) {
      throw Exception("Blockchain initialization failed: ${e.toString()}");
    }
  }

  String getAddress(Wallet wallet) {
    // await syncWallet(wallet);

    var addressInfo = wallet.getAddress(
      addressIndex: const AddressIndex //
          .increase(),
      // .peek(index: 0),
    );

    // print('New Address generated: ${addressInfo.address.asString()}');

    return addressInfo.address.asString();
  }

  /// Fetches and calculates confirmed & pending balance
  Future<Map<String, int>> getBitcoinBalance(String address) async {
    await syncWallet(wallet);
    try {
      final int confirmedBalance = int.parse(
        wallet.getBalance().spendable.toString(),
      );

      // print('confirmedBalance: $confirmedBalance');

      final int pendingBalance = int.parse(
        wallet.getBalance().untrustedPending.toString(),
      );

      // print('pendingBalance: $pendingBalance');

      return {
        "confirmedBalance": confirmedBalance,
        "pendingBalance": pendingBalance,
      };
    } catch (e) {
      print("Error fetching balance: $e");
      return {"confirmedBalance": 0, "pendingBalance": 0};
    }
  }

  Future<int> calculateSendAllBalance({
    required String recipientAddress,
    required Wallet wallet,
    required BigInt availableBalance,
    required WalletService walletService,
    double? customFeeRate,
  }) async {
    try {
      final feeRate = customFeeRate ?? await getFeeRate();

      // print(customFeeRate);
      // print(feeRate);
      // print(availableBalance);

      final recipient = await Address.fromString(
        s: recipientAddress,
        network: settingsProvider.network,
      );
      final recipientScript = recipient.scriptPubkey();

      final txBuilder = TxBuilder();

      await txBuilder
          .addRecipient(recipientScript, availableBalance)
          .feeRate(feeRate)
          .finish(wallet);

      return availableBalance
          .toInt(); // If no exception occurs, return available balance
    } catch (e) {
      print(e);
      // Handle insufficient funds

      if (e.toString().contains("InsufficientFundsException")) {
        print(e);
        final RegExp regex = RegExp(r'Needed: (\d+), Available: (\d+)');
        final match = regex.firstMatch(e.toString());
        if (match != null) {
          final int neededAmount = int.parse(match.group(1)!);
          final int availableAmount = int.parse(match.group(2)!);
          final int fee = neededAmount - availableAmount;
          final int sendAllBalance = availableBalance.toInt() - fee;

          if (sendAllBalance > 0) {
            return sendAllBalance; // Return adjusted send all balance
          } else {
            throw Exception('No balance available after fee deduction');
          }
        } else {
          throw Exception('Failed to extract Needed amount from exception');
        }
      } else {
        rethrow; // Re-throw unhandled exceptions
      }
    }
  }

  // Use the first available server in the list
  Future<void> blockchainInit() async {
    for (var url in electrumServers) {
      try {
        blockchain = await Blockchain.create(
          config: BlockchainConfig.electrum(
            config: ElectrumConfig(
              url: url,
              timeout: 5,
              retry: 5,
              stopGap: BigInt.from(10),
              validateDomain: true,
            ),
          ),
        );
        // print("Connected to Electrum server: $url");
        return;
      } catch (e) {
        print(
          "Error: $e Failed to connect to Electrum server: $url, trying next...",
        );
      }
    }
    throw Exception("Failed to connect to any Electrum server.");
  }

  Future<double> getFeeRate() async {
    try {
      final response = await http.get(
        Uri.parse("${await baseUrl}/v1/fees/recommended"),
      );

      if (response.statusCode == 200) {
        final fees = jsonDecode(response.body);
        return fees['halfHourFee'].toDouble(); // Use mempool.space's fee
      } else {
        throw ('Error: $e');
      }
    } catch (e) {
      print("Mempool API failed, falling back to default: $e");
      throw ('Mempool API failed, falling back to default');
    }
  }

  Future<Map<String, double>?> fetchRecommendedFees() async {
    // Get whatever you already return from your helper (with or without trailing slash)
    final String base = await baseUrl;
    Uri join(String path) {
      final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      return Uri.parse('$b$path');
    }

    // Attempt 1: mempool-style endpoint
    final candidates = <Uri>[
      join('/v1/fees/recommended'),
      // Attempt 2: blockstream-style endpoint
      join('/fee-estimates'),
    ];

    Map<String, double>? parsed;

    for (final uri in candidates) {
      try {
        final resp = await http.get(uri);
        if (resp.statusCode != 200) {
          // Try next candidate
          continue;
        }

        final dynamic json = jsonDecode(resp.body);

        // Case A: mempool recommended shape
        if (json is Map && json.containsKey('fastestFee')) {
          final fastest = (json['fastestFee'] as num?)?.toDouble();
          final halfHour = (json['halfHourFee'] as num?)?.toDouble();
          final hour = (json['hourFee'] as num?)?.toDouble();
          if (fastest != null && halfHour != null && hour != null) {
            parsed = {
              'fastestFee': fastest,
              'halfHourFee': halfHour,
              'hourFee': hour,
            };
            break;
          }
        }

        // Case B: blockstream fee-estimates shape: {"1": 87.882, "2": ...}
        if (json is Map<String, dynamic>) {
          double? get(Map<String, dynamic> m, String k) {
            final v = m[k];
            if (v is num) return v.toDouble();
            if (v is String) return double.tryParse(v);
            return null;
          }

          // Preferred direct lookups
          double? f1 = get(json, '1');
          double? f3 = get(json, '3');
          double? f6 = get(json, '6');

          // If any are missing, pick the closest available target among the known keys
          double? closest(int target) {
            // keys include 1-25, 144, 504, 1008
            // We’ll search exact first, then the nearest greater, then nearest lower.
            final keys = <int>[];
            for (final k in json.keys) {
              final n = int.tryParse(k);
              if (n != null) keys.add(n);
            }
            if (keys.isEmpty) return null;
            keys.sort();

            double? readFor(int t) {
              final exact = get(json, '$t');
              if (exact != null) return exact;
              // nearest >= target
              final ge = keys.firstWhere(
                (k) => k >= t,
                orElse: () => -1,
              );
              if (ge != -1) {
                final v = get(json, '$ge');
                if (v != null) return v;
              }
              // nearest <= target
              for (int i = keys.length - 1; i >= 0; i--) {
                if (keys[i] <= t) {
                  final v = get(json, '${keys[i]}');
                  if (v != null) return v;
                }
              }
              return null;
            }

            return readFor(target);
          }

          f1 ??= closest(1);
          f3 ??= closest(3);
          f6 ??= closest(6);

          if (f1 != null && f3 != null && f6 != null) {
            parsed = {
              'fastestFee': f1,
              'halfHourFee': f3,
              'hourFee': f6,
            };
            break;
          }
        }

        // If we got here, this candidate didn't produce the shape we need; try next
      } catch (e) {
        // Network/parse error → try next candidate
        // print('fetchRecommendedFees error for $uri: $e');
        continue;
      }
    }

    if (parsed == null) {
      print('Failed to fetch fee estimates from available endpoints.');
    }

    return parsed;
  }

  Future<List<Map<String, dynamic>>> getTransactions(String address) async {
    final results = wallet.listTransactions(includeRaw: true);

    List<Map<String, dynamic>> finalTxs = [];

    for (var tx in results) {
      final url = '${await baseUrl}/tx/${tx.txid}';

      try {
        // print(url);

        // Send the GET request to the API
        final response = await http.get(Uri.parse(url));

        // Check if the response was successful
        if (response.statusCode == 200) {
          // Parse the JSON response
          Map<String, dynamic> txJson = jsonDecode(response.body);

          // Do not add 'index' key — use the list index instead
          finalTxs.add(txJson);
        } else {
          throw Exception(
            'Failed to load transactions. Status Code: ${response.statusCode}',
          );
        }
      } catch (e) {
        throw Exception('Failed to fetch transactions: $e');
      }
    }

    // printInChunks('txsnew: $finalTxs');

    return finalTxs;
  }

  // Future<List<Map<String, dynamic>>> getTransactions(String address) async {
  //   try {
  //     // Construct the URL
  //     final url = '${await baseUrl}/address/$address/txs';

  //     print(url);

  //     // Send the GET request to the API
  //     final response = await http.get(Uri.parse(url));

  //     // Check if the response was successful
  //     if (response.statusCode == 200) {
  //       // Parse the JSON response
  //       List<dynamic> transactionsJson = jsonDecode(response.body);

  //       printInChunks(
  //           'txsold: ${List<Map<String, dynamic>>.from(transactionsJson)}');

  //       // Cast to List<Map<String, dynamic>> for easier processing
  //       return List<Map<String, dynamic>>.from(transactionsJson);
  //     } else {
  //       throw Exception(
  //         'Failed to load transactions. Status Code: ${response.statusCode}',
  //       );
  //     }
  //   } catch (e) {
  //     throw Exception('Failed to fetch transactions: $e');
  //   }
  // }

  Future<int> fetchCurrentBlockHeight() async {
    // print(await blockchain.getHeight());

    return blockchain.getHeight();
  }

  Future<String> fetchBlockTimestamp(int height) async {
    try {
      String currentHash = await blockchain.getBlockHash(height: height);
      // print('currentHash: $currentHash');

      // API endpoint to fetch block details
      final String blockApiUrl = '${await baseUrl}/block/$currentHash';

      // print(blockApiUrl);

      // Make GET request to fetch block details
      final response = await http.get(Uri.parse(blockApiUrl));

      if (response.statusCode == 200) {
        // Decode JSON response
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // Check if data contains the `time` field
        if (jsonData.containsKey('timestamp')) {
          int timestamp = jsonData['timestamp']; // Extract timestamp

          // print('timestamp from method: $timestamp');

          DateTime formattedTime =
              DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          if (settingsProvider.isTestnet) {
            formattedTime = formattedTime.subtract(const Duration(hours: 2));
          }

          return formattedTime
              .toString()
              .substring(0, formattedTime.toString().length - 7);
        } else {
          print('Error: "timestamp" field not found in response.');
          throw Exception('Block API response missing timestamp field.');
        }
      } else {
        // Handle HTTP errors for block details API
        print('HTTP Error (Block API): ${response.statusCode}');
        throw Exception('HTTP Error (Block API): ${response.statusCode}');
      }
    } catch (e) {
      // Handle any unexpected exceptions
      print('Exception occurred: $e');
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

    for (var utxo in walletUtxos) {
      final txid = utxo.outpoint.txid;
      final vout = utxo.outpoint.vout;
      final value = utxo.txout.value;

      try {
        final txResponse =
            await http.get(Uri.parse('${await baseUrl}/tx/$txid'));

        if (txResponse.statusCode == 200) {
          final txData = json.decode(txResponse.body);

          final status = {
            'confirmed': txData['status']['confirmed'],
            'block_height': txData['status']['block_height'],
            'block_hash': txData['status']['block_hash'],
            'block_time': txData['status']['block_time'],
          };

          finalUtxos.add({
            'txid': txid,
            'vout': vout,
            'status': status,
            'value': value,
          });

          // print('[DEBUG] Decoded UTXOs: $finalUtxos');
        } else {
          print('[ERROR] Failed to fetch tx $txid: ${txResponse.statusCode}');
        }
      } catch (e) {
        print('[EXCEPTION] While fetching tx $txid: $e');
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

    // print(
    //     "[WalletService.checkCondition] → type=$type, timelock=$rawTimelock (norm=$timelock), "
    //     "amount='$amount' ($requiredAmount), height=$currentHeight, utxos=${utxos.length}");

    // MULTISIG with no timelock: keep your original short-circuit
    final isMultisigNoTimelock =
        type.contains('MULTISIG') && rawTimelock == null;
    if (isMultisigNoTimelock) {
      // print("[WalletService.checkCondition] MULTISIG (no timelock) → TRUE");
      return true;
    }

    final isAbsolute =
        type.contains('ABSOLUTETIMELOCK'); // CLTV / AFTER <height>
    final isRelative =
        type.contains('RELATIVETIMELOCK'); // CSV / OLDER <blocks>

    double totalSpendable = 0.0;

    if (isAbsolute) {
      // CLTV: path is unlocked iff chain height reached/passed absolute height
      final pathUnlocked = (timelock == 0) || (currentHeight >= timelock);
      // print(
      //     "[WalletService.checkCondition] ABSOLUTE (AFTER height=$timelock) → "
      //     "currentHeight($currentHeight) >= timelock($timelock)? $pathUnlocked");

      if (!pathUnlocked) {
        // print(
        //     "[WalletService.checkCondition] REASON: absolute height not reached.");
        return false;
      }

      // If unlocked, all UTXOs are eligible (no per-UTXO CSV needed)
      for (var i = 0; i < utxos.length; i++) {
        final utxoValueRaw = utxos[i]['value'] ?? 0.0;
        final v = double.tryParse(utxoValueRaw.toString()) ?? 0.0;
        totalSpendable += v;
        // print(
        //     "[WalletService.checkCondition]   ABS add UTXO[$i] value=$v → total=$totalSpendable");
      }
    } else if (isRelative) {
      // CSV: per-UTXO confirmations must reach 'timelock'
      for (var i = 0; i < utxos.length; i++) {
        final status =
            (utxos[i]['status'] is Map) ? utxos[i]['status'] as Map : const {};
        final blockHeight = status['block_height'] ?? 0; // 0 → unconfirmed
        final utxoValueRaw = utxos[i]['value'] ?? 0.0;
        final v = double.tryParse(utxoValueRaw.toString()) ?? 0.0;

        final hasHeight = blockHeight is int && blockHeight > 0;
        final confirmations = hasHeight ? (currentHeight - blockHeight) : 0;
        final spendable =
            (timelock == 0) ? true : (hasHeight && confirmations >= timelock);

        // print("[WalletService.checkCondition] RELATIVE UTXO[$i] "
        //     "bh=$blockHeight, conf=$confirmations, need=$timelock → spendable=$spendable, value=$v");

        if (spendable) {
          totalSpendable += v;
          // print(
          //     "[WalletService.checkCondition]   CSV add → total=$totalSpendable");
        }
      }
    } else {
      // Fallback (unknown type): keep old conservative per-UTXO rule
      // print(
      //     "[WalletService.checkCondition] Unknown type → fallback CSV-style per-UTXO check");
      for (var i = 0; i < utxos.length; i++) {
        final status =
            (utxos[i]['status'] is Map) ? utxos[i]['status'] as Map : const {};
        final blockHeight = status['block_height'] ?? 0;
        final utxoValueRaw = utxos[i]['value'] ?? 0.0;
        final v = double.tryParse(utxoValueRaw.toString()) ?? 0.0;

        final spendable =
            (timelock == 0) || (blockHeight + timelock <= currentHeight);
        // print(
        //     "[WalletService.checkCondition] FALLBACK UTXO[$i] bh=$blockHeight, "
        //     "bh+timelock=${blockHeight + timelock} <= $currentHeight ? $spendable, value=$v");
        if (spendable) {
          totalSpendable += v;
        }
      }
    }

    final decision = totalSpendable >= requiredAmount;
    // print("[WalletService.checkCondition] totalSpendable=$totalSpendable "
    //     "vs required=$requiredAmount → DECISION=$decision");
    // if (!decision) {
    //   print(
    //       "[WalletService.checkCondition] REASON: insufficient spendable for chosen path.");
    // }
    return decision;
  }

  Future<bool> areEqualAddresses(List<TxOut> outputs) async {
    Address? firstAddress;

    for (final output in outputs) {
      final testAddress = await Address.fromScript(
        script: ScriptBuf(bytes: output.scriptPubkey.bytes),
        network: settingsProvider.network,
      );

      if (firstAddress == null) {
        // Store the first address for comparison
        firstAddress = testAddress;
      } else if (testAddress.asString() != firstAddress.asString()) {
        // If an address does not match the first one, set the flag to false
        return false;
      }
    }
    return true;
  }

  Future<Address> getAddressFromScriptOutput(TxOut output) {
    // print('Output: ${output.scriptPubkey.asString()}');

    return Address.fromScript(
      script: ScriptBuf(bytes: output.scriptPubkey.bytes),
      network: settingsProvider.network,
    );
  }

  Future<Address> getAddressFromScriptInput(TxIn input) {
    // print(input.previousOutput);

    // print("         script: ${input.scriptSig}");
    // print("         previousOutout Txid: ${input.previousOutput.txid}");
    // print("         previousOutout vout: ${input.previousOutput.vout}");
    // print("         witness: ${input.witness}");
    return Address.fromScript(
      script: ScriptBuf(bytes: input.scriptSig!.bytes),
      network: settingsProvider.network,
    );
  }

  void validateAddress(String address) async {
    try {
      await Address.fromString(s: address, network: settingsProvider.network);
    } on AddressException catch (e) {
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
      // print(response.body);
      final data = json.decode(response.body);
      final btcToCurrency = data[currency]['buy'];
      final satoshiToCurrency = (btcToCurrency / 100000000) * satoshis;

      return double.parse(satoshiToCurrency.toStringAsFixed(2));
    } else {
      throw Exception('Failed to fetch conversion rate');
    }
  }

  List<Map<String, dynamic>> sortTransactionsByConfirmations(
    List<Map<String, dynamic>> transactions,
    int currentHeight,
  ) {
    transactions.sort((a, b) {
      // Extract block height values (if null, assume unconfirmed)
      final blockHeightA = a['status']?['block_height'];
      final blockHeightB = b['status']?['block_height'];

      // Extract the number of confirmations for comparison
      // Determine confirmations (if unconfirmed, set to -1 to prioritize them first)
      final confirmationsA =
          (blockHeightA != null) ? currentHeight - blockHeightA : -1;
      final confirmationsB =
          (blockHeightB != null) ? currentHeight - blockHeightB : -1;

      int result = confirmationsA.compareTo(confirmationsB);

      // Sort by number of confirmations in descending order (highest first)
      return result;
    });

    return transactions;
  }

  List<String> findNewTransactions(
    List<Map<String, dynamic>> apiTransactions,
    List<TransactionDetails> walletTransactions,
  ) {
    // Extract transaction IDs from both sources
    List<String> apiTxIds = apiTransactions
        .map((tx) => tx['txid'].toString().toLowerCase())
        .toList();
    List<String> walletTxIds = walletTransactions
        .map((tx) => tx.txid.toString().toLowerCase())
        .toList();
    // print("🔎 Checking for new transactions...");

    // Find new transactions
    List<String> newTransactions =
        walletTxIds.where((txid) => !apiTxIds.contains(txid)).toList();

    // Debugging Output
    // print("✅ Total API Transactions: ${apiTransactions.length}");
    // printInChunks(apiTxIds.toString());

    // print("✅ Total Wallet Transactions: ${walletTxIds.length}");
    // printInChunks(walletTxIds.toString());

    // if (newTransactions.isNotEmpty) {
    //   print("🆕 New Transactions Found: ${newTransactions.length}");

    //   print("🆕 New Transactions Detected: ${newTransactions.join(", ")}");
    // } else {
    //   print("✅ No new transactions.");
    // }

    return newTransactions;
  }

  Future<DescriptorPublicKey?> getpubkey(
    Map<String, Future<DescriptorPublicKey?>> pubKeyFutures,
    String mnemonic,
  ) {
    if (!pubKeyFutures.containsKey(mnemonic)) {
      pubKeyFutures[mnemonic] = fetchPubKey(mnemonic);
    }
    return pubKeyFutures[mnemonic]!;
  }

  Future<DescriptorPublicKey?> fetchPubKey(String mnemonic) async {
    final trueMnemonic = await Mnemonic.fromString(mnemonic);

    final hardenedDerivationPath = await DerivationPath.create(
      path: "m/84h/1h/0h",
    );

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = await deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    return receivingPublicKey;
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
      final descriptors = await getDescriptors(mnemonic);

      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        await blockchainInit();
      }

      final res = await Wallet.create(
        descriptor: descriptors[0],
        changeDescriptor: descriptors[1],
        network: settingsProvider.network,
        databaseConfig: const DatabaseConfig.memory(),
      );
      // var addressInfo =
      //     await res.getAddress(addressIndex: const AddressIndex());

      // print(res);

      return res;
    } on Exception catch (e) {
      // print("Error: ${e.toString()}");
      throw Exception('Failed to create wallet (Error: ${e.toString()})');
    }
  }

  Future<List<Descriptor>> getDescriptors(String mnemonic) async {
    final descriptors = <Descriptor>[];
    try {
      for (var e in [KeychainKind.externalChain, KeychainKind.internalChain]) {
        final mnemonicObj = await Mnemonic.fromString(mnemonic);

        final descriptorSecretKey = await DescriptorSecretKey.create(
          network: settingsProvider.network,
          mnemonic: mnemonicObj,
        );

        final descriptor = await Descriptor.newBip84(
          secretKey: descriptorSecretKey,
          network: settingsProvider.network,
          keychain: e,
        );

        descriptors.add(descriptor);
      }
      return descriptors;
    } on Exception catch (e) {
      // print("Error: ${e.toString()}");
      throw ("Error: ${e.toString()}");
    }
  }

  // Method to create, sign and broadcast a single user transaction
  Future<void> sendSingleTx(
    String recipientAddressStr,
    BigInt amount,
    Wallet wallet,
    String changeAddressStr,
    double? customFeeRate,
  ) async {
    await syncWallet(wallet);

    // final utxos = wallet.getBalance();
    // print("Available UTXOs: ${utxos.total.toInt()}");
    // print(wallet.getAddress(addressIndex: AddressIndex.peek(index: 0)));

    try {
      // Build the transaction
      final txBuilder = TxBuilder();

      final recipientAddress = await Address.fromString(
        s: recipientAddressStr,
        network: wallet.network(),
      );
      final recipientScript = recipientAddress.scriptPubkey();

      final changeAddress = await Address.fromString(
        s: changeAddressStr,
        network: wallet.network(),
      );
      final changeScript = changeAddress.scriptPubkey();

      final feeRate = customFeeRate ?? await getFeeRate();

      // Build the transaction:
      // - Send `amount` to the recipient
      // - Any remaining funds (change) will be sent to the change address
      final txBuilderResult = await txBuilder
          .enableRbf()
          .addRecipient(recipientScript, amount) // Send to recipient
          .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
          .feeRate(feeRate) // Set the fee rate (in satoshis per byte)
          .drainTo(
            changeScript,
          ) // Specify the custom address to send the change
          .finish(wallet); // Finalize the transaction with wallet's UTXOs

      // Sign the transaction
      final isFinalized = wallet.sign(psbt: txBuilderResult.$1);

      // Broadcast the transaction only if it is finalized
      if (isFinalized) {
        final tx = txBuilderResult.$1.extractTx();
        // Broadcast the transaction to the network only if it is finalized
        await blockchain.broadcast(transaction: tx);
      }
    } on Exception catch (e) {
      print("Error: ${e.toString()}");
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

  Future<Wallet> createSharedWallet(String descriptor) async {
    // print(settingsProvider.network);

    Descriptor descriptorReal = await Descriptor.create(
      descriptor: descriptor,
      network: settingsProvider.network,
    );

    // print("Checksum Descriptor");
    // printInChunks(descriptorReal.asString());

    wallet = await Wallet.create(
      descriptor: descriptorReal,
      network: settingsProvider.network,
      databaseConfig: const DatabaseConfig.memory(),
    );

    return wallet;
  }

  Future<void> saveLocalData(
    Wallet wallet,
    DateTime lastRefreshed,
    Set<String> myAddresses,
  ) async {
    String currentAddress = getAddress(wallet);

    String walletId = wallet
        .getAddress(addressIndex: AddressIndex.peek(index: 0))
        .address
        .asString();

    final totalBalance = await getBitcoinBalance(currentAddress);
    final availableBalance = totalBalance['confirmedBalance'];
    final ledgerBalance = totalBalance['pendingBalance'];
    final currentHeight = await fetchCurrentBlockHeight();
    final timestamp = await fetchBlockTimestamp(currentHeight);

    List<Map<String, dynamic>> transactions =
        await getTransactions(currentAddress);
    transactions = sortTransactionsByConfirmations(transactions, currentHeight);

    final walletData = WalletData(
      address: currentAddress,
      balance: int.parse(getBalance(wallet).toString()),
      ledgerBalance: ledgerBalance!,
      availableBalance: availableBalance!,
      transactions: transactions,
      currentHeight: currentHeight,
      timeStamp: timestamp,
      utxos: await getUtxos(),
      lastRefreshed: lastRefreshed,
      myAddresses: myAddresses,
    );

    // Save the data to Hive
    await _walletStorageService.saveWalletData(walletId, walletData);
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
    // print('------------Replacing------------');
    // printInChunks('Descriptor Before Replacement:\n$descriptor');
    // print('Chosen Path Index: $chosenPath');
    // print('Public Key: $pubKey');
    // print('Private Key: ${privKey.substring(0, privKey.length - 4)}');

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

      // Debugging info for each match
      // print('Match Found: ${match.group(0)}');
      // print('Trailing Path Extracted: $trailingPath');
      // print('Current Match Index: $currentIndex');

      if (currentIndex == chosenPath) {
        // print(
        //     'Replacing with Private Key: ${privKey.substring(0, privKey.length - 4)}/$trailingPath/*');
        currentIndex++; // Increment the index for the next match
        return '${privKey.substring(0, privKey.length - 4)}/$trailingPath/*';
      } else {
        // print('Keeping Original Public Key: ${match.group(0)}');
        currentIndex++; // Increment the index for the next match
        return match.group(
          0,
        )!; // Keep the original matched string for other paths
      }
    });

    // printInChunks('Descriptor After Replacement:\n$result');
    // print('------------Replacement Complete------------');

    return result;
  }

  Future<(DescriptorSecretKey, DescriptorPublicKey)> deriveDescriptorKeys(
    DerivationPath hardenedPath,
    DerivationPath unHardenedPath,
    Mnemonic mnemonic,
  ) async {
    // print("🔐 Starting key derivation process...");
    // print("🧠 Mnemonic: $mnemonic");
    // print("📌 Network: ${settingsProvider.network}");
    // print("📍 Hardened path: $hardenedPath");
    // print("📍 Unhardened path: $unHardenedPath");

    // Create the root secret key from the mnemonic
    final secretKey = await DescriptorSecretKey.create(
      network: settingsProvider.network,
      mnemonic: mnemonic,
    );
    // print("✅ Root secret key created: ${secretKey.asString()}");

    // Derive the key at the hardened path
    final derivedSecretKey = secretKey.derive(hardenedPath);
    // print("📍 Derived hardened secret key: ${derivedSecretKey.asString()}");

    // Extend the derived secret key further using the unhardened path
    final derivedExtendedSecretKey = derivedSecretKey.extend(unHardenedPath);
    // print("🔁 Extended secret key: ${derivedExtendedSecretKey.asString()}");

    // Convert the derived secret key to its public counterpart
    final publicKey = derivedSecretKey.toPublic();
    // print("🔓 Public key from hardened key: ${publicKey.asString()}");

    // Extend the public key using the same unhardened path
    final derivedExtendedPublicKey = publicKey.extend(path: unHardenedPath);
    // print("🔁 Extended public key: ${derivedExtendedPublicKey.asString()}");

    // print("✅ Key derivation complete");

    return (derivedExtendedSecretKey, derivedExtendedPublicKey);
  }

  // Function to traverse and extract both the id and the path to the fingerprint
  List<Map<String, dynamic>> extractAllPathsToFingerprint(
    Map<String, dynamic> policy,
    String targetFingerprint,
  ) {
    List<Map<String, dynamic>> result = [];

    void traverse(dynamic node, List<int> currentPath, List<String> idPath) {
      if (node == null) return;

      // // Debugging: Print the current node and paths being processed
      // print('Traversing Node: ${node['id'] ?? 'No ID'}');
      // print('Current Path: $currentPath');
      // print('ID Path: $idPath');

      // Check if the node itself has a matching fingerprint
      if (node['fingerprint'] == targetFingerprint) {
        // print('Match Found in Node: ${node['id']}');
        result.add({
          'ids': [...idPath, node['id']],
          'indexes': currentPath,
        });
      }

      // Check if the node contains `keys` with matching fingerprints
      if (node['keys'] != null) {
        for (var key in node['keys']) {
          // print('Checking Key Fingerprint: ${key['fingerprint']}');
          if (key['fingerprint'] == targetFingerprint) {
            // print('Match Found in Keys: Adding Path');
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
          // print('Traversing Child at Index: $i');
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

    // print('Final Result: $result');
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
      // print("\n🔍 Traversing node: ${node['id'] ?? 'Unknown ID'}");
      // print("📍 Current path: ${path.join(' > ')}");
      // print(
      //     "📦 Node type: ${node['type']}, Keys: ${node['keys']?.length ?? 0}, Items: ${node['items']?.length ?? 0}");

      // === Check for keys ===
      if (node['keys'] != null) {
        // print("🔑 Node has keys. Checking for fingerprint matches...");
        List<dynamic> keys = node['keys'];
        final matchingKeys =
            keys.where((key) => key['fingerprint'] == fingerprint).toList();

        if (matchingKeys.isNotEmpty) {
          // print("✅ Fingerprint match found in keys!");

          String type = node['type'];
          int? timelockValue;

          if (node['threshold'] != null) {
            type = "THRESH > $type";
            // print("🔢 Threshold detected. Adjusted type: $type");
          }

          // === Check sibling constraints ===
          if (parentItems != null) {
            for (var sibling in parentItems) {
              if (sibling['type'] == 'RELATIVETIMELOCK') {
                type = "RELATIVETIMELOCK > $type";
                timelockValue = sibling['value'];
                // print(
                //     "⏱️ RELATIVETIMELOCK detected. Updated type: $type | Timelock: $timelockValue");
              } else if (sibling['type'] == 'ABSOLUTETIMELOCK') {
                type = "ABSOLUTETIMELOCK > $type";
                timelockValue = sibling['value'];
                // print(
                //     "🕰️ ABSOLUTETIMELOCK detected. Updated type: $type | Timelock: $timelockValue");
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
          // print("📥 Added to result: $entry");
        } else {
          // print("❌ No fingerprint match in keys.");
        }
      }

      // === Check for direct fingerprint match in ECDSASIGNATURE ===
      if (node['type'] == 'ECDSASIGNATURE' &&
          node['fingerprint'] == fingerprint) {
        // print("🖊️ Direct fingerprint match in ECDSASIGNATURE node.");

        String type = node['type'];
        int? timelockValue;

        if (parentItems != null) {
          for (var sibling in parentItems) {
            if (sibling['type'] == 'RELATIVETIMELOCK') {
              type = "RELATIVETIMELOCK > $type";
              timelockValue = sibling['value'];
              // print(
              //     "⏱️ RELATIVETIMELOCK affects ECDSASIGNATURE. Timelock: $timelockValue");
            } else if (sibling['type'] == 'ABSOLUTETIMELOCK') {
              type = "ABSOLUTETIMELOCK > $type";
              timelockValue = sibling['value'];
              // print(
              //     "🕰️ ABSOLUTETIMELOCK affects ECDSASIGNATURE. Timelock: $timelockValue");
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
        // print("📥 Added ECDSASIGNATURE to result: $entry");
      }

      // === Traverse child nodes ===
      if (node['items'] != null) {
        // print("🔁 Traversing ${node['items'].length} child items...");
        List<dynamic> items = node['items'];
        for (int i = 0; i < items.length; i++) {
          traverse(
            items[i],
            [...path, '${node['type']}[$i]'],
            items,
          );
        }
      } else {
        // print("🚫 No child items.");
      }
    }

    // print("🚀 Starting fingerprint extraction for: $fingerprint\n");
    traverse(json, [], null);
    // print("\n✅ Traversal complete. Total matches: ${result.length}");
    return result;
  }

  List<Map<String, dynamic>> extractAllPaths(Map<String, dynamic> json) {
    List<Map<String, dynamic>> result = [];

    void traverse(
      Map<String, dynamic> node,
      List<String> path,
      List<dynamic>? parentItems,
    ) {
      // print(
      //     "Traversing node: ${node['id'] ?? 'Unknown ID'}, Path: ${path.join(' > ')}");

      // Check if this node has keys
      if (node['keys'] != null) {
        // print("Checking keys in node: ${node['id'] ?? 'Unknown ID'}");
        List<dynamic> keys = node['keys'];
        List<String> fingerprints =
            keys.map((key) => key['fingerprint'] as String).toList();

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
              timelockValue = sibling['value']; // Capture the timelock value
            } else if (sibling['type'] == 'ABSOLUTETIMELOCK') {
              type = "ABSOLUTETIMELOCK > $type";
              timelockValue = sibling['value'];
            }
          }
        }

        // print("Path found in node: ${node['id'] ?? 'Unknown ID'}");
        result.add({
          'type': type, // Type reflects sibling constraints
          'threshold': node['threshold'],
          'fingerprints': fingerprints,
          'path': path.join(' > '),
          'timelock': timelockValue,
        });
        // print("Added to result: ${result.last}");
      }

      // Check if this node has a direct fingerprint reference (e.g., ECDSASIGNATURE)
      if (node['type'] == 'ECDSASIGNATURE') {
        // print("Checking ECDSASIGNATURE in node: ${node['id'] ?? 'Unknown ID'}");
        String type = "ECDSASIGNATURE";
        int? timelockValue;

        // Look for sibling constraints (e.g., RELATIVETIMELOCK)
        if (parentItems != null) {
          for (var sibling in parentItems) {
            if (sibling['type'] == 'RELATIVETIMELOCK') {
              type = "RELATIVETIMELOCK > $type";
              timelockValue = sibling['value']; // Capture the timelock value
            } else if (sibling['type'] == 'ABSOLUTETIMELOCK') {
              type = "ABSOLUTETIMELOCK > $type";
              timelockValue = sibling['value'];
            }
          }
        }

        result.add({
          'type': type,
          'threshold': null, // No threshold for ECDSASIGNATURE
          'fingerprints': [node['fingerprint']], // Single fingerprint
          'path': path.join(' > '),
          'timelock': timelockValue,
        });
        // print("Added ECDSASIGNATURE to result: ${result.last}");
      }

      // Recursively traverse child nodes in "items"
      if (node['items'] != null) {
        // print(
        //     "Node has child items: ${node['items'].length} found in node: ${node['id'] ?? 'Unknown ID'}");
        List<dynamic> items = node['items'];
        for (int i = 0; i < items.length; i++) {
          traverse(
            {
              ...items[i],
              'parentItems': items, // Pass sibling items as context
            },
            [...path, '${node['type']}[$i]'],
            items,
          );
        }
      } else {
        // print("No child items in node: ${node['id'] ?? 'Unknown ID'}");
      }
    }

    // print("Starting traversal for all paths");
    traverse(json, [], null);
    // print("Traversal complete. Results: $result");
    return result;
  }

  List<String> extractSignersFromPsbt(PartiallySignedTransaction psbt) {
    final serializedPsbt = psbt.jsonSerialize();

    // printPrettyJson(serializedPsbt);
    // printInChunks(psbt.asString());

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

    // Print fingerprints of signing public keys
    // print("Fingerprints of signing public keys: $signingFingerprints");

    return signingFingerprints.toSet().toList();
  }

  Map<String, dynamic> extractSpendingPathFromPsbt(
    PartiallySignedTransaction psbt,
    List<Map<String, dynamic>> spendingPaths,
  ) {
    final serializedPsbt = psbt.jsonSerialize();
    // print("Serialized PSBT: $serializedPsbt");

    // Parse JSON
    final Map<String, dynamic> psbtDecoded = jsonDecode(serializedPsbt);
    printInChunks("Decoded PSBT: $psbtDecoded");

    if (!psbtDecoded.containsKey("unsigned_tx") ||
        !psbtDecoded["unsigned_tx"].containsKey("input")) {
      throw Exception("Invalid PSBT format or missing inputs.");
    }

    final inputs = (psbtDecoded["unsigned_tx"]["input"] as List).cast<Map>();
    // print("Inputs: $inputs");

    final sequenceValues = inputs.map((i) => i["sequence"] as int).toSet();
    // print("Sequence values: $sequenceValues");

    if (sequenceValues.length != 1) {
      throw Exception("Mismatched sequence values in inputs.");
    }

    final sequence = sequenceValues.first;
    // print("Final sequence: $sequence");

    // --- NEW: Inspect partial_sigs and map to derivation paths (for debug) ---
    final inputObjs = (psbtDecoded["inputs"] as List?) ?? const [];
    for (var idx = 0; idx < inputObjs.length; idx++) {
      final inp = inputObjs[idx] as Map;
      final derivs = (inp["bip32_derivation"] as List?) ?? const [];
      final derivMap = <String, String>{}; // pubkey -> path
      for (final d in derivs) {
        // d is like ["<pubkey>", ["<fingerprint>", "m/84'/1'/0'/0/0"]]
        try {
          final pub = d[0] as String;
          final path = (d[1] as List)[1] as String;
          derivMap[pub] = path;
        } catch (_) {}
      }

      // final sigs =
      //     (inp["partial_sigs"] as Map?)?.cast<String, dynamic>() ?? const {};
      // if (sigs.isNotEmpty) {
      //   // print("Input[$idx] partial_sigs count: ${sigs.length}");
      //   sigs.forEach((pubkey, sigInfo) {
      //     final path = derivMap[pubkey];
      //     final fp = path == null
      //         ? null
      //         : (derivs.firstWhere(
      //             (d) => d[0] == pubkey,
      //             orElse: () => null,
      //           ) as List?)?[1]?[0];
      //     // print("  ↳ signer pubkey: $pubkey");
      //     if (path != null) {
      //       // Try to infer the BIP84 'change' (…/change/index)
      //       String branchHint = "";
      //       try {
      //         final segs = path.split('/');
      //         // m / 84' / coin' / acct' / change / index
      //         if (segs.length >= 6) {
      //           final change = segs[4].replaceAll("'", "");
      //           final index = segs[5].replaceAll("'", "");
      //           branchHint = " (change=$change, index=$index)";
      //         }
      //       } catch (_) {}
      //       print(
      //           "     derivation: $path$branchHint${fp != null ? " (fp $fp)" : ""}");
      //     } else {
      //       print("     derivation: <not found in bip32_derivation>");
      //     }
      //     final sigHex = (sigInfo is Map && sigInfo["sig"] != null)
      //         ? sigInfo["sig"]
      //         : "<no sig>";
      //     final hashTy = (sigInfo is Map && sigInfo["hash_ty"] != null)
      //         ? sigInfo["hash_ty"]
      //         : "<none>";
      //     print("     sig hash_ty: $hashTy");
      //     print(
      //         "     sig (truncated): ${sigHex.toString().substring(0, sigHex.toString().length.clamp(0, 32))}...");
      //   });
      // }
    }

    // --- Your original logic (unchanged) ---
    if (sequence == 4294967294) {
      // print(
      //     "Sequence is 0xFFFFFFFE → could be MULTISIG or AFTER. Disambiguating via signer derivation index...");

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

      // print("Derivation-based change(s) from partial_sigs: $signerChanges");

      // 2) If exactly one change value, try to use it as spendingPaths index
      if (signerChanges.length == 1) {
        final changeVal = signerChanges.first;
        if (changeVal >= 0 && changeVal < spendingPaths.length) {
          // print(signerChanges);
          // print(spendingPaths);
          final candidate = spendingPaths[changeVal];
          // print("Index-based match → spendingPaths[$changeVal]: "
          //     "type=${candidate["type"]}, timelock=${candidate["timelock"]}");
          return candidate;
        }
        //  else {
        //   print(
        //       "No spendingPaths[$changeVal] exists (len=${spendingPaths.length}). Falling back to MULTISIG heuristic.");
        // }
      }
      //  else if (signerChanges.isEmpty) {
      //   print(
      //       "No signer derivation change inferred; falling back to MULTISIG heuristic.");
      // } else {
      //   print(
      //       "Multiple signer changes observed ($signerChanges); falling back to MULTISIG heuristic.");
      // }

      // 3) Fallback: original MULTISIG heuristic
      // print("Fallback → MULTISIG heuristic");
      return spendingPaths.firstWhere(
        (path) {
          // print("Checking path for MULTISIG: $path");
          return path["type"].toString().toUpperCase().contains("MULTISIG");
        },
        orElse: () =>
            throw Exception("No matching multisig spending path found."),
      );
    } else {
      // print("Detected TIMELOCK case");
      return spendingPaths.firstWhere(
        (path) {
          // print("Checking path for timelock: $path");
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

    // Print the original pubKeysAlias list
    // print("widget.pubKeysAlias (List of Maps): $pubKeysAlias");

    // Flatten the list of maps into a single map
    for (var map in pubKeysAlias) {
      // print("Processing map: $map");

      if (map.containsKey("publicKey") && map.containsKey("alias")) {
        String publicKeyRaw =
            map["publicKey"].toString(); // e.g. "[42e5d2a0/84'/1'/0']tpubDC..."
        String alias = map["alias"].toString();

        // Extract fingerprint (inside brackets)
        RegExp regex = RegExp(r"\[(.*?)\]");
        Match? match = regex.firstMatch(publicKeyRaw);

        if (match != null) {
          String fingerprint =
              match.group(1)!.split("/")[0]; // Extract first part (fingerprint)
          // print("Extracted Fingerprint: $fingerprint -> Alias: $alias");

          pubKeysAliasMap[fingerprint] = alias; // Store the mapping
        }
      }
    }

    // Print the final fingerprint-to-alias mapping
    // print("Final pubKeysAliasMap (Flattened): $pubKeysAliasMap");

    // Initialize list for signer aliases
    List<String> signersAliases = [];

    // Match fingerprints to aliases
    for (String fingerprint in signers) {
      // print("Checking fingerprint: $fingerprint");

      if (pubKeysAliasMap.containsKey(fingerprint)) {
        String alias = pubKeysAliasMap[fingerprint]!;
        // print("Match found! Fingerprint: $fingerprint -> Alias: $alias");
        signersAliases.add(alias);
      } else {
        // print("No match found for fingerprint: $fingerprint");
        signersAliases.add("Unknown ($fingerprint)");
      }
    }

    // Print final mapping of signers to aliases
    // print("Final Signers with Aliases: $signersAliases");

    return signersAliases;
  }

  bool _isImmediateMultisig(Map<String, dynamic>? p) {
    // print("🔎 Checking path: $p");

    if (p == null) {
      // print("❌ Path is null → returning false");
      return false;
    }

    final type = (p['type'] as String?) ?? '';
    final hasTimelock = p['timelock'] != null;
    final threshold = p['threshold'] is int ? p['threshold'] as int : null;

    final looksMulti =
        type.contains('MULTISIG') || (threshold != null && threshold > 1);

    // print("➡️ type=$type");
    // print("➡️ hasTimelock=$hasTimelock");
    // print("➡️ threshold=$threshold");
    // print("➡️ looksMulti=$looksMulti");

    final result = looksMulti && !hasTimelock;
    // print("✅ Result (isImmediateMultisig) = $result");

    return result;
  }

  Map<String, dynamic>? _pathAt(List paths, int i) {
    if (i < 0 || i >= paths.length) return null;
    final v = paths[i];
    return (v is Map<String, dynamic>) ? v : null;
  }

  // Method to create a PSBT for a multisig transaction, this psbt is signed by the first user
  Future<String?> createPartialTx(
    String descriptor,
    String mnemonic,
    String recipientAddressStr,
    BigInt amount,
    int? chosenPath,
    BigInt avBalance, {
    bool isSendAllBalance = false,
    List<Map<String, dynamic>>? spendingPaths,
    double? customFeeRate,
    List<dynamic>? localUtxos,
  }) async {
    Map<String, Uint32List>? multiSigPath;
    Map<String, Uint32List>? timeLockPath;

    // print('Bool: $multiSig');
    Mnemonic trueMnemonic = await Mnemonic.fromString(mnemonic);

    final hardenedDerivationPath = await DerivationPath.create(
      path: "m/84h/1h/0h",
    );

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = await deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    // print(receivingPublicKey);

    // Extract the content inside square brackets
    final RegExp regex = RegExp(r'\[([^\]]+)\]');
    final Match? match = regex.firstMatch(receivingPublicKey.asString());

    final String targetFingerprint = match!.group(1)!.split('/')[0];
    // print("Fingerprint: $targetFingerprint");

    // print(spendingPaths);

    // Usage
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

    // printInChunks('Sending Descriptor: $descriptor');

    wallet = await createSharedWallet(descriptor);

    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

    final Balance utxos;
    // final List<LocalUtxo> unspent;

    BigInt totalSpending;

    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (!isSendAllBalance) {
        // totalSpending = amount + BigInt.from(feeRate);

        totalSpending = amount;
        // print("Total Spending: $totalSpending");
        // print("Available Balance: ${avBalance}");
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
      utxos = wallet.getBalance();
      // print("Available UTXOs: ${utxos.confirmed}");

      if (!isSendAllBalance) {
        totalSpending = amount;
        // print("Total Spending: $totalSpending");
        // print("Confirmed Utxos: ${utxos.spendable}");
        // Check If there are enough funds available
        if (utxos.spendable < totalSpending) {
          // Exit early if no confirmed UTXOs are available
          throw Exception(
            "Not enough confirmed funds available. Please wait until your transactions confirm.",
          );
        }
      }

      // unspent = wallet.listUnspent();
    }

    final feeRate = customFeeRate ?? await getFeeRate();

    // print('Custom Fee Rate: $customFeeRate');

    List<OutPoint> spendableOutpoints = [];

    // for (var utxo in unspent) {
    //   print('UTXO: ${utxo.outpoint.txid}, Amount: ${utxo.txout.value}');
    // }

    try {
      // Build the transaction
      var txBuilder = TxBuilder();

      final recipientAddress = await Address.fromString(
        s: recipientAddressStr,
        network: wallet.network(),
      );
      final recipientScript = recipientAddress.scriptPubkey();

      var internalChangeAddress = wallet.getInternalAddress(
        addressIndex: const AddressIndex.peek(index: 0),
      );

      final changeScript = internalChangeAddress.address.scriptPubkey();

      // final internalWalletPolicy = wallet.policies(KeychainKind.internalChain);
      final Policy externalWalletPolicy =
          wallet.policies(KeychainKind.externalChain)!;

      // print(externalWalletPolicy.contribution());

      // printPrettyJson(internalWalletPolicy!.asString());
      // printPrettyJson(externalWalletPolicy.asString());

      // const String targetFingerprint = "fb94d032";

      final Map<String, dynamic> policy = jsonDecode(
        externalWalletPolicy.asString(),
      );

      final path = extractAllPathsToFingerprint(policy, targetFingerprint);

      // print(path);

      if (_isImmediateMultisig(correctPath)) {
        // First Path: Direct MULTISIG
        multiSigPath = {
          for (int i = 0; i < path[0]["ids"].length - 1; i++)
            path[0]["ids"][i]: Uint32List.fromList([path[0]["indexes"][i]]),
        };

        // print("Generated multiSigPath: $multiSigPath");
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

        // print("Generated timeLockPath: $timeLockPath");
      }

      // Build the transaction:
      (PartiallySignedTransaction, TransactionDetails) txBuilderResult;

      // await syncWallet(wallet);

      if (isSendAllBalance) {
        // print(internalChangeAddress.address.asString());
        // print('AmountSendAll: ${amount.toInt()}');
        try {
          if (_isImmediateMultisig(correctPath)) {
            // print('multisig');
            await txBuilder
                .addRecipient(recipientScript, amount)
                .policyPath(KeychainKind.internalChain, multiSigPath!)
                .policyPath(KeychainKind.externalChain, multiSigPath)
                .feeRate(feeRate)
                .finish(wallet);
          } else {
            // print('timelock');
            // print(timeLockPath);
            await txBuilder
                .addRecipient(recipientScript, amount)
                .policyPath(KeychainKind.internalChain, timeLockPath!)
                .policyPath(KeychainKind.externalChain, timeLockPath)
                .feeRate(feeRate)
                .finish(wallet);
          }

          return amount.toString();
        } catch (e) {
          print('Error: $e');

          final utxos = await getUtxos();

          // print('SpendingPaths');
          // print(spendingPaths);
          // print('Chosen Path');
          // print(chosenPath);

          List<dynamic> spendableUtxos = [];

          if (_isImmediateMultisig(correctPath)) {
            spendableUtxos = utxos;
          } else {
            // print(chosenPath);
            // print(spendingPaths);

            final timelock = spendingPaths[chosenPath]['timelock'];
            // print('Timelock value: $timelock');

            int currentHeight = await fetchCurrentBlockHeight();
            // print('Current block height: $currentHeight');

            final type =
                spendingPaths[chosenPath]['type'].toString().toLowerCase();

            spendableUtxos = utxos.where((utxo) {
              final blockHeight = utxo['status']['block_height'];
              // print(
              //     'Evaluating UTXO: txid=${utxo['txid']}, blockHeight=$blockHeight');

              bool isSpendable = false;

              if (type.contains('relativetimelock')) {
                isSpendable = blockHeight != null &&
                    (blockHeight + timelock - 1 <= currentHeight ||
                        timelock == 0);
              } else if (type.contains('absolutetimelock')) {
                isSpendable = timelock <= currentHeight;
              } else {
                // If there's no timelock type, consider it spendable by default
                isSpendable = true;
              }

              // print('Is spendable: $isSpendable');
              return isSpendable;
            }).toList();

            // print('Spendable UTXOs found: ${spendableUtxos.length}');
            // for (var spendableUtxo in spendableUtxos) {
            //   print(
            //     'Spendable UTXO: txid=${spendableUtxo['txid']}, blockHeight=${spendableUtxo['status']['block_height']}',
            //   );
            // }
          }

          // Sum the value of spendable UTXOs
          final totalSpendableBalance = spendableUtxos.fold<int>(
            0,
            (sum, utxo) => sum + (int.parse(utxo['value'].toString())),
          );

          // print('totalSpendableBalance: $totalSpendableBalance');
          // for (var spendableUtxo in spendableUtxos) {
          //   print("Spendable Outputs: ${spendableUtxo['txid']}");
          // }
          // Handle insufficient funds
          if (e.toString().contains("InsufficientFundsException")) {
            print(e);
            final RegExp regex = RegExp(r'Needed: (\d+), Available: (\d+)');
            final match = regex.firstMatch(e.toString());
            if (match != null) {
              final int neededAmount = int.parse(match.group(1)!);
              final int availableAmount = int.parse(match.group(2)!);
              final int fee = neededAmount - availableAmount;
              final int sendAllBalance = totalSpendableBalance - fee;

              if (sendAllBalance > 0) {
                return sendAllBalance
                    .toString(); // Return adjusted send all balance
              } else {
                throw Exception('No balance available after fee deduction');
              }
            } else {
              throw Exception('Failed to extract Needed amount from exception');
            }
          } else {
            rethrow; // Re-throw unhandled exceptions
          }
        }
      }
      // print('Spending: $amount');
      // print('LocalUtxos: $localUtxos');

      final utxos = localUtxos ?? await getUtxos();

      // spendingPaths = extractAllPaths(policy);

      if (_isImmediateMultisig(correctPath)) {
        spendableOutpoints = utxos
            .map((utxo) => OutPoint(txid: utxo['txid'], vout: utxo['vout']))
            .toList();
      } else {
        // print(spendingPaths);

        final timelock = spendingPaths[chosenPath]['timelock'];
        // print('Timelock value: $timelock');

        final type = spendingPaths[chosenPath]['type'].toString().toLowerCase();

        int currentHeight = await fetchCurrentBlockHeight();
        // print('Current block height: $currentHeight');

        // Filter spendable UTXOs
        spendableOutpoints = utxos
            .where((utxo) {
              final blockHeight = utxo['status']['block_height'];

              bool isSpendable = false;

              if (type.contains('relativetimelock')) {
                isSpendable = blockHeight != null &&
                    (blockHeight + timelock - 1 <= currentHeight ||
                        timelock == 0);
              } else if (type.contains('absolutetimelock')) {
                isSpendable = timelock <= currentHeight;
              } else {
                // No timelock type; assume spendable
                isSpendable = true;
              }

              // print(
              //   'Evaluating UTXO: txid=${utxo['txid']}, blockHeight=$blockHeight, isSpendable=$isSpendable',
              // );

              return isSpendable;
            })
            .map((utxo) => OutPoint(txid: utxo['txid'], vout: utxo['vout']))
            .toList();
      }

      if (_isImmediateMultisig(correctPath)) {
        // print('MultiSig Builder');

        // for (var spendableOutpoint in spendableOutpoints) {
        //   print('Spendable Outputs: ${spendableOutpoint.txid}');
        // }
        try {
          txBuilder = txBuilder.addUtxos(spendableOutpoints);
        } catch (e) {
          print('❌ Error in addUtxos: $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.manuallySelectedOnly();
        } catch (e) {
          print('❌ Error in manuallySelectedOnly: $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.addRecipient(recipientScript, amount);
        } catch (e) {
          print('❌ Error in addRecipient: $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.drainWallet();
        } catch (e) {
          print('❌ Error in drainWallet: $e');
          rethrow;
        }

        try {
          txBuilder =
              txBuilder.policyPath(KeychainKind.internalChain, multiSigPath!);
        } catch (e) {
          print('❌ Error in policyPath (internal): $e');
          rethrow;
        }

        try {
          txBuilder =
              txBuilder.policyPath(KeychainKind.externalChain, multiSigPath);
        } catch (e) {
          print('❌ Error in policyPath (external): $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.feeRate(feeRate);
        } catch (e) {
          print('❌ Error in feeRate: $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.drainTo(changeScript);
        } catch (e) {
          print('❌ Error in drainTo: $e');
          rethrow;
        }

        try {
          txBuilderResult = await txBuilder.finish(wallet);
        } catch (e) {
          print('❌ Error in finish(): $e');
          rethrow;
        }

        // print('Transaction Built');
      } else {
        // print('TimeLock Builder');
        // for (var spendableOutpoint in spendableOutpoints) {
        //   print('Spendable Outputs: ${spendableOutpoint.txid}');
        // }

        // print('Sending: $amount');
        txBuilderResult = await txBuilder
            // .enableRbf()
            // .enableRbfWithSequence(olderValue)
            .addUtxos(spendableOutpoints)
            .manuallySelectedOnly()
            .addRecipient(recipientScript, amount) // Send to recipient
            .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
            .policyPath(KeychainKind.internalChain, timeLockPath!)
            .policyPath(KeychainKind.externalChain, timeLockPath)
            .feeRate(feeRate) // Set the fee rate (in satoshis per byte)
            .drainTo(changeScript) // Specify the address to send the change
            .finish(wallet); // Finalize the transaction with wallet's UTXOs

        // print('Transaction Built');
      }

      try {
        final signed = wallet.sign(
          psbt: txBuilderResult.$1,
          signOptions: const SignOptions(
            trustWitnessUtxo: false,
            allowAllSighashes: true,
            removePartialSigs: true,
            tryFinalize: true,
            signWithTapInternalKey: true,
            allowGrinding: true,
          ),
        );

        if (signed) {
          // print('Signing returned true');

          // printInChunks(txBuilderResult.$1.asString());

          // print('Sending');
          final tx = txBuilderResult.$1.extractTx();

          // for (var input in tx.input()) {
          //   print("Input sequence number: ${input.previousOutput.txid}");
          // }

          // final isLockTime = tx.isLockTimeEnabled();
          // print('LockTime enabled: $isLockTime');

          // final lockTime = tx.lockTime();
          // print('LockTime: $lockTime');

          await blockchain.broadcast(transaction: tx);
          // print('Transaction sent');

          return null;
        } else {
          // print('Signing returned false');

          // printInChunks(txBuilderResult.$1.asString());

          final psbtString = base64Encode(txBuilderResult.$1.serialize());

          // print(psbtString);

          // print('CorrectPath: $correctPath');

          final jsonContent = {
            "psbt": psbtString,
            "spending_path": correctPath,
          };

          final jsonString = jsonEncode(jsonContent);

          return jsonString;
        }
      } catch (broadcastError) {
        print("Broadcasting error: ${broadcastError.toString()}");
        throw Exception("Broadcasting error: ${broadcastError.toString()}");
      }
    } on Exception catch (e, stackTrace) {
      print("Error: ${e.toString()}");
      print('StackTrace: $stackTrace');

      throw Exception("Error: ${e.toString()}");
    }
  }

  Future<String?> createBackupTx(
    String descriptor,
    String mnemonic,
    String recipientAddressStr,
    BigInt amount,
    int? chosenPath,
    BigInt avBalance, {
    bool isSendAllBalance = false,
    List<Map<String, dynamic>>? spendingPaths,
    double? customFeeRate,
    List<dynamic>? localUtxos,
  }) async {
    Map<String, Uint32List>? multiSigPath;
    Map<String, Uint32List>? timeLockPath;

    // print('Bool: $multiSig');
    Mnemonic trueMnemonic = await Mnemonic.fromString(mnemonic);

    final hardenedDerivationPath = await DerivationPath.create(
      path: "m/84h/1h/0h",
    );

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = await deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    // print(receivingPublicKey);

    // Extract the content inside square brackets
    final RegExp regex = RegExp(r'\[([^\]]+)\]');
    final Match? match = regex.firstMatch(receivingPublicKey.asString());

    final String targetFingerprint = match!.group(1)!.split('/')[0];
    // print("Fingerprint: $targetFingerprint");

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

    // printInChunks('Sending Descriptor: $descriptor');

    wallet = await createSharedWallet(descriptor);

    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

    final Balance utxos;
    // final List<LocalUtxo> unspent;

    BigInt totalSpending;

    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (!isSendAllBalance) {
        // totalSpending = amount + BigInt.from(feeRate);

        totalSpending = amount;
        // print("Total Spending: $totalSpending");
        // print("Available Balance: $avBalance");
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
      utxos = wallet.getBalance();
      // print("Available UTXOs: ${utxos.confirmed}");

      if (!isSendAllBalance) {
        // totalSpending = amount + BigInt.from(feeRate);

        totalSpending = amount;
        // print("Total Spending: $totalSpending");
        // print("Confirmed Utxos: ${utxos.spendable}");
        // Check If there are enough funds available
        if (utxos.spendable < totalSpending) {
          // Exit early if no confirmed UTXOs are available
          throw Exception(
            "Not enough confirmed funds available. Please wait until your transactions confirm.",
          );
        }
      }

      // unspent = wallet.listUnspent();
    }

    final feeRate = customFeeRate ?? await getFeeRate();

    // print('Custom Fee Rate: $customFeeRate');

    List<OutPoint> spendableOutpoints = [];

    // for (var utxo in unspent) {
    //   print('UTXO: ${utxo.outpoint.txid}, Amount: ${utxo.txout.value}');
    // }

    try {
      // Build the transaction
      var txBuilder = TxBuilder();

      final recipientAddress = await Address.fromString(
        s: recipientAddressStr,
        network: wallet.network(),
      );
      final recipientScript = recipientAddress.scriptPubkey();

      var internalChangeAddress = wallet.getInternalAddress(
        addressIndex: const AddressIndex.peek(index: 0),
      );

      final changeScript = internalChangeAddress.address.scriptPubkey();

      // final internalWalletPolicy = wallet.policies(KeychainKind.internalChain);
      final Policy externalWalletPolicy =
          wallet.policies(KeychainKind.externalChain)!;

      // print(externalWalletPolicy.contribution());

      // printPrettyJson(internalWalletPolicy!.asString());
      // printPrettyJson(externalWalletPolicy.asString());

      // const String targetFingerprint = "fb94d032";

      final Map<String, dynamic> policy = jsonDecode(
        externalWalletPolicy.asString(),
      );

      final path = extractAllPathsToFingerprint(policy, targetFingerprint);

      // print(path);

      if (_isImmediateMultisig(correctPath)) {
        // First Path: Direct MULTISIG
        multiSigPath = {
          for (int i = 0; i < path[0]["ids"].length - 1; i++)
            path[0]["ids"][i]: Uint32List.fromList([path[0]["indexes"][i]]),
        };

        // print("Generated multiSigPath: $multiSigPath");
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

        // print("Generated timeLockPath: $timeLockPath");
      }

      // Build the transaction:
      (PartiallySignedTransaction, TransactionDetails) txBuilderResult;

      // await syncWallet(wallet);

      if (isSendAllBalance) {
        // print(internalChangeAddress.address.asString());
        // print('AmountSendAll: ${amount.toInt()}');
        try {
          if (_isImmediateMultisig(correctPath)) {
            await txBuilder
                .addRecipient(recipientScript, amount)
                .policyPath(KeychainKind.internalChain, multiSigPath!)
                .policyPath(KeychainKind.externalChain, multiSigPath)
                .feeRate(feeRate)
                .finish(wallet);
          } else {
            // print(timeLockPath);
            await txBuilder
                .addRecipient(recipientScript, amount)
                .policyPath(KeychainKind.internalChain, timeLockPath!)
                .policyPath(KeychainKind.externalChain, timeLockPath)
                .feeRate(feeRate)
                .finish(wallet);
          }

          return amount.toString();
        } catch (e) {
          print('Error: $e');

          final utxos = await getUtxos();

          // print(spendingPaths);
          // print(chosenPath);

          List<dynamic> spendableUtxos = [];

          if (_isImmediateMultisig(correctPath)) {
            spendableUtxos = utxos;
          } else {
            // print(chosenPath);
            // print(spendingPaths);

            // final timelock = spendingPaths![chosenPath!]['timelock'];
            // print('Timelock value: $timelock');

            // int currentHeight = await fetchCurrentBlockHeight();
            // print('Current block height: $currentHeight');

            spendableUtxos = utxos.where((utxo) {
              final status = utxo['status'];
              final confirmed = status != null && status['confirmed'] == true;

              // print(
              //     'Evaluating UTXO: txid=${utxo['txid']}, confirmed=$confirmed');

              return confirmed;
            }).toList();

            // print('Spendable UTXOs found: ${spendableUtxos.length}');
            // for (var spendableUtxo in spendableUtxos) {
            //   print(
            //     'Spendable UTXO: txid=${spendableUtxo['txid']}, blockHeight=${spendableUtxo['status']['block_height']}',
            //   );
            // }
          }

          // Sum the value of spendable UTXOs
          final totalSpendableBalance = spendableUtxos.fold<int>(
            0,
            (sum, utxo) => sum + (int.parse(utxo['value'].toString())),
          );

          // print('totalSpendableBalance: $totalSpendableBalance');
          // for (var spendableUtxo in spendableUtxos) {
          //   print("Spendable Outputs: ${spendableUtxo['txid']}");
          // }
          // Handle insufficient funds
          if (e.toString().contains("InsufficientFundsException")) {
            print(e);
            final RegExp regex = RegExp(r'Needed: (\d+), Available: (\d+)');
            final match = regex.firstMatch(e.toString());
            if (match != null) {
              final int neededAmount = int.parse(match.group(1)!);
              final int availableAmount = int.parse(match.group(2)!);
              final int fee = neededAmount - availableAmount;
              final int sendAllBalance = totalSpendableBalance - fee;

              if (sendAllBalance > 0) {
                return sendAllBalance
                    .toString(); // Return adjusted send all balance
              } else {
                throw Exception('No balance available after fee deduction');
              }
            } else {
              throw Exception('Failed to extract Needed amount from exception');
            }
          } else {
            rethrow; // Re-throw unhandled exceptions
          }
        }
      }

      // print('Spending: $amount');
      // print('LocalUtxos: $localUtxos');

      final utxos = localUtxos ?? await getUtxos();

      // spendingPaths = extractAllPaths(policy);

      if (_isImmediateMultisig(correctPath)) {
        spendableOutpoints = utxos
            .map((utxo) => OutPoint(txid: utxo['txid'], vout: utxo['vout']))
            .toList();
      } else {
        // print(spendingPaths);

        final timelock = spendingPaths[chosenPath]['timelock'];
        // print('Timelock value: $timelock');

        final type = spendingPaths[chosenPath]['type'].toString().toLowerCase();

        // print('Type: $type');

        int currentHeight = await fetchCurrentBlockHeight();
        // print('Current block height: $currentHeight');

        // Filter spendable UTXOs
        spendableOutpoints = utxos
            .where((utxo) {
              final blockHeight = utxo['status']['block_height'];

              bool isSpendable = false;

              if (type.contains('relativetimelock')) {
                isSpendable = blockHeight != null &&
                    (blockHeight + timelock - 1 <= currentHeight ||
                        timelock == 0);
              } else if (type.contains('absolutetimelock')) {
                isSpendable = timelock <= currentHeight;
              } else {
                // No timelock type; assume spendable
                isSpendable = true;
              }

              // print(
              //   'Evaluating UTXO: txid=${utxo['txid']}, blockHeight=$blockHeight, isSpendable=$isSpendable',
              // );

              return isSpendable;
            })
            .map((utxo) => OutPoint(txid: utxo['txid'], vout: utxo['vout']))
            .toList();
      }

      if (_isImmediateMultisig(correctPath)) {
        // print('MultiSig Builder');

        // for (var spendableOutpoint in spendableOutpoints) {
        //   print('Spendable Outputs: ${spendableOutpoint.txid}');
        // }
        try {
          txBuilder = txBuilder.addUtxos(spendableOutpoints);
        } catch (e) {
          print('❌ Error in addUtxos: $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.manuallySelectedOnly();
        } catch (e) {
          print('❌ Error in manuallySelectedOnly: $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.addRecipient(recipientScript, amount);
        } catch (e) {
          print('❌ Error in addRecipient: $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.drainWallet();
        } catch (e) {
          print('❌ Error in drainWallet: $e');
          rethrow;
        }

        try {
          txBuilder =
              txBuilder.policyPath(KeychainKind.internalChain, multiSigPath!);
        } catch (e) {
          print('❌ Error in policyPath (internal): $e');
          rethrow;
        }

        try {
          txBuilder =
              txBuilder.policyPath(KeychainKind.externalChain, multiSigPath);
        } catch (e) {
          print('❌ Error in policyPath (external): $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.feeRate(feeRate);
        } catch (e) {
          print('❌ Error in feeRate: $e');
          rethrow;
        }

        try {
          txBuilder = txBuilder.drainTo(changeScript);
        } catch (e) {
          print('❌ Error in drainTo: $e');
          rethrow;
        }

        try {
          txBuilderResult = await txBuilder.finish(wallet);
        } catch (e) {
          print('❌ Error in finish(): $e');
          rethrow;
        }

        // print('Transaction Built');
      } else {
        // print('TimeLock Builder');
        // for (var spendableOutpoint in spendableOutpoints) {
        //   print('Spendable Outputs: ${spendableOutpoint.txid}');
        // }

        // print('Sending: $amount');
        txBuilderResult = await txBuilder
            // .enableRbf()
            // .enableRbfWithSequence(olderValue)
            // .addUtxos(spendableOutpoints)
            // .manuallySelectedOnly()
            .addRecipient(recipientScript, amount) // Send to recipient
            .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
            .policyPath(KeychainKind.internalChain, timeLockPath!)
            .policyPath(KeychainKind.externalChain, timeLockPath)
            .feeRate(feeRate) // Set the fee rate (in satoshis per byte)
            .drainTo(changeScript) // Specify the address to send the change
            .finish(wallet); // Finalize the transaction with wallet's UTXOs

        // print('Transaction Built');
      }

      try {
        wallet.sign(
          psbt: txBuilderResult.$1,
          signOptions: const SignOptions(
            trustWitnessUtxo: false,
            allowAllSighashes: true,
            removePartialSigs: true,
            tryFinalize: true,
            signWithTapInternalKey: true,
            allowGrinding: true,
          ),
        );

        // final psbtString = base64Encode(txBuilderResult.$1.serialize());

        final tx = txBuilderResult.$1.extractTx();

        final serialized = tx.serialize();

        // Convert bytes to hex string
        final rawHex = hex.encode(serialized);
        // print('🚀 Raw tx hex: $rawHex');

        return rawHex;
        // }
      } catch (broadcastError) {
        print("Broadcasting error: ${broadcastError.toString()}");
        throw Exception("Broadcasting error: ${broadcastError.toString()}");
      }
    } on Exception catch (e, stackTrace) {
      print("Error: ${e.toString()}");
      print('StackTrace: $stackTrace');

      throw Exception("Error: ${e.toString()}");
    }
  }

  // TODO: Broadcast Backup TX
  // Future<String?> broadcastBackupTx(String psbtString) async {
  //   await blockchainInit();

  //   final psbt = await PartiallySignedTransaction.fromString(psbtString);

  //   // print('Sending');
  //   final tx = psbt.extractTx();

  //   // print('serialize');
  //   // print(tx.serialize());

  //   // print('tostring');
  //   // printInChunks(tx.toString());

  //   // await blockchain.broadcast(transaction: tx);
  //   // print('Transaction sent');

  //   return null;
  // }

  // This method takes a PSBT, signs it with the second user and then broadcasts it
  Future<String?> signBroadcastTx(
    String psbtString,
    String descriptor,
    String mnemonic,
    Map<String, dynamic> correctPath,
    // int? chosenPath,
    List<Map<String, dynamic>>? spendingPaths,
  ) async {
    Mnemonic trueMnemonic = await Mnemonic.fromString(mnemonic);

    final hardenedDerivationPath = await DerivationPath.create(
      path: "m/84h/1h/0h",
    );

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = await deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    // print(spendingPaths);
    // print("-----------");
    // print(correctPath);

    final index = spendingPaths!.indexWhere(
      (path) => const DeepCollectionEquality().equals(path, correctPath),
    );

    // print(index);

    // final correctPath = _pathAt(spendingPaths!, chosenPath!);

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

    printInChunks('Sending descriptor: $descriptor');

    wallet = await Wallet.create(
      descriptor: await Descriptor.create(
        descriptor: descriptor,
        network: settingsProvider.network,
      ),
      network: settingsProvider.network,
      databaseConfig: const DatabaseConfig.memory(),
    );

    await syncWallet(wallet);

    // Convert the psbt String to a PartiallySignedTransaction
    final psbt = await PartiallySignedTransaction.fromString(psbtString);

    // printInChunks('Transaction Not Signed: $psbt');

    try {
      final signed = wallet.sign(
        psbt: psbt,
        signOptions: const SignOptions(
          trustWitnessUtxo: false,
          allowAllSighashes: true,
          removePartialSigs: true,
          tryFinalize: true,
          signWithTapInternalKey: true,
          allowGrinding: true,
        ),
      );
      // printInChunks('Transaction Signed: $psbt');

      if (signed) {
        // print('Signing returned true');
        final tx = psbt.extractTx();
        // print('Extracting');

        // final lockTime = tx.lockTime();
        // print('LockTime: $lockTime');

        // for (var input in tx.input()) {
        //   print("Input sequence number: ${input.sequence}");
        // }

        // final currentHeight = await blockchain.getHeight();
        // print('Current height: $currentHeight');

        await blockchain.broadcast(transaction: tx);
        // print('Transaction sent');
      } else {
        // print('Signing returned false');
        // throw Exception('Not signed');

        final jsonContent = {
          "psbt": psbt.asString(),
          "spending_path": correctPath,
        };

        final jsonString = jsonEncode(jsonContent);

        return jsonString;
      }

      // printInChunks('Transaction after Signing: $psbt');

      return null;
    } on Exception catch (e) {
      print("Error: ${e.toString()}");

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

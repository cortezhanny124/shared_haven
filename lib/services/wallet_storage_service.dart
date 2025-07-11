import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:hive/hive.dart';

class WalletStorageService {
  final secureStorage = FlutterSecureStorage();

  // Open the Hive box with encryption
  Future<Box<WalletData>> openBox() async {
    return Hive.box<WalletData>('walletDataBox');
  }

  Future<void> saveWalletData(String walletId, WalletData walletData) async {
    var box = await openBox();

    // Save the wallet data
    await box.put(walletId, walletData);

    // // Retrieve the data immediately after saving to verify
    // final savedData = box.get(walletId);

    // if (savedData != null) {
    //   print('Data saved successfully for $walletId: $savedData');
    // } else {
    //   print('Failed to save data for $walletId');
    // }
  }

  // Load wallet data from Hive
  Future<WalletData?> loadWalletData(String walletId) async {
    try {
      var box = await openBox(); // Safely open or access the existing box
      WalletData? walletData =
          box.get(walletId); // Retrieve the wallet data using the walletId
      // print(walletData);

      return walletData;
    } catch (e) {
      // print('Error loading wallet data: $e');
      throw Exception('Error loading wallet data (Error: ${e.toString()})');
    }
  }

  // Check if wallet data exists
  Future<bool> walletDataExists() async {
    var box = await openBox();
    return box.containsKey('walletData');
  }

  // Clear wallet data
  Future<void> clearWalletData() async {
    var box = await openBox();
    await box.delete('walletData');
  }
}

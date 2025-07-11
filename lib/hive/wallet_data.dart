import 'package:hive/hive.dart';

part 'wallet_data.g.dart'; // Needed for Hive TypeAdapter (generated)

@HiveType(typeId: 0)
class WalletData extends HiveObject {
  @HiveField(0)
  String address;

  @HiveField(1)
  int balance;

  @HiveField(2)
  int ledgerBalance;

  @HiveField(3)
  int availableBalance;

  @HiveField(4)
  List<Map<String, dynamic>> transactions;

  @HiveField(5)
  int currentHeight;

  @HiveField(6)
  String timeStamp;

  @HiveField(7)
  List<dynamic>? utxos;

  @HiveField(8)
  DateTime? lastRefreshed;

  @HiveField(9)
  Set<String>? myAddresses;

  WalletData({
    required this.address,
    required this.balance,
    required this.ledgerBalance,
    required this.availableBalance,
    required this.transactions,
    required this.currentHeight,
    required this.timeStamp,
    required this.utxos,
    required this.lastRefreshed,
    required this.myAddresses,
  });
}

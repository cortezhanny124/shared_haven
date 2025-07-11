// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WalletDataAdapter extends TypeAdapter<WalletData> {
  @override
  final int typeId = 0;

  @override
  WalletData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WalletData(
      address: fields[0] as String,
      balance: fields[1] as int,
      ledgerBalance: fields[2] as int,
      availableBalance: fields[3] as int,
      transactions: (fields[4] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      currentHeight: fields[5] as int,
      timeStamp: fields[6].toString(),
      utxos: (fields[7] as List?)?.cast<dynamic>(),
      lastRefreshed: fields[8] as DateTime?,
      myAddresses: fields[9] != null ? Set<String>.from(fields[9]) : {},
    );
  }

  @override
  void write(BinaryWriter writer, WalletData obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.address)
      ..writeByte(1)
      ..write(obj.balance)
      ..writeByte(2)
      ..write(obj.ledgerBalance)
      ..writeByte(3)
      ..write(obj.availableBalance)
      ..writeByte(4)
      ..write(obj.transactions)
      ..writeByte(5)
      ..write(obj.currentHeight)
      ..writeByte(6)
      ..write(obj.timeStamp)
      ..writeByte(7)
      ..write(obj.utxos)
      ..writeByte(8)
      ..write(obj.lastRefreshed)
      ..writeByte(9)
      ..write(obj.myAddresses?.toList());
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fuel_price_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FuelPriceModelAdapter extends TypeAdapter<FuelPriceModel> {
  @override
  final int typeId = 6;

  @override
  FuelPriceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FuelPriceModel(
      id: fields[0] as String?,
      fuelTypeIndex: fields[1] as int,
      price: fields[2] as double,
      updatedAt: fields[3] as DateTime?,
      source: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FuelPriceModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fuelTypeIndex)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.source);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FuelPriceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

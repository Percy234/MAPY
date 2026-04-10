// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TravelExpenseModelAdapter extends TypeAdapter<TravelExpenseModel> {
  @override
  final int typeId = 4;

  @override
  TravelExpenseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TravelExpenseModel(
      id: fields[0] as String?,
      routeId: fields[1] as String,
      vehicleId: fields[2] as String,
      distance: fields[3] as double,
      fuelConsumption: fields[4] as double,
      fuelPrice: fields[5] as double,
      fuelCost: fields[6] as double,
      date: fields[7] as DateTime,
      createdAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TravelExpenseModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.routeId)
      ..writeByte(2)
      ..write(obj.vehicleId)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.fuelConsumption)
      ..writeByte(5)
      ..write(obj.fuelPrice)
      ..writeByte(6)
      ..write(obj.fuelCost)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TravelExpenseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

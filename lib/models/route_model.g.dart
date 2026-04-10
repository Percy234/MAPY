// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RouteModelAdapter extends TypeAdapter<RouteModel> {
  @override
  final int typeId = 2;

  @override
  RouteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RouteModel(
      id: fields[0] as String?,
      startPlaceId: fields[1] as String?,
      endPlaceId: fields[2] as String?,
      startLatitude: fields[3] as double,
      startLongitude: fields[4] as double,
      endLatitude: fields[5] as double,
      endLongitude: fields[6] as double,
      startTime: fields[7] as DateTime,
      endTime: fields[8] as DateTime?,
      distanceKm: fields[9] as double,
      routeTypeIndex: fields[10] as int,
      lastTraveledCount: fields[11] as int,
      lastTraveledDate: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, RouteModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startPlaceId)
      ..writeByte(2)
      ..write(obj.endPlaceId)
      ..writeByte(3)
      ..write(obj.startLatitude)
      ..writeByte(4)
      ..write(obj.startLongitude)
      ..writeByte(5)
      ..write(obj.endLatitude)
      ..writeByte(6)
      ..write(obj.endLongitude)
      ..writeByte(7)
      ..write(obj.startTime)
      ..writeByte(8)
      ..write(obj.endTime)
      ..writeByte(9)
      ..write(obj.distanceKm)
      ..writeByte(10)
      ..write(obj.routeTypeIndex)
      ..writeByte(11)
      ..write(obj.lastTraveledCount)
      ..writeByte(12)
      ..write(obj.lastTraveledDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

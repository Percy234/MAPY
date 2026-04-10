import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'vehicle_model.g.dart';

enum VehicleType {
  car('Ô tô'),
  motorbike('Xe máy'),
  truck('Xe tải'),
  bus('Xe buýt');

  final String display;
  const VehicleType(this.display);
}

enum FuelType {
  e5Ron92('Xăng E5 RON92'),
  ron95('Xăng RON95'),
  diesel('Dầu Diesel');

  final String display;
  const FuelType(this.display);
}

@HiveType(typeId: 5)
class VehicleModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int vehicleTypeIndex;

  @HiveField(3)
  final int fuelTypeIndex;

  @HiveField(4)
  final double fuelConsumption; // lít/km

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime? modifiedAt;

  VehicleModel({
    String? id,
    required this.name,
    required this.vehicleTypeIndex,
    required this.fuelTypeIndex,
    required this.fuelConsumption,
    DateTime? createdAt,
    this.modifiedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory VehicleModel.create({
    String? id,
    required String name,
    required VehicleType vehicleType,
    required FuelType fuelType,
    required double fuelConsumption,
    DateTime? createdAt,
  }) {
    return VehicleModel(
      id: id,
      name: name,
      vehicleTypeIndex: vehicleType.index,
      fuelTypeIndex: fuelType.index,
      fuelConsumption: fuelConsumption,
      createdAt: createdAt,
    );
  }

  VehicleType get vehicleType => VehicleType.values[vehicleTypeIndex];
  FuelType get fuelType => FuelType.values[fuelTypeIndex];

  @override
  String toString() =>
      'VehicleModel(name: $name, type: ${vehicleType.display}, consumption: ${fuelConsumption}L/km)';
}
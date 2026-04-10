import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'vehicle_model.dart';

part 'fuel_price_model.g.dart';

@HiveType(typeId: 6)
class FuelPriceModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int fuelTypeIndex;

  @HiveField(2)
  final double price; // ₫/lít

  @HiveField(3)
  final DateTime updatedAt;

  @HiveField(4)
  final String source; // "Petrolimex", "manual", v.v.

  FuelPriceModel({
    String? id,
    required this.fuelTypeIndex,
    required this.price,
    DateTime? updatedAt,
    this.source = 'manual',
  })  : id = id ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now();

  factory FuelPriceModel.create({
    String? id,
    required FuelType fuelType,
    required double price,
    DateTime? updatedAt,
    String source = 'manual',
  }) {
    return FuelPriceModel(
      id: id,
      fuelTypeIndex: fuelType.index,
      price: price,
      updatedAt: updatedAt,
      source: source,
    );
  }

  FuelType get fuelType => FuelType.values[fuelTypeIndex];

  @override
  String toString() =>
      'FuelPriceModel(type: ${fuelType.display}, price: $price₫/lít)';
}
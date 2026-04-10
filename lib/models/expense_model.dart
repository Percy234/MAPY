import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 4)
class TravelExpenseModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String routeId;

  @HiveField(2)
  final String vehicleId;

  @HiveField(3)
  final double distance; // km

  @HiveField(4)
  final double fuelConsumption; // lít/km

  @HiveField(5)
  final double fuelPrice; // ₫/lít

  @HiveField(6)
  final double fuelCost; // Nhất cấp: distance * fuelConsumption * fuelPrice

  @HiveField(7)
  final DateTime date;

  @HiveField(8)
  final DateTime createdAt;

  TravelExpenseModel({
    String? id,
    required this.routeId,
    required this.vehicleId,
    required this.distance,
    required this.fuelConsumption,
    required this.fuelPrice,
    required this.fuelCost,
    required this.date,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory TravelExpenseModel.calculate({
    String? id,
    required String routeId,
    required String vehicleId,
    required double distance,
    required double fuelConsumption,
    required double fuelPrice,
    required DateTime date,
    DateTime? createdAt,
  }) {
    final fuelCost = distance * fuelConsumption * fuelPrice;
    return TravelExpenseModel(
      id: id,
      routeId: routeId,
      vehicleId: vehicleId,
      distance: distance,
      fuelConsumption: fuelConsumption,
      fuelPrice: fuelPrice,
      fuelCost: fuelCost,
      date: date,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'TravelExpenseModel(routeId: $routeId, distance: ${distance}km, fuelCost: $fuelCost₫)';
}
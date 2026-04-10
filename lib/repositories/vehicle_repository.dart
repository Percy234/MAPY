import 'package:hive/hive.dart';
import '../models/vehicle_model.dart';
import '../utils/constants.dart';
import '../utils/hive_manager.dart';

class VehicleRepository {
  Box<VehicleModel> get _box => HiveManager.getBox<VehicleModel>(DatabaseConfig.vehiclesBox);

  Future<void> add(VehicleModel vehicle) async => _box.put(vehicle.id, vehicle);

  Future<void> addVehicle(VehicleModel vehicle) async => _box.put(vehicle.id, vehicle);
  
  Future<void> deleteVehicle(String id) async => _box.delete(id);
  
  Future<List<VehicleModel>> getAllVehicles() async => _box.values.toList();
  
  Future<VehicleModel?> getVehicleById(String id) async => _box.get(id);
}
import 'package:hive/hive.dart';
import '../models/vehicle_model.dart';
import '../utils/constants.dart';
import '../utils/hive_manager.dart';

class VehicleRepository {
  Box<VehicleModel> get _box =>
      HiveManager.getBox<VehicleModel>(DatabaseConfig.vehiclesBox);

  Future<void> add(VehicleModel vehicle) async {
    await _box.put(vehicle.id, vehicle);
    await _box.flush();
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    await _box.put(vehicle.id, vehicle);
    await _box.flush();
  }

  Future<void> deleteVehicle(String id) async {
    await _box.delete(id);
    await _box.flush();
  }

  Future<List<VehicleModel>> getAllVehicles() async =>
      _box.values.toList(growable: false);

  Future<VehicleModel?> getVehicleById(String id) async => _box.get(id);
}

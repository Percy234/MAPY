import 'package:hive/hive.dart';
import '../models/fuel_price_model.dart';
import '../utils/constants.dart';
import '../utils/hive_manager.dart';

class FuelPriceRepository {
  Box<FuelPriceModel> get _box => HiveManager.getBox<FuelPriceModel>(DatabaseConfig.fuelPricesBox);

  Future<void> updatePrice(FuelPriceModel price) async => _box.put(price.id, price);
  
  Future<FuelPriceModel?> getPriceByFuelType(int fuelTypeIndex) async {
    final prices = _box.values.where((p) => p.fuelTypeIndex == fuelTypeIndex).toList();
    return prices.isNotEmpty ? prices.last : null;
  }
}
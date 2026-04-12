import 'package:hive/hive.dart';
import '../models/fuel_price_model.dart';
import '../utils/constants.dart';
import '../utils/hive_manager.dart';

class FuelPriceRepository {
  Box<FuelPriceModel> get _box => HiveManager.getBox<FuelPriceModel>(DatabaseConfig.fuelPricesBox);

  // Lưu danh sách giá xăng
  Future<void> updatePrices(List<FuelPriceModel> prices) async {
    for (final price in prices) {
      await _box.put(price.id, price);
    }
  }

  // Lấy giá xăng mới nhất của từng loại nhiên liệu
  Future<List<FuelPriceModel>> getLatestPrices() async {
    final allPrices = _box.values.toList();
    final latestByType = <int, FuelPriceModel>{};
    
    for (final price in allPrices) {
      final existing = latestByType[price.fuelTypeIndex];
      if (existing == null || price.updatedAt.isAfter(existing.updatedAt)) {
        latestByType[price.fuelTypeIndex] = price;
      }
    }
    return latestByType.values.toList();
  }

  // Kiểm tra cần cập nhật (nếu >24h chưa cập nhật)
  Future<bool> shouldRefresh() async {
    final prices = _box.values.toList();
    if (prices.isEmpty) return true;
    
    final newest = prices.fold<DateTime>(
      DateTime(2000),
      (latest, price) => price.updatedAt.isAfter(latest) ? price.updatedAt : latest,
    );
    
    return DateTime.now().difference(newest).inHours >= 24;
  }
}
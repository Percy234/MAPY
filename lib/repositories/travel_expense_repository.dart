import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/expense_model.dart';
import '../utils/constants.dart';
import '../utils/hive_manager.dart';

class TravelExpenseRepository {
  Box<TravelExpenseModel> get _box =>
      HiveManager.getBox<TravelExpenseModel>(DatabaseConfig.travelExpensesBox);

  Future<void> add(TravelExpenseModel expense) async =>
      _box.put(expense.id, expense);

  Future<void> delete(String id) async => _box.delete(id);

  Future<List<TravelExpenseModel>> getAll() async => _box.values.toList();

  Future<List<TravelExpenseModel>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return _box.values
          .where((expense) =>
              expense.date.isAfter(startDate) && expense.date.isBefore(endDate))
          .toList();
    } catch (e) {
      debugPrint('Lỗi khi tính phí đi lại: $e');
      return [];
    }
  }

  Future<List<TravelExpenseModel>> getByVehicle(String vehicleId) async {
    return _box.values
        .where((expense) => expense.vehicleId == vehicleId)
        .toList();
  }

  Future<double> getTotalCost(DateTime startDate, DateTime endDate) async {
    final expenses = await getByDateRange(startDate, endDate);
    return expenses.fold<double>(0.0, (sum, e) => sum + e.fuelCost);
  }
}
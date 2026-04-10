import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../services/travel_expense_service.dart';

final travelExpenseServiceProvider =
    Provider((ref) => TravelExpenseService());

// Chi phí xăng hôm nay
final todayFuelCostProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(travelExpenseServiceProvider);
  return await service.getTodayFuelCost();
});

// Danh sách chi phí xăng hôm nay
final todayTravelExpensesProvider =
    FutureProvider<List<TravelExpenseModel>>((ref) async {
  final service = ref.watch(travelExpenseServiceProvider);
  return await service.getTodayExpenses();
});

// Chi phí xăng tháng này
final monthTravelExpensesProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(travelExpenseServiceProvider);
  final now = DateTime.now();
  final startMonth = DateTime(now.year, now.month, 1);
  final endMonth = DateTime(now.year, now.month + 1, 1);
  return await service.getMonthlyFuelCost(startMonth, endMonth);
});
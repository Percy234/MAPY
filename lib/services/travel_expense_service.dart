import '../models/expense_model.dart';
import '../repositories/travel_expense_repository.dart';

class TravelExpenseService {
  final TravelExpenseRepository _repository = TravelExpenseRepository();

  Future<void> recordExpense(TravelExpenseModel expense) =>
      _repository.add(expense);

  Future<List<TravelExpenseModel>> getTodayExpenses() async {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(now.year, now.month, now.day + 1);
    return _repository.getByDateRange(startDay, endDay);
  }

  Future<double> getTodayFuelCost() async {
    final expenses = await getTodayExpenses();
    return expenses.fold<double>(0.0, (sum, e) => sum + e.fuelCost);
  }

  Future<double> getMonthlyFuelCost(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _repository.getTotalCost(startDate, endDate);
  }
}
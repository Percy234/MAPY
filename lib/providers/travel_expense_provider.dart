import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../services/travel_expense_service.dart';
import '../services/petrolimex_service.dart';

final travelExpenseServiceProvider = Provider((ref) => TravelExpenseService());

final petrolimexServiceProvider = Provider((ref) => PetrolimexService());

// Chi phí xăng hôm nay
final todayFuelCostProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(travelExpenseServiceProvider);
  return await service.getTodayFuelCost();
});

// Danh sách chi phí xăng hôm nay
final todayTravelExpensesProvider = FutureProvider<List<TravelExpenseModel>>((
  ref,
) async {
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

// Giá xăng từ Petrolimex
final petrolimexPricesProvider = FutureProvider<List<PetrolimexRetailPrice>>((
  ref,
) async {
  final service = ref.watch(petrolimexServiceProvider);
  final prices = await service.fetchRetailPrices();
  if (prices.isEmpty) {
    throw Exception('Petrolimex tra ve danh sach gia rong');
  }
  return prices;
});

// Provider để trigger refresh thủ công
final refreshPetrolimexPricesProvider = StateNotifierProvider((ref) {
  return RefreshPricesNotifier(ref);
});

class RefreshPricesNotifier extends StateNotifier<AsyncValue<void>> {
  RefreshPricesNotifier(this.ref) : super(const AsyncValue.data(null));
  final Ref ref;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      ref.invalidate(petrolimexPricesProvider);
      await ref.read(petrolimexPricesProvider.future);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

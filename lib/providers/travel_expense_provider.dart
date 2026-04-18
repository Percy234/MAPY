import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../models/vehicle_model.dart';
import '../repositories/user_profile_repository.dart';
import '../repositories/vehicle_repository.dart';
import '../providers/route_provider.dart';
import '../services/travel_expense_service.dart';
import '../services/petrolimex_service.dart';

final travelExpenseServiceProvider = Provider((ref) => TravelExpenseService());

final petrolimexServiceProvider = Provider((ref) => PetrolimexService());
final userProfileRepositoryProvider = Provider(
  (ref) => UserProfileRepository(),
);
final vehicleRepositoryProvider = Provider((ref) => VehicleRepository());

final selectedFuelZoneProvider = StateProvider<int>((ref) => 1);

final activeVehicleProvider = FutureProvider<VehicleModel?>((ref) async {
  final profileRepository = ref.watch(userProfileRepositoryProvider);
  final vehicleRepository = ref.watch(vehicleRepositoryProvider);

  final profile = await profileRepository.getProfile();
  final activeVehicleId = profile?.activeVehicleId;
  if (activeVehicleId == null || activeVehicleId.isEmpty) {
    return null;
  }

  return vehicleRepository.getVehicleById(activeVehicleId);
});

// Chi phí xăng hôm nay
final todayFuelCostProvider = FutureProvider<double>((ref) async {
  final expenses = await ref.watch(todayTravelExpensesProvider.future);
  return expenses.fold<double>(0.0, (sum, e) => sum + e.fuelCost);
});

// Danh sách chi phí xăng hôm nay
final todayTravelExpensesProvider = FutureProvider<List<TravelExpenseModel>>((
  ref,
) async {
  // Khi routes thay doi (them/chinh sua), can doc lai chi phi theo ngay.
  ref.watch(allRoutesProvider);
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

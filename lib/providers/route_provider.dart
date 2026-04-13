import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_model.dart';
import '../repositories/route_repository.dart';

final routeRepositoryProvider = Provider<RouteRepository>((ref) => RouteRepository());

final allRoutesProvider = FutureProvider<List<RouteModel>>((ref) async {
  final repository = ref.watch(routeRepositoryProvider);
  return repository.getAll();
});

final routesByDateRangeProvider =
    FutureProvider.family<List<RouteModel>, (DateTime, DateTime)>(
  (ref, dateRange) async {
    final repository = ref.watch(routeRepositoryProvider);
    final (startDate, endDate) = dateRange;
    return repository.getByDateRange(startDate, endDate);
  },
);

final totalDistanceProvider =
    FutureProvider.family<double, (DateTime, DateTime)>(
  (ref, dateRange) async {
    final repository = ref.watch(routeRepositoryProvider);
    final (startDate, endDate) = dateRange;
    return repository.getTotalDistance(startDate, endDate);
  },
);
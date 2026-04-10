import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import '../models/route_model.dart';
import '../utils/constants.dart';
import '../utils/hive_manager.dart';

class RouteRepository {
  Box<RouteModel> get _box =>
      HiveManager.getBox<RouteModel>(DatabaseConfig.routesBox);

  Future<void> add(RouteModel route) async => _box.put(route.id, route);

  Future<void> delete(String id) async => _box.delete(id);

  Future<List<RouteModel>> getAll() async {
    try {
      return _box.values.toList();
    } catch (e) {
      debugPrint('Error getting all routes: $e');
      return [];
    }
  }

  Future<List<RouteModel>> getByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return _box.values
          .where((route) =>
              route.startTime.isAfter(startDate) &&
              route.startTime.isBefore(endDate))
          .toList();
    } catch (e) {
      debugPrint('Lỗi khi lấy tuyến đường theo phạm vi ngày: $e');
      return [];
    }
  }

  Future<List<RouteModel>> getByPlace(String placeId) async {
    try {
      return _box.values
          .where((route) =>
              route.startPlaceId == placeId || route.endPlaceId == placeId)
          .toList();
    } catch (e) {
      debugPrint('Lỗi khi lấy tuyến đường theo địa điểm: $e');
      return [];
    }
  }

  Future<double> getTotalDistance(DateTime startDate, DateTime endDate) async {
    final routes = await getByDateRange(startDate, endDate);
    return routes.fold<double>(0.0, (sum, route) => sum + route.distanceKm);
  }
}
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

part 'route_model.g.dart';

@HiveType(typeId: 2)
class RouteModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? startPlaceId;

  @HiveField(2)
  final String? endPlaceId;

  @HiveField(3)
  final double startLatitude;

  @HiveField(4)
  final double startLongitude;

  @HiveField(5)
  final double endLatitude;

  @HiveField(6)
  final double endLongitude;

  @HiveField(7)
  final DateTime startTime;

  @HiveField(8)
  final DateTime? endTime;

  @HiveField(9)
  final double distanceKm; // Khoảng cách tính theo đường đi

  @HiveField(10)
  final int routeTypeIndex; // Lưu index của enum

  @HiveField(11)
  final int lastTraveledCount; // Số lần đã đi qua

  @HiveField(12)
  final DateTime lastTraveledDate;

  @HiveField(13)
  final List<double>? traceCoordinates; // Flattened [lat1, lon1, lat2, lon2, ...]

  RouteModel({
    String? id,
    this.startPlaceId,
    this.endPlaceId,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    required this.routeTypeIndex,
    this.lastTraveledCount = 1,
    DateTime? lastTraveledDate,
    this.traceCoordinates,
  })  : id = id ?? const Uuid().v4(),
        lastTraveledDate = lastTraveledDate ?? DateTime.now();

  factory RouteModel.fromRouteType({
    String? id,
    String? startPlaceId,
    String? endPlaceId,
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    required DateTime startTime,
    DateTime? endTime,
    required double distanceKm,
    required RouteType routeType,
    int lastTraveledCount = 1,
    DateTime? lastTraveledDate,
    List<double>? traceCoordinates,
  }) {
    return RouteModel(
      id: id,
      startPlaceId: startPlaceId,
      endPlaceId: endPlaceId,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
      startTime: startTime,
      endTime: endTime,
      distanceKm: distanceKm,
      routeTypeIndex: routeType.index,
      lastTraveledCount: lastTraveledCount,
      lastTraveledDate: lastTraveledDate,
      traceCoordinates: traceCoordinates,
    );
  }

  // Getter để lấy RouteType từ index
  RouteType get routeType => RouteType.values[routeTypeIndex];

  // Tính thời gian di chuyển (phút)
  int get durationMinutes {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes;
  }

  // Tính tốc độ trung bình (km/h)
  double get averageSpeed {
    if (durationMinutes == 0) return 0;
    return (distanceKm / durationMinutes) * 60;
  }

  // Kiểm tra đây có phải là tuyến đường thường xuyên không
  bool get isFrequent => lastTraveledCount >= 5;

  RouteModel copyWith({
    String? id,
    String? startPlaceId,
    String? endPlaceId,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceKm,
    RouteType? routeType,
    int? lastTraveledCount,
    DateTime? lastTraveledDate,
    List<double>? traceCoordinates,
  }) {
    return RouteModel(
      id: id ?? this.id,
      startPlaceId: startPlaceId ?? this.startPlaceId,
      endPlaceId: endPlaceId ?? this.endPlaceId,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceKm: distanceKm ?? this.distanceKm,
      // ignore: unnecessary_this
      routeTypeIndex: routeType?.index ?? this.routeTypeIndex,
      lastTraveledCount: lastTraveledCount ?? this.lastTraveledCount,
      lastTraveledDate: lastTraveledDate ?? this.lastTraveledDate,
      traceCoordinates: traceCoordinates ?? this.traceCoordinates,
    );
  }

  @override
  String toString() {
    return 'RouteModel(id: $id, from: ($startLatitude, $startLongitude), to: ($endLatitude, $endLongitude), distance: ${distanceKm}km)';
  }
}

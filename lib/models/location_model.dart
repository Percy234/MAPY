import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;

part 'location_model.g.dart';

@HiveType(typeId: 0)
class LocationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double latitude;

  @HiveField(2)
  final double longitude;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final double? accuracy;

  @HiveField(5)
  final double? altitude;

  @HiveField(6)
  final double? speed;

  @HiveField(7)
  final double? heading;

  LocationModel({
    String? id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
  }) : id = id ?? const Uuid().v4();

  // Tính khoảng cách từ vị trí này đến vị trí khác (Haversine formula)
  double distanceTo(LocationModel other) {
    const earthRadiusKm = 6371;

    final dLat = _toRadians(other.latitude - latitude);
    final dLon = _toRadians(other.longitude - longitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(latitude)) *
            math.cos(_toRadians(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));

    return earthRadiusKm * c * 1000; // Trả về mét
  }

  double _toRadians(double degree) {
    return degree * (3.141592653589793 / 180);
  }

  LocationModel copyWith({
    String? id,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
  }) {
    return LocationModel(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
    );
  }

  @override
  String toString() {
    return 'LocationModel(id: $id, lat: $latitude, lon: $longitude, time: $timestamp)';
  }
}

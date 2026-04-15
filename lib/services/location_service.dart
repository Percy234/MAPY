import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../utils/constants.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final List<LocationModel> _locationHistory = [];
  LocationModel? _currentLocation;

  // Streams để theo dõi thay đổi
  final _locationStreamController = StreamController<LocationModel>.broadcast();
  Stream<LocationModel> get locationStream => _locationStreamController.stream;

  List<LocationModel> get locationHistory => List.unmodifiable(_locationHistory);
  LocationModel? get currentLocation => _currentLocation;

  void _handlePosition(Position position) {
    _currentLocation = LocationModel(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
    );

    _locationHistory.add(_currentLocation!);
    if (!_locationStreamController.isClosed) {
      _locationStreamController.add(_currentLocation!);
    }
  }

  /// Kiểm tra quyền truy cập vị trí
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Quyen vi tri bi tu choi vinh vien');
        return false;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Loi xin quyen vi tri: $e');
      return false;
    }
  }

  /// Kiểm tra dịch vụ vị trí có được bật không
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Lấy vị trí hiện tại
  Future<LocationModel?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        debugPrint('Không có quyền truy cập vị trí');
        return null;
      }

      final isServiceEnabled = await isLocationServiceEnabled();
      if (!isServiceEnabled) {
        debugPrint('Dịch vụ vị trí chưa được bật');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _handlePosition(position);

      return _currentLocation;
    } catch (e) {
      debugPrint('Lỗi lấy vị trí: $e');
      return null;
    }
  }

  /// Bắt đầu theo dõi vị trí
  Future<bool> startLocationTracking() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        debugPrint('Khong the bat dau tracking vi chua co quyen vi tri');
        return false;
      }

      final isServiceEnabled = await isLocationServiceEnabled();
      if (!isServiceEnabled) {
        debugPrint('Khong the bat dau tracking vi dich vu vi tri dang tat');
        return false;
      }

      await _positionStreamSubscription?.cancel();

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Cập nhật mỗi 10m
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _handlePosition(position);
          debugPrint(
            'Vị trí: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}',
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Loi stream vi tri: $error');
        },
        cancelOnError: false,
      );

      debugPrint('Bắt đầu theo dõi vị trí');
      return true;
    } catch (e) {
      debugPrint('Lỗi theo dõi vị trí: $e');
      return false;
    }
  }

  /// Dừng theo dõi vị trí
  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    debugPrint('Dừng theo dõi vị trí');
  }

  /// Lấy vị trí gần nhất trong khoảng thời gian
  List<LocationModel> getLocationsInTimeRange(
    DateTime startTime,
    DateTime endTime,
  ) {
    return _locationHistory
        .where((loc) => loc.timestamp.isAfter(startTime) && loc.timestamp.isBefore(endTime))
        .toList();
  }

  /// Tính quãng đường di chuyển trong ngày
  double getDailyDistance() {
    double totalDistance = 0;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day + 1);

    final todayLocations = getLocationsInTimeRange(startOfDay, endOfDay);

    for (int i = 0; i < todayLocations.length - 1; i++) {
      totalDistance += todayLocations[i].distanceTo(todayLocations[i + 1]);
    }

    return totalDistance / 1000; // Chuyển sang km
  }

  /// Phát hiện các vị trí dừng lâu (tiềm năng địa điểm)
  List<LocationCluster> detectStayPoints() {
    if (_locationHistory.isEmpty) return [];

    final clusters = <LocationCluster>[];
    final minStayMs = LocationConfig.minStayDuration; // 5 phút
    final distanceThreshold = LocationConfig.distanceThreshold; // 50m

    int i = 0;
    while (i < _locationHistory.length) {
      final startLoc = _locationHistory[i];
      final clusterLocations = [startLoc];

      // Tìm tất cả vị trí gần startLoc
      for (int j = i + 1; j < _locationHistory.length; j++) {
        if (startLoc.distanceTo(_locationHistory[j]) <= distanceThreshold) {
          clusterLocations.add(_locationHistory[j]);
        } else {
          break;
        }
      }

      // Kiểm tra xem có dừng lâu không
      if (clusterLocations.length > 1) {
        final duration = clusterLocations.last.timestamp.difference(clusterLocations.first.timestamp);
        if (duration.inMilliseconds >= minStayMs) {
          // Tính trung tâm cluster
          final centerLat = clusterLocations.fold<double>(
            0,
            (sum, loc) => sum + loc.latitude,
          ) / clusterLocations.length;
          final centerLon = clusterLocations.fold<double>(
            0,
            (sum, loc) => sum + loc.longitude,
          ) / clusterLocations.length;

          clusters.add(
            LocationCluster(
              latitude: centerLat,
              longitude: centerLon,
              arrivalTime: clusterLocations.first.timestamp,
              departureTime: clusterLocations.last.timestamp,
              points: clusterLocations,
            ),
          );

          i += clusterLocations.length;
          continue;
        }
      }

      i++;
    }

    return clusters;
  }

  /// Xóa lịch sử vị trí
  void clearLocationHistory() {
    _locationHistory.clear();
  }

  /// Dispose resource
  void dispose() {
    stopLocationTracking();
    _locationStreamController.close();
  }
}

/// Lớp để đại diện cho một cluster (nhóm) vị trí
class LocationCluster {
  final double latitude;
  final double longitude;
  final DateTime arrivalTime;
  final DateTime departureTime;
  final List<LocationModel> points;

  LocationCluster({
    required this.latitude,
    required this.longitude,
    required this.arrivalTime,
    required this.departureTime,
    required this.points,
  });

  // Tính thời gian dừng
  Duration get duration => departureTime.difference(arrivalTime);

  @override
  String toString() {
    return 'LocationCluster(lat: $latitude, lon: $longitude, duration: ${duration.inMinutes}m)';
  }
}

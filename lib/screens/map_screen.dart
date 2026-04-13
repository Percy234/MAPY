import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/expense_model.dart';
import '../models/place_model.dart';
import '../models/route_model.dart';
import '../models/vehicle_model.dart';
import '../providers/location_provider.dart';
import '../providers/route_provider.dart';
import '../providers/travel_expense_provider.dart';
import '../repositories/fuel_price_repository.dart';
import '../repositories/travel_expense_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../repositories/vehicle_repository.dart';
import '../utils/constants.dart';
import '../models/location_model.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? _mapController;
  bool _isTrackingEnabled = false;
  bool _isSatelliteView = false;
  bool _isStyleLoaded = false;
  bool _isSyncingMapData = false;
  bool _isDetectingStayPoints = false;
  DateTime? _lastStayPointDetectionAt;
  DateTime? _trackingSegmentStartAt;
  LocationModel? _latestTrackedLocation;
  final List<LatLng> _liveTracePoints = <LatLng>[];
  final Map<dynamic, PlaceModel> _placeByCircleId = <dynamic, PlaceModel>{};
  final UserProfileRepository _userProfileRepository = UserProfileRepository();
  final VehicleRepository _vehicleRepository = VehicleRepository();
  final TravelExpenseRepository _travelExpenseRepository =
      TravelExpenseRepository();
  final FuelPriceRepository _fuelPriceRepository = FuelPriceRepository();

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = ref.watch(currentLocationProvider);
    final places = ref.watch(placesProvider);
    final locationStream = ref.watch(locationStreamProvider);
    final routes = ref.watch(allRoutesProvider);

    locationStream.whenData(_buildLocationUpdater);

    if (currentLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncMapData(
          currentLocation: _latestTrackedLocation ?? currentLocation,
          places: places,
          routes: routes.valueOrNull ?? const <RouteModel>[],
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản Đồ'),
        actions: [
          IconButton(
            icon: Icon(
              _isSatelliteView ? Icons.layers_clear : Icons.satellite_alt,
            ),
            tooltip: _isSatelliteView
                ? 'Chuyển sang bản đồ đường phố'
                : 'Chuyển sang bản đồ vệ tinh',
            onPressed: _toggleMapStyle,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: IconButton(
                icon: Icon(
                  _isTrackingEnabled ? Icons.location_on : Icons.location_off,
                  color: _isTrackingEnabled ? Colors.red : Colors.grey,
                ),
                onPressed: _toggleTracking,
              ),
            ),
          ),
        ],
      ),
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : !ApiConfig.isGoongConfigured
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Bạn chưa cấu hình Goong Map key.\n'
                      'Hãy cập nhật ApiConfig.goongMapKey trong lib/utils/constants.dart',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
          : Stack(
              children: [
                _buildMap(currentLocation),

                // Bottom info panel
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildInfoPanel(_latestTrackedLocation ?? currentLocation),
                ),

                // Floating action buttons
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.blue,
                        onPressed: _centerOnCurrentLocation,
                        child: const Icon(Icons.my_location),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.green,
                        onPressed: _addPlace,
                        child: const Icon(Icons.add_location),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMap(LocationModel currentLocation) {
    final styleString = _resolveMapStyleString();

    return MapLibreMap(
      key: ValueKey<String>('goong-${_isSatelliteView ? 'sat' : 'street'}'),
      styleString: styleString,
      initialCameraPosition: CameraPosition(
        target: LatLng(
          currentLocation.latitude,
          currentLocation.longitude,
        ),
        zoom: 15,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
      myLocationEnabled: !kIsWeb,
      myLocationTrackingMode: MyLocationTrackingMode.none,
      compassEnabled: true,
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onCircleTapped.add(_onCircleTapped);
  }

  void _onStyleLoaded() {
    _isStyleLoaded = true;

    final currentLocation = _latestTrackedLocation ?? ref.read(currentLocationProvider);
    if (currentLocation == null) {
      return;
    }

    unawaited(
      _syncMapData(
        currentLocation: currentLocation,
        places: ref.read(placesProvider),
        routes: ref.read(allRoutesProvider).valueOrNull ?? const <RouteModel>[],
      ),
    );
  }

  String _resolveMapStyleString() {
    return _isSatelliteView
        ? ApiConfig.goongSatelliteStyleUrl
        : ApiConfig.goongStreetStyleUrl;
  }

  Future<void> _syncMapData({
    required LocationModel currentLocation,
    required List<PlaceModel> places,
    required List<RouteModel> routes,
  }) async {
    if (_isSyncingMapData || !_isStyleLoaded) {
      return;
    }

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    _isSyncingMapData = true;

    try {
      await controller.clearLines();
      await controller.clearCircles();
      _placeByCircleId.clear();

      for (final route in routes) {
        final geometry = _buildGeometryForRoute(route);
        if (geometry.length < 2) {
          continue;
        }

        await controller.addLine(
          LineOptions(
            geometry: geometry,
            lineColor: '#2962FF',
            lineWidth: 4,
            lineOpacity: 0.9,
          ),
        );
      }

      if (_liveTracePoints.length >= 2) {
        await controller.addLine(
          LineOptions(
            geometry: _liveTracePoints,
            lineColor: '#00E5FF',
            lineWidth: 6,
            lineOpacity: 0.95,
          ),
        );
      }

      await controller.addCircle(
        CircleOptions(
          geometry: LatLng(currentLocation.latitude, currentLocation.longitude),
          circleRadius: 9,
          circleColor: '#1E88E5',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
          circleOpacity: 0.95,
        ),
      );

      for (final place in places) {
        final circle = await controller.addCircle(
          CircleOptions(
            geometry: LatLng(place.latitude, place.longitude),
            circleRadius: 7,
            circleColor: _getPlaceMarkerHexColor(place.placeType),
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 1.5,
            circleOpacity: 0.95,
          ),
        );
        _placeByCircleId[circle.id] = place;
      }
    } finally {
      _isSyncingMapData = false;
    }
  }

  void _onCircleTapped(Circle circle) {
    final place = _placeByCircleId[circle.id];
    if (place != null) {
      _showPlaceDetail(place);
    }
  }

  void _buildLocationUpdater(LocationModel location) {
    if (!_isTrackingEnabled) {
      return;
    }

    _latestTrackedLocation = location;
    _appendLiveTracePoint(location);

    unawaited(_detectStoppedPlacesIfNeeded());

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(location.latitude, location.longitude),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(LocationModel location) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Vị trí hiện tại',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {
                    final lat = location.latitude;
                    final lon = location.longitude;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tọa độ: $lat, $lon')),
                    );
                  },
                  child: const Icon(Icons.copy, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lat: ${location.latitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Lon: ${location.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _centerOnCurrentLocation() {
    final location = _latestTrackedLocation ?? ref.read(currentLocationProvider);
    final controller = _mapController;
    if (location != null && controller != null) {
      unawaited(
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(location.latitude, location.longitude),
            15,
          ),
        ),
      );
    }
  }

  void _addPlace() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thêm điểm dừng')),
    );
  }

  void _showPlaceDetail(PlaceModel place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(place.name),
        content: Text('Lat: ${place.latitude}, Lon: ${place.longitude}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTracking() async {
    final shouldEnable = !_isTrackingEnabled;

    setState(() {
      _isTrackingEnabled = shouldEnable;
    });

    final locationService = ref.read(locationServiceProvider);

    if (shouldEnable) {
      _lastStayPointDetectionAt = null;
      _isDetectingStayPoints = false;
      _trackingSegmentStartAt = DateTime.now();
      _liveTracePoints.clear();

      final seedLocation = _latestTrackedLocation ?? ref.read(currentLocationProvider);
      if (seedLocation != null) {
        _liveTracePoints.add(LatLng(seedLocation.latitude, seedLocation.longitude));
      }

      locationService.startLocationTracking();

      if (seedLocation != null) {
        unawaited(
          _syncMapData(
            currentLocation: seedLocation,
            places: ref.read(placesProvider),
            routes: ref.read(allRoutesProvider).valueOrNull ?? const <RouteModel>[],
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bắt đầu theo dõi'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    locationService.stopLocationTracking();

    int detectedCount = 0;
    try {
      detectedCount = await ref
          .read(placesProvider.notifier)
          .detectPlacesFromStayPoints();
    } catch (_) {
      // Giữ app ổn định nếu detect thất bại, người dùng vẫn dừng tracking bình thường.
    }

    final routeSaved = await _saveCurrentRouteSegment(
      endTime: DateTime.now(),
      resetTraceAfterSave: false,
    );

    _trackingSegmentStartAt = null;

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          detectedCount > 0
              ? 'Dừng theo dõi, đã cập nhật $detectedCount điểm đã ghé${routeSaved ? ' và lưu tuyến đường' : ''}'
              : (routeSaved ? 'Dừng theo dõi, đã lưu tuyến đường' : 'Dừng theo dõi'),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleMapStyle() {
    setState(() {
      _isSatelliteView = !_isSatelliteView;
      _isStyleLoaded = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSatelliteView ? 'Đã chuyển sang bản đồ vệ tinh' : 'Đã chuyển sang bản đồ đường phố',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _getPlaceMarkerHexColor(PlaceType placeType) {
    switch (placeType) {
      case PlaceType.home:
        return '#D32F2F';
      case PlaceType.workplace:
        return '#F57C00';
      case PlaceType.restaurant:
        return '#388E3C';
      case PlaceType.cafe:
        return '#5D4037';
      case PlaceType.shop:
        return '#7B1FA2';
      case PlaceType.other:
        return '#616161';
    }
  }

  void _appendLiveTracePoint(LocationModel location) {
    final currentPoint = LatLng(location.latitude, location.longitude);

    if (_liveTracePoints.isEmpty) {
      _liveTracePoints.add(currentPoint);
      return;
    }

    final lastPoint = _liveTracePoints.last;
    final distanceInMeters = Geolocator.distanceBetween(
      lastPoint.latitude,
      lastPoint.longitude,
      currentPoint.latitude,
      currentPoint.longitude,
    );

    if (distanceInMeters >= LocationConfig.liveTraceMinDistanceMeters) {
      _liveTracePoints.add(currentPoint);
    }
  }

  Future<void> _detectStoppedPlacesIfNeeded() async {
    if (_isDetectingStayPoints) {
      return;
    }

    final now = DateTime.now();
    final lastDetection = _lastStayPointDetectionAt;
    if (lastDetection != null &&
        now.difference(lastDetection).inSeconds <
            LocationConfig.stayPointDetectionIntervalSeconds) {
      return;
    }

    _lastStayPointDetectionAt = now;
    _isDetectingStayPoints = true;

    try {
      final detectedCount = await ref
          .read(placesProvider.notifier)
          .detectPlacesFromStayPoints();

      if (detectedCount > 0 && mounted) {
        final routeSaved = await _saveCurrentRouteSegment(
          endTime: now,
          resetTraceAfterSave: true,
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              routeSaved
                  ? 'Đã lưu $detectedCount địa điểm dừng và 1 tuyến đường'
                  : 'Đã lưu $detectedCount địa điểm dừng mới',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      _isDetectingStayPoints = false;
    }
  }

  Future<bool> _saveCurrentRouteSegment({
    required DateTime endTime,
    required bool resetTraceAfterSave,
  }) async {
    if (_liveTracePoints.length < 2) {
      return false;
    }

    final distanceKm = _calculateTraceDistanceKm(_liveTracePoints);
    if (distanceKm * 1000 < LocationConfig.minRouteSaveDistanceMeters) {
      if (resetTraceAfterSave) {
        final lastPoint = _liveTracePoints.last;
        _liveTracePoints
          ..clear()
          ..add(lastPoint);
        _trackingSegmentStartAt = endTime;
      }
      return false;
    }

    final startPoint = _liveTracePoints.first;
    final endPoint = _liveTracePoints.last;
    final places = ref.read(placesProvider);

    final route = RouteModel.fromRouteType(
      startPlaceId: _findNearestPlaceId(startPoint, places),
      endPlaceId: _findNearestPlaceId(endPoint, places),
      startLatitude: startPoint.latitude,
      startLongitude: startPoint.longitude,
      endLatitude: endPoint.latitude,
      endLongitude: endPoint.longitude,
      startTime: _trackingSegmentStartAt ?? endTime,
      endTime: endTime,
      distanceKm: distanceKm,
      routeType: RouteType.daily,
      traceCoordinates: _flattenTraceCoordinates(_liveTracePoints),
    );

    await ref.read(routeRepositoryProvider).add(route);
    await _recordTravelExpenseForRoute(route);
    ref.invalidate(allRoutesProvider);
    ref.invalidate(todayFuelCostProvider);
    ref.invalidate(todayTravelExpensesProvider);
    ref.invalidate(monthTravelExpensesProvider);

    if (resetTraceAfterSave) {
      _liveTracePoints
        ..clear()
        ..add(endPoint);
      _trackingSegmentStartAt = endTime;
    }

    return true;
  }

  double _calculateTraceDistanceKm(List<LatLng> points) {
    double distanceMeters = 0;

    for (int i = 0; i < points.length - 1; i++) {
      distanceMeters += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }

    return distanceMeters / 1000;
  }

  String? _findNearestPlaceId(LatLng point, List<PlaceModel> places) {
    String? nearestPlaceId;
    double nearestDistanceMeters = double.infinity;

    for (final place in places) {
      final distanceMeters = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        place.latitude,
        place.longitude,
      );

      if (distanceMeters < nearestDistanceMeters) {
        nearestDistanceMeters = distanceMeters;
        nearestPlaceId = place.id;
      }
    }

    if (nearestDistanceMeters <= LocationConfig.distanceThreshold * 3) {
      return nearestPlaceId;
    }

    return null;
  }

  List<LatLng> _buildGeometryForRoute(RouteModel route) {
    final trace = route.traceCoordinates;
    if (trace == null || trace.length < 4) {
      return <LatLng>[
        LatLng(route.startLatitude, route.startLongitude),
        LatLng(route.endLatitude, route.endLongitude),
      ];
    }

    final points = <LatLng>[];
    for (int i = 0; i < trace.length - 1; i += 2) {
      final lat = trace[i];
      final lon = trace[i + 1];

      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        continue;
      }

      points.add(LatLng(lat, lon));
    }

    if (points.length >= 2) {
      return points;
    }

    return <LatLng>[
      LatLng(route.startLatitude, route.startLongitude),
      LatLng(route.endLatitude, route.endLongitude),
    ];
  }

  List<double> _flattenTraceCoordinates(List<LatLng> points) {
    final flattened = <double>[];
    for (final point in points) {
      flattened
        ..add(point.latitude)
        ..add(point.longitude);
    }
    return flattened;
  }

  Future<void> _recordTravelExpenseForRoute(RouteModel route) async {
    final profile = await _userProfileRepository.getProfile();
    final activeVehicleId = profile?.activeVehicleId;

    if (activeVehicleId == null || activeVehicleId.isEmpty) {
      return;
    }

    final vehicle = await _vehicleRepository.getVehicleById(activeVehicleId);
    if (vehicle == null) {
      return;
    }

    final fuelPrice = await _resolveFuelPrice(vehicle.fuelType);
    if (fuelPrice <= 0) {
      return;
    }

    final expense = TravelExpenseModel.calculate(
      id: route.id,
      routeId: route.id,
      vehicleId: vehicle.id,
      distance: route.distanceKm,
      fuelConsumption: vehicle.fuelConsumption,
      fuelPrice: fuelPrice,
      date: route.endTime ?? route.startTime,
    );

    await _travelExpenseRepository.add(expense);
  }

  Future<double> _resolveFuelPrice(FuelType fuelType) async {
    final latestPrices = await _fuelPriceRepository.getLatestPrices();

    for (final price in latestPrices) {
      if (price.fuelType == fuelType && price.price > 0) {
        return price.price;
      }
    }

    switch (fuelType) {
      case FuelType.e5Ron92:
        return 22000;
      case FuelType.ron95:
        return 23000;
      case FuelType.diesel:
        return 21000;
    }
  }
}

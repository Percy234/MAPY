import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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
  static const Color _petrolBlue = Color(0xFF005BAC);

  MapLibreMapController? _mapController;
  Timer? _centerButtonTimer;
  Timer? _addPlaceButtonTimer;
  bool _isTrackingEnabled = false;
  bool _isSatelliteView = false;
  bool _isCenterLocationActive = false;
  bool _isAddPlaceActive = false;
  bool _isStyleLoaded = false;
  bool _isSyncingMapData = false;
  bool _isDetectingStayPoints = false;
  bool _isResolvingAddress = false;
  DateTime? _lastStayPointDetectionAt;
  DateTime? _trackingSegmentStartAt;
  DateTime? _lastAddressResolvedAt;
  LocationModel? _latestTrackedLocation;
  String? _currentAddress;
  double? _lastAddressLatitude;
  double? _lastAddressLongitude;
  final List<LatLng> _liveTracePoints = <LatLng>[];
  final Map<dynamic, PlaceModel> _placeByCircleId = <dynamic, PlaceModel>{};
  final UserProfileRepository _userProfileRepository = UserProfileRepository();
  final VehicleRepository _vehicleRepository = VehicleRepository();
  final TravelExpenseRepository _travelExpenseRepository =
      TravelExpenseRepository();
  final FuelPriceRepository _fuelPriceRepository = FuelPriceRepository();
  static const double _addressRefreshDistanceMeters = 40;
  static const Duration _addressRefreshInterval = Duration(seconds: 45);

  @override
  void dispose() {
    _centerButtonTimer?.cancel();
    _addPlaceButtonTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = ref.watch(currentLocationProvider);
    final places = ref.watch(placesProvider);
    final locationStream = ref.watch(locationStreamProvider);
    final routes = ref.watch(allRoutesProvider);
    final displayLocation = _latestTrackedLocation ?? currentLocation;

    locationStream.whenData(_buildLocationUpdater);

    if (displayLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncMapData(
          currentLocation: displayLocation,
          places: places,
          routes: routes.valueOrNull ?? const <RouteModel>[],
        );
      });

      unawaited(_updateCurrentAddressIfNeeded(displayLocation));
    }

    return Scaffold(
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

                Positioned(
                  top: 8,
                  right: 8,
                  child: SafeArea(
                    child: Card(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 34,
                            ),
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Phóng to',
                            onPressed: _zoomIn,
                            icon: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 2),
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 34,
                            ),
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Thu nhỏ',
                            onPressed: _zoomOut,
                            icon: const Icon(Icons.remove),
                          ),
                          const SizedBox(height: 2),
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 45,
                              height: 38,
                            ),
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Đưa hướng về Bắc',
                            onPressed: _resetBearingToNorth,
                            icon: const Icon(Icons.explore),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.centerLeft,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'map_style_button',
                            mini: true,
                            backgroundColor: _isSatelliteView
                                ? _petrolBlue
                                : Colors.white,
                            foregroundColor: _isSatelliteView
                                ? Colors.white
                                : Colors.black87,
                            tooltip: _isSatelliteView
                                ? 'Chuyển sang bản đồ đường phố'
                                : 'Chuyển sang bản đồ vệ tinh',
                            onPressed: _toggleMapStyle,
                            child: Icon(
                              _isSatelliteView
                                  ? Icons.layers_clear
                                  : Icons.satellite_alt,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton(
                            heroTag: 'center_location_button',
                            mini: true,
                            backgroundColor: _isCenterLocationActive
                                ? _petrolBlue
                                : Colors.white,
                            foregroundColor: _isCenterLocationActive
                                ? Colors.white
                                : Colors.black87,
                            tooltip: 'Di chuyển về vị trí hiện tại',
                            onPressed: _onCenterLocationPressed,
                            child: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'tracking_button',
                            mini: true,
                            backgroundColor: _isTrackingEnabled
                                ? _petrolBlue
                                : Colors.white,
                            foregroundColor: _isTrackingEnabled
                                ? Colors.white
                                : Colors.black87,
                            tooltip: _isTrackingEnabled
                                ? 'Tắt theo dõi'
                                : 'Bật theo dõi',
                            onPressed: _toggleTracking,
                            child: Icon(
                              _isTrackingEnabled
                                  ? Icons.location_on
                                  : Icons.location_off,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton(
                            heroTag: 'add_place_button',
                            mini: true,
                            backgroundColor: _isAddPlaceActive
                                ? _petrolBlue
                                : Colors.white,
                            foregroundColor: _isAddPlaceActive
                                ? Colors.white
                                : Colors.black87,
                            tooltip: 'Thêm điểm dừng',
                            onPressed: _onAddPlacePressed,
                            child: const Icon(Icons.add_location),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom info panel
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildInfoPanel(
                    _latestTrackedLocation ?? currentLocation,
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
        target: LatLng(currentLocation.latitude, currentLocation.longitude),
        zoom: 15,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
      myLocationEnabled: !kIsWeb,
      myLocationTrackingMode: MyLocationTrackingMode.none,
      compassEnabled: false,
      attributionButtonPosition: AttributionButtonPosition.topLeft,
      attributionButtonMargins: const Point(10000, 10000),
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

    final currentLocation =
        _latestTrackedLocation ?? ref.read(currentLocationProvider);
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
        CameraUpdate.newLatLng(LatLng(location.latitude, location.longitude)),
      ),
    );
  }

  Widget _buildInfoPanel(LocationModel location) {
    final addressText = _currentAddress?.trim();
    final displayAddress = (addressText == null || addressText.isEmpty)
        ? (ApiConfig.isGoongRestConfigured
              ? 'Đang tìm địa chỉ gần nhất...'
              : 'Chưa cấu hình Goong REST API để lấy địa chỉ.')
        : addressText;

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
                    final addressToCopy = _currentAddress?.trim();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          (addressToCopy == null || addressToCopy.isEmpty)
                              ? 'Địa chỉ chưa sẵn sàng'
                              : addressToCopy,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              displayAddress,
              style: const TextStyle(fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCurrentAddressIfNeeded(LocationModel location) async {
    if (!ApiConfig.isGoongRestConfigured || _isResolvingAddress) {
      return;
    }

    final now = DateTime.now();
    if (_lastAddressLatitude != null && _lastAddressLongitude != null) {
      final movedDistance = Geolocator.distanceBetween(
        _lastAddressLatitude!,
        _lastAddressLongitude!,
        location.latitude,
        location.longitude,
      );

      final isRecentlyResolved =
          _lastAddressResolvedAt != null &&
          now.difference(_lastAddressResolvedAt!) < _addressRefreshInterval;

      if (movedDistance < _addressRefreshDistanceMeters && isRecentlyResolved) {
        return;
      }
    }

    _isResolvingAddress = true;
    try {
      final resolvedAddress = await _reverseGeocodeAddress(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      _lastAddressLatitude = location.latitude;
      _lastAddressLongitude = location.longitude;
      _lastAddressResolvedAt = DateTime.now();

      if (!mounted || resolvedAddress == null || resolvedAddress.isEmpty) {
        return;
      }

      if (resolvedAddress == _currentAddress) {
        return;
      }

      setState(() {
        _currentAddress = resolvedAddress;
      });
    } catch (_) {
      // Giữ nguyên địa chỉ cũ nếu reverse geocode thất bại.
    } finally {
      _isResolvingAddress = false;
    }
  }

  Future<String?> _reverseGeocodeAddress({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('${ApiConfig.goongBaseUrl}/Geocode').replace(
      queryParameters: {
        'latlng': '$latitude,$longitude',
        'api_key': ApiConfig.goongApiKey,
      },
    );

    final response = await http
        .get(uri)
        .timeout(Duration(milliseconds: ApiConfig.connectionTimeout));

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final results = decoded['results'];
    if (results is! List || results.isEmpty) {
      return null;
    }

    final first = results.first;
    if (first is! Map<String, dynamic>) {
      return null;
    }

    final formattedAddress = (first['formatted_address'] as String?)?.trim();
    if (formattedAddress != null && formattedAddress.isNotEmpty) {
      return formattedAddress;
    }

    final addressComponents = first['address_components'];
    if (addressComponents is List) {
      for (final component in addressComponents) {
        if (component is Map<String, dynamic>) {
          final longName = (component['long_name'] as String?)?.trim();
          if (longName != null && longName.isNotEmpty) {
            return longName;
          }
        }
      }
    }

    return null;
  }

  void _centerOnCurrentLocation() {
    final location =
        _latestTrackedLocation ?? ref.read(currentLocationProvider);
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

  void _onCenterLocationPressed() {
    _centerButtonTimer?.cancel();
    setState(() {
      _isCenterLocationActive = true;
    });

    _centerOnCurrentLocation();

    _centerButtonTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCenterLocationActive = false;
      });
    });
  }

  void _zoomIn() {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    unawaited(controller.animateCamera(CameraUpdate.zoomIn()));
  }

  void _zoomOut() {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    unawaited(controller.animateCamera(CameraUpdate.zoomOut()));
  }

  void _resetBearingToNorth() {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    unawaited(controller.animateCamera(CameraUpdate.bearingTo(0)));
  }

  void _addPlace() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Thêm điểm dừng')));
  }

  void _onAddPlacePressed() {
    _addPlaceButtonTimer?.cancel();
    setState(() {
      _isAddPlaceActive = true;
    });

    _addPlace();

    _addPlaceButtonTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAddPlaceActive = false;
      });
    });
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

      final seedLocation =
          _latestTrackedLocation ?? ref.read(currentLocationProvider);
      if (seedLocation != null) {
        _liveTracePoints.add(
          LatLng(seedLocation.latitude, seedLocation.longitude),
        );
      }

      locationService.startLocationTracking();

      if (seedLocation != null) {
        unawaited(
          _syncMapData(
            currentLocation: seedLocation,
            places: ref.read(placesProvider),
            routes:
                ref.read(allRoutesProvider).valueOrNull ?? const <RouteModel>[],
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
              : (routeSaved
                    ? 'Dừng theo dõi, đã lưu tuyến đường'
                    : 'Dừng theo dõi'),
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
          _isSatelliteView
              ? 'Đã chuyển sang bản đồ vệ tinh'
              : 'Đã chuyển sang bản đồ đường phố',
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

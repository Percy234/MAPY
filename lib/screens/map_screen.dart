import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;
import 'dart:typed_data';
import 'dart:ui' as ui;

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

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  static const Color _petrolBlue = Color(0xFF005BAC);
  static const String _currentLocationIconId = 'current-location-material-icon';

  MapLibreMapController? _mapController;
  Timer? _centerButtonTimer;
  Timer? _addPlaceButtonTimer;
  bool _isTrackingEnabled = false;
  bool _isSatelliteView = false;
  bool _isCenterLocationActive = false;
  bool _isAddPlaceActive = false;
  bool _isInfoPanelExpanded = false;
  bool _isStyleLoaded = false;
  bool _isSyncingMapData = false;
  bool _isCurrentLocationIconLoaded = false;
  bool _hasRenderedStaticMapData = false;
  int _mapRebuildSeed = 0;
  bool _isDetectingStayPoints = false;
  bool _isResolvingAddress = false;
  String? _trackingStartPlaceLabel;
  DateTime? _lastStayPointDetectionAt;
  DateTime? _trackingSegmentStartAt;
  DateTime? _lastAddressResolvedAt;
  LocationModel? _latestTrackedLocation;
  String? _currentAddress;
  Symbol? _currentLocationSymbol;
  Line? _liveTraceLine;
  double? _lastAddressLatitude;
  double? _lastAddressLongitude;
  int _lastPlacesSignature = 0;
  int _lastRoutesSignature = 0;
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isTrackingEnabled = ref.read(locationServiceProvider).isTrackingActive;
    unawaited(_bootstrapTrackingOnLaunch());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMapAfterResume();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistTrackingSegmentForBackground());
    }
  }

  void _refreshMapAfterResume() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isStyleLoaded = false;
      _isCurrentLocationIconLoaded = false;
      _hasRenderedStaticMapData = false;
      _currentLocationSymbol = null;
      _liveTraceLine = null;
      _lastPlacesSignature = 0;
      _lastRoutesSignature = 0;
      _mapRebuildSeed++;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final routeList = routes.valueOrNull ?? const <RouteModel>[];
    final displayLocation = currentLocation ?? _latestTrackedLocation;

    locationStream.whenData(_buildLocationUpdater);

    if (displayLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncMapData(
          currentLocation: displayLocation,
          places: places,
          routes: routeList,
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

                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    minimum: const EdgeInsets.only(bottom: 10),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slideAnimation = Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(animation);

                        return SlideTransition(
                          position: slideAnimation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _isInfoPanelExpanded
                          ? _buildExpandedInfoOverlay(
                              _latestTrackedLocation ?? currentLocation,
                              places: places,
                              routes: routeList,
                              key: const ValueKey<String>('info-expanded'),
                            )
                          : _buildCollapsedInfoOverlay(
                              key: const ValueKey<String>('info-collapsed'),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMap(LocationModel currentLocation) {
    final styleString = _resolveMapStyleString();

    return MapLibreMap(
      key: ValueKey<String>(
        'goong-${_isSatelliteView ? 'sat' : 'street'}-$_mapRebuildSeed',
      ),
      styleString: styleString,
      initialCameraPosition: CameraPosition(
        target: LatLng(currentLocation.latitude, currentLocation.longitude),
        zoom: 15,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
      myLocationEnabled: false,
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
    _isCurrentLocationIconLoaded = false;
    _hasRenderedStaticMapData = false;
    _currentLocationSymbol = null;
    _liveTraceLine = null;
    _lastPlacesSignature = 0;
    _lastRoutesSignature = 0;

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

    final placesSignature = _computePlacesSignature(places);
    final routesSignature = _computeRoutesSignature(routes);
    final shouldRenderStaticMapData =
        !_hasRenderedStaticMapData ||
        _lastPlacesSignature != placesSignature ||
        _lastRoutesSignature != routesSignature;

    if (!shouldRenderStaticMapData) {
      await _ensureCurrentLocationIcon(controller);
      await _renderCurrentLocationMarker(controller, currentLocation);
      await _renderLiveTraceLine(controller);
      return;
    }

    _isSyncingMapData = true;

    try {
      await controller.clearLines();
      await controller.clearCircles();
      await controller.clearSymbols();
      _currentLocationSymbol = null;
      _liveTraceLine = null;
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

      await _renderLiveTraceLine(controller);

      await _ensureCurrentLocationIcon(controller);
      await _renderCurrentLocationMarker(controller, currentLocation);

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

      _hasRenderedStaticMapData = true;
      _lastPlacesSignature = placesSignature;
      _lastRoutesSignature = routesSignature;
    } finally {
      _isSyncingMapData = false;
    }
  }

  Future<void> _renderCurrentLocationMarker(
    MapLibreMapController controller,
    LocationModel currentLocation,
  ) async {
    final symbolOptions = SymbolOptions(
      geometry: LatLng(currentLocation.latitude, currentLocation.longitude),
      iconImage: _currentLocationIconId,
      iconSize: 0.7,
      iconAnchor: 'bottom',
      zIndex: 1000,
    );

    final currentSymbol = _currentLocationSymbol;
    if (currentSymbol == null) {
      _currentLocationSymbol = await controller.addSymbol(symbolOptions);
      return;
    }

    try {
      await controller.updateSymbol(currentSymbol, symbolOptions);
    } catch (_) {
      _currentLocationSymbol = await controller.addSymbol(symbolOptions);
    }
  }

  Future<void> _renderLiveTraceLine(MapLibreMapController controller) async {
    if (_liveTracePoints.length < 2) {
      final existingLine = _liveTraceLine;
      if (existingLine != null) {
        try {
          await controller.removeLine(existingLine);
        } catch (_) {
          // Bỏ qua lỗi remove line để không ảnh hưởng render marker.
        }
      }

      _liveTraceLine = null;
      return;
    }

    final lineOptions = LineOptions(
      geometry: _liveTracePoints,
      lineColor: '#00E5FF',
      lineWidth: 6,
      lineOpacity: 0.95,
    );

    final existingLine = _liveTraceLine;
    if (existingLine == null) {
      _liveTraceLine = await controller.addLine(lineOptions);
      return;
    }

    try {
      await controller.updateLine(existingLine, lineOptions);
    } catch (_) {
      _liveTraceLine = await controller.addLine(lineOptions);
    }
  }

  int _computePlacesSignature(List<PlaceModel> places) {
    return Object.hashAll(
      places.map(
        (place) => Object.hash(
          place.id,
          place.latitude,
          place.longitude,
          place.placeType.index,
          place.visitCount,
          place.lastVisited?.millisecondsSinceEpoch ?? 0,
        ),
      ),
    );
  }

  int _computeRoutesSignature(List<RouteModel> routes) {
    return Object.hashAll(
      routes.map(
        (route) => Object.hash(
          route.id,
          route.startLatitude,
          route.startLongitude,
          route.endLatitude,
          route.endLongitude,
          route.distanceKm,
          route.lastTraveledCount,
          route.lastTraveledDate.millisecondsSinceEpoch,
          route.traceCoordinates?.length ?? 0,
        ),
      ),
    );
  }

  Future<void> _ensureCurrentLocationIcon(
    MapLibreMapController controller,
  ) async {
    if (_isCurrentLocationIconLoaded) {
      return;
    }

    final iconBytes = await _buildCurrentLocationMaterialIconBytes();
    await controller.addImage(_currentLocationIconId, iconBytes);
    _isCurrentLocationIconLoaded = true;
  }

  Future<Uint8List> _buildCurrentLocationMaterialIconBytes() async {
    const canvasSize = 128.0;
    const iconFontSize = 110.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint),
      style: TextStyle(
        fontSize: iconFontSize,
        color: const Color(0xFF1E88E5),
        fontFamily: Icons.location_on.fontFamily,
        package: Icons.location_on.fontPackage,
      ),
    );
    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        (canvasSize - textPainter.width) / 2,
        (canvasSize - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Không thể tạo icon vị trí từ Material Icons.');
    }

    return byteData.buffer.asUint8List();
  }

  void _onCircleTapped(Circle circle) {
    final place = _placeByCircleId[circle.id];
    if (place != null) {
      _showPlaceDetail(place);
    }
  }

  void _buildLocationUpdater(LocationModel location) {
    _latestTrackedLocation = location;

    if (!_isTrackingEnabled) {
      return;
    }

    _appendLiveTracePoint(location);

    _trackingStartPlaceLabel ??= _resolvePlaceLabelFromLocation(
      location,
      ref.read(placesProvider),
    );

    unawaited(_detectStoppedPlacesIfNeeded());

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    unawaited(
      _syncMapData(
        currentLocation: location,
        places: ref.read(placesProvider),
        routes: ref.read(allRoutesProvider).valueOrNull ?? const <RouteModel>[],
      ),
    );

    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(location.latitude, location.longitude)),
      ),
    );
  }

  Future<void> _persistTrackingSegmentForBackground() async {
    if (!_isTrackingEnabled || _liveTracePoints.length < 2) {
      return;
    }

    await _saveCurrentRouteSegment(
      endTime: DateTime.now(),
      resetTraceAfterSave: true,
    );
  }

  void _toggleInfoPanel() {
    setState(() {
      _isInfoPanelExpanded = !_isInfoPanelExpanded;
    });
  }

  Widget _buildCollapsedInfoOverlay({required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 4),
      child: _buildInfoToggleButton(),
    );
  }

  Widget _buildExpandedInfoOverlay(
    LocationModel location, {
    required List<PlaceModel> places,
    required List<RouteModel> routes,
    required Key key,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInfoToggleButton(),
        const SizedBox(height: 8),
        _buildInfoPanel(
          location,
          places: places,
          routes: routes,
          key: const ValueKey<String>('info-panel'),
        ),
      ],
    );
  }

  Widget _buildInfoToggleButton() {
    return ElevatedButton(
      onPressed: _toggleInfoPanel,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _petrolBlue,
        elevation: 1,
        side: const BorderSide(color: _petrolBlue, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(_isInfoPanelExpanded ? 'Ẩn thông tin' : 'Xem thông tin'),
    );
  }

  Widget _buildInfoPanel(
    LocationModel location, {
    required List<PlaceModel> places,
    required List<RouteModel> routes,
    required Key key,
  }) {
    final addressText = _currentAddress?.trim();
    final displayAddress = (addressText == null || addressText.isEmpty)
        ? (ApiConfig.isGoongRestConfigured
              ? 'Đang tìm địa chỉ gần nhất...'
              : 'Chưa cấu hình Goong REST API để lấy địa chỉ.')
        : addressText;

    final placeNameById = <String, String>{
      for (final place in places) place.id: place.name,
    };
    final currentPlaceLabel = _resolvePlaceLabelFromLocation(location, places);
    final startPlaceLabel = _trackingStartPlaceLabel ?? currentPlaceLabel;
    final hasActivePair =
        _isTrackingEnabled && startPlaceLabel != currentPlaceLabel;
    final activePairLabel = '$startPlaceLabel -> $currentPlaceLabel';

    final placePairRoutes = routes
        .where(
          (route) => route.startPlaceId != null && route.endPlaceId != null,
        )
        .toList(growable: false);
    final latestPairRoute = placePairRoutes.isNotEmpty
        ? placePairRoutes.last
        : null;
    final latestPairLabel = latestPairRoute == null
        ? null
        : '${placeNameById[latestPairRoute.startPlaceId!] ?? 'Địa điểm A'} -> ${placeNameById[latestPairRoute.endPlaceId!] ?? 'Địa điểm B'}';

    final trackingHint = _isTrackingEnabled
        ? 'Đang theo dõi: điểm A đã được giữ, khi tới địa điểm khác sẽ tạo cặp A -> B.'
        : 'Bật theo dõi để bắt đầu một cặp địa điểm mới từ vị trí hiện tại.';

    return Container(
      key: key,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
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
                                    (addressToCopy == null ||
                                            addressToCopy.isEmpty)
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
                      const SizedBox(height: 6),
                      Text(
                        'Lat: ${location.latitude.toStringAsFixed(6)} | Lng: ${location.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nối điểm di chuyển',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Điểm A (bắt đầu): $startPlaceLabel',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasActivePair
                            ? 'Cặp địa điểm hiện tại: $activePairLabel'
                            : 'Đang chờ điểm B: hãy di chuyển sang một địa điểm khác để tạo cặp A -> B.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cặp địa điểm đã ghi nhận: ${placePairRoutes.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (latestPairLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Cặp gần nhất: $latestPairLabel',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        trackingHint,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bootstrapTrackingOnLaunch() async {
    final locationService = ref.read(locationServiceProvider);
    var seedLocation =
        _latestTrackedLocation ?? ref.read(currentLocationProvider);

    if (!locationService.isTrackingActive) {
      final trackingStarted = await locationService.startLocationTracking();
      if (!mounted) {
        return;
      }

      if (!trackingStarted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không bật được định vị. Hãy bật GPS chính xác và cấp quyền vị trí cho ứng dụng.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        });
        return;
      }

      seedLocation ??= await locationService.getCurrentLocation();
      if (!mounted) {
        return;
      }

      setState(() {
        _isTrackingEnabled = true;
      });
    }

    seedLocation ??= await locationService.getCurrentLocation();
    if (!mounted || seedLocation == null) {
      return;
    }

    final places = ref.read(placesProvider);
    setState(() {
      _trackingStartPlaceLabel = _resolvePlaceLabelFromLocation(
        seedLocation!,
        places,
      );
    });
  }

  String _resolvePlaceLabelFromLocation(
    LocationModel location,
    List<PlaceModel> places,
  ) {
    final nearestPlaceId = _findNearestPlaceId(
      LatLng(location.latitude, location.longitude),
      places,
    );

    if (nearestPlaceId != null) {
      for (final place in places) {
        if (place.id == nearestPlaceId) {
          return place.name;
        }
      }
    }

    return 'Địa điểm hiện tại';
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
    final locationService = ref.read(locationServiceProvider);

    if (shouldEnable) {
      final trackingStarted = await locationService.startLocationTracking();
      if (!mounted) {
        return;
      }

      if (!trackingStarted) {
        setState(() {
          _isTrackingEnabled = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể bật theo dõi. Hãy cấp quyền vị trí nền.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      _lastStayPointDetectionAt = null;
      _isDetectingStayPoints = false;
      _trackingSegmentStartAt = DateTime.now();
      _liveTracePoints.clear();

      final seedLocation =
          _latestTrackedLocation ?? ref.read(currentLocationProvider);
      final startPlaceLabel = seedLocation != null
          ? _resolvePlaceLabelFromLocation(
              seedLocation,
              ref.read(placesProvider),
            )
          : 'Địa điểm hiện tại';

      if (seedLocation != null) {
        _liveTracePoints.add(
          LatLng(seedLocation.latitude, seedLocation.longitude),
        );
      }

      setState(() {
        _isTrackingEnabled = true;
        _trackingStartPlaceLabel = startPlaceLabel;
      });

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

    setState(() {
      _isTrackingEnabled = false;
      _trackingStartPlaceLabel = null;
    });

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

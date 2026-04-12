import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/place_model.dart';
import '../models/route_model.dart';
import '../providers/location_provider.dart';
import '../providers/route_provider.dart';
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
  final Map<dynamic, PlaceModel> _placeByCircleId = <dynamic, PlaceModel>{};

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
          currentLocation: currentLocation,
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
                  child: _buildInfoPanel(currentLocation),
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

    final currentLocation = ref.read(currentLocationProvider);
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
        await controller.addLine(
          LineOptions(
            geometry: <LatLng>[
              LatLng(route.startLatitude, route.startLongitude),
              LatLng(route.endLatitude, route.endLongitude),
            ],
            lineColor: '#2962FF',
            lineWidth: 4,
            lineOpacity: 0.9,
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
    final location = ref.read(currentLocationProvider);
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

  void _toggleTracking() {
    setState(() {
      _isTrackingEnabled = !_isTrackingEnabled;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isTrackingEnabled ? 'Bắt đầu theo dõi' : 'Dừng theo dõi',
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
}

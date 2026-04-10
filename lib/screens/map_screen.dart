import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
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
  late MapController _mapController;
  bool _isTrackingEnabled = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = ref.watch(currentLocationProvider);
    final places = ref.watch(placesProvider);
    final locationStream = ref.watch(locationStreamProvider);
    final routes = ref.watch(allRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản Đồ'),
        actions: [
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
          : Stack(
              children: [
                // Flutter Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      currentLocation.latitude,
                      currentLocation.longitude,
                    ),
                    initialZoom: 15,
                  ),
                  children: [
                    // 1. Lớp bản đồ
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.percy.mapy',
                    ),

                    // 2. Lớp bản quyền
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => {},
                        ),
                      ],
                    ),

                    // 3. Lớp Polylines (Routes)
                    routes.when(
                      data: (routeList) {
                        return PolylineLayer(
                          polylines: _buildPolylines(routeList),
                        );
                      },
                      loading: () => PolylineLayer(polylines: []),
                      error: (_, _) => PolylineLayer(polylines: []),
                    ),

                    // 4. Lớp Marker
                    MarkerLayer(
                      markers: _buildMarkers(currentLocation, places),
                    ),
                  ],
                ),

                // Location tracking listener
                if (locationStream.when(
                  data: (location) {
                    _buildLocationUpdater(location);
                    return true;
                  },
                  loading: () => false,
                  error: (_, _) => false,
                ))
                  _buildLocationUpdater(locationStream.value!),

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

  // 🎨 Vẽ Polylines từ routes
  List<Polyline> _buildPolylines(List<RouteModel> routes) {
    return routes.map((route) {
      return Polyline(
        points: [
          LatLng(route.startLatitude, route.startLongitude),
          LatLng(route.endLatitude, route.endLongitude),
        ],
        color: Colors.blue,
        strokeWidth: 4,
        borderStrokeWidth: 2,
        borderColor: Colors.white,
      );
    }).toList();
  }

  List<Marker> _buildMarkers(
    LocationModel currentLocation,
    List<PlaceModel> places,
  ) {
    final markers = <Marker>[];

    // Current location marker
    markers.add(
      Marker(
        point: LatLng(
          currentLocation.latitude,
          currentLocation.longitude,
        ),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white),
          ),
        ),
      ),
    );

    // Place markers
    for (final place in places) {
      final color = _getPlaceMarkerColor(place.placeType);
      markers.add(
        Marker(
          point: LatLng(place.latitude, place.longitude),
          child: SizedBox(
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showPlaceDetail(place),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    place.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildLocationUpdater(LocationModel location) {
    // Cập nhật bản đồ khi vị trí thay đổi (nếu tracking bật)
    if (_isTrackingEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(location.latitude, location.longitude),
          _mapController.camera.zoom,
        );
      });
    }
    return const SizedBox.shrink();
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
    if (location != null) {
      _mapController.move(
        LatLng(location.latitude, location.longitude),
        15,
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

  Color _getPlaceMarkerColor(PlaceType placeType) {
    switch (placeType) {
      case PlaceType.home:
        return Colors.red;
      case PlaceType.workplace:
        return Colors.orange;
      case PlaceType.restaurant:
        return Colors.green;
      case PlaceType.cafe:
        return Colors.brown;
      case PlaceType.shop:
        return Colors.purple;
      case PlaceType.other:
        return Colors.grey;
    }
  }
}

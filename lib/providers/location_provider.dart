import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_model.dart';
import '../models/place_model.dart';
import '../repositories/place_repository.dart';
import '../services/location_service.dart';
import '../services/place_detection_service.dart';
// import '../utils/constants.dart'; // Sử dụng nếu cần

// 1. Singleton LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// 2. Provider cho vị trí hiện tại
final currentLocationProvider = StateNotifierProvider<CurrentLocationNotifier, LocationModel?>((ref) {
  final service = ref.watch(locationServiceProvider);
  return CurrentLocationNotifier(service);
});

// 3. Provider cho lịch sử vị trí
final locationHistoryProvider = StateNotifierProvider<LocationHistoryNotifier, List<LocationModel>>((ref) {
  final service = ref.watch(locationServiceProvider);
  return LocationHistoryNotifier(service);
});

// 4. Provider cho stream vị trí real-time
final locationStreamProvider = StreamProvider<LocationModel>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.locationStream;
});

// 5. Provider cho các vị trí dừng (Stay Points)
final stayPointsProvider = FutureProvider<List<LocationCluster>>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.detectStayPoints();
});

// Provider cho quãng đường hôm nay
final dailyDistanceProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.getDailyDistance();
});

final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  return PlaceRepository();
});

// 6. Provider cho danh sách địa điểm
final placesProvider = StateNotifierProvider<PlacesNotifier, List<PlaceModel>>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  final placeRepository = ref.watch(placeRepositoryProvider);
  return PlacesNotifier(locationService, placeRepository);
});


// --- IMPLEMENTATIONS ---

class CurrentLocationNotifier extends StateNotifier<LocationModel?> {
  final LocationService _service;

  CurrentLocationNotifier(this._service) : super(null) {
    updateCurrentLocation();
  }

  Future<void> updateCurrentLocation() async {
    try {
      state = await _service.getCurrentLocation();
    } catch (e) {
      // Xử lý lỗi nếu cần (ví dụ: chưa cấp quyền GPS)
    }
  }
}

class LocationHistoryNotifier extends StateNotifier<List<LocationModel>> {
  final LocationService _service;

  LocationHistoryNotifier(this._service) : super([]) {
    _initializeHistory();
  }

  void _initializeHistory() {
    // Sử dụng spread operator để đảm bảo Riverpod nhận diện được state mới
    state = [..._service.locationHistory];
  }

  void clearHistory() {
    _service.clearLocationHistory();
    state = [];
  }
  
  // Bạn có thể thêm hàm refresh nếu service cập nhật dữ liệu ngầm
  void refreshHistory() {
    state = [..._service.locationHistory];
  }
}

class PlacesNotifier extends StateNotifier<List<PlaceModel>> {
  PlacesNotifier(this._locationService, this._placeRepository) : super([]) {
    _loadPlaces();
  }

  final LocationService _locationService;
  final PlaceRepository _placeRepository;
  final Set<String> _processedStayPointKeys = <String>{};

  Future<void> _loadPlaces() async {
    final places = await _placeRepository.getAll();
    state = places;
  }

  Future<void> addPlace(PlaceModel place) async {
    await _placeRepository.save(place);
    state = [...state, place];
  }

  Future<void> updatePlace(PlaceModel place) async {
    await _placeRepository.save(place);
    state = [
      for (final p in state)
        if (p.id == place.id) place else p
    ];
  }

  Future<void> deletePlace(String placeId) async {
    await _placeRepository.delete(placeId);
    state = state.where((p) => p.id != placeId).toList();
  }

  Future<void> incrementVisitCount(String placeId) async {
    final nextState = [
      for (final p in state)
        if (p.id == placeId)
          p.copyWith(
            visitCount: p.visitCount + 1,
            lastVisited: DateTime.now(),
          )
        else
          p
    ];
    await _placeRepository.saveAll(nextState);
    state = nextState;
  }

  Future<int> detectPlacesFromStayPoints() async {
    final stayPoints = _locationService.detectStayPoints();
    if (stayPoints.isEmpty) {
      return 0;
    }

    final unprocessedStayPoints = stayPoints
        .where((cluster) => !_processedStayPointKeys.contains(_buildStayPointKey(cluster)))
        .toList(growable: false);

    if (unprocessedStayPoints.isEmpty) {
      return 0;
    }

    final detectedMap = await PlaceDetectionService.detectPlaces(
      stayPoints: unprocessedStayPoints,
      existingPlaces: state,
    );

    for (final cluster in unprocessedStayPoints) {
      _processedStayPointKeys.add(_buildStayPointKey(cluster));
    }

    if (detectedMap.isEmpty) {
      return 0;
    }

    final mergedById = <String, PlaceModel>{
      for (final place in state) place.id: place,
      ...detectedMap,
    };

    final mergedPlaces = mergedById.values.toList(growable: false);
    await _placeRepository.saveAll(mergedPlaces);
    state = mergedPlaces;
    return detectedMap.length;
  }

  String _buildStayPointKey(LocationCluster cluster) {
    final lat = cluster.latitude.toStringAsFixed(4);
    final lon = cluster.longitude.toStringAsFixed(4);
    final arrivalBucket = cluster.arrivalTime.millisecondsSinceEpoch ~/ 60000;
    return '$lat|$lon|$arrivalBucket';
  }
}
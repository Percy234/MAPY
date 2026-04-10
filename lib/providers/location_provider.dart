import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_model.dart';
import '../models/place_model.dart';
import '../services/location_service.dart';
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

// 6. Provider cho danh sách địa điểm
final placesProvider = StateNotifierProvider<PlacesNotifier, List<PlaceModel>>((ref) {
  return PlacesNotifier();
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
  PlacesNotifier() : super([]) {
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    // TODO: Tương lai sẽ gọi repository ở đây
    state = []; 
  }

  Future<void> addPlace(PlaceModel place) async {
    state = [...state, place];
  }

  Future<void> updatePlace(PlaceModel place) async {
    state = [
      for (final p in state)
        if (p.id == place.id) place else p
    ];
  }

  Future<void> deletePlace(String placeId) async {
    state = state.where((p) => p.id != placeId).toList();
  }

  Future<void> incrementVisitCount(String placeId) async {
    state = [
      for (final p in state)
        if (p.id == placeId)
          p.copyWith(
            visitCount: p.visitCount + 1,
            lastVisited: DateTime.now(),
          )
        else
          p
    ];
  }
}
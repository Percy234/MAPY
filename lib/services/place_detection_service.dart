import '../models/place_model.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import 'dart:math' as math;

class PlaceDetectionService {
  /// Phát hiện địa điểm dựa trên stay points
  /// Trả về danh sách PlaceModel được phát hiện từ vị trí dừng lâu
  static Future<Map<String, PlaceModel>> detectPlaces({
    required List<LocationCluster> stayPoints,
    required List<PlaceModel> existingPlaces,
  }) async {
    final detectedPlaces = <String, PlaceModel>{};

    for (final cluster in stayPoints) {
      // Kiểm tra xem cluster này có matched với existing place không
      final matchedPlace = _findMatchingPlace(cluster, existingPlaces);

      if (matchedPlace != null) {
        // Nếu có match, cập nhật visit count
        detectedPlaces[matchedPlace.id] = matchedPlace.copyWith(
          lastVisited: DateTime.now(),
          visitCount: matchedPlace.visitCount + 1,
        );
      } else {
        // Nếu không có match, tạo place mới
        final suggestedType = _suggestPlaceType(cluster);
        final newPlace = PlaceModel.fromPlaceType(
          name: _generatePlaceName(suggestedType),
          latitude: cluster.latitude,
          longitude: cluster.longitude,
          placeType: suggestedType,
          radius: 100, // Mặc định 100m
        );

        detectedPlaces[newPlace.id] = newPlace;
      }
    }

    return detectedPlaces;
  }

  /// Kiểm tra xem cluster có match với place nào hiện có không
  static PlaceModel? _findMatchingPlace(
    LocationCluster cluster,
    List<PlaceModel> existingPlaces,
  ) {
    for (final place in existingPlaces) {
      final distance = _calculateDistance(
        cluster.latitude,
        cluster.longitude,
        place.latitude,
        place.longitude,
      );

      if (distance <= (place.radius ?? 100)) {
        return place;
      }
    }
    return null;
  }

  /// Gợi ý loại địa điểm dựa trên thời gian dừng
  /// - Dừng từ 8 giờ đêm đến 8 giờ sáng với thời gian dừng > 8h => Nhà
  /// - Dừng 8-10 giờ hàng ngày (8-17 giờ) => Nơi làm việc
  /// - Dừng 30-60 phút => Nhà hàng/Quán cà phê
  static PlaceType _suggestPlaceType(LocationCluster cluster) {
    final duration = cluster.duration;
    final hour = cluster.arrivalTime.hour;

    // Phát hiện nhà (dừng quá đêm hoặc dừng rất lâu)
    if ((hour >= 22 || hour <= 8) && duration.inHours >= 6) {
      return PlaceType.home;
    }

    // Phát hiện nơi làm việc (dừng trong giờ hành chính)
    if (hour >= 8 && hour <= 17 && duration.inHours >= 4) {
      return PlaceType.workplace;
    }

    // Phát hiện ăn uống (dừng 30-90 phút)
    if (duration.inMinutes >= 30 && duration.inMinutes <= 120) {
      if (hour >= 11 && hour <= 14) {
        return PlaceType.restaurant;
      }
      if (hour >= 15 && hour <= 18) {
        return PlaceType.cafe;
      }
    }

    // Phát hiện cửa hàng (dừng 15-45 phút)
    if (duration.inMinutes >= 15 && duration.inMinutes <= 45) {
      return PlaceType.shop;
    }

    return PlaceType.other;
  }

  /// Tạo tên địa điểm dựa trên loại
  static String _generatePlaceName(PlaceType type) {
    switch (type) {
      case PlaceType.home:
        return 'Nhà';
      case PlaceType.workplace:
        return 'Nơi Làm Việc';
      case PlaceType.restaurant:
        return 'Nhà Hàng';
      case PlaceType.cafe:
        return 'Quán Cà Phê';
      case PlaceType.shop:
        return 'Cửa Hàng';
      case PlaceType.other:
        return 'Địa Điểm';
    }
  }

  /// Tính khoảng cách giữa 2 điểm (Haversine formula)
  /// Trả về khoảng cách tính bằng mét
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));

    return earthRadiusKm * c * 1000; // Trả về mét
  }

  static double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
}

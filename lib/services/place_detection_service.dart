import 'dart:convert';
import '../models/place_model.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
        final resolvedStop = await _resolveNearestStopPoint(
          latitude: cluster.latitude,
          longitude: cluster.longitude,
          placeType: suggestedType,
        );

        final newPlace = PlaceModel.fromPlaceType(
          name: resolvedStop.name,
          latitude: cluster.latitude,
          longitude: cluster.longitude,
          address: resolvedStop.address,
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

  /// Với nhà/nơi làm việc giữ tên chuẩn.
  /// Các loại còn lại lấy theo POI gần nhất, nếu không có thì fallback địa chỉ gần nhất.
  static Future<_ResolvedStopPoint> _resolveNearestStopPoint({
    required double latitude,
    required double longitude,
    required PlaceType placeType,
  }) async {
    if (placeType == PlaceType.home || placeType == PlaceType.workplace) {
      return _ResolvedStopPoint(name: _generatePlaceName(placeType));
    }

    final geocodeResult = await _reverseGeocode(
      latitude: latitude,
      longitude: longitude,
    );

    if (geocodeResult == null) {
      return _ResolvedStopPoint(name: _generatePlaceName(placeType));
    }

    final resolvedName =
        _extractBestNameFromGeocode(geocodeResult) ??
        _generatePlaceName(placeType);
    final address = (geocodeResult['formatted_address'] as String?)?.trim();

    return _ResolvedStopPoint(
      name: resolvedName,
      address: (address == null || address.isEmpty) ? null : address,
    );
  }

  static Future<Map<String, dynamic>?> _reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (!ApiConfig.isGoongRestConfigured) {
      return null;
    }

    final uri = Uri.parse('${ApiConfig.goongBaseUrl}/Geocode').replace(
      queryParameters: {
        'latlng': '$latitude,$longitude',
        'api_key': ApiConfig.goongApiKey,
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(Duration(milliseconds: ApiConfig.connectionTimeout));

      if (response.statusCode != 200) {
        debugPrint('Reverse geocode failed: ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final results = decoded['results'];
      if (results is! List) {
        return null;
      }

      for (final item in results) {
        if (item is Map<String, dynamic>) {
          final candidateName = _extractBestNameFromGeocode(item);
          final candidateAddress =
              (item['formatted_address'] as String?)?.trim() ?? '';
          if (candidateName != null || candidateAddress.isNotEmpty) {
            return item;
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }

    return null;
  }

  static String? _extractBestNameFromGeocode(Map<String, dynamic> item) {
    final components = item['address_components'];
    if (components is List) {
      for (final component in components) {
        if (component is Map<String, dynamic>) {
          final longName = (component['long_name'] as String?)?.trim();
          if (longName != null && longName.isNotEmpty) {
            return longName;
          }
        }
      }
    }

    final formattedAddress = (item['formatted_address'] as String?)?.trim();
    if (formattedAddress == null || formattedAddress.isEmpty) {
      return null;
    }

    return formattedAddress.split(',').first.trim();
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

class _ResolvedStopPoint {
  const _ResolvedStopPoint({
    required this.name,
    this.address,
  });

  final String name;
  final String? address;
}

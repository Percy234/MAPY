import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

part 'place_model.g.dart';

@HiveType(typeId: 1)
class PlaceModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double latitude;

  @HiveField(3)
  final double longitude;

  @HiveField(4)
  final String? address;

  @HiveField(5)
  final int placeTypeIndex; // Lưu index của enum

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime? lastVisited;

  @HiveField(8)
  final int visitCount;

  @HiveField(9)
  final double? radius; // Bán kính nhận diện địa điểm (mét)

  PlaceModel({
    String? id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.placeTypeIndex,
    DateTime? createdAt,
    this.lastVisited,
    this.visitCount = 1,
    this.radius = 100, // Mặc định 100m
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory PlaceModel.fromPlaceType({
    String? id,
    required String name,
    required double latitude,
    required double longitude,
    String? address,
    required PlaceType placeType,
    DateTime? createdAt,
    DateTime? lastVisited,
    int visitCount = 1,
    double? radius = 100,
  }) {
    return PlaceModel(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      address: address,
      placeTypeIndex: placeType.index,
      createdAt: createdAt,
      lastVisited: lastVisited,
      visitCount: visitCount,
      radius: radius,
    );
  }

  // Getter để lấy PlaceType từ index
  PlaceType get placeType => PlaceType.values[placeTypeIndex];

  PlaceModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
    PlaceType? placeType,
    DateTime? createdAt,
    DateTime? lastVisited,
    int? visitCount,
    double? radius,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      // ignore: unnecessary_this
      placeTypeIndex: placeType?.index ?? this.placeTypeIndex,
      createdAt: createdAt ?? this.createdAt,
      lastVisited: lastVisited ?? this.lastVisited,
      visitCount: visitCount ?? this.visitCount,
      radius: radius ?? this.radius,
    );
  }

  @override
  String toString() {
    return 'PlaceModel(id: $id, name: $name, type: ${placeType.display}, visits: $visitCount)';
  }
}

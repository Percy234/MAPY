import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'user_profile_model.g.dart';

enum Gender {
  male('Nam'),
  female('Nữ'),
  other('Khác');

  final String display;
  const Gender(this.display);
}

@HiveType(typeId: 7)
class UserProfileModel extends HiveObject {
  static const Object _keepValue = Object();

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fullName;

  @HiveField(2)
  final int genderIndex; // Lưu index của enum

  @HiveField(3)
  final String? activeVehicleId; // ID phương tiện đang dùng

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime? modifiedAt;

  @HiveField(6)
  final bool isSetupComplete; // Đã hoàn tất onboarding?

  UserProfileModel({
    String? id,
    required this.fullName,
    required this.genderIndex,
    this.activeVehicleId,
    DateTime? createdAt,
    this.modifiedAt,
    this.isSetupComplete = false,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Gender get gender => Gender.values[genderIndex];

  factory UserProfileModel.create({
    String? id,
    required String fullName,
    required Gender gender,
    String? activeVehicleId,
    bool isSetupComplete = false,
  }) {
    return UserProfileModel(
      id: id,
      fullName: fullName,
      genderIndex: gender.index,
      activeVehicleId: activeVehicleId,
      isSetupComplete: isSetupComplete,
    );
  }

  UserProfileModel copyWith({
    String? fullName,
    Gender? gender,
    Object? activeVehicleId = _keepValue,
    bool? isSetupComplete,
  }) {
    return UserProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      genderIndex: gender?.index ?? genderIndex,
      activeVehicleId: identical(activeVehicleId, _keepValue)
          ? this.activeVehicleId
          : activeVehicleId as String?,
      createdAt: createdAt,
      modifiedAt: DateTime.now(),
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
    );
  }
}

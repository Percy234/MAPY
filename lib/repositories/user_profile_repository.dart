import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/user_profile_model.dart';
import '../utils/constants.dart';
import '../utils/hive_manager.dart';

class UserProfileRepository {
  static const String _profileKey = 'user_profile';

  Box<UserProfileModel> get _box =>
      HiveManager.getBox<UserProfileModel>(DatabaseConfig.userProfileBox);

  Future<UserProfileModel?> getProfile() async {
    try {
      // Ưu tiên đọc theo key cố định để tránh lấy nhầm record cũ trong box.
      final currentProfile = _box.get(_profileKey);
      if (currentProfile != null) {
        return currentProfile;
      }

      // Fallback cho dữ liệu legacy từng lưu bằng key khác.
      final legacyProfiles = _box.values.toList(growable: false);
      if (legacyProfiles.isEmpty) {
        return null;
      }

      legacyProfiles.sort((a, b) {
        final aTimestamp = a.modifiedAt ?? a.createdAt;
        final bTimestamp = b.modifiedAt ?? b.createdAt;
        return aTimestamp.compareTo(bTimestamp);
      });

      final latestProfile = legacyProfiles.last;
      await _box.put(_profileKey, latestProfile);
      return latestProfile;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> saveProfile(UserProfileModel profile) async {
    try {
      await _box.put(_profileKey, profile);
      await _box.flush();
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      rethrow;
    }
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    try {
      await _box.put(_profileKey, profile);
      await _box.flush();
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<bool> isSetupComplete() async {
    final profile = await getProfile();
    return profile?.isSetupComplete ?? false;
  }
}

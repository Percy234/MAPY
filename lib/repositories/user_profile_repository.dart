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
      final profiles = _box.values.toList();
      return profiles.isNotEmpty ? profiles.first : null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> saveProfile(UserProfileModel profile) async {
    try {
      await _box.put(_profileKey, profile);
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      rethrow;
    }
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    try {
      await _box.put(_profileKey, profile);
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
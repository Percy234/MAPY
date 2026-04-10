import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import '../repositories/user_profile_repository.dart';

final userProfileRepositoryProvider = Provider((ref) => UserProfileRepository());

final userProfileProvider = FutureProvider<UserProfileModel?>((ref) async {
  final repository = ref.watch(userProfileRepositoryProvider);
  return repository.getProfile();
});

final isSetupCompleteProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(userProfileRepositoryProvider);
  return repository.isSetupComplete();
});
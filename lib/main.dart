import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'repositories/vehicle_repository.dart';
import 'utils/service_locator.dart';
import 'utils/hive_manager.dart';
import 'repositories/user_profile_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? bootstrapError;

  try {
    // Khởi tạo Hive Database
    await HiveManager.initHive();

    // Khởi tạo Service Locator
    await setupServiceLocator();
  } catch (e, stackTrace) {
    bootstrapError = e;
    debugPrint('Bootstrap error: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(ProviderScope(child: MyApp(bootstrapError: bootstrapError)));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.bootstrapError});

  final Object? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAPY',
      theme: AppTheme.lightTheme,
      home: bootstrapError == null
          ? const AppInitializationScreen()
          : BootstrapErrorScreen(error: bootstrapError!),
      routes: {
        Routes.onboarding: (context) => const OnboardingScreen(),
        Routes.home: (context) => const MainNavigationScreen(),
      },
    );
  }
}

// 🎯 Màn hình kiểm tra setup status
class AppInitializationScreen extends StatefulWidget {
  const AppInitializationScreen({super.key});

  @override
  State<AppInitializationScreen> createState() =>
      _AppInitializationScreenState();
}

class _AppInitializationScreenState extends State<AppInitializationScreen> {
  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    try {
      final userProfileRepo = UserProfileRepository();
      final vehicleRepo = VehicleRepository();

      final profile = await userProfileRepo.getProfile();
      final vehicles = await vehicleRepo.getAllVehicles();

      final hasProfileName =
          profile != null && profile.fullName.trim().isNotEmpty;
      final hasVehicle = vehicles.isNotEmpty;
      final shouldOpenHome = hasProfileName && hasVehicle;

      if (shouldOpenHome) {
        final existingProfile = profile;
        final activeVehicleExists =
            existingProfile.activeVehicleId != null &&
            vehicles.any(
              (vehicle) => vehicle.id == existingProfile.activeVehicleId,
            );
        final shouldRepairProfile =
            !existingProfile.isSetupComplete || !activeVehicleExists;

        if (shouldRepairProfile) {
          await userProfileRepo.updateProfile(
            existingProfile.copyWith(
              isSetupComplete: true,
              activeVehicleId: activeVehicleExists
                  ? existingProfile.activeVehicleId
                  : vehicles.first.id,
            ),
          );
        }
      }

      if (!mounted) return;

      if (shouldOpenHome) {
        // Đã setup → Vào MainNavigationScreen
        Navigator.of(context).pushReplacementNamed(Routes.home);
      } else {
        // Chưa setup → Vào OnboardingScreen
        Navigator.of(context).pushReplacementNamed(Routes.onboarding);
      }
    } catch (e) {
      debugPrint('Error checking setup status: $e');
      // Nếu lỗi, mặc định vào Onboarding
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.onboarding);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Đang khởi tạo ứng dụng...'),
          ],
        ),
      ),
    );
  }
}

class BootstrapErrorScreen extends StatelessWidget {
  const BootstrapErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Ứng dụng không thể khởi tạo dữ liệu cục bộ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await HiveManager.initHive();
                    await setupServiceLocator();

                    if (!context.mounted) return;

                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const AppInitializationScreen(),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Khởi tạo lại thất bại: $e')),
                    );
                  }
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

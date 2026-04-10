import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'utils/service_locator.dart';
import 'utils/hive_manager.dart';
import 'repositories/user_profile_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Hive Database
  await HiveManager.initHive();

  // Khởi tạo Service Locator
  await setupServiceLocator();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAPY',
      theme: AppTheme.lightTheme,
      home: const AppInitializationScreen(),
      routes: {
        Routes.onboarding: (context) => const OnboardingScreen(),
        Routes.home: (context) => const HomeScreen(),
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
      final isSetupComplete = await userProfileRepo.isSetupComplete();

      if (!mounted) return;

      if (isSetupComplete) {
        // Đã setup → Vào HomeScreen
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

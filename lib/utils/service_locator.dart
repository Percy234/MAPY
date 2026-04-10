import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // Các services sẽ được thêm vào sau
  // getIt.registerSingleton<LocationService>(LocationService());
  // getIt.registerSingleton<ExpenseService>(ExpenseService());
  // getIt.registerSingleton<DatabaseService>(DatabaseService());
}

import 'package:hive_flutter/hive_flutter.dart';
import '../models/location_model.dart';
import '../models/place_model.dart';
import '../models/route_model.dart';
import '../models/expense_model.dart';
import '../models/vehicle_model.dart';
import '../models/fuel_price_model.dart';
import '../models/user_profile_model.dart';
import 'constants.dart';

class HiveManager {
  static Future<void> initHive() async {
    await Hive.initFlutter();

    Hive.registerAdapter(LocationModelAdapter());
    Hive.registerAdapter(PlaceModelAdapter());
    Hive.registerAdapter(RouteModelAdapter());
    Hive.registerAdapter(TravelExpenseModelAdapter());
    Hive.registerAdapter(VehicleModelAdapter());
    Hive.registerAdapter(FuelPriceModelAdapter());
    Hive.registerAdapter(UserProfileModelAdapter());

    await Hive.openBox<LocationModel>(DatabaseConfig.locationsBox);
    await Hive.openBox<PlaceModel>(DatabaseConfig.placesBox);
    await Hive.openBox<RouteModel>(DatabaseConfig.routesBox);
    await Hive.openBox<TravelExpenseModel>(DatabaseConfig.travelExpensesBox);
    await Hive.openBox<VehicleModel>(DatabaseConfig.vehiclesBox);
    await Hive.openBox<FuelPriceModel>(DatabaseConfig.fuelPricesBox);
    await Hive.openBox<UserProfileModel>(DatabaseConfig.userProfileBox);
    await Hive.openBox(DatabaseConfig.settingsBox);
  }

  static Future<void> closeHive() async {
    await Hive.close();
  }

  static Box<T> getBox<T>(String boxName) {
    return Hive.box<T>(boxName);
  }
}

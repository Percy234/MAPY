// API Configuration
class ApiConfig {
  static const String goongApiKey = 'RenfdlU86rE2N4ZsZhwyWZWe37XQ3KETffhGfxyq';
  static const String goongBaseUrl = 'https://rsapi.goong.io';
  
  static const int connectionTimeout = 30000; // 30 giây
  static const int receiveTimeout = 30000;
}

// Location Configuration
class LocationConfig {
  static const int minStayDuration = 300000; // 5 phút (ms)
  static const double distanceThreshold = 50; // 50 mét
  static const int updateInterval = 10000; // 10 giây
}

// Database Configuration
class DatabaseConfig {
  static const String travelExpensesBox = 'travel_expenses';
  static const String vehiclesBox = 'vehicles';
  static const String fuelPricesBox = 'fuel_prices';
  static const String locationsBox = 'locations';
  static const String routesBox = 'routes';
  static const String placesBox = 'places';
  static const String settingsBox = 'settings';
  static const String userProfileBox = 'user_profile';  // ✨ THÊM DÒNG NÀY
}

// Expense Categories
enum ExpenseCategory {
  food('Ăn uống'),
  transport('Giao thông'),
  shopping('Mua sắm'),
  utilities('Tiện ích'),
  entertainment('Giải trí'),
  health('Y tế'),
  education('Giáo dục'),
  other('Khác');

  final String display;
  const ExpenseCategory(this.display);
}

// Place Types
enum PlaceType {
  home('Nhà'),
  workplace('Nơi làm việc'),
  restaurant('Nhà hàng'),
  cafe('Quán cà phê'),
  shop('Cửa hàng'),
  other('Khác');

  final String display;
  const PlaceType(this.display);
}

// Route Types
enum RouteType {
  daily('Hàng ngày'),
  weekly('Hàng tuần'),
  occasional('Bất thường');

  final String display;
  const RouteType(this.display);
}

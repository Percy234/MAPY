# Phase 2 - Theo Dõi Vị Trí & Bản Đồ

## ✅ Đã Hoàn Thành

### 1. **Models** (`lib/models/`)
- ✅ **location_model.dart** - LocationModel (Hive)
  - Lưu trữ điểm vị trí với timestamp, accuracy, speed
  - Phương thức `distanceTo()` - tính khoảng cách dùng Haversine formula
  
- ✅ **place_model.dart** - PlaceModel (Hive)
  - Đại diện một địa điểm (nhà, nơi làm việc, nhà hàng, v.v.)
  - Lưu trữ visit count, lastVisited, radius
  - PlaceType enum: home, workplace, restaurant, cafe, shop, other
  
- ✅ **route_model.dart** - RouteModel (Hive)
  - Đại diện một tuyến đường từ điểm A đến B
  - Tính toán: duration, averageSpeed, isFrequent
  - RouteType enum: daily, weekly, occasional

### 2. **Services** (`lib/services/`)
- ✅ **location_service.dart** - LocationService (Singleton)
  - `getCurrentLocation()` - Lấy vị trí hiện tại
  - `startLocationTracking()` - Bắt đầu theo dõi vị trí real-time
  - `stopLocationTracking()` - Dừng theo dõi
  - `getDailyDistance()` - Tính quãng đường hôm nay
  - `detectStayPoints()` - Phát hiện các vị trí dừng lâu
  - `LocationCluster` class - Đại diện nhóm vị trí gần nhau
  - `getLocationsInTimeRange()` - Lấy vị trí trong khoảng thời gian
  - Stream broadcaster cho location updates

- ✅ **place_detection_service.dart** - PlaceDetectionService
  - `detectPlaces()` - Phát hiện địa điểm từ stay points
  - `_suggestPlaceType()` - Gợi ý loại địa điểm dựa thời gian:
    - **Nhà**: Dừng từ 22h-8h hoặc dừng > 8 giờ
    - **Nơi làm việc**: Dừng trong giờ công sở (8-17h) > 4 giờ
    - **Nhà hàng**: Dừng 30-120 phút giữa trưa (11-14h)
    - **Quán cà phê**: Dừng 30-120 phút chiều (15-18h)
    - **Cửa hàng**: Dừng 15-45 phút
  - Distance calculation với Haversine formula

### 3. **Providers** (`lib/providers/`)
- ✅ **location_provider.dart** - Riverpod Providers
  - `locationServiceProvider` - Singleton LocationService
  - `currentLocationProvider` - Vị trí hiện tại (StateNotifier)
  - `locationHistoryProvider` - Lịch sử vị trị (StateNotifier)
  - `locationStreamProvider` - Stream vị trị real-time (StreamProvider)
  - `dailyDistanceProvider` - Quãng đường hôm nay (FutureProvider)
  - `stayPointsProvider` - Stay points (FutureProvider)
  - `placesProvider` - Danh sách địa điểm (StateNotifier)
  - **PlacesNotifier** - Quản lý CRUD cho places

### 4. **Screens** (`lib/screens/`)
- ✅ **map_screen.dart** - MapScreen hoàn chỉnh
  - **Flutter Map** display bản đồ
  - **Markers**:
    - Current location (điểm xanh)
    - Places (các loại màu khác nhau)
  - **Features**:
    - Tracking toggle button (bắt/dừng tracking)
    - Center button - Tập trung vào vị trí hiện tại
    - Add place button - Thêm địa điểm mới
    - Real-time location updates khi tracking
  - **_AddPlaceDialog** - Dialog thêm địa điểm
    - Input: tên, địa chỉ, loại địa điểm
  - **Info panel** - Hiển thị tọa độ hiện tại
  - **Bottom sheet** - Chi tiết địa điểm khi click

### 5. **UI Updates** (`lib/screens/`)
- ✅ **home_screen.dart** - Cập nhật HomeScreen
  - Hiển thị quãng đường hôm nay thực từ provider
  - Hiển thị số địa điểm
  - Navigation đến MapScreen từ button "Bản Đồ"
  - Other buttons hiển thị "coming soon" message

## 📊 Kiến Trúc Phase 2

```
MapScreen (UI)
    ↓
location_provider (Riverpod)
    ↓
location_service (Business Logic)
    ├── getCurrentLocation()
    ├── startLocationTracking()
    ├── detectStayPoints()
    └── Stream<LocationModel>
    
place_detection_service
    ├── detectPlaces()
    ├── _suggestPlaceType()
    └── _findMatchingPlace()

Models (Hive)
    ├── LocationModel
    ├── PlaceModel
    └── RouteModel
```

## 🔧 Cấu Hình API

Để hoạt động bình thường, cần thiết lập:

1. **Goong API Key** - `lib/utils/constants.dart`
```dart
static const String goongApiKey = 'YOUR_GOONG_API_KEY_HERE';
```

2. **Permissions** - `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

3. **iOS** - `ios/Runner/Info.plist`
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>MAPY cần truy cập vị trí để theo dõi</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>MAPY cần truy cập vị trí nền</string>
```

## 🚀 Để Chạy

```bash
cd d:\programs\mapy
flutter pub get
flutter pub run build_runner build  # Cho code generation Hive
flutter run
```

## ⚠️ Lưu Ý

1. **Hive Models** - Cần chạy `build_runner` để tạo `.g.dart` files
2. **Permissions** - Request quyền vị trí lần đầu chạy ứng dụng
3. **Location Service** - Phải bật dịch vụ vị trí trên thiết bị
4. **Location Accuracy** - Sử dụng `LocationAccuracy.high` cho kết quả chính xác

## 📋 Tính Năng Hoạt Động

✅ Lấy vị trí hiện tại
✅ Theo dõi vị trí real-time
✅ Hiển thị trên bản đồ
✅ Phát hiện stay points
✅ Gợi ý loại địa điểm
✅ Add/manage places
✅ Tính quãng đường hôm nay
✅ Navigation HomeScreen ↔ MapScreen

## ⏳ Phase 3 - Quản Lý Chi Phí (Sắp Tới)

- ExpenseModel
- ExpenseService
- Expense screens & UI
- Chi phí di chuyển tự động
- Notification parser
- Expense analytics

---

**Status**: Phase 2 ✅ 95% | Còn lại: Hive code generation

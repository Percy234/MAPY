import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle_model.dart';
import '../models/user_profile_model.dart';
import '../repositories/user_profile_repository.dart';
import '../repositories/vehicle_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late PageController _pageController;
  int _currentStep = 0;

  // Step 1 - Profile
  late TextEditingController _fullNameController;
  Gender? _selectedGender;

  // Step 2 - Vehicle
  VehicleType? _selectedVehicleType;
  late TextEditingController _vehicleNameController;
  late TextEditingController _cylinderDisplacementController;
  FuelType? _selectedFuelType;
  late TextEditingController _fuelConsumptionController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fullNameController = TextEditingController();
    _vehicleNameController = TextEditingController();
    _cylinderDisplacementController = TextEditingController();
    _fuelConsumptionController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _vehicleNameController.dispose();
    _cylinderDisplacementController.dispose();
    _fuelConsumptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thiết lập tài khoản - Bước ${_currentStep + 1}/3'),
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentStep = index);
        },
        children: [
          _buildStep1ProfilePage(),
          _buildStep2VehiclePage(),
          _buildStep3ConfirmPage(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              ElevatedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Quay lại'),
              )
            else
              const SizedBox(width: 100),
            ElevatedButton.icon(
              onPressed: _currentStep < 2 ? _nextStep : _completeSetup,
              icon: Icon(_currentStep < 2 ? Icons.arrow_forward : Icons.check),
              label: Text(_currentStep < 2 ? 'Tiếp tục' : 'Hoàn tất'),
            ),
          ],
        ),
      ),
    );
  }

  // 📋 STEP 1: Profile
  Widget _buildStep1ProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin cá nhân',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Họ và Tên',
              hintText: 'Ví dụ: Nguyễn Văn A',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Giới tính',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: Gender.values.map((gender) {
              return ChoiceChip(
                label: Text(gender.display),
                selected: _selectedGender == gender,
                onSelected: (selected) {
                  setState(() => _selectedGender = selected ? gender : null);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 🚗 STEP 2: Vehicle
  Widget _buildStep2VehiclePage() {
    final cylinderDisplacementOptions = [
      '100cc',
      '110cc',
      '125cc',
      '150cc',
      '175cc',
      '250cc',
      '300cc',
      '350cc',
    ];

    // Set mặc định nếu chưa chọn (sử dụng ??= operator)
    _selectedVehicleType ??= VehicleType.motorbike;
    _cylinderDisplacementController.text == ''
        ? _cylinderDisplacementController.text = '125cc'
        : null;
    _selectedFuelType ??= FuelType.ron95;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin phương tiện',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // 🚙 Loại phương tiện (Chọn sẵn: Xe máy)
          const Text(
            'Loại phương tiện',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [VehicleType.motorbike, VehicleType.car].map((type) {
              return ChoiceChip(
                avatar: Icon(
                  type == VehicleType.car
                      ? Icons.directions_car
                      : Icons.two_wheeler,
                  size: 18,
                ),
                label: Text(type.display),
                selected: _selectedVehicleType == type,
                onSelected: (selected) {
                  setState(() => _selectedVehicleType = selected ? type : null);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 📝 Tên phương tiện
          TextField(
            controller: _vehicleNameController,
            decoration: InputDecoration(
              labelText: 'Tên phương tiện',
              hintText: 'Ví dụ: Honda SH 150',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.label),
            ),
          ),

          const SizedBox(height: 24),

          // ⚙️ Dung tích xi lanh (Chip/Viên thuốc)
          const Text(
            'Dung tích xi lanh',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cylinderDisplacementOptions.map((cc) {
              return ChoiceChip(
                label: Text(cc),
                selected: _cylinderDisplacementController.text == cc,
                onSelected: (selected) {
                  setState(() {
                    _cylinderDisplacementController.text = selected ? cc : '';
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // ⛽ Loại nhiên liệu (Mặc định: RON95)
          const Text(
            'Loại nhiên liệu',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: FuelType.values.map((fuel) {
              return ChoiceChip(
                label: Text(fuel.display),
                selected: _selectedFuelType == fuel,
                onSelected: (selected) {
                  setState(() => _selectedFuelType = selected ? fuel : null);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 💨 Mức tiêu hao (TextField với gợi ý)
          TextField(
            controller: _fuelConsumptionController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Mức tiêu hao',
              hintText: 'Ví dụ: Xe máy thường 3.5-4.5',
              suffixText: 'L/100km',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.local_gas_station),
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: const Text(
              '💡 Mức tiêu hao trung bình xe máy: 3.5-4.5 L/100km',
              style: TextStyle(fontSize: 12, color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ STEP 3: Confirm
  Widget _buildStep3ConfirmPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Xác nhận thông tin',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Profile info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text('Họ và tên: ${_fullNameController.text}'),
                  Text('Giới tính: ${_selectedGender?.display ?? "Chưa chọn"}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Vehicle info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin phương tiện',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text('Loại: ${_selectedVehicleType?.display ?? "Chưa chọn"}'),
                  Text('Tên: ${_vehicleNameController.text}'),
                  Text('Dung tích: ${_cylinderDisplacementController.text} cc'),
                  Text(
                    'Nhiên liệu: ${_selectedFuelType?.display ?? "Chưa chọn"}',
                  ),
                  Text('Tiêu hao: ${_fuelConsumptionController.text} L/100km'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '✓ Sau khi hoàn tất, bạn có thể thay đổi thông tin này trong phần Cài đặt sau này.',
              style: TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 &&
        (_fullNameController.text.isEmpty || _selectedGender == null)) {
      _showSnackbar('Vui lòng điền đầy đủ thông tin');
      return;
    }

    if (_currentStep == 1 &&
        (_selectedVehicleType == null ||
            _vehicleNameController.text.isEmpty ||
            _selectedFuelType == null ||
            _fuelConsumptionController.text.isEmpty)) {
      _showSnackbar('Vui lòng điền đầy đủ thông tin phương tiện');
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeSetup() async {
    try {
      final userProfileRepo = UserProfileRepository();
      final vehicleRepo = VehicleRepository();

      final normalizedFuelConsumptionInput = _fuelConsumptionController.text
          .trim()
          .replaceAll(',', '.');
      final fuelConsumption = double.tryParse(normalizedFuelConsumptionInput);

      if (fuelConsumption == null || fuelConsumption <= 0) {
        _showSnackbar('Mức tiêu hao không hợp lệ. Ví dụ: 3.8');
        return;
      }

      // Tạo vehicle
      final vehicle = VehicleModel.create(
        name: _vehicleNameController.text.trim(),
        vehicleType: _selectedVehicleType!,
        fuelType: _selectedFuelType!,
        fuelConsumption: fuelConsumption / 100,
      );

      await vehicleRepo.add(vehicle);

      // Tạo user profile
      final profile = UserProfileModel.create(
        fullName: _fullNameController.text.trim(),
        gender: _selectedGender!,
        activeVehicleId: vehicle.id,
        isSetupComplete: true,
      );

      await userProfileRepo.saveProfile(profile);

      _showSnackbar('Thiết lập hoàn tất! Bắt đầu sử dụng app');

      // Điều hướng về Home
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      _showSnackbar('Lỗi: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

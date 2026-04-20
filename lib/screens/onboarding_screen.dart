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
  static const Color _petrolBlue = Color(0xFF005BAC);

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
    _fullNameController = TextEditingController();
    _vehicleNameController = TextEditingController();
    _cylinderDisplacementController = TextEditingController();
    _fuelConsumptionController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _vehicleNameController.dispose();
    _cylinderDisplacementController.dispose();
    _fuelConsumptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const totalSteps = 3;
    final progressValue = (_currentStep + 1) / totalSteps;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thiết lập tài khoản',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bắt đầu với MAPY',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hoàn tất 3 bước để tính quãng đường và chi phí theo phương tiện của bạn',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progressValue,
                                minHeight: 6,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  _petrolBlue,
                                ),
                                backgroundColor: _petrolBlue.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Bước ${_currentStep + 1}/$totalSteps',
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: KeyedSubtree(
                          key: ValueKey(_currentStep),
                          child: _buildCurrentStepContent(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          children: [
                            if (_currentStep > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextButton.icon(
                                  onPressed: _previousStep,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Quay lại'),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _currentStep < 2
                                    ? _nextStep
                                    : _completeSetup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _petrolBlue,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  _currentStep < 2 ? 'Tiếp tục' : 'Hoàn tất',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1ProfilePage();
      case 1:
        return _buildStep2VehiclePage();
      default:
        return _buildStep3ConfirmPage();
    }
  }

  // 📋 STEP 1: Profile
  Widget _buildStep1ProfilePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: _petrolBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Thông tin cá nhân',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Họ và Tên',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fullNameController,
            decoration: InputDecoration(
              hintText: 'Ví dụ: Nguyễn Văn A',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
              final isSelected = _selectedGender == gender;

              return ChoiceChip(
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: isSelected
                      ? _petrolBlue
                      : _petrolBlue.withValues(alpha: 0.35),
                ),
                selectedColor: _petrolBlue.withValues(alpha: 0.16),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? _petrolBlue : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                label: Text(gender.display),
                selected: isSelected,
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

    return Padding(
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
    return Padding(
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

    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
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

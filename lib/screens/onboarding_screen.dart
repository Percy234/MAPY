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
  String? _fuelConsumptionError;

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

  List<FuelType> _availableFuelTypes(VehicleType type) {
    switch (type) {
      case VehicleType.motorbike:
        return const [FuelType.e5Ron92, FuelType.ron95];
      case VehicleType.car:
        return const [
          FuelType.ron95,
          FuelType.ron95V,
          FuelType.e10Ron95III,
          FuelType.diesel,
          FuelType.diesel0001SV,
          FuelType.electric,
        ];
      case VehicleType.truck:
        return const [
          FuelType.diesel,
          FuelType.diesel0001SV,
          FuelType.electric,
        ];
      case VehicleType.bus:
        return const [
          FuelType.diesel,
          FuelType.diesel0001SV,
          FuelType.electric,
        ];
    }
  }

  List<String> _availableCylinderOptions(VehicleType type) {
    switch (type) {
      case VehicleType.car:
        return const ['1.0L', '1.2L', '1.5L', '2.0L', '2.5L', '3.0L'];
      case VehicleType.truck:
      case VehicleType.bus:
        return const ['2.5L', '3.0L', '4.0L', '5.0L'];
      case VehicleType.motorbike:
        return const [
          '100cc',
          '110cc',
          '125cc',
          '150cc',
          '175cc',
          '250cc',
          '300cc',
          '350cc',
        ];
    }
  }

  String? _validateFuelConsumption(
    String rawValue, {
    bool requireValue = false,
  }) {
    final normalized = rawValue.trim().replaceAll(',', '.');

    if (normalized.isEmpty) {
      return requireValue ? 'Vui lòng nhập mức tiêu hao' : null;
    }

    final value = double.tryParse(normalized);
    if (value == null) {
      return 'Mức tiêu hao phải là số hợp lệ';
    }

    if (value <= 0) {
      return 'Mức tiêu hao phải lớn hơn 0';
    }

    return null;
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
                        child: Row(
                          children: [
                            if (_currentStep > 0) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _previousStep,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: const Text('Quay lại'),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _currentStep < 2
                                    ? _nextStep
                                    : _completeSetup,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
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
    _selectedVehicleType ??= VehicleType.motorbike;
    final selectedVehicleType = _selectedVehicleType!;
    final cylinderDisplacementOptions = _availableCylinderOptions(
      selectedVehicleType,
    );
    if (_cylinderDisplacementController.text.isEmpty ||
        !cylinderDisplacementOptions.contains(
          _cylinderDisplacementController.text,
        )) {
      _cylinderDisplacementController.text = cylinderDisplacementOptions.first;
    }

    final availableFuelTypes = _availableFuelTypes(selectedVehicleType);
    if (_selectedFuelType == null ||
        !availableFuelTypes.contains(_selectedFuelType)) {
      _selectedFuelType = availableFuelTypes.first;
    }

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
            runSpacing: 8,
            children: [VehicleType.motorbike, VehicleType.car].map((type) {
              final isSelected = _selectedVehicleType == type;
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
                label: Text(type.display),
                selected: isSelected,
                onSelected: (selected) {
                  if (!selected) {
                    return;
                  }
                  setState(() {
                    _selectedVehicleType = type;

                    final nextFuelOptions = _availableFuelTypes(type);
                    if (!nextFuelOptions.contains(_selectedFuelType)) {
                      _selectedFuelType = nextFuelOptions.first;
                    }

                    final nextCylinderOptions = _availableCylinderOptions(type);
                    if (!nextCylinderOptions.contains(
                      _cylinderDisplacementController.text,
                    )) {
                      _cylinderDisplacementController.text =
                          nextCylinderOptions.first;
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 📝 Tên phương tiện
          const Text(
            'Tên phương tiện',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vehicleNameController,
            decoration: InputDecoration(
              hintText: 'Ví dụ: Honda SH 150',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
              final isSelected = _cylinderDisplacementController.text == cc;
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
                label: Text(cc),
                selected: isSelected,
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
            runSpacing: 8,
            children: availableFuelTypes.map((fuel) {
              final isSelected = _selectedFuelType == fuel;
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
                label: Text(fuel.display),
                selected: isSelected,
                onSelected: (selected) {
                  if (!selected) {
                    return;
                  }
                  setState(() => _selectedFuelType = fuel);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 💨 Mức tiêu hao (TextField với gợi ý)
          const Text(
            'Mức tiêu hao nhiên liệu',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fuelConsumptionController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              setState(() {
                _fuelConsumptionError = _validateFuelConsumption(value);
              });
            },
            decoration: InputDecoration(
              hintText: selectedVehicleType == VehicleType.car
                  ? 'Ví dụ: Ô tô thường 6.5-8.5'
                  : 'Ví dụ: Xe máy thường 3.5-4.5',
              suffixText: 'L/100km',
              errorText: _fuelConsumptionError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
          SizedBox(
            width: double.infinity,
            child: Card(
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
                    _buildInfoGrid([
                      MapEntry('Họ và tên', _fullNameController.text),
                      MapEntry(
                        'Giới tính',
                        _selectedGender?.display ?? 'Chưa chọn',
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Vehicle info
          SizedBox(
            width: double.infinity,
            child: Card(
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
                    _buildInfoGrid([
                      MapEntry(
                        'Loại',
                        _selectedVehicleType?.display ?? 'Chưa chọn',
                      ),
                      MapEntry('Tên', _vehicleNameController.text),
                      MapEntry(
                        'Dung tích',
                        '${_cylinderDisplacementController.text} cc',
                      ),
                      MapEntry(
                        'Nhiên liệu',
                        _selectedFuelType?.display ?? 'Chưa chọn',
                      ),
                      MapEntry(
                        'Tiêu hao',
                        '${_fuelConsumptionController.text} L/100km',
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(List<MapEntry<String, String>> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _buildInfoItemCard(item.key, item.value),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildInfoItemCard(String label, String value) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _petrolBlue),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? 'Chưa nhập' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 &&
        (_fullNameController.text.isEmpty || _selectedGender == null)) {
      _showSnackbar('Vui lòng điền đầy đủ thông tin');
      return;
    }

    if (_currentStep == 1) {
      final fuelConsumptionError = _validateFuelConsumption(
        _fuelConsumptionController.text,
        requireValue: true,
      );

      if (_selectedVehicleType == null ||
          _vehicleNameController.text.isEmpty ||
          _selectedFuelType == null) {
        _showSnackbar('Vui lòng điền đầy đủ thông tin phương tiện');
        return;
      }

      if (fuelConsumptionError != null) {
        setState(() => _fuelConsumptionError = fuelConsumptionError);
        _showSnackbar(fuelConsumptionError);
        return;
      }
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

      final fuelConsumptionError = _validateFuelConsumption(
        _fuelConsumptionController.text,
        requireValue: true,
      );
      if (fuelConsumptionError != null ||
          fuelConsumption == null ||
          fuelConsumption <= 0) {
        setState(() => _fuelConsumptionError = fuelConsumptionError);
        _showSnackbar(fuelConsumptionError ?? 'Mức tiêu hao không hợp lệ');
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

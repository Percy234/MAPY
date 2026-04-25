import 'package:flutter/material.dart';

import '../models/user_profile_model.dart';
import '../models/vehicle_model.dart';
import '../repositories/user_profile_repository.dart';
import '../repositories/vehicle_repository.dart';

class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  final UserProfileRepository _profileRepository = UserProfileRepository();
  final VehicleRepository _vehicleRepository = VehicleRepository();

  bool _isLoading = true;
  UserProfileModel? _profile;
  List<VehicleModel> _vehicles = const <VehicleModel>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final profile = await _profileRepository.getProfile();
    final vehicles = await _vehicleRepository.getAllVehicles();

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
      _vehicles = vehicles;
      _isLoading = false;
    });
  }

  VehicleModel? get _activeVehicle {
    final activeId = _profile?.activeVehicleId;
    if (activeId == null) {
      return _vehicles.isNotEmpty ? _vehicles.first : null;
    }

    for (final vehicle in _vehicles) {
      if (vehicle.id == activeId) {
        return vehicle;
      }
    }

    return _vehicles.isNotEmpty ? _vehicles.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileSection(),
                  const SizedBox(height: 16),
                  _buildActiveVehicleSection(),
                  const SizedBox(height: 16),
                  _buildVehicleListSection(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Thêm phương tiện'),
      ),
    );
  }

  Widget _buildProfileSection() {
    if (_profile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Tài khoản',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Chưa có dữ liệu tài khoản. Hãy chạy onboarding để thiết lập.',
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tài khoản',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Chỉnh sửa'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Họ tên: ${_profile!.fullName}'),
            Text('Giới tính: ${_profile!.gender.display}'),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVehicleSection() {
    final activeVehicle = _activeVehicle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phương tiện đang dùng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (activeVehicle == null)
              const Text('Chưa có phương tiện nào được chọn.')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeVehicle.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('Loại: ${activeVehicle.vehicleType.display}'),
                  Text('Nhiên liệu: ${activeVehicle.fuelType.display}'),
                  Text(
                    'Tiêu hao: ${(activeVehicle.fuelConsumption * 100).toStringAsFixed(2)} L/100km',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleListSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Danh sách phương tiện',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Chưa có phương tiện. Bấm "Thêm phương tiện" để tạo mới.',
                ),
              )
            else
              ..._vehicles.map((vehicle) {
                final isActive = vehicle.id == _profile?.activeVehicleId;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    vehicle.vehicleType == VehicleType.car
                        ? Icons.directions_car
                        : Icons.two_wheeler,
                  ),
                  title: Text(vehicle.name),
                  subtitle: Text(
                    '${vehicle.vehicleType.display} - ${vehicle.fuelType.display}\n${(vehicle.fuelConsumption * 100).toStringAsFixed(2)} L/100km',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'active') {
                        _setActiveVehicle(vehicle.id);
                      } else if (value == 'delete') {
                        _deleteVehicle(vehicle.id);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'active',
                        enabled: !isActive,
                        child: const Text('Đặt làm phương tiện chính'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Xóa phương tiện'),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final currentProfile = _profile;
    if (currentProfile == null) {
      return;
    }

    final nameController = TextEditingController(text: currentProfile.fullName);
    Gender selectedGender = currentProfile.gender;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cập nhật tài khoản'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Gender>(
                    initialValue: selectedGender,
                    decoration: const InputDecoration(labelText: 'Giới tính'),
                    items: Gender.values
                        .map(
                          (gender) => DropdownMenuItem<Gender>(
                            value: gender,
                            child: Text(gender.display),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedGender = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) {
                      return;
                    }

                    await _profileRepository.updateProfile(
                      currentProfile.copyWith(
                        fullName: newName,
                        gender: selectedGender,
                      ),
                    );

                    if (!dialogContext.mounted || !mounted) {
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    await _loadData();
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddVehicleDialog() async {
    final nameController = TextEditingController();
    final consumptionController = TextEditingController();

    List<FuelType> fuelOptionsFor(VehicleType type) {
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
        case VehicleType.bus:
          return const [
            FuelType.diesel,
            FuelType.diesel0001SV,
            FuelType.electric,
          ];
      }
    }

    VehicleType selectedType = VehicleType.motorbike;
    FuelType selectedFuel = fuelOptionsFor(selectedType).first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm phương tiện'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên phương tiện',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<VehicleType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Loại phương tiện',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: VehicleType.motorbike,
                          child: Text('Xe máy'),
                        ),
                        DropdownMenuItem(
                          value: VehicleType.car,
                          child: Text('Ô tô'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedType = value;
                          final nextFuelOptions = fuelOptionsFor(selectedType);
                          if (!nextFuelOptions.contains(selectedFuel)) {
                            selectedFuel = nextFuelOptions.first;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<FuelType>(
                      initialValue: selectedFuel,
                      decoration: const InputDecoration(
                        labelText: 'Loại nhiên liệu',
                      ),
                      items: fuelOptionsFor(selectedType)
                          .map(
                            (fuel) => DropdownMenuItem<FuelType>(
                              value: fuel,
                              child: Text(fuel.display),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedFuel = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: consumptionController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tiêu hao (L/100km)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final consumption100 = double.tryParse(
                      consumptionController.text.trim(),
                    );

                    if (name.isEmpty ||
                        consumption100 == null ||
                        consumption100 <= 0) {
                      return;
                    }

                    final vehicle = VehicleModel.create(
                      name: name,
                      vehicleType: selectedType,
                      fuelType: selectedFuel,
                      fuelConsumption: consumption100 / 100,
                    );
                    await _vehicleRepository.addVehicle(vehicle);

                    final profile = _profile;
                    if (profile != null && profile.activeVehicleId == null) {
                      await _profileRepository.updateProfile(
                        profile.copyWith(activeVehicleId: vehicle.id),
                      );
                    }

                    if (!dialogContext.mounted || !mounted) {
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    await _loadData();
                  },
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setActiveVehicle(String vehicleId) async {
    final profile = _profile;
    if (profile == null) {
      return;
    }

    await _profileRepository.updateProfile(
      profile.copyWith(activeVehicleId: vehicleId),
    );
    await _loadData();
  }

  Future<void> _deleteVehicle(String vehicleId) async {
    await _vehicleRepository.deleteVehicle(vehicleId);

    final profile = _profile;
    if (profile != null && profile.activeVehicleId == vehicleId) {
      final remainingVehicles = await _vehicleRepository.getAllVehicles();
      final nextActiveVehicleId = remainingVehicles.isNotEmpty
          ? remainingVehicles.first.id
          : null;
      await _profileRepository.updateProfile(
        profile.copyWith(activeVehicleId: nextActiveVehicleId),
      );
    }

    await _loadData();
  }
}

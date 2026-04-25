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
  static const Color _petrolBlue = Color(0xFF005BAC);

  final UserProfileRepository _profileRepository = UserProfileRepository();
  final VehicleRepository _vehicleRepository = VehicleRepository();
  final TextEditingController _vehicleSearchController =
      TextEditingController();

  bool _isLoading = true;
  UserProfileModel? _profile;
  List<VehicleModel> _vehicles = const <VehicleModel>[];
  bool _isVehicleSearchVisible = false;
  String _vehicleSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _vehicleSearchController.dispose();
    super.dispose();
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 8),
            _buildHeaderSection(context),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildProfileSection(),
              const SizedBox(height: 16),
              _buildActiveVehicleSection(),
              const SizedBox(height: 16),
              _buildVehicleListSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cá nhân',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadData,
                  tooltip: 'Làm mới dữ liệu',
                  icon: const Icon(Icons.refresh, color: _petrolBlue),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tài khoản và phương tiện',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Quản lý thông tin cá nhân, phương tiện chính và danh sách phương tiện của bạn.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
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
            const SizedBox(height: 12),
            _buildInfoGrid([
              MapEntry('Họ tên', _profile!.fullName),
              MapEntry('Giới tính', _profile!.gender.display),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVehicleSection() {
    final activeVehicle = _activeVehicle;
    final fuelConsumptionText = activeVehicle == null
        ? 'Chưa chọn'
        : '${(activeVehicle.fuelConsumption * 100).toStringAsFixed(2)} L/100km';

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
            const SizedBox(height: 12),
            _buildInfoGrid([
              MapEntry('Tên phương tiện', activeVehicle?.name ?? 'Chưa chọn'),
              MapEntry('Loại', activeVehicle?.vehicleType.display ?? 'Chưa chọn'),
              MapEntry('Nhiên liệu', activeVehicle?.fuelType.display ?? 'Chưa chọn'),
              MapEntry('Tiêu hao', fuelConsumptionText),
            ]),
          ],
        ),
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

  Widget _buildVehicleListSection() {
    final normalizedQuery = _vehicleSearchQuery.trim().toLowerCase();
    final filteredVehicles = normalizedQuery.isEmpty
        ? _vehicles
        : _vehicles.where((vehicle) {
            final keywords =
                '${vehicle.name} ${vehicle.vehicleType.display} ${vehicle.fuelType.display}'
                    .toLowerCase();
            return keywords.contains(normalizedQuery);
          }).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Danh sách phương tiện',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 132,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isVehicleSearchVisible = !_isVehicleSearchVisible;
                        if (!_isVehicleSearchVisible) {
                          _vehicleSearchQuery = '';
                          _vehicleSearchController.clear();
                        }
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(132, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: Icon(
                      _isVehicleSearchVisible ? Icons.close : Icons.search,
                      size: 18,
                    ),
                    label: Text(
                      _isVehicleSearchVisible ? 'Đóng tìm' : 'Tìm kiếm',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _showAddVehicleDialog,
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(40, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isVehicleSearchVisible) ...[
              TextField(
                controller: _vehicleSearchController,
                onChanged: (value) {
                  setState(() {
                    _vehicleSearchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, loại, nhiên liệu',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _vehicleSearchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              _vehicleSearchQuery = '';
                              _vehicleSearchController.clear();
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (filteredVehicles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  normalizedQuery.isEmpty
                      ? 'Chưa có phương tiện. Bấm "Thêm" để tạo mới.'
                      : 'Không tìm thấy phương tiện phù hợp.',
                ),
              )
            else
              ...filteredVehicles.map((vehicle) {
                final isActive = vehicle.id == _profile?.activeVehicleId;
                return _buildVehicleCardItem(vehicle: vehicle, isActive: isActive);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCardItem({
    required VehicleModel vehicle,
    required bool isActive,
  }) {
    final fuelConsumptionText =
        '${(vehicle.fuelConsumption * 100).toStringAsFixed(2)} L/100km';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          color: isActive ? _petrolBlue.withValues(alpha: 0.05) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isActive
                  ? _petrolBlue
                  : _petrolBlue.withValues(alpha: 0.25),
              width: isActive ? 1.8 : 1,
            ),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      vehicle.vehicleType == VehicleType.car
                          ? Icons.directions_car
                          : Icons.two_wheeler,
                      color: _petrolBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        vehicle.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
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
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildVehicleInlineInfo('Loại xe', vehicle.vehicleType.display),
                    const SizedBox(width: 8),
                    _buildVehicleInlineInfo('Nhiên liệu', vehicle.fuelType.display),
                    const SizedBox(width: 8),
                    _buildVehicleInlineInfo('Tiêu hao', fuelConsumptionText),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInlineInfo(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: _petrolBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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

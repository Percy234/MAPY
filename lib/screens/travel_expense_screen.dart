import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/vehicle_model.dart';
import '../providers/location_provider.dart';
import '../providers/travel_expense_provider.dart';
import '../services/petrolimex_service.dart';

class TravelExpenseScreen extends ConsumerWidget {
  const TravelExpenseScreen({super.key});
  static const Color _petrolBlue = Color(0xFF005BAC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayExpenses = ref.watch(todayTravelExpensesProvider);
    final dailyDistance = ref.watch(dailyDistanceProvider);
    final todayFuelCost = ref.watch(todayFuelCostProvider);
    final petrolimexPrices = ref.watch(petrolimexPricesProvider);
    final activeVehicle = ref.watch(activeVehicleProvider);
    final selectedFuelZone = ref.watch(selectedFuelZoneProvider);
    final priceFormatter = NumberFormat.decimalPattern('vi_VN');
    final dateTimeFormatter = DateFormat('HH:mm - dd/MM/yyyy');
    final latestSyncedFormatter = DateFormat('HH:mm dd/MM');

    final todayDistanceFromExpenses = todayExpenses.maybeWhen(
      data: (expenses) =>
          expenses.fold<double>(0, (sum, expense) => sum + expense.distance),
      orElse: () => 0,
    );
    final todayDistanceFromTracking = dailyDistance.maybeWhen(
      data: (distance) => distance,
      orElse: () => 0,
    );
    final todayDistance = math.max(
      todayDistanceFromExpenses,
      todayDistanceFromTracking,
    );
    final consumption = activeVehicle.maybeWhen(
      data: (vehicle) => vehicle?.fuelConsumption ?? 0,
      orElse: () => 0,
    );
    final fuelPriceByZone = petrolimexPrices.maybeWhen(
      data: (prices) => _resolveFuelPriceByZone(
        prices: prices,
        vehicle: activeVehicle.valueOrNull,
        zone: selectedFuelZone,
      ),
      orElse: () => 0,
    );
    final estimatedCost = todayDistance * consumption * fuelPriceByZone;
    final persistedTodayFuelCost = todayFuelCost.maybeWhen(
      data: (cost) => cost,
      orElse: () => 0,
    );
    final totalCost = math.max(estimatedCost, persistedTodayFuelCost);
    final estimatedFuel = todayDistance * consumption;
    final fuelTypeText = activeVehicle.maybeWhen(
      data: (vehicle) => vehicle?.fuelType.display ?? '--',
      orElse: () => '--',
    );
    final latestSyncedAt = petrolimexPrices.maybeWhen(
      data: (prices) {
        if (prices.isEmpty) {
          return null;
        }
        return prices
            .map((price) => price.updatedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      },
      orElse: () => null,
    );
    final latestSyncedText = latestSyncedAt == null
        ? '--'
        : latestSyncedFormatter.format(latestSyncedAt);
    final totalCostText = '${priceFormatter.format(totalCost.round())}đ';
    final priceByZoneText =
        '${priceFormatter.format(fuelPriceByZone.round())}đ/L';
    final formulaText =
        '${todayDistance.toStringAsFixed(2)} km x ${consumption.toStringAsFixed(2)} L/km x ${selectedFuelZone == 1 ? 'Vùng 1' : 'Vùng 2'} ($priceByZoneText)';

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          // Tổng quan chi phí
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chi phí',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bảng giá xăng dầu và chi phí đi lại',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Theo dõi chi phí xăng dầu hôm nay và cập nhật giá xăng mới nhất từ Petrolimex.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          petrolimexPrices.when(
            data: (prices) {
              if (prices.isEmpty) {
                return const Text('Không có dữ liệu giá xăng từ Petrolimex');
              }

              final latestUpdatedAt = prices
                  .map((price) => price.updatedAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b);

              return Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_gas_station,
                                  color: _petrolBlue,
                                ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Text(
                                    'Bảng giá bán lẻ xăng dầu',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '* Đơn vị: VND',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: DataTable(
                                  columnSpacing: 20,
                                  horizontalMargin: 12,
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Sản phẩm',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Vùng 1',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Vùng 2',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: prices.map((price) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 180,
                                            child: Text(
                                              price.productName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            priceFormatter.format(
                                              price.zone1Price.round(),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            priceFormatter.format(
                                              price.zone2Price.round(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Giá cập nhật: ${dateTimeFormatter.format(latestUpdatedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => ref
                                .read(refreshPetrolimexPricesProvider.notifier)
                                .refresh(),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Làm mới'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (err, _) => Text('Lỗi: $err'),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chi phí hôm nay',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _buildZoneButton(
                        context,
                        label: 'Vùng 1',
                        selected: selectedFuelZone == 1,
                        onPressed: () =>
                            ref.read(selectedFuelZoneProvider.notifier).state =
                                1,
                      ),
                      const SizedBox(width: 8),
                      _buildZoneButton(
                        context,
                        label: 'Vùng 2',
                        selected: selectedFuelZone == 2,
                        onPressed: () =>
                            ref.read(selectedFuelZoneProvider.notifier).state =
                                2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    totalCostText,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _petrolBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$formulaText = ${priceFormatter.format(totalCost.round())}đ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 120,
            ),
            children: [
              _buildTodayInfoBlock(
                context,
                icon: Icons.route,
                title: 'Quãng đường',
                value: '${todayDistance.toStringAsFixed(2)} km',
                caption: 'Tính từ khi di chuyển đến hiện tại',
              ),
              _buildTodayInfoBlock(
                context,
                icon: Icons.local_gas_station,
                title: 'Nhiên liệu ước tính',
                value: '${estimatedFuel.toStringAsFixed(2)} L',
                caption: 'Số nhiên liệu tiêu hao ước tính',
              ),
              _buildTodayInfoBlock(
                context,
                icon: Icons.ev_station,
                title: 'Loại nhiên liệu',
                value: fuelTypeText,
                caption: 'Theo phương tiện di chuyển chính',
              ),
              _buildTodayInfoBlock(
                context,
                icon: Icons.schedule,
                title: 'Đồng bộ gần nhất',
                value: latestSyncedText,
                caption: 'Theo lần cập nhật bảng giá xăng',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayInfoBlock(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String caption,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: _petrolBlue),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: selected ? _petrolBlue : Colors.grey.shade400),
        backgroundColor: selected
            ? _petrolBlue.withValues(alpha: 0.14)
            : Colors.transparent,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? _petrolBlue : Colors.black87,
        ),
      ),
    );
  }

  double _resolveFuelPriceByZone({
    required List<PetrolimexRetailPrice> prices,
    required VehicleModel? vehicle,
    required int zone,
  }) {
    if (vehicle == null) {
      return 0;
    }

    PetrolimexRetailPrice? findByKeywords(List<String> keywords) {
      for (final price in prices) {
        final normalized = price.productName.toUpperCase();
        if (keywords.any((keyword) => normalized.contains(keyword))) {
          return price;
        }
      }
      return null;
    }

    final matchedPrice = switch (vehicle.fuelType) {
      FuelType.e5Ron92 => findByKeywords(['E5 RON 92']),
      FuelType.ron95 =>
        findByKeywords(['RON 95-III']) ??
            findByKeywords(['RON 95-V', 'RON 95']),
      FuelType.diesel =>
        findByKeywords(['DO 0,05S-II']) ??
            findByKeywords(['DO 0,001S-V', 'DO 0.001S-V']),
    };

    if (matchedPrice == null) {
      return 0;
    }

    return zone == 2 ? matchedPrice.zone2Price : matchedPrice.zone1Price;
  }
}

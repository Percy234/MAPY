import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/place_model.dart';
import '../models/vehicle_model.dart';
import '../providers/location_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/route_provider.dart';
import '../providers/travel_expense_provider.dart';
import '../services/petrolimex_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const Color _petrolBlue = Color(0xFF005BAC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyDistance = ref.watch(dailyDistanceProvider);
    final todayExpenses = ref.watch(todayTravelExpensesProvider);
    final places = ref.watch(placesProvider);
    final todayFuelCost = ref.watch(todayFuelCostProvider);
    final petrolimexPrices = ref.watch(petrolimexPricesProvider);
    final selectedFuelZone = ref.watch(selectedFuelZoneProvider);
    final routes = ref.watch(allRoutesProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    final activeVehicle = ref.watch(activeVehicleProvider);

    final now = DateTime.now();
    final currencyFormatter = NumberFormat.decimalPattern('vi_VN');
    final visitedPlacesToday = places.where((place) {
      final lastVisited = place.lastVisited;
      return lastVisited != null && _isSameDay(lastVisited, now);
    }).length;
    final distanceFromTracking = dailyDistance.maybeWhen(
      data: (distance) => distance,
      orElse: () => 0,
    );
    final distanceFromExpenses = todayExpenses.maybeWhen(
      data: (expenses) =>
          expenses.fold<double>(0.0, (sum, expense) => sum + expense.distance),
      orElse: () => 0,
    );
    final totalDistanceKm = math.max(distanceFromTracking, distanceFromExpenses);

    final rawLatestSpeedKmh = (currentLocation?.speed ?? 0) * 3.6;
    final latestSpeedKmh = rawLatestSpeedKmh < 0 ? 0.0 : rawLatestSpeedKmh;
    final latestSpeedText = currentLocation == null
        ? '-- km/h'
        : '${latestSpeedKmh.toStringAsFixed(1)} km/h';
    final fuelConsumptionPerKm = activeVehicle.maybeWhen(
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
    final estimatedTodayCost =
        totalDistanceKm * fuelConsumptionPerKm * fuelPriceByZone;
    final persistedTodayCost = todayFuelCost.maybeWhen(
      data: (cost) => cost,
      orElse: () => 0,
    );
    final calculatedTodayCost = todayExpenses.maybeWhen(
      data: (expenses) =>
          expenses.fold<double>(0.0, (sum, expense) => sum + expense.fuelCost),
      orElse: () => 0,
    );
    final totalTodayCost = math.max(
      math.max(persistedTodayCost, calculatedTodayCost),
      estimatedTodayCost,
    );
    final isCostLoading =
        todayFuelCost.isLoading &&
        todayExpenses.isLoading &&
        petrolimexPrices.isLoading;
    final todayCostText = isCostLoading
        ? 'Đang tải...'
        : '${currencyFormatter.format(totalTodayCost.round())}đ';

    final estimatedFuelText = '${(totalDistanceKm * fuelConsumptionPerKm).toStringAsFixed(2)}L';

    final recentlyVisitedPlaces =
        places
            .where((place) => place.lastVisited != null)
            .toList(growable: false)
          ..sort((a, b) => b.lastVisited!.compareTo(a.lastVisited!));
    final previewVisitedPlaces = recentlyVisitedPlaces
        .take(3)
        .toList(growable: false);

    final travelDurationToday = routes.maybeWhen(
      data: (allRoutes) {
        var totalSeconds = 0;
        for (final route in allRoutes) {
          if (!_isSameDay(route.startTime, now)) {
            continue;
          }

          final endTime = route.endTime ?? now;
          if (endTime.isBefore(route.startTime)) {
            continue;
          }
          totalSeconds += endTime.difference(route.startTime).inSeconds;
        }
        return Duration(seconds: totalSeconds);
      },
      orElse: () => Duration.zero,
    );

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MAPY',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tổng quan hôm nay',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Theo dõi nhanh quãng đường và các điểm đã ghé trong ngày.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            context,
            title: 'Quãng Đường Hôm Nay',
            value: '',
            customValue: (dailyDistance.isLoading && todayExpenses.isLoading)
                ? Text(
                'Đang tải...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _petrolBlue,
                  fontWeight: FontWeight.w700,
                ),
                )
                : _buildDistanceValue(
                    context,
                    number: totalDistanceKm.toStringAsFixed(2),
                  ),
            icon: Icons.directions,
            color: Colors.blueAccent,
            hideIcon: true,
            emphasizedValue: true,
            subtitle: 'Nhiên liệu ước tính: $estimatedFuelText',
            extraContent: _buildTodayMetricsGrid(
              context,
              costText: todayCostText,
              visitedPlacesText: '$visitedPlacesToday điểm',
              latestSpeedText: latestSpeedText,
              travelDurationText: _formatDuration(travelDurationToday),
            ),
          ),
          const SizedBox(height: 12),
          _buildVisitedPlacesCard(
            context,
            ref: ref,
            places: previewVisitedPlaces,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dùng thanh điều hướng bên dưới để chuyển nhanh giữa Di chuyển, Chi phí và Cá nhân.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool hideIcon = false,
    bool emphasizedValue = false,
    String? subtitle,
    Widget? extraContent,
    Widget? customValue,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (!hideIcon)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
            if (!hideIcon) const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  if (customValue != null)
                    customValue
                  else
                    Text(
                      value,
                      style: emphasizedValue
                          ? Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            )
                          : Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(color: color),
                    ),
                  if (subtitle case final subtitleText?) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                  ],
                  if (extraContent case final content?) ...[
                    const SizedBox(height: 12),
                    content,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceValue(BuildContext context, {required String number}) {
    final numberStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: _petrolBlue,
      height: 1,
    );
    final unitStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
      height: 1,
    );

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: number, style: numberStyle),
          TextSpan(text: ' Km', style: unitStyle),
        ],
      ),
    );
  }

  Widget _buildVisitedPlacesCard(
    BuildContext context, {
    required WidgetRef ref,
    required List<PlaceModel> places,
  }) {
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
                    'Địa điểm đã đi qua',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(mainNavigationIndexProvider.notifier).state = 1;
                  },
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (places.isEmpty)
              Text(
                'Chưa có địa điểm nào vừa đi qua.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              )
            else
              Column(
                children: places
                    .map((place) => _buildVisitedPlaceItem(context, place))
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitedPlaceItem(BuildContext context, PlaceModel place) {
    final visitedAt = place.lastVisited;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 18, color: _petrolBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            visitedAt == null ? '--' : DateFormat('HH:mm').format(visitedAt),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMetricsGrid(
    BuildContext context, {
    required String costText,
    required String visitedPlacesText,
    required String latestSpeedText,
    required String travelDurationText,
  }) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 90,
      ),
      children: [
        _buildMetricBlock(
          context,
          title: 'Chi phí',
          value: costText,
          icon: Icons.payments_outlined,
          color: _petrolBlue,
        ),
        _buildMetricBlock(
          context,
          title: 'Địa điểm ghé',
          value: visitedPlacesText,
          icon: Icons.place_outlined,
          color: _petrolBlue,
        ),
        _buildMetricBlock(
          context,
          title: 'Tốc độ gần nhất',
          value: latestSpeedText,
          icon: Icons.speed,
          color: _petrolBlue,
        ),
        _buildMetricBlock(
          context,
          title: 'Thời gian di chuyển',
          value: travelDurationText,
          icon: Icons.timer_outlined,
          color: _petrolBlue,
        ),
      ],
    );
  }

  Widget _buildMetricBlock(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes <= 0) {
      return '0 phút';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours == 0) {
      return '$minutes phút';
    }
    if (minutes == 0) {
      return '$hours giờ';
    }
    return '$hours giờ $minutes phút';
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

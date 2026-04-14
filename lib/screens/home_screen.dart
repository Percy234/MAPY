import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyDistance = ref.watch(dailyDistanceProvider);
    final places = ref.watch(placesProvider);

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
            value: dailyDistance.maybeWhen(
              data: (distance) => '${distance.toStringAsFixed(2)} km',
              loading: () => 'Đang tải...',
              error: (_, _) => '-- km',
              orElse: () => '0 km',
            ),
            icon: Icons.directions,
            color: Colors.blueAccent,
            hideIcon: true,
            emphasizedValue: true,
            subtitle: 'Nhiên liệu: 0.00L',
          ),
          const SizedBox(height: 12),
          _buildCard(
            context,
            title: 'Địa Điểm',
            value: '${places.length}',
            icon: Icons.location_on,
            color: Colors.greenAccent,
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
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: emphasizedValue
                        ? Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          )
                        : Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: color,
                          ),
                  ),
                  if (subtitle != null) const SizedBox(height: 4),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

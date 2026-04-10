import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';
import '../screens/map_screen.dart';
import '../screens/travel_expense_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyDistance = ref.watch(dailyDistanceProvider);
    final places = ref.watch(placesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MAPY'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          ),
          const SizedBox(height: 12),
          _buildCard(
            context,
            title: 'Địa Điểm',
            value: '${places.length}',
            icon: Icons.location_on,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 24),
          const Text(
            'Chức Năng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuButton(
            context,
            title: 'Bản Đồ',
            subtitle: 'Theo dõi vị trí',
            icon: Icons.map,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildMenuButton(
            context,
            title: 'Địa Điểm',
            subtitle: 'Danh sách địa điểm',
            icon: Icons.place,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('⏳ Chức năng đang phát triển')),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildMenuButton(
            context,
            title: 'Thống Kê',
            subtitle: 'Phân tích chi phí xăng',
            icon: Icons.bar_chart,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TravelExpenseScreen()),
              );
            },
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
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
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

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../providers/travel_expense_provider.dart';

class TravelExpenseScreen extends ConsumerWidget {
  const TravelExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayFuelCost = ref.watch(todayFuelCostProvider);
    final todayExpenses = ref.watch(todayTravelExpensesProvider);
    final monthFuelCost = ref.watch(monthTravelExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Phí Xăng'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tóm tắt
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hôm Nay',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    todayFuelCost.maybeWhen(
                      data: (cost) => Text(
                        '${cost.toStringAsFixed(0)} ₫',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, _) => const Text('Lỗi'),
                      orElse: () => const Text('0 ₫'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tháng Này',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    monthFuelCost.maybeWhen(
                      data: (cost) => Text(
                        '${cost.toStringAsFixed(0)} ₫',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.orange),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, _) => const Text('Lỗi'),
                      orElse: () => const Text('0 ₫'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Danh sách hôm nay
            const Text(
              'Chi Phí Hôm Nay',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            todayExpenses.maybeWhen(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Chưa có chi phí xăng hôm nay'),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expenses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return _buildExpenseCard(context, expense);
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => const Text('Lỗi tải dữ liệu'),
              orElse: () => const Text('Không có dữ liệu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    TravelExpenseModel expense,
  ) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.local_gas_station,
            color: Colors.orange,
          ),
        ),
        title: Text('${expense.distance.toStringAsFixed(1)} km'),
        subtitle: Text(
          '${expense.fuelConsumption.toStringAsFixed(2)} L/km × ${expense.fuelPrice.toStringAsFixed(0)} ₫/L',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${expense.fuelCost.toStringAsFixed(0)} ₫',
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_provider.dart';

import 'home_screen.dart';
import 'map_screen.dart';
import 'personal_screen.dart';
import 'travel_expense_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  static const Color _petrolBlue = Color(0xFF005BAC);
  static const Color _selectedTileColor = Color(0xFFE6F1FF);

  static const List<Widget> _tabs = <Widget>[
    HomeScreen(),
    MapScreen(),
    TravelExpenseScreen(),
    PersonalScreen(),
  ];

  static const List<_BottomNavItem> _items = <_BottomNavItem>[
    _BottomNavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Tổng quan',
    ),
    _BottomNavItem(
      icon: Icons.alt_route_outlined,
      selectedIcon: Icons.alt_route,
      label: 'Di chuyển',
    ),
    _BottomNavItem(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'Chi phí',
    ),
    _BottomNavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Cá nhân',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainNavigationIndexProvider);

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _tabs),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 58,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.8),
              ),
            ),
          ),
          child: Row(
            children: List<Widget>.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = currentIndex == index;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        ref.read(mainNavigationIndexProvider.notifier).state =
                            index;
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedTileColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              size: 19,
                              color: isSelected ? _petrolBlue : Colors.black54,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? _petrolBlue
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/orders/application/orders_controller.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// Main shell with bottom navigation: Customers | Orders | Settings.
/// Settings holds Edit Profile, Change Password, Upgrade Plan, Log out.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _NavItem(icon: Icons.people_rounded, label: 'Customers'),
    _NavItem(icon: Icons.assignment_rounded, label: 'Orders'),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    final upcomingCount = ordersAsync.valueOrNull
        ?.where((o) {
          if (o.status == 'delivered' || o.status == 'cancelled') return false;
          if (o.dueDate == null) return false;
          final d = DateTime(o.dueDate!.year, o.dueDate!.month, o.dueDate!.day);
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          final end = today.add(const Duration(days: 7));
          return !d.isBefore(today) && !d.isAfter(end);
        })
        .length ?? 0;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          CustomersScreen(),
          OrdersScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.people_rounded),
            selectedIcon: const Icon(Icons.people_rounded, color: AppColors.primary),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: upcomingCount > 0,
              label: Text('$upcomingCount'),
              child: const Icon(Icons.assignment_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: upcomingCount > 0,
              label: Text('$upcomingCount'),
              child: const Icon(Icons.assignment_rounded, color: AppColors.primary),
            ),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

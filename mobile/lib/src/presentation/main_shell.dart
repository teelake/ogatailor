import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// Main shell with bottom navigation: Customers | Orders | Settings.
/// Settings holds Edit Profile, Change Password, Upgrade Plan, Log out.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _NavItem(icon: Icons.people_rounded, label: 'Customers'),
    _NavItem(icon: Icons.assignment_rounded, label: 'Orders'),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
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
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.icon, color: AppColors.primary),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

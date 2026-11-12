import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';

/// Student bottom bar: Home · Scan · Orders · Profile.
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = ['/home', '/scan', '/orders', '/profile'];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere(location.startsWith);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: context.tr('Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: context.tr('Scan'),
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: context.tr('Orders'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: context.tr('Profile'),
          ),
        ],
      ),
    );
  }
}

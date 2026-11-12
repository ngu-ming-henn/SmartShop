import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';

/// Staff bottom bar: Dashboard · Stock · Orders · Reports · More.
class StaffShell extends StatelessWidget {
  const StaffShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = [
    '/staff',
    '/staff/stock',
    '/staff/orders',
    '/staff/reports',
    '/staff/more',
  ];

  int get _index {
    for (var i = _tabs.length - 1; i > 0; i--) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: context.tr('Dashboard'),
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: context.tr('Stock'),
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: context.tr('Orders'),
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: context.tr('Reports'),
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: context.tr('More'),
          ),
        ],
      ),
    );
  }
}

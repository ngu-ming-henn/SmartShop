import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/staff/dashboard_view_model.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Today's sales, pending orders, low-stock count, near-expiry count.
/// All numbers come from [DashboardViewModel] and update live.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final user = context.watch<AuthViewModel>().user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Dashboard'))),
      body: Builder(
        builder: (context) {
          if (vm.error != null) return ErrorView(error: vm.error!);
          final todayOrders = vm.todaySales;
          final columns = gridColumns(context, minTileWidth: 160);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.tr('Hello, {name} 👋', {
                  'name': user?.name.split(' ').first ?? '',
                }),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatDate(DateTime.now()),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (vm.shopIsEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: _EmptyShopCard(),
                ),
              FadeSlideIn(
                child: GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: [
                    StatCard(
                      label: context.tr("Today's sales ({count} orders)", {
                        'count': todayOrders.length,
                      }),
                      value: formatRM(vm.salesTodaySen),
                      icon: Icons.payments_outlined,
                      color: context.brand,
                      onTap: () => context.go('/staff/reports'),
                    ),
                    StatCard(
                      label: context.tr('Pending orders · {ready} ready', {
                        'ready': vm.readyCount,
                      }),
                      value: '${vm.pendingCount}',
                      icon: Icons.pending_actions,
                      color: const Color(0xFF1565C0),
                      onTap: () => context.go('/staff/orders'),
                    ),
                    StatCard(
                      label: context.tr('Low stock'),
                      value: '${vm.lowStockCount}',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      onTap: () => context.push('/staff/alerts'),
                    ),
                    StatCard(
                      label: context.tr('Near expiry'),
                      value: '${vm.nearExpiryCount}',
                      icon: Icons.timer_outlined,
                      color: const Color(0xFFB26A00),
                      onTap: () => context.push('/staff/alerts?tab=expiry'),
                    ),
                  ],
                ),
              ),
              SectionHeader(title: context.tr('Quick actions')),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _QuickAction(
                          icon: Icons.point_of_sale,
                          color: const Color(0xFF3A57E8),
                          label: context.tr('Counter sale'),
                          onTap: () => context.push('/staff/counter'),
                        ),
                        _QuickAction(
                          icon: Icons.move_to_inbox,
                          color: const Color(0xFF2E7D32),
                          label: context.tr('Stock in'),
                          onTap: () => context.go('/staff/stock'),
                        ),
                        _QuickAction(
                          icon: Icons.qr_code_scanner,
                          color: const Color(0xFFB26A00),
                          label: context.tr('Pickup'),
                          onTap: () => context.go('/staff/orders'),
                        ),
                        _QuickAction(
                          icon: Icons.add_box_outlined,
                          color: const Color(0xFF8E24AA),
                          label: context.tr('Add product'),
                          onTap: () => context.push('/staff/product-new'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SectionHeader(title: context.tr("Today's sales")),
              if (vm.loadingSales)
                const LoadingView()
              else if (todayOrders.isEmpty)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.receipt_long_outlined),
                    title: Text(context.tr('No sales yet today')),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final o in todayOrders.take(8))
                        ListTile(
                          onTap: () => context.push('/receipt/${o.id}'),
                          leading: Icon(
                            o.isPreorder
                                ? Icons.shopping_bag_outlined
                                : Icons.point_of_sale,
                          ),
                          title: Text(
                            '${o.customerName ?? context.tr('Walk-in')} · '
                            '${context.tr('{count} item(s)', {'count': o.itemCount})}',
                          ),
                          subtitle: Text(
                            '${formatTime(o.collectedAt ?? o.sortTime)} · '
                            '${context.tr(o.isPreorder ? 'Pre-order' : 'Counter')}',
                          ),
                          trailing: Text(
                            formatRM(o.totalSen),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Shown while the shop has no products: one tap loads the demo catalogue.
class _EmptyShopCard extends StatelessWidget {
  const _EmptyShopCard();

  Future<void> _load(BuildContext context) async {
    try {
      final added = await context
          .read<DashboardViewModel>()
          .loadSampleProducts();
      if (context.mounted) {
        showSnack(
          context,
          context.tr('Added {count} products.', {'count': added}),
        );
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<DashboardViewModel>();
    return FadeSlideIn(
      child: Card(
        color: context.colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Floating(
                    child: Text('📦', style: TextStyle(fontSize: 34)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Your shop is empty'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          context.tr(
                            'Add {count} sample products (food, drinks, snacks, stationery...) to try the app.',
                            {'count': vm.sampleProductCount},
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GradientButton(
                label: context.tr('Load sample products'),
                icon: Icons.inventory_2_outlined,
                busy: vm.busy,
                onPressed: () => _load(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the four actions in the Quick actions card: a tinted round icon
/// with the label under it. All four share the row equally.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = context.isDark
        ? Color.lerp(color, Colors.white, 0.35)!
        : color;
    return Expanded(
      child: Pressable(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: tint, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

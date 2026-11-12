import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/product_widgets.dart';

/// My Orders: Pending / Ready / Collected / Cancelled.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late final Stream<List<Order>> _orders = context
      .read<OrderService>()
      .watchMyOrders(context.read<AuthProvider>().user!.uid);

  static const _tabs = [
    (OrderStatus.pending, 'Pending'),
    (OrderStatus.ready, 'Ready'),
    (OrderStatus.collected, 'Collected'),
    (OrderStatus.cancelled, 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('My orders')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [for (final t in _tabs) Tab(text: context.tr(t.$2))],
          ),
        ),
        body: StreamBuilder<List<Order>>(
          stream: _orders,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!);
            if (!snap.hasData) return const LoadingView();
            return TabBarView(
              children: [
                for (final t in _tabs)
                  _OrderList(
                    orders: snap.data!.where((o) => o.status == t.$1).toList(),
                    emptyText: context.tr('No {status} orders', {
                      'status': context.tr(t.$1),
                    }),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.emptyText});
  final List<Order> orders;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(icon: Icons.receipt_long_outlined, title: emptyText);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => FadeSlideIn(
        delay: stagger(i),
        child: OrderCard(
          order: orders[i],
          onTap: () => context.push('/order/${orders[i].id}'),
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap});
  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${context.tr(order.isPreorder ? 'Pre-order' : 'Counter sale')} · ${receiptNo(order.id)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatRM(order.totalSen),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${context.tr('{count} item(s)', {'count': order.itemCount})} · '
                '${formatDateTime(order.sortTime)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OrderStatusPill(order: order),
                  if (order.pointsEarned > 0 && order.isCollected)
                    Pill(
                      label: context.tr('+{points} pts', {
                        'points': order.pointsEarned,
                      }),
                      color: context.eco,
                      icon: Icons.eco,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

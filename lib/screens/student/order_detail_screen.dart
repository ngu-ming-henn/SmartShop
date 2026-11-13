import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/order.dart';
import '../../viewmodels/common/order_view_model.dart';
import '../../widgets/common.dart';
import '../../widgets/product_widgets.dart';
import '../../widgets/receipt_view.dart';

/// Pickup QR while the order is pending / ready; digital receipt once
/// collected ([OrderViewModel]).
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  Future<void> _cancel(BuildContext context, Order order) async {
    final ok = await confirm(
      context,
      title: context.tr('Cancel order?'),
      message: context.tr('Order {no} will be cancelled.', {
        'no': receiptNo(order.id),
      }),
      confirmLabel: context.tr('Cancel order'),
      cancelLabel: context.tr('Keep'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<OrderViewModel>().cancel();
      if (context.mounted) showSnack(context, context.tr('Order cancelled.'));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderViewModel>();
    final order = vm.order;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          order == null
              ? context.tr('Order')
              : order.isCollected
              ? context.tr('Digital receipt')
              : context.tr('Order {no}', {'no': receiptNo(order.id)}),
        ),
      ),
      body: vm.error != null
          ? ErrorView(error: vm.error!)
          : vm.loading
          ? const LoadingView()
          : order == null
          ? EmptyState(
              icon: Icons.search_off,
              title: context.tr('Order not found'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: order.isCollected
                  ? [ReceiptView(order: order)]
                  : _activeOrder(context, order),
            ),
    );
  }

  List<Widget> _activeOrder(BuildContext context, Order order) {
    final theme = Theme.of(context);
    return [
      if (order.isCancelled)
        Card(
          color: context.colors.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.cancel, color: AppColors.error),
            title: Text(
              context.tr(
                order.wasNotCollected
                    ? 'Cancelled: not collected'
                    : 'This order was cancelled',
              ),
            ),
            subtitle: order.wasNotCollected
                ? Text(
                    context.tr(
                      'It was not collected before the koperasi closed, so the '
                      'items went back on the shelf.',
                    ),
                  )
                : null,
          ),
        )
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _StatusSteps(order: order),
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    order.isReady
                        ? 'Ready! Show this QR at the koperasi counter.'
                        : 'Waiting for staff to pack your order.\nYou can show this QR when it is ready.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                if (order.pickupCode != null) ...[
                  QrImageView(
                    data: order.pickupCode!,
                    size: 220,
                    backgroundColor: Colors.white,
                    semanticsLabel: context.tr('Pickup QR code'),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    order.pickupCode!,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    context.tr('Pickup code'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.push('/shop'),
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(context.tr('Where to collect')),
                  ),
                ],
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Items'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OrderStatusPill(order: order),
                ],
              ),
              const SizedBox(height: 8),
              OrderItemsList(order: order),
              const SizedBox(height: 8),
              Text(
                context.tr('Pay at counter.') +
                    (order.noPlasticBag
                        ? ' 🌱 ${context.tr('No plastic bag.')}'
                        : '') +
                    (order.pointsEarned > 0
                        ? ' ${context.tr('+{points} green points when collected.', {'points': order.pointsEarned})}'
                        : ''),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      if (order.isPending) ...[
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: context.watch<OrderViewModel>().busy
              ? null
              : () => _cancel(context, order),
          icon: const Icon(Icons.close),
          label: Text(context.tr('Cancel order')),
        ),
      ],
    ];
  }
}

/// Pending → Ready → Collected.
class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final step = order.isPending
        ? 0
        : order.isReady
        ? 1
        : 2;
    const labels = ['Pending', 'Ready', 'Collected'];
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: i <= step
                    ? context.brand
                    : context.colors.outlineVariant,
                child: Icon(
                  i < step ? Icons.check : Icons.circle,
                  size: i < step ? 16 : 8,
                  color: context.colors.onPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(labels[i]),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == step ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
          if (i < 2)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < step ? context.brand : context.colors.outlineVariant,
              ),
            ),
        ],
      ],
    );
  }
}

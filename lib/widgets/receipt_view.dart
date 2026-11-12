import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils/format.dart';
import '../l10n/strings.dart';
import '../models/order.dart';
import 'brand.dart';
import 'common.dart';

/// Order items with prices and the total.
class OrderItemsList extends StatelessWidget {
  const OrderItemsList({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${item.qty}×',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: theme.textTheme.bodyMedium),
                      Text(
                        context.tr('{price} each', {
                              'price': formatRM(item.unitPriceSen),
                            }) +
                            (item.isSaveFood
                                ? '  ·  🍞 ${context.tr('Save Food')}'
                                : ''),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatRM(item.lineTotalSen),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('Total'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              formatRM(order.totalSen),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The digital receipt (M9) — replaces the paper receipt.
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = order.collectedAt ?? order.createdAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SmartShopLogo(size: 52, shadow: false)),
            const SizedBox(height: 8),
            Text(
              'UTS SmartShop',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              context.tr('Digital receipt'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _row(context, context.tr('Receipt no.'), receiptNo(order.id)),
            if (when != null)
              _row(context, context.tr('Date'), formatDateTime(when)),
            _row(
              context,
              context.tr('Type'),
              context.tr(
                order.isPreorder ? 'Pre-order pickup' : 'Counter sale',
              ),
            ),
            if (order.customerName != null)
              _row(context, context.tr('Customer'), order.customerName!),
            _row(context, context.tr('Payment'), context.tr('Paid at counter')),
            const Divider(height: 28),
            OrderItemsList(order: order),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                Pill(
                  label: context.tr('Paper receipt saved'),
                  color: context.eco,
                  icon: Icons.receipt_long,
                ),
                if (order.noPlasticBag)
                  Pill(
                    label: context.tr('No plastic bag'),
                    color: context.eco,
                    icon: Icons.shopping_bag_outlined,
                  ),
                if (order.pointsEarned > 0)
                  Pill(
                    label: context.tr('+{points} green points', {
                      'points': order.pointsEarned,
                    }),
                    color: AppColors.accent,
                    textColor: AppColors.textOnAccent,
                    icon: Icons.eco,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

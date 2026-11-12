import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/common.dart';
import '../../widgets/product_widgets.dart';

/// Cart & Checkout: items, total, "No plastic bag" toggle, Pay at counter.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _busy = false;

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    final user = context.read<AuthProvider>().user;
    if (user == null || cart.isEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await context.read<OrderService>().placePreorder(
        user: user,
        items: cart.toOrderItems(),
        noPlasticBag: cart.noPlasticBag,
      );
      cart.clear();
      if (!mounted) return;
      showSnack(
        context,
        context.tr(
          result.synced
              ? 'Order placed! We will tell you when it is ready.'
              : 'Saved offline. It will be sent when you are back online.',
        ),
      );
      context.pushReplacement('/order/${result.orderId}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Cart'))),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: context.tr('Your cart is empty'),
              message: context.tr('Scan or search for products to pre-order.'),
              action: FilledButton(
                onPressed: () => context.go('/home'),
                child: Text(context.tr('Browse products')),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final line in cart.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ProductImage(product: line.product, size: 48),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Text(
                                    context.tr('{price} each', {
                                          'price': formatRM(line.unitPriceSen),
                                        }) +
                                        (line.isSaveFood
                                            ? ' · 🍞 ${context.tr('Save Food')}'
                                            : ''),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 6),
                                  QtyStepper(
                                    value: line.qty,
                                    min: 0,
                                    max: line.product.stock,
                                    onChanged: (v) =>
                                        cart.setQty(line.product.barcode, v),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatRM(line.lineTotalSen),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  tooltip: context.tr('Remove'),
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      cart.remove(line.product.barcode),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    value: cart.noPlasticBag,
                    onChanged: cart.setNoPlasticBag,
                    secondary: Icon(Icons.eco, color: context.eco),
                    title: Text(context.tr('No plastic bag')),
                    subtitle: Text(
                      context.tr(
                        'Bring your own bag and earn +{points} green points',
                        {'points': AppRules.pointsNoPlasticBag},
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _summaryRow(context, 'Items', '${cart.itemCount}'),
                        if (cart.saveFoodSavingsSen > 0)
                          _summaryRow(
                            context,
                            '🍞 Save Food savings',
                            '-${formatRM(cart.saveFoodSavingsSen)}',
                          ),
                        _summaryRow(
                          context,
                          '🌱 Green points to earn',
                          '+${cart.pointsPreview}',
                        ),
                        const Divider(height: 24),
                        _summaryRow(
                          context,
                          'Total',
                          formatRM(cart.totalSen),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(
                          'Pay at counter when you collect. Staff confirm the final total.',
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _placeOrder,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.check),
                  label: Text(context.tr('Place order')),
                ),
              ],
            ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
  }) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(context.tr(label), style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

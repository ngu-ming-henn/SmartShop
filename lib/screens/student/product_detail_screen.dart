import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../services/product_service.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/product_widgets.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.code});
  final String code;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final Stream<Product?> _product = context
      .read<ProductService>()
      .watchProduct(widget.code);
  int _qty = 1;

  void _addToCart(Product product) {
    final cart = context.read<CartProvider>();
    if (cart.add(product, qty: _qty)) {
      showSnack(
        context,
        context.tr('Added {qty} × {name} to cart', {
          'qty': _qty,
          'name': product.name,
        }),
        action: SnackBarAction(
          label: context.tr('View cart'),
          onPressed: () => context.push('/cart'),
        ),
      );
      setState(() => _qty = 1);
    } else {
      showSnack(
        context,
        context.tr('You already have all {count} in your cart.', {
          'count': product.stock,
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Product?>(
      stream: _product,
      builder: (context, snap) {
        final product = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(product?.name ?? context.tr('Product')),
            actions: const [CartButton()],
          ),
          body: switch (snap) {
            AsyncSnapshot(hasError: true) => ErrorView(error: snap.error!),
            AsyncSnapshot(connectionState: ConnectionState.waiting) =>
              const LoadingView(),
            _ when product == null || !product.isActive => EmptyState(
              icon: Icons.search_off,
              title: context.tr('Product not found — ask staff'),
              message: context.tr('Code: {code}', {'code': widget.code}),
              action: OutlinedButton(
                onPressed: () => context.pop(),
                child: Text(context.tr('Scan again')),
              ),
            ),
            _ => _details(context, product),
          },
        );
      },
    );
  }

  Widget _details(BuildContext context, Product product) {
    final theme = Theme.of(context);
    final inCart = context.select<CartProvider, int>(
      (c) => c.qtyOf(product.barcode),
    );
    final canAdd = product.stock - inCart;
    final qty = _qty.clamp(1, canAdd < 1 ? 1 : canAdd);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Product360(
                product: product,
                size: 180,
                radius: 24,
                interactive: true,
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Pill(
                  label: '360°',
                  color: context.brand,
                  icon: Icons.threesixty,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('Drag to turn'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Text(
          product.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          context.tr(product.category),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        PriceText(product: product, large: true),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: StockBadge(product: product),
        ),
        if (product.isOnSaveFood) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.accent),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🍞 ${context.tr('SAVE FOOD')}: ${formatRM(product.saveFoodPriceSen!)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (product.expiryDate != null)
                  Text(
                    context.tr('Expires: {date} ({label})', {
                      'date': formatDate(product.expiryDate!),
                      'label': expiryLabel(product.expiryDate!).toLowerCase(),
                    }),
                  ),
                Text(
                  context.tr(
                    'You save {saving} and earn +{points} green points each. '
                    'Thanks for helping reduce food waste!',
                    {
                      'saving': formatRM(product.saveFoodSavingSen),
                      'points': AppRules.pointsPerSaveFoodItem,
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (inCart > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.tr('In your cart: {count}', {'count': inCart}),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Row(
          children: [
            QtyStepper(
              value: qty,
              max: canAdd < 1 ? 1 : canAdd,
              onChanged: canAdd < 1 ? (_) {} : (v) => setState(() => _qty = v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: canAdd < 1 ? null : () => _addToCart(product),
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  context.tr(
                    product.isOutOfStock
                        ? 'Out of stock'
                        : canAdd < 1
                        ? 'All in cart'
                        : 'Add to cart',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('Pre-order now and pay at the counter when you collect.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

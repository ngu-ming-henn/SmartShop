import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../viewmodels/cart_view_model.dart';
import '../../viewmodels/student/product_detail_view_model.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/product_widgets.dart';

/// One product with its 3D picture, price, stock and Add to cart
/// ([ProductDetailViewModel]).
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key});

  void _addToCart(BuildContext context, Product product) {
    final added = context.read<ProductDetailViewModel>().addToCart();
    if (added > 0) {
      showSnack(
        context,
        context.tr('Added {qty} × {name} to cart', {
          'qty': added,
          'name': product.name,
        }),
        action: SnackBarAction(
          label: context.tr('View cart'),
          onPressed: () => context.push('/cart'),
        ),
      );
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
    final vm = context.watch<ProductDetailViewModel>();
    final product = vm.product;
    return Scaffold(
      appBar: AppBar(
        title: Text(product?.name ?? context.tr('Product')),
        actions: const [CartButton()],
      ),
      body: vm.error != null
          ? ErrorView(error: vm.error!)
          : vm.loading
          ? const LoadingView()
          : product == null
          ? EmptyState(
              icon: Icons.search_off,
              title: context.tr('Product not found — ask staff'),
              message: context.tr('Code: {code}', {'code': vm.code}),
              action: OutlinedButton(
                onPressed: () => context.pop(),
                child: Text(context.tr('Scan again')),
              ),
            )
          : _details(context, vm, product),
    );
  }

  Widget _details(
    BuildContext context,
    ProductDetailViewModel vm,
    Product product,
  ) {
    final theme = Theme.of(context);
    final inCart = context.select<CartViewModel, int>(
      (c) => c.qtyOf(product.barcode),
    );
    final canAdd = product.stock - inCart;
    final qty = vm.qty.clamp(1, canAdd < 1 ? 1 : canAdd);

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
        if (product.description != null) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: context.brand),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('About this product'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // Sample descriptions have a Malay entry; text typed
                    // by staff has none and is shown as written.
                    context.tr(product.description!),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ],
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
              onChanged: canAdd < 1 ? (_) {} : vm.setQty,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: canAdd < 1
                    ? null
                    : () => _addToCart(context, product),
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

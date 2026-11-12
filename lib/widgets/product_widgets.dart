import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils/format.dart';
import '../l10n/strings.dart';
import '../models/order.dart';
import '../models/product.dart';
import 'common.dart';
import 'motion.dart';

IconData categoryIcon(String category) => switch (category) {
  'Food' => Icons.rice_bowl,
  'Drinks' => Icons.local_drink,
  'Snacks' => Icons.cookie,
  'Stationery' => Icons.edit_note,
  _ => Icons.shopping_basket,
};

String categoryEmoji(String category) => switch (category) {
  'Food' => '🍱',
  'Drinks' => '🥤',
  'Snacks' => '🍿',
  'Stationery' => '✏️',
  _ => '🛍️',
};

/// Soft background colour for each category's picture.
Color categoryColor(String category) => switch (category) {
  'Food' => const Color(0xFFFFE0B2),
  'Drinks' => const Color(0xFFB3E5FC),
  'Snacks' => const Color(0xFFFFCDD2),
  'Stationery' => const Color(0xFFD1C4E9),
  _ => const Color(0xFFC8E6C9),
};

/// Products have no photos yet, so each one gets an emoji that matches its
/// name (first match wins), or its category.
const _emojiByKeyword = <String, String>{
  'candle': '🕯️',
  'bread': '🍞',
  'roti': '🍞',
  'bun': '🥯',
  'muffin': '🧁',
  'puff': '🥟',
  'sandwich': '🥪',
  'nasi': '🍛',
  'noodle': '🍜',
  'maggi': '🍜',
  'mee': '🍜',
  'indomie': '🍜',
  'kuih': '🍡',
  'yogurt': '🥣',
  'milk': '🥛',
  'water': '💧',
  'coffee': '☕',
  'nescaf': '☕',
  'teh': '🧋',
  'tea': '🧋',
  'milo': '🥤',
  'cola': '🥤',
  '100plus': '🥤',
  'juice': '🧃',
  'chocolate': '🍫',
  'chips': '🍟',
  'twisties': '🍟',
  'cracker': '🍘',
  'biscuit': '🍪',
  'oreo': '🍪',
  'pen': '🖊️',
  'pencil': '✏️',
  'highlighter': '🖍️',
  'notebook': '📒',
  'pad': '📝',
  'paper': '📄',
  'sticky': '🗒️',
  'calculator': '🧮',
  'tape': '📏',
  'tissue': '🧻',
  'sanitizer': '🧴',
  'mask': '😷',
  'umbrella': '☂️',
  'batter': '🔋',
  'toothpaste': '🪥',
  'shampoo': '🧴',
};

String productEmoji(Product product) {
  final name = product.name.toLowerCase();
  for (final e in _emojiByKeyword.entries) {
    if (name.contains(e.key)) return e.value;
  }
  return switch (product.category) {
    'Food' => '🍱',
    'Drinks' => '🥤',
    'Snacks' => '🍿',
    'Stationery' => '✏️',
    _ => '🛍️',
  };
}

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    this.size = 56,
    this.radius = 12,
  });

  final Product product;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tint = categoryColor(product.category);
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDark
              ? [tint.withValues(alpha: 0.30), tint.withValues(alpha: 0.12)]
              : [tint, tint.withValues(alpha: 0.45)],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        productEmoji(product),
        style: TextStyle(fontSize: size * 0.5, height: 1.1),
      ),
    );
    if (product.imageUrl == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: product.imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

/// "Live 360°" product picture: turns slowly like on a turntable, with a
/// floor shadow that narrows as it turns. With [interactive], drag sideways
/// to turn it yourself (it starts turning again after a moment).
class Product360 extends StatefulWidget {
  const Product360({
    super.key,
    required this.product,
    this.size = 72,
    this.radius = 12,
    this.interactive = false,
    this.secondsPerTurn = 8,
  });

  final Product product;
  final double size;
  final double radius;
  final bool interactive;
  final int secondsPerTurn;

  @override
  State<Product360> createState() => _Product360State();
}

class _Product360State extends State<Product360>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.secondsPerTurn),
    // Each product starts at a different angle, so a row of them is not
    // all turning in step.
    value: (widget.product.barcode.hashCode % 1000).abs() / 1000,
  )..repeat();
  double _drag = 0; // extra turns from the student's finger
  Timer? _resume;

  @override
  void dispose() {
    _resume?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = AnimatedBuilder(
      animation: _spin,
      builder: (context, child) {
        final angle = 2 * math.pi * (_spin.value + _drag);
        final facing = math.cos(angle);
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(angle);
        // Show the front on both sides instead of a mirrored back.
        if (facing < 0) transform.multiply(Matrix4.diagonal3Values(-1, 1, 1));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: transform,
              child: child,
            ),
            SizedBox(height: widget.size * 0.07),
            Container(
              width: widget.size * 0.7 * (0.3 + 0.7 * facing.abs()),
              height: widget.size * 0.07,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.size),
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.45 : 0.14,
                ),
              ),
            ),
          ],
        );
      },
      child: ProductImage(
        product: widget.product,
        size: widget.size,
        radius: widget.radius,
      ),
    );
    if (!widget.interactive) return picture;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _resume?.cancel();
        _spin.stop();
      },
      onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta.dx / 320),
      onHorizontalDragEnd: (_) => _resume = Timer(
        const Duration(seconds: 2),
        () => mounted ? _spin.repeat() : null,
      ),
      child: picture,
    );
  }
}

/// In stock / Low / Out of stock (design principle: clear stock status).
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.product, this.showCount = true});

  final Product product;
  final bool showCount;

  @override
  Widget build(BuildContext context) => switch (product.stockStatus) {
    StockStatus.out => Pill(
      label: context.tr('Out of stock'),
      color: AppColors.error,
      icon: Icons.cancel,
    ),
    StockStatus.low => Pill(
      label: showCount
          ? context.tr('Low stock ({count})', {'count': product.stock})
          : context.tr('Low stock'),
      color: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    ),
    StockStatus.inStock => Pill(
      label: showCount
          ? context.tr('In stock ({count})', {'count': product.stock})
          : context.tr('In stock'),
      color: context.brand,
      icon: Icons.check_circle,
    ),
  };
}

class SaveFoodBadge extends StatelessWidget {
  const SaveFoodBadge({super.key});

  @override
  Widget build(BuildContext context) => Pill(
    label: context.tr('SAVE FOOD'),
    color: AppColors.accent,
    textColor: AppColors.textOnAccent,
    icon: Icons.eco,
  );
}

/// Effective price, with the normal price struck through on Save Food.
class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.product, this.large = false});

  final Product product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (large ? theme.textTheme.headlineMedium : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w700);
    if (!product.isOnSaveFood) {
      return Text(formatRM(product.priceSen), style: style);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      children: [
        Text(
          formatRM(product.saveFoodPriceSen!),
          style: style?.copyWith(color: const Color(0xFFB26A00)),
        ),
        Text(
          formatRM(product.priceSen),
          style: theme.textTheme.bodySmall?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    this.onTap,
    this.trailing,
    this.showStockCount = true,
  });

  final Product product;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showStockCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Pressable(
      scale: 0.98,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: product.isActive ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ProductImage(product: product),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        PriceText(product: product),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            StockBadge(
                              product: product,
                              showCount: showStockCount,
                            ),
                            if (product.isOnSaveFood) const SaveFoodBadge(),
                            if (!product.isActive)
                              Pill(
                                label: context.tr('Disabled'),
                                color: Colors.grey,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small card for the "Popular now" and Save Food carousels on the student
/// home screen. Save Food deals get an amber border and their expiry.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
      child: Pressable(
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: product.isOnSaveFood
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.accent, width: 1.5),
                )
              : null,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Product360(product: product, size: 64)),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  PriceText(product: product),
                  if (product.isOnSaveFood && product.expiryDate != null)
                    Text(
                      expiryLabel(product.expiryDate!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.tr('Less'),
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: context.tr('More'),
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) => switch (order.status) {
    'pending' => Pill(
      label: context.tr('Pending'),
      color: Color(0xFF1565C0),
      icon: Icons.schedule,
    ),
    'ready' => Pill(
      label: context.tr('Ready for pickup'),
      color: AppColors.accent,
      textColor: AppColors.textOnAccent,
      icon: Icons.shopping_bag,
    ),
    'collected' => Pill(
      label: context.tr('Collected'),
      color: context.brand,
      icon: Icons.check_circle,
    ),
    _ => Pill(
      label: context.tr(
        order.wasNotCollected ? 'Cancelled: not collected' : 'Cancelled',
      ),
      color: AppColors.error,
      icon: Icons.cancel,
    ),
  };
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../core/utils/format.dart';
import '../l10n/strings.dart';
import '../models/product.dart';
import 'motion.dart';
import 'product_widgets.dart';

/// Three category boxes (tap "More" for the rest) and, beside them, an
/// animated "Hot deal" advert that cycles through real products.
class CategoriesAndDeal extends StatefulWidget {
  const CategoriesAndDeal({super.key, required this.featured});
  final List<Product> featured;

  @override
  State<CategoriesAndDeal> createState() => _CategoriesAndDealState();
}

class _CategoriesAndDealState extends State<CategoriesAndDeal> {
  static const _shown = 3;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final extra = productCategories.length - _shown;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 132,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (var i = 0; i < productCategories.length; i++)
                      if (_open || i < _shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FadeSlideIn(
                            delay: stagger(i, stepMs: 50),
                            offset: 10,
                            child: _CategoryPill(
                              category: productCategories[i],
                            ),
                          ),
                        ),
                    SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => setState(() => _open = !_open),
                        icon: AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(Icons.expand_more, size: 18),
                        ),
                        label: Text(
                          _open
                              ? context.tr('Less')
                              : context.tr('+{count} more', {'count': extra}),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _HotDealCard(products: widget.featured)),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final tint = categoryColor(category);
    return Pressable(
      child: Material(
        color: context.isDark
            ? tint.withValues(alpha: 0.18)
            : tint.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(
            '/products?category=${Uri.encodeQueryComponent(category)}',
          ),
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Text(
                  categoryEmoji(category),
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr(category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "HOT DEAL" advert: slides to the next real product every few seconds;
/// the product floats and the badge pulses. Tap to open the product.
class _HotDealCard extends StatefulWidget {
  const _HotDealCard({required this.products});
  final List<Product> products;

  @override
  State<_HotDealCard> createState() => _HotDealCardState();
}

class _HotDealCardState extends State<_HotDealCard>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Timer? _timer;
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (mounted && widget.products.length > 1) {
        setState(() => _index = (_index + 1) % widget.products.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    final product = products.isEmpty
        ? null
        : products[_index % products.length];
    final onDeal = product?.isOnSaveFood ?? false;

    return Pressable(
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: onDeal
                  ? const [Color(0xFFFF7A45), Color(0xFFE53935)]
                  : const [AppColors.primary, AppColors.primaryBright],
            ),
          ),
          child: InkWell(
            onTap: product == null
                ? () => context.push('/products')
                : () => context.push(productPath(product.barcode)),
            child: Stack(
              children: [
                // Soft circles for depth
                Positioned(
                  right: -30,
                  top: -30,
                  child: _Circle(size: 110, opacity: 0.12),
                ),
                Positioned(
                  left: -20,
                  bottom: -40,
                  child: _Circle(size: 90, opacity: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ScaleTransition(
                            scale: Tween(begin: 0.94, end: 1.06).animate(
                              CurvedAnimation(
                                parent: _glow,
                                curve: Curves.easeInOut,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                onDeal
                                    ? '🔥 ${context.tr('HOT DEAL')}'
                                    : '⭐ ${context.tr('TOP PICK')}',
                                style: const TextStyle(
                                  color: AppColors.textOnAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (products.length > 1)
                            Row(
                              children: [
                                for (var i = 0; i < products.length; i++)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.only(left: 3),
                                    width: i == _index % products.length
                                        ? 12
                                        : 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: i == _index % products.length
                                            ? 1
                                            : 0.45,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0.3, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: product == null
                              ? _DealPlaceholder(key: const ValueKey('none'))
                              : _DealContent(
                                  key: ValueKey(product.barcode),
                                  product: product,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DealContent extends StatelessWidget {
  const _DealContent({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatRM(product.effectivePriceSen),
                style: const TextStyle(
                  color: white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (product.isOnSaveFood)
                Text(
                  formatRM(product.priceSen),
                  style: TextStyle(
                    color: white.withValues(alpha: 0.75),
                    decoration: TextDecoration.lineThrough,
                    decorationColor: white,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        Floating(
          distance: 8,
          child: Text(
            productEmoji(product),
            style: const TextStyle(fontSize: 46),
          ),
        ),
      ],
    );
  }
}

class _DealPlaceholder extends StatelessWidget {
  const _DealPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr('Pre-order now, skip the queue!'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        const Floating(
          distance: 8,
          child: Text('🛍️', style: TextStyle(fontSize: 44)),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

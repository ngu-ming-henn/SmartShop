import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../providers/cart_provider.dart';
import 'motion.dart';

/// Cart icon with the number of items, for app bars.
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartProvider, int>((c) => c.itemCount);
    return IconButton(
      tooltip: context.tr('Cart'),
      onPressed: () => context.push('/cart'),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.accent,
        textColor: AppColors.textOnAccent,
        // Bounces whenever the number changes.
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
            child: child,
          ),
          child: Text('$count', key: ValueKey(count)),
        ),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

/// "🌱 120" chip in the student app bar.
class GreenPointsChip extends StatelessWidget {
  const GreenPointsChip({super.key, required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/points'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco, size: 18, color: Colors.white),
                const SizedBox(width: 4),
                Semantics(
                  label: context.tr('{points} green points', {
                    'points': points,
                  }),
                  excludeSemantics: true,
                  child: CountUp(
                    value: points,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/budget_plan.dart';
import '../../viewmodels/student/budget_planner_view_model.dart';
import '../../widgets/brand.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/product_widgets.dart';

/// ✨ AI Budget Planner: budget + the categories the student needs + what
/// they feel like ("chocolate, no spicy") -> 3 suggested combos of in-stock
/// items -> "Pre-order this combo" (design doc 8.1, flow 9.6).
/// Data and actions: [BudgetPlannerViewModel].
class BudgetPlannerScreen extends StatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  final _budget = TextEditingController(text: '10.00');
  final _wishes = TextEditingController();

  @override
  void dispose() {
    _budget.dispose();
    _wishes.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    final budgetSen = parseRMToSen(_budget.text);
    if (budgetSen == null || budgetSen <= 0) {
      showSnack(context, context.tr('Enter a budget, e.g. 10.00'));
      return;
    }
    final vm = context.read<BudgetPlannerViewModel>();
    if (!vm.hasCategories) {
      showSnack(context, context.tr('Pick at least one category.'));
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      await vm.suggest(budgetSen: budgetSen, wishes: _wishes.text);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Items go to the cart, then the normal pre-order flow (9.2).
  Future<void> _preorder(Combo combo) async {
    final vm = context.read<BudgetPlannerViewModel>();
    var replace = false;
    if (vm.cartHasItems) {
      replace = await confirm(
        context,
        title: context.tr('Replace your cart?'),
        message: context.tr(
          'Your cart already has items. Replace them with this combo?',
        ),
        confirmLabel: context.tr('Replace'),
        cancelLabel: context.tr('Keep both'),
      );
      if (!mounted) return;
    }
    vm.addToCart(combo, replaceCart: replace);
    await context.push('/cart');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<BudgetPlannerViewModel>();
    final combos = vm.combos;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('✨ AI Budget Planner')),
        actions: const [CartButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _suggest(),
            decoration: InputDecoration(
              labelText: context.tr('My budget'),
              prefixText: 'RM ',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final rm in const [5, 10, 15, 20])
                ActionChip(
                  label: Text('RM$rm'),
                  onPressed: () => setState(() => _budget.text = '$rm.00'),
                ),
            ],
          ),
          label(context.tr('What do you need?')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in productCategories)
                FilterChip(
                  avatar: Text(categoryEmoji(c)),
                  label: Text(context.tr(c)),
                  selected: vm.isPicked(c),
                  onSelected: (on) => vm.pick(c, on),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(context.tr('Quick pick:'), style: theme.textTheme.bodySmall),
              const SizedBox(width: 4),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  children: [
                    for (final m in MealType.values)
                      TextButton(
                        onPressed: () => vm.pickMeal(m),
                        child: Text(context.tr(m.label)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          label(context.tr('Personalise (optional)')),
          TextField(
            controller: _wishes,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _suggest(),
            decoration: InputDecoration(
              hintText: context.tr('e.g. chocolate, milo, no spicy'),
              prefixIcon: const Icon(Icons.favorite_border),
              helperText: context.tr(
                'Things you like go first. Write "no ..." to leave things out.',
              ),
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: context.tr('Suggest for me'),
            icon: Icons.auto_awesome,
            busy: vm.busy,
            onPressed: _suggest,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Picks in-stock items you have bought before, popular items and '
              'Save Food deals. Pay at the counter when you collect.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (combos != null && combos.isEmpty)
            EmptyState(
              icon: Icons.savings_outlined,
              title: context.tr(
                'No combo fits this budget. Try a higher amount.',
              ),
            ),
          if (combos != null)
            for (var i = 0; i < combos.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FadeSlideIn(
                  key: ObjectKey(combos[i]),
                  delay: stagger(i, stepMs: 120),
                  child: _ComboCard(
                    combo: combos[i],
                    rank: i + 1,
                    wishes: vm.usedWishes,
                    onPreorder: () => _preorder(combos[i]),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  const _ComboCard({
    required this.combo,
    required this.rank,
    required this.wishes,
    required this.onPreorder,
  });

  final Combo combo;
  final int rank;
  final Wishes wishes;
  final VoidCallback onPreorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = rank == 1;
    return Card(
      shape: best
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.brand, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              (best ? '⭐ ' : '') +
                  context.tr('Combo {rank} — {total}', {
                    'rank': rank,
                    'total': formatRM(combo.totalSen),
                  }) +
                  (best ? ' (${context.tr('Best for you')})' : ''),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final p in combo.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ProductImage(product: p, size: 36, radius: 10),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.name +
                            (p.isOnSaveFood
                                ? '  🍞 ${context.tr('Save Food')}'
                                : ''),
                      ),
                    ),
                    if (wishes.likes(p))
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Text('❤️'),
                      ),
                    Text(formatRM(p.effectivePriceSen)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            best
                ? FilledButton.icon(
                    onPressed: onPreorder,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(context.tr('Pre-order this combo')),
                  )
                : OutlinedButton.icon(
                    onPressed: onPreorder,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(context.tr('Pre-order this combo')),
                  ),
          ],
        ),
      ),
    );
  }
}

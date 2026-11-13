import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/router.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/student/product_list_view_model.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/product_widgets.dart';

/// Search / Category: product list with filters ([ProductListViewModel]).
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final _search = TextEditingController(
    text: context.read<ProductListViewModel>().query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProductListViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          vm.saveFoodOnly
              ? context.tr('Save Food deals')
              : context.tr(vm.category ?? 'Products'),
        ),
        actions: const [CartButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: vm.search,
              decoration: InputDecoration(
                hintText: context.tr('Search products'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: vm.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('Clear'),
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          vm.search('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  label: Text(context.tr('🍞 Save Food')),
                  selected: vm.saveFoodOnly,
                  onSelected: vm.showSaveFoodOnly,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.tr('In stock')),
                  selected: vm.inStockOnly,
                  onSelected: vm.showInStockOnly,
                ),
                for (final c in productCategories) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(context.tr(c)),
                    selected: vm.category == c,
                    onSelected: (v) => vm.showCategory(v ? c : null),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (vm.error != null) return ErrorView(error: vm.error!);
                final items = vm.items;
                if (items == null) return const LoadingView();
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: context.tr('No products found'),
                    message: context.tr('Try another search or category.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => FadeSlideIn(
                    delay: stagger(i, stepMs: 40),
                    child: ProductTile(
                      product: items[i],
                      showStockCount: false,
                      onTap: () => context.push(productPath(items[i].barcode)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

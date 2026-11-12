import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/router.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/product_widgets.dart';

/// Search / Category: product list with filters.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({
    super.key,
    this.initialCategory,
    this.initialQuery,
    this.saveFoodOnly = false,
  });

  final String? initialCategory;
  final String? initialQuery;
  final bool saveFoodOnly;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final Stream<List<Product>> _products = context
      .read<ProductService>()
      .watchActiveProducts();
  late final _search = TextEditingController(text: widget.initialQuery ?? '');
  late String? _category = widget.initialCategory;
  late bool _saveFood = widget.saveFoodOnly;
  bool _inStockOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Product> _filter(List<Product> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((p) {
      if (_category != null && p.category != _category) return false;
      if (_saveFood && !p.isOnSaveFood) return false;
      if (_inStockOnly && p.isOutOfStock) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) || p.barcode.toLowerCase() == q;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _saveFood
              ? context.tr('Save Food deals')
              : context.tr(_category ?? 'Products'),
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
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.tr('Search products'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('Clear'),
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_search.clear),
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
                  selected: _saveFood,
                  onSelected: (v) => setState(() => _saveFood = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.tr('In stock')),
                  selected: _inStockOnly,
                  onSelected: (v) => setState(() => _inStockOnly = v),
                ),
                for (final c in productCategories) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(context.tr(c)),
                    selected: _category == c,
                    onSelected: (v) => setState(() => _category = v ? c : null),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _products,
              builder: (context, snap) {
                if (snap.hasError) return ErrorView(error: snap.error!);
                if (!snap.hasData) return const LoadingView();
                final items = _filter(snap.data!);
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

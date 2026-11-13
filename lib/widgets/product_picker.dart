import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/product.dart';
import 'common.dart';
import 'product_widgets.dart';

/// Bottom sheet to search and pick a product by name (when a barcode
/// cannot be scanned). [products] comes from the screen's ViewModel.
Future<Product?> showProductPicker(
  BuildContext context, {
  required Stream<List<Product>> products,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ProductPicker(products: products),
  );
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.products});
  final Stream<List<Product>> products;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.tr('Search by name or code'),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: widget.products,
              builder: (context, snap) {
                if (snap.hasError) return ErrorView(error: snap.error!);
                if (!snap.hasData) return const LoadingView();
                final items = snap.data!
                    .where(
                      (p) =>
                          _query.isEmpty ||
                          p.name.toLowerCase().contains(_query) ||
                          p.barcode.toLowerCase().contains(_query),
                    )
                    .toList();
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: context.tr('No products found'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => ProductTile(
                    product: items[i],
                    onTap: () => Navigator.pop(context, items[i]),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import 'common.dart';
import 'product_widgets.dart';

/// Bottom sheet to search and pick a product by name (when a barcode
/// cannot be scanned).
Future<Product?> showProductPicker(
  BuildContext context, {
  bool activeOnly = true,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ProductPicker(activeOnly: activeOnly),
  );
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.activeOnly});
  final bool activeOnly;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  late final Stream<List<Product>> _products = widget.activeOnly
      ? context.read<ProductService>().watchActiveProducts()
      : context.read<ProductService>().watchAllProducts();
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
              stream: _products,
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../widgets/common.dart';
import '../../widgets/product_widgets.dart';
import '../common/scanner_page.dart';

enum _Filter { all, lowStock, noBarcode, disabled }

/// Products: add / edit / disable; scan a barcode to fill in.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final Stream<List<Product>> _products = context
      .read<ProductService>()
      .watchAllProducts();
  String _query = '';
  _Filter _filter = _Filter.all;

  Future<void> _add() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(context.tr('Scan the barcode')),
              subtitle: Text(context.tr('Most packaged products')),
              onTap: () => Navigator.pop(ctx, 'scan'),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(context.tr('No barcode')),
              subtitle: Text(
                context.tr('Kuih, bread, loose stationery: we make a QR label'),
              ),
              onTap: () => Navigator.pop(ctx, 'none'),
            ),
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: Text(context.tr('Type the barcode')),
              onTap: () => Navigator.pop(ctx, 'type'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'scan':
        final code = await scanCode(
          context,
          title: context.tr('Scan new product'),
        );
        if (code != null && mounted) {
          await context.push(
            '/staff/product-new?barcode=${Uri.encodeQueryComponent(code)}',
          );
        }
      case 'none':
        await context.push('/staff/product-new?barcode=generate');
      default:
        await context.push('/staff/product-new');
    }
  }

  bool _matches(Product p) {
    if (_query.isNotEmpty &&
        !p.name.toLowerCase().contains(_query) &&
        !p.barcode.toLowerCase().contains(_query)) {
      return false;
    }
    return switch (_filter) {
      _Filter.all => true,
      _Filter.lowStock => p.needsRestock,
      _Filter.noBarcode => p.hasShortCode,
      _Filter.disabled => !p.isActive,
    };
  }

  Future<void> _toggleActive(Product p) async {
    try {
      await context.read<ProductService>().setActive(p.barcode, !p.isActive);
      if (mounted) {
        showSnack(
          context,
          context.tr(p.isActive ? '{name} disabled' : '{name} enabled', {
            'name': p.name,
          }),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Products'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(context.tr('Add product')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.tr('Search by name or code'),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final (f, label) in const [
                  (_Filter.all, 'All'),
                  (_Filter.lowStock, 'Low stock'),
                  (_Filter.noBarcode, 'No barcode (QR label)'),
                  (_Filter.disabled, 'Disabled'),
                ]) ...[
                  ChoiceChip(
                    label: Text(context.tr(label)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
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
                final items = snap.data!.where(_matches).toList();
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: context.tr(
                      snap.data!.isEmpty ? 'No products yet' : 'No matches',
                    ),
                    message: snap.data!.isEmpty
                        ? context.tr(
                            'Add products, or load the sample catalogue from More.',
                          )
                        : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return ProductTile(
                      product: p,
                      onTap: () => context.push(
                        '/staff/product/${Uri.encodeComponent(p.barcode)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: context.tr('More'),
                        onSelected: (v) {
                          if (v == 'label') {
                            context.push(
                              '/staff/label/${Uri.encodeComponent(p.barcode)}',
                            );
                          } else if (v == 'toggle') {
                            _toggleActive(p);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'label',
                            child: Text(context.tr('QR label')),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              context.tr(p.isActive ? 'Disable' : 'Enable'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

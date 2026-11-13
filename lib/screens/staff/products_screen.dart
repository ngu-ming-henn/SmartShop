import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../viewmodels/staff/products_view_model.dart';
import '../../widgets/common.dart';
import '../../widgets/product_widgets.dart';
import '../common/scanner_page.dart';

/// Products: add / edit / disable; scan a barcode to fill in
/// ([ProductsViewModel]).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
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

  Future<void> _toggleActive(Product p) async {
    try {
      await context.read<ProductsViewModel>().toggleActive(p);
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
    final vm = context.watch<ProductsViewModel>();
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
              onChanged: vm.search,
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final (f, label) in const [
                  (ProductFilter.all, 'All'),
                  (ProductFilter.lowStock, 'Low stock'),
                  (ProductFilter.noBarcode, 'No barcode (QR label)'),
                  (ProductFilter.disabled, 'Disabled'),
                ]) ...[
                  ChoiceChip(
                    label: Text(context.tr(label)),
                    selected: vm.filter == f,
                    onSelected: (_) => vm.show(f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (vm.error != null) return ErrorView(error: vm.error!);
                if (vm.loading) return const LoadingView();
                final items = vm.items;
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: context.tr(
                      vm.shopIsEmpty ? 'No products yet' : 'No matches',
                    ),
                    message: vm.shopIsEmpty
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

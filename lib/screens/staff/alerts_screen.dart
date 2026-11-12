import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/points.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../services/stock_service.dart';
import '../../widgets/common.dart';
import '../../widgets/product_widgets.dart';

/// Low stock and near expiry; set the Save Food price from here.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final Stream<List<Product>> _products = context
      .read<ProductService>()
      .watchAllProducts();

  Future<void> _setSaveFood(Product p) async {
    final controller = TextEditingController(
      text: senToInput(
        p.saveFoodPriceSen ?? suggestedSaveFoodPriceSen(p.priceSen),
      ),
    );
    final form = GlobalKey<FormState>();
    final price = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Save Food price')),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('{name}\nNormal price {price}', {
                  'name': p.name,
                  'price': formatRM(p.priceSen),
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: 'RM ',
                  labelText: context.tr('Deal price'),
                ),
                validator: (v) {
                  final sen = parseRMToSen(v ?? '');
                  if (sen == null || sen <= 0) {
                    return context.tr('Enter a price, e.g. 2.50');
                  }
                  if (sen >= p.priceSen) {
                    return context.tr('Must be lower than the normal price');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('Suggested: 30% off'),
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, parseRMToSen(controller.text));
              }
            },
            child: Text(context.tr('Start deal')),
          ),
        ],
      ),
    );
    if (price == null || !mounted) return;
    try {
      await context.read<ProductService>().setSaveFoodPrice(p.barcode, price);
      if (mounted) {
        showSnack(
          context,
          context.tr('{name} is now on Save Food: {price}', {
            'name': p.name,
            'price': formatRM(price),
          }),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _endDeal(Product p) async {
    try {
      await context.read<ProductService>().setSaveFoodPrice(p.barcode, null);
      if (mounted) {
        showSnack(
          context,
          context.tr('Save Food deal ended for {name}', {'name': p.name}),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _writeOff(Product p) async {
    final controller = TextEditingController(text: '${p.stock}');
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Write off expired stock')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: context.tr('Quantity thrown away'),
            helperText: context.tr('In stock: {count}', {'count': p.stock}),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: Text(context.tr('Write off')),
          ),
        ],
      ),
    );
    if (qty == null || qty <= 0 || !mounted) return;
    try {
      await context.read<StockService>().stockOut(
        productId: p.barcode,
        quantity: qty,
        staffId: context.read<AuthProvider>().user!.uid,
        type: MovementType.expired,
      );
      if (mounted) {
        showSnack(
          context,
          context.tr('{qty} × {name} written off as expired.', {
            'qty': qty,
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
    return StreamBuilder<List<Product>>(
      stream: _products,
      builder: (context, snap) {
        final active = (snap.data ?? const <Product>[]).where(
          (p) => p.isActive,
        );
        final low = active.where((p) => p.needsRestock).toList()
          ..sort((a, b) => a.stock.compareTo(b.stock));
        final expiry = active.where((p) => p.needsExpiryAction()).toList()
          ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

        return DefaultTabController(
          length: 2,
          initialIndex: widget.initialTab,
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.tr('Alerts')),
              bottom: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(
                    text: context.tr('Low stock ({count})', {
                      'count': low.length,
                    }),
                  ),
                  Tab(
                    text: context.tr('Near expiry ({count})', {
                      'count': expiry.length,
                    }),
                  ),
                ],
              ),
            ),
            body: snap.hasError
                ? ErrorView(error: snap.error!)
                : !snap.hasData
                ? const LoadingView()
                : TabBarView(children: [_lowStock(low), _nearExpiry(expiry)]),
          ),
        );
      },
    );
  }

  Widget _lowStock(List<Product> items) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: context.tr('All products are well stocked'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = items[i];
        return ProductTile(
          product: p,
          trailing: Column(
            children: [
              Text(
                context.tr('min {count}', {'count': p.lowStockThreshold}),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () => context.go(
                  '/staff/stock?code=${Uri.encodeQueryComponent(p.barcode)}',
                ),
                child: Text(context.tr('Stock in')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _nearExpiry(List<Product> items) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: context.tr('Nothing near expiry'),
        message: context.tr('Products expiring within {days} days show here.', {
          'days': AppRules.nearExpiryDays,
        }),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = items[i];
        final expired = p.isExpired();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ProductImage(product: p, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            context.tr('{count} in stock · {date}', {
                              'count': p.stock,
                              'date': formatDate(p.expiryDate!),
                            }),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Pill(
                                label: expiryLabel(p.expiryDate!),
                                color: expired
                                    ? AppColors.error
                                    : AppColors.warning,
                                icon: Icons.timer_outlined,
                              ),
                              if (p.isOnSaveFood)
                                Pill(
                                  label: context.tr('Deal {price}', {
                                    'price': formatRM(p.saveFoodPriceSen!),
                                  }),
                                  color: AppColors.accent,
                                  textColor: AppColors.textOnAccent,
                                  icon: Icons.eco,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    if (expired)
                      FilledButton.tonalIcon(
                        onPressed: () => _writeOff(p),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(context.tr('Write off')),
                      )
                    else ...[
                      if (p.isOnSaveFood)
                        TextButton(
                          onPressed: () => _endDeal(p),
                          child: Text(context.tr('End deal')),
                        ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.textOnAccent,
                          minimumSize: const Size(48, 44),
                        ),
                        onPressed: () => _setSaveFood(p),
                        icon: const Icon(Icons.eco),
                        label: Text(
                          context.tr(
                            p.isOnSaveFood
                                ? 'Change price'
                                : 'Set Save Food price',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/app_user.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../widgets/common.dart';
import '../../widgets/product_picker.dart';
import '../../widgets/product_widgets.dart';
import '../../widgets/scanner_view.dart';

/// Counter sale: scan items -> (optional) scan student member QR ->
/// checkout -> stock deducted -> digital receipt.
class CounterSaleScreen extends StatefulWidget {
  const CounterSaleScreen({super.key});

  @override
  State<CounterSaleScreen> createState() => _CounterSaleScreenState();
}

class _CounterSaleScreenState extends State<CounterSaleScreen> {
  final _cart = CartProvider(); // separate from the student cart
  AppUser? _member;
  bool _busy = false;

  @override
  void dispose() {
    _cart.dispose();
    super.dispose();
  }

  Future<void> _onCode(String code) async {
    try {
      if (code.startsWith(memberQrPrefix)) {
        final member = await context.read<AuthService>().getUser(
          code.substring(memberQrPrefix.length),
        );
        if (!mounted) return;
        if (member == null) {
          showSnack(context, context.tr('Member not found.'));
        } else {
          setState(() => _member = member);
          showSnack(
            context,
            context.tr('Member: {name}', {'name': member.name}),
          );
        }
        return;
      }
      final product = await context.read<ProductService>().findByBarcode(code);
      if (!mounted) return;
      _addProduct(product, code);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _addProduct(Product? product, String code) {
    if (product == null || !product.isActive) {
      showSnack(context, context.tr('Unknown code {code}', {'code': code}));
    } else if (product.isOutOfStock) {
      showSnack(
        context,
        context.tr('{name} is out of stock.', {'name': product.name}),
      );
    } else if (!_cart.add(product)) {
      showSnack(
        context,
        context.tr('Only {count} {name} in stock.', {
          'count': product.stock,
          'name': product.name,
        }),
      );
    }
  }

  Future<void> _search() async {
    final p = await showProductPicker(context);
    if (p != null && mounted) _addProduct(p, p.barcode);
  }

  Future<void> _checkout() async {
    final ok = await confirm(
      context,
      title: context.tr('Collect {total}', {'total': formatRM(_cart.totalSen)}),
      message: [
        context.tr('{count} item(s)', {'count': _cart.itemCount}),
        if (_member != null)
          context.tr(' · {name} earns +{points} points', {
            'name': _member!.name,
            'points': _cart.pointsPreview,
          }),
        '\n\n',
        context.tr('Take payment, then confirm.'),
      ].join(),
      confirmLabel: context.tr('Paid'),
      cancelLabel: context.tr('Back'),
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final orderId = await context.read<OrderService>().counterSale(
        requested: _cart.toOrderItems(),
        staffId: context.read<AuthProvider>().user!.uid,
        noPlasticBag: _cart.noPlasticBag,
        member: _member,
      );
      _cart.clear();
      setState(() => _member = null);
      if (mounted) await context.push('/receipt/$orderId');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Counter sale')),
        actions: [
          IconButton(
            tooltip: context.tr('Search product'),
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _cart,
        builder: (context, _) => Column(
          children: [
            SizedBox(
              height: 220,
              child: ScannerView(
                continuous: true,
                hint: context.tr('Scan items or the student member QR'),
                onCode: _onCode,
              ),
            ),
            Material(
              color: _member == null
                  ? context.colors.surface
                  : context.colors.secondaryContainer,
              child: ListTile(
                leading: Icon(
                  _member == null ? Icons.person_outline : Icons.verified_user,
                  color: context.brand,
                ),
                title: Text(
                  _member == null
                      ? context.tr('Walk-in customer')
                      : '${_member!.name} (${_member!.studentId})',
                ),
                subtitle: Text(
                  _member == null
                      ? context.tr(
                          'Scan the member QR for a digital receipt and points',
                        )
                      : context.tr('{points} green points', {
                          'points': _member!.greenPoints,
                        }),
                ),
                trailing: _member == null
                    ? null
                    : IconButton(
                        tooltip: context.tr('Remove member'),
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _member = null),
                      ),
              ),
            ),
            Expanded(
              child: _cart.isEmpty
                  ? EmptyState(
                      icon: Icons.qr_code_scanner,
                      title: context.tr('Scan items to start'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _cart.lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final line = _cart.lines[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.product.name,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      Text(
                                        formatRM(line.unitPriceSen) +
                                            (line.isSaveFood
                                                ? ' · 🍞 ${context.tr('Save Food')}'
                                                : ''),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                QtyStepper(
                                  value: line.qty,
                                  min: 0,
                                  max: line.product.stock,
                                  onChanged: (v) =>
                                      _cart.setQty(line.product.barcode, v),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                color: context.colors.surface,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _cart.noPlasticBag,
                      onChanged: _cart.setNoPlasticBag,
                      title: Text(context.tr('No plastic bag')),
                      secondary: Icon(Icons.eco, color: context.eco),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _cart.isEmpty || _busy ? null : _checkout,
                      child: Text(
                        _cart.isEmpty
                            ? context.tr('Checkout')
                            : context.tr('Checkout · {total}', {
                                'total': formatRM(_cart.totalSen),
                              }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

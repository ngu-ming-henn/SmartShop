import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/staff/counter_sale_view_model.dart';
import '../../widgets/common.dart';
import '../../widgets/product_picker.dart';
import '../../widgets/product_widgets.dart';
import '../../widgets/scanner_view.dart';

/// Counter sale: scan items -> (optional) scan student member QR ->
/// checkout -> stock deducted -> digital receipt ([CounterSaleViewModel]).
class CounterSaleScreen extends StatelessWidget {
  const CounterSaleScreen({super.key});

  Future<void> _onCode(BuildContext context, String code) async {
    final vm = context.read<CounterSaleViewModel>();
    try {
      final result = await vm.scan(code);
      if (context.mounted) _tell(context, result, code);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  void _tell(BuildContext context, CounterScan result, String code) {
    final vm = context.read<CounterSaleViewModel>();
    final product = vm.lastProduct;
    final message = switch (result) {
      CounterScan.member => context.tr('Member: {name}', {
        'name': vm.member!.name,
      }),
      CounterScan.memberNotFound => context.tr('Member not found.'),
      CounterScan.unknown => context.tr('Unknown code {code}', {'code': code}),
      CounterScan.outOfStock => context.tr('{name} is out of stock.', {
        'name': product!.name,
      }),
      CounterScan.notEnough => context.tr('Only {count} {name} in stock.', {
        'count': product!.stock,
        'name': product.name,
      }),
      CounterScan.added => null,
    };
    if (message != null) showSnack(context, message);
  }

  Future<void> _search(BuildContext context) async {
    final vm = context.read<CounterSaleViewModel>();
    final p = await showProductPicker(context, products: vm.activeProducts);
    if (p != null && context.mounted) _tell(context, vm.add(p), p.barcode);
  }

  Future<void> _checkout(BuildContext context) async {
    final vm = context.read<CounterSaleViewModel>();
    final cart = vm.cart;
    final ok = await confirm(
      context,
      title: context.tr('Collect {total}', {'total': formatRM(cart.totalSen)}),
      message: [
        context.tr('{count} item(s)', {'count': cart.itemCount}),
        if (vm.member != null)
          context.tr(' · {name} earns +{points} points', {
            'name': vm.member!.name,
            'points': cart.pointsPreview,
          }),
        '\n\n',
        context.tr('Take payment, then confirm.'),
      ].join(),
      confirmLabel: context.tr('Paid'),
      cancelLabel: context.tr('Back'),
    );
    if (!ok || !context.mounted) return;
    try {
      final orderId = await vm.checkout();
      if (context.mounted) await context.push('/receipt/$orderId');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<CounterSaleViewModel>();
    final cart = vm.cart;
    final member = vm.member;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Counter sale')),
        actions: [
          IconButton(
            tooltip: context.tr('Search product'),
            icon: const Icon(Icons.search),
            onPressed: () => _search(context),
          ),
        ],
      ),
      body: Builder(
        builder: (context) => Column(
          children: [
            SizedBox(
              height: 220,
              child: ScannerView(
                continuous: true,
                hint: context.tr('Scan items or the student member QR'),
                onCode: (code) => _onCode(context, code),
              ),
            ),
            Material(
              color: member == null
                  ? context.colors.surface
                  : context.colors.secondaryContainer,
              child: ListTile(
                leading: Icon(
                  member == null ? Icons.person_outline : Icons.verified_user,
                  color: context.brand,
                ),
                title: Text(
                  member == null
                      ? context.tr('Walk-in customer')
                      : '${member.name} (${member.studentId})',
                ),
                subtitle: Text(
                  member == null
                      ? context.tr(
                          'Scan the member QR for a digital receipt and points',
                        )
                      : context.tr('{points} green points', {
                          'points': member.greenPoints,
                        }),
                ),
                trailing: member == null
                    ? null
                    : IconButton(
                        tooltip: context.tr('Remove member'),
                        icon: const Icon(Icons.close),
                        onPressed: vm.removeMember,
                      ),
              ),
            ),
            Expanded(
              child: cart.isEmpty
                  ? EmptyState(
                      icon: Icons.qr_code_scanner,
                      title: context.tr('Scan items to start'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: cart.lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final line = cart.lines[i];
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
                                      cart.setQty(line.product.barcode, v),
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
                      value: cart.noPlasticBag,
                      onChanged: cart.setNoPlasticBag,
                      title: Text(context.tr('No plastic bag')),
                      secondary: Icon(Icons.eco, color: context.eco),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: cart.isEmpty || vm.busy
                          ? null
                          : () => _checkout(context),
                      child: Text(
                        cart.isEmpty
                            ? context.tr('Checkout')
                            : context.tr('Checkout · {total}', {
                                'total': formatRM(cart.totalSen),
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

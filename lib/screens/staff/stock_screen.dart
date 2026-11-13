import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../viewmodels/staff/stock_view_model.dart';
import '../../widgets/common.dart';
import '../../widgets/product_picker.dart';
import '../../widgets/product_widgets.dart';
import '../common/scanner_page.dart';

/// Stock In / Out: scan barcode -> quantity -> 📷 read expiry date (AI)
/// or pick the date manually -> save ([StockViewModel]).
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, this.initialCode});
  final String? initialCode;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _qty = TextEditingController(text: '1');

  StockViewModel get _vm => context.read<StockViewModel>();

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _load(widget.initialCode!, MovementSource.manual),
      );
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _select(Product p, String source) {
    _qty.text = '1';
    _vm.select(p, source);
  }

  Future<void> _load(String code, String source) async {
    try {
      final product = await _vm.findByBarcode(code);
      if (!mounted) return;
      if (product != null) {
        _select(product, source);
        return;
      }
      final add = await confirm(
        context,
        title: context.tr('Product not found'),
        message: context.tr('No product with code {code}. Add it now?', {
          'code': code,
        }),
        confirmLabel: context.tr('Add product'),
        cancelLabel: context.tr('Cancel'),
      );
      if (add && mounted) {
        await context.push(
          '/staff/product-new?barcode=${Uri.encodeQueryComponent(code)}',
        );
        if (mounted) await _load(code, source); // back from the form: try again
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _scan() async {
    final code = await scanCode(
      context,
      title: context.tr('Scan product'),
      hint: context.tr('Scan the barcode or SmartShop QR label'),
    );
    if (code == null || !mounted) return;
    await _load(
      code,
      code.startsWith(shortCodePrefix)
          ? MovementSource.qr
          : MovementSource.barcode,
    );
  }

  Future<void> _find() async {
    final p = await showProductPicker(context, products: _vm.allProducts);
    if (p != null && mounted) _select(p, MovementSource.manual);
  }

  /// AI expiry-date scanner (design doc 8.4).
  Future<void> _readExpiry() async {
    try {
      final date = await _vm.readExpiryDate();
      if (date == null && mounted) {
        showSnack(
          context,
          context.tr('Date not found, please pick it manually'),
        );
      }
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          context.tr(
            'Could not read the photo. Please pick the date manually.',
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _vm.expiryDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: context.tr('Expiry date'),
    );
    if (picked != null) _vm.setExpiry(picked);
  }

  Future<void> _save(Product product) async {
    final qty = int.tryParse(_qty.text.trim());
    if (qty == null || qty <= 0) {
      showSnack(context, context.tr('Enter a valid quantity.'));
      return;
    }
    final stockIn = _vm.mode == StockMode.stockIn;
    try {
      final synced = await _vm.save(qty);
      if (!mounted) return;
      showSnack(
        context,
        !stockIn
            ? context.tr('Stock -{qty} for {name}', {
                'qty': qty,
                'name': product.name,
              })
            : synced
            ? context.tr('Stock +{qty} for {name}', {
                'qty': qty,
                'name': product.name,
              })
            : context.tr(
                'Stock +{qty} saved offline. It will sync when you are online.',
                {'qty': qty},
              ),
      );
      _qty.text = '1';
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StockViewModel>();
    final recent = vm.recent;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Stock in / out'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(context.tr('Scan barcode')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _find,
                  icon: const Icon(Icons.search),
                  label: Text(context.tr('Find product')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!vm.hasSelection)
            Card(
              child: ListTile(
                leading: Icon(Icons.inventory_2_outlined),
                title: Text(context.tr('Scan a barcode to start')),
                subtitle: Text(
                  context.tr(
                    'Stock in a delivery, or remove expired or damaged items.',
                  ),
                ),
              ),
            )
          else
            _form(context, vm, vm.product!),
          SectionHeader(title: context.tr('Recent stock movements')),
          if (vm.error != null)
            ErrorView(error: vm.error!)
          else if (recent == null)
            const LoadingView()
          else if (recent.isEmpty)
            Card(child: ListTile(title: Text(context.tr('No movements yet'))))
          else
            Card(
              child: Column(
                children: [for (final m in recent) _MovementTile(movement: m)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context, StockViewModel vm, Product product) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductTile(product: product),
        if (product.expiryDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              context.tr('Current nearest expiry: {date} ({label})', {
                'date': formatDate(product.expiryDate!),
                'label': expiryLabel(product.expiryDate!).toLowerCase(),
              }),
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        SegmentedButton<StockMode>(
          segments: [
            ButtonSegment(
              value: StockMode.stockIn,
              icon: Icon(Icons.add),
              label: Text(context.tr('Stock in')),
            ),
            ButtonSegment(
              value: StockMode.stockOut,
              icon: Icon(Icons.remove),
              label: Text(context.tr('Stock out')),
            ),
          ],
          selected: {vm.mode},
          onSelectionChanged: (s) {
            _qty.text = '1';
            vm.setMode(s.first);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _qty,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: context.tr('Quantity'),
            prefixIcon: Icon(Icons.numbers),
          ),
        ),
        const SizedBox(height: 12),
        if (vm.mode == StockMode.stockIn) _expirySection(context, vm),
        if (vm.mode == StockMode.stockOut)
          DropdownButtonFormField<String>(
            initialValue: vm.outReason,
            decoration: InputDecoration(labelText: context.tr('Reason')),
            items: [
              DropdownMenuItem(
                value: MovementType.expired,
                child: Text(context.tr('Expired (write-off)')),
              ),
              DropdownMenuItem(
                value: MovementType.damaged,
                child: Text(context.tr('Damaged')),
              ),
              DropdownMenuItem(
                value: MovementType.adjustment,
                child: Text(context.tr('Other adjustment')),
              ),
            ],
            onChanged: (v) => vm.setOutReason(v!),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: vm.busy ? null : () => _save(product),
          icon: vm.busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.save),
          label: Text(switch (vm.mode) {
            StockMode.stockIn => context.tr('Save stock in'),
            StockMode.stockOut => context.tr('Save stock out'),
          }),
        ),
      ],
    );
  }

  Widget _expirySection(BuildContext context, StockViewModel vm) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vm.expiryDate == null
                        ? context.tr('Expiry date: not set')
                        : context.tr('Expiry date: {date}', {
                            'date': formatDate(vm.expiryDate!),
                          }),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (vm.expiryDate != null)
                  IconButton(
                    tooltip: context.tr('Clear date'),
                    icon: const Icon(Icons.clear),
                    onPressed: () => vm.setExpiry(null),
                  ),
              ],
            ),
            if (vm.expiryFromAi)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Pill(
                  label: context.tr('Read by AI — please check'),
                  color: AppColors.accent,
                  textColor: AppColors.textOnAccent,
                  icon: Icons.auto_awesome,
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: vm.readingExpiry
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner),
                  label: Text(context.tr('📷 Read expiry date')),
                  onPressed: vm.readingExpiry ? null : _readExpiry,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(context.tr('Pick date')),
                  onPressed: _pickDate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});
  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final positive = m.quantity > 0;
    return ListTile(
      dense: true,
      leading: Icon(
        positive ? Icons.arrow_downward : Icons.arrow_upward,
        color: positive ? context.brand : AppColors.error,
      ),
      title: Text(m.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          m.typeLabel,
          if (m.createdAt != null) formatDateTime(m.createdAt!),
          if (m.expiryDate != null)
            context.tr('exp {date}', {'date': formatDate(m.expiryDate!)}),
        ].join(' · '),
      ),
      trailing: Text(
        positive ? '+${m.quantity}' : '${m.quantity}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: positive ? context.brand : AppColors.error,
        ),
      ),
    );
  }
}

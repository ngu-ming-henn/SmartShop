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
import '../../providers/auth_provider.dart';
import '../../services/expiry_scan_service.dart';
import '../../services/product_service.dart';
import '../../services/stock_service.dart';
import '../../widgets/common.dart';
import '../../widgets/product_picker.dart';
import '../../widgets/product_widgets.dart';
import '../common/scanner_page.dart';

enum _Mode { stockIn, stockOut }

/// Stock In / Out: scan barcode -> quantity -> 📷 read expiry date (AI)
/// or pick the date manually -> save.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, this.initialCode});
  final String? initialCode;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _expiryScanner = ExpiryScanService();
  final _qty = TextEditingController(text: '1');
  late final Stream<List<StockMovement>> _recent = context
      .read<StockService>()
      .watchRecentMovements(limit: 15);

  Stream<Product?>? _productStream;
  String? _barcode;
  String _source = MovementSource.barcode;
  _Mode _mode = _Mode.stockIn;
  DateTime? _expiryDate;
  bool _expiryFromAi = false;
  String _outReason = MovementType.expired;
  bool _busy = false;
  bool _readingExpiry = false;

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
    _expiryScanner.dispose();
    _qty.dispose();
    super.dispose();
  }

  String get _staffId => context.read<AuthProvider>().user!.uid;

  void _select(Product p, String source) {
    setState(() {
      _barcode = p.barcode;
      _productStream = context.read<ProductService>().watchProduct(p.barcode);
      _source = source;
      _expiryDate = null;
      _expiryFromAi = false;
      _qty.text = '1';
    });
  }

  Future<void> _load(String code, String source) async {
    try {
      final product = await context.read<ProductService>().findByBarcode(code);
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
    final p = await showProductPicker(context, activeOnly: false);
    if (p != null && mounted) _select(p, MovementSource.manual);
  }

  /// AI expiry-date scanner (design doc 8.4).
  Future<void> _readExpiry() async {
    setState(() => _readingExpiry = true);
    try {
      final date = await _expiryScanner.scanExpiryDate();
      if (!mounted) return;
      if (date == null) {
        showSnack(
          context,
          context.tr('Date not found, please pick it manually'),
        );
      } else {
        setState(() {
          _expiryDate = date; // staff can still change it
          _expiryFromAi = true;
        });
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
    } finally {
      if (mounted) setState(() => _readingExpiry = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Expiry date',
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
        _expiryFromAi = false;
      });
    }
  }

  Future<void> _save(Product product) async {
    final qty = int.tryParse(_qty.text.trim());
    if (qty == null || qty <= 0) {
      showSnack(context, context.tr('Enter a valid quantity.'));
      return;
    }
    setState(() => _busy = true);
    final stock = context.read<StockService>();
    try {
      switch (_mode) {
        case _Mode.stockIn:
          final synced = await stock.stockIn(
            product: product,
            quantity: qty,
            staffId: _staffId,
            expiryDate: _expiryDate,
            source: _source,
          );
          if (mounted) {
            showSnack(
              context,
              synced
                  ? context.tr('Stock +{qty} for {name}', {
                      'qty': qty,
                      'name': product.name,
                    })
                  : context.tr(
                      'Stock +{qty} saved offline. It will sync when you are online.',
                      {'qty': qty},
                    ),
            );
          }
        case _Mode.stockOut:
          await stock.stockOut(
            productId: product.barcode,
            quantity: qty,
            staffId: _staffId,
            type: _outReason,
            source: _source,
          );
          if (mounted) {
            showSnack(
              context,
              context.tr('Stock -{qty} for {name}', {
                'qty': qty,
                'name': product.name,
              }),
            );
          }
      }
      if (mounted) {
        setState(() {
          _expiryDate = null;
          _expiryFromAi = false;
          _qty.text = '1';
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          if (_productStream == null)
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
            StreamBuilder<Product?>(
              key: ValueKey(_barcode),
              stream: _productStream,
              builder: (context, snap) {
                if (snap.hasError) return ErrorView(error: snap.error!);
                final product = snap.data;
                if (product == null) return const LoadingView();
                return _form(context, product);
              },
            ),
          SectionHeader(title: context.tr('Recent stock movements')),
          StreamBuilder<List<StockMovement>>(
            stream: _recent,
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(error: snap.error!);
              if (!snap.hasData) return const LoadingView();
              if (snap.data!.isEmpty) {
                return Card(
                  child: ListTile(title: Text(context.tr('No movements yet'))),
                );
              }
              return Card(
                child: Column(
                  children: [
                    for (final m in snap.data!) _MovementTile(movement: m),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context, Product product) {
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
        SegmentedButton<_Mode>(
          segments: [
            ButtonSegment(
              value: _Mode.stockIn,
              icon: Icon(Icons.add),
              label: Text(context.tr('Stock in')),
            ),
            ButtonSegment(
              value: _Mode.stockOut,
              icon: Icon(Icons.remove),
              label: Text(context.tr('Stock out')),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            _qty.text = '1';
          }),
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
        if (_mode == _Mode.stockIn) _expirySection(context),
        if (_mode == _Mode.stockOut)
          DropdownButtonFormField<String>(
            initialValue: _outReason,
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
            onChanged: (v) => setState(() => _outReason = v!),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : () => _save(product),
          icon: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.save),
          label: Text(switch (_mode) {
            _Mode.stockIn => context.tr('Save stock in'),
            _Mode.stockOut => context.tr('Save stock out'),
          }),
        ),
      ],
    );
  }

  Widget _expirySection(BuildContext context) {
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
                    _expiryDate == null
                        ? context.tr('Expiry date: not set')
                        : context.tr('Expiry date: {date}', {
                            'date': formatDate(_expiryDate!),
                          }),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (_expiryDate != null)
                  IconButton(
                    tooltip: context.tr('Clear date'),
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _expiryDate = null),
                  ),
              ],
            ),
            if (_expiryFromAi)
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
                  icon: _readingExpiry
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner),
                  label: Text(context.tr('📷 Read expiry date')),
                  onPressed: _readingExpiry ? null : _readExpiry,
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

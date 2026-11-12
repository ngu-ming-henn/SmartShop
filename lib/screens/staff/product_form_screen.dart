import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/codes.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/expiry_scan_service.dart';
import '../../services/product_service.dart';
import '../../widgets/common.dart';
import '../common/scanner_page.dart';

/// Add a product ([newBarcode], "generate" for an SK- code) or edit one
/// ([editBarcode]). Stock is not edited here: use Stock In / Out.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.newBarcode, this.editBarcode});

  final String? newBarcode;
  final String? editBarcode;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _saveFoodPrice = TextEditingController();
  final _threshold = TextEditingController(
    text: '${AppRules.defaultLowStockThreshold}',
  );
  final _imageUrl = TextEditingController();
  final _openingStock = TextEditingController(text: '0');
  final _expiryScanner = ExpiryScanService();

  String _category = productCategories.first;
  DateTime? _expiryDate;
  bool _isActive = true;
  String _source = MovementSource.manual;
  Product? _original;
  bool _loading = false;
  bool _busy = false;

  bool get _isNew => widget.editBarcode == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) {
      _loadExisting();
    } else if (widget.newBarcode == 'generate') {
      _generateCode();
    } else if (widget.newBarcode != null) {
      _code.text = widget.newBarcode!;
      _source = MovementSource.barcode;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _code,
      _name,
      _description,
      _price,
      _saveFoodPrice,
      _threshold,
      _imageUrl,
      _openingStock,
    ]) {
      c.dispose();
    }
    _expiryScanner.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final p = await context.read<ProductService>().findByBarcode(
        widget.editBarcode!,
      );
      if (!mounted) return;
      if (p == null) {
        showSnack(context, context.tr('Product not found.'));
        context.pop();
        return;
      }
      _original = p;
      _code.text = p.barcode;
      _name.text = p.name;
      _description.text = p.description ?? '';
      _price.text = senToInput(p.priceSen);
      _saveFoodPrice.text = p.saveFoodPriceSen == null
          ? ''
          : senToInput(p.saveFoodPriceSen!);
      _threshold.text = '${p.lowStockThreshold}';
      _imageUrl.text = p.imageUrl ?? '';
      _category = productCategories.contains(p.category)
          ? p.category
          : 'Others';
      _expiryDate = p.expiryDate;
      _isActive = p.isActive;
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateCode() async {
    try {
      final code = await context.read<ProductService>().newShortCode();
      if (mounted) {
        setState(() {
          _code.text = code;
          _source = MovementSource.manual;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _scanBarcode() async {
    final code = await scanCode(
      context,
      title: context.tr('Scan product barcode'),
    );
    if (code != null && mounted) {
      setState(() {
        _code.text = code;
        _source = MovementSource.barcode;
      });
    }
  }

  Future<void> _readExpiry() async {
    try {
      final date = await _expiryScanner.scanExpiryDate();
      if (!mounted) return;
      if (date == null) {
        showSnack(
          context,
          context.tr('Date not found, please pick it manually'),
        );
      } else {
        setState(() => _expiryDate = date);
        showSnack(
          context,
          context.tr('Read {date}. Please check it.', {
            'date': formatDate(date),
          }),
        );
      }
    } catch (_) {
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
      initialDate: _expiryDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: context.tr('Expiry date'),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final saveFood = _saveFoodPrice.text.trim().isEmpty
        ? null
        : parseRMToSen(_saveFoodPrice.text);
    final product = Product(
      barcode: _code.text.trim(),
      name: _name.text.trim(),
      category: _category,
      priceSen: parseRMToSen(_price.text)!,
      saveFoodPriceSen: saveFood,
      stock: _isNew ? int.parse(_openingStock.text) : _original!.stock,
      lowStockThreshold: int.parse(_threshold.text),
      expiryDate: _expiryDate,
      imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      isActive: _isActive,
    );

    setState(() => _busy = true);
    final service = context.read<ProductService>();
    try {
      if (_isNew) {
        await service.createProduct(
          product,
          staffId: context.read<AuthProvider>().user!.uid,
          source: _source,
        );
      } else {
        await service.updateProduct(product);
      }
      if (!mounted) return;
      showSnack(
        context,
        context.tr(_isNew ? '{name} added' : '{name} saved', {
          'name': product.name,
        }),
        action: product.hasShortCode
            ? SnackBarAction(
                label: context.tr('QR label'),
                onPressed: () => context.push(
                  '/staff/label/${Uri.encodeComponent(product.barcode)}',
                ),
              )
            : null,
      );
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validatePrice(String? v) {
    final sen = parseRMToSen(v ?? '');
    if (sen == null || sen <= 0) return context.tr('Enter a price, e.g. 18.50');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(_isNew ? 'Add product' : 'Edit product')),
      ),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _code,
                    enabled: _isNew,
                    decoration: InputDecoration(
                      labelText: context.tr('Barcode / code'),
                      prefixIcon: const Icon(Icons.qr_code),
                      suffixIcon: _isNew
                          ? IconButton(
                              tooltip: context.tr('Scan barcode'),
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: _scanBarcode,
                            )
                          : null,
                    ),
                    validator: (v) => isValidProductCode(v?.trim() ?? '')
                        ? null
                        : context.tr('Scan or type a barcode (no "/")'),
                  ),
                  if (_isNew)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _generateCode,
                        icon: const Icon(Icons.auto_fix_high),
                        label: Text(
                          context.tr('No barcode? Generate an SK- code'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: context.tr('Product name'),
                    ),
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? context.tr('Enter a name')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 300,
                    decoration: InputDecoration(
                      labelText: context.tr('Description (optional)'),
                      hintText: context.tr('e.g. flavour, size, how to use it'),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: InputDecoration(
                      labelText: context.tr('Category'),
                    ),
                    items: [
                      for (final c in productCategories)
                        DropdownMenuItem(value: c, child: Text(context.tr(c))),
                    ],
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: context.tr('Price'),
                            prefixText: 'RM ',
                          ),
                          validator: _validatePrice,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _threshold,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: context.tr('Low-stock alert at'),
                          ),
                          validator: (v) => int.tryParse(v ?? '') == null
                              ? context.tr('Enter a number')
                              : null,
                        ),
                      ),
                    ],
                  ),
                  if (_isNew) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _openingStock,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: context.tr('Opening stock'),
                        helperText: context.tr('Logged as a stock-in movement'),
                      ),
                      validator: (v) => int.tryParse(v ?? '') == null
                          ? context.tr('Enter a number')
                          : null,
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _saveFoodPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.tr('Save Food price (optional)'),
                        prefixText: 'RM ',
                        helperText: context.tr('Leave empty for no deal'),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final sen = parseRMToSen(v);
                        final price = parseRMToSen(_price.text);
                        if (sen == null || sen <= 0) {
                          return context.tr('Enter a price or leave empty');
                        }
                        if (price != null && sen >= price) {
                          return context.tr(
                            'Must be lower than the normal price',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Stock: {count} (change it on the Stock screen)',
                        {'count': _original?.stock ?? 0},
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: context.tr('Image URL (optional)'),
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
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
                                      ? context.tr(
                                          'Expiry date: none (non-food)',
                                        )
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
                                  onPressed: () =>
                                      setState(() => _expiryDate = null),
                                ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.document_scanner),
                                label: Text(context.tr('📷 Read expiry date')),
                                onPressed: _readExpiry,
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
                  ),
                  if (!_isNew)
                    SwitchListTile(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      title: Text(context.tr('Sold in the app')),
                      subtitle: Text(
                        context.tr('Turn off to hide it from students'),
                      ),
                      activeThumbColor: context.brand,
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(
                      context.tr(_isNew ? 'Add product' : 'Save changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

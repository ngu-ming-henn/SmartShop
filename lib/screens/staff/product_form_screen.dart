import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/codes.dart';
import '../../core/utils/format.dart';
import '../../l10n/strings.dart';
import '../../viewmodels/staff/product_form_view_model.dart';
import '../../widgets/common.dart';
import '../common/scanner_page.dart';

/// Add a product or edit one ([ProductFormViewModel]). Stock is not edited
/// here: use Stock In / Out.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key});

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

  ProductFormViewModel get _vm => context.read<ProductFormViewModel>();

  @override
  void initState() {
    super.initState();
    final vm = _vm;
    _code.text = vm.initialCode;
    if (!vm.isNew) {
      _loadExisting();
    } else if (vm.wantsGeneratedCode) {
      _generateCode();
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
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final p = await _vm.loadExisting();
      if (!mounted) return;
      if (p == null) {
        showSnack(context, context.tr('Product not found.'));
        context.pop();
        return;
      }
      _code.text = p.barcode;
      _name.text = p.name;
      _description.text = p.description ?? '';
      _price.text = senToInput(p.priceSen);
      _saveFoodPrice.text = p.saveFoodPriceSen == null
          ? ''
          : senToInput(p.saveFoodPriceSen!);
      _threshold.text = '${p.lowStockThreshold}';
      _imageUrl.text = p.imageUrl ?? '';
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _generateCode() async {
    try {
      final code = await _vm.generateCode();
      if (mounted) _code.text = code;
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
      _code.text = code;
      _vm.usedScannedCode();
    }
  }

  Future<void> _readExpiry() async {
    try {
      final date = await _vm.readExpiryDate();
      if (!mounted) return;
      if (date == null) {
        showSnack(
          context,
          context.tr('Date not found, please pick it manually'),
        );
      } else {
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
      initialDate: _vm.expiryDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: context.tr('Expiry date'),
    );
    if (picked != null) _vm.setExpiry(picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final vm = _vm;
    try {
      final product = await vm.save(
        code: _code.text,
        name: _name.text,
        description: _description.text,
        priceSen: parseRMToSen(_price.text)!,
        saveFoodPriceSen: _saveFoodPrice.text.trim().isEmpty
            ? null
            : parseRMToSen(_saveFoodPrice.text),
        lowStockThreshold: int.parse(_threshold.text),
        openingStock: vm.isNew ? int.parse(_openingStock.text) : 0,
        imageUrl: _imageUrl.text,
      );
      if (!mounted) return;
      showSnack(
        context,
        context.tr(vm.isNew ? '{name} added' : '{name} saved', {
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
    final vm = context.watch<ProductFormViewModel>();
    final isNew = vm.isNew;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(isNew ? 'Add product' : 'Edit product')),
      ),
      body: vm.loading
          ? const LoadingView()
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _code,
                    enabled: isNew,
                    decoration: InputDecoration(
                      labelText: context.tr('Barcode / code'),
                      prefixIcon: const Icon(Icons.qr_code),
                      suffixIcon: isNew
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
                  if (isNew)
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
                    initialValue: vm.category,
                    decoration: InputDecoration(
                      labelText: context.tr('Category'),
                    ),
                    items: [
                      for (final c in productCategories)
                        DropdownMenuItem(value: c, child: Text(context.tr(c))),
                    ],
                    onChanged: (v) => vm.setCategory(v!),
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
                  if (isNew) ...[
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
                        {'count': vm.original?.stock ?? 0},
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
                                  vm.expiryDate == null
                                      ? context.tr(
                                          'Expiry date: none (non-food)',
                                        )
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
                  if (!isNew)
                    SwitchListTile(
                      value: vm.isActive,
                      onChanged: vm.setActive,
                      title: Text(context.tr('Sold in the app')),
                      subtitle: Text(
                        context.tr('Turn off to hide it from students'),
                      ),
                      activeThumbColor: context.brand,
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: vm.busy ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(
                      context.tr(isNew ? 'Add product' : 'Save changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

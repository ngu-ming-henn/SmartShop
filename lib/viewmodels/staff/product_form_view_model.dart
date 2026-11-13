import '../../core/constants.dart';
import '../../models/product.dart';
import '../../services/expiry_scan_service.dart';
import '../../services/product_service.dart';
import '../view_model.dart';

/// Add a product ([newBarcode]; "generate" makes an SK- code) or edit one
/// ([editBarcode]). Holds the choices that are not text fields (category,
/// expiry date, shown to students) and saves the product.
class ProductFormViewModel extends ViewModel {
  ProductFormViewModel(
    this._products,
    this._staffId, {
    this.newBarcode,
    this.editBarcode,
    ExpiryScanService? expiryScanner,
  }) : _expiry = expiryScanner ?? ExpiryScanService(),
       // Editing: loading from the start (the page opens on a spinner).
       loading = editBarcode != null {
    if (newBarcode != null && newBarcode != 'generate') {
      source = MovementSource.barcode;
    }
  }

  final ProductService _products;
  final ExpiryScanService _expiry;
  final String _staffId;
  final String? newBarcode;
  final String? editBarcode;

  bool get isNew => editBarcode == null;

  /// The code given when the form opened (scanned or typed), if any.
  String get initialCode =>
      newBarcode == null || newBarcode == 'generate' ? '' : newBarcode!;

  bool get wantsGeneratedCode => newBarcode == 'generate';

  String category = productCategories.first;
  DateTime? expiryDate;
  bool isActive = true;

  /// How the code was entered, logged with the opening stock.
  String source = MovementSource.manual;

  /// The product before editing (its stock is not changed here).
  Product? original;
  bool loading;

  /// Loads the product being edited; null when it no longer exists. Called
  /// while the page is first built, so it only redraws once it is done.
  Future<Product?> loadExisting() async {
    try {
      final p = await _products.findByBarcode(editBarcode!);
      if (p != null) {
        original = p;
        category = productCategories.contains(p.category)
            ? p.category
            : 'Others';
        expiryDate = p.expiryDate;
        isActive = p.isActive;
      }
      return p;
    } finally {
      loading = false;
      notify();
    }
  }

  /// A free "SK-000123" code for items without a barcode.
  Future<String> generateCode() async {
    final code = await _products.newShortCode();
    source = MovementSource.manual;
    notify();
    return code;
  }

  void usedScannedCode() {
    source = MovementSource.barcode;
  }

  void setCategory(String value) {
    category = value;
    notify();
  }

  void setExpiry(DateTime? date) {
    expiryDate = date;
    notify();
  }

  void setActive(bool value) {
    isActive = value;
    notify();
  }

  /// 📷 AI: reads the expiry date from a photo; null when none was found.
  Future<DateTime?> readExpiryDate() async {
    final date = await _expiry.scanExpiryDate();
    if (date != null) setExpiry(date);
    return date;
  }

  Future<Product> save({
    required String code,
    required String name,
    required String description,
    required int priceSen,
    required int? saveFoodPriceSen,
    required int lowStockThreshold,
    required int openingStock,
    required String imageUrl,
  }) => run(() async {
    final product = Product(
      barcode: code.trim(),
      name: name.trim(),
      category: category,
      priceSen: priceSen,
      saveFoodPriceSen: saveFoodPriceSen,
      stock: isNew ? openingStock : original!.stock,
      lowStockThreshold: lowStockThreshold,
      expiryDate: expiryDate,
      imageUrl: imageUrl.trim().isEmpty ? null : imageUrl.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      isActive: isActive,
    );
    if (isNew) {
      await _products.createProduct(product, staffId: _staffId, source: source);
    } else {
      await _products.updateProduct(product);
    }
    return product;
  });

  @override
  void dispose() {
    _expiry.dispose();
    super.dispose();
  }
}

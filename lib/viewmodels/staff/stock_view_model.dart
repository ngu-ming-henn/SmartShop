import 'dart:async';

import '../../core/constants.dart';
import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../services/expiry_scan_service.dart';
import '../../services/product_service.dart';
import '../../services/stock_service.dart';
import '../view_model.dart';

enum StockMode { stockIn, stockOut }

/// Stock in / out: the scanned product (live), quantity choices, the 📷 AI
/// expiry-date reader, and the recent stock history.
class StockViewModel extends ViewModel {
  StockViewModel(
    this._products,
    this._stock,
    this._staffId, {
    ExpiryScanService? expiryScanner,
  }) : _expiry = expiryScanner ?? ExpiryScanService() {
    follow(_stock.watchRecentMovements(limit: 15), (list) => _recent = list);
  }

  final ProductService _products;
  final StockService _stock;
  final ExpiryScanService _expiry;
  final String _staffId;

  List<StockMovement>? _recent;
  StreamSubscription<Product?>? _selected;

  /// Null until loaded.
  List<StockMovement>? get recent => _recent;

  /// The product being stocked; null until one is scanned or picked.
  Product? product;
  bool get hasSelection => _selected != null;

  String source = MovementSource.barcode;
  StockMode mode = StockMode.stockIn;
  String outReason = MovementType.expired;
  DateTime? expiryDate;

  /// The date came from the AI reader: staff should check it.
  bool expiryFromAi = false;
  bool readingExpiry = false;

  /// For "Find product" when a barcode cannot be scanned.
  Stream<List<Product>> get allProducts => _products.watchAllProducts();

  Future<Product?> findByBarcode(String code) => _products.findByBarcode(code);

  /// Follows [p] live (its stock changes after saving).
  void select(Product p, String from) {
    _selected?.cancel();
    product = p;
    source = from;
    expiryDate = null;
    expiryFromAi = false;
    _selected = _products.watchProduct(p.barcode).listen((latest) {
      if (latest != null) product = latest;
      notify();
    });
    notify();
  }

  void setMode(StockMode value) {
    mode = value;
    notify();
  }

  void setOutReason(String value) {
    outReason = value;
    notify();
  }

  void setExpiry(DateTime? date) {
    expiryDate = date;
    expiryFromAi = false;
    notify();
  }

  /// 📷 AI expiry-date scanner (design doc 8.4); null when none was found.
  Future<DateTime?> readExpiryDate() async {
    readingExpiry = true;
    notify();
    try {
      final date = await _expiry.scanExpiryDate();
      if (date != null) {
        expiryDate = date; // staff can still change it
        expiryFromAi = true;
      }
      return date;
    } finally {
      readingExpiry = false;
      notify();
    }
  }

  /// Saves the movement. Returns false when a stock-in was saved offline.
  Future<bool> save(int quantity) => run(() async {
    final p = product!;
    var synced = true;
    switch (mode) {
      case StockMode.stockIn:
        synced = await _stock.stockIn(
          product: p,
          quantity: quantity,
          staffId: _staffId,
          expiryDate: expiryDate,
          source: source,
        );
      case StockMode.stockOut:
        await _stock.stockOut(
          productId: p.barcode,
          quantity: quantity,
          staffId: _staffId,
          type: outReason,
          source: source,
        );
    }
    expiryDate = null;
    expiryFromAi = false;
    return synced;
  });

  @override
  void dispose() {
    _selected?.cancel();
    _expiry.dispose();
    super.dispose();
  }
}

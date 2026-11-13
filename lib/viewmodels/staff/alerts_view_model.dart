import '../../core/constants.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/stock_service.dart';
import '../view_model.dart';

/// Alerts: low-stock and near-expiry products (live), Save Food deals and
/// writing off expired stock.
class AlertsViewModel extends ViewModel {
  AlertsViewModel(this._products, this._stock, this._staffId) {
    follow(_products.watchAllProducts(), (list) => _all = list);
  }

  final ProductService _products;
  final StockService _stock;
  final String _staffId;
  List<Product>? _all;

  bool get loading => _all == null && error == null;

  Iterable<Product> get _active =>
      (_all ?? const <Product>[]).where((p) => p.isActive);

  /// Fewest left first.
  List<Product> get lowStock =>
      _active.where((p) => p.needsRestock).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));

  /// Expiring first.
  List<Product> get nearExpiry =>
      _active.where((p) => p.needsExpiryAction()).toList()
        ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

  Future<void> startSaveFood(Product p, int priceSen) =>
      _products.setSaveFoodPrice(p.barcode, priceSen);

  Future<void> endSaveFood(Product p) =>
      _products.setSaveFoodPrice(p.barcode, null);

  /// Expired items thrown away (logged in the stock history).
  Future<void> writeOff(Product p, int quantity) => _stock.stockOut(
    productId: p.barcode,
    quantity: quantity,
    staffId: _staffId,
    type: MovementType.expired,
  );
}

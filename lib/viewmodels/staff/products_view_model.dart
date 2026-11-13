import '../../models/product.dart';
import '../../services/product_service.dart';
import '../view_model.dart';

enum ProductFilter { all, lowStock, noBarcode, disabled }

/// Staff product list: every product (also hidden ones), search, filters,
/// and hiding / showing a product to students.
class ProductsViewModel extends ViewModel {
  ProductsViewModel(this._products) {
    follow(_products.watchAllProducts(), (list) => _all = list);
  }

  final ProductService _products;
  List<Product>? _all;
  String _query = '';
  ProductFilter filter = ProductFilter.all;

  bool get loading => _all == null && error == null;
  bool get shopIsEmpty => _all != null && _all!.isEmpty;

  List<Product> get items =>
      (_all ?? const <Product>[]).where(_matches).toList();

  bool _matches(Product p) {
    if (_query.isNotEmpty &&
        !p.name.toLowerCase().contains(_query) &&
        !p.barcode.toLowerCase().contains(_query)) {
      return false;
    }
    return switch (filter) {
      ProductFilter.all => true,
      ProductFilter.lowStock => p.needsRestock,
      ProductFilter.noBarcode => p.hasShortCode,
      ProductFilter.disabled => !p.isActive,
    };
  }

  void search(String text) {
    _query = text.trim().toLowerCase();
    notify();
  }

  void show(ProductFilter value) {
    filter = value;
    notify();
  }

  /// Hides a product from students, or shows it again.
  Future<void> toggleActive(Product p) =>
      _products.setActive(p.barcode, !p.isActive);
}

import '../../models/product.dart';
import '../../services/product_service.dart';
import '../view_model.dart';

/// Search / category list: live products and the filters the student picks.
class ProductListViewModel extends ViewModel {
  ProductListViewModel(
    ProductService products, {
    String? initialCategory,
    String? query,
    bool saveFoodOnly = false,
  }) : _category = initialCategory,
       _query = query ?? '',
       _saveFood = saveFoodOnly {
    follow(products.watchActiveProducts(), (list) => _all = list);
  }

  List<Product>? _all;
  String _query;
  String? _category;
  bool _saveFood;
  bool _inStockOnly = false;

  String get query => _query;
  String? get category => _category;
  bool get saveFoodOnly => _saveFood;
  bool get inStockOnly => _inStockOnly;

  /// Null while loading.
  List<Product>? get items {
    final all = _all;
    if (all == null) return null;
    final q = _query.trim().toLowerCase();
    return all.where((p) {
      if (_category != null && p.category != _category) return false;
      if (_saveFood && !p.isOnSaveFood) return false;
      if (_inStockOnly && p.isOutOfStock) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) || p.barcode.toLowerCase() == q;
    }).toList();
  }

  void search(String text) {
    _query = text;
    notify();
  }

  void showCategory(String? value) {
    _category = value;
    notify();
  }

  void showSaveFoodOnly(bool value) {
    _saveFood = value;
    notify();
  }

  void showInStockOnly(bool value) {
    _inStockOnly = value;
    notify();
  }
}

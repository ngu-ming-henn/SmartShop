import '../../models/product.dart';
import '../../services/product_service.dart';
import '../cart_view_model.dart';
import '../view_model.dart';

/// One product: live price and stock, the quantity picked, add to cart.
class ProductDetailViewModel extends ViewModel {
  ProductDetailViewModel(ProductService products, this._cart, this.code) {
    follow(products.watchProduct(code), (p) {
      _product = p;
      _loaded = true;
    });
  }

  final CartViewModel _cart;
  final String code;
  Product? _product;
  bool _loaded = false;

  bool get loading => !_loaded && error == null;

  /// Null when it does not exist or staff hid it.
  Product? get product => _product?.isActive == true ? _product : null;

  int qty = 1;

  void setQty(int value) {
    qty = value;
    notify();
  }

  /// Adds [qty] to the cart. Returns how many were added, or 0 when the
  /// cart already holds all the stock.
  int addToCart() {
    final added = qty;
    if (product == null || !_cart.add(product!, qty: added)) return 0;
    qty = 1;
    notify();
    return added;
  }
}

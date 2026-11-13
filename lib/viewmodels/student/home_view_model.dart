import '../../models/order.dart';
import '../../models/product.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../view_model.dart';

/// Home: live products (Save Food deals, popular, the Hot Deal advert) and
/// the student's orders that are ready for pickup.
class HomeViewModel extends ViewModel {
  HomeViewModel(ProductService products, OrderService orders, String uid) {
    follow(products.watchActiveProducts(), (list) => _products = list);
    follow(orders.watchMyOrders(uid), (list) => _orders = list);
  }

  List<Product>? _products;
  List<Order> _orders = const [];

  /// Null while loading.
  List<Product>? get products => _products;

  /// Save Food items in stock, the ones expiring first at the front.
  List<Product> get deals =>
      (_products ?? const <Product>[])
          .where((p) => p.isOnSaveFood && !p.isOutOfStock)
          .toList()
        ..sort(
          (a, b) => (a.expiryDate ?? DateTime(9999)).compareTo(
            b.expiryDate ?? DateTime(9999),
          ),
        );

  /// In stock, best sellers first.
  List<Product> get popular =>
      (_products ?? const <Product>[]).where((p) => !p.isOutOfStock).toList()
        ..sort((a, b) {
          final bySold = b.soldCount.compareTo(a.soldCount);
          return bySold != 0 ? bySold : a.name.compareTo(b.name);
        });

  /// What the Hot Deal advert cycles through.
  List<Product> get featured =>
      [...deals, ...popular.where((p) => !p.isOnSaveFood)].take(6).toList();

  List<Order> get readyOrders => _orders.where((o) => o.isReady).toList();

  /// The "Find the koperasi" card was closed with ✕. Kept until the app is
  /// opened again (on purpose not saved), so it is shared by every Home.
  static bool _shopCardHidden = false;
  bool get shopCardHidden => _shopCardHidden;

  void hideShopCard() {
    _shopCardHidden = true;
    notify();
  }
}

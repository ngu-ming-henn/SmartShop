import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../cart_view_model.dart';
import '../view_model.dart';

/// What happened to a scanned code at the counter (the View shows it).
enum CounterScan {
  member,
  memberNotFound,
  unknown,
  outOfStock,
  notEnough,
  added,
}

/// Counter sale: scan items (or the student's member QR) into a cart of its
/// own, then checkout -> stock deducted -> digital receipt.
class CounterSaleViewModel extends ViewModel {
  CounterSaleViewModel(
    this._auth,
    this._products,
    this._orders,
    this._staffId,
  ) {
    cart.addListener(notify);
  }

  final AuthService _auth;
  final ProductService _products;
  final OrderService _orders;
  final String _staffId;

  /// Separate from the student's cart.
  final cart = CartViewModel();

  /// The student whose member QR was scanned (digital receipt + points).
  AppUser? member;

  /// The product of the last scan, for the message.
  Product? lastProduct;

  /// For "Search product" when a barcode cannot be scanned.
  Stream<List<Product>> get activeProducts => _products.watchActiveProducts();

  Future<CounterScan> scan(String code) async {
    if (code.startsWith(memberQrPrefix)) {
      final found = await _auth.getUser(code.substring(memberQrPrefix.length));
      if (found == null) return CounterScan.memberNotFound;
      member = found;
      notify();
      return CounterScan.member;
    }
    return add(await _products.findByBarcode(code));
  }

  CounterScan add(Product? product) {
    lastProduct = product;
    if (product == null || !product.isActive) return CounterScan.unknown;
    if (product.isOutOfStock) return CounterScan.outOfStock;
    return cart.add(product) ? CounterScan.added : CounterScan.notEnough;
  }

  void removeMember() {
    member = null;
    notify();
  }

  /// Records the sale (stock deducted, points for a member); returns the
  /// order id for the receipt.
  Future<String> checkout() => run(() async {
    final orderId = await _orders.counterSale(
      requested: cart.toOrderItems(),
      staffId: _staffId,
      noPlasticBag: cart.noPlasticBag,
      member: member,
    );
    cart.clear();
    member = null;
    return orderId;
  });

  @override
  void dispose() {
    cart.removeListener(notify);
    cart.dispose();
    super.dispose();
  }
}

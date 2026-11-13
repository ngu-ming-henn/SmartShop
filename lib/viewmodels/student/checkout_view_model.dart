import '../../services/order_service.dart';
import '../auth_view_model.dart';
import '../cart_view_model.dart';
import '../view_model.dart';

/// Cart & checkout: turns the cart into a pre-order (pay at the counter).
class CheckoutViewModel extends ViewModel {
  CheckoutViewModel(this._orders, this._cart, this._auth);

  final OrderService _orders;
  final CartViewModel _cart;
  final AuthViewModel _auth;

  /// Places the pre-order and empties the cart. Null when there is nothing
  /// to order. `synced` is false when it was saved offline.
  Future<PlaceOrderResult?> placeOrder() => run(() async {
    final user = _auth.user;
    if (user == null || _cart.isEmpty) return null;
    final result = await _orders.placePreorder(
      user: user,
      items: _cart.toOrderItems(),
      noPlasticBag: _cart.noPlasticBag,
    );
    _cart.clear();
    return result;
  });
}
